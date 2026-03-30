"""
Integration tests for the onboarding HTTP contract — Sprint S57.

Tests the FULL request → endpoint → response → client mapping path
for /api/v1/onboarding/chiffre-choc and /api/v1/onboarding/minimal-profile.

These tests catch serialization drift, missing fields, and schema/endpoint
misalignment that unit tests on isolated selectors cannot detect.

Specifically validates:
- stress_type flows from request to selector (Finding 1)
- confidence_mode flows from selector to response (Finding 2)
- New categories (compound_growth, hourly_rate, retirement_income) serialize correctly
- camelCase aliasing works for all new fields

Sources:
    - LAVS art. 21-29, LPP art. 15-16, OPP3 art. 7
"""



BANNED_TERMS = [
    "garanti", "certain", "assuré", "sans risque",
    "optimal", "meilleur", "parfait",
    "conseiller", "tu devrais", "tu dois",
]


# ===========================================================================
# TestChiffreChocContract — HTTP contract tests
# ===========================================================================

class TestChiffreChocContract:
    """Full HTTP round-trip tests for /api/v1/onboarding/chiffre-choc."""

    def test_basic_request_returns_200(self, client):
        """Minimal 3-field request returns 200 with all required fields."""
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 45,
            "grossSalary": 100_000,
            "canton": "VD",
        })
        assert resp.status_code == 200
        data = resp.json()

        # All required fields present
        assert "category" in data
        assert "primaryNumber" in data
        assert "displayText" in data
        assert "explanationText" in data
        assert "actionText" in data
        assert "disclaimer" in data
        assert "sources" in data
        assert "confidenceScore" in data
        assert "confidenceMode" in data

    def test_stress_type_flows_to_selector(self, client):
        """stress_type in request influences category in response."""
        # stress_budget should produce hourly_rate for a user with good liquidity
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 30,
            "grossSalary": 80_000,
            "canton": "ZH",
            "currentSavings": 20_000,
            "stressType": "stress_budget",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["category"] == "hourly_rate"

    def test_stress_impots_produces_tax_saving(self, client):
        """stress_impots should produce tax_saving category."""
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 35,
            "grossSalary": 90_000,
            "canton": "GE",
            "currentSavings": 30_000,
            "stressType": "stress_impots",
        })
        assert resp.status_code == 200
        assert resp.json()["category"] == "tax_saving"

    def test_stress_retraite_with_ok_ratio_returns_income_not_gap(self, client):
        """stress_retraite with good ratio → retirement_income (not retirement_gap).

        This is the exact divergence that Finding 3 caught: backend was returning
        retirement_gap for all stress_retraite, but Flutter returns retirement_income
        when ratio is OK.
        """
        # High salary + real LPP data → ratio should be OK
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 45,
            "grossSalary": 80_000,
            "canton": "VD",
            "existingLpp": 250_000,
            "currentSavings": 50_000,
            "stressType": "stress_retraite",
        })
        assert resp.status_code == 200
        data = resp.json()
        # With real LPP data at 250k, ratio should be decent → retirement_income
        # MUST be retirement_income, NOT retirement_gap — this locks the F3 fix
        assert data["category"] == "retirement_income", (
            f"Expected retirement_income for OK ratio with stress_retraite, "
            f"got {data['category']}. This is the exact divergence Finding 3 caught."
        )

    def test_young_user_without_stress_gets_lifecycle_choc(self, client):
        """Age 22 without stress_type → compound_growth or tax_saving (not retirement_gap).

        Provide enough savings to avoid triggering liquidity alert, so the
        test isolates the lifecycle fallback behavior.
        """
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 22,
            "grossSalary": 55_000,
            "canton": "FR",
            "currentSavings": 20_000,  # Enough to avoid liquidity alert
        })
        assert resp.status_code == 200
        data = resp.json()
        # Young user should NEVER get retirement_gap — that's the whole V2 point
        assert data["category"] in ("compound_growth", "tax_saving", "hourly_rate")

    def test_confidence_mode_in_response(self, client):
        """confidence_mode field is present and valid in response."""
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 45,
            "grossSalary": 100_000,
            "canton": "VD",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["confidenceMode"] in ("factual", "pedagogical")

    def test_estimated_data_produces_pedagogical_mode(self, client):
        """When key data is estimated (no LPP/savings provided), mode should be pedagogical."""
        # Don't provide LPP or savings → they will be estimated
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 49,
            "grossSalary": 100_000,
            "canton": "VD",
            # No existingLpp, no currentSavings → both estimated
        })
        assert resp.status_code == 200
        data = resp.json()
        # For retirement-related categories with estimated LPP, should be pedagogical
        if data["category"] in ("retirement_gap", "retirement_income"):
            assert data["confidenceMode"] == "pedagogical"

    def test_real_data_produces_factual_mode(self, client):
        """When key data is provided, mode should be factual."""
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 22,
            "grossSalary": 60_000,
            "canton": "ZH",
            "currentSavings": 8_000,
            "existing3a": 3_000,
            "existingLpp": 5_000,
            "stressType": "stress_budget",
        })
        assert resp.status_code == 200
        data = resp.json()
        # hourly_rate is pure math from salary → always factual
        assert data["category"] == "hourly_rate"
        assert data["confidenceMode"] == "factual"

    def test_compound_growth_serializes_correctly(self, client):
        """compound_growth category serializes with all required fields."""
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 22,
            "grossSalary": 55_000,
            "canton": "BE",
            "currentSavings": 5_000,
            "existing3a": 2_000,
        })
        assert resp.status_code == 200
        data = resp.json()
        if data["category"] == "compound_growth":
            assert data["primaryNumber"] > 0
            assert "temps" in data["displayText"].lower() or "200" in data["displayText"]
            assert data["confidenceMode"] == "factual"

    def test_camel_case_aliasing(self, client):
        """All fields use camelCase in response (Pydantic alias_generator)."""
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 40,
            "grossSalary": 90_000,
            "canton": "VD",
        })
        assert resp.status_code == 200
        data = resp.json()
        # camelCase fields (not snake_case)
        assert "primaryNumber" in data
        assert "displayText" in data
        assert "explanationText" in data
        assert "actionText" in data
        assert "confidenceScore" in data
        assert "confidenceMode" in data
        # snake_case should NOT be present
        assert "primary_number" not in data
        assert "display_text" not in data
        assert "confidence_mode" not in data

    def test_no_banned_terms_in_response(self, client):
        """No compliance-banned terms in any user-facing text fields."""
        profiles = [
            {"age": 22, "grossSalary": 55_000, "canton": "FR", "currentSavings": 5_000},
            {"age": 45, "grossSalary": 100_000, "canton": "VD"},
            {"age": 30, "grossSalary": 80_000, "canton": "ZH", "stressType": "stress_budget", "currentSavings": 20_000},
        ]
        for body in profiles:
            resp = client.post("/api/v1/onboarding/chiffre-choc", json=body)
            assert resp.status_code == 200
            data = resp.json()
            all_text = " ".join([
                data.get("displayText", ""),
                data.get("explanationText", ""),
                data.get("actionText", ""),
            ]).lower()
            for term in BANNED_TERMS:
                assert term.lower() not in all_text, (
                    f"Banned term '{term}' in {data['category']} response"
                )

    def test_disclaimer_and_sources_present(self, client):
        """Every response includes disclaimer and sources."""
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 40,
            "grossSalary": 90_000,
            "canton": "VD",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["disclaimer"]) > 0
        assert "LSFin" in data["disclaimer"]
        assert isinstance(data["sources"], list)
        assert len(data["sources"]) >= 1

    def test_invalid_stress_type_rejected(self, client):
        """Invalid stress_type value is rejected by schema validation."""
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 30,
            "grossSalary": 80_000,
            "canton": "VD",
            "stressType": "stress_invalid_value",
        })
        assert resp.status_code == 422  # Pydantic validation error

    def test_null_stress_type_accepted(self, client):
        """Null/absent stress_type is valid (V1 backward compat)."""
        resp = client.post("/api/v1/onboarding/chiffre-choc", json={
            "age": 30,
            "grossSalary": 80_000,
            "canton": "VD",
        })
        assert resp.status_code == 200


