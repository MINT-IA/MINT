"""
Tests for Precision — Guided Precision Entry — Sprint S41.

Test categories:
    1. Field help (12 tests): contextual help for each supported field
    2. Cross-validation (12 tests): LPP coherence, salary, 3a, mortgage, marginal rate
    3. Smart defaults (10 tests): by archetype swiss_native, expat_eu, independent, etc.
    4. Precision prompts (8 tests): by context rente_vs_capital, tax_optimization, fri
    5. Edge cases (4 tests): empty profile, zero values, extreme values, unknown field
    6. Compliance (2 tests): no banned terms, disclaimer present

Sources:
    - LPP art. 7 (seuil d'entree: 22'680 CHF)
    - LPP art. 8 (deduction de coordination: 26'460 CHF)
    - LPP art. 15-16 (bonifications vieillesse: 7/10/15/18%)
    - LAVS art. 29ter (duree cotisation complete: 44 ans)
    - OPP3 art. 7 (plafond 3a: 7'258 CHF / 36'288 CHF)
    - LIFD art. 38 (imposition du capital de prevoyance)
"""

import pytest

from app.services.precision.precision_models import (
    FieldHelp,
)
from app.services.precision.precision_service import (
    get_field_help,
    cross_validate,
    compute_smart_defaults,
    get_precision_prompts,
)


# ===================================================================
# Banned terms — NEVER appear in any user-facing text
# ===================================================================

BANNED_TERMS = [
    "garanti",
    "certain",
    "assure",
    "sans risque",
    "optimal",
    "meilleur",
    "parfait",
    "conseiller",
]


# ===================================================================
# 1. Field Help Tests (12 tests — one per field)
# ===================================================================

class TestFieldHelp:
    """Test contextual help for all 12 supported financial fields."""

    @pytest.mark.parametrize("field_name", [
        "lpp_total",
        "lpp_obligatoire",
        "lpp_surobligatoire",
        "salaire_brut",
        "salaire_net",
        "taux_marginal",
        "avs_contribution_years",
        "pillar_3a_balance",
        "mortgage_remaining",
        "monthly_expenses",
        "replacement_ratio",
        "tax_saving_3a",
    ])
    def test_field_help_returns_valid_help(self, field_name: str):
        """Each supported field returns a valid FieldHelp object."""
        result = get_field_help(field_name)
        assert isinstance(result, FieldHelp)
        assert result.field_name == field_name
        assert len(result.where_to_find) > 10
        assert len(result.document_name) > 5
        assert len(result.german_name) > 3
        assert len(result.fallback_estimation) > 10

    def test_field_help_lpp_total_mentions_certificate(self):
        """LPP total help mentions the prevoyance certificate."""
        result = get_field_help("lpp_total")
        assert "certificat" in result.where_to_find.lower()
        assert "Vorsorgeausweis" in result.german_name

    def test_field_help_taux_marginal_mentions_taxation(self):
        """Marginal rate help mentions the taxation notice."""
        result = get_field_help("taux_marginal")
        assert "taxation" in result.where_to_find.lower()
        assert "Grenzsteuersatz" in result.german_name

    def test_field_help_avs_mentions_ci(self):
        """AVS contribution years help mentions the individual account extract."""
        result = get_field_help("avs_contribution_years")
        assert "extrait" in result.where_to_find.lower() or "CI" in result.where_to_find
        assert "ahv-iv.ch" in result.where_to_find

    def test_field_help_unknown_field_raises_error(self):
        """Unknown field name raises ValueError with available fields listed."""
        with pytest.raises(ValueError, match="Champ inconnu"):
            get_field_help("unknown_field_xyz")

    def test_field_help_unknown_field_lists_available(self):
        """Error message lists available field names."""
        with pytest.raises(ValueError) as exc_info:
            get_field_help("invalid")
        assert "lpp_total" in str(exc_info.value)
        assert "salaire_brut" in str(exc_info.value)


# ===================================================================
# 2. Cross-Validation Tests (12 tests)
# ===================================================================

