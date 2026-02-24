"""
Tests for FRI (Financial Resilience Index) — Sprint S38.

Covers:
    - L component: liquidity (sqrt, penalties)
    - F component: fiscal efficiency (weighted, conditional rachat)
    - R component: retirement readiness (pow 1.5)
    - S component: structural risk (penalties)
    - Full FRI computation
    - Archetype × age variations (8 archetypes × 3 ages)
    - Edge cases and boundary conditions

Run: cd services/backend && python3 -m pytest tests/test_fri.py -v
"""

import math
import pytest

from app.services.fri.fri_service import FriService, FriBreakdown, FriInput


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def default_input():
    return FriInput(
        liquid_assets=15000,
        monthly_fixed_costs=3000,
        short_term_debt_ratio=0.10,
        income_volatility="low",
        actual_3a=7258,
        max_3a=7258,
        potentiel_rachat_lpp=20000,
        rachat_effectue=10000,
        taux_marginal=0.30,
        is_property_owner=False,
        replacement_ratio=0.65,
        disability_gap_ratio=0.10,
        has_dependents=False,
        death_protection_gap_ratio=0.0,
        mortgage_stress_ratio=0.0,
        concentration_ratio=0.40,
        employer_dependency_ratio=0.50,
        archetype="swiss_native",
        age=35,
        canton="VD",
    )


@pytest.fixture
def worst_case_input():
    """All penalties triggered, minimal assets."""
    return FriInput(
        liquid_assets=0,
        monthly_fixed_costs=4000,
        short_term_debt_ratio=0.50,
        income_volatility="high",
        actual_3a=0,
        max_3a=7258,
        potentiel_rachat_lpp=50000,
        rachat_effectue=0,
        taux_marginal=0.35,
        is_property_owner=True,
        amort_indirect=0,
        replacement_ratio=0.20,
        disability_gap_ratio=0.40,
        has_dependents=True,
        death_protection_gap_ratio=0.50,
        mortgage_stress_ratio=0.40,
        concentration_ratio=0.80,
        employer_dependency_ratio=0.90,
    )


@pytest.fixture
def excellent_input():
    """All components maxed out."""
    return FriInput(
        liquid_assets=24000,
        monthly_fixed_costs=4000,
        short_term_debt_ratio=0.0,
        income_volatility="low",
        actual_3a=7258,
        max_3a=7258,
        potentiel_rachat_lpp=20000,
        rachat_effectue=20000,
        taux_marginal=0.35,
        is_property_owner=True,
        amort_indirect=5000,
        replacement_ratio=0.75,
        disability_gap_ratio=0.05,
        has_dependents=True,
        death_protection_gap_ratio=0.10,
        mortgage_stress_ratio=0.30,
        concentration_ratio=0.40,
        employer_dependency_ratio=0.50,
    )


# ===========================================================================
# L — Liquidity tests
# ===========================================================================

