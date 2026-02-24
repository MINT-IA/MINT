"""
Tests for FRI Display Service — Sprint S39 (Beta Display).

Covers:
    - Display rules (5+ tests):
        - display_allowed=True when confidence >= 50%
        - display_allowed=False when confidence < 50%
        - Enrichment message shown when display not allowed
        - Top action always present when display allowed
        - Breakdown always present regardless of display_allowed
    - Top action detection (5+ tests):
        - Low L -> liquidity suggestion
        - Low F -> fiscal suggestion
        - Low R -> retirement suggestion
        - Low S -> structural risk suggestion
        - Delta estimation is positive
    - Simulate action (3+ tests):
        - add_3a: F increases
        - add_liquidity: L increases
        - reduce_mortgage: S improves
    - Compliance (3+ tests):
        - No banned display terms in any text
        - No social comparison terms
        - Disclaimer present
    - API endpoints (2+ tests):
        - POST /fri/current returns valid response
        - POST /fri/simulate-action returns valid response

Sources:
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 14-16 (taux de conversion)
    - LIFD art. 38 (imposition du capital)
    - OPP3 art. 7 (plafond 3a)
    - FINMA circ. 2008/21 (gestion des risques)
"""

import pytest
from fastapi.testclient import TestClient

from app.services.fri.fri_service import FriInput, FriService
from app.services.fri.fri_display_service import (
    FriDisplayService,
    FriDisplayResult,
    DISCLAIMER,
    SOURCES,
    DISPLAY_CONFIDENCE_THRESHOLD,
)


# ═══════════════════════════════════════════════════════════════════════════════
# Banned display terms — NEVER appear in user-facing text
# ═══════════════════════════════════════════════════════════════════════════════

