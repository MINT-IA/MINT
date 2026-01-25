"""
Tests for profiles endpoint.
"""
import pytest
import httpx


@pytest.mark.asyncio
async def test_create_profile(client: httpx.AsyncClient):
    """Test creating a new profile."""
    payload = {
        "householdType": "single",
        "goal": "invest",
        "birthYear": 1990,
        "canton": "ZH",
    }
    response = await client.post("/api/v1/profiles", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["householdType"] == "single"
    assert data["goal"] == "invest"
    assert "id" in data
    assert "createdAt" in data


@pytest.mark.asyncio
async def test_get_profile(client: httpx.AsyncClient):
    """Test getting a profile by ID."""
    # First create a profile
    payload = {
        "householdType": "couple",
        "goal": "house",
    }
    create_response = await client.post("/api/v1/profiles", json=payload)
    profile_id = create_response.json()["id"]

    # Then get it
    response = await client.get(f"/api/v1/profiles/{profile_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == profile_id
    assert data["householdType"] == "couple"


@pytest.mark.asyncio
async def test_get_profile_not_found(client: httpx.AsyncClient):
    """Test that getting a non-existent profile returns 404."""
    import uuid
    fake_id = str(uuid.uuid4())
    response = await client.get(f"/api/v1/profiles/{fake_id}")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_update_profile(client: httpx.AsyncClient):
    """Test updating a profile."""
    # Create
    payload = {
        "householdType": "single",
        "goal": "invest",
    }
    create_response = await client.post("/api/v1/profiles", json=payload)
    profile_id = create_response.json()["id"]

    # Update
    update_payload = {"goal": "retire", "savingsMonthly": 1000.0}
    response = await client.patch(f"/api/v1/profiles/{profile_id}", json=update_payload)
    assert response.status_code == 200
    data = response.json()
    assert data["goal"] == "retire"
    assert data["savingsMonthly"] == 1000.0
    assert data["householdType"] == "single"  # unchanged
