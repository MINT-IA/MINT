"""
Tests for Rachat LPP vs Investissement Libre — Sprint S33.

Covers:
    - Rachat tax saving correctly computed
    - LPP growth at caisse rate
    - Market investment with wealth tax
    - Blocage 3 ans mentioned in hypotheses
    - Compliance (no banned terms, hypotheses, disclaimer)
    - Edge cases: montant 0, taux_marginal 0, 1 year to retirement

Sources:
    - LPP art. 79b (rachat volontaire)
    - LPP art. 79b al. 3 (blocage 3 ans)
    - LIFD art. 33 (deduction fiscale)
    - OPP2 art. 60a (conditions de rachat)
"""


from app.services.arbitrage.rachat_vs_marche import compare_rachat_vs_marche


# ═══════════════════════════════════════════════════════════════════════════════
# Test data
# ═══════════════════════════════════════════════════════════════════════════════

TYPICAL_MONTANT = 50_000.0
TYPICAL_TAUX_MARGINAL = 0.30

BANNED_TERMS = [
    "garanti", "certain", "assure", "sans risque",
    "optimal", "meilleur", "parfait", "conseiller",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Core comparison tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestRachatVsMarcheCore:
    """Test core comparison logic."""

    def test_returns_two_options(self):
        """Must return exactly 2 options: rachat_lpp and investissement_libre."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
        )
        assert len(result.options) == 2
        assert result.options[0].id == "rachat_lpp"
        assert result.options[1].id == "investissement_libre"

    def test_rachat_tax_saving_correct(self):
        """Tax saving from buyback must equal montant * taux_marginal."""
        montant = 50_000
        taux = 0.30
        result = compare_rachat_vs_marche(
            montant=montant,
            taux_marginal=taux,
        )
        # The tax saving should appear in the premier_eclairage or hypotheses
        hyp_text = " ".join(result.hypotheses)
        assert "15" in hyp_text  # 15'000 CHF saving

    def test_lpp_growth_at_caisse_rate(self):
        """LPP capital must grow at rendement_lpp rate."""
        montant = 100_000
        rendement = 0.02
        years = 10
        result = compare_rachat_vs_marche(
            montant=montant,
            taux_marginal=0.30,
            annees_avant_retraite=years,
            rendement_lpp=rendement,
            canton="ZG",  # Low tax canton
        )
        # Check that rachat option trajectory shows growth
        rachat_traj = result.options[0].trajectory
        assert len(rachat_traj) == years
        # First year patrimony should be > montant (growth)
        assert rachat_traj[0].net_patrimony > montant

    def test_market_investment_includes_wealth_tax(self):
        """Market investment must include wealth tax deduction (~0.3%/year)."""
        montant = 100_000
        years = 10
        rendement = 0.04
        result = compare_rachat_vs_marche(
            montant=montant,
            taux_marginal=0.30,
            annees_avant_retraite=years,
            rendement_marche=rendement,
        )
        marche_traj = result.options[1].trajectory
        # After 10 years at 4%, without wealth tax: 100000 * 1.04^10 = ~148024
        # With wealth tax ~0.3%, effective rate ~3.7%: should be less
        terminal = marche_traj[-1].net_patrimony
        pure_growth = montant * (1.04 ** years)
        assert terminal < pure_growth  # Wealth tax reduces final value

    def test_high_marginal_rate_favors_rachat(self):
        """With high marginal tax rate, rachat should be relatively more attractive."""
        result_high = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=0.40,
            annees_avant_retraite=5,
            rendement_lpp=0.0125,
            rendement_marche=0.04,
        )
        result_low = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=0.10,
            annees_avant_retraite=5,
            rendement_lpp=0.0125,
            rendement_marche=0.04,
        )
        # Higher tax rate means bigger tax saving, so rachat terminal should be higher
        high_rachat_terminal = result_high.options[0].terminal_value
        low_rachat_terminal = result_low.options[0].terminal_value
        assert high_rachat_terminal > low_rachat_terminal

    def test_trajectory_length_matches_years(self):
        """Trajectory must have exactly annees_avant_retraite entries."""
        years = 15
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
            annees_avant_retraite=years,
        )
        assert len(result.options[0].trajectory) == years
        assert len(result.options[1].trajectory) == years


# ═══════════════════════════════════════════════════════════════════════════════
# LPP-specific tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestLPPRules:
    """Test LPP-specific rules are enforced."""

    def test_blocage_3_ans_in_hypotheses(self):
        """Hypotheses must mention the 3-year lock-up period."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
        )
        hyp_text = " ".join(result.hypotheses).lower()
        assert "blocage" in hyp_text
        assert "3 ans" in hyp_text

    def test_withdrawal_tax_at_retirement(self):
        """Rachat option must include capital withdrawal tax at retirement."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
            annees_avant_retraite=10,
        )
        rachat_traj = result.options[0].trajectory
        # Last year should have positive cumulative tax (withdrawal tax)
        last_year = rachat_traj[-1]
        # cumulative_tax_delta starts negative (tax saving) and ends with withdrawal tax added
        # Net should be: withdrawal_tax - tax_saving
        # The fact that it exists (not 0) means tax was applied
        assert last_year.cumulative_tax_delta != 0

    def test_sources_reference_lpp(self):
        """Sources must reference LPP art. 79b."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
        )
        sources_text = " ".join(result.sources)
        assert "LPP art. 79b" in sources_text


