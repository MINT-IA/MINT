"""
Tests for profiles endpoint.
"""

import uuid


def test_create_profile(client):
    """Test creating a new profile."""
    payload = {
        "householdType": "single",
        "goal": "invest",
        "birthYear": 1990,
        "canton": "ZH",
    }
    response = client.post("/api/v1/profiles", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["householdType"] == "single"
    assert data["goal"] == "invest"
    assert "id" in data
    assert "createdAt" in data


def test_get_profile(client):
    """Test getting a profile by ID."""
    # First create a profile
    payload = {
        "householdType": "couple",
        "goal": "house",
    }
    create_response = client.post("/api/v1/profiles", json=payload)
    profile_id = create_response.json()["id"]

    # Then get it
    response = client.get(f"/api/v1/profiles/{profile_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == profile_id
    assert data["householdType"] == "couple"


def test_get_profile_not_found(client):
    """Test that getting a non-existent profile returns 404."""
    fake_id = str(uuid.uuid4())
    response = client.get(f"/api/v1/profiles/{fake_id}")
    assert response.status_code == 404


def test_get_my_profile(client):
    """Test getting the authenticated user's profile via /profiles/me."""
    # Create a profile (linked to the test user via auth override)
    payload = {
        "householdType": "single",
        "goal": "retire",
        "birthYear": 1985,
        "canton": "VD",
        "gender": "F",
    }
    create_response = client.post("/api/v1/profiles", json=payload)
    assert create_response.status_code == 200

    # Fetch via /me endpoint
    response = client.get("/api/v1/profiles/me")
    assert response.status_code == 200
    data = response.json()
    assert data["householdType"] == "single"
    assert data["goal"] == "retire"
    assert data["birthYear"] == 1985
    assert data["canton"] == "VD"
    assert data["gender"] == "F"


def test_get_my_profile_not_found(client):
    """Test /profiles/me returns 404 when user has no profile."""
    response = client.get("/api/v1/profiles/me")
    assert response.status_code == 404


def test_update_profile(client):
    """Test updating a profile."""
    # Create
    payload = {
        "householdType": "single",
        "goal": "invest",
    }
    create_response = client.post("/api/v1/profiles", json=payload)
    profile_id = create_response.json()["id"]

    # Update
    update_payload = {"goal": "retire", "savingsMonthly": 1000.0}
    response = client.patch(f"/api/v1/profiles/{profile_id}", json=update_payload)
    assert response.status_code == 200
    data = response.json()
    assert data["goal"] == "retire"
    assert data["savingsMonthly"] == 1000.0
    assert data["householdType"] == "single"  # unchanged
