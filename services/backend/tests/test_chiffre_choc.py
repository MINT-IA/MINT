"""
Tests for ChiffreChocSelector — Sprint S31: Onboarding Redesign.

18 tests across 5 groups:
    - TestPriorityOrdering (4): correct priority selection
    - TestLiquidityChoc (3): liquidity crisis triggers
    - TestRetirementGapChoc (3): retirement gap triggers
    - TestTaxSavingChoc (3): tax saving triggers
    - TestCompliance (5): banned terms, disclaimer, sources, text format

Sources:
    - LAVS art. 21-29 (rente AVS)
    - LPP art. 15-16 (bonifications vieillesse)
    - LIFD art. 38 (imposition du capital)
    - OPP3 art. 7 (plafond 3a)
"""

import pytest

from app.services.onboarding.chiffre_choc_selector import select_chiffre_choc
from app.services.onboarding.minimal_profile_service import compute_minimal_profile
from app.services.onboarding.onboarding_models import (
    MinimalProfileInput,
    MinimalProfileResult,
    ChiffreChoc,
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
    )
    defaults.update(overrides)
    return MinimalProfileResult(**defaults)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def liquidity_crisis_profile():
    """Profile with < 2 months liquidity."""
    return _make_profile(months_liquidity=1.2, estimated_replacement_ratio=0.60)


@pytest.fixture
def retirement_gap_profile():
    """Profile with low replacement ratio (< 0.55), but good liquidity."""
    return _make_profile(
        months_liquidity=6.0,
        estimated_replacement_ratio=0.45,
        estimated_monthly_retirement=2_600.0,
        estimated_monthly_expenses=5_800.0,
    )


@pytest.fixture
def tax_saving_profile():
    """Profile with no 3a, significant tax saving, good liquidity, OK ratio."""
    return _make_profile(
        months_liquidity=6.0,
        estimated_replacement_ratio=0.65,
        tax_saving_3a=2_000.0,
        estimated_fields=["household_type", "current_savings", "is_property_owner",
                          "existing_3a", "existing_lpp"],
    )


@pytest.fixture
def all_good_profile():
    """Profile where nothing is critical: falls to default."""
    return _make_profile(
        months_liquidity=8.0,
        estimated_replacement_ratio=0.70,
        tax_saving_3a=500.0,
        estimated_fields=[],
    )


# ===========================================================================
# TestPriorityOrdering — 4 tests
# ===========================================================================

class TestPriorityOrdering:
    """Test that chiffre choc priority is correctly applied."""

    def test_liquidity_beats_retirement_gap(self, liquidity_crisis_profile):
        """Liquidity crisis (< 2 months) should take priority over retirement gap."""
        # Also set low replacement ratio
        liquidity_crisis_profile.estimated_replacement_ratio = 0.40
        choc = select_chiffre_choc(liquidity_crisis_profile)
        assert choc.category == "liquidity"

    def test_retirement_gap_beats_tax_saving(self):
        """Retirement gap (ratio < 0.55) should take priority over tax saving."""
        profile = _make_profile(
            months_liquidity=6.0,
            estimated_replacement_ratio=0.45,
            tax_saving_3a=2_000.0,
            estimated_fields=["existing_3a"],
        )
        choc = select_chiffre_choc(profile)
        assert choc.category == "retirement_gap"

    def test_tax_saving_when_no_higher_priority(self, tax_saving_profile):
        """Tax saving triggers when liquidity OK and ratio >= 0.55."""
        choc = select_chiffre_choc(tax_saving_profile)
        assert choc.category == "tax_saving"

    def test_default_fallback_is_retirement_gap(self, all_good_profile):
        """When nothing is critical, default to retirement_gap."""
        choc = select_chiffre_choc(all_good_profile)
        assert choc.category == "retirement_gap"


# ===========================================================================
# TestLiquidityChoc — 3 tests
# ===========================================================================

class TestLiquidityChoc:
    """Test liquidity crisis chiffre choc."""

    def test_liquidity_category_correct(self, liquidity_crisis_profile):
        """Category should be 'liquidity'."""
        choc = select_chiffre_choc(liquidity_crisis_profile)
        assert choc.category == "liquidity"

    def test_liquidity_primary_number_matches(self, liquidity_crisis_profile):
        """Primary number should reflect months of liquidity."""
        choc = select_chiffre_choc(liquidity_crisis_profile)
        assert choc.primary_number == 1.2

    def test_liquidity_display_text_mentions_months(self, liquidity_crisis_profile):
        """Display text should mention months of reserve."""
        choc = select_chiffre_choc(liquidity_crisis_profile)
        assert "mois" in choc.display_text.lower()


# ===========================================================================
# TestRetirementGapChoc — 3 tests
# ===========================================================================

class TestRetirementGapChoc:
    """Test retirement gap chiffre choc."""

    def test_retirement_gap_category(self, retirement_gap_profile):
        """Category should be 'retirement_gap'."""
        choc = select_chiffre_choc(retirement_gap_profile)
        assert choc.category == "retirement_gap"

    def test_retirement_gap_primary_number_is_gap(self, retirement_gap_profile):
        """Primary number should be the monthly gap (expenses - retirement income)."""
        choc = select_chiffre_choc(retirement_gap_profile)
        expected_gap = max(0, 5_800 - 2_600)
        assert choc.primary_number == expected_gap

    def test_retirement_gap_mentions_retraite(self, retirement_gap_profile):
        """Display text should mention 'retraite'."""
        choc = select_chiffre_choc(retirement_gap_profile)
        assert "retraite" in choc.display_text.lower()


