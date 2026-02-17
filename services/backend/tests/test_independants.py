"""
Tests for the Independants module (Sprint S18).

Covers:
    - AVS cotisations service — 12 tests
    - IJM service — 11 tests
    - Pillar 3a independant service — 11 tests
    - Dividende vs Salaire service — 11 tests
    - LPP volontaire service — 11 tests
    - API endpoints (integration) — 5 tests
    - Compliance (banned terms, disclaimer, sources) — 5 tests

Target: 66 tests.

Run: cd services/backend && python3 -m pytest tests/test_independants.py -v
"""

import re

from app.services.independants.avs_cotisations_service import (
    calculer_cotisation_avs,
    AVS_BAREME,
    COTISATION_MINIMALE,
    DISCLAIMER as AVS_DISCLAIMER,
    SOURCES as AVS_SOURCES,
)
from app.services.independants.ijm_service import (
    simuler_ijm,
    DISCLAIMER as IJM_DISCLAIMER,
    SOURCES as IJM_SOURCES,
)
from app.services.independants.pillar_3a_indep_service import (
    calculer_3a_independant,
    PLAFOND_3A_AVEC_LPP,
    PLAFOND_3A_SANS_LPP_MAX,
    DISCLAIMER as P3A_DISCLAIMER,
    SOURCES as P3A_SOURCES,
)
from app.services.independants.dividende_vs_salaire_service import (
    simuler_dividende_vs_salaire,
    DISCLAIMER as DIV_DISCLAIMER,
    SOURCES as DIV_SOURCES,
)
from app.services.independants.lpp_volontaire_service import (
    simuler_lpp_volontaire,
    DEDUCTION_COORDINATION,
    SALAIRE_COORDONNE_MINIMUM,
    DISCLAIMER as LPP_DISCLAIMER,
    SOURCES as LPP_SOURCES,
)


# ===========================================================================
# TestAvsCotisations — AVS contribution calculator (12 tests)
# ===========================================================================

class TestAvsCotisations:
    """Tests for the AVS self-employed contribution calculator."""

    def test_zero_income_returns_zero(self):
        """Zero income should produce zero contribution."""
        result = calculer_cotisation_avs(0.0)
        assert result.cotisation_avs_ai_apg == 0.0
        assert result.taux_effectif == 0.0

    def test_negative_income_returns_zero(self):
        """Negative income should produce zero contribution."""
        result = calculer_cotisation_avs(-5000.0)
        assert result.cotisation_avs_ai_apg == 0.0

    def test_very_low_income_gets_minimum_contribution(self):
        """Income below first bracket should use minimum contribution."""
        result = calculer_cotisation_avs(5000.0)
        assert result.cotisation_avs_ai_apg == COTISATION_MINIMALE

    def test_income_at_first_bracket_boundary(self):
        """Income at the first bracket boundary (10'100) should use correct rate."""
        result = calculer_cotisation_avs(10_100.0)
        # At 10'100, we enter the second bracket (10'100 to 17'600)
        expected = round(10_100 * 0.05828, 2)
        assert result.cotisation_avs_ai_apg == expected

    def test_high_income_uses_full_rate(self):
        """Income >= 60'500 should use the full 10.6% rate."""
        result = calculer_cotisation_avs(100_000.0)
        expected = round(100_000 * 0.106, 2)
        assert result.cotisation_avs_ai_apg == expected
        assert abs(result.taux_effectif - 0.106) < 0.001

    def test_income_at_60500_boundary(self):
        """Income exactly at 60'500 should use full rate."""
        result = calculer_cotisation_avs(60_500.0)
        expected = round(60_500 * 0.106, 2)
        assert result.cotisation_avs_ai_apg == expected

    def test_bareme_progression_is_monotonic(self):
        """The AVS bareme rates should be monotonically increasing."""
        rates = [rate for _, _, rate in AVS_BAREME]
        for i in range(1, len(rates)):
            assert rates[i] >= rates[i - 1], (
                f"Rate at bracket {i} ({rates[i]}) is less than bracket {i-1} ({rates[i-1]})"
            )

    def test_bareme_brackets_are_contiguous(self):
        """The AVS bareme brackets should be contiguous (no gaps)."""
        for i in range(1, len(AVS_BAREME)):
            prev_upper = AVS_BAREME[i - 1][1]
            curr_lower = AVS_BAREME[i][0]
            assert prev_upper == curr_lower, (
                f"Gap between bracket {i-1} upper ({prev_upper}) and "
                f"bracket {i} lower ({curr_lower})"
            )

    def test_comparaison_salarie_is_lower(self):
        """Employee contribution should be lower than self-employed."""
        result = calculer_cotisation_avs(80_000.0)
        assert result.comparaison_salarie < result.cotisation_avs_ai_apg
        assert result.difference_vs_salarie > 0

    def test_difference_equals_cotisation_minus_salarie(self):
        """Difference should equal self-employed minus employee contribution."""
        result = calculer_cotisation_avs(120_000.0)
        expected_diff = round(result.cotisation_avs_ai_apg - result.comparaison_salarie, 2)
        assert abs(result.difference_vs_salarie - expected_diff) < 0.01

    def test_chiffre_choc_present(self):
        """Chiffre choc should be a non-empty string."""
        result = calculer_cotisation_avs(80_000.0)
        assert len(result.chiffre_choc) > 20
        assert "CHF" in result.chiffre_choc

    def test_middle_bracket_income(self):
        """Income in the middle bracket should use correct rate."""
        # 37'800 to 43'200: rate 0.09002
        result = calculer_cotisation_avs(40_000.0)
        expected = round(40_000 * 0.09002, 2)
        assert result.cotisation_avs_ai_apg == expected


