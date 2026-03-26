"""Tests for the Regulatory Registry — single source of truth for Swiss financial constants.

Verifies:
    1. All constants from social_insurance.py are present in the registry.
    2. Values match exactly between registry and social_insurance.py.
    3. All parameters have source_url set.
    4. All parameters have reviewed_at within 90 days.
    5. No expired parameter without a replacement.
    6. All 26 cantonal tax rates are present.
    7. 3a historical limits 2016-2026 are all present.
    8. AVS reference ages are correct.
    9. Freshness check returns empty list (all recently reviewed).
    10. get() returns correct values for each category.
    11. Category filtering works.
    12. Cantonal lookup works.
    13. Unknown key returns None.
    14. LLM tool handler works.
    15. API-compatible serialization works.
    16. Singleton pattern works correctly.

Sources:
    - app/constants/social_insurance.py
    - app/services/regulatory/registry.py
    - app/models/regulatory_parameter.py
"""

import pytest
from datetime import date

from app.models.regulatory_parameter import RegulatoryParameter
from app.services.regulatory.registry import RegulatoryRegistry
from app.constants import social_insurance as si


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def reset_registry():
    """Reset singleton between tests to ensure isolation."""
    RegulatoryRegistry._reset()
    yield
    RegulatoryRegistry._reset()


@pytest.fixture
def registry() -> RegulatoryRegistry:
    """Return a fresh registry instance."""
    return RegulatoryRegistry.instance()


# ---------------------------------------------------------------------------
# 1. All key constants from social_insurance.py are present
# ---------------------------------------------------------------------------


