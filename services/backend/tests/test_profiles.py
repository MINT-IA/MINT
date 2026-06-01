"""
Tests for profiles endpoint.
"""

import uuid
from datetime import datetime, timezone

from app.models.profile_model import ProfileModel
from tests.conftest import TestingSessionLocal


def _insert_legacy_profile(data: dict) -> str:
    db = TestingSessionLocal()
    try:
        profile_id = data.get("id", str(uuid.uuid4()))
        profile = ProfileModel(
            id=profile_id,
            user_id="test-user-id",
            data={
                "id": profile_id,
                "createdAt": datetime.now(timezone.utc).isoformat(),
                **data,
            },
        )
        db.add(profile)
        db.commit()
        return profile_id
    finally:
        db.close()


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


def test_create_profile_rejects_spouse_fields_for_single_household(client):
    payload = {
        "householdType": "single",
        "goal": "invest",
        "spouseBirthYear": 1982,
        "spouseIncomeNetMonthly": 5000,
    }

    response = client.post("/api/v1/profiles", json=payload)

    assert response.status_code == 422


def test_create_profile_rejects_invalid_birth_year(client):
    payload = {
        "householdType": "single",
        "birthYear": 2099,
    }

    response = client.post("/api/v1/profiles", json=payload)

    assert response.status_code == 422


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


def test_get_my_profile_tolerates_legacy_single_with_spouse_fields(client):
    profile_id = _insert_legacy_profile(
        {
            "householdType": "single",
            "goal": "other",
            "spouseBirthYear": 1982,
            "spouseIncomeNetMonthly": 5000,
            "spouseAvsContributionYears": 18,
        }
    )

    response = client.get("/api/v1/profiles/me")

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["id"] == profile_id
    assert body["householdType"] == "single"
    assert body["spouseBirthYear"] is None
    assert body["spouseIncomeNetMonthly"] is None
    assert body["spouseAvsContributionYears"] is None


def test_get_profile_tolerates_legacy_single_with_spouse_fields(client):
    profile_id = _insert_legacy_profile(
        {
            "householdType": "single",
            "goal": "other",
            "spouseBirthYear": 1982,
            "spouseIncomeNetMonthly": 5000,
            "spouseAvsContributionYears": 18,
        }
    )

    response = client.get(f"/api/v1/profiles/{profile_id}")

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["id"] == profile_id
    assert body["householdType"] == "single"
    assert body["spouseBirthYear"] is None
    assert body["spouseIncomeNetMonthly"] is None
    assert body["spouseAvsContributionYears"] is None


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


def test_get_my_profile_auto_bootstraps(client):
    """FIX-B: /profiles/me is get-or-create.

    If an authenticated user has no profile row yet (legacy account,
    partial bootstrap, migration edge case), GET /profiles/me must
    auto-create an empty profile and return it — never 404. This is
    the last line of defence for downstream screens (Aujourd'hui,
    Explorer, Coach) that read the profile on mount.
    """
    response = client.get("/api/v1/profiles/me")
    assert response.status_code == 200
    data = response.json()
    # Empty-profile defaults from ensure_empty_profile()
    assert data["householdType"] == "single"
    assert data["hasDebt"] is False
    assert data["goal"] == "other"

    # Idempotent: a second call returns the same profile, not a new one.
    second = client.get("/api/v1/profiles/me")
    assert second.status_code == 200
    assert second.json()["id"] == data["id"]


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


def test_update_profile_rejects_invalid_numeric_bounds_without_mutating(client):
    create_response = client.post(
        "/api/v1/profiles",
        json={
            "householdType": "single",
            "goal": "invest",
            "savingsMonthly": 1000,
            "totalSavings": 5000,
            "lppInsuredSalary": 60000,
        },
    )
    assert create_response.status_code == 200
    profile_id = create_response.json()["id"]

    for payload in (
        {"savingsMonthly": -1},
        {"totalSavings": -1},
        {"lppInsuredSalary": -1},
        {"savingsMonthly": 10_000_001},
        {"totalSavings": 10_000_001},
        {"lppInsuredSalary": 10_000_001},
    ):
        response = client.patch(f"/api/v1/profiles/{profile_id}", json=payload)
        assert response.status_code == 422, payload

        get_response = client.get(f"/api/v1/profiles/{profile_id}")
        assert get_response.status_code == 200, get_response.text
        body = get_response.json()
        assert body["savingsMonthly"] == 1000
        assert body["totalSavings"] == 5000
        assert body["lppInsuredSalary"] == 60000


def test_update_profile_clears_spouse_fields_when_switching_to_single(client):
    create_response = client.post(
        "/api/v1/profiles",
        json={
            "householdType": "couple",
            "goal": "invest",
            "spouseBirthYear": 1982,
            "spouseIncomeNetMonthly": 5000,
        },
    )
    assert create_response.status_code == 200
    profile_id = create_response.json()["id"]

    response = client.patch(
        f"/api/v1/profiles/{profile_id}",
        json={
            "householdType": "single",
            "spouseBirthYear": 1982,
            "spouseIncomeNetMonthly": 5000,
        },
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["householdType"] == "single"
    assert body["spouseBirthYear"] is None
    assert body["spouseIncomeNetMonthly"] is None