# ===========================================================================
# TestIjm — IJM (income loss insurance) simulator (11 tests)
# ===========================================================================

class TestIjm:
    """Tests for the IJM simulator."""

    def test_zero_income_returns_zero(self):
        """Zero income should produce zero premium."""
        result = simuler_ijm(0.0, 35, 30)
        assert result.prime_mensuelle == 0.0
        assert result.prime_annuelle == 0.0
        assert result.indemnite_journaliere == 0.0

    def test_basic_simulation_30_days(self):
        """Basic simulation with 30-day waiting period."""
        result = simuler_ijm(8000.0, 35, 30)
        assert result.indemnite_journaliere > 0
        assert result.prime_mensuelle > 0
        assert result.prime_annuelle == round(result.prime_mensuelle * 12, 2)

    def test_indemnite_is_80_percent_of_daily(self):
        """Daily allowance should be 80% of daily income."""
        revenu_mensuel = 10_000.0
        result = simuler_ijm(revenu_mensuel, 30, 30)
        revenu_journalier = revenu_mensuel / 21.75
        expected = round(revenu_journalier * 0.80, 2)
        assert abs(result.indemnite_journaliere - expected) < 0.01

    def test_cost_without_coverage_equals_daily_times_waiting(self):
        """Cost without coverage should be daily income * waiting period."""
        revenu_mensuel = 8000.0
        delai = 60
        result = simuler_ijm(revenu_mensuel, 35, delai)
        revenu_journalier = revenu_mensuel / 21.75
        expected = round(revenu_journalier * delai, 2)
        assert abs(result.cout_sans_couverture - expected) < 0.01

    def test_longer_waiting_period_lower_premium(self):
        """Longer waiting period should produce lower premium."""
        result_30 = simuler_ijm(8000.0, 35, 30)
        result_60 = simuler_ijm(8000.0, 35, 60)
        result_90 = simuler_ijm(8000.0, 35, 90)
        assert result_30.prime_mensuelle > result_60.prime_mensuelle
        assert result_60.prime_mensuelle > result_90.prime_mensuelle

    def test_older_age_higher_premium(self):
        """Older age should produce higher premium."""
        result_25 = simuler_ijm(8000.0, 25, 30)
        result_45 = simuler_ijm(8000.0, 45, 30)
        result_60 = simuler_ijm(8000.0, 60, 30)
        assert result_25.prime_mensuelle < result_45.prime_mensuelle
        assert result_45.prime_mensuelle < result_60.prime_mensuelle

    def test_age_above_65_alert(self):
        """Age above 65 should trigger an alert (outside known bands)."""
        result = simuler_ijm(8000.0, 67, 30)
        assert any("dehors" in a.lower() or "impossible" in a.lower() for a in result.alertes)

    def test_invalid_waiting_period_defaults_to_30(self):
        """Invalid waiting period should default to 30 and produce alert."""
        result = simuler_ijm(8000.0, 35, 45)
        assert any("invalide" in a.lower() or "defaut" in a.lower() for a in result.alertes)

    def test_chiffre_choc_contains_amount(self):
        """Chiffre choc should mention the cost without coverage."""
        result = simuler_ijm(8000.0, 35, 60)
        assert "CHF" in result.chiffre_choc
        assert "delai de carence" in result.chiffre_choc

    def test_high_age_premium_alert(self):
        """Age >= 51 should trigger a premium warning."""
        result = simuler_ijm(8000.0, 55, 30)
        assert any("prime" in a.lower() or "elevee" in a.lower() for a in result.alertes)

    def test_all_age_bands_covered(self):
        """All age bands should produce non-zero premiums."""
        ages = [20, 35, 45, 55, 63]
        for age in ages:
            result = simuler_ijm(8000.0, age, 30)
            assert result.prime_mensuelle > 0, f"Zero premium for age {age}"