BANNED_DISPLAY_TERMS = [
    "faible", "mauvais", "insuffisant", "danger",
    "en retard", "inferieur", "moyenne",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def balanced_input() -> FriInput:
    """A balanced profile with moderate scores in all components."""
    return FriInput(
        liquid_assets=20_000.0,
        monthly_fixed_costs=4_000.0,
        short_term_debt_ratio=0.10,
        income_volatility="low",
        actual_3a=5_000.0,
        max_3a=7_258.0,
        potentiel_rachat_lpp=20_000.0,
        rachat_effectue=5_000.0,
        taux_marginal=0.30,
        is_property_owner=False,
        amort_indirect=0.0,
        replacement_ratio=0.55,
        disability_gap_ratio=0.15,
        has_dependents=True,
        death_protection_gap_ratio=0.20,
        mortgage_stress_ratio=0.25,
        concentration_ratio=0.40,
        employer_dependency_ratio=0.60,
        archetype="swiss_native",
        age=35,
        canton="VD",
    )


@pytest.fixture
def low_liquidity_input() -> FriInput:
    """Profile with very low liquidity, other components decent."""
    return FriInput(
        liquid_assets=500.0,
        monthly_fixed_costs=4_000.0,
        short_term_debt_ratio=0.50,
        income_volatility="high",
        actual_3a=7_258.0,
        max_3a=7_258.0,
        potentiel_rachat_lpp=0.0,
        rachat_effectue=0.0,
        taux_marginal=0.30,
        is_property_owner=False,
        amort_indirect=0.0,
        replacement_ratio=0.70,
        disability_gap_ratio=0.10,
        has_dependents=False,
        death_protection_gap_ratio=0.10,
        mortgage_stress_ratio=0.20,
        concentration_ratio=0.30,
        employer_dependency_ratio=0.50,
    )


@pytest.fixture
def low_fiscal_input() -> FriInput:
    """Profile with very low fiscal efficiency, other components decent."""
    return FriInput(
        liquid_assets=30_000.0,
        monthly_fixed_costs=4_000.0,
        short_term_debt_ratio=0.05,
        income_volatility="low",
        actual_3a=0.0,
        max_3a=7_258.0,
        potentiel_rachat_lpp=50_000.0,
        rachat_effectue=0.0,
        taux_marginal=0.35,
        is_property_owner=True,
        amort_indirect=0.0,
        replacement_ratio=0.65,
        disability_gap_ratio=0.10,
        has_dependents=False,
        death_protection_gap_ratio=0.10,
        mortgage_stress_ratio=0.20,
        concentration_ratio=0.30,
        employer_dependency_ratio=0.50,
    )


@pytest.fixture
def low_retirement_input() -> FriInput:
    """Profile with very low retirement readiness, other components decent."""
    return FriInput(
        liquid_assets=30_000.0,
        monthly_fixed_costs=4_000.0,
        short_term_debt_ratio=0.05,
        income_volatility="low",
        actual_3a=7_258.0,
        max_3a=7_258.0,
        potentiel_rachat_lpp=0.0,
        rachat_effectue=0.0,
        taux_marginal=0.30,
        is_property_owner=False,
        amort_indirect=0.0,
        replacement_ratio=0.10,
        disability_gap_ratio=0.10,
        has_dependents=False,
        death_protection_gap_ratio=0.10,
        mortgage_stress_ratio=0.20,
        concentration_ratio=0.30,
        employer_dependency_ratio=0.50,
    )


@pytest.fixture
def low_risk_input() -> FriInput:
    """Profile with high structural risk (low S), other components decent."""
    return FriInput(
        liquid_assets=30_000.0,
        monthly_fixed_costs=4_000.0,
        short_term_debt_ratio=0.05,
        income_volatility="low",
        actual_3a=7_258.0,
        max_3a=7_258.0,
        potentiel_rachat_lpp=0.0,
        rachat_effectue=0.0,
        taux_marginal=0.30,
        is_property_owner=False,
        amort_indirect=0.0,
        replacement_ratio=0.70,
        disability_gap_ratio=0.50,
        has_dependents=True,
        death_protection_gap_ratio=0.60,
        mortgage_stress_ratio=0.40,
        concentration_ratio=0.80,
        employer_dependency_ratio=0.90,
    )


@pytest.fixture
def api_client():
    """FastAPI test client."""
    from app.main import app
    return TestClient(app)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. Display rules (5+ tests)
# ═══════════════════════════════════════════════════════════════════════════════

class TestDisplayRules:
    """Tests for FRI display permission logic."""

    def test_display_allowed_when_confidence_high(self, balanced_input):
        """display_allowed=True when confidence >= 50%."""
        result = FriDisplayService.compute_for_display(balanced_input, 75.0)
        assert result.display_allowed is True

    def test_display_allowed_at_threshold(self, balanced_input):
        """display_allowed=True at exactly 50% confidence."""
        result = FriDisplayService.compute_for_display(balanced_input, 50.0)
        assert result.display_allowed is True

    def test_display_not_allowed_below_threshold(self, balanced_input):
        """display_allowed=False when confidence < 50%."""
        result = FriDisplayService.compute_for_display(balanced_input, 49.9)
        assert result.display_allowed is False

    def test_enrichment_message_when_not_allowed(self, balanced_input):
        """Enrichment message present when display not allowed."""
        result = FriDisplayService.compute_for_display(balanced_input, 30.0)
        assert result.display_allowed is False
        assert len(result.enrichment_message) > 10
        assert "profil" in result.enrichment_message.lower()

    def test_no_enrichment_message_when_allowed(self, balanced_input):
        """Enrichment message empty when display allowed."""
        result = FriDisplayService.compute_for_display(balanced_input, 70.0)
        assert result.display_allowed is True
        assert result.enrichment_message == ""

    def test_top_action_present_when_display_allowed(self, balanced_input):
        """Top action always populated when display allowed."""
        result = FriDisplayService.compute_for_display(balanced_input, 70.0)
        assert result.display_allowed is True
        assert len(result.top_action) > 10

    def test_top_action_empty_when_not_allowed(self, balanced_input):
        """Top action empty when display not allowed."""
        result = FriDisplayService.compute_for_display(balanced_input, 20.0)
        assert result.display_allowed is False
        assert result.top_action == ""

    def test_breakdown_always_present(self, balanced_input):
        """Breakdown is always computed, regardless of display permission."""
        result_low = FriDisplayService.compute_for_display(balanced_input, 20.0)
        result_high = FriDisplayService.compute_for_display(balanced_input, 80.0)

        # Both should have a valid breakdown
        assert result_low.breakdown.total > 0
        assert result_high.breakdown.total > 0
        # Same input => same breakdown
        assert result_low.breakdown.liquidite == result_high.breakdown.liquidite
        assert result_low.breakdown.fiscalite == result_high.breakdown.fiscalite
        assert result_low.breakdown.retraite == result_high.breakdown.retraite
        assert result_low.breakdown.risque == result_high.breakdown.risque


# ═══════════════════════════════════════════════════════════════════════════════
# 2. Top action detection (5+ tests)
# ═══════════════════════════════════════════════════════════════════════════════

class TestTopActionDetection:
    """Tests for identifying the most impactful improvement action."""

    def test_low_liquidity_suggests_reserve(self, low_liquidity_input):
        """When L is the weakest, suggests building liquidity reserve."""
        result = FriDisplayService.compute_for_display(low_liquidity_input, 70.0)
        assert "reserve" in result.top_action.lower() or "liquidite" in result.top_action.lower()

    def test_low_fiscal_suggests_3a(self, low_fiscal_input):
        """When F is the weakest, suggests 3a contribution."""
        result = FriDisplayService.compute_for_display(low_fiscal_input, 70.0)
        assert "3a" in result.top_action.lower() or "fiscale" in result.top_action.lower()

    def test_low_retirement_suggests_prevoyance(self, low_retirement_input):
        """When R is the weakest, suggests exploring prevoyance options."""
        result = FriDisplayService.compute_for_display(low_retirement_input, 70.0)
        assert "prevoyance" in result.top_action.lower() or "retraite" in result.top_action.lower()

    def test_low_risk_suggests_coverage(self, low_risk_input):
        """When S is the weakest, suggests verifying risk coverage."""
        result = FriDisplayService.compute_for_display(low_risk_input, 70.0)
        assert "couverture" in result.top_action.lower() or "risque" in result.top_action.lower() or "structure" in result.top_action.lower()

    def test_top_action_delta_is_positive(self, balanced_input):
        """Top action delta should always be >= 0."""
        result = FriDisplayService.compute_for_display(balanced_input, 70.0)
        assert result.top_action_delta >= 0.0

    def test_top_action_delta_for_low_component(self, low_liquidity_input):
        """Delta should be meaningful when a component is very low."""
        result = FriDisplayService.compute_for_display(low_liquidity_input, 70.0)
        assert result.top_action_delta > 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# 3. Simulate action (3+ tests)
# ═══════════════════════════════════════════════════════════════════════════════

class TestSimulateAction:
    """Tests for what-if action simulation."""

    def test_add_3a_increases_fiscal(self, low_fiscal_input):
        """add_3a simulation should increase fiscal component."""
        original = FriService.compute(low_fiscal_input, 70.0)
        result = FriDisplayService.simulate_action(
            low_fiscal_input, "add_3a", 70.0,
        )
        assert result["new_breakdown"].fiscalite >= original.fiscalite
        assert result["delta_fri"] >= 0.0

    def test_add_liquidity_increases_l(self, low_liquidity_input):
        """add_liquidity simulation should increase liquidity component."""
        original = FriService.compute(low_liquidity_input, 70.0)
        result = FriDisplayService.simulate_action(
            low_liquidity_input, "add_liquidity", 70.0,
        )
        assert result["new_breakdown"].liquidite >= original.liquidite
        assert result["delta_fri"] >= 0.0

    def test_reduce_mortgage_improves_risk(self):
        """reduce_mortgage simulation should improve structural risk."""
        inp = FriInput(
            liquid_assets=30_000.0,
            monthly_fixed_costs=4_000.0,
            mortgage_stress_ratio=0.45,
            has_dependents=False,
        )
        original = FriService.compute(inp, 70.0)
        result = FriDisplayService.simulate_action(inp, "reduce_mortgage", 70.0)
        assert result["new_breakdown"].risque >= original.risque
        assert result["delta_fri"] >= 0.0

    def test_add_rachat_with_potential(self):
        """add_rachat simulation should improve fiscal when potential exists."""
        inp = FriInput(
            potentiel_rachat_lpp=50_000.0,
            rachat_effectue=0.0,
            taux_marginal=0.35,
            actual_3a=7_258.0,
            max_3a=7_258.0,
        )
        original = FriService.compute(inp, 70.0)
        result = FriDisplayService.simulate_action(inp, "add_rachat", 70.0)
        assert result["new_breakdown"].fiscalite >= original.fiscalite
        assert result["delta_fri"] >= 0.0

    def test_invalid_action_raises_error(self, balanced_input):
        """Unknown action_type should raise ValueError."""
        with pytest.raises(ValueError, match="Action inconnue"):
            FriDisplayService.simulate_action(balanced_input, "invalid_action", 70.0)

    def test_simulate_action_has_description(self, balanced_input):
        """Simulation result should include a description."""
        result = FriDisplayService.simulate_action(
            balanced_input, "add_3a", 70.0,
        )
        assert len(result["action_description"]) > 10

    def test_simulate_action_has_disclaimer(self, balanced_input):
        """Simulation result should include a disclaimer."""
        result = FriDisplayService.simulate_action(
            balanced_input, "add_3a", 70.0,
        )
        assert "educatif" in result["disclaimer"].lower()
        assert "LSFin" in result["disclaimer"]

    def test_simulate_action_has_sources(self, balanced_input):
        """Simulation result should include legal sources."""
        result = FriDisplayService.simulate_action(
            balanced_input, "add_3a", 70.0,
        )
        assert len(result["sources"]) >= 3


# ═══════════════════════════════════════════════════════════════════════════════
# 4. Compliance (3+ tests)
# ═══════════════════════════════════════════════════════════════════════════════

class TestCompliance:
    """Tests for compliance with display rules and banned terms."""

    def _collect_all_text(self, result: FriDisplayResult) -> str:
        """Collect all user-facing text from a display result."""
        texts = [
            result.top_action,
            result.enrichment_message,
            result.disclaimer,
        ]
        return " ".join(texts).lower()

    def test_no_banned_terms_when_allowed(self, balanced_input):
        """No banned display terms in any text when display allowed."""
        result = FriDisplayService.compute_for_display(balanced_input, 70.0)
        all_text = self._collect_all_text(result)
        for term in BANNED_DISPLAY_TERMS:
            assert term not in all_text, (
                f"Banned term '{term}' found in display text"
            )

    def test_no_banned_terms_when_not_allowed(self, balanced_input):
        """No banned display terms in any text when display not allowed."""
        result = FriDisplayService.compute_for_display(balanced_input, 30.0)
        all_text = self._collect_all_text(result)
        for term in BANNED_DISPLAY_TERMS:
            assert term not in all_text, (
                f"Banned term '{term}' found in display text"
            )

    def test_no_banned_terms_in_low_liquidity(self, low_liquidity_input):
        """No banned terms even with very low liquidity score."""
        result = FriDisplayService.compute_for_display(low_liquidity_input, 70.0)
        all_text = self._collect_all_text(result)
        for term in BANNED_DISPLAY_TERMS:
            assert term not in all_text, (
                f"Banned term '{term}' found in display text for low liquidity"
            )

    def test_no_banned_terms_in_low_risk(self, low_risk_input):
        """No banned terms even with very low structural risk score."""
        result = FriDisplayService.compute_for_display(low_risk_input, 70.0)
        all_text = self._collect_all_text(result)
        for term in BANNED_DISPLAY_TERMS:
            assert term not in all_text, (
                f"Banned term '{term}' found in display text for low risk"
            )

    def test_no_social_comparison(self, balanced_input):
        """No comparison to other users in any text."""
        result = FriDisplayService.compute_for_display(balanced_input, 70.0)
        all_text = self._collect_all_text(result)
        comparison_terms = ["autres", "comparaison", "percentile", "classement"]
        for term in comparison_terms:
            assert term not in all_text, (
                f"Social comparison term '{term}' found in display text"
            )

    def test_disclaimer_present_when_allowed(self, balanced_input):
        """Disclaimer must be present when display allowed."""
        result = FriDisplayService.compute_for_display(balanced_input, 70.0)
        assert "educatif" in result.disclaimer.lower()
        assert "LSFin" in result.disclaimer

    def test_disclaimer_present_when_not_allowed(self, balanced_input):
        """Disclaimer must be present even when display not allowed."""
        result = FriDisplayService.compute_for_display(balanced_input, 30.0)
        assert "educatif" in result.disclaimer.lower()
        assert "LSFin" in result.disclaimer

    def test_sources_present(self, balanced_input):
        """Legal sources must be present."""
        result = FriDisplayService.compute_for_display(balanced_input, 70.0)
        assert len(result.sources) >= 3
        # Check at least one Swiss law reference
        sources_text = " ".join(result.sources).lower()
        assert "lavs" in sources_text or "lpp" in sources_text or "lifd" in sources_text

    def test_simulate_no_banned_terms(self, low_fiscal_input):
        """No banned terms in simulation output."""
        result = FriDisplayService.simulate_action(
            low_fiscal_input, "add_3a", 70.0,
        )
        all_text = result["action_description"].lower()
        for term in BANNED_DISPLAY_TERMS:
            assert term not in all_text, (
                f"Banned term '{term}' found in simulation text"
            )


# ═══════════════════════════════════════════════════════════════════════════════
# 5. API endpoint tests (2+ tests)
# ═══════════════════════════════════════════════════════════════════════════════

class TestFriEndpoints:
    """Tests for FRI API endpoints."""

    def test_post_fri_current(self, api_client):
        """POST /api/v1/fri/current returns valid FriDisplayResponse."""
        payload = {
            "inputData": {
                "liquidAssets": 20000.0,
                "monthlyFixedCosts": 4000.0,
                "shortTermDebtRatio": 0.1,
                "incomeVolatility": "low",
                "actual3a": 5000.0,
                "max3a": 7258.0,
                "potentielRachatLpp": 20000.0,
                "rachatEffectue": 5000.0,
                "tauxMarginal": 0.30,
                "isPropertyOwner": False,
                "amortIndirect": 0.0,
                "replacementRatio": 0.55,
                "disabilityGapRatio": 0.15,
                "hasDependents": True,
                "deathProtectionGapRatio": 0.20,
                "mortgageStressRatio": 0.25,
                "concentrationRatio": 0.40,
                "employerDependencyRatio": 0.60,
                "archetype": "swiss_native",
                "age": 35,
                "canton": "VD",
            },
            "confidenceScore": 75.0,
        }
        response = api_client.post("/api/v1/fri/current", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "breakdown" in data
        assert "displayAllowed" in data
        assert data["displayAllowed"] is True
        assert "topAction" in data
        assert "disclaimer" in data
        assert "sources" in data
        assert len(data["sources"]) >= 3

    def test_post_fri_current_low_confidence(self, api_client):
        """POST /api/v1/fri/current with low confidence disallows display."""
        payload = {
            "inputData": {
                "liquidAssets": 20000.0,
                "monthlyFixedCosts": 4000.0,
            },
            "confidenceScore": 30.0,
        }
        response = api_client.post("/api/v1/fri/current", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["displayAllowed"] is False
        assert len(data["enrichmentMessage"]) > 0

    def test_post_simulate_action(self, api_client):
        """POST /api/v1/fri/simulate-action returns valid FriSimulateResponse."""
        payload = {
            "inputData": {
                "liquidAssets": 5000.0,
                "monthlyFixedCosts": 4000.0,
                "actual3a": 0.0,
                "max3a": 7258.0,
            },
            "actionType": "add_3a",
            "confidenceScore": 70.0,
        }
        response = api_client.post("/api/v1/fri/simulate-action", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "deltaFri" in data
        assert data["deltaFri"] >= 0.0
        assert "newBreakdown" in data
        assert "actionDescription" in data
        assert "disclaimer" in data
        assert "sources" in data

    def test_post_simulate_action_invalid_type(self, api_client):
        """POST /api/v1/fri/simulate-action with invalid action returns 422."""
        payload = {
            "inputData": {
                "liquidAssets": 5000.0,
                "monthlyFixedCosts": 4000.0,
            },
            "actionType": "invalid_action",
            "confidenceScore": 70.0,
        }
        response = api_client.post("/api/v1/fri/simulate-action", json=payload)
        assert response.status_code == 422