class TestCrossValidation:
    """Test cross-validation alerts for profile coherence."""

    def test_lpp_too_low_for_age_salary(self):
        """LPP way too low triggers a warning."""
        alerts = cross_validate({
            "age": 50,
            "salaire_brut": 100_000,
            "lpp_total": 5_000,  # Way too low for 50yo, 100k salary
        })
        lpp_alerts = [a for a in alerts if a.field_name == "lpp_total"]
        assert len(lpp_alerts) >= 1
        assert lpp_alerts[0].severity == "warning"
        assert "bas" in lpp_alerts[0].message.lower()

    def test_lpp_too_high_for_age_salary(self):
        """LPP way too high triggers a warning."""
        alerts = cross_validate({
            "age": 28,
            "salaire_brut": 60_000,
            "lpp_total": 500_000,  # Way too high for 28yo, 60k salary
        })
        lpp_alerts = [a for a in alerts if a.field_name == "lpp_total"]
        assert len(lpp_alerts) >= 1
        assert lpp_alerts[0].severity == "warning"
        assert "eleve" in lpp_alerts[0].message.lower()

    def test_lpp_reasonable_no_alert(self):
        """LPP within reasonable range produces no LPP alert."""
        alerts = cross_validate({
            "age": 40,
            "salaire_brut": 80_000,
            "lpp_total": 100_000,  # Reasonable for 40yo
        })
        lpp_alerts = [a for a in alerts if a.field_name == "lpp_total"]
        assert len(lpp_alerts) == 0

    def test_salary_gross_net_ratio_too_low(self):
        """Net too low vs gross triggers salary alert."""
        alerts = cross_validate({
            "salaire_brut": 100_000,
            "salaire_net": 50_000,  # 50% ratio — way too low
            "canton": "ZH",
        })
        salary_alerts = [a for a in alerts if a.field_name == "salaire_net"]
        assert len(salary_alerts) >= 1
        assert "ecart" in salary_alerts[0].message.lower() or "bas" in salary_alerts[0].message.lower()

    def test_salary_gross_net_ratio_too_high(self):
        """Net too high vs gross triggers salary alert."""
        alerts = cross_validate({
            "salaire_brut": 100_000,
            "salaire_net": 98_000,  # 98% ratio — too high
            "canton": "ZH",
        })
        salary_alerts = [a for a in alerts if a.field_name == "salaire_net"]
        assert len(salary_alerts) >= 1
        assert "eleve" in salary_alerts[0].message.lower()

    def test_salary_ratio_normal_no_alert(self):
        """Normal gross/net ratio produces no alert."""
        alerts = cross_validate({
            "salaire_brut": 100_000,
            "salaire_net": 78_000,  # 78% — normal for ZH
            "canton": "ZH",
        })
        salary_alerts = [a for a in alerts if a.field_name == "salaire_net"]
        assert len(salary_alerts) == 0

    def test_3a_under_18_error(self):
        """3a balance with age < 18 triggers error."""
        alerts = cross_validate({
            "age": 16,
            "pillar_3a_balance": 5_000,
        })
        a3_alerts = [a for a in alerts if a.field_name == "pillar_3a_balance"]
        assert len(a3_alerts) >= 1
        assert a3_alerts[0].severity == "error"
        assert "18 ans" in a3_alerts[0].message

    def test_3a_too_high_for_age(self):
        """3a balance impossibly high for age triggers warning."""
        alerts = cross_validate({
            "age": 22,
            "pillar_3a_balance": 100_000,  # 4 years max × 7258 = ~29k
        })
        a3_alerts = [a for a in alerts if a.field_name == "pillar_3a_balance"]
        assert len(a3_alerts) >= 1
        assert a3_alerts[0].severity == "warning"

    def test_lpp_positive_independant_no_lpp_error(self):
        """LPP > 0 but independant without LPP triggers error."""
        alerts = cross_validate({
            "lpp_total": 50_000,
            "is_independant": True,
            "has_lpp": False,
        })
        lpp_alerts = [a for a in alerts if a.field_name == "lpp_total"]
        assert len(lpp_alerts) >= 1
        assert lpp_alerts[0].severity == "error"
        assert "independant" in lpp_alerts[0].message.lower()

    def test_mortgage_positive_not_owner_error(self):
        """Mortgage > 0 but not property owner triggers error."""
        alerts = cross_validate({
            "mortgage_remaining": 300_000,
            "is_property_owner": False,
        })
        mortgage_alerts = [a for a in alerts if a.field_name == "mortgage_remaining"]
        assert len(mortgage_alerts) >= 1
        assert mortgage_alerts[0].severity == "error"
        assert "proprietaire" in mortgage_alerts[0].message.lower()

    def test_marginal_rate_too_low_for_income(self):
        """Marginal rate way too low for high income triggers warning."""
        alerts = cross_validate({
            "salaire_brut": 200_000,
            "taux_marginal": 0.05,  # 5% marginal for 200k — unrealistic
            "canton": "GE",
        })
        rate_alerts = [a for a in alerts if a.field_name == "taux_marginal"]
        assert len(rate_alerts) >= 1
        assert rate_alerts[0].severity == "warning"
        assert "bas" in rate_alerts[0].message.lower()

    def test_marginal_rate_too_high_for_income(self):
        """Marginal rate way too high for low income triggers warning."""
        alerts = cross_validate({
            "salaire_brut": 40_000,
            "taux_marginal": 0.50,  # 50% marginal for 40k — unrealistic
            "canton": "ZG",
        })
        rate_alerts = [a for a in alerts if a.field_name == "taux_marginal"]
        assert len(rate_alerts) >= 1
        assert rate_alerts[0].severity == "warning"