# ===========================================================================
# TestPillar3aIndep — Enhanced 3a for self-employed (11 tests)
# ===========================================================================

class TestPillar3aIndep:
    """Tests for the 3a enhanced calculator."""

    def test_zero_income_returns_zero(self):
        """Zero income should produce zero plafond."""
        result = calculer_3a_independant(0.0, False, 0.30)
        assert result.plafond_applicable == 0.0
        assert result.economie_fiscale == 0.0

    def test_without_lpp_uses_grand_3a(self):
        """Without LPP, should use the grand 3a limit (20%, max 36'288)."""
        result = calculer_3a_independant(100_000.0, False, 0.30)
        expected = min(100_000 * 0.20, PLAFOND_3A_SANS_LPP_MAX)
        assert result.plafond_applicable == expected

    def test_with_lpp_uses_small_limit(self):
        """With LPP, should use the small 3a limit (7'258)."""
        result = calculer_3a_independant(100_000.0, True, 0.30)
        assert result.plafond_applicable == PLAFOND_3A_AVEC_LPP

    def test_grand_3a_capped_at_36288(self):
        """Grand 3a should be capped at 36'288 CHF."""
        result = calculer_3a_independant(300_000.0, False, 0.30)
        assert result.plafond_applicable == PLAFOND_3A_SANS_LPP_MAX

    def test_grand_3a_20_percent_rule(self):
        """For income where 20% < 36'288, limit should be 20% of income."""
        # 20% of 80'000 = 16'000, which is < 36'288
        result = calculer_3a_independant(80_000.0, False, 0.30)
        assert result.plafond_applicable == round(80_000 * 0.20, 2)

    def test_economie_fiscale_equals_plafond_times_taux(self):
        """Tax savings should equal plafond * marginal rate."""
        result = calculer_3a_independant(100_000.0, False, 0.35)
        expected = round(result.plafond_applicable * 0.35, 2)
        assert abs(result.economie_fiscale - expected) < 0.01

    def test_comparaison_salarie_uses_small_limit(self):
        """Employee comparison should always use the small limit."""
        result = calculer_3a_independant(100_000.0, False, 0.30)
        expected = round(PLAFOND_3A_AVEC_LPP * 0.30, 2)
        assert abs(result.comparaison_salarie - expected) < 0.01

    def test_avantage_independant_positive_without_lpp(self):
        """Advantage should be positive when without LPP."""
        result = calculer_3a_independant(100_000.0, False, 0.30)
        assert result.avantage_independant > 0

    def test_avantage_independant_zero_with_lpp(self):
        """Advantage should be zero when with LPP."""
        result = calculer_3a_independant(100_000.0, True, 0.30)
        assert result.avantage_independant == 0.0

    def test_chiffre_choc_mentions_grand_3a(self):
        """Chiffre choc should mention the advantage for self-employed without LPP."""
        result = calculer_3a_independant(100_000.0, False, 0.30)
        assert "independant" in result.chiffre_choc.lower()

    def test_taux_marginal_clamped(self):
        """Marginal rate should be clamped to [0, 1]."""
        result_high = calculer_3a_independant(100_000.0, False, 1.5)
        result_low = calculer_3a_independant(100_000.0, False, -0.5)
        # Should not crash, and values should be reasonable
        assert result_high.economie_fiscale >= 0
        assert result_low.economie_fiscale == 0.0