class TestLiquidity:
    """Tests for L component (0-25)."""

    def test_zero_assets(self):
        inp = FriInput(liquid_assets=0, monthly_fixed_costs=3000)
        assert FriService.compute_liquidity(inp) == 0.0

    def test_one_month_reserve(self):
        inp = FriInput(liquid_assets=3000, monthly_fixed_costs=3000)
        # sqrt(1/6) ≈ 0.408 → 25 * 0.408 ≈ 10.2
        l = FriService.compute_liquidity(inp)
        assert 10 < l < 11

    def test_three_months_reserve(self):
        inp = FriInput(liquid_assets=9000, monthly_fixed_costs=3000)
        # sqrt(3/6) = sqrt(0.5) ≈ 0.707 → 25 * 0.707 ≈ 17.7
        l = FriService.compute_liquidity(inp)
        assert 17 < l < 18

    def test_six_months_full_score(self):
        inp = FriInput(liquid_assets=18000, monthly_fixed_costs=3000)
        # sqrt(6/6) = 1.0 → 25
        assert FriService.compute_liquidity(inp) == 25.0

    def test_twelve_months_capped(self):
        inp = FriInput(liquid_assets=36000, monthly_fixed_costs=3000)
        # sqrt(12/6) > 1 → capped at 25
        assert FriService.compute_liquidity(inp) == 25.0

    def test_penalty_high_debt_ratio(self):
        inp = FriInput(
            liquid_assets=18000, monthly_fixed_costs=3000,
            short_term_debt_ratio=0.35,
        )
        # 25 - 4 = 21
        assert FriService.compute_liquidity(inp) == 21.0

    def test_penalty_high_volatility(self):
        inp = FriInput(
            liquid_assets=18000, monthly_fixed_costs=3000,
            income_volatility="high",
        )
        # 25 - 3 = 22
        assert FriService.compute_liquidity(inp) == 22.0

    def test_both_penalties(self):
        inp = FriInput(
            liquid_assets=18000, monthly_fixed_costs=3000,
            short_term_debt_ratio=0.50, income_volatility="high",
        )
        # 25 - 4 - 3 = 18
        assert FriService.compute_liquidity(inp) == 18.0

    def test_penalties_dont_go_negative(self):
        inp = FriInput(
            liquid_assets=500, monthly_fixed_costs=3000,
            short_term_debt_ratio=0.50, income_volatility="high",
        )
        # Small base - 7 penalties → clamped to 0
        assert FriService.compute_liquidity(inp) >= 0.0


# ===========================================================================
# F — Fiscal efficiency tests
# ===========================================================================

class TestFiscal:
    """Tests for F component (0-25)."""

    def test_full_3a_no_other(self):
        inp = FriInput(actual_3a=7258, max_3a=7258)
        f = FriService.compute_fiscal(inp)
        # Rachat not applicable (no potential) → redistributed weights:
        # 25 * (0.80 * 1.0 + 0.20 * 1.0) = 25.0
        assert abs(f - 25.0) < 0.01

    def test_zero_3a(self):
        inp = FriInput(actual_3a=0, max_3a=7258)
        f = FriService.compute_fiscal(inp)
        # Rachat not applicable → 25 * (0.80 * 0 + 0.20 * 1.0) = 5.0
        assert abs(f - 5.0) < 0.01

    def test_rachat_ignored_if_low_marginal(self):
        """Rachat LPP not penalized if taux marginal <= 25%."""
        inp = FriInput(
            actual_3a=0, max_3a=7258,
            potentiel_rachat_lpp=50000, rachat_effectue=0,
            taux_marginal=0.20,  # Below 25% threshold
        )
        f = FriService.compute_fiscal(inp)
        # Rachat not applicable → weights redistribute: 25 * (0.80 * 0 + 0.20 * 1.0) = 5.0
        assert abs(f - 5.0) < 0.01

    def test_rachat_penalized_if_high_marginal(self):
        """Rachat LPP penalized if taux marginal > 25% and no buyback."""
        inp_no_rachat = FriInput(
            actual_3a=7258, max_3a=7258,
            potentiel_rachat_lpp=50000, rachat_effectue=0,
            taux_marginal=0.30,
        )
        inp_full_rachat = FriInput(
            actual_3a=7258, max_3a=7258,
            potentiel_rachat_lpp=50000, rachat_effectue=50000,
            taux_marginal=0.30,
        )
        # With no rachat: 25 * (0.6 + 0 + 0.15) = 18.75
        # With full rachat: 25 * (0.6 + 0.25 + 0.15) = 25.0
        f_no = FriService.compute_fiscal(inp_no_rachat)
        f_full = FriService.compute_fiscal(inp_full_rachat)
        assert f_full > f_no
        assert abs(f_full - 25.0) < 0.01

    def test_property_owner_no_amort(self):
        """Property owner without indirect amortization loses amort weight."""
        inp = FriInput(
            actual_3a=7258, max_3a=7258,
            is_property_owner=True, amort_indirect=0,
        )
        f = FriService.compute_fiscal(inp)
        # Rachat not applicable → 25 * (0.80 * 1 + 0.20 * 0) = 20.0
        assert abs(f - 20.0) < 0.01

    def test_property_owner_with_amort(self):
        inp = FriInput(
            actual_3a=7258, max_3a=7258,
            is_property_owner=True, amort_indirect=3000,
        )
        f = FriService.compute_fiscal(inp)
        # Rachat not applicable → 25 * (0.80 * 1 + 0.20 * 1) = 25.0
        assert abs(f - 25.0) < 0.01

    def test_independant_max_3a(self):
        """Independant has higher 3a max."""
        inp = FriInput(actual_3a=36288, max_3a=36288)
        f = FriService.compute_fiscal(inp)
        # Rachat not applicable → 25 * (0.80 * 1 + 0.20 * 1) = 25.0
        assert abs(f - 25.0) < 0.01


