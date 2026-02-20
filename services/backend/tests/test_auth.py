"""
Tests for authentication endpoints.
"""

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.main import app


@pytest.fixture
def auth_client(client: TestClient):
    """Client without auth override — for testing real JWT flow."""
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)
    yield client


def test_register_new_user(client: TestClient):
    """Test 1: Register new user returns 201 and token."""
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "test@example.com",
            "password": "testpass123",
            "display_name": "Test User",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["email"] == "test@example.com"
    assert "user_id" in data


def test_register_duplicate_email(client: TestClient):
    """Test 2: Register duplicate email returns 409."""
    # Register first user
    client.post(
        "/api/v1/auth/register",
        json={
            "email": "duplicate@example.com",
            "password": "testpass123",
        },
    )

    # Try to register with same email
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "duplicate@example.com",
            "password": "otherpass456",
        },
    )
    assert response.status_code == 409
    assert "existe déjà" in response.json()["detail"]


def test_register_short_password(client: TestClient):
    """Test: Register with short password returns 422."""
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "short@example.com",
            "password": "short",
        },
    )
    assert response.status_code == 422


def test_login_correct_credentials(client: TestClient):
    """Test 3: Login with correct credentials returns 200 and token."""
    # Register user
    client.post(
        "/api/v1/auth/register",
        json={
            "email": "login@example.com",
            "password": "loginpass123",
        },
    )

    # Login
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "login@example.com",
            "password": "loginpass123",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["email"] == "login@example.com"


def test_login_wrong_password(client: TestClient):
    """Test 4: Login with wrong password returns 401."""
    # Register user
    client.post(
        "/api/v1/auth/register",
        json={
            "email": "wrongpass@example.com",
            "password": "correctpass123",
        },
    )

    # Try to login with wrong password
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "wrongpass@example.com",
            "password": "wrongpassword",
        },
    )
    assert response.status_code == 401
    assert "incorrect" in response.json()["detail"].lower()


def test_login_nonexistent_user(client: TestClient):
    """Test: Login with nonexistent user returns 401."""
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "nonexistent@example.com",
            "password": "anypassword123",
        },
    )
    assert response.status_code == 401


def test_get_me_with_valid_token(auth_client: TestClient):
    """Test 5: Access /auth/me with valid token returns 200 and user info."""
    # Register user
    register_response = auth_client.post(
        "/api/v1/auth/register",
        json={
            "email": "getme@example.com",
            "password": "getmepass123",
            "display_name": "GetMe User",
        },
    )
    token = register_response.json()["access_token"]

    # Access /auth/me
    response = auth_client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "getme@example.com"
    assert data["display_name"] == "GetMe User"
    assert "id" in data
    assert "created_at" in data


def test_get_me_without_token(auth_client: TestClient):
    """Test 6: Access /auth/me without token returns 401/403."""
    response = auth_client.get("/api/v1/auth/me")
    # Should return 401 or 403 (depends on HTTPBearer auto_error setting)
    assert response.status_code in [401, 403]


def test_get_me_with_invalid_token(auth_client: TestClient):
    """Test: Access /auth/me with invalid token returns 401."""
    response = auth_client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer invalid-token-xyz"},
    )
    assert response.status_code == 401


def test_create_profile_with_auth(client: TestClient):
    """Test 7: Create profile with auth links it to user."""
    # Register and get token
    register_response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "profileauth@example.com",
            "password": "profilepass123",
        },
    )
    token = register_response.json()["access_token"]

    # Create profile with auth
    response = client.post(
        "/api/v1/profiles",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "householdType": "single",
            "birthYear": 1990,
            "canton": "VD",
        },
    )
    assert response.status_code == 200
    profile = response.json()
    assert profile["birthYear"] == 1990
    assert profile["canton"] == "VD"


def test_access_other_user_profile(auth_client: TestClient):
    """Test 8: Access other user's profile returns 403."""
    # Register first user and create profile
    user1_response = auth_client.post(
        "/api/v1/auth/register",
        json={
            "email": "user1@example.com",
            "password": "user1pass123",
        },
    )
    user1_token = user1_response.json()["access_token"]

    profile_response = auth_client.post(
        "/api/v1/profiles",
        headers={"Authorization": f"Bearer {user1_token}"},
        json={
            "householdType": "single",
            "birthYear": 1990,
        },
    )
    profile_id = profile_response.json()["id"]

    # Register second user
    user2_response = auth_client.post(
        "/api/v1/auth/register",
        json={
            "email": "user2@example.com",
            "password": "user2pass123",
        },
    )
    user2_token = user2_response.json()["access_token"]

    # Try to access user1's profile with user2's token
    response = auth_client.get(
        f"/api/v1/profiles/{profile_id}",
        headers={"Authorization": f"Bearer {user2_token}"},
    )
    assert response.status_code == 403
    assert "authorized" in response.json()["detail"].lower()