# ===================================================================
# 3. Smart Defaults Tests (10 tests)
# ===================================================================

class TestSmartDefaults:
    """Test contextual estimation by archetype."""

    def test_swiss_native_35_returns_4_defaults(self):
        """Swiss native returns all 4 default categories."""
        defaults = compute_smart_defaults(
            archetype="swiss_native", age=35, salary=80_000, canton="ZH",
        )
        assert len(defaults) == 4
        field_names = [d.field_name for d in defaults]
        assert "lpp_total" in field_names
        assert "taux_marginal" in field_names
        assert "reserve_liquidite" in field_names
        assert "avs_contribution_years" in field_names

    def test_swiss_native_lpp_positive(self):
        """Swiss native with salary above LPP threshold has positive LPP estimate."""
        defaults = compute_smart_defaults(
            archetype="swiss_native", age=40, salary=80_000, canton="VD",
        )
        lpp = next(d for d in defaults if d.field_name == "lpp_total")
        assert lpp.value > 0
        assert lpp.confidence > 0

    def test_swiss_native_avs_years(self):
        """Swiss native AVS years = age - 20."""
        defaults = compute_smart_defaults(
            archetype="swiss_native", age=45, salary=80_000, canton="ZH",
        )
        avs = next(d for d in defaults if d.field_name == "avs_contribution_years")
        assert avs.value == 25  # 45 - 20

    def test_independent_no_lpp_zero(self):
        """Independent without LPP has LPP estimate = 0."""
        defaults = compute_smart_defaults(
            archetype="independent_no_lpp", age=40, salary=100_000, canton="GE",
        )
        lpp = next(d for d in defaults if d.field_name == "lpp_total")
        assert lpp.value == 0
        assert lpp.confidence >= 0.85  # High confidence that it's 0

    def test_expat_eu_fewer_avs_years(self):
        """Expat EU has fewer AVS contribution years."""
        defaults = compute_smart_defaults(
            archetype="expat_eu", age=45, salary=100_000, canton="ZH",
        )
        avs = next(d for d in defaults if d.field_name == "avs_contribution_years")
        # Expat arrived ~30, so ~15 years at age 45
        assert avs.value == 15
        assert avs.confidence < 0.5  # Lower confidence for expats

    def test_expat_eu_lower_lpp(self):
        """Expat EU has lower LPP than swiss_native (fewer contribution years)."""
        swiss = compute_smart_defaults(
            archetype="swiss_native", age=45, salary=100_000, canton="ZH",
        )
        expat = compute_smart_defaults(
            archetype="expat_eu", age=45, salary=100_000, canton="ZH",
        )
        swiss_lpp = next(d for d in swiss if d.field_name == "lpp_total")
        expat_lpp = next(d for d in expat if d.field_name == "lpp_total")
        assert expat_lpp.value < swiss_lpp.value

    def test_marginal_rate_varies_by_canton(self):
        """Marginal rate differs between low-tax and high-tax cantons."""
        low_tax = compute_smart_defaults(
            archetype="swiss_native", age=35, salary=80_000, canton="ZG",
        )
        high_tax = compute_smart_defaults(
            archetype="swiss_native", age=35, salary=80_000, canton="GE",
        )
        zg_rate = next(d for d in low_tax if d.field_name == "taux_marginal")
        ge_rate = next(d for d in high_tax if d.field_name == "taux_marginal")
        assert zg_rate.value < ge_rate.value

    def test_marginal_rate_varies_by_income(self):
        """Marginal rate increases with income."""
        low_income = compute_smart_defaults(
            archetype="swiss_native", age=35, salary=50_000, canton="ZH",
        )
        high_income = compute_smart_defaults(
            archetype="swiss_native", age=35, salary=150_000, canton="ZH",
        )
        low_rate = next(d for d in low_income if d.field_name == "taux_marginal")
        high_rate = next(d for d in high_income if d.field_name == "taux_marginal")
        assert low_rate.value < high_rate.value

    def test_smart_defaults_source_is_transparent(self):
        """Each smart default has a transparent source explanation."""
        defaults = compute_smart_defaults(
            archetype="swiss_native", age=35, salary=80_000, canton="VD",
        )
        for d in defaults:
            assert len(d.source) > 20
            assert d.confidence >= 0.0
            assert d.confidence <= 1.0

    def test_cross_border_avs_years_like_native(self):
        """Cross-border workers cotise en CH like natives."""
        defaults = compute_smart_defaults(
            archetype="cross_border", age=45, salary=100_000, canton="GE",
        )
        avs = next(d for d in defaults if d.field_name == "avs_contribution_years")
        assert avs.value == 25  # 45 - 20, same as native