class TestConstantsPresence:
    """Verify every critical constant from social_insurance.py is in the registry."""

    def test_pillar3a_max_with_lpp(self, registry):
        param = registry.get("pillar3a.max_with_lpp")
        assert param is not None
        assert param.value == si.PILIER_3A_PLAFOND_AVEC_LPP

    def test_pillar3a_max_without_lpp(self, registry):
        param = registry.get("pillar3a.max_without_lpp")
        assert param is not None
        assert param.value == si.PILIER_3A_PLAFOND_SANS_LPP

    def test_pillar3a_income_rate(self, registry):
        param = registry.get("pillar3a.income_rate_without_lpp")
        assert param is not None
        assert param.value == si.PILIER_3A_TAUX_REVENU_SANS_LPP

    def test_lpp_entry_threshold(self, registry):
        param = registry.get("lpp.entry_threshold")
        assert param is not None
        assert param.value == si.LPP_SEUIL_ENTREE

    def test_lpp_coordination_deduction(self, registry):
        param = registry.get("lpp.coordination_deduction")
        assert param is not None
        assert param.value == si.LPP_DEDUCTION_COORDINATION

    def test_lpp_min_coordinated_salary(self, registry):
        param = registry.get("lpp.min_coordinated_salary")
        assert param is not None
        assert param.value == si.LPP_SALAIRE_COORDONNE_MIN

    def test_lpp_max_coordinated_salary(self, registry):
        param = registry.get("lpp.max_coordinated_salary")
        assert param is not None
        assert param.value == si.LPP_SALAIRE_COORDONNE_MAX

    def test_lpp_max_insured_salary(self, registry):
        param = registry.get("lpp.max_insured_salary")
        assert param is not None
        assert param.value == si.LPP_SALAIRE_MAX

    def test_lpp_conversion_rate(self, registry):
        param = registry.get("lpp.conversion_rate")
        assert param is not None
        assert param.value == si.LPP_TAUX_CONVERSION_MIN_DECIMAL

    def test_lpp_min_interest_rate(self, registry):
        param = registry.get("lpp.min_interest_rate")
        assert param is not None
        assert param.value == si.LPP_TAUX_INTERET_MIN

    def test_lpp_bonification_25_34(self, registry):
        param = registry.get("lpp.bonification.25_34")
        assert param is not None
        assert param.value == 0.07

    def test_lpp_bonification_35_44(self, registry):
        param = registry.get("lpp.bonification.35_44")
        assert param is not None
        assert param.value == 0.10

    def test_lpp_bonification_45_54(self, registry):
        param = registry.get("lpp.bonification.45_54")
        assert param is not None
        assert param.value == 0.15

    def test_lpp_bonification_55_65(self, registry):
        param = registry.get("lpp.bonification.55_65")
        assert param is not None
        assert param.value == 0.18

    def test_avs_max_monthly_pension(self, registry):
        param = registry.get("avs.max_monthly_pension")
        assert param is not None
        assert param.value == si.AVS_RENTE_MAX_MENSUELLE

    def test_avs_min_monthly_pension(self, registry):
        param = registry.get("avs.min_monthly_pension")
        assert param is not None
        assert param.value == si.AVS_RENTE_MIN_MENSUELLE

    def test_avs_couple_max(self, registry):
        param = registry.get("avs.couple_max_monthly")
        assert param is not None
        assert param.value == si.AVS_RENTE_COUPLE_MAX_MENSUELLE

    def test_avs_contribution_rate(self, registry):
        param = registry.get("avs.contribution_rate_employee")
        assert param is not None
        assert param.value == si.AVS_COTISATION_SALARIE

    def test_avs_full_contribution_years(self, registry):
        param = registry.get("avs.full_contribution_years")
        assert param is not None
        assert param.value == float(si.AVS_DUREE_COTISATION_COMPLETE)

    def test_avs_anticipation_reduction(self, registry):
        param = registry.get("avs.anticipation_reduction")
        assert param is not None
        assert param.value == si.AVS_REDUCTION_ANTICIPATION

    def test_avs_13th_pension(self, registry):
        param = registry.get("avs.13th_pension_active")
        assert param is not None
        assert param.value == 1.0  # True stored as 1.0

    def test_mortgage_theoretical_rate(self, registry):
        param = registry.get("mortgage.theoretical_rate")
        assert param is not None
        assert param.value == si.HYPOTHEQUE_TAUX_THEORIQUE

    def test_mortgage_amortization_rate(self, registry):
        param = registry.get("mortgage.amortization_rate")
        assert param is not None
        assert param.value == si.HYPOTHEQUE_TAUX_AMORTISSEMENT

    def test_mortgage_max_charge_ratio(self, registry):
        param = registry.get("mortgage.max_charge_ratio")
        assert param is not None
        assert abs(param.value - si.HYPOTHEQUE_RATIO_CHARGES_MAX) < 1e-6

    def test_mortgage_min_equity(self, registry):
        param = registry.get("mortgage.min_equity")
        assert param is not None
        assert param.value == si.HYPOTHEQUE_FONDS_PROPRES_MIN

    def test_mortgage_max_2nd_pillar(self, registry):
        param = registry.get("mortgage.max_2nd_pillar")
        assert param is not None
        assert param.value == si.HYPOTHEQUE_PART_2E_PILIER_MAX

    def test_epl_minimum(self, registry):
        param = registry.get("lpp.epl_minimum")
        assert param is not None
        assert param.value == si.EPL_MONTANT_MINIMUM

    def test_epl_buyback_lock(self, registry):
        param = registry.get("lpp.epl_buyback_lock_years")
        assert param is not None
        assert param.value == float(si.EPL_BLOCAGE_RACHAT_ANNEES)

    def test_capital_tax_default_rate(self, registry):
        param = registry.get("capital_tax.default_rate")
        assert param is not None
        assert param.value == si.TAUX_IMPOT_RETRAIT_CAPITAL_DEFAULT

    def test_capital_tax_married_discount(self, registry):
        param = registry.get("capital_tax.married_discount")
        assert param is not None
        assert param.value == si.MARRIED_CAPITAL_TAX_DISCOUNT

    def test_avs_min_contribution_independent(self, registry):
        param = registry.get("avs.min_contribution_independent")
        assert param is not None
        assert param.value == si.AVS_COTISATION_MIN_INDEPENDANT

    def test_lamal_copay_rate(self, registry):
        param = registry.get("lamal.copay_rate")
        assert param is not None
        assert param.value == si.LAMAL_QUOTE_PART_RATE

    def test_lamal_copay_cap_adult(self, registry):
        param = registry.get("lamal.copay_cap_adult")
        assert param is not None
        assert param.value == si.LAMAL_QUOTE_PART_CAP_ADULT

    def test_ai_full_pension(self, registry):
        param = registry.get("ai.full_pension_monthly")
        assert param is not None
        assert param.value == si.AI_RENTE_ENTIERE

    def test_ac_max_insured_salary(self, registry):
        param = registry.get("ac.max_insured_salary")
        assert param is not None
        assert param.value == si.AC_PLAFOND_SALAIRE_ASSURE