# ===========================================================================
# TestDividendeVsSalaire — Dividend vs Salary optimizer (11 tests)
# ===========================================================================

class TestDividendeVsSalaire:
    """Tests for the dividend vs salary optimizer."""

    def test_zero_benefice_returns_zero(self):
        """Zero profit should produce zero charges."""
        result = simuler_dividende_vs_salaire(0.0, 0.5, 0.30)
        assert result.charge_totale_salaire == 0.0
        assert result.economies == 0.0

    def test_100_pct_salary_charges(self):
        """100% salary should have both social charges and income tax."""
        result = simuler_dividende_vs_salaire(200_000.0, 1.0, 0.35)
        # Charges: 200k * 12.5% + 200k * 35% = 25k + 70k = 95k
        expected = round(200_000 * 0.125 + 200_000 * 0.35, 2)
        assert abs(result.charge_totale_salaire - expected) < 0.01

    def test_100_pct_dividend_no_social_charges(self):
        """100% dividend should have no social charges, only partial tax."""
        result = simuler_dividende_vs_salaire(200_000.0, 0.0, 0.35)
        # Charges: 0% social + 200k * 50% * 35% = 35k
        expected = round(200_000 * 0.50 * 0.35, 2)
        assert abs(result.charge_totale_tout_dividende - expected) < 0.01

    def test_dividend_cheaper_than_salary(self):
        """100% dividend should have lower total charge than 100% salary."""
        result = simuler_dividende_vs_salaire(200_000.0, 0.5, 0.35)
        assert result.charge_totale_tout_dividende < result.charge_totale_salaire

    def test_economies_positive(self):
        """Economies (savings vs all-salary) should be positive."""
        result = simuler_dividende_vs_salaire(200_000.0, 0.5, 0.35)
        assert result.economies > 0

    def test_requalification_alert_low_salary(self):
        """Low salary proportion should trigger requalification alert."""
        result = simuler_dividende_vs_salaire(200_000.0, 0.10, 0.35)
        assert result.alerte_requalification is True

    def test_requalification_alert_high_salary(self):
        """High salary proportion should not trigger requalification alert."""
        result = simuler_dividende_vs_salaire(200_000.0, 0.80, 0.35)
        assert result.alerte_requalification is False

    def test_requalification_alert_salary_below_minimum(self):
        """Salary below 60'000 CHF should trigger requalification alert."""
        # 100k * 0.50 = 50k < 60k threshold
        result = simuler_dividende_vs_salaire(100_000.0, 0.50, 0.35)
        assert result.alerte_requalification is True

    def test_graphe_data_has_11_points(self):
        """Sensitivity curve should have 11 points (0% to 100% in 10% steps)."""
        result = simuler_dividende_vs_salaire(200_000.0, 0.5, 0.35)
        assert len(result.graphe_data) == 11

    def test_graphe_data_first_and_last(self):
        """First point should be 0% salary, last should be 100% salary."""
        result = simuler_dividende_vs_salaire(200_000.0, 0.5, 0.35)
        assert result.graphe_data[0].split_salaire == 0.0
        assert result.graphe_data[-1].split_salaire == 1.0

    def test_split_optimal_between_0_and_1(self):
        """Optimal split should be between 0 and 1."""
        result = simuler_dividende_vs_salaire(200_000.0, 0.5, 0.35)
        assert 0.0 <= result.split_optimal_indicatif <= 1.0


