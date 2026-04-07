"""
Tests for PremierEclairageSelector V2 — Sprint S57: intention × lifecycle × confidence.

28 tests across 7 groups:
    - TestCriticalAlerts (3): archetype overrides still top priority
    - TestStressAligned (5): stressType influences selection
    - TestLifecycleAware (5): age-driven fallback selection
    - TestConfidenceGating (4): estimated data → pedagogical mode
    - TestPriorityOrdering (4): correct priority with V2 logic
    - TestCompliance (5): banned terms, disclaimer, sources, text format
    - TestEndToEnd (2): full pipeline tests

Sources:
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 15-16 (bonifications vieillesse)
    - LIFD art. 38 (imposition du capital)
    - OPP3 art. 7 (plafond 3a)
"""

import pytest

from app.services.onboarding.premier_eclairage_selector import select_premier_eclairage
from app.services.onboarding.minimal_profile_service import compute_minimal_profile
from app.services.onboarding.onboarding_models import (
    MinimalProfileInput,
    MinimalProfileResult,
    PremierEclairage,
)


# Banned terms that must NEVER appear in user-facing text
BANNED_TERMS = [
    "garanti", "certain", "assuré", "sans risque",
    "optimal", "meilleur", "parfait",
    "conseiller", "tu devrais", "tu dois",
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_profile(**overrides) -> MinimalProfileResult:
    """Create a MinimalProfileResult with sensible defaults, overriding as needed."""
    defaults = dict(
        projected_avs_monthly=2000.0,
        projected_lpp_capital=300_000.0,
        projected_lpp_monthly=1_700.0,
        estimated_replacement_ratio=0.60,
        estimated_monthly_retirement=3_700.0,
        estimated_monthly_expenses=5_800.0,
        retirement_gap_monthly=4_633.33,
        tax_saving_3a=1_800.0,
        existing_3a=0.0,
        marginal_tax_rate=0.25,
        months_liquidity=5.0,
        monthly_debt_impact=0.0,
        confidence_score=30.0,
        estimated_fields=["household_type", "current_savings", "is_property_owner",
                          "existing_3a", "existing_lpp"],
        archetype="swiss_native",
        disclaimer="Outil educatif simplifie. Ne constitue pas un conseil financier (LSFin).",
        sources=["LAVS art. 21-29", "LPP art. 15-16"],
        enrichment_prompts=[],
        age=45,  # Default age where retirement gap is relevant
        gross_annual_salary=100_000.0,  # Required for hourly_rate and stress guards
    )
    defaults.update(overrides)
    return MinimalProfileResult(**defaults)


# ===========================================================================
# TestCriticalAlerts — 3 tests (unchanged behavior)
# ===========================================================================

class TestCriticalAlerts:
    """Critical alerts should still override everything."""

    def test_liquidity_crisis_real_savings_still_triggers(self):
        """Liquidity < 2 months with REAL savings data triggers alert."""
        profile = _make_profile(
            months_liquidity=0.8,
            estimated_fields=[],  # No fields estimated — real data
            age=45,
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "liquidity"

    def test_liquidity_estimated_but_severe_still_triggers(self):
        """Liquidity < 1 month triggers even with estimated savings."""
        profile = _make_profile(
            months_liquidity=0.5,
            estimated_fields=["current_savings", "existing_lpp"],
            age=30,
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "liquidity"

    def test_liquidity_estimated_mild_skipped(self):
        """Liquidity 1.2 months with estimated savings → skipped (not false alarm)."""
        profile = _make_profile(
            months_liquidity=1.2,
            estimated_fields=["current_savings", "existing_lpp"],
            estimated_replacement_ratio=0.60,
            age=30,
        )
        choc = select_premier_eclairage(profile)
        # Should NOT be liquidity — savings are estimated, not severe
        assert choc.category != "liquidity"


# ===========================================================================
# TestStressAligned — 5 tests (NEW)
# ===========================================================================

class TestStressAligned:
    """stressType should influence selection when data supports it."""

    def test_stress_budget_shows_hourly_rate(self):
        """stress_budget → hourly rate (pure math from salary)."""
        profile = _make_profile(
            age=25,
            estimated_replacement_ratio=0.65,
            months_liquidity=6.0,
        )
        choc = select_premier_eclairage(profile, stress_type="stress_budget")
        assert choc.category == "hourly_rate"
        assert choc.confidence_mode == "factual"

    def test_stress_impots_shows_tax_saving(self):
        """stress_impots → tax saving 3a."""
        profile = _make_profile(
            age=30,
            tax_saving_3a=2_000.0,
            estimated_replacement_ratio=0.65,
            months_liquidity=6.0,
        )
        choc = select_premier_eclairage(profile, stress_type="stress_impots")
        assert choc.category == "tax_saving"

    def test_stress_retraite_low_ratio_shows_gap(self):
        """stress_retraite with low ratio → retirement gap."""
        profile = _make_profile(
            age=45,
            estimated_replacement_ratio=0.50,
            months_liquidity=6.0,
        )
        choc = select_premier_eclairage(profile, stress_type="stress_retraite")
        assert choc.category == "retirement_gap"

    def test_stress_retraite_ok_ratio_shows_income(self):
        """stress_retraite with OK ratio → retirement income (not gap)."""
        profile = _make_profile(
            age=45,
            estimated_replacement_ratio=0.65,
            months_liquidity=6.0,
        )
        choc = select_premier_eclairage(profile, stress_type="stress_retraite")
        # Aligned with Flutter: OK ratio → retirement_income, not retirement_gap
        assert choc.category == "retirement_income"

    def test_stress_general_falls_through(self):
        """stress_general → no stress influence, uses lifecycle."""
        profile = _make_profile(
            age=22,
            estimated_replacement_ratio=0.65,
            months_liquidity=6.0,
            existing_3a=5_000.0,  # Has 3a, so universal tax_saving skipped
            tax_saving_3a=500.0,
        )
        choc = select_premier_eclairage(profile, stress_type="stress_general")
        assert choc.category == "compound_growth"

    def test_no_stress_type_uses_lifecycle(self):
        """No stress_type → same as stress_general."""
        profile = _make_profile(
            age=22,
            estimated_replacement_ratio=0.65,
            months_liquidity=6.0,
            existing_3a=5_000.0,  # Has 3a, so universal tax_saving skipped
            tax_saving_3a=500.0,
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "compound_growth"


# ===========================================================================
# TestLifecycleAware — 5 tests (NEW)
# ===========================================================================

class TestLifecycleAware:
    """Lifecycle-aware fallback adapts to user's age."""

    def test_young_user_gets_compound_growth(self):
        """Age < 28 → compound growth (not retirement gap)."""
        profile = _make_profile(
            age=22,
            estimated_replacement_ratio=0.65,
            months_liquidity=6.0,
            existing_3a=5_000.0,  # Has 3a, so tax saving not triggered
            tax_saving_3a=500.0,
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "compound_growth"
        assert choc.confidence_mode == "factual"  # Pure math

    def test_construction_age_gets_tax_saving_if_applicable(self):
        """Age 28-37 with no 3a + significant saving → tax saving."""
        profile = _make_profile(
            age=32,
            existing_3a=0.0,
            tax_saving_3a=2_000.0,
            estimated_replacement_ratio=0.65,
            months_liquidity=6.0,
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "tax_saving"

    def test_construction_age_without_3a_opportunity_gets_compound(self):
        """Age 28-37 with existing 3a → compound growth."""
        profile = _make_profile(
            age=32,
            existing_3a=8_000.0,
            tax_saving_3a=2_000.0,
            estimated_replacement_ratio=0.65,
            months_liquidity=6.0,
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "compound_growth"

    def test_midcareer_gets_retirement_gap(self):
        """Age 38+ with low replacement → retirement gap."""
        profile = _make_profile(
            age=49,
            estimated_replacement_ratio=0.50,
            months_liquidity=6.0,
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "retirement_gap"

    def test_retirement_gap_under_30_skipped_to_lifecycle(self):
        """Age < 30 with low ratio → does NOT show retirement gap, uses lifecycle."""
        profile = _make_profile(
            age=25,
            estimated_replacement_ratio=0.40,
            months_liquidity=6.0,
            existing_3a=5_000.0,
            tax_saving_3a=500.0,
        )
        choc = select_premier_eclairage(profile)
        # Should NOT be retirement_gap — too young
        assert choc.category == "compound_growth"


# ===========================================================================
# TestConfidenceGating — 4 tests (NEW)
# ===========================================================================

class TestConfidenceGating:
    """Confidence gating: estimated data → pedagogical mode."""

    def test_retirement_gap_with_estimated_lpp_is_pedagogical(self):
        """Retirement gap when LPP is estimated → pedagogical."""
        profile = _make_profile(
            age=49,
            estimated_replacement_ratio=0.45,
            months_liquidity=6.0,
            estimated_fields=["existing_lpp", "current_savings"],
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "retirement_gap"
        assert choc.confidence_mode == "pedagogical"

    def test_retirement_gap_with_real_lpp_is_factual(self):
        """Retirement gap when LPP is provided → factual."""
        profile = _make_profile(
            age=49,
            estimated_replacement_ratio=0.45,
            months_liquidity=6.0,
            estimated_fields=[],  # All data provided
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "retirement_gap"
        assert choc.confidence_mode == "factual"

    def test_compound_growth_always_factual(self):
        """Compound growth is pure math → always factual."""
        profile = _make_profile(
            age=22,
            estimated_replacement_ratio=0.65,
            months_liquidity=6.0,
            existing_3a=5_000.0,
            tax_saving_3a=500.0,
            estimated_fields=["existing_lpp", "current_savings", "existing_3a"],
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "compound_growth"
        assert choc.confidence_mode == "factual"

    def test_tax_saving_always_factual(self):
        """Tax saving derived from salary + canton (both provided) → factual."""
        profile = _make_profile(
            age=32,
            existing_3a=0.0,
            tax_saving_3a=2_000.0,
            estimated_replacement_ratio=0.65,
            months_liquidity=6.0,
            estimated_fields=["existing_lpp", "current_savings"],
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "tax_saving"
        assert choc.confidence_mode == "factual"


# ===========================================================================
# TestPriorityOrdering — 4 tests (updated for V2)
# ===========================================================================

class TestPriorityOrdering:
    """Test that V2 priority ordering works correctly."""

    def test_critical_liquidity_beats_stress_aligned(self):
        """Severe liquidity (real data) beats stress-aligned selection."""
        profile = _make_profile(
            months_liquidity=0.5,
            estimated_fields=[],  # Real data
            age=30,
        )
        choc = select_premier_eclairage(profile, stress_type="stress_impots")
        assert choc.category == "liquidity"

    def test_stress_beats_lifecycle_when_data_supports(self):
        """stress_budget at age 22 → hourly_rate (not compound_growth)."""
        profile = _make_profile(
            age=22,
            estimated_replacement_ratio=0.65,
            months_liquidity=6.0,
        )
        choc = select_premier_eclairage(profile, stress_type="stress_budget")
        assert choc.category == "hourly_rate"

    def test_universal_retirement_gap_beats_lifecycle(self):
        """Age 45 + low ratio → retirement_gap from universal, not lifecycle."""
        profile = _make_profile(
            age=45,
            estimated_replacement_ratio=0.40,
            months_liquidity=6.0,
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "retirement_gap"

    def test_tax_saving_universal_beats_lifecycle(self):
        """No 3a + high tax saving at age 45 → tax_saving from universal."""
        profile = _make_profile(
            age=45,
            existing_3a=0.0,
            tax_saving_3a=2_000.0,
            estimated_replacement_ratio=0.65,
            months_liquidity=6.0,
        )
        choc = select_premier_eclairage(profile)
        assert choc.category == "tax_saving"


# ===========================================================================
# TestCompliance — 5 tests
# ===========================================================================

class TestCompliance:
    """Test compliance requirements for all premier éclairage categories."""

    @pytest.mark.parametrize("profile_kwargs,stress", [
        (dict(months_liquidity=0.5, estimated_fields=[], age=45), None),  # liquidity
        (dict(age=45, estimated_replacement_ratio=0.40, months_liquidity=6.0), None),  # retirement_gap
        (dict(age=30, existing_3a=0.0, tax_saving_3a=2_000.0, estimated_replacement_ratio=0.65, months_liquidity=6.0), None),  # tax_saving
        (dict(age=22, estimated_replacement_ratio=0.65, months_liquidity=6.0, existing_3a=5_000.0, tax_saving_3a=500.0), None),  # compound_growth
        (dict(age=25, estimated_replacement_ratio=0.65, months_liquidity=6.0), "stress_budget"),  # hourly_rate
    ])
    def test_no_banned_terms_in_any_text(self, profile_kwargs, stress):
        """No banned terms in display_text, explanation_text, or action_text."""
        profile = _make_profile(**profile_kwargs)
        choc = select_premier_eclairage(profile, stress_type=stress)

        all_text = (
            choc.display_text + " " +
            choc.explanation_text + " " +
            choc.action_text
        ).lower()

        for term in BANNED_TERMS:
            assert term.lower() not in all_text, (
                f"Banned term '{term}' found in {choc.category} choc text"
            )

    def test_disclaimer_present_in_all_categories(self):
        """Each category's premier éclairage must include a disclaimer."""
        profiles = [
            (_make_profile(months_liquidity=0.5, estimated_fields=[], age=45), None),
            (_make_profile(age=45, estimated_replacement_ratio=0.40, months_liquidity=6.0), None),
            (_make_profile(age=22, existing_3a=5_000.0, tax_saving_3a=500.0, months_liquidity=6.0), None),
        ]
        for p, stress in profiles:
            choc = select_premier_eclairage(p, stress_type=stress)
            assert len(choc.disclaimer) > 0
            assert "éducatif" in choc.disclaimer.lower()
            assert "LSFin" in choc.disclaimer

    def test_sources_present_in_all_categories(self):
        """Each category's premier éclairage must include sources."""
        profiles = [
            (_make_profile(months_liquidity=0.5, estimated_fields=[], age=45), None),
            (_make_profile(age=45, estimated_replacement_ratio=0.40, months_liquidity=6.0), None),
        ]
        for p, stress in profiles:
            choc = select_premier_eclairage(p, stress_type=stress)
            assert len(choc.sources) >= 1

    def test_exactly_one_premier_eclairage(self):
        """select_premier_eclairage returns exactly one PremierEclairage, not a list."""
        profile = _make_profile(age=45, estimated_replacement_ratio=0.40, months_liquidity=6.0)
        choc = select_premier_eclairage(profile)
        assert isinstance(choc, PremierEclairage)

    def test_confidence_score_propagated(self):
        """Chiffre choc should carry the profile's confidence score."""
        profile = _make_profile(age=45, estimated_replacement_ratio=0.40, months_liquidity=6.0)
        choc = select_premier_eclairage(profile)
        assert choc.confidence_score == profile.confidence_score


# ===========================================================================
# TestEndToEnd — 2 tests
# ===========================================================================

class TestEndToEnd:
    """End-to-end tests: input -> profile -> premier éclairage."""

    def test_full_pipeline_age_30_salary_80k(self):
        """Full pipeline: 3-input -> profile -> premier éclairage."""
        inp = MinimalProfileInput(age=30, gross_salary=80_000.0, canton="VD")
        profile = compute_minimal_profile(inp)
        choc = select_premier_eclairage(profile)
        assert choc.category in ["retirement_gap", "tax_saving", "liquidity",
                                  "compound_growth", "hourly_rate"]
        assert len(choc.display_text) > 0
        assert len(choc.disclaimer) > 0
        assert choc.confidence_mode in ("factual", "pedagogical")

    def test_full_pipeline_age_22_salary_50k(self):
        """Young worker pipeline: should get compound_growth or tax_saving."""
        inp = MinimalProfileInput(age=22, gross_salary=50_000.0, canton="ZH")
        profile = compute_minimal_profile(inp)
        choc = select_premier_eclairage(profile)
        # Young user should NOT get retirement_gap
        assert choc.category in ["compound_growth", "tax_saving", "liquidity"]

    def test_full_pipeline_age_64_salary_120k(self):
        """Near-retirement pipeline: should produce valid premier éclairage."""
        inp = MinimalProfileInput(age=64, gross_salary=120_000.0, canton="GE")
        profile = compute_minimal_profile(inp)
        choc = select_premier_eclairage(profile)
        assert choc.category in ["retirement_gap", "tax_saving", "liquidity",
                                  "retirement_gap"]
        assert choc.confidence_score == profile.confidence_score

    def test_full_pipeline_with_stress_type(self):
        """Pipeline with stress_type: budget intention at age 30 with savings."""
        inp = MinimalProfileInput(
            age=30, gross_salary=65_000.0, canton="FR",
            stress_type="stress_budget",
            current_savings=10_000.0,  # Provide savings to avoid false liquidity
        )
        profile = compute_minimal_profile(inp)
        choc = select_premier_eclairage(profile, stress_type=inp.stress_type)
        assert choc.category == "hourly_rate"
        assert choc.confidence_mode == "factual"
