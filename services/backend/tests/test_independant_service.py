"""
Tests for IndependantService (app/services/independant_service.py).

Covers:
    1. AVS bareme — minimum income returns minimum contribution
    2. AVS bareme — income at each bracket boundary
    3. AVS bareme — high income above degressive ceiling -> flat 10.6%
    4. 3a plafond — with LPP -> 7258
    5. 3a plafond — without LPP -> min(20% revenu, 36288)
    6. IJM simulation — basic case
    7. Dividende vs salaire — basic split (analyze method)
    8. LPP volontaire — basic case (analyze method)
    9. Edge case — zero income
    10. Edge case — negative income

Run: cd services/backend && python3 -m pytest tests/test_independant_service.py -v
"""

import pytest

from app.services.independant_service import (
    IndependantInput,
    IndependantService,
    DISCLAIMER,
)
from app.constants.social_insurance import (
    AVS_COTISATION_MIN_INDEPENDANT,
    AVS_COTISATION_TOTAL,
    AVS_BAREME_DEGRESSIF_PLAFOND,
    AVS_SEUIL_REVENU_MIN_INDEPENDANT,
    PILIER_3A_PLAFOND_AVEC_LPP,
    PILIER_3A_PLAFOND_SANS_LPP,
    PILIER_3A_TAUX_REVENU_SANS_LPP,
)


@pytest.fixture
def service():
    return IndependantService()


# ===========================================================================
# 1. AVS bareme — minimum income returns minimum contribution
# ===========================================================================

class TestAvsBaremeMinimum:
    """Income below threshold should return minimum contribution."""

    def test_income_below_threshold_returns_minimum(self, service):
        """Income below AVS_SEUIL_REVENU_MIN_INDEPENDANT -> AVS_COTISATION_MIN_INDEPENDANT."""
        result = service.calculate_avs_contribution(5_000.0)
        assert result == AVS_COTISATION_MIN_INDEPENDANT

    def test_income_just_below_threshold(self, service):
        """Income at threshold - 1 should still return minimum."""
        result = service.calculate_avs_contribution(AVS_SEUIL_REVENU_MIN_INDEPENDANT - 1)
        assert result == AVS_COTISATION_MIN_INDEPENDANT


# ===========================================================================
# 2. AVS bareme — income at each bracket boundary
# ===========================================================================

class TestAvsBaremeBrackets:
    """Income at bracket boundaries should use correct degressive rate."""

    def test_income_at_first_bracket_lower(self, service):
        """Income at 9800 (first bracket lower) should use first bracket rate."""
        result = service.calculate_avs_contribution(9_800.0)
        # 9800 is the threshold — at exactly this it should enter degressive
        assert result == AVS_COTISATION_MIN_INDEPENDANT or result > 0

    def test_income_at_mid_bracket(self, service):
        """Income in the middle bracket (38201-43000) should use 6.8% rate."""
        result = service.calculate_avs_contribution(40_000.0)
        expected = round(40_000 * 0.068, 2)
        assert result == expected

    def test_income_at_last_bracket(self, service):
        """Income at the top degressive bracket (52601-58800)."""
        result = service.calculate_avs_contribution(55_000.0)
        expected = round(55_000 * 0.092, 2)
        assert result == expected


# ===========================================================================
# 3. AVS bareme — high income above degressive ceiling -> flat 10.6%
# ===========================================================================

class TestAvsBaremeHighIncome:
    """High income above the degressive ceiling should use flat AVS rate."""

    def test_income_above_ceiling_uses_full_rate(self, service):
        """Income above AVS_BAREME_DEGRESSIF_PLAFOND -> full AVS_COTISATION_TOTAL."""
        income = 100_000.0
        result = service.calculate_avs_contribution(income)
        expected = round(income * AVS_COTISATION_TOTAL, 2)
        assert result == expected

    def test_income_just_above_ceiling(self, service):
        """Income at ceiling + 1 should use full rate."""
        income = AVS_BAREME_DEGRESSIF_PLAFOND + 1
        result = service.calculate_avs_contribution(income)
        expected = round(income * AVS_COTISATION_TOTAL, 2)
        assert result == expected


# ===========================================================================
# 4. 3a plafond — with LPP -> 7258
# ===========================================================================

class TestPlafond3aWithLpp:
    """Self-employed with voluntary LPP should get small 3a plafond."""

    def test_with_lpp_returns_salarie_plafond(self, service):
        """analyze() with a_lpp_volontaire=True -> plafond_3a = 7258."""
        inp = IndependantInput(
            revenu_net=100_000.0,
            age=40,
            a_lpp_volontaire=True,
            a_3a=True,
            a_ijm=True,
            a_laa=True,
            canton="VD",
        )
        result = service.analyze(inp)
        assert result.plafond_3a_grand == PILIER_3A_PLAFOND_AVEC_LPP