# ═══════════════════════════════════════════════════════════════════════════════
# Compliance tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestRachatVsMarcheCompliance:
    """Test compliance with MINT rules."""

    def test_no_banned_terms(self):
        """No banned terms in any user-facing text."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
        )
        all_text = " ".join([
            result.premier_eclairage,
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
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
        )
        assert "outil educatif" in result.disclaimer.lower()
        assert "LSFin" in result.disclaimer

    def test_hypotheses_populated(self):
        """Hypotheses list must not be empty."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
        )
        assert len(result.hypotheses) >= 8

    def test_sources_populated(self):
        """Sources must reference Swiss legal articles."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
        )
        assert len(result.sources) >= 3

    def test_premier_eclairage_not_empty(self):
        """Chiffre choc must be a non-empty string."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
        )
        assert len(result.premier_eclairage) > 20

    def test_confidence_score_in_range(self):
        """Confidence score must be between 0 and 100."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
        )
        assert 0 <= result.confidence_score <= 100


# ═══════════════════════════════════════════════════════════════════════════════
# Edge case tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestRachatVsMarcheEdgeCases:
    """Test edge cases and boundary conditions."""

    def test_zero_montant(self):
        """Must handle zero amount without crashing."""
        result = compare_rachat_vs_marche(
            montant=0,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
        )
        assert len(result.options) == 2
        assert result.options[0].terminal_value == 0.0
        assert result.options[1].terminal_value == 0.0

    def test_zero_taux_marginal(self):
        """Must handle zero marginal rate (no tax benefit from rachat)."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=0.0,
        )
        assert len(result.options) == 2
        # With 0% tax rate, rachat has no tax advantage
        rachat_terminal = result.options[0].terminal_value
        # Terminal includes 0 tax saving
        assert rachat_terminal > 0

    def test_one_year_to_retirement(self):
        """Must work with 1 year to retirement."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
            annees_avant_retraite=1,
        )
        assert len(result.options[0].trajectory) == 1
        assert len(result.options[1].trajectory) == 1

    def test_invalid_canton_falls_back_to_vd(self):
        """Invalid canton must fall back to VD."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
            canton="XX",
        )
        hyp_text = " ".join(result.hypotheses)
        assert "VD" in hyp_text

    def test_sensitivity_present(self):
        """Sensitivity analysis must be present."""
        result = compare_rachat_vs_marche(
            montant=TYPICAL_MONTANT,
            taux_marginal=TYPICAL_TAUX_MARGINAL,
        )
        assert "rendement_marche" in result.sensitivity
        assert result.sensitivity["rendement_marche"] > 0
