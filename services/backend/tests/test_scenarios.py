"""
Tests for scenarios endpoint.
"""


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