# ===========================================================================
# R — Retirement tests
# ===========================================================================

class TestRetirement:
    """Tests for R component (0-25)."""

    def test_zero_replacement(self):
        inp = FriInput(replacement_ratio=0.0)
        assert FriService.compute_retirement(inp) == 0.0

    def test_target_replacement(self):
        """70% replacement = full score."""
        inp = FriInput(replacement_ratio=0.70)
        r = FriService.compute_retirement(inp)
        assert abs(r - 25.0) < 0.01

    def test_above_target(self):
        """Above 70% still capped at 25."""
        inp = FriInput(replacement_ratio=0.90)
        assert FriService.compute_retirement(inp) == 25.0

    def test_half_target(self):
        """35% replacement → pow(0.5, 1.5) ≈ 0.354 → ~8.8"""
        inp = FriInput(replacement_ratio=0.35)
        r = FriService.compute_retirement(inp)
        expected = 25.0 * math.pow(0.35 / 0.70, 1.5)
        assert abs(r - expected) < 0.1

    def test_nonlinear_curve(self):
        """Verify diminishing returns: 30%→60% gains more than 60%→70%."""
        inp_30 = FriInput(replacement_ratio=0.30)
        inp_60 = FriInput(replacement_ratio=0.60)
        inp_70 = FriInput(replacement_ratio=0.70)
        r_30 = FriService.compute_retirement(inp_30)
        r_60 = FriService.compute_retirement(inp_60)
        r_70 = FriService.compute_retirement(inp_70)
        gain_30_to_60 = r_60 - r_30
        gain_60_to_70 = r_70 - r_60
        assert gain_30_to_60 > gain_60_to_70


# ===========================================================================
# S — Structural risk tests
# ===========================================================================

class TestStructuralRisk:
    """Tests for S component (0-25)."""

    def test_no_penalties(self):
        inp = FriInput()
        assert FriService.compute_structural_risk(inp) == 25.0

    def test_disability_gap_penalty(self):
        inp = FriInput(disability_gap_ratio=0.25)
        assert FriService.compute_structural_risk(inp) == 19.0  # 25 - 6

    def test_death_protection_with_dependents(self):
        inp = FriInput(has_dependents=True, death_protection_gap_ratio=0.40)
        assert FriService.compute_structural_risk(inp) == 19.0  # 25 - 6

    def test_death_protection_without_dependents(self):
        """No penalty if no dependents, even with high gap."""
        inp = FriInput(has_dependents=False, death_protection_gap_ratio=0.90)
        assert FriService.compute_structural_risk(inp) == 25.0

    def test_mortgage_stress(self):
        inp = FriInput(mortgage_stress_ratio=0.40)
        assert FriService.compute_structural_risk(inp) == 20.0  # 25 - 5

    def test_concentration(self):
        inp = FriInput(concentration_ratio=0.80)
        assert FriService.compute_structural_risk(inp) == 21.0  # 25 - 4

    def test_employer_dependency(self):
        inp = FriInput(employer_dependency_ratio=0.90)
        assert FriService.compute_structural_risk(inp) == 21.0  # 25 - 4

    def test_all_penalties(self):
        inp = FriInput(
            disability_gap_ratio=0.30,
            has_dependents=True,
            death_protection_gap_ratio=0.40,
            mortgage_stress_ratio=0.40,
            concentration_ratio=0.80,
            employer_dependency_ratio=0.90,
        )
        # 25 - 6 - 6 - 5 - 4 - 4 = 0
        assert FriService.compute_structural_risk(inp) == 0.0