# ===========================================================================
# TestLppVolontaire — Voluntary LPP simulator (11 tests)
# ===========================================================================

class TestLppVolontaire:
    """Tests for the voluntary LPP simulator."""

    def test_zero_income_returns_zero(self):
        """Zero income should produce zero contribution."""
        result = simuler_lpp_volontaire(0.0, 35, 0.30)
        assert result.cotisation_annuelle == 0.0
        assert result.economie_fiscale == 0.0

    def test_age_below_25_returns_zero(self):
        """Age below 25 should produce zero (LPP starts at 25)."""
        result = simuler_lpp_volontaire(80_000.0, 22, 0.30)
        assert result.cotisation_annuelle == 0.0

    def test_age_above_65_returns_zero(self):
        """Age above 65 should produce zero."""
        result = simuler_lpp_volontaire(80_000.0, 67, 0.30)
        assert result.cotisation_annuelle == 0.0

    def test_salaire_coordonne_basic(self):
        """Coordinated salary should be income minus coordination deduction."""
        result = simuler_lpp_volontaire(80_000.0, 35, 0.30)
        expected = 80_000 - DEDUCTION_COORDINATION
        assert result.salaire_coordonne == expected

    def test_salaire_coordonne_minimum(self):
        """Low income should use minimum coordinated salary."""
        result = simuler_lpp_volontaire(28_000.0, 35, 0.30)
        assert result.salaire_coordonne == SALAIRE_COORDONNE_MINIMUM

    def test_age_bracket_25_34(self):
        """Age 25-34 should use 7% contribution rate."""
        result = simuler_lpp_volontaire(80_000.0, 30, 0.30)
        assert result.taux_bonification == 0.07

    def test_age_bracket_35_44(self):
        """Age 35-44 should use 10% contribution rate."""
        result = simuler_lpp_volontaire(80_000.0, 40, 0.30)
        assert result.taux_bonification == 0.10

    def test_age_bracket_45_54(self):
        """Age 45-54 should use 15% contribution rate."""
        result = simuler_lpp_volontaire(80_000.0, 50, 0.30)
        assert result.taux_bonification == 0.15

    def test_age_bracket_55_65(self):
        """Age 55-65 should use 18% contribution rate."""
        result = simuler_lpp_volontaire(80_000.0, 60, 0.30)
        assert result.taux_bonification == 0.18

    def test_economie_fiscale_equals_cotisation_times_taux(self):
        """Tax savings should equal contribution * marginal rate."""
        result = simuler_lpp_volontaire(100_000.0, 40, 0.35)
        expected = round(result.cotisation_annuelle * 0.35, 2)
        assert abs(result.economie_fiscale - expected) < 0.01

    def test_comparaison_sans_lpp_positive(self):
        """Capital lost without LPP should be positive for working age."""
        result = simuler_lpp_volontaire(100_000.0, 35, 0.30)
        assert result.comparaison_sans_lpp > 0


# ===========================================================================
# TestIndependantsEndpoints — API integration (5 tests)
# ===========================================================================