# ---------------------------------------------------------------------------
# 2. Values match social_insurance.py
# ---------------------------------------------------------------------------


class TestValueConsistency:
    """Cross-check registry values against social_insurance.py constants."""

    def test_lpp_bonifications_match(self, registry):
        """All 4 LPP bonification rates match LPP_BONIFICATIONS_DICT."""
        for age, rate in si.LPP_BONIFICATIONS_DICT.items():
            if age == 25:
                key = "lpp.bonification.25_34"
            elif age == 35:
                key = "lpp.bonification.35_44"
            elif age == 45:
                key = "lpp.bonification.45_54"
            else:
                key = "lpp.bonification.55_65"
            param = registry.get(key)
            assert param is not None, f"Missing bonification key: {key}"
            assert param.value == rate, f"{key}: {param.value} != {rate}"

    def test_avs_annual_pension_matches(self, registry):
        """AVS annual pension = monthly * 12."""
        param = registry.get("avs.max_annual_pension")
        assert param is not None
        monthly = registry.get("avs.max_monthly_pension")
        assert param.value == monthly.value * 12

    def test_capital_tax_brackets_match(self, registry):
        """Progressive bracket multipliers match social_insurance.py."""
        expected = {
            "capital_tax.bracket.0_100k": 1.00,
            "capital_tax.bracket.100k_200k": 1.15,
            "capital_tax.bracket.200k_500k": 1.30,
            "capital_tax.bracket.500k_1m": 1.50,
            "capital_tax.bracket.1m_plus": 1.70,
        }
        for key, expected_value in expected.items():
            param = registry.get(key)
            assert param is not None, f"Missing bracket: {key}"
            assert param.value == expected_value, f"{key}: {param.value} != {expected_value}"

    def test_avs_deferral_supplements_match(self, registry):
        """AVS deferral supplements match social_insurance.py."""
        for years, rate in si.AVS_SUPPLEMENT_AJOURNEMENT.items():
            key = f"avs.deferral_supplement.{years}"
            param = registry.get(key)
            assert param is not None, f"Missing deferral supplement: {key}"
            assert param.value == rate, f"{key}: {param.value} != {rate}"


# ---------------------------------------------------------------------------
# 3. All parameters have source_url
# ---------------------------------------------------------------------------


class TestMetadataQuality:
    """Every parameter must have complete metadata."""

    def test_all_have_source_url(self, registry):
        """Every parameter must have a non-empty source_url."""
        for param in registry.get_all():
            assert param.source_url, f"Missing source_url for {param.key}"

    def test_all_have_source_title(self, registry):
        """Every parameter must have a non-empty source_title."""
        for param in registry.get_all():
            assert param.source_title, f"Missing source_title for {param.key}"

    def test_all_have_description(self, registry):
        """Every parameter must have a non-empty description."""
        for param in registry.get_all():
            assert param.description, f"Missing description for {param.key}"

    def test_all_have_valid_source_type(self, registry):
        """source_type must be one of the allowed values."""
        allowed = {"law", "ordinance", "circular", "faq", "estimate"}
        for param in registry.get_all():
            assert param.source_type in allowed, (
                f"Invalid source_type '{param.source_type}' for {param.key}"
            )


# ---------------------------------------------------------------------------
# 4. All parameters have reviewed_at within 90 days
# ---------------------------------------------------------------------------


