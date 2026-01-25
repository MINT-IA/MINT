"""
Tests for scenarios endpoint.
"""
import pytest
import httpx


@pytest.mark.asyncio
async def test_create_compound_interest_scenario(client: httpx.AsyncClient):
    """Test creating a compound interest scenario."""
    # First create a profile
    profile_payload = {"householdType": "single", "goal": "invest"}
    profile_resp = await client.post("/api/v1/profiles", json=profile_payload)
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
    response = await client.post("/api/v1/scenarios", json=scenario_payload)
    assert response.status_code == 200
    data = response.json()
    assert data["kind"] == "compound_interest"
    assert "outputs" in data
    assert "finalValue" in data["outputs"]
    assert "gains" in data["outputs"]


@pytest.mark.asyncio
async def test_create_leasing_scenario(client: httpx.AsyncClient):
    """Test creating a leasing scenario."""
    profile_payload = {"householdType": "single", "goal": "house"}
    profile_resp = await client.post("/api/v1/profiles", json=profile_payload)
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
    response = await client.post("/api/v1/scenarios", json=scenario_payload)
    assert response.status_code == 200
    data = response.json()
    assert data["kind"] == "leasing"
    assert "opportunityCost" in data["outputs"]
    # Check structure match with new logic
    assert "5y" in data["outputs"]["opportunityCost"]


@pytest.mark.asyncio
async def test_list_scenarios(client: httpx.AsyncClient):
    """Test listing scenarios for a profile."""
    # Create profile
    profile_payload = {"householdType": "family", "goal": "retire"}
    profile_resp = await client.post("/api/v1/profiles", json=profile_payload)
    profile_id = profile_resp.json()["id"]

    # Create a scenario
    scenario_payload = {
        "profileId": profile_id,
        "kind": "pillar3a",
        "inputs": {"annualContribution": 7056, "marginalTaxRate": 0.25, "years": 30},
    }
    await client.post("/api/v1/scenarios", json=scenario_payload)

    # List
    response = await client.get(f"/api/v1/scenarios/{profile_id}")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