class TestIndependantsEndpoints:
    """Tests for the Independants FastAPI endpoints."""

    def test_avs_cotisations_endpoint(self, client):
        """POST /independants/avs-cotisations should return 200."""
        response = client.post(
            "/api/v1/independants/avs-cotisations",
            json={"revenuNetActivite": 80000},
        )
        assert response.status_code == 200
        data = response.json()
        assert "cotisationAvsAiApg" in data
        assert "disclaimer" in data
        assert "sources" in data
        assert data["cotisationAvsAiApg"] > 0

    def test_ijm_simulation_endpoint(self, client):
        """POST /independants/ijm-simulation should return 200."""
        response = client.post(
            "/api/v1/independants/ijm-simulation",
            json={"revenuMensuel": 8000, "age": 35, "delaiCarence": 30},
        )
        assert response.status_code == 200
        data = response.json()
        assert "indemniteJournaliere" in data
        assert "primeMensuelle" in data
        assert "disclaimer" in data

    def test_3a_independant_endpoint(self, client):
        """POST /independants/3a-independant should return 200."""
        response = client.post(
            "/api/v1/independants/3a-independant",
            json={
                "revenuNet": 100000,
                "affilieLpp": False,
                "tauxMarginalImposition": 0.30,
                "canton": "VD",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "plafondApplicable" in data
        assert data["plafondApplicable"] == min(100000 * 0.20, 36288)
        assert "disclaimer" in data

    def test_dividende_vs_salaire_endpoint(self, client):
        """POST /independants/dividende-vs-salaire should return 200."""
        response = client.post(
            "/api/v1/independants/dividende-vs-salaire",
            json={
                "beneficeDisponible": 200000,
                "partSalaire": 0.6,
                "tauxMarginal": 0.35,
                "canton": "ZH",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "chargeTotaleSalaire" in data
        assert "grapheData" in data
        assert len(data["grapheData"]) == 11
        assert "disclaimer" in data

    def test_lpp_volontaire_endpoint(self, client):
        """POST /independants/lpp-volontaire should return 200."""
        response = client.post(
            "/api/v1/independants/lpp-volontaire",
            json={
                "revenuNet": 100000,
                "age": 40,
                "tauxMarginal": 0.30,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "salaireCoordonne" in data
        assert "cotisationAnnuelle" in data
        assert "disclaimer" in data


# ===========================================================================
# TestIndependantsCompliance — Compliance checks (5 tests)
# ===========================================================================

class TestIndependantsCompliance:
    """Tests for compliance rules: banned terms, disclaimers, sources, language."""

    BANNED_PATTERNS = [
        r"\bgaranti[es]?\b",
        r"\bcertaine?s?\b",
        r"\best\s+assure[es]?\b",
        r"\bsont\s+assure[es]?\b",
        r"\bsans\s+risque\b",
    ]

    ALL_DISCLAIMERS = [
        AVS_DISCLAIMER,
        IJM_DISCLAIMER,
        P3A_DISCLAIMER,
        DIV_DISCLAIMER,
        LPP_DISCLAIMER,
    ]

    ALL_SOURCES = [
        AVS_SOURCES,
        IJM_SOURCES,
        P3A_SOURCES,
        DIV_SOURCES,
        LPP_SOURCES,
    ]

    def test_all_disclaimers_contain_educatif(self):
        """All disclaimers should contain 'educatif'."""
        for disclaimer in self.ALL_DISCLAIMERS:
            assert "educatif" in disclaimer.lower(), (
                f"Disclaimer missing 'educatif': {disclaimer[:50]}"
            )

    def test_all_disclaimers_contain_lsfin(self):
        """All disclaimers should reference LSFin."""
        for disclaimer in self.ALL_DISCLAIMERS:
            assert "LSFin" in disclaimer, (
                f"Disclaimer missing 'LSFin': {disclaimer[:50]}"
            )

    def test_all_disclaimers_use_specialiste(self):
        """All disclaimers should use 'specialiste' (not 'conseiller')."""
        for disclaimer in self.ALL_DISCLAIMERS:
            assert "specialiste" in disclaimer.lower(), (
                f"Disclaimer missing 'specialiste': {disclaimer[:50]}"
            )
            assert "conseiller" not in disclaimer.lower(), (
                f"Disclaimer uses banned 'conseiller': {disclaimer[:50]}"
            )

    def test_no_banned_terms_in_disclaimers(self):
        """Disclaimers should not contain banned terms."""
        all_text = " ".join(self.ALL_DISCLAIMERS)
        for pattern in self.BANNED_PATTERNS:
            matches = re.findall(pattern, all_text, re.IGNORECASE)
            assert len(matches) == 0, (
                f"Banned pattern '{pattern}' found in disclaimers: {matches}"
            )

    def test_all_sources_non_empty(self):
        """All source lists should be non-empty."""
        for sources in self.ALL_SOURCES:
            assert len(sources) >= 2, (
                f"Source list should have at least 2 entries: {sources}"
            )