# ===========================================================================
# Full FRI computation
# ===========================================================================

class TestFriComputation:
    """Tests for full FRI breakdown."""

    def test_returns_breakdown(self, default_input):
        result = FriService.compute(default_input)
        assert isinstance(result, FriBreakdown)
        assert 0 <= result.liquidite <= 25
        assert 0 <= result.fiscalite <= 25
        assert 0 <= result.retraite <= 25
        assert 0 <= result.risque <= 25
        assert 0 <= result.total <= 100

    def test_total_equals_sum(self, default_input):
        result = FriService.compute(default_input)
        assert abs(result.total - (result.liquidite + result.fiscalite + result.retraite + result.risque)) < 0.01

    def test_excellent_score(self, excellent_input):
        result = FriService.compute(excellent_input)
        assert result.total > 85

    def test_worst_case_score(self, worst_case_input):
        result = FriService.compute(worst_case_input)
        assert result.total < 15

    def test_model_version(self, default_input):
        result = FriService.compute(default_input)
        assert result.model_version == "1.0.0"

    def test_confidence_score_passed_through(self, default_input):
        result = FriService.compute(default_input, confidence_score=72.5)
        assert result.confidence_score == 72.5

    def test_has_disclaimer(self, default_input):
        result = FriService.compute(default_input)
        assert "educatif" in result.disclaimer.lower()

    def test_has_sources(self, default_input):
        result = FriService.compute(default_input)
        assert len(result.sources) >= 3


# ===========================================================================
# Archetype × age variations
# ===========================================================================

ARCHETYPES = [
    "swiss_native", "expat_eu", "expat_non_eu", "expat_us",
    "independent_with_lpp", "independent_no_lpp",
    "cross_border", "returning_swiss",
]

class TestArchetypeVariations:
    """Test FRI across 8 archetypes × 3 ages."""

    @pytest.mark.parametrize("archetype", ARCHETYPES)
    def test_archetype_produces_valid_score(self, archetype):
        inp = FriInput(
            liquid_assets=12000,
            monthly_fixed_costs=3500,
            actual_3a=5000,
            max_3a=7258 if archetype != "independent_no_lpp" else 36288,
            replacement_ratio=0.55,
            archetype=archetype,
            age=40,
        )
        result = FriService.compute(inp)
        assert 0 <= result.total <= 100
        assert result.total == round(
            result.liquidite + result.fiscalite + result.retraite + result.risque, 2
        )

    @pytest.mark.parametrize("age", [25, 45, 63])
    def test_age_produces_valid_score(self, age):
        inp = FriInput(
            liquid_assets=10000,
            monthly_fixed_costs=3000,
            actual_3a=3000,
            max_3a=7258,
            replacement_ratio=0.50,
            age=age,
        )
        result = FriService.compute(inp)
        assert 0 <= result.total <= 100

    def test_independant_high_volatility(self):
        """Independants get high volatility penalty on L."""
        inp_salarie = FriInput(
            liquid_assets=18000, monthly_fixed_costs=3000,
            income_volatility="low",
        )
        inp_indep = FriInput(
            liquid_assets=18000, monthly_fixed_costs=3000,
            income_volatility="high",
        )
        l_salarie = FriService.compute_liquidity(inp_salarie)
        l_indep = FriService.compute_liquidity(inp_indep)
        assert l_salarie > l_indep
        assert l_salarie - l_indep == 3.0  # exact -3 penalty

    def test_independant_no_lpp_higher_3a_max(self):
        """Independant sans LPP has 36'288 3a max, partial fill."""
        inp = FriInput(
            actual_3a=7258,
            max_3a=36288,
        )
        f = FriService.compute_fiscal(inp)
        utilisation_3a = 7258 / 36288  # ≈ 0.20
        # Rachat not applicable → redistributed: 25 * (0.80 * util_3a + 0.20 * 1.0)
        expected = 25 * (0.80 * utilisation_3a + 0.20)
        assert abs(f - expected) < 0.1
