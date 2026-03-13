"""
Tests for Allocation Annuelle — Sprint S32: Arbitrage Phase 1.

20 tests across 8 groups:
    - TestOptionEligibility (4): 3a, rachat LPP, amort indirect conditions
    - TestInvestLibreAlwaysPresent (2): invest libre always available
    - TestHorizonConsistency (2): same horizon applied to all
    - TestTaxSaving (2): tax saving = taux_marginal * contribution
    - TestCompliance (3): disclaimer, sources, banned terms
    - TestEdgeCases (3): montant 0, all ineligible, partial eligibility
    - Test3aPlafond (2): capped at 7258
    - TestLPPBlocage (2): blocage 3 ans in hypotheses

Sources:
    - OPP3 art. 7 (plafond 3a: 7'258 CHF avec LPP)
    - LPP art. 79b (rachat volontaire, blocage 3 ans)
    - LIFD art. 33 (deductions fiscales prevoyance)
    - LIFD art. 38 (imposition du capital de prevoyance)
"""

import pytest

from app.services.arbitrage.allocation_annuelle import (
    compare_allocation_annuelle,
    _build_3a_option,
    _build_rachat_lpp_option,
)
from app.constants.social_insurance import (
    PILIER_3A_PLAFOND_AVEC_LPP,
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
    """Standard allocation: 10k available, 25% taux marginal, all eligible."""
    return compare_allocation_annuelle(
        montant_disponible=10_000,
        taux_marginal=0.25,
        a3a_maxed=False,
        potentiel_rachat_lpp=50_000,
        is_property_owner=True,
        annees_avant_retraite=20,
        canton="VD",
    )


@pytest.fixture
def minimal_result():
    """Minimal: only invest libre eligible."""
    return compare_allocation_annuelle(
        montant_disponible=10_000,
        taux_marginal=0.25,
        a3a_maxed=True,
        potentiel_rachat_lpp=0,
        is_property_owner=False,
    )


# ===========================================================================
# TestOptionEligibility — 4 tests
# ===========================================================================

class TestOptionEligibility:
    """Verify option inclusion based on eligibility criteria."""

    def test_3a_included_when_not_maxed(self, standard_result):
        """3a should be included when a3a_maxed is False."""
        ids = [o.id for o in standard_result.options]
        assert "3a" in ids

    def test_3a_excluded_when_maxed(self):
        """3a should be excluded when a3a_maxed is True."""
        result = compare_allocation_annuelle(
            montant_disponible=10_000,
            taux_marginal=0.25,
            a3a_maxed=True,
            potentiel_rachat_lpp=50_000,
        )
        ids = [o.id for o in result.options]
        assert "3a" not in ids

    def test_rachat_lpp_included_when_potentiel_positive(self, standard_result):
        """Rachat LPP should be included when potentiel_rachat_lpp > 0."""
        ids = [o.id for o in standard_result.options]
        assert "rachat_lpp" in ids

    def test_rachat_lpp_excluded_when_potentiel_zero(self):
        """Rachat LPP should be excluded when potentiel_rachat_lpp is 0."""
        result = compare_allocation_annuelle(
            montant_disponible=10_000,
            taux_marginal=0.25,
            potentiel_rachat_lpp=0,
        )
        ids = [o.id for o in result.options]
        assert "rachat_lpp" not in ids


# ===========================================================================
# TestAmortIndirect — 2 tests
# ===========================================================================

class TestAmortIndirect:
    """Verify amortissement indirect eligibility."""

    def test_amort_included_when_property_owner(self, standard_result):
        """Amort indirect should be included when is_property_owner is True."""
        ids = [o.id for o in standard_result.options]
        assert "amort_indirect" in ids

    def test_amort_excluded_when_not_owner(self):
        """Amort indirect should be excluded when is_property_owner is False."""
        result = compare_allocation_annuelle(
            montant_disponible=10_000,
            taux_marginal=0.25,
            is_property_owner=False,
        )
        ids = [o.id for o in result.options]
        assert "amort_indirect" not in ids


# ===========================================================================
# TestInvestLibreAlwaysPresent — 2 tests
# ===========================================================================

class TestInvestLibreAlwaysPresent:
    """Verify investissement libre is always available."""

    def test_invest_libre_in_standard(self, standard_result):
        """Invest libre should be present in standard case."""
        ids = [o.id for o in standard_result.options]
        assert "invest_libre" in ids

    def test_invest_libre_when_all_others_excluded(self, minimal_result):
        """Invest libre should be the only option when all others excluded."""
        ids = [o.id for o in minimal_result.options]
        assert "invest_libre" in ids
        assert len(minimal_result.options) == 1


# ===========================================================================
# TestHorizonConsistency — 2 tests
# ===========================================================================

class TestHorizonConsistency:
    """Verify same horizon applied to all options."""

    def test_all_trajectories_same_length(self, standard_result):
        """All option trajectories must have the same number of years."""
        lengths = [len(o.trajectory) for o in standard_result.options]
        assert len(set(lengths)) == 1
        assert lengths[0] == 20

    def test_custom_horizon(self):
        """Custom horizon should be reflected in all trajectories."""
        result = compare_allocation_annuelle(
            montant_disponible=5_000,
            taux_marginal=0.20,
            annees_avant_retraite=10,
        )
        for opt in result.options:
            assert len(opt.trajectory) == 10


# ===========================================================================
# TestTaxSaving — 2 tests
# ===========================================================================

class TestTaxSaving:
    """Verify tax saving computation."""

    def test_3a_tax_saving_correct(self):
        """3a tax saving = contribution * taux_marginal."""
        option = _build_3a_option(
            montant=10_000,
            taux_marginal=0.25,
            annees=1,
            rendement_3a=0.0,  # Zero return for simplicity
            canton="VD",
        )
        # Contribution capped at 7258, tax saving = 7258 * 0.25 = 1814.50
        expected_saving = PILIER_3A_PLAFOND_AVEC_LPP * 0.25
        # In first year: cumulative_tax_delta should be negative (saving)
        assert abs(option.trajectory[0].cumulative_tax_delta + expected_saving) < 0.01

    def test_rachat_lpp_tax_saving_correct(self):
        """Rachat LPP tax saving = buyback * taux_marginal."""
        option = _build_rachat_lpp_option(
            montant=5_000,
            potentiel_rachat=100_000,
            taux_marginal=0.30,
            annees=1,
            rendement_lpp=0.0,
            canton="VD",
        )
        expected_saving = 5_000 * 0.30
        assert abs(option.trajectory[0].cumulative_tax_delta + expected_saving) < 0.01


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

    def test_sources_contain_opp3_lpp_lifd(self, standard_result):
        """Sources must contain OPP3 art. 7, LPP art. 79b, LIFD art. 33."""
        sources_text = " ".join(standard_result.sources)
        assert "OPP3 art. 7" in sources_text
        assert "LPP art. 79b" in sources_text
        assert "LIFD art. 33" in sources_text

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


# ===========================================================================
# TestEdgeCases — 3 tests
# ===========================================================================

class TestEdgeCases:
    """Boundary conditions and edge cases."""

    def test_montant_zero(self):
        """Montant 0 should still return invest libre (with zero trajectory)."""
        result = compare_allocation_annuelle(
            montant_disponible=0,
            taux_marginal=0.25,
        )
        assert len(result.options) >= 1
        invest_libre = next(o for o in result.options if o.id == "invest_libre")
        assert invest_libre.terminal_value == 0.0

    def test_only_invest_libre_when_all_ineligible(self, minimal_result):
        """When 3a maxed, no rachat, not owner: only invest libre."""
        assert len(minimal_result.options) == 1
        assert minimal_result.options[0].id == "invest_libre"

    def test_high_montant_100k(self):
        """High montant (100k) should still cap 3a at plafond."""
        result = compare_allocation_annuelle(
            montant_disponible=100_000,
            taux_marginal=0.30,
            a3a_maxed=False,
            potentiel_rachat_lpp=200_000,
            annees_avant_retraite=10,
        )
        option_3a = next(o for o in result.options if o.id == "3a")
        # Annual cashflow should be capped at 7258
        assert option_3a.trajectory[0].annual_cashflow == PILIER_3A_PLAFOND_AVEC_LPP


# ===========================================================================
# Test3aPlafond — 2 tests
# ===========================================================================

class Test3aPlafond:
    """Verify 3a contribution capped at plafond."""

    def test_3a_capped_at_7258(self):
        """3a contribution must be capped at 7'258 CHF even if montant is higher."""
        option = _build_3a_option(
            montant=20_000,
            taux_marginal=0.25,
            annees=5,
            rendement_3a=0.02,
            canton="VD",
        )
        # Each year contribution should be 7258
        for snap in option.trajectory:
            assert snap.annual_cashflow == PILIER_3A_PLAFOND_AVEC_LPP

    def test_3a_uses_montant_if_below_plafond(self):
        """3a contribution should use montant if below plafond."""
        option = _build_3a_option(
            montant=3_000,
            taux_marginal=0.25,
            annees=5,
            rendement_3a=0.02,
            canton="VD",
        )
        for snap in option.trajectory:
            assert snap.annual_cashflow == 3_000.0


# ===========================================================================
# TestLPPBlocage — 2 tests
# ===========================================================================

class TestLPPBlocage:
    """Verify LPP blocage 3 ans is mentioned in hypotheses."""

    def test_blocage_in_hypotheses(self, standard_result):
        """Hypotheses must mention LPP art. 79b al. 3 blocage."""
        hypotheses_text = " ".join(standard_result.hypotheses)
        assert "79b" in hypotheses_text or "blocage" in hypotheses_text

    def test_hypotheses_always_populated(self, standard_result):
        """Hypotheses list must always be populated."""
        assert len(standard_result.hypotheses) >= 5
