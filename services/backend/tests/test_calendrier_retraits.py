"""
Tests for Calendrier de Retraits — Sprint S33.

THE HIGHEST WOW-NUMBER MODULE.

Covers:
    - Staggered ALWAYS saves tax vs same-year (for > 100k total)
    - Progressive brackets applied correctly
    - Single asset (no staggering possible)
    - 4+ assets
    - Chiffre choc shows correct delta
    - Compliance (no banned terms, hypotheses, disclaimer)
    - Edge cases: all assets 0, single asset 1M+

Sources:
    - LIFD art. 38 (imposition separee du capital)
    - OPP3 art. 3 (retrait 3a des 59/60 ans)
    - LPP art. 13 (retraite anticipee des 58 ans)
"""


from app.services.arbitrage.calendrier_retraits import (
    compare_calendrier_retraits,
    RetirementAsset,
)
from app.constants.social_insurance import (
    TAUX_IMPOT_RETRAIT_CAPITAL,
    calculate_progressive_capital_tax,
)


# ═══════════════════════════════════════════════════════════════════════════════
# Test data
# ═══════════════════════════════════════════════════════════════════════════════

BANNED_TERMS = [
    "garanti", "certain", "assure", "sans risque",
    "optimal", "meilleur", "parfait", "conseiller",
]

# Typical scenario: 3 retirement assets
TYPICAL_ASSETS = [
    RetirementAsset(type="3a", amount=150_000, earliest_withdrawal_age=60),
    RetirementAsset(type="lpp", amount=400_000, earliest_withdrawal_age=65),
    RetirementAsset(type="libre_passage", amount=100_000, earliest_withdrawal_age=62),
]


# ═══════════════════════════════════════════════════════════════════════════════
# Core comparison tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestCalendrierRetraitsCore:
    """Test core comparison logic."""

    def test_returns_two_options(self):
        """Must return exactly 2 options: same_year and staggered."""
        result = compare_calendrier_retraits(assets=TYPICAL_ASSETS)
        assert len(result.options) == 2
        assert result.options[0].id == "same_year"
        assert result.options[1].id == "staggered"

    def test_staggered_always_saves_tax_above_100k(self):
        """Staggered withdrawals must save tax vs same-year when total > 100k."""
        assets = [
            RetirementAsset(type="3a", amount=150_000, earliest_withdrawal_age=60),
            RetirementAsset(type="lpp", amount=400_000, earliest_withdrawal_age=65),
        ]
        result = compare_calendrier_retraits(assets=assets)
        same_year_tax = result.options[0].cumulative_tax_impact
        staggered_tax = result.options[1].cumulative_tax_impact
        assert staggered_tax <= same_year_tax

    def test_staggered_saves_significant_amount(self):
        """With large total, staggering should save a significant amount."""
        assets = [
            RetirementAsset(type="3a", amount=200_000, earliest_withdrawal_age=60),
            RetirementAsset(type="lpp", amount=500_000, earliest_withdrawal_age=65),
            RetirementAsset(type="libre_passage", amount=150_000, earliest_withdrawal_age=62),
        ]
        result = compare_calendrier_retraits(assets=assets, canton="VD")
        same_year_tax = result.options[0].cumulative_tax_impact
        staggered_tax = result.options[1].cumulative_tax_impact
        savings = same_year_tax - staggered_tax
        # With 850k in VD, savings should be substantial
        assert savings > 5_000

    def test_progressive_brackets_applied_correctly(self):
        """Same-year tax must match calculate_progressive_capital_tax."""
        assets = TYPICAL_ASSETS
        total = sum(a.amount for a in assets)  # 650'000
        base_rate = TAUX_IMPOT_RETRAIT_CAPITAL["VD"]
        expected_tax = calculate_progressive_capital_tax(total, base_rate)

        result = compare_calendrier_retraits(assets=assets, canton="VD")
        actual_tax = result.options[0].cumulative_tax_impact
        assert abs(actual_tax - expected_tax) < 1.0  # Float rounding tolerance

    def test_chiffre_choc_shows_delta(self):
        """Chiffre choc must show the tax savings delta."""
        result = compare_calendrier_retraits(assets=TYPICAL_ASSETS)
        assert "CHF" in result.chiffre_choc
        assert "economiser" in result.chiffre_choc.lower() or "avantage" in result.chiffre_choc.lower() or "echelonner" in result.chiffre_choc.lower()

    def test_single_asset_no_staggering_benefit(self):
        """With a single asset, staggered should equal same-year."""
        assets = [RetirementAsset(type="lpp", amount=500_000, earliest_withdrawal_age=65)]
        result = compare_calendrier_retraits(assets=assets)
        same_year_tax = result.options[0].cumulative_tax_impact
        staggered_tax = result.options[1].cumulative_tax_impact
        assert abs(same_year_tax - staggered_tax) < 1.0

    def test_four_plus_assets(self):
        """Must handle 4+ assets correctly."""
        assets = [
            RetirementAsset(type="3a", amount=50_000, earliest_withdrawal_age=60),
            RetirementAsset(type="3a", amount=50_000, earliest_withdrawal_age=61),
            RetirementAsset(type="libre_passage", amount=100_000, earliest_withdrawal_age=62),
            RetirementAsset(type="lpp", amount=300_000, earliest_withdrawal_age=65),
        ]
        result = compare_calendrier_retraits(assets=assets)
        assert len(result.options) == 2
        # Staggered should have multiple trajectory entries
        staggered_traj = result.options[1].trajectory
        assert len(staggered_traj) >= 2  # At least some spread

    def test_staggered_net_higher_than_same_year(self):
        """Staggered terminal value must be >= same-year terminal value."""
        result = compare_calendrier_retraits(assets=TYPICAL_ASSETS)
        same_year_terminal = result.options[0].terminal_value
        staggered_terminal = result.options[1].terminal_value
        assert staggered_terminal >= same_year_terminal - 1.0  # Float tolerance