class TestFreshness:
    """All parameters must have been reviewed recently."""

    def test_all_reviewed_within_90_days(self, registry):
        """No parameter should be stale (reviewed_at > 90 days ago)."""
        stale = registry.check_freshness(max_age_days=90)
        stale_keys = [p.key for p in stale]
        assert stale_keys == [], f"Stale parameters: {stale_keys}"

    def test_all_have_reviewed_at(self, registry):
        """Every parameter must have a reviewed_at date."""
        for param in registry.get_all():
            assert param.reviewed_at is not None, (
                f"Missing reviewed_at for {param.key}"
            )

    def test_freshness_check_empty(self, registry):
        """check_freshness returns empty list when all are fresh."""
        stale = registry.check_freshness(max_age_days=90)
        assert len(stale) == 0


# ---------------------------------------------------------------------------
# 5. No expired parameter without replacement
# ---------------------------------------------------------------------------


class TestExpiredParameters:
    """Expired parameters should have a successor (same key, later effective_from)."""

    def test_expired_3a_limits_have_successors(self, registry):
        """Historical 3a limits that are expired should have a newer version."""
        for year in range(2016, 2025):
            key = f"pillar3a.historical_limits.{year}"
            param = registry.get(key)
            assert param is not None, f"Missing historical 3a limit: {key}"
            # Current year's limit should exist
            current = registry.get(f"pillar3a.historical_limits.{year + 1}")
            if year < 2026:
                assert current is not None, (
                    f"No successor for {key}"
                )


# ---------------------------------------------------------------------------
# 6. All 26 cantonal tax rates present
# ---------------------------------------------------------------------------


class TestCantonalTaxRates:
    """All 26 Swiss cantons must have capital withdrawal tax rates."""

    ALL_CANTONS = [
        "ZH", "BE", "LU", "UR", "SZ", "OW", "NW", "GL", "ZG", "FR",
        "SO", "BS", "BL", "SH", "AR", "AI", "SG", "GR", "AG", "TG",
        "TI", "VD", "VS", "NE", "GE", "JU",
    ]

    def test_all_26_cantons_present(self, registry):
        """Every Swiss canton has a capital_tax.cantonal.XX entry."""
        for canton in self.ALL_CANTONS:
            key = f"capital_tax.cantonal.{canton}"
            param = registry.get(key, jurisdiction=canton)
            assert param is not None, f"Missing cantonal tax rate: {canton}"

    def test_cantonal_rates_match_social_insurance(self, registry):
        """Cantonal rates match TAUX_IMPOT_RETRAIT_CAPITAL dict."""
        for canton, expected_rate in si.TAUX_IMPOT_RETRAIT_CAPITAL.items():
            key = f"capital_tax.cantonal.{canton}"
            param = registry.get(key, jurisdiction=canton)
            assert param is not None, f"Missing cantonal rate: {canton}"
            assert param.value == expected_rate, (
                f"{canton}: {param.value} != {expected_rate}"
            )

    def test_cantonal_count_is_26(self, registry):
        """Exactly 26 cantonal tax rate parameters."""
        cantonal = [
            p for p in registry.get_all()
            if p.key.startswith("capital_tax.cantonal.")
        ]
        assert len(cantonal) == 26


# ---------------------------------------------------------------------------
# 7. 3a historical limits 2016-2026 all present
# ---------------------------------------------------------------------------


class TestHistoricalLimits:
    """3a historical limits from 2016 to 2026 must all be present."""

    def test_all_years_present(self, registry):
        """Every year from 2016 to 2026 has a 3a limit."""
        for year in range(2016, 2027):
            key = f"pillar3a.historical_limits.{year}"
            param = registry.get(key)
            assert param is not None, f"Missing 3a historical limit for {year}"

    def test_historical_values_match(self, registry):
        """Historical 3a values match retroactive_3a_service.py."""
        from app.services.pillar_3a_deep.retroactive_3a_service import HISTORICAL_3A_LIMITS

        for year, expected_value in HISTORICAL_3A_LIMITS.items():
            key = f"pillar3a.historical_limits.{year}"
            param = registry.get(key)
            assert param is not None, f"Missing historical limit for {year}"
            assert param.value == expected_value, (
                f"Year {year}: {param.value} != {expected_value}"
            )

    def test_historical_count(self, registry):
        """At least 11 historical limits (2016-2026)."""
        historical = [
            p for p in registry.get_all()
            if p.key.startswith("pillar3a.historical_limits.")
        ]
        assert len(historical) >= 11


