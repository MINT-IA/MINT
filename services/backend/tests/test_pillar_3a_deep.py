"""
Tests for Pillar 3a Deep Dive module (Sprint S16).

Covers:
    - Multi-account staggered withdrawal — 10 tests
    - Real return calculator — 7 tests
    - Provider comparator — 7 tests
    - API endpoints (integration) — 3 tests
    - Compliance (banned terms, disclaimer, premier_eclairage) — 4 tests

Target: 31 tests.

Run: cd services/backend && python3 -m pytest tests/test_pillar_3a_deep.py -v
"""

import re
import pytest

from app.services.pillar_3a_deep.multi_account_service import (
    MultiAccountService,
    DISCLAIMER as MULTI_DISCLAIMER,
    TAUX_IMPOT_RETRAIT_CAPITAL,
)
from app.services.pillar_3a_deep.real_return_service import (
    RealReturnService,
    DISCLAIMER as RETURN_DISCLAIMER,
    PLAFOND_3A_SALARIE,
    fv_annuity_due,
    solve_rate_bisection,
)
from app.services.pillar_3a_deep.provider_comparator_service import (
    ProviderComparatorService,
    DISCLAIMER as PROVIDER_DISCLAIMER,
    PROVIDERS,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def multi_service():
    return MultiAccountService()


@pytest.fixture
def return_service():
    return RealReturnService()


@pytest.fixture
def provider_service():
    return ProviderComparatorService()


# ===========================================================================
# TestMultiAccount — Staggered withdrawal simulator (10 tests)
# ===========================================================================

class TestMultiAccount:
    """Tests for the multi-account staggered 3a withdrawal simulator."""

    def test_bloc_tax_higher_than_staggered(self, multi_service):
        """Bloc withdrawal should have higher tax than staggered."""
        result = multi_service.simulate_staggered_withdrawal(
            avoir_total=300_000,
            nb_comptes=3,
            canton="VD",
            revenu_imposable=120_000,
            age_retrait_debut=60,
            age_retrait_fin=64,
        )
        assert result.bloc_tax > result.staggered_tax
        assert result.economy > 0

    def test_single_account_no_savings(self, multi_service):
        """With 1 account, staggered == bloc."""
        result = multi_service.simulate_staggered_withdrawal(
            avoir_total=200_000,
            nb_comptes=1,
            canton="ZH",
            revenu_imposable=100_000,
            age_retrait_debut=60,
            age_retrait_fin=64,
        )
        assert result.nb_comptes == 1
        assert abs(result.bloc_tax - result.staggered_tax) < 0.01

    def test_three_accounts_plan_has_three_entries(self, multi_service):
        """3 accounts should produce 3 yearly entries."""
        result = multi_service.simulate_staggered_withdrawal(
            avoir_total=150_000,
            nb_comptes=3,
            canton="GE",
            revenu_imposable=100_000,
            age_retrait_debut=60,
            age_retrait_fin=64,
        )
        assert len(result.yearly_plan) == 3

    def test_five_accounts_max_savings(self, multi_service):
        """5 accounts should produce even more savings than 3."""
        result_3 = multi_service.simulate_staggered_withdrawal(
            avoir_total=500_000,
            nb_comptes=3,
            canton="VD",
            revenu_imposable=150_000,
            age_retrait_debut=60,
            age_retrait_fin=64,
        )
        result_5 = multi_service.simulate_staggered_withdrawal(
            avoir_total=500_000,
            nb_comptes=5,
            canton="VD",
            revenu_imposable=150_000,
            age_retrait_debut=60,
            age_retrait_fin=64,
        )
        assert result_5.economy >= result_3.economy

    def test_canton_zg_lowest_tax(self, multi_service):
        """ZG (low tax canton) should have lower taxes than GE."""
        result_zg = multi_service.simulate_staggered_withdrawal(
            avoir_total=200_000,
            nb_comptes=3,
            canton="ZG",
            revenu_imposable=100_000,
            age_retrait_debut=60,
            age_retrait_fin=64,
        )
        result_ge = multi_service.simulate_staggered_withdrawal(
            avoir_total=200_000,
            nb_comptes=3,
            canton="GE",
            revenu_imposable=100_000,
            age_retrait_debut=60,
            age_retrait_fin=64,
        )
        assert result_zg.bloc_tax < result_ge.bloc_tax

    def test_six_cantons_all_work(self, multi_service):
        """Test the 6 main cantons (ZH, BE, VD, GE, LU, BS)."""
        for canton in ["ZH", "BE", "VD", "GE", "LU", "BS"]:
            result = multi_service.simulate_staggered_withdrawal(
                avoir_total=200_000,
                nb_comptes=3,
                canton=canton,
                revenu_imposable=120_000,
                age_retrait_debut=60,
                age_retrait_fin=64,
            )
            assert result.bloc_tax > 0
            assert result.canton == canton

    def test_all_26_cantons_in_tax_table(self, multi_service):
        """Tax table should have all 26 cantons."""
        assert len(TAUX_IMPOT_RETRAIT_CAPITAL) == 26

    def test_yearly_plan_sums_to_total(self, multi_service):
        """All yearly withdrawals should sum to the total avoir."""
        result = multi_service.simulate_staggered_withdrawal(
            avoir_total=250_000,
            nb_comptes=4,
            canton="VD",
            revenu_imposable=100_000,
            age_retrait_debut=60,
            age_retrait_fin=64,
        )
        total = sum(e.montant_retrait for e in result.yearly_plan)
        assert abs(total - 250_000) < 0.01

    def test_zero_avoir_produces_zero_tax(self, multi_service):
        """Zero avoir should produce zero taxes."""
        result = multi_service.simulate_staggered_withdrawal(
            avoir_total=0,
            nb_comptes=3,
            canton="ZH",
            revenu_imposable=100_000,
            age_retrait_debut=60,
            age_retrait_fin=64,
        )
        assert result.bloc_tax == 0.0
        assert result.staggered_tax == 0.0

    def test_optimal_accounts_between_2_and_5(self, multi_service):
        """Optimal accounts recommendation should be between 2 and 5."""
        result = multi_service.simulate_staggered_withdrawal(
            avoir_total=300_000,
            nb_comptes=3,
            canton="VD",
            revenu_imposable=150_000,
            age_retrait_debut=60,
            age_retrait_fin=64,
        )
        assert 2 <= result.optimal_accounts <= 5


# ===========================================================================
# TestRealReturn — Real return calculator (7 tests)
# ===========================================================================

class TestRealReturn:
    """Tests for the real return calculator."""

    def test_basic_return_positive(self, return_service):
        """Real return should be positive with positive inputs."""
        result = return_service.calculate_real_return(
            versement_annuel=PLAFOND_3A_SALARIE,
            taux_marginal=0.30,
            rendement_brut=0.04,
            frais_gestion=0.005,
            duree_annees=30,
            inflation=0.01,
        )
        assert result.rendement_reel_annualise > 0
        assert result.capital_final_3a > result.total_verse

    def test_tax_savings_calculated(self, return_service):
        """Tax savings should equal versement x taux_marginal x duree."""
        result = return_service.calculate_real_return(
            versement_annuel=7000,
            taux_marginal=0.30,
            rendement_brut=0.04,
            frais_gestion=0.005,
            duree_annees=20,
            inflation=0.01,
        )
        expected_savings = 7000 * 0.30 * 20
        assert abs(result.total_economies_fiscales - expected_savings) < 0.01

    def test_higher_marginal_rate_better_return(self, return_service):
        """Higher marginal tax rate should improve real return."""
        result_low = return_service.calculate_real_return(
            versement_annuel=7000,
            taux_marginal=0.15,
            rendement_brut=0.04,
            frais_gestion=0.005,
            duree_annees=30,
        )
        result_high = return_service.calculate_real_return(
            versement_annuel=7000,
            taux_marginal=0.35,
            rendement_brut=0.04,
            frais_gestion=0.005,
            duree_annees=30,
        )
        assert result_high.rendement_reel_annualise > result_low.rendement_reel_annualise

    def test_3a_better_than_savings(self, return_service):
        """3a should outperform savings account (with tax deduction)."""
        result = return_service.calculate_real_return(
            versement_annuel=7000,
            taux_marginal=0.25,
            rendement_brut=0.04,
            frais_gestion=0.005,
            duree_annees=30,
            inflation=0.01,
        )
        assert result.avantage_3a_vs_epargne > 0
        total_3a = result.capital_final_3a + result.total_economies_fiscales
        assert total_3a > result.capital_final_epargne

    def test_capital_3a_equals_fv_annuity_due(self, return_service):
        """capital_3a should equal fv_annuity_due(versement, rGross, n)."""
        result = return_service.calculate_real_return(
            versement_annuel=7000,
            taux_marginal=0.30,
            rendement_brut=0.04,
            frais_gestion=0.005,
            duree_annees=30,
        )
        r_gross = 0.04 - 0.005  # 0.035
        expected = fv_annuity_due(7000, r_gross, 30)
        assert abs(result.capital_final_3a - expected) < 0.01

    def test_rendement_nominal_equals_rgross(self, return_service):
        """rendement_net_annuel should equal rGross = brut - frais."""
        result = return_service.calculate_real_return(
            versement_annuel=7000,
            taux_marginal=0.30,
            rendement_brut=0.04,
            frais_gestion=0.005,
            duree_annees=30,
        )
        assert abs(result.rendement_net_annuel - 0.035) < 1e-5

    def test_roundtrip_fv_annuity_due(self, return_service):
        """fv_annuity_due(pmtNet, rNet, n) should ≈ capital_3a."""
        result = return_service.calculate_real_return(
            versement_annuel=7258,
            taux_marginal=0.30,
            rendement_brut=0.045,
            frais_gestion=0.005,
            duree_annees=30,
        )
        pmt_net = 7258 * (1 - 0.30)
        r_net = result.rendement_reel_annualise
        fv_check = fv_annuity_due(pmt_net, r_net, 30)
        assert abs(fv_check - result.capital_final_3a) < 1.0

    def test_marginal_tax_rate_zero_keeps_same_rate(self, return_service):
        """With 0% tax rate, rNet should match rGross."""
        result = return_service.calculate_real_return(
            versement_annuel=7258,
            taux_marginal=0.0,
            rendement_brut=0.03,
            frais_gestion=0.0,
            duree_annees=16,
        )
        assert abs(result.rendement_reel_annualise - 0.03) < 1e-6

    def test_non_regression_prompt_case_7258_10pct_3pct_49_to_65(self, return_service):
        """Prompt case: 7'258, 10%, 3%, n=16 should roundtrip exactly."""
        pmt_gross = 7258.0
        marginal_tax_rate = 0.10
        r_gross = 0.03
        n = 16
        pmt_net = pmt_gross * (1 - marginal_tax_rate)

        fv_gross = fv_annuity_due(pmt_gross, r_gross, n)
        r_net = solve_rate_bisection(pmt_net, fv_gross, n)
        fv_check = fv_annuity_due(pmt_net, r_net, n)

        assert abs(fv_check - fv_gross) < 1e-4
        assert r_net > r_gross

    def test_duration_zero_returns_zero_capital_and_zero_rate(self, return_service):
        """n=0 should return zero FV and zero equivalent rate by design."""
        result = return_service.calculate_real_return(
            versement_annuel=7258,
            taux_marginal=0.30,
            rendement_brut=0.04,
            frais_gestion=0.005,
            duree_annees=0,
        )
        assert result.capital_final_3a == 0.0
        assert result.total_verse == 0.0
        assert result.rendement_reel_annualise == 0.0

    def test_negative_gross_after_fees_supported(self, return_service):
        """Negative gross net rate should be supported above -99%."""
        result = return_service.calculate_real_return(
            versement_annuel=7258,
            taux_marginal=0.20,
            rendement_brut=-0.02,
            frais_gestion=0.0,
            duree_annees=10,
        )
        assert result.rendement_net_annuel < 0
        assert result.capital_final_3a > 0

    def test_zero_return_still_has_tax_advantage(self, return_service):
        """Even with 0% gross return, tax savings provide a real return."""
        result = return_service.calculate_real_return(
            versement_annuel=7000,
            taux_marginal=0.30,
            rendement_brut=0.0,
            frais_gestion=0.0,
            duree_annees=20,
            inflation=0.0,
        )
        assert result.total_economies_fiscales > 0
        assert result.rendement_reel_annualise > 0

    def test_short_duration(self, return_service):
        """Short duration (1 year) should still produce valid results."""
        result = return_service.calculate_real_return(
            versement_annuel=7000,
            taux_marginal=0.30,
            rendement_brut=0.04,
            frais_gestion=0.005,
            duree_annees=1,
        )
        assert result.duree_annees == 1
        assert result.total_verse == 7000
        assert result.capital_final_3a > 0


# ===========================================================================
# TestProviderComparator — Provider comparison (7 tests)
# ===========================================================================

class TestProviderComparator:
    """Tests for the 3a provider comparator."""

    def test_five_providers_returned(self, provider_service):
        """Should return projections for all 5 providers."""
        result = provider_service.compare_providers(
            age=30,
            versement_annuel=7000,
            duree=35,
            profil_risque="equilibre",
        )
        assert len(result.projections) == 5

    def test_fintech_beats_assurance(self, provider_service):
        """Fintech providers should have higher capital than assurance."""
        result = provider_service.compare_providers(
            age=25,
            versement_annuel=7000,
            duree=40,
            profil_risque="dynamique",
        )
        fintechs = [p for p in result.projections if p.type_provider == "fintech"]
        assurances = [p for p in result.projections if p.type_provider == "assurance"]
        assert len(fintechs) > 0
        assert len(assurances) > 0
        best_fintech = max(p.capital_final for p in fintechs)
        best_assurance = max(p.capital_final for p in assurances)
        assert best_fintech > best_assurance

    def test_insurance_warning_for_young(self, provider_service):
        """Insurance should have a warning for users under 35."""
        result = provider_service.compare_providers(
            age=25,
            versement_annuel=7000,
            duree=40,
            profil_risque="equilibre",
        )
        assurance = [p for p in result.projections if p.type_provider == "assurance"][0]
        assert assurance.warning is not None
        assert "fintech" in assurance.warning.lower() or "rendement" in assurance.warning.lower()

    def test_all_providers_have_data(self, provider_service):
        """All 5 static providers should be defined."""
        assert len(PROVIDERS) == 5
        types = set(p.type_provider for p in PROVIDERS)
        assert "fintech" in types
        assert "banque" in types
        assert "assurance" in types

    def test_difference_max_positive(self, provider_service):
        """Max difference between best and worst should be positive."""
        result = provider_service.compare_providers(
            age=30,
            versement_annuel=7000,
            duree=30,
            profil_risque="equilibre",
        )
        assert result.difference_max > 0

    def test_prudent_vs_dynamique(self, provider_service):
        """Dynamique should yield higher returns than prudent."""
        result_p = provider_service.compare_providers(
            age=30, versement_annuel=7000, duree=30, profil_risque="prudent",
        )
        result_d = provider_service.compare_providers(
            age=30, versement_annuel=7000, duree=30, profil_risque="dynamique",
        )
        # Finpension dynamique > Finpension prudent
        fp_p = [p for p in result_p.projections if p.nom == "Finpension"][0]
        fp_d = [p for p in result_d.projections if p.nom == "Finpension"][0]
        assert fp_d.capital_final > fp_p.capital_final

    def test_base_legale_present(self, provider_service):
        """Response should include base legale (OPP3, LIFD)."""
        result = provider_service.compare_providers(
            age=30, versement_annuel=7000, duree=30,
        )
        assert "OPP3" in result.base_legale
        assert "LIFD" in result.base_legale


# ===========================================================================
# TestPillar3aDeepEndpoints — API integration (3 tests)
# ===========================================================================

class TestPillar3aDeepEndpoints:
    """Tests for the Pillar 3a Deep FastAPI endpoints."""

    def test_staggered_withdrawal_endpoint(self, client):
        """POST /3a-deep/staggered-withdrawal should return 200."""
        response = client.post(
            "/api/v1/3a-deep/staggered-withdrawal",
            json={
                "avoirTotal": 300000,
                "nbComptes": 3,
                "canton": "VD",
                "revenuImposable": 120000,
                "ageRetraitDebut": 60,
                "ageRetraitFin": 64,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["yearlyPlan"]) == 3
        assert data["economy"] > 0
        assert "premierEclairage" in data
        assert "disclaimer" in data
        assert "sources" in data

    def test_real_return_endpoint(self, client):
        """POST /3a-deep/real-return should return 200."""
        response = client.post(
            "/api/v1/3a-deep/real-return",
            json={
                "versementAnnuel": 7000,
                "tauxMarginal": 0.30,
                "rendementBrut": 0.04,
                "fraisGestion": 0.005,
                "dureeAnnees": 30,
                "inflation": 0.01,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["capitalFinal3a"] > data["totalVerse"]
        assert "premierEclairage" in data
        assert "disclaimer" in data

    def test_compare_providers_endpoint(self, client):
        """POST /3a-deep/compare-providers should return 200."""
        response = client.post(
            "/api/v1/3a-deep/compare-providers",
            json={
                "age": 30,
                "versementAnnuel": 7000,
                "duree": 35,
                "profilRisque": "equilibre",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["projections"]) == 5
        assert data["differenceMax"] > 0
        assert "premierEclairage" in data
        assert "disclaimer" in data


# ===========================================================================
# TestPillar3aDeepCompliance — Compliance checks (4 tests)
# ===========================================================================

class TestPillar3aDeepCompliance:
    """Compliance checks for Pillar 3a Deep."""

    BANNED_PATTERNS = [
        r"\bgaranti[es]?\b",
        r"\bcertaine?s?\b",
        r"\best\s+assure[es]?\b",
        r"\bsont\s+assure[es]?\b",
    ]

    def _collect_all_text(self, data) -> str:
        texts = []
        if isinstance(data, dict):
            for value in data.values():
                texts.append(self._collect_all_text(value))
        elif isinstance(data, list):
            for item in data:
                texts.append(self._collect_all_text(item))
        elif isinstance(data, str):
            texts.append(data)
        return " ".join(texts)

    def test_no_banned_terms_in_disclaimers(self):
        """Disclaimers should not contain banned terms."""
        all_disclaimers = MULTI_DISCLAIMER + RETURN_DISCLAIMER + PROVIDER_DISCLAIMER
        for pattern in self.BANNED_PATTERNS:
            matches = re.findall(pattern, all_disclaimers, re.IGNORECASE)
            assert len(matches) == 0, (
                f"Banned pattern '{pattern}' found in disclaimers: {matches}"
            )

    def test_gender_neutral_disclaimers(self):
        """Disclaimers should use gender-neutral language."""
        for disclaimer in [MULTI_DISCLAIMER, RETURN_DISCLAIMER, PROVIDER_DISCLAIMER]:
            assert "un ou une specialiste" in disclaimer.lower(), (
                f"Disclaimer should use gender-neutral language: {disclaimer}"
            )

    def test_premier_eclairage_always_present(self, multi_service, return_service, provider_service):
        """All service results should include a premier_eclairage."""
        r1 = multi_service.simulate_staggered_withdrawal(
            avoir_total=200_000, nb_comptes=3, canton="VD",
            revenu_imposable=100_000, age_retrait_debut=60, age_retrait_fin=64,
        )
        assert len(r1.premier_eclairage) > 10

        r2 = return_service.calculate_real_return(
            versement_annuel=7000, taux_marginal=0.30,
            rendement_brut=0.04, frais_gestion=0.005, duree_annees=30,
        )
        assert len(r2.premier_eclairage) > 10

        r3 = provider_service.compare_providers(
            age=30, versement_annuel=7000, duree=30,
        )
        assert len(r3.premier_eclairage) > 10

    def test_no_banned_terms_in_api_responses(self, client):
        """No API response should contain banned terms."""
        endpoints_and_bodies = [
            ("/api/v1/3a-deep/staggered-withdrawal", {
                "avoirTotal": 300000,
                "nbComptes": 3,
                "canton": "VD",
                "revenuImposable": 120000,
                "ageRetraitDebut": 60,
                "ageRetraitFin": 64,
            }),
            ("/api/v1/3a-deep/real-return", {
                "versementAnnuel": 7000,
                "tauxMarginal": 0.30,
                "rendementBrut": 0.04,
                "fraisGestion": 0.005,
                "dureeAnnees": 30,
            }),
            ("/api/v1/3a-deep/compare-providers", {
                "age": 30,
                "versementAnnuel": 7000,
                "duree": 35,
                "profilRisque": "equilibre",
            }),
        ]

        for url, body in endpoints_and_bodies:
            response = client.post(url, json=body)
            data = response.json()
            all_text = self._collect_all_text(data).lower()
            for pattern in self.BANNED_PATTERNS:
                matches = re.findall(pattern, all_text, re.IGNORECASE)
                assert len(matches) == 0, (
                    f"Banned pattern '{pattern}' found in {url}: {matches}"
                )