# ===========================================================================
# TestMinimalProfileContract — HTTP contract tests
# ===========================================================================

class TestMinimalProfileContract:
    """Full HTTP round-trip tests for /api/v1/onboarding/minimal-profile."""

    def test_basic_request_returns_200(self, client):
        """Minimal 3-field request returns 200 with all required fields."""
        resp = client.post("/api/v1/onboarding/minimal-profile", json={
            "age": 30,
            "grossSalary": 80_000,
            "canton": "VD",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "projectedAvsMonthly" in data
        assert "projectedLppMonthly" in data
        assert "estimatedReplacementRatio" in data
        assert "confidenceScore" in data
        assert "estimatedFields" in data
        assert "disclaimer" in data

    def test_enrichment_fields_reduce_estimated(self, client):
        """Providing optional fields reduces the estimatedFields list."""
        # Minimal request
        resp_minimal = client.post("/api/v1/onboarding/minimal-profile", json={
            "age": 30,
            "grossSalary": 80_000,
            "canton": "VD",
        })
        # Enriched request
        resp_enriched = client.post("/api/v1/onboarding/minimal-profile", json={
            "age": 30,
            "grossSalary": 80_000,
            "canton": "VD",
            "currentSavings": 20_000,
            "existingLpp": 50_000,
            "existing3a": 10_000,
        })
        minimal_est = len(resp_minimal.json()["estimatedFields"])
        enriched_est = len(resp_enriched.json()["estimatedFields"])
        assert enriched_est < minimal_est
