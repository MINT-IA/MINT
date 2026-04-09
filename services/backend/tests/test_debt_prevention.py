"""
Tests for Debt Prevention module (Sprint S16).

Covers:
    - Debt ratio service — 8 tests
    - Repayment service — 8 tests
    - Resources service — 5 tests
    - API endpoints (integration) — 3 tests
    - Compliance (banned terms, disclaimer, premier_eclairage) — 4 tests

Target: 28 tests.

Run: cd services/backend && python3 -m pytest tests/test_debt_prevention.py -v
"""

import re
import pytest

from app.services.debt_prevention.debt_ratio_service import (
    DebtRatioService,
    DISCLAIMER as RATIO_DISCLAIMER,
    MINIMUM_VITAL,
)
from app.services.debt_prevention.repayment_service import (
    RepaymentService,
    DISCLAIMER as REPAYMENT_DISCLAIMER,
)
from app.services.debt_prevention.resources_service import (
    ResourcesService,
    DISCLAIMER as RESOURCES_DISCLAIMER,
    _CANTONAL_RESOURCES,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def ratio_service():
    return DebtRatioService()


@pytest.fixture
def repayment_service():
    return RepaymentService()


@pytest.fixture
def resources_service():
    return ResourcesService()


# ===========================================================================
# TestDebtRatio — Debt ratio service (8 tests)
# ===========================================================================

class TestDebtRatio:
    """Tests for the debt ratio calculator."""

    def test_green_ratio(self, ratio_service):
        """Ratio < 15% should be green."""
        result = ratio_service.calculate_debt_ratio(
            revenus_mensuels=6000,
            charges_dette_mensuelles=500,
            loyer=1500,
            autres_charges_fixes=300,
        )
        assert result.niveau_risque == "vert"
        assert result.ratio_pct < 15

    def test_orange_ratio(self, ratio_service):
        """Ratio 15-30% should be orange."""
        result = ratio_service.calculate_debt_ratio(
            revenus_mensuels=5000,
            charges_dette_mensuelles=1000,
            loyer=1500,
            autres_charges_fixes=200,
        )
        assert result.niveau_risque == "orange"
        assert 15 <= result.ratio_pct <= 30

    def test_red_ratio(self, ratio_service):
        """Ratio > 30% should be red."""
        result = ratio_service.calculate_debt_ratio(
            revenus_mensuels=4000,
            charges_dette_mensuelles=1500,
            loyer=1500,
            autres_charges_fixes=200,
        )
        assert result.niveau_risque == "rouge"
        assert result.ratio_pct > 30

    def test_minimum_vital_celibataire(self, ratio_service):
        """Minimum vital for single person should be correct."""
        result = ratio_service.calculate_debt_ratio(
            revenus_mensuels=3000,
            charges_dette_mensuelles=200,
            loyer=1200,
            autres_charges_fixes=100,
            situation_familiale="celibataire",
            nb_enfants=0,
        )
        # Minimum vital = 1200 (base) + 1200 (loyer) = 2400
        assert result.minimum_vital == 1200 + 1200

    def test_minimum_vital_couple_with_children(self, ratio_service):
        """Minimum vital for couple with children should include supplements."""
        result = ratio_service.calculate_debt_ratio(
            revenus_mensuels=6000,
            charges_dette_mensuelles=500,
            loyer=2000,
            autres_charges_fixes=300,
            situation_familiale="couple",
            nb_enfants=2,
        )
        # Minimum vital = 1750 (couple) + 2*400 (children) + 2000 (loyer) = 4550
        expected = MINIMUM_VITAL["couple"] + 2 * MINIMUM_VITAL["supplement_enfant"] + 2000
        assert result.minimum_vital == expected

    def test_below_minimum_vital_detected(self, ratio_service):
        """Should detect when person is below minimum vital."""
        result = ratio_service.calculate_debt_ratio(
            revenus_mensuels=2500,
            charges_dette_mensuelles=800,
            loyer=1200,
            autres_charges_fixes=300,
            situation_familiale="celibataire",
        )
        assert result.en_dessous_minimum_vital is True

    def test_zero_income_full_ratio(self, ratio_service):
        """Zero income with debts should give ratio 1.0."""
        result = ratio_service.calculate_debt_ratio(
            revenus_mensuels=0,
            charges_dette_mensuelles=500,
            loyer=0,
            autres_charges_fixes=0,
        )
        assert result.ratio_endettement == 1.0

    def test_no_debt_zero_ratio(self, ratio_service):
        """No debt should give ratio 0."""
        result = ratio_service.calculate_debt_ratio(
            revenus_mensuels=5000,
            charges_dette_mensuelles=0,
            loyer=1500,
            autres_charges_fixes=200,
        )
        assert result.ratio_endettement == 0.0
        assert result.niveau_risque == "vert"


# ===========================================================================
# TestRepayment — Repayment planner (8 tests)
# ===========================================================================

class TestRepayment:
    """Tests for the debt repayment planner."""

    SAMPLE_DEBTS = [
        {"nom": "Credit conso", "montant": 10000, "taux": 0.10, "mensualite_min": 200},
        {"nom": "Leasing auto", "montant": 15000, "taux": 0.05, "mensualite_min": 300},
        {"nom": "Carte credit", "montant": 3000, "taux": 0.15, "mensualite_min": 100},
    ]

    def test_avalanche_repayment(self, repayment_service):
        """Avalanche strategy should produce a valid plan."""
        result = repayment_service.plan_repayment(
            dettes=self.SAMPLE_DEBTS,
            budget_mensuel_remboursement=800,
            strategie="avalanche",
        )
        assert result.duree_mois > 0
        assert result.total_interets > 0
        assert result.strategie == "avalanche"

    def test_snowball_repayment(self, repayment_service):
        """Snowball strategy should produce a valid plan."""
        result = repayment_service.plan_repayment(
            dettes=self.SAMPLE_DEBTS,
            budget_mensuel_remboursement=800,
            strategie="boule_de_neige",
        )
        assert result.duree_mois > 0
        assert result.strategie == "boule_de_neige"

    def test_avalanche_saves_more_interest(self, repayment_service):
        """Avalanche should pay less total interest than snowball."""
        comparison = repayment_service.compare_strategies(
            dettes=self.SAMPLE_DEBTS,
            budget_mensuel_remboursement=800,
        )
        assert comparison.difference_interets >= 0
        assert comparison.avalanche.total_interets <= comparison.boule_de_neige.total_interets

    def test_snowball_pays_smallest_first(self, repayment_service):
        """Snowball should pay off the smallest debt first."""
        result = repayment_service.plan_repayment(
            dettes=self.SAMPLE_DEBTS,
            budget_mensuel_remboursement=800,
            strategie="boule_de_neige",
        )
        if len(result.payoffs) >= 2:
            # The smallest debt (Carte credit, 3000) should be paid off first
            first_payoff = result.payoffs[0]
            assert first_payoff.nom == "Carte credit"

    def test_all_debts_paid_off(self, repayment_service):
        """All debts should eventually be paid off."""
        result = repayment_service.plan_repayment(
            dettes=self.SAMPLE_DEBTS,
            budget_mensuel_remboursement=800,
            strategie="avalanche",
        )
        assert len(result.payoffs) == 3  # All 3 debts should be in payoffs

    def test_empty_debts(self, repayment_service):
        """Empty debt list should return zero result."""
        result = repayment_service.plan_repayment(
            dettes=[],
            budget_mensuel_remboursement=500,
        )
        assert result.duree_mois == 0
        assert result.total_interets == 0.0

    def test_single_debt(self, repayment_service):
        """Single debt should produce a simple plan."""
        result = repayment_service.plan_repayment(
            dettes=[{"nom": "Pret", "montant": 5000, "taux": 0.08, "mensualite_min": 200}],
            budget_mensuel_remboursement=500,
            strategie="avalanche",
        )
        assert result.duree_mois > 0
        assert result.nb_dettes == 1
        assert len(result.payoffs) == 1

    def test_comparison_premier_eclairage(self, repayment_service):
        """Comparison should include a premier_eclairage."""
        comparison = repayment_service.compare_strategies(
            dettes=self.SAMPLE_DEBTS,
            budget_mensuel_remboursement=800,
        )
        assert len(comparison.premier_eclairage) > 10
        assert "mois" in comparison.premier_eclairage.lower()


# ===========================================================================
# TestResources — Help resources service (5 tests)
# ===========================================================================

class TestResources:
    """Tests for the help resources service."""

    def test_six_cantons_have_resources(self, resources_service):
        """The 6 main cantons should have cantonal resources."""
        for canton in ["ZH", "BE", "VD", "GE", "LU", "BS"]:
            result = resources_service.get_help_resources(canton=canton)
            cantonals = [r for r in result.resources if r.canton == canton]
            assert len(cantonals) >= 1, f"No cantonal resource for {canton}"

    def test_all_26_cantons_covered(self, resources_service):
        """All 26 cantons should be in the cantonal resources dict."""
        assert len(_CANTONAL_RESOURCES) == 26

    def test_national_resources_always_included(self, resources_service):
        """National resources should always be included."""
        result = resources_service.get_help_resources(canton="ZH")
        national = [r for r in result.resources if r.canton is None]
        assert len(national) >= 2  # At least Dettes Conseils + Caritas

    def test_situation_specific_resource(self, resources_service):
        """Situation-specific resources should be included."""
        for situation in ["surendettement", "poursuites", "acte_defaut_biens", "prevention"]:
            result = resources_service.get_help_resources(
                canton="VD", situation=situation,
            )
            assert len(result.resources) >= 3
            assert result.situation == situation

    def test_all_resources_are_gratuit(self, resources_service):
        """All resources should be free."""
        result = resources_service.get_help_resources(canton="GE")
        for r in result.resources:
            assert r.gratuit is True


# ===========================================================================
# TestDebtPreventionEndpoints — API integration (3 tests)
# ===========================================================================

class TestDebtPreventionEndpoints:
    """Tests for the Debt Prevention FastAPI endpoints."""

    def test_debt_ratio_endpoint(self, client):
        """POST /debt/ratio should return 200."""
        response = client.post(
            "/api/v1/debt/ratio",
            json={
                "revenusMensuels": 6000,
                "chargesDetteMensuelles": 1200,
                "loyer": 1500,
                "autresChargesFixes": 300,
                "situationFamiliale": "celibataire",
                "nbEnfants": 0,
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "ratioEndettement" in data
        assert "niveauRisque" in data
        assert "premierEclairage" in data
        assert "disclaimer" in data
        assert "minimumVital" in data

    def test_repayment_plan_endpoint(self, client):
        """POST /debt/repayment-plan should return 200."""
        response = client.post(
            "/api/v1/debt/repayment-plan",
            json={
                "dettes": [
                    {"nom": "Credit", "montant": 10000, "taux": 0.10, "mensualiteMin": 200},
                    {"nom": "Leasing", "montant": 5000, "taux": 0.05, "mensualiteMin": 150},
                ],
                "budgetMensuelRemboursement": 600,
                "strategie": "avalanche",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["dureeMois"] > 0
        assert "premierEclairage" in data
        assert "disclaimer" in data
        assert len(data["payoffs"]) == 2

    def test_resources_endpoint(self, client):
        """GET /debt/resources/{canton} should return 200."""
        response = client.get(
            "/api/v1/debt/resources/VD?situation=surendettement",
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["resources"]) >= 3
        assert data["canton"] == "VD"
        assert "premierEclairage" in data
        assert "disclaimer" in data


# ===========================================================================
# TestDebtPreventionCompliance — Compliance checks (4 tests)
# ===========================================================================

class TestDebtPreventionCompliance:
    """Compliance checks for Debt Prevention."""

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
        all_disclaimers = RATIO_DISCLAIMER + REPAYMENT_DISCLAIMER + RESOURCES_DISCLAIMER
        for pattern in self.BANNED_PATTERNS:
            matches = re.findall(pattern, all_disclaimers, re.IGNORECASE)
            assert len(matches) == 0, (
                f"Banned pattern '{pattern}' found: {matches}"
            )

    def test_gender_neutral_disclaimers(self):
        """Disclaimers should use gender-neutral language."""
        for disclaimer in [RATIO_DISCLAIMER, REPAYMENT_DISCLAIMER, RESOURCES_DISCLAIMER]:
            assert "un ou une specialiste" in disclaimer.lower() or "un ou une" in disclaimer.lower(), (
                f"Disclaimer should use gender-neutral language: {disclaimer}"
            )

    def test_premier_eclairage_always_present(self, ratio_service, repayment_service, resources_service):
        """All service results should include a premier_eclairage."""
        r1 = ratio_service.calculate_debt_ratio(
            revenus_mensuels=5000,
            charges_dette_mensuelles=800,
            loyer=1500,
            autres_charges_fixes=200,
        )
        assert len(r1.premier_eclairage) > 10

        r2 = repayment_service.plan_repayment(
            dettes=[{"nom": "Test", "montant": 5000, "taux": 0.08, "mensualite_min": 200}],
            budget_mensuel_remboursement=500,
        )
        assert len(r2.premier_eclairage) > 10

        r3 = resources_service.get_help_resources(canton="VD")
        assert len(r3.premier_eclairage) > 10

    def test_no_banned_terms_in_api_responses(self, client):
        """No API response should contain banned terms."""
        response = client.post(
            "/api/v1/debt/ratio",
            json={
                "revenusMensuels": 6000,
                "chargesDetteMensuelles": 1200,
                "loyer": 1500,
            },
        )
        data = response.json()
        all_text = self._collect_all_text(data).lower()
        for pattern in self.BANNED_PATTERNS:
            matches = re.findall(pattern, all_text, re.IGNORECASE)
            assert len(matches) == 0, (
                f"Banned pattern '{pattern}' found in debt/ratio: {matches}"
            )

        response2 = client.get("/api/v1/debt/resources/VD")
        data2 = response2.json()
        all_text2 = self._collect_all_text(data2).lower()
        for pattern in self.BANNED_PATTERNS:
            matches = re.findall(pattern, all_text2, re.IGNORECASE)
            assert len(matches) == 0, (
                f"Banned pattern '{pattern}' found in debt/resources: {matches}"
            )
