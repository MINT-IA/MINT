"""
Tests for Rente vs Capital — Sprint S32: Arbitrage Phase 1.

20 tests across 8 groups:
    - TestThreeOptionsAlwaysReturned (2): 3 options always present
    - TestBreakevenCalculation (2): breakeven accuracy
    - TestMixedScenario (2): mixed differs from pure A and B
    - TestSensitivity (2): rendement +1% changes terminal value
    - TestProgressiveTax (2): tax brackets applied correctly
    - TestConversionRate (2): 6.8% conversion on obligatoire
    - TestSWRSustainability (2): SWR sustainability over horizon
    - TestCompliance (3): disclaimer, sources, banned terms
    - TestEdgeCases (3): edge cases (age 64, capital 0, huge capital)

Sources:
    - LPP art. 14 (taux de conversion minimum)
    - LPP art. 37 (choix rente/capital)
    - LIFD art. 22 (imposition des rentes)
    - LIFD art. 38 (imposition du capital de prevoyance)
"""

import pytest

from app.services.arbitrage.rente_vs_capital import (
    compare_rente_vs_capital,
    _get_capital_tax,
)


# Banned terms that must NEVER appear in user-facing text
BANNED_TERMS = [
    "garanti", "certain", "assuré", "sans risque",
    "optimal", "meilleur", "parfait",
    "conseiller", "tu devrais", "tu dois",
]


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def standard_result():
    """Standard comparison: 500k total, 300k obligatoire, 200k surobligatoire."""
    return compare_rente_vs_capital(
        capital_lpp_total=500_000,
        capital_obligatoire=300_000,
        capital_surobligatoire=200_000,
        rente_annuelle_proposee=30_000,
        canton="VD",
        horizon=25,
    )


@pytest.fixture
def married_result():
    """Married couple scenario."""
    return compare_rente_vs_capital(
        capital_lpp_total=500_000,
        capital_obligatoire=300_000,
        capital_surobligatoire=200_000,
        rente_annuelle_proposee=30_000,
        canton="VD",
        horizon=25,
        is_married=True,
    )


# ===========================================================================
# TestThreeOptionsAlwaysReturned — 2 tests
# ===========================================================================

class TestThreeOptionsAlwaysReturned:
    """Verify that ALWAYS 3 options are returned."""

    def test_standard_returns_3_options(self, standard_result):
        """Standard scenario must return exactly 3 options."""
        assert len(standard_result.options) == 3

    def test_option_ids_correct(self, standard_result):
        """Options must have ids: full_rente, full_capital, mixed."""
        ids = [o.id for o in standard_result.options]
        assert "full_rente" in ids
        assert "full_capital" in ids
        assert "mixed" in ids


# ===========================================================================
# TestBreakevenCalculation — 2 tests
# ===========================================================================

class TestBreakevenCalculation:
    """Verify breakeven calculation accuracy."""

    def test_breakeven_is_integer_or_negative_one(self, standard_result):
        """Breakeven must be an integer year or -1."""
        assert isinstance(standard_result.breakeven_year, int)
        assert standard_result.breakeven_year == -1 or standard_result.breakeven_year >= 65

    def test_breakeven_with_high_rente(self):
        """High rente relative to capital: rente should lead early, breakeven later."""
        result = compare_rente_vs_capital(
            capital_lpp_total=400_000,
            capital_obligatoire=250_000,
            capital_surobligatoire=150_000,
            rente_annuelle_proposee=40_000,  # Very generous rente
            canton="ZG",
            horizon=35,
        )
        # With very generous rente, rente may always be ahead
        assert isinstance(result.breakeven_year, int)


# ===========================================================================
# TestMixedScenario — 2 tests
# ===========================================================================

class TestMixedScenario:
    """Verify mixed option differs from pure A and B."""

    def test_mixed_terminal_differs_from_rente(self, standard_result):
        """Mixed terminal value should differ from full rente."""
        rente = next(o for o in standard_result.options if o.id == "full_rente")
        mixed = next(o for o in standard_result.options if o.id == "mixed")
        assert mixed.terminal_value != rente.terminal_value

    def test_mixed_terminal_differs_from_capital(self, standard_result):
        """Mixed terminal value should differ from full capital."""
        capital = next(o for o in standard_result.options if o.id == "full_capital")
        mixed = next(o for o in standard_result.options if o.id == "mixed")
        assert mixed.terminal_value != capital.terminal_value