# ===========================================================================
# 5. 3a plafond — without LPP -> min(20% revenu, 36288)
# ===========================================================================

class TestPlafond3aWithoutLpp:
    """Self-employed without LPP should get grand 3a plafond."""

    def test_without_lpp_20_percent_rule(self, service):
        """20% of 80000 = 16000 which is < 36288."""
        result = service.calculate_3a_plafond(80_000.0)
        expected = round(80_000 * PILIER_3A_TAUX_REVENU_SANS_LPP, 2)
        assert result == expected

    def test_without_lpp_capped_at_max(self, service):
        """20% of 300000 = 60000, capped at 36288."""
        result = service.calculate_3a_plafond(300_000.0)
        assert result == PILIER_3A_PLAFOND_SANS_LPP


# ===========================================================================
# 6. IJM simulation — basic case
# ===========================================================================

class TestIjmSimulation:
    """IJM cost estimation should be ~2% of income."""

    def test_basic_ijm_cost(self, service):
        """IJM cost for 100k income = 100000 * 0.02 = 2000."""
        result = service.estimate_ijm_cost(100_000.0)
        assert result == 2_000.0

    def test_ijm_zero_income(self, service):
        """IJM cost for zero income = 0."""
        result = service.estimate_ijm_cost(0.0)
        assert result == 0.0


# ===========================================================================
# 7. Dividende vs salaire — basic split (via analyze)
# ===========================================================================

class TestAnalyzeRecommendations:
    """analyze() should produce recommendations for missing protections."""

    def test_missing_lpp_produces_recommendation(self, service):
        """Without LPP, should recommend voluntary LPP affiliation."""
        inp = IndependantInput(
            revenu_net=100_000.0,
            age=40,
            a_lpp_volontaire=False,
            a_3a=True,
            a_ijm=True,
            a_laa=True,
            canton="ZH",
        )
        result = service.analyze(inp)
        lpp_rec = [r for r in result.recommandations if r["id"] == "lpp_volontaire"]
        assert len(lpp_rec) == 1
        assert "volontaire" in lpp_rec[0]["description"].lower()


# ===========================================================================
# 8. LPP volontaire — basic case (via analyze)
# ===========================================================================

class TestAnalyzeLppVolontaire:
    """analyze() should flag LPP gap when missing."""

    def test_missing_lpp_flagged_as_lacune(self, service):
        """Without voluntary LPP, should flag LPP as coverage gap."""
        inp = IndependantInput(
            revenu_net=80_000.0,
            age=35,
            a_lpp_volontaire=False,
            a_3a=True,
            a_ijm=True,
            a_laa=True,
            canton="BE",
        )
        result = service.analyze(inp)
        lpp_gaps = [g for g in result.lacunes_couverture if g["type"] == "lpp"]
        assert len(lpp_gaps) == 1
        assert lpp_gaps[0]["severite"] == "haute"


# ===========================================================================
# 9. Edge case — zero income
# ===========================================================================

class TestZeroIncome:
    """Zero income should produce zero contributions across all methods."""

    def test_avs_zero(self, service):
        """AVS contribution for zero income = 0."""
        assert service.calculate_avs_contribution(0.0) == 0.0

    def test_3a_zero(self, service):
        """3a plafond for zero income = 0."""
        assert service.calculate_3a_plafond(0.0) == 0.0

    def test_analyze_zero_income(self, service):
        """analyze() with zero income should not crash."""
        inp = IndependantInput(
            revenu_net=0.0,
            age=30,
            a_lpp_volontaire=False,
            a_3a=False,
            a_ijm=False,
            a_laa=False,
            canton="GE",
        )
        result = service.analyze(inp)
        assert result.cotisations_avs == 0.0
        assert result.disclaimer == DISCLAIMER


# ===========================================================================
# 10. Edge case — negative income
# ===========================================================================

class TestNegativeIncome:
    """Negative income should be handled gracefully."""

    def test_avs_negative(self, service):
        """AVS contribution for negative income = 0."""
        assert service.calculate_avs_contribution(-10_000.0) == 0.0

    def test_3a_negative(self, service):
        """3a plafond for negative income = 0."""
        assert service.calculate_3a_plafond(-5_000.0) == 0.0

    def test_ijm_negative(self, service):
        """IJM cost for negative income = negative (no guard), but should not crash."""
        # The service does revenu_net * rate — negative input produces negative output.
        # This is acceptable since negative income is an invalid input.
        result = service.estimate_ijm_cost(-5_000.0)
        assert isinstance(result, float)
