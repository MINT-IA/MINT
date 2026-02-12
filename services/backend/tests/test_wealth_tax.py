"""
Tests for Wealth Tax Service + Church Tax Service — Chantier 1.

Covers:
    - Wealth tax estimation (single, married, all 26 cantons)
    - Exemption thresholds
    - Wealth level adjustments
    - Comparison rankings
    - Move simulations
    - Church tax estimation (all cantons, mandatory vs voluntary)
    - Compliance checks (disclaimer, sources, chiffre_choc, banned terms)
    - Edge cases (zero, negative, invalid canton)

Sources tested:
    - LHID art. 14 (impot sur la fortune)
    - OFS — Charge fiscale en Suisse 2024
    - Lois fiscales cantonales (impot ecclesiastique)
"""

import pytest

from app.services.fiscal.wealth_tax_service import (
    WealthTaxService,
    WealthTaxEstimate,
    WealthTaxRanking,
    WealthTaxMoveSimulation,
    EFFECTIVE_WEALTH_TAX_RATES_500K,
    WEALTH_TAX_EXEMPTIONS,
    WEALTH_ADJUSTMENT,
    CANTON_NAMES,
    DISCLAIMER as WEALTH_DISCLAIMER,
    SOURCES as WEALTH_SOURCES,
    estimer_impot_fortune,
    comparer_fortune_cantons,
)