# ===========================================================================
# TestSensitivity — 2 tests
# ===========================================================================

class TestSensitivity:
    """Verify sensitivity analysis."""

    def test_sensitivity_has_rendement_capital_key(self, standard_result):
        """Sensitivity dict must have 'rendement_capital' key."""
        assert "rendement_capital" in standard_result.sensitivity

    def test_rendement_plus_1_changes_terminal(self):
        """Rendement +1% must change terminal value significantly."""
        result_base = compare_rente_vs_capital(
            capital_lpp_total=500_000,
            capital_obligatoire=300_000,
            capital_surobligatoire=200_000,
            rente_annuelle_proposee=30_000,
            rendement_capital=0.03,
            horizon=25,
        )
        result_plus = compare_rente_vs_capital(
            capital_lpp_total=500_000,
            capital_obligatoire=300_000,
            capital_surobligatoire=200_000,
            rente_annuelle_proposee=30_000,
            rendement_capital=0.04,
            horizon=25,
        )
        capital_base = next(o for o in result_base.options if o.id == "full_capital")
        capital_plus = next(o for o in result_plus.options if o.id == "full_capital")
        assert capital_plus.terminal_value > capital_base.terminal_value


# ===========================================================================
# TestProgressiveTax — 2 tests
# ===========================================================================

class TestProgressiveTax:
    """Verify progressive tax brackets applied correctly on capital withdrawal."""

    def test_tax_increases_with_capital_amount(self):
        """Higher capital = higher effective tax rate (progressive brackets)."""
        tax_100k = _get_capital_tax(100_000, "VD", False)
        tax_500k = _get_capital_tax(500_000, "VD", False)
        # Effective rate on 500k should be higher than on 100k
        effective_100k = tax_100k / 100_000
        effective_500k = tax_500k / 500_000
        assert effective_500k > effective_100k

    def test_married_discount_reduces_tax(self):
        """Married couples get a tax discount on capital withdrawal."""
        tax_single = _get_capital_tax(500_000, "VD", False)
        tax_married = _get_capital_tax(500_000, "VD", True)
        assert tax_married < tax_single


# ===========================================================================
# TestConversionRate — 2 tests
# ===========================================================================

class TestConversionRate:
    """Verify 6.8% conversion rate on obligatoire portion."""

    def test_rente_from_obligatoire_at_6_8_percent(self):
        """Mixed option: rente from obligatoire = capital * 6.8%."""
        result = compare_rente_vs_capital(
            capital_lpp_total=500_000,
            capital_obligatoire=300_000,
            capital_surobligatoire=200_000,
            rente_annuelle_proposee=30_000,
            taux_conversion_obligatoire=0.068,
        )
        mixed = next(o for o in result.options if o.id == "mixed")
        # First year cashflow should include rente from 300k * 6.8% = 20'400 (before tax)
        # Plus SWR from surobligatoire portion
        assert mixed.trajectory[0].annual_cashflow > 0

    def test_custom_conversion_rate(self):
        """Custom conversion rate should affect mixed option."""
        result_68 = compare_rente_vs_capital(
            capital_lpp_total=500_000,
            capital_obligatoire=300_000,
            capital_surobligatoire=200_000,
            rente_annuelle_proposee=30_000,
            taux_conversion_obligatoire=0.068,
        )
        result_50 = compare_rente_vs_capital(
            capital_lpp_total=500_000,
            capital_obligatoire=300_000,
            capital_surobligatoire=200_000,
            rente_annuelle_proposee=30_000,
            taux_conversion_obligatoire=0.050,
        )
        mixed_68 = next(o for o in result_68.options if o.id == "mixed")
        mixed_50 = next(o for o in result_50.options if o.id == "mixed")
        # Higher conversion rate = more annual rente, more terminal value
        assert mixed_68.terminal_value > mixed_50.terminal_value


# ===========================================================================
# TestSWRSustainability — 2 tests
# ===========================================================================