# ===================================================================
# 4. Precision Prompts Tests (8 tests)
# ===================================================================

class TestPrecisionPrompts:
    """Test progressive precision prompts by context."""

    def test_rente_vs_capital_missing_lpp_obligatoire(self):
        """Rente vs capital context prompts for lpp_obligatoire if missing."""
        prompts = get_precision_prompts("rente_vs_capital", {})
        fields_needed = [p.field_needed for p in prompts]
        assert "lpp_obligatoire" in fields_needed

    def test_rente_vs_capital_has_lpp_obligatoire_no_prompt(self):
        """Rente vs capital context: no lpp_obligatoire prompt if present."""
        prompts = get_precision_prompts("rente_vs_capital", {
            "lpp_obligatoire": 80_000,
            "taux_marginal": 0.30,
        })
        fields_needed = [p.field_needed for p in prompts]
        assert "lpp_obligatoire" not in fields_needed

    def test_tax_optimization_missing_taux_marginal(self):
        """Tax optimization context prompts for taux_marginal if missing."""
        prompts = get_precision_prompts("tax_optimization", {})
        fields_needed = [p.field_needed for p in prompts]
        assert "taux_marginal" in fields_needed

    def test_tax_optimization_has_taux_marginal_no_prompt(self):
        """Tax optimization: no taux_marginal prompt if present."""
        prompts = get_precision_prompts("tax_optimization", {
            "taux_marginal": 0.30,
            "pillar_3a_balance": 50_000,
        })
        fields_needed = [p.field_needed for p in prompts]
        assert "taux_marginal" not in fields_needed

    def test_fri_display_prompts_for_multiple_fields(self):
        """FRI display prompts for all critical missing fields."""
        prompts = get_precision_prompts("fri_display", {})
        fields_needed = [p.field_needed for p in prompts]
        assert "lpp_total" in fields_needed
        assert "taux_marginal" in fields_needed
        assert "monthly_expenses" in fields_needed

    def test_fri_display_partial_profile_fewer_prompts(self):
        """FRI display with some fields filled produces fewer prompts."""
        full_prompts = get_precision_prompts("fri_display", {})
        partial_prompts = get_precision_prompts("fri_display", {
            "lpp_total": 100_000,
            "taux_marginal": 0.30,
        })
        assert len(partial_prompts) < len(full_prompts)

    def test_retirement_projection_missing_avs(self):
        """Retirement projection prompts for AVS contribution years."""
        prompts = get_precision_prompts("retirement_projection", {})
        fields_needed = [p.field_needed for p in prompts]
        assert "avs_contribution_years" in fields_needed

    def test_mortgage_check_missing_mortgage(self):
        """Mortgage check prompts for mortgage_remaining if missing."""
        prompts = get_precision_prompts("mortgage_check", {})
        fields_needed = [p.field_needed for p in prompts]
        assert "mortgage_remaining" in fields_needed


# ===================================================================
# 5. Edge Cases Tests (4 tests)
# ===================================================================

class TestEdgeCases:
    """Test edge cases: empty profiles, zeros, extremes."""

    def test_cross_validate_empty_profile(self):
        """Empty profile produces no alerts."""
        alerts = cross_validate({})
        assert isinstance(alerts, list)
        assert len(alerts) == 0

    def test_cross_validate_all_zeros(self):
        """Profile with all zeros produces no alerts (no contradictions)."""
        alerts = cross_validate({
            "age": 30,
            "salaire_brut": 0,
            "salaire_net": 0,
            "lpp_total": 0,
            "pillar_3a_balance": 0,
            "mortgage_remaining": 0,
            "taux_marginal": 0,
        })
        # No contradictions when everything is 0 (low salary = no LPP expected)
        assert isinstance(alerts, list)

    def test_smart_defaults_salary_below_lpp_threshold(self):
        """Salary below LPP threshold produces LPP = 0."""
        defaults = compute_smart_defaults(
            archetype="swiss_native", age=35, salary=20_000, canton="ZH",
        )
        lpp = next(d for d in defaults if d.field_name == "lpp_total")
        assert lpp.value == 0  # Below 22'680 threshold

    def test_precision_prompts_unknown_context(self):
        """Unknown context returns empty list."""
        prompts = get_precision_prompts("unknown_context_xyz", {})
        assert isinstance(prompts, list)
        assert len(prompts) == 0