# ===========================================================================
# TestTaxSavingChoc — 3 tests
# ===========================================================================

class TestTaxSavingChoc:
    """Test tax saving chiffre choc."""

    def test_tax_saving_category(self, tax_saving_profile):
        """Category should be 'tax_saving'."""
        choc = select_chiffre_choc(tax_saving_profile)
        assert choc.category == "tax_saving"

    def test_tax_saving_primary_number(self, tax_saving_profile):
        """Primary number should reflect annual tax saving."""
        choc = select_chiffre_choc(tax_saving_profile)
        assert choc.primary_number == 2_000.0

    def test_tax_saving_not_triggered_with_low_saving(self):
        """Tax saving should NOT trigger if saving <= 1500."""
        profile = _make_profile(
            months_liquidity=6.0,
            estimated_replacement_ratio=0.65,
            tax_saving_3a=1_200.0,
            estimated_fields=["existing_3a"],
        )
        choc = select_chiffre_choc(profile)
        # Should fall to default (retirement_gap), not tax_saving
        assert choc.category == "retirement_gap"

    def test_tax_saving_not_triggered_when_existing_3a_positive(self):
        """Tax saving should NOT trigger when user already has 3a capital."""
        profile = _make_profile(
            months_liquidity=6.0,
            estimated_replacement_ratio=0.65,
            tax_saving_3a=2_000.0,
            existing_3a=8_000.0,
            estimated_fields=[],
        )
        choc = select_chiffre_choc(profile)
        assert choc.category == "retirement_gap"


# ===========================================================================
# TestCompliance — 5 tests
# ===========================================================================

class TestCompliance:
    """Test compliance requirements for all chiffre choc categories."""

    @pytest.mark.parametrize("profile_fixture", [
        "liquidity_crisis_profile",
        "retirement_gap_profile",
        "tax_saving_profile",
        "all_good_profile",
    ])
    def test_no_banned_terms_in_any_text(self, profile_fixture, request):
        """No banned terms in display_text, explanation_text, or action_text."""
        profile = request.getfixturevalue(profile_fixture)
        choc = select_chiffre_choc(profile)

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
        """Each category's chiffre choc must include a disclaimer."""
        profiles = [
            _make_profile(months_liquidity=1.0),
            _make_profile(months_liquidity=6.0, estimated_replacement_ratio=0.40),
            _make_profile(
                months_liquidity=6.0, estimated_replacement_ratio=0.65,
                tax_saving_3a=2_000.0,
                estimated_fields=["existing_3a"],
            ),
        ]
        for p in profiles:
            choc = select_chiffre_choc(p)
            assert len(choc.disclaimer) > 0
            assert "éducatif" in choc.disclaimer.lower()
            assert "LSFin" in choc.disclaimer

    def test_sources_present_in_all_categories(self):
        """Each category's chiffre choc must include sources."""
        profiles = [
            _make_profile(months_liquidity=1.0),
            _make_profile(months_liquidity=6.0, estimated_replacement_ratio=0.40),
        ]
        for p in profiles:
            choc = select_chiffre_choc(p)
            assert len(choc.sources) >= 1

    def test_exactly_one_chiffre_choc(self, retirement_gap_profile):
        """select_chiffre_choc returns exactly one ChiffreChoc, not a list."""
        choc = select_chiffre_choc(retirement_gap_profile)
        assert isinstance(choc, ChiffreChoc)

    def test_confidence_score_propagated(self, retirement_gap_profile):
        """Chiffre choc should carry the profile's confidence score."""
        choc = select_chiffre_choc(retirement_gap_profile)
        assert choc.confidence_score == retirement_gap_profile.confidence_score


# ===========================================================================
# TestEndToEnd — 2 tests
# ===========================================================================

class TestEndToEnd:
    """End-to-end tests: input -> profile -> chiffre choc."""

    def test_full_pipeline_age_30_salary_80k(self):
        """Full pipeline: 3-input -> profile -> chiffre choc."""
        inp = MinimalProfileInput(age=30, gross_salary=80_000.0, canton="VD")
        profile = compute_minimal_profile(inp)
        choc = select_chiffre_choc(profile)
        assert choc.category in ["retirement_gap", "tax_saving", "liquidity"]
        assert len(choc.display_text) > 0
        assert len(choc.disclaimer) > 0

    def test_full_pipeline_age_22_salary_50k(self):
        """Young worker pipeline: should produce valid chiffre choc."""
        inp = MinimalProfileInput(age=22, gross_salary=50_000.0, canton="ZH")
        profile = compute_minimal_profile(inp)
        choc = select_chiffre_choc(profile)
        assert choc.category in ["retirement_gap", "tax_saving", "liquidity"]

    def test_full_pipeline_age_64_salary_120k(self):
        """Near-retirement pipeline: should produce valid chiffre choc."""
        inp = MinimalProfileInput(age=64, gross_salary=120_000.0, canton="GE")
        profile = compute_minimal_profile(inp)
        choc = select_chiffre_choc(profile)
        assert choc.category in ["retirement_gap", "tax_saving", "liquidity"]
        assert choc.confidence_score == profile.confidence_score