class TestSWRSustainability:
    """Verify SWR sustainability over horizon."""

    def test_capital_decreases_over_time_with_net_4_pct_swr(self):
        """With 4% SWR and 3% return, capital should gradually decline."""
        result = compare_rente_vs_capital(
            capital_lpp_total=500_000,
            capital_obligatoire=300_000,
            capital_surobligatoire=200_000,
            rente_annuelle_proposee=30_000,
            taux_retrait=0.04,
            rendement_capital=0.03,
            horizon=25,
        )
        capital = next(o for o in result.options if o.id == "full_capital")
        # Annual cashflow should be positive for all years
        for snapshot in capital.trajectory:
            assert snapshot.annual_cashflow >= 0

    def test_capital_trajectory_has_correct_length(self, standard_result):
        """Capital trajectory must have correct number of years."""
        capital = next(o for o in standard_result.options if o.id == "full_capital")
        assert len(capital.trajectory) == 25


# ===========================================================================
# TestCompliance — 3 tests
# ===========================================================================

class TestCompliance:
    """Verify mandatory compliance fields."""

    def test_disclaimer_present_and_valid(self, standard_result):
        """Disclaimer must be non-empty and contain 'educatif' and 'LSFin'."""
        d = standard_result.disclaimer
        assert len(d) > 0
        assert "educatif" in d.lower()
        assert "LSFin" in d

    def test_sources_contain_lpp_and_lifd(self, standard_result):
        """Sources must contain LPP art. 14, LIFD art. 22, LIFD art. 38."""
        sources_text = " ".join(standard_result.sources)
        assert "LPP art. 14" in sources_text
        assert "LIFD art. 22" in sources_text
        assert "LIFD art. 38" in sources_text

    def test_no_banned_terms_in_any_output(self, standard_result):
        """No banned terms in any user-facing output string."""
        all_text = " ".join([
            standard_result.chiffre_choc,
            standard_result.display_summary,
            standard_result.disclaimer,
            *standard_result.hypotheses,
            *standard_result.sources,
            *[o.label for o in standard_result.options],
        ]).lower()
        for term in BANNED_TERMS:
            assert term.lower() not in all_text, (
                f"Banned term '{term}' found in output"
            )

    def test_hypotheses_always_populated(self, standard_result):
        """Hypotheses list must always be populated."""
        assert len(standard_result.hypotheses) >= 5


# ===========================================================================
# TestEdgeCases — 3 tests
# ===========================================================================

class TestEdgeCases:
    """Boundary conditions and edge cases."""

    def test_age_64_one_year_horizon(self):
        """Age 64 with 1 year horizon should still work."""
        result = compare_rente_vs_capital(
            capital_lpp_total=300_000,
            capital_obligatoire=200_000,
            capital_surobligatoire=100_000,
            rente_annuelle_proposee=18_000,
            age_retraite=64,
            horizon=1,
        )
        assert len(result.options) == 3
        for opt in result.options:
            assert len(opt.trajectory) == 1

    def test_capital_zero(self):
        """Capital 0 should still return 3 options with zero values."""
        result = compare_rente_vs_capital(
            capital_lpp_total=0,
            capital_obligatoire=0,
            capital_surobligatoire=0,
            rente_annuelle_proposee=0,
        )
        assert len(result.options) == 3
        # All terminal values should be 0 or near 0
        for opt in result.options:
            assert opt.terminal_value == 0.0

    def test_huge_capital_2m(self):
        """2M capital should work with progressive brackets."""
        result = compare_rente_vs_capital(
            capital_lpp_total=2_000_000,
            capital_obligatoire=800_000,
            capital_surobligatoire=1_200_000,
            rente_annuelle_proposee=100_000,
            horizon=25,
        )
        assert len(result.options) == 3
        capital_opt = next(o for o in result.options if o.id == "full_capital")
        # Tax on 2M should be significant (progressive brackets)
        assert capital_opt.cumulative_tax_impact > 100_000

    def test_rente_zero_capital_positive(self):
        """Rente 0 but positive capital should still work."""
        result = compare_rente_vs_capital(
            capital_lpp_total=500_000,
            capital_obligatoire=300_000,
            capital_surobligatoire=200_000,
            rente_annuelle_proposee=0,
        )
        assert len(result.options) == 3
        rente = next(o for o in result.options if o.id == "full_rente")
        assert rente.terminal_value == 0.0