from app.services.fiscal.church_tax_service import (
    ChurchTaxService,
    ChurchTaxEstimate,
    CHURCH_TAX_RATES,
    NO_MANDATORY_CHURCH_TAX,
    DISCLAIMER as CHURCH_DISCLAIMER,
    SOURCES as CHURCH_SOURCES,
    estimer_impot_eglise,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def wealth_service():
    return WealthTaxService()


@pytest.fixture
def church_service():
    return ChurchTaxService()


# ===========================================================================
# WEALTH TAX — Basic estimation
# ===========================================================================

class TestWealthTaxEstimateBasic:
    """Basic wealth tax estimation tests."""

    def test_estimate_basic_zg_500k(self, wealth_service):
        """Test basic estimate: single, 500k, ZG — known low-tax canton."""
        result = wealth_service.estimate_wealth_tax(500_000, "ZG")
        assert isinstance(result, WealthTaxEstimate)
        assert result.canton == "ZG"
        assert result.canton_name == "Zoug"
        assert result.fortune_nette == 500_000
        # ZG has no exemption, rate = 1.10 per mille, adjustment = 1.0
        # fortune_imposable = 500000, impot = 500000 * 1.10 / 1000 = 550
        assert result.impot_fortune == 550.0
        assert result.fortune_imposable == 500_000

    def test_estimate_basic_bs_500k(self, wealth_service):
        """Test basic estimate: single, 500k, BS — known high-tax canton."""
        result = wealth_service.estimate_wealth_tax(500_000, "BS")
        assert isinstance(result, WealthTaxEstimate)
        assert result.canton == "BS"
        # BS exemption = 100000, fortune_imposable = 400000
        # rate = 5.10 per mille, impot = 400000 * 5.10 / 1000 = 2040
        assert result.fortune_imposable == 400_000
        assert result.impot_fortune == 2040.0

    def test_estimate_zh_500k(self, wealth_service):
        """Test ZH: single, 500k, exemption 77000."""
        result = wealth_service.estimate_wealth_tax(500_000, "ZH")
        assert result.canton == "ZH"
        assert result.fortune_imposable == 500_000 - 77_000  # 423000
        assert result.impot_fortune > 0

    def test_estimate_all_26_cantons(self, wealth_service):
        """Test that all 26 cantons return valid estimates."""
        for canton in EFFECTIVE_WEALTH_TAX_RATES_500K:
            result = wealth_service.estimate_wealth_tax(500_000, canton)
            assert isinstance(result, WealthTaxEstimate)
            assert result.canton == canton
            assert result.canton_name == CANTON_NAMES[canton]
            assert result.fortune_nette == 500_000
            assert result.impot_fortune >= 0
            assert result.taux_effectif_permille >= 0

    def test_estimate_case_insensitive(self, wealth_service):
        """Test that canton codes are case insensitive."""
        result_upper = wealth_service.estimate_wealth_tax(500_000, "ZH")
        result_lower = wealth_service.estimate_wealth_tax(500_000, "zh")
        assert result_upper.impot_fortune == result_lower.impot_fortune


# ===========================================================================
# WEALTH TAX — Exemption thresholds
# ===========================================================================

class TestWealthTaxExemptions:
    """Tests for wealth tax exemption thresholds."""

    def test_exemption_threshold_zh(self, wealth_service):
        """Fortune below ZH exemption (77k) = 0 tax."""
        result = wealth_service.estimate_wealth_tax(70_000, "ZH")
        assert result.impot_fortune == 0.0
        assert result.fortune_imposable == 0.0

    def test_exemption_threshold_bs(self, wealth_service):
        """Fortune below BS exemption (100k) = 0 tax."""
        result = wealth_service.estimate_wealth_tax(90_000, "BS")
        assert result.impot_fortune == 0.0
        assert result.fortune_imposable == 0.0

    def test_exemption_threshold_ge(self, wealth_service):
        """Fortune below GE exemption (82040) = 0 tax."""
        result = wealth_service.estimate_wealth_tax(80_000, "GE")
        assert result.impot_fortune == 0.0

    def test_no_exemption_lu(self, wealth_service):
        """LU has no exemption: any fortune > 0 should have tax."""
        result = wealth_service.estimate_wealth_tax(10_000, "LU")
        assert result.fortune_imposable == 10_000
        assert result.impot_fortune > 0

    def test_no_exemption_zg(self, wealth_service):
        """ZG has no exemption: any fortune > 0 should have tax."""
        result = wealth_service.estimate_wealth_tax(1_000, "ZG")
        assert result.fortune_imposable == 1_000
        assert result.impot_fortune > 0

    def test_exemption_exactly_at_threshold(self, wealth_service):
        """Fortune exactly at exemption = 0 tax (fortune_imposable = 0)."""
        # ZH exemption = 77000
        result = wealth_service.estimate_wealth_tax(77_000, "ZH")
        assert result.impot_fortune == 0.0
        assert result.fortune_imposable == 0.0

    def test_exemption_just_above_threshold(self, wealth_service):
        """Fortune above exemption should have positive fortune_imposable."""
        # ZH exemption = 77000, 78000 is above threshold
        result = wealth_service.estimate_wealth_tax(78_000, "ZH")
        assert result.fortune_imposable == 1_000.0
        assert result.impot_fortune > 0

    def test_married_doubling_exemption_zh(self, wealth_service):
        """Married couples: exemption doubled. ZH = 77000*2 = 154000."""
        result = wealth_service.estimate_wealth_tax(
            150_000, "ZH", civil_status="marie"
        )
        # 150k < 154k (doubled exemption)
        assert result.impot_fortune == 0.0
        assert result.fortune_imposable == 0.0

    def test_married_doubling_exemption_bs(self, wealth_service):
        """Married couples: BS exemption doubled = 200000."""
        result = wealth_service.estimate_wealth_tax(
            190_000, "BS", civil_status="marie"
        )
        assert result.impot_fortune == 0.0
        assert result.fortune_imposable == 0.0

    def test_married_above_doubled_exemption(self, wealth_service):
        """Married, fortune above doubled exemption, should pay tax."""
        result = wealth_service.estimate_wealth_tax(
            200_000, "ZH", civil_status="marie"
        )
        # Exemption = 154000, fortune_imposable = 46000
        assert result.fortune_imposable == 200_000 - 154_000
        assert result.impot_fortune > 0


# ===========================================================================
# WEALTH TAX — Wealth levels
# ===========================================================================

class TestWealthTaxLevels:
    """Tests for different wealth levels and adjustment factors."""

    def test_high_wealth_5m(self, wealth_service):
        """5M fortune should have higher effective rate (factor 1.35)."""
        result_500k = wealth_service.estimate_wealth_tax(500_000, "ZG")
        result_5m = wealth_service.estimate_wealth_tax(5_000_000, "ZG")
        # 5M should produce much more tax than 10x the 500k tax
        # because the adjustment factor is 1.35 at 5M vs 1.0 at 500k
        assert result_5m.impot_fortune > result_500k.impot_fortune * 10

    def test_low_wealth_100k(self, wealth_service):
        """100k fortune: should have lower effective rate (factor 0.60)."""
        # Use LU (no exemption) for clean test
        result = wealth_service.estimate_wealth_tax(100_000, "LU")
        # Rate = 1.70 * 0.60 = 1.02 per mille
        # impot = 100000 * 1.02 / 1000 = 102
        assert result.impot_fortune == 102.0

    def test_wealth_adjustment_interpolation(self, wealth_service):
        """Fortune between brackets should be interpolated."""
        # 300k is between 200k (0.75) and 500k (1.00)
        # ratio = (300000-200000)/(500000-200000) = 1/3
        # factor = 0.75 + 1/3 * (1.00 - 0.75) = 0.75 + 0.0833 = 0.8333
        result = wealth_service.estimate_wealth_tax(300_000, "LU")
        # Rate = 1.70 * 0.8333 = 1.4167 per mille
        # impot = 300000 * 1.4167 / 1000 = 425.0
        assert result.impot_fortune == pytest.approx(425.0, abs=1.0)


# ===========================================================================
# WEALTH TAX — Comparison rankings
# ===========================================================================

class TestWealthTaxComparison:
    """Tests for 26-canton comparison."""

    def test_compare_rankings_ordered(self, wealth_service):
        """Rankings should be sorted by tax ascending."""
        rankings = wealth_service.compare_all_cantons(500_000)
        assert len(rankings) == 26
        for i in range(len(rankings) - 1):
            assert rankings[i].impot_fortune <= rankings[i + 1].impot_fortune

    def test_compare_rankings_rang_sequential(self, wealth_service):
        """Rang should be sequential 1..26."""
        rankings = wealth_service.compare_all_cantons(500_000)
        for i, r in enumerate(rankings):
            assert r.rang == i + 1

    def test_compare_cheapest_is_nw_or_zg(self, wealth_service):
        """NW or OW or ZG should be among the cheapest for 500k."""
        rankings = wealth_service.compare_all_cantons(500_000)
        top_3_cantons = {r.canton for r in rankings[:3]}
        # NW has lowest rate but ZG has no exemption; both should be near top
        assert len(top_3_cantons & {"NW", "ZG", "OW"}) >= 1

    def test_bs_most_expensive(self, wealth_service):
        """BS should be the most expensive or near the bottom for 500k."""
        rankings = wealth_service.compare_all_cantons(500_000)
        bottom_3_cantons = {r.canton for r in rankings[-3:]}
        assert "BS" in bottom_3_cantons

    def test_compare_difference_vs_cheapest(self, wealth_service):
        """First entry should have difference_vs_cheapest = 0."""
        rankings = wealth_service.compare_all_cantons(500_000)
        assert rankings[0].difference_vs_cheapest == 0.0
        assert rankings[-1].difference_vs_cheapest > 0


# ===========================================================================
# WEALTH TAX — Move simulation
# ===========================================================================

class TestWealthTaxMoveSimulation:
    """Tests for wealth tax move simulation."""

    def test_move_zh_to_zg_saves_money(self, wealth_service):
        """Moving from ZH to ZG should save money on wealth tax."""
        sim = wealth_service.simulate_move_wealth(500_000, "ZH", "ZG")
        assert isinstance(sim, WealthTaxMoveSimulation)
        assert sim.economie_annuelle > 0  # ZG cheaper than ZH
        assert sim.economie_mensuelle > 0
        assert sim.economie_10_ans > 0

    def test_move_zg_to_bs_costs_more(self, wealth_service):
        """Moving from ZG to BS should cost more on wealth tax."""
        sim = wealth_service.simulate_move_wealth(500_000, "ZG", "BS")
        assert sim.economie_annuelle < 0  # BS more expensive

    def test_move_same_canton(self, wealth_service):
        """Moving to the same canton should have 0 savings."""
        sim = wealth_service.simulate_move_wealth(500_000, "ZH", "ZH")
        assert sim.economie_annuelle == 0.0

    def test_move_monthly_is_annual_div_12(self, wealth_service):
        """Monthly savings should be annual / 12."""
        sim = wealth_service.simulate_move_wealth(500_000, "ZH", "ZG")
        assert sim.economie_mensuelle == pytest.approx(
            sim.economie_annuelle / 12, abs=0.01
        )

    def test_move_10_years_is_annual_x_10(self, wealth_service):
        """10-year savings should be annual * 10."""
        sim = wealth_service.simulate_move_wealth(500_000, "ZH", "ZG")
        assert sim.economie_10_ans == pytest.approx(
            sim.economie_annuelle * 10, abs=0.01
        )

    def test_move_has_alertes(self, wealth_service):
        """Move simulation should include alerts."""
        sim = wealth_service.simulate_move_wealth(500_000, "ZH", "ZG")
        assert len(sim.alertes) > 0

    def test_move_high_wealth_bouclier_alert(self, wealth_service):
        """High wealth (>1M) should trigger bouclier fiscal alert."""
        sim = wealth_service.simulate_move_wealth(2_000_000, "ZH", "ZG")
        bouclier_alerts = [a for a in sim.alertes if "bouclier" in a.lower()]
        assert len(bouclier_alerts) > 0


# ===========================================================================
# WEALTH TAX — Edge cases
# ===========================================================================

class TestWealthTaxEdgeCases:
    """Edge case tests."""

    def test_zero_fortune(self, wealth_service):
        """Zero fortune should return 0 tax."""
        result = wealth_service.estimate_wealth_tax(0, "ZH")
        assert result.impot_fortune == 0.0
        assert result.fortune_imposable == 0.0
        assert result.fortune_nette == 0.0

    def test_negative_fortune_raises(self, wealth_service):
        """Negative fortune should raise ValueError."""
        with pytest.raises(ValueError, match="negative"):
            wealth_service.estimate_wealth_tax(-10_000, "ZH")

    def test_invalid_canton_raises(self, wealth_service):
        """Invalid canton should raise ValueError."""
        with pytest.raises(ValueError, match="Canton inconnu"):
            wealth_service.estimate_wealth_tax(500_000, "XX")

    def test_very_small_fortune(self, wealth_service):
        """Very small fortune (1 CHF) in canton without exemption."""
        result = wealth_service.estimate_wealth_tax(1, "LU")
        assert result.impot_fortune >= 0

    def test_very_large_fortune(self, wealth_service):
        """Very large fortune (100M) should produce a valid result."""
        result = wealth_service.estimate_wealth_tax(100_000_000, "GE")
        assert result.impot_fortune > 0
        assert isinstance(result.impot_fortune, float)


# ===========================================================================
# WEALTH TAX — Convenience functions
# ===========================================================================

class TestWealthTaxConvenienceFunctions:
    """Tests for functional-style convenience wrappers."""

    def test_estimer_impot_fortune(self):
        """Test the convenience function returns a dict."""
        result = estimer_impot_fortune(500_000, "ZH")
        assert isinstance(result, dict)
        assert "canton" in result
        assert "impot_fortune" in result
        assert "disclaimer" in result
        assert "sources" in result
        assert "chiffre_choc" in result

    def test_comparer_fortune_cantons(self):
        """Test the convenience comparison function returns ranked dict."""
        result = comparer_fortune_cantons(500_000)
        assert isinstance(result, dict)
        assert "classement" in result
        assert len(result["classement"]) == 26
        assert "ecart_max" in result


# ===========================================================================
# CHURCH TAX — Basic estimation
# ===========================================================================

class TestChurchTaxEstimateBasic:
    """Basic church tax estimation tests."""

    def test_church_tax_basic_zh(self, church_service):
        """Single, 10k cantonal tax, ZH = 10% = 1000 church tax."""
        result = church_service.estimate_church_tax(10_000, "ZH")
        assert isinstance(result, ChurchTaxEstimate)
        assert result.canton == "ZH"
        assert result.canton_name == "Zurich"
        assert result.is_mandatory is True
        assert result.church_tax_rate == 0.10
        assert result.impot_eglise == 1000.0

    def test_church_tax_be(self, church_service):
        """BE = 15% of cantonal tax."""
        result = church_service.estimate_church_tax(10_000, "BE")
        assert result.impot_eglise == 1500.0
        assert result.church_tax_rate == 0.15

    def test_church_tax_all_26_cantons(self, church_service):
        """All 26 cantons should return valid estimates."""
        for canton in CHURCH_TAX_RATES:
            result = church_service.estimate_church_tax(10_000, canton)
            assert isinstance(result, ChurchTaxEstimate)
            assert result.canton == canton
            assert result.impot_eglise >= 0


# ===========================================================================
# CHURCH TAX — Mandatory vs voluntary
# ===========================================================================

class TestChurchTaxMandatory:
    """Tests for mandatory vs voluntary church tax."""

    def test_no_mandatory_ti(self, church_service):
        """TI: church tax is voluntary, should be 0."""
        result = church_service.estimate_church_tax(10_000, "TI")
        assert result.is_mandatory is False
        assert result.impot_eglise == 0.0

    def test_no_mandatory_vd(self, church_service):
        """VD: church tax is voluntary, should be 0."""
        result = church_service.estimate_church_tax(10_000, "VD")
        assert result.is_mandatory is False
        assert result.impot_eglise == 0.0

    def test_no_mandatory_ne(self, church_service):
        """NE: church tax is voluntary, should be 0."""
        result = church_service.estimate_church_tax(10_000, "NE")
        assert result.is_mandatory is False
        assert result.impot_eglise == 0.0

    def test_no_mandatory_ge(self, church_service):
        """GE: church tax is voluntary, should be 0."""
        result = church_service.estimate_church_tax(10_000, "GE")
        assert result.is_mandatory is False
        assert result.impot_eglise == 0.0

    def test_mandatory_zh(self, church_service):
        """ZH: church tax is mandatory, should be > 0."""
        result = church_service.estimate_church_tax(10_000, "ZH")
        assert result.is_mandatory is True
        assert result.impot_eglise > 0

    def test_mandatory_be(self, church_service):
        """BE: church tax is mandatory, should be > 0."""
        result = church_service.estimate_church_tax(10_000, "BE")
        assert result.is_mandatory is True
        assert result.impot_eglise > 0

    def test_is_church_tax_mandatory_function(self, church_service):
        """Test the is_church_tax_mandatory() method."""
        assert church_service.is_church_tax_mandatory("ZH") is True
        assert church_service.is_church_tax_mandatory("TI") is False
        assert church_service.is_church_tax_mandatory("GE") is False
        assert church_service.is_church_tax_mandatory("BE") is True

    def test_no_mandatory_set_matches_rates(self):
        """All cantons in NO_MANDATORY_CHURCH_TAX should have rate = 0."""
        for canton in NO_MANDATORY_CHURCH_TAX:
            assert CHURCH_TAX_RATES[canton] == 0.0, (
                f"Canton {canton} is in NO_MANDATORY_CHURCH_TAX "
                f"but has rate {CHURCH_TAX_RATES[canton]}"
            )


# ===========================================================================
# CHURCH TAX — Edge cases
# ===========================================================================

class TestChurchTaxEdgeCases:
    """Church tax edge case tests."""

    def test_zero_cantonal_tax(self, church_service):
        """Zero cantonal tax = zero church tax."""
        result = church_service.estimate_church_tax(0, "ZH")
        assert result.impot_eglise == 0.0

    def test_negative_cantonal_tax_raises(self, church_service):
        """Negative cantonal tax should raise ValueError."""
        with pytest.raises(ValueError, match="negatif"):
            church_service.estimate_church_tax(-1000, "ZH")

    def test_invalid_canton_raises(self, church_service):
        """Invalid canton should raise ValueError."""
        with pytest.raises(ValueError, match="Canton inconnu"):
            church_service.estimate_church_tax(10_000, "XX")

    def test_convenience_function_estimer_impot_eglise(self):
        """Test the convenience function returns a dict."""
        result = estimer_impot_eglise(10_000, "ZH")
        assert isinstance(result, dict)
        assert result["impot_eglise"] == 1000.0
        assert "disclaimer" in result
        assert "sources" in result


# ===========================================================================
# COMPLIANCE — Disclaimer, sources, chiffre_choc, banned terms
# ===========================================================================

class TestComplianceWealth:
    """Compliance checks for wealth tax outputs."""

    def test_disclaimer_present(self, wealth_service):
        """Every wealth tax estimate must have a disclaimer."""
        result = wealth_service.estimate_wealth_tax(500_000, "ZH")
        assert result.disclaimer
        assert len(result.disclaimer) > 20
        assert "ne constitue pas un conseil" in result.disclaimer.lower()

    def test_disclaimer_mentions_educatif(self, wealth_service):
        """Disclaimer must mention 'outil educatif'."""
        result = wealth_service.estimate_wealth_tax(500_000, "ZH")
        assert "educatif" in result.disclaimer.lower()

    def test_disclaimer_mentions_lsfin(self, wealth_service):
        """Disclaimer must mention LSFin."""
        result = wealth_service.estimate_wealth_tax(500_000, "ZH")
        assert "lsfin" in result.disclaimer.lower()

    def test_sources_present(self, wealth_service):
        """Every wealth tax estimate must have sources."""
        result = wealth_service.estimate_wealth_tax(500_000, "ZH")
        assert len(result.sources) >= 2
        # Check for key references
        source_text = " ".join(result.sources).lower()
        assert "lhid" in source_text
        assert "fortune" in source_text

    def test_chiffre_choc_present(self, wealth_service):
        """Every wealth tax estimate must have a chiffre_choc."""
        result = wealth_service.estimate_wealth_tax(500_000, "ZH")
        assert result.chiffre_choc
        assert len(result.chiffre_choc) > 10

    def test_chiffre_choc_for_zero_fortune(self, wealth_service):
        """Chiffre choc should be meaningful even for 0 fortune."""
        result = wealth_service.estimate_wealth_tax(0, "ZH")
        assert result.chiffre_choc
        assert "0 CHF" in result.chiffre_choc

    def test_chiffre_choc_for_below_exemption(self, wealth_service):
        """Chiffre choc for fortune below exemption should mention it."""
        result = wealth_service.estimate_wealth_tax(50_000, "ZH")
        assert result.chiffre_choc
        assert "exoneration" in result.chiffre_choc.lower()

    def test_move_simulation_compliance(self, wealth_service):
        """Move simulation must have disclaimer, sources, chiffre_choc."""
        sim = wealth_service.simulate_move_wealth(500_000, "ZH", "ZG")
        assert sim.disclaimer
        assert len(sim.sources) >= 2
        assert sim.chiffre_choc
        assert len(sim.chiffre_choc) > 10

    def test_no_banned_terms_in_wealth_outputs(self, wealth_service):
        """Scan wealth tax outputs for banned terms."""
        banned = [
            "garanti", "certain", "assure",
            "sans risque", "optimal", "meilleur", "parfait",
            "conseiller",
        ]
        result = wealth_service.estimate_wealth_tax(500_000, "ZH")
        all_text = (
            result.disclaimer
            + result.chiffre_choc
            + " ".join(result.sources)
        ).lower()

        for term in banned:
            assert term not in all_text, (
                f"Banned term '{term}' found in wealth tax output"
            )

    def test_no_banned_terms_in_church_outputs(self, church_service):
        """Scan church tax outputs for banned terms."""
        banned = [
            "garanti", "certain", "assure",
            "sans risque", "optimal", "meilleur", "parfait",
            "conseiller",
        ]
        result = church_service.estimate_church_tax(10_000, "ZH")
        all_text = (
            result.disclaimer
            + result.chiffre_choc
            + " ".join(result.sources)
        ).lower()

        for term in banned:
            assert term not in all_text, (
                f"Banned term '{term}' found in church tax output"
            )


class TestComplianceChurch:
    """Compliance checks for church tax outputs."""

    def test_church_disclaimer_present(self, church_service):
        """Every church tax estimate must have a disclaimer."""
        result = church_service.estimate_church_tax(10_000, "ZH")
        assert result.disclaimer
        assert "ne constitue pas un conseil" in result.disclaimer.lower()

    def test_church_sources_present(self, church_service):
        """Every church tax estimate must have sources."""
        result = church_service.estimate_church_tax(10_000, "ZH")
        assert len(result.sources) >= 2

    def test_church_chiffre_choc_present(self, church_service):
        """Every church tax estimate must have a chiffre_choc."""
        result = church_service.estimate_church_tax(10_000, "ZH")
        assert result.chiffre_choc
        assert len(result.chiffre_choc) > 10

    def test_church_uses_specialiste_not_conseiller(self, church_service):
        """Disclaimer must use 'specialiste' not 'conseiller'."""
        result = church_service.estimate_church_tax(10_000, "ZH")
        assert "specialiste" in result.disclaimer.lower()
        assert "conseiller" not in result.disclaimer.lower()

    def test_wealth_uses_specialiste_not_conseiller(self, wealth_service):
        """Disclaimer must use 'specialiste' not 'conseiller'."""
        result = wealth_service.estimate_wealth_tax(500_000, "ZH")
        assert "specialiste" in result.disclaimer.lower()
        assert "conseiller" not in result.disclaimer.lower()


# ===========================================================================
# DATA INTEGRITY — Constants coverage
# ===========================================================================

class TestDataIntegrity:
    """Tests for data consistency across constants."""

    def test_all_26_cantons_in_wealth_rates(self):
        """All 26 cantons must have wealth tax rates."""
        assert len(EFFECTIVE_WEALTH_TAX_RATES_500K) == 26

    def test_all_26_cantons_in_exemptions(self):
        """All 26 cantons must have exemption thresholds."""
        assert len(WEALTH_TAX_EXEMPTIONS) == 26

    def test_all_26_cantons_in_church_rates(self):
        """All 26 cantons must have church tax rates."""
        assert len(CHURCH_TAX_RATES) == 26

    def test_canton_names_match_rates(self):
        """All cantons in rates should have names."""
        for canton in EFFECTIVE_WEALTH_TAX_RATES_500K:
            assert canton in CANTON_NAMES, f"Canton {canton} missing from CANTON_NAMES"

    def test_exemptions_match_rates(self):
        """All cantons in rates should have exemptions."""
        for canton in EFFECTIVE_WEALTH_TAX_RATES_500K:
            assert canton in WEALTH_TAX_EXEMPTIONS, (
                f"Canton {canton} missing from WEALTH_TAX_EXEMPTIONS"
            )

    def test_exemptions_non_negative(self):
        """All exemption thresholds should be >= 0."""
        for canton, exemption in WEALTH_TAX_EXEMPTIONS.items():
            assert exemption >= 0, f"Canton {canton} has negative exemption"

    def test_rates_positive(self):
        """All wealth tax rates should be > 0."""
        for canton, rate in EFFECTIVE_WEALTH_TAX_RATES_500K.items():
            assert rate > 0, f"Canton {canton} has non-positive rate"

    def test_wealth_adjustment_has_500k_reference(self):
        """Wealth adjustment must have 500k as reference (factor 1.0)."""
        assert 500000 in WEALTH_ADJUSTMENT
        assert WEALTH_ADJUSTMENT[500000] == 1.0

    def test_wealth_adjustment_monotonically_increasing(self):
        """Higher wealth should have higher adjustment factor."""
        sorted_brackets = sorted(WEALTH_ADJUSTMENT.items())
        for i in range(len(sorted_brackets) - 1):
            assert sorted_brackets[i][1] <= sorted_brackets[i + 1][1], (
                f"Adjustment not monotonically increasing at "
                f"{sorted_brackets[i][0]} -> {sorted_brackets[i + 1][0]}"
            )