# ═══════════════════════════════════════════════════════════════════════════════
# Canton-specific tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestCantonImpact:
    """Test canton impact on tax calculations."""

    def test_zg_lower_tax_than_vd(self):
        """Canton ZG must have lower tax than VD."""
        result_vd = compare_calendrier_retraits(
            assets=TYPICAL_ASSETS, canton="VD"
        )
        result_zg = compare_calendrier_retraits(
            assets=TYPICAL_ASSETS, canton="ZG"
        )
        assert result_zg.options[0].cumulative_tax_impact < result_vd.options[0].cumulative_tax_impact

    def test_sensitivity_shows_canton_impact(self):
        """Sensitivity must show canton impact (VD vs ZG)."""
        result = compare_calendrier_retraits(assets=TYPICAL_ASSETS)
        assert "canton_impact_VD_vs_ZG" in result.sensitivity
        assert result.sensitivity["canton_impact_VD_vs_ZG"] > 0


# ═══════════════════════════════════════════════════════════════════════════════
# Compliance tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestCalendrierRetraitsCompliance:
    """Test compliance with MINT rules."""

    def test_no_banned_terms(self):
        """No banned terms in any user-facing text."""
        result = compare_calendrier_retraits(assets=TYPICAL_ASSETS)
        all_text = " ".join([
            result.chiffre_choc,
            result.display_summary,
            result.disclaimer,
            " ".join(result.hypotheses),
            " ".join(result.sources),
            " ".join(o.label for o in result.options),
        ]).lower()
        for term in BANNED_TERMS:
            assert term not in all_text, f"Banned term '{term}' found in output"

    def test_disclaimer_present(self):
        """Disclaimer must mention 'outil educatif' and 'LSFin'."""
        result = compare_calendrier_retraits(assets=TYPICAL_ASSETS)
        assert "outil educatif" in result.disclaimer.lower()
        assert "LSFin" in result.disclaimer

    def test_hypotheses_populated(self):
        """Hypotheses list must include asset schedule."""
        result = compare_calendrier_retraits(assets=TYPICAL_ASSETS)
        assert len(result.hypotheses) >= 5
        hyp_text = " ".join(result.hypotheses).lower()
        assert "3a" in hyp_text
        assert "lpp" in hyp_text

    def test_sources_reference_lifd(self):
        """Sources must reference LIFD art. 38."""
        result = compare_calendrier_retraits(assets=TYPICAL_ASSETS)
        sources_text = " ".join(result.sources)
        assert "LIFD art. 38" in sources_text

    def test_confidence_score_populated(self):
        """Confidence score must be > 0 when assets are provided."""
        result = compare_calendrier_retraits(assets=TYPICAL_ASSETS)
        assert result.confidence_score > 0


# ═══════════════════════════════════════════════════════════════════════════════
# Edge case tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestCalendrierRetraitsEdgeCases:
    """Test edge cases and boundary conditions."""

    def test_all_assets_zero(self):
        """Must handle all-zero assets gracefully."""
        assets = [
            RetirementAsset(type="3a", amount=0, earliest_withdrawal_age=60),
            RetirementAsset(type="lpp", amount=0, earliest_withdrawal_age=65),
        ]
        result = compare_calendrier_retraits(assets=assets)
        assert len(result.options) == 2
        assert result.options[0].terminal_value == 0.0

    def test_single_large_asset(self):
        """Must handle single asset > 1M."""
        assets = [RetirementAsset(type="lpp", amount=1_500_000, earliest_withdrawal_age=65)]
        result = compare_calendrier_retraits(assets=assets)
        assert len(result.options) == 2
        # Tax should be substantial
        assert result.options[0].cumulative_tax_impact > 50_000

    def test_invalid_canton_falls_back(self):
        """Invalid canton must fall back to VD."""
        result = compare_calendrier_retraits(
            assets=TYPICAL_ASSETS,
            canton="XX",
        )
        hyp_text = " ".join(result.hypotheses)
        assert "VD" in hyp_text

    def test_married_reduces_tax(self):
        """Married status should reduce tax (splitting)."""
        result_single = compare_calendrier_retraits(
            assets=TYPICAL_ASSETS, is_married=False,
        )
        result_married = compare_calendrier_retraits(
            assets=TYPICAL_ASSETS, is_married=True,
        )
        single_tax = result_single.options[0].cumulative_tax_impact
        married_tax = result_married.options[0].cumulative_tax_impact
        assert married_tax < single_tax