def test_update_other_user_profile(auth_client: TestClient):
    """Test: Update other user's profile returns 403."""
    # Register first user and create profile
    user1_response = auth_client.post(
        "/api/v1/auth/register",
        json={
            "email": "update1@example.com",
            "password": "update1pass123",
        },
    )
    user1_token = user1_response.json()["access_token"]

    profile_response = auth_client.post(
        "/api/v1/profiles",
        headers={"Authorization": f"Bearer {user1_token}"},
        json={
            "householdType": "single",
            "birthYear": 1990,
        },
    )
    profile_id = profile_response.json()["id"]

    # Register second user
    user2_response = auth_client.post(
        "/api/v1/auth/register",
        json={
            "email": "update2@example.com",
            "password": "update2pass123",
        },
    )
    user2_token = user2_response.json()["access_token"]

    # Try to update user1's profile with user2's token
    response = auth_client.patch(
        f"/api/v1/profiles/{profile_id}",
        headers={"Authorization": f"Bearer {user2_token}"},
        json={"birthYear": 1995},
    )
    assert response.status_code == 403


def test_anonymous_profile_access(client: TestClient):
    """Test: Anonymous profile creation and access still works."""
    # Create profile without auth
    create_response = client.post(
        "/api/v1/profiles",
        json={
            "householdType": "single",
            "birthYear": 1985,
        },
    )
    assert create_response.status_code == 200
    profile_id = create_response.json()["id"]

    # Access profile without auth
    get_response = client.get(f"/api/v1/profiles/{profile_id}")
    assert get_response.status_code == 200
    assert get_response.json()["birthYear"] == 1985


def test_delete_account_purges_user_profiles_and_sessions(auth_client: TestClient):
    """Deleting account removes user and linked profile/session data."""
    register = auth_client.post(
        "/api/v1/auth/register",
        json={"email": "delete-me@example.com", "password": "deletepass123"},
    )
    token = register.json()["access_token"]

    profile = auth_client.post(
        "/api/v1/profiles",
        headers={"Authorization": f"Bearer {token}"},
        json={"householdType": "single", "birthYear": 1991, "canton": "VD"},
    ).json()
    profile_id = profile["id"]

    session_resp = auth_client.post(
        "/api/v1/sessions",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "profileId": profile_id,
            "answers": {"q_birth_year": 1991},
            "selectedFocusKinds": ["retirement"],
        },
    )
    assert session_resp.status_code == 200

    delete_resp = auth_client.delete(
        "/api/v1/auth/account",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert delete_resp.status_code == 200
    body = delete_resp.json()
    assert body["status"] == "deleted"
    assert body["deleted_profiles"] >= 1
    assert body["deleted_sessions"] >= 1

    me_resp = auth_client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert me_resp.status_code == 401

    relogin = auth_client.post(
        "/api/v1/auth/login",
        json={"email": "delete-me@example.com", "password": "deletepass123"},
    )
    assert relogin.status_code == 401


def test_claim_local_data_creates_and_updates_cloud_profile(auth_client: TestClient):
    """Claim endpoint migrates local snapshot and is idempotent on next call."""
    register = auth_client.post(
        "/api/v1/auth/register",
        json={"email": "claim-local@example.com", "password": "claimpass123"},
    )
    token = register.json()["access_token"]

    payload = {
        "local_data_version": 1,
        "device_id": "ios-device-abc123",
        "mini_onboarding": {
            "q_birth_year": 1988,
            "q_canton": "VS",
            "q_income_monthly": 9200,
            "q_household_type": "couple",
            "q_goal": "retire",
        },
        "wizard_answers": {"q_has_debt": False},
        "budget_snapshot": {"income": 9200, "rent": 1900},
        "checkins": [{"month": "2026-02", "score": 78}],
    }

    first = auth_client.post(
        "/api/v1/sync/claim-local-data",
        headers={"Authorization": f"Bearer {token}"},
        json=payload,
    )
    assert first.status_code == 200
    first_body = first.json()
    assert first_body["status"] == "ok"
    assert first_body["created_profile"] is True
    assert first_body["merged_fields_count"] >= 1

    second = auth_client.post(
        "/api/v1/sync/claim-local-data",
        headers={"Authorization": f"Bearer {token}"},
        json=payload,
    )
    assert second.status_code == 200
    second_body = second.json()
    assert second_body["status"] == "ok"
    assert second_body["created_profile"] is False
    assert second_body["profile_id"] == first_body["profile_id"]