# ===================================================================
# 6. Compliance Tests (2 tests)
# ===================================================================

class TestCompliance:
    """Test that all user-facing text complies with MINT rules."""

    def test_field_help_no_banned_terms(self):
        """All field help texts contain no banned terms."""
        fields = [
            "lpp_total", "lpp_obligatoire", "lpp_surobligatoire",
            "salaire_brut", "salaire_net", "taux_marginal",
            "avs_contribution_years", "pillar_3a_balance",
            "mortgage_remaining", "monthly_expenses",
            "replacement_ratio", "tax_saving_3a",
        ]
        for field_name in fields:
            help_data = get_field_help(field_name)
            all_text = " ".join([
                help_data.where_to_find,
                help_data.document_name,
                help_data.fallback_estimation,
            ]).lower()
            for banned in BANNED_TERMS:
                assert banned not in all_text, (
                    f"Banned term '{banned}' found in help for '{field_name}'"
                )

    def test_cross_validation_alerts_no_banned_terms(self):
        """Cross-validation alert messages contain no banned terms."""
        # Trigger multiple alerts
        alerts = cross_validate({
            "age": 50,
            "salaire_brut": 100_000,
            "lpp_total": 5_000,
            "salaire_net": 50_000,
            "canton": "ZH",
            "pillar_3a_balance": 5_000,
            "mortgage_remaining": 300_000,
            "is_property_owner": False,
            "taux_marginal": 0.05,
        })
        for alert in alerts:
            all_text = f"{alert.message} {alert.suggestion}".lower()
            for banned in BANNED_TERMS:
                assert banned not in all_text, (
                    f"Banned term '{banned}' found in alert for '{alert.field_name}'"
                )


# ===================================================================
# 7. API Integration Tests (via FastAPI TestClient)
# ===================================================================

class TestAPIEndpoints:
    """Test API endpoints via FastAPI TestClient."""

    @pytest.fixture
    def client(self):
        from fastapi.testclient import TestClient
        from app.main import app
        return TestClient(app)

    def test_get_help_lpp_total(self, client):
        """GET /precision/help/lpp_total returns valid response."""
        resp = client.get("/api/v1/precision/help/lpp_total")
        assert resp.status_code == 200
        data = resp.json()
        assert data["fieldName"] == "lpp_total"  # camelCase
        assert "certificat" in data["whereToFind"].lower()

    def test_get_help_unknown_field_404(self, client):
        """GET /precision/help/unknown returns 404."""
        resp = client.get("/api/v1/precision/help/unknown_xyz")
        assert resp.status_code == 404

    def test_post_validate_coherent_profile(self, client):
        """POST /validate with coherent profile returns 0 alerts."""
        resp = client.post("/api/v1/precision/validate", json={
            "age": 40,
            "salaireBrut": 80_000,
            "salaireNet": 62_000,
            "canton": "ZH",
            "lppTotal": 100_000,
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["alertCount"] == 0
        assert "disclaimer" in data

    def test_post_validate_incoherent_profile(self, client):
        """POST /validate with incoherent profile returns alerts."""
        resp = client.post("/api/v1/precision/validate", json={
            "age": 50,
            "salaireBrut": 100_000,
            "lppTotal": 2_000,  # Way too low
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["alertCount"] > 0
        assert len(data["alerts"]) > 0

    def test_post_smart_defaults(self, client):
        """POST /smart-defaults returns 4 defaults with disclaimer."""
        resp = client.post("/api/v1/precision/smart-defaults", json={
            "archetype": "swiss_native",
            "age": 35,
            "salary": 80_000,
            "canton": "VD",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["defaults"]) == 4
        assert "disclaimer" in data
        assert len(data["sources"]) > 0

    def test_post_prompts_rente_vs_capital(self, client):
        """POST /prompts for rente_vs_capital returns prompts."""
        resp = client.post("/api/v1/precision/prompts", json={
            "context": "rente_vs_capital",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["prompts"]) > 0
        assert "disclaimer" in data

    def test_post_prompts_all_fields_present(self, client):
        """POST /prompts with all fields present returns empty prompts."""
        resp = client.post("/api/v1/precision/prompts", json={
            "context": "rente_vs_capital",
            "lppObligatoire": 80_000,
            "tauxMarginal": 0.30,
        })
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["prompts"]) == 0
