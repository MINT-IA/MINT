"""
Tests for scenarios endpoint.
"""

import uuid
from datetime import datetime, timezone

from app.models.profile_model import ProfileModel
from tests.conftest import TestingSessionLocal


def _assert_scenario_confidence_envelope(data: dict) -> None:
    assert data["confidenceMode"] == "educational"
    assert data["enhancedConfidence"]["label"] == "à confirmer"
    assert (
        data["enhancedConfidence"]["rangePolicy"]
        == "projected_numbers_require_ranges_or_confidence_band"
    )
    assert "éducatif" in data["disclaimer"].lower()
    assert "conseil financier" not in data["disclaimer"].lower()
    assert data["sources"]


def test_create_compound_interest_scenario(client):
    """Test creating a compound interest scenario."""
    # First create a profile
    profile_payload = {"householdType": "single", "goal": "invest"}
    profile_resp = client.post("/api/v1/profiles", json=profile_payload)
    profile_id = profile_resp.json()["id"]

    # Create scenario
    scenario_payload = {
        "profileId": profile_id,
        "kind": "compound_interest",
        "inputs": {
            "principal": 10000,
            "monthlyContribution": 500,
            "annualRate": 5.0,
            "years": 10,
        },
    }
    response = client.post("/api/v1/scenarios", json=scenario_payload)
    assert response.status_code == 200
    data = response.json()
    assert data["kind"] == "compound_interest"
    assert "outputs" in data
    assert "finalValue" in data["outputs"]
    assert "gains" in data["outputs"]
    _assert_scenario_confidence_envelope(data)


def test_create_leasing_scenario(client):
    """Test creating a leasing scenario."""
    profile_payload = {"householdType": "single", "goal": "house"}
    profile_resp = client.post("/api/v1/profiles", json=profile_payload)
    profile_id = profile_resp.json()["id"]

    scenario_payload = {
        "profileId": profile_id,
        "kind": "leasing",
        "inputs": {
            "monthlyPayment": 400,
            "durationMonths": 48,
            "alternativeRate": 5.0,
        },
    }
    response = client.post("/api/v1/scenarios", json=scenario_payload)
    assert response.status_code == 200
    data = response.json()
    assert data["kind"] == "leasing"
    assert "opportunityCost" in data["outputs"]
    # Check structure match with new logic
    assert "5y" in data["outputs"]["opportunityCost"]


def test_create_mortgage_scenario_computes_swiss_affordability(client):
    """Mortgage scenario must use the Swiss affordability calculator."""
    profile_payload = {"householdType": "couple", "goal": "house"}
    profile_resp = client.post("/api/v1/profiles", json=profile_payload)
    profile_id = profile_resp.json()["id"]

    scenario_payload = {
        "profileId": profile_id,
        "kind": "mortgage",
        "inputs": {
            "incomeGrossYearly": 150000,
            "patrimoine.epargneLiquide": 200000,
            "targetPropertyValue": 800000,
            "canton": "ZH",
        },
    }
    response = client.post("/api/v1/scenarios", json=scenario_payload)

    assert response.status_code == 200
    data = response.json()
    assert data["kind"] == "mortgage"
    assert "Scenario type not yet implemented" not in str(data["outputs"])
    assert data["outputs"]["status"] == "affordable"
    assert data["outputs"]["affordability"]["capacityOk"] is True
    assert data["outputs"]["affordability"]["equityOk"] is True
    assert data["outputs"]["affordability"]["mortgageAmount"] == 600000
    assert data["outputs"]["equity"]["required"] == 160000
    _assert_scenario_confidence_envelope(data)