# ---------------------------------------------------------------------------
# 8. AVS reference ages correct
# ---------------------------------------------------------------------------


class TestAvsReferenceAges:
    """AVS reference ages must reflect post-AVS 21 reform values."""

    def test_men_reference_age_65(self, registry):
        param = registry.get("avs.reference_age_men")
        assert param is not None
        assert param.value == 65.0

    def test_women_reference_age_65(self, registry):
        """Women's reference age is 65 since AVS 21 reform."""
        param = registry.get("avs.reference_age_women")
        assert param is not None
        assert param.value == 65.0

    def test_gender_equality_post_reform(self, registry):
        """Both genders have the same reference age after AVS 21."""
        men = registry.get("avs.reference_age_men")
        women = registry.get("avs.reference_age_women")
        assert men.value == women.value


# ---------------------------------------------------------------------------
# 9. Freshness check returns empty list
# ---------------------------------------------------------------------------


class TestFreshnessCheck:
    """The freshness check should confirm all parameters are recently reviewed."""

    def test_check_freshness_returns_empty(self, registry):
        stale = registry.check_freshness(max_age_days=90)
        assert stale == []

    def test_stale_detection_works(self):
        """A parameter with old reviewed_at should be flagged stale."""
        param = RegulatoryParameter(
            key="test.stale",
            value=42.0,
            reviewed_at=date(2020, 1, 1),
        )
        assert param.is_stale(max_age_days=90)

    def test_fresh_detection_works(self):
        """A recently reviewed parameter should not be stale."""
        param = RegulatoryParameter(
            key="test.fresh",
            value=42.0,
            reviewed_at=date.today(),
        )
        assert not param.is_stale(max_age_days=90)

    def test_none_reviewed_at_is_stale(self):
        """A parameter with no reviewed_at should be stale."""
        param = RegulatoryParameter(
            key="test.no_review",
            value=42.0,
            reviewed_at=None,
        )
        assert param.is_stale(max_age_days=90)


# ---------------------------------------------------------------------------
# 10. get() returns correct values for each category
# ---------------------------------------------------------------------------


class TestGetByCategory:
    """get_all() with category filter returns correct subsets."""

    def test_avs_category(self, registry):
        avs = registry.get_all(category="avs")
        assert len(avs) > 10  # Multiple AVS params
        assert all(p.key.startswith("avs.") for p in avs)

    def test_lpp_category(self, registry):
        lpp = registry.get_all(category="lpp")
        assert len(lpp) >= 8  # LPP params
        assert all(p.key.startswith("lpp.") for p in lpp)

    def test_pillar3a_category(self, registry):
        p3a = registry.get_all(category="pillar3a")
        assert len(p3a) >= 3  # 3 core + 11 historical
        assert all(p.key.startswith("pillar3a.") for p in p3a)

    def test_mortgage_category(self, registry):
        mortgage = registry.get_all(category="mortgage")
        assert len(mortgage) >= 5
        assert all(p.key.startswith("mortgage.") for p in mortgage)

    def test_capital_tax_category(self, registry):
        tax = registry.get_all(category="capital_tax")
        # 26 cantonal + brackets + default + married
        assert len(tax) >= 30

    def test_all_params_returned_without_filter(self, registry):
        """get_all() with no filter returns everything."""
        all_params = registry.get_all()
        assert len(all_params) > 80  # Many parameters


# ---------------------------------------------------------------------------
# 11. Unknown key returns None
# ---------------------------------------------------------------------------


class TestEdgeCases:
    """Edge cases and error handling."""

    def test_unknown_key_returns_none(self, registry):
        assert registry.get("nonexistent.key") is None

    def test_get_value_shortcut(self, registry):
        value = registry.get_value("pillar3a.max_with_lpp")
        assert value == 7258.0

    def test_get_value_unknown_returns_none(self, registry):
        assert registry.get_value("nonexistent.key") is None

    def test_singleton_returns_same_instance(self):
        a = RegulatoryRegistry.instance()
        b = RegulatoryRegistry.instance()
        assert a is b

    def test_keys_sorted(self, registry):
        keys = registry.keys()
        assert keys == sorted(keys)

    def test_count_returns_positive(self, registry):
        assert registry.count() > 80


