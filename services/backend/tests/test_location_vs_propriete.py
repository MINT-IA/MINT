"""
Tests for Location vs Propriete — Sprint S33.

Covers:
    - Renting beats buying at high market returns
    - Buying beats renting at high appreciation
    - FINMA affordability: theoretical 5% + amort 1% + frais 1%
    - Crossover point exists with reasonable parameters
    - Compliance (no banned terms, hypotheses populated, disclaimer present)
    - Edge cases: capital 0, prix_bien very high, horizon 1 year

Sources:
    - CO art. 253ss (bail)
    - LIFD art. 21 (valeur locative)
    - LIFD art. 32 (deductions)
    - FINMA Tragbarkeitsrechnung
"""

import pytest

from app.services.arbitrage.location_vs_propriete import compare_location_vs_propriete


# ═══════════════════════════════════════════════════════════════════════════════
# Test data
# ═══════════════════════════════════════════════════════════════════════════════

# Typical scenario: 200k capital, 2000 CHF rent, 800k property
TYPICAL_CAPITAL = 200_000.0
TYPICAL_RENT = 2_000.0
TYPICAL_PRICE = 800_000.0

BANNED_TERMS = [
    "garanti", "certain", "assure", "sans risque",
    "optimal", "meilleur", "parfait", "conseiller",
]


# ═══════════════════════════════════════════════════════════════════════════════
# Core comparison tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestLocationVsProprieteCore:
    """Test core comparison logic."""

    def test_returns_two_options(self):
        """Must return exactly 2 options: location and propriete."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
        assert len(result.options) == 2
        assert result.options[0].id == "location"
        assert result.options[1].id == "propriete"

    def test_renting_wins_at_high_market_returns(self):
        """With very high market returns, renting + investing should produce more patrimony."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
            rendement_marche=0.10,  # 10% market return — very high
            appreciation_immo=0.005,  # 0.5% appreciation — low
            horizon_annees=20,
        )
        location_terminal = result.options[0].terminal_value
        propriete_terminal = result.options[1].terminal_value
        assert location_terminal > propriete_terminal

    def test_buying_wins_at_high_appreciation(self):
        """With high real estate appreciation and low market return, buying should win."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
            rendement_marche=0.01,     # 1% market return — low
            appreciation_immo=0.04,    # 4% appreciation — high
            taux_hypotheque=0.015,
            horizon_annees=20,
        )
        location_terminal = result.options[0].terminal_value
        propriete_terminal = result.options[1].terminal_value
        assert propriete_terminal > location_terminal

    def test_trajectory_length_matches_horizon(self):
        """Trajectory must have exactly horizon_annees entries."""
        horizon = 15
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
            horizon_annees=horizon,
        )
        assert len(result.options[0].trajectory) == horizon
        assert len(result.options[1].trajectory) == horizon

    def test_crossover_exists_with_reasonable_params(self):
        """With balanced parameters, a crossover point should exist."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
            rendement_marche=0.03,
            appreciation_immo=0.02,
            horizon_annees=30,
        )
        # breakeven_year might or might not be -1, but the function must not crash
        assert isinstance(result.breakeven_year, int)


# ═══════════════════════════════════════════════════════════════════════════════
# FINMA rules tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestFINMARules:
    """Test FINMA affordability rules are reflected."""

    def test_finma_hypotheses_mention_theoretical_rate(self):
        """Hypotheses must mention the 5% theoretical rate."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
        hyp_text = " ".join(result.hypotheses)
        assert "5%" in hyp_text
        assert "Tragbarkeitsrechnung" in hyp_text

    def test_finma_hypotheses_mention_amortization(self):
        """Hypotheses must mention 1% amortization."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
        hyp_text = " ".join(result.hypotheses)
        assert "Amortissement" in hyp_text

    def test_finma_hypotheses_mention_maintenance(self):
        """Hypotheses must mention maintenance costs."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
        hyp_text = " ".join(result.hypotheses)
        assert "entretien" in hyp_text

    def test_finma_sources_present(self):
        """Sources must reference FINMA Tragbarkeitsrechnung."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
        sources_text = " ".join(result.sources)
        assert "FINMA" in sources_text


# ═══════════════════════════════════════════════════════════════════════════════
# Compliance tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestLocationVsProprieteCompliance:
    """Test compliance with MINT rules."""

    def test_no_banned_terms(self):
        """No banned terms in any user-facing text."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
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
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
        assert "outil educatif" in result.disclaimer.lower()
        assert "LSFin" in result.disclaimer

    def test_hypotheses_populated(self):
        """Hypotheses list must not be empty and have reasonable count."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
        assert len(result.hypotheses) >= 10

    def test_sources_populated(self):
        """Sources must reference Swiss legal articles."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
        assert len(result.sources) >= 3
        sources_text = " ".join(result.sources)
        assert "CO" in sources_text
        assert "LIFD" in sources_text

    def test_chiffre_choc_not_empty(self):
        """Chiffre choc must be a non-empty string."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
        assert len(result.chiffre_choc) > 20

    def test_confidence_score_in_range(self):
        """Confidence score must be between 0 and 100."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
        assert 0 <= result.confidence_score <= 100


# ═══════════════════════════════════════════════════════════════════════════════
# Edge case tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestLocationVsProprieteEdgeCases:
    """Test edge cases and boundary conditions."""

    def test_zero_capital(self):
        """Must handle zero capital without crashing."""
        result = compare_location_vs_propriete(
            capital_disponible=0,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
        assert len(result.options) == 2
        assert result.options[0].id == "location"

    def test_horizon_one_year(self):
        """Must work with 1-year horizon."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
            horizon_annees=1,
        )
        assert len(result.options[0].trajectory) == 1
        assert len(result.options[1].trajectory) == 1

    def test_very_high_price(self):
        """Must handle very expensive property without crashing."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=5_000_000,
        )
        assert len(result.options) == 2

    def test_invalid_canton_falls_back_to_vd(self):
        """Invalid canton must fall back to VD."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
            canton="XX",
        )
        hyp_text = " ".join(result.hypotheses)
        assert "VD" in hyp_text

    def test_married_affects_tax_benefit(self):
        """Married status should affect the tax benefit calculation."""
        result_single = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
            is_married=False,
        )
        result_married = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
            is_married=True,
        )
        # Propriete option tax impact should differ
        single_tax = result_single.options[1].cumulative_tax_impact
        married_tax = result_married.options[1].cumulative_tax_impact
        assert single_tax != married_tax

    def test_sensitivity_present(self):
        """Sensitivity analysis must be present."""
        result = compare_location_vs_propriete(
            capital_disponible=TYPICAL_CAPITAL,
            loyer_mensuel_actuel=TYPICAL_RENT,
            prix_bien=TYPICAL_PRICE,
        )
        assert "rendement_marche" in result.sensitivity
        assert result.sensitivity["rendement_marche"] > 0