def test_create_mortgage_scenario_reports_missing_property_value(client):
    """Missing target property value must stay an explicit Data Quest gap."""
    profile_payload = {"householdType": "single", "goal": "house"}
    profile_resp = client.post("/api/v1/profiles", json=profile_payload)
    profile_id = profile_resp.json()["id"]

    response = client.post(
        "/api/v1/scenarios",
        json={
            "profileId": profile_id,
            "kind": "mortgage",
            "inputs": {
                "incomeGrossYearly": 150000,
                "patrimoine.epargneLiquide": 200000,
                "canton": "ZH",
            },
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["outputs"]["status"] == "missing_data"
    assert data["outputs"]["missingInputs"] == ["targetPropertyValue"]
    assert data["outputs"]["affordability"] is None
    _assert_scenario_confidence_envelope(data)


def test_create_mortgage_scenario_does_not_use_owned_property_value(client):
    """Owned real-estate value must not satisfy a planned purchase target."""
    profile_payload = {"householdType": "single", "goal": "house"}
    profile_resp = client.post("/api/v1/profiles", json=profile_payload)
    profile_id = profile_resp.json()["id"]

    response = client.post(
        "/api/v1/scenarios",
        json={
            "profileId": profile_id,
            "kind": "mortgage",
            "inputs": {
                "incomeGrossYearly": 150000,
                "patrimoine.epargneLiquide": 200000,
                "patrimoine.propertyMarketValue": 800000,
                "canton": "ZH",
            },
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["outputs"]["status"] == "missing_data"
    assert data["outputs"]["missingInputs"] == ["targetPropertyValue"]
    assert data["outputs"]["affordability"] is None
    _assert_scenario_confidence_envelope(data)


def test_create_mortgage_scenario_prefers_target_over_owned_value(client):
    """If both values exist, planned purchase target drives affordability."""
    profile_payload = {"householdType": "couple", "goal": "house"}
    profile_resp = client.post("/api/v1/profiles", json=profile_payload)
    profile_id = profile_resp.json()["id"]

    response = client.post(
        "/api/v1/scenarios",
        json={
            "profileId": profile_id,
            "kind": "mortgage",
            "inputs": {
                "incomeGrossYearly": 150000,
                "patrimoine.epargneLiquide": 200000,
                "patrimoine.propertyMarketValue": 1200000,
                "targetPropertyValue": 800000,
                "canton": "ZH",
            },
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["outputs"]["status"] == "affordable"
    assert data["outputs"]["affordability"]["mortgageAmount"] == 600000
    assert data["outputs"]["equity"]["required"] == 160000
    _assert_scenario_confidence_envelope(data)


def test_create_scenario_rejects_profile_owned_by_another_user(client):
    """POST /scenarios must not attach outputs to a foreign profile."""
    foreign_profile_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    db = TestingSessionLocal()
    try:
        db.add(
            ProfileModel(
                id=foreign_profile_id,
                user_id="other-user-id",
                data={
                    "id": foreign_profile_id,
                    "householdType": "single",
                    "goal": "invest",
                    "createdAt": now.isoformat(),
                },
                created_at=now,
                updated_at=now,
            )
        )
        db.commit()
    finally:
        db.close()

    response = client.post(
        "/api/v1/scenarios",
        json={
            "profileId": foreign_profile_id,
            "kind": "compound_interest",
            "inputs": {"principal": 10000, "monthlyContribution": 500},
        },
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "Profile not found"


def test_list_scenarios(client):
    """Test listing scenarios for a profile."""
    # Create profile
    profile_payload = {"householdType": "family", "goal": "retire"}
    profile_resp = client.post("/api/v1/profiles", json=profile_payload)
    profile_id = profile_resp.json()["id"]

    # Create a scenario
    scenario_payload = {
        "profileId": profile_id,
        "kind": "pillar3a",
        "inputs": {"annualContribution": 7056, "marginalTaxRate": 0.25, "years": 30},
    }
    client.post("/api/v1/scenarios", json=scenario_payload)

    # List
    response = client.get(f"/api/v1/scenarios/{profile_id}")
    assert response.status_code == 200
    data = response.json()
    assert "items" in data
    assert "total" in data
    assert isinstance(data["items"], list)
    assert len(data["items"]) >= 1