# ---------------------------------------------------------------------------
# 12. RegulatoryParameter model
# ---------------------------------------------------------------------------


class TestParameterModel:
    """Test the RegulatoryParameter dataclass."""

    def test_is_active_current(self):
        param = RegulatoryParameter(
            key="test",
            value=1.0,
            effective_from=date(2025, 1, 1),
        )
        assert param.is_active(date(2025, 6, 1))

    def test_is_active_before_effective(self):
        param = RegulatoryParameter(
            key="test",
            value=1.0,
            effective_from=date(2025, 1, 1),
        )
        assert not param.is_active(date(2024, 12, 31))

    def test_is_active_after_expired(self):
        param = RegulatoryParameter(
            key="test",
            value=1.0,
            effective_from=date(2025, 1, 1),
            effective_to=date(2025, 12, 31),
        )
        assert not param.is_active(date(2026, 1, 1))

    def test_to_dict_camelcase(self):
        param = RegulatoryParameter(
            key="test.key",
            value=42.0,
            unit="CHF",
            effective_from=date(2025, 1, 1),
            source_url="https://example.com",
            source_title="Test",
            reviewed_at=date(2026, 3, 26),
        )
        d = param.to_dict()
        assert d["key"] == "test.key"
        assert d["value"] == 42.0
        assert d["effectiveFrom"] == "2025-01-01"
        assert d["reviewedAt"] == "2026-03-26"
        assert "sourceUrl" in d  # camelCase


# ---------------------------------------------------------------------------
# 13. LLM tool handler
# ---------------------------------------------------------------------------


class TestLLMToolHandler:
    """Test the get_regulatory_constant internal tool handler."""

    def test_handler_returns_value(self):
        from app.api.v1.endpoints.coach_chat import _handle_regulatory_constant

        result = _handle_regulatory_constant({"key": "pillar3a.max_with_lpp"})
        assert "7258" in result
        assert "OPP3" in result

    def test_handler_unknown_key(self):
        from app.api.v1.endpoints.coach_chat import _handle_regulatory_constant

        result = _handle_regulatory_constant({"key": "nonexistent.key"})
        assert "non trouvée" in result

    def test_handler_empty_key(self):
        from app.api.v1.endpoints.coach_chat import _handle_regulatory_constant

        result = _handle_regulatory_constant({"key": ""})
        assert "manquante" in result

    def test_handler_with_canton(self):
        from app.api.v1.endpoints.coach_chat import _handle_regulatory_constant

        result = _handle_regulatory_constant({
            "key": "capital_tax.cantonal.VS",
            "canton": "VS",
        })
        assert "0.06" in result

    def test_handler_canton_auto_key(self):
        """When canton is provided but key is generic, handler auto-builds key."""
        from app.api.v1.endpoints.coach_chat import _handle_regulatory_constant

        result = _handle_regulatory_constant({
            "key": "capital_tax.cantonal",
            "canton": "ZG",
        })
        assert "0.035" in result


# ---------------------------------------------------------------------------
# 14. Coach tools integration
# ---------------------------------------------------------------------------


class TestCoachToolsIntegration:
    """Verify the regulatory tool is registered in coach_tools.py."""

    def test_internal_tool_name_registered(self):
        from app.services.coach.coach_tools import INTERNAL_TOOL_NAMES

        assert "get_regulatory_constant" in INTERNAL_TOOL_NAMES

    def test_tool_definition_exists(self):
        from app.services.coach.coach_tools import COACH_TOOLS

        tool_names = [t["name"] for t in COACH_TOOLS]
        assert "get_regulatory_constant" in tool_names

    def test_tool_has_correct_schema(self):
        from app.services.coach.coach_tools import COACH_TOOLS

        tool = next(t for t in COACH_TOOLS if t["name"] == "get_regulatory_constant")
        schema = tool["input_schema"]
        assert "key" in schema["properties"]
        assert "canton" in schema["properties"]
        assert schema["required"] == ["key"]
        assert tool["category"] == "read"
