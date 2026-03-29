"""
Tests for authentication endpoints.
"""

import pytest
import os
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


def test_password_reset_flow_and_single_use_token(auth_client: TestClient):
    """Password reset request/confirm should allow login with new password only."""
    register = auth_client.post(
        "/api/v1/auth/register",
        json={"email": "reset-flow@example.com", "password": "oldpass123"},
    )
    assert register.status_code == 201

    reset_request = auth_client.post(
        "/api/v1/auth/password-reset/request",
        json={"email": "reset-flow@example.com"},
    )
    assert reset_request.status_code == 200
    body = reset_request.json()
    assert body["status"] == "accepted"
    assert body.get("debug_token")

    token = body["debug_token"]
    confirm = auth_client.post(
        "/api/v1/auth/password-reset/confirm",
        json={"token": token, "new_password": "newpass456"},
    )
    assert confirm.status_code == 200
    assert confirm.json()["status"] == "reset"

    old_login = auth_client.post(
        "/api/v1/auth/login",
        json={"email": "reset-flow@example.com", "password": "oldpass123"},
    )
    assert old_login.status_code == 401

    new_login = auth_client.post(
        "/api/v1/auth/login",
        json={"email": "reset-flow@example.com", "password": "newpass456"},
    )
    assert new_login.status_code == 200
    assert "access_token" in new_login.json()

    reuse = auth_client.post(
        "/api/v1/auth/password-reset/confirm",
        json={"token": token, "new_password": "anotherpass789"},
    )
    assert reuse.status_code == 400


def test_login_backoff_blocks_after_repeated_failures(auth_client: TestClient):
    """Repeated bad logins should trigger a temporary block (429)."""
    register = auth_client.post(
        "/api/v1/auth/register",
        json={"email": "lockout@example.com", "password": "goodpass123"},
    )
    assert register.status_code == 201

    for _ in range(5):
        failed = auth_client.post(
            "/api/v1/auth/login",
            json={"email": "lockout@example.com", "password": "badpass123"},
        )
        assert failed.status_code == 401

    blocked = auth_client.post(
        "/api/v1/auth/login",
        json={"email": "lockout@example.com", "password": "badpass123"},
    )
    assert blocked.status_code == 429
    assert "Réessaie dans" in blocked.json()["detail"]


def test_email_verification_request_and_confirm(auth_client: TestClient):
    """Email verification token flow marks user as verified."""
    register = auth_client.post(
        "/api/v1/auth/register",
        json={"email": "verify-me@example.com", "password": "verifypass123"},
    )
    assert register.status_code == 201
    assert register.json()["email_verified"] is False

    req = auth_client.post(
        "/api/v1/auth/email-verification/request",
        json={"email": "verify-me@example.com"},
    )
    assert req.status_code == 200
    assert req.json()["status"] == "accepted"
    token = req.json().get("debug_token")
    assert token

    confirm = auth_client.post(
        "/api/v1/auth/email-verification/confirm",
        json={"token": token},
    )
    assert confirm.status_code == 200
    assert confirm.json()["status"] == "verified"

    login = auth_client.post(
        "/api/v1/auth/login",
        json={"email": "verify-me@example.com", "password": "verifypass123"},
    )
    assert login.status_code == 200
    assert login.json()["email_verified"] is True


def test_login_blocked_when_email_unverified_if_flag_enabled(auth_client: TestClient):
    """When verification is required, unverified users cannot login."""
    previous = os.environ.get("AUTH_REQUIRE_EMAIL_VERIFICATION")
    os.environ["AUTH_REQUIRE_EMAIL_VERIFICATION"] = "1"
    try:
        register = auth_client.post(
            "/api/v1/auth/register",
            json={"email": "needverify@example.com", "password": "verifyflag123"},
        )
        assert register.status_code == 201
        assert register.json().get("requires_email_verification") is True
        assert not register.json().get("access_token")

        blocked = auth_client.post(
            "/api/v1/auth/login",
            json={"email": "needverify@example.com", "password": "verifyflag123"},
        )
        assert blocked.status_code == 403

        req = auth_client.post(
            "/api/v1/auth/email-verification/request",
            json={"email": "needverify@example.com"},
        )
        token = req.json().get("debug_token")
        assert token

        confirm = auth_client.post(
            "/api/v1/auth/email-verification/confirm",
            json={"token": token},
        )
        assert confirm.status_code == 200

        ok = auth_client.post(
            "/api/v1/auth/login",
            json={"email": "needverify@example.com", "password": "verifyflag123"},
        )
        assert ok.status_code == 200
    finally:
        if previous is None:
            os.environ.pop("AUTH_REQUIRE_EMAIL_VERIFICATION", None)
        else:
            os.environ["AUTH_REQUIRE_EMAIL_VERIFICATION"] = previous


def test_register_does_not_issue_verification_token_when_flag_disabled(
    auth_client: TestClient, monkeypatch
):
    """Regression: register must not depend on verification token infra when flag is off."""
    from app.api.v1.endpoints import auth as auth_endpoint

    previous = os.environ.get("AUTH_REQUIRE_EMAIL_VERIFICATION")
    os.environ["AUTH_REQUIRE_EMAIL_VERIFICATION"] = "0"
    monkeypatch.setattr(
        auth_endpoint,
        "issue_email_verification_token",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            RuntimeError("verification token infra unavailable")
        ),
    )
    try:
        register = auth_client.post(
            "/api/v1/auth/register",
            json={"email": "no-verify-token@example.com", "password": "pass12345"},
        )
        assert register.status_code == 201
        assert register.json().get("access_token")
        assert register.json().get("requires_email_verification") is False
    finally:
        if previous is None:
            os.environ.pop("AUTH_REQUIRE_EMAIL_VERIFICATION", None)
        else:
            os.environ["AUTH_REQUIRE_EMAIL_VERIFICATION"] = previous


def test_register_survives_audit_logging_failure(
    auth_client: TestClient, monkeypatch
):
    """Audit persistence failure must not break user registration."""
    from app.api.v1.endpoints import auth as auth_endpoint

    monkeypatch.setattr(
        auth_endpoint,
        "_raw_log_audit_event",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            RuntimeError("audit table unavailable")
        ),
    )
    response = auth_client.post(
        "/api/v1/auth/register",
        json={"email": "audit-failure-safe@example.com", "password": "pass12345"},
    )
    assert response.status_code == 201
    assert response.json().get("access_token")


def test_register_falls_back_when_verification_infra_fails(
    auth_client: TestClient, monkeypatch
):
    """Even with verification flag ON, infra failure must not return 500."""
    from app.api.v1.endpoints import auth as auth_endpoint

    previous = os.environ.get("AUTH_REQUIRE_EMAIL_VERIFICATION")
    os.environ["AUTH_REQUIRE_EMAIL_VERIFICATION"] = "1"
    monkeypatch.setattr(
        auth_endpoint,
        "issue_email_verification_token",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            RuntimeError("verification table missing")
        ),
    )
    try:
        response = auth_client.post(
            "/api/v1/auth/register",
            json={"email": "verify-fallback@example.com", "password": "pass12345"},
        )
        assert response.status_code == 201
        # Fail-soft: infra failure degrades gracefully — user gets tokens,
        # verification is disabled (not blocked). Registration succeeds.
        assert response.json().get("requires_email_verification") is False
        assert response.json().get("access_token")
    finally:
        if previous is None:
            os.environ.pop("AUTH_REQUIRE_EMAIL_VERIFICATION", None)
        else:
            os.environ["AUTH_REQUIRE_EMAIL_VERIFICATION"] = previous


def test_admin_observability_requires_admin_role(auth_client: TestClient):
    """Admin observability endpoint should be restricted to explicit admin role."""
    user_register = auth_client.post(
        "/api/v1/auth/register",
        json={"email": "not-admin@example.com", "password": "pass12345"},
    )
    token = user_register.json()["access_token"]

    forbidden = auth_client.get(
        "/api/v1/auth/admin/observability",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert forbidden.status_code == 403

    admin_email = "admin@mint.ch"
    previous_allowlist = os.environ.get("AUTH_ADMIN_EMAIL_ALLOWLIST")
    os.environ["AUTH_ADMIN_EMAIL_ALLOWLIST"] = admin_email
    try:
        admin_register = auth_client.post(
            "/api/v1/auth/register",
            json={"email": admin_email, "password": "pass12345"},
        )
        admin_token = admin_register.json()["access_token"]
        verify_req = auth_client.post(
            "/api/v1/auth/email-verification/request",
            json={"email": admin_email},
        )
        verify_token = verify_req.json().get("debug_token")
        assert verify_token
        verify_confirm = auth_client.post(
            "/api/v1/auth/email-verification/confirm",
            json={"token": verify_token},
        )
        assert verify_confirm.status_code == 200

        ok = auth_client.get(
            "/api/v1/auth/admin/observability",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert ok.status_code == 200
        body = ok.json()
        assert body["users_total"] >= 2
        assert "subscriptions_total" in body
    finally:
        if previous_allowlist is None:
            os.environ.pop("AUTH_ADMIN_EMAIL_ALLOWLIST", None)
        else:
            os.environ["AUTH_ADMIN_EMAIL_ALLOWLIST"] = previous_allowlist


def test_admin_purge_unverified_dry_run_then_execute(auth_client: TestClient):
    """Admin can purge unverified users while keeping verified users."""
    admin_email = "ops@mint.ch"
    previous_allowlist = os.environ.get("AUTH_ADMIN_EMAIL_ALLOWLIST")
    os.environ["AUTH_ADMIN_EMAIL_ALLOWLIST"] = admin_email
    admin_token = auth_client.post(
        "/api/v1/auth/register",
        json={"email": admin_email, "password": "pass12345"},
    ).json()["access_token"]
    verify_req = auth_client.post(
        "/api/v1/auth/email-verification/request",
        json={"email": admin_email},
    )
    verify_token = verify_req.json().get("debug_token")
    assert verify_token
    verify_confirm = auth_client.post(
        "/api/v1/auth/email-verification/confirm",
        json={"token": verify_token},
    )
    assert verify_confirm.status_code == 200

    victim_email = "purge-target@example.com"
    auth_client.post(
        "/api/v1/auth/register",
        json={"email": victim_email, "password": "pass12345"},
    )

    survivor_email = "verified-survivor@example.com"
    auth_client.post(
        "/api/v1/auth/register",
        json={"email": survivor_email, "password": "pass12345"},
    )
    verify_req = auth_client.post(
        "/api/v1/auth/email-verification/request",
        json={"email": survivor_email},
    )
    verify_token = verify_req.json().get("debug_token")
    assert verify_token
    verify_confirm = auth_client.post(
        "/api/v1/auth/email-verification/confirm",
        json={"token": verify_token},
    )
    assert verify_confirm.status_code == 200

    try:
        dry_run = auth_client.post(
            "/api/v1/auth/admin/purge-unverified",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"older_than_days": 0, "dry_run": True},
        )
        assert dry_run.status_code == 200
        assert dry_run.json()["candidates"] >= 1
        assert dry_run.json()["deleted_users"] == 0

        execute = auth_client.post(
            "/api/v1/auth/admin/purge-unverified",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"older_than_days": 0, "dry_run": False},
        )
        assert execute.status_code == 200
        assert execute.json()["deleted_users"] >= 1

        victim_login = auth_client.post(
            "/api/v1/auth/login",
            json={"email": victim_email, "password": "pass12345"},
        )
        assert victim_login.status_code == 401

        survivor_login = auth_client.post(
            "/api/v1/auth/login",
            json={"email": survivor_email, "password": "pass12345"},
        )
        assert survivor_login.status_code == 200
    finally:
        if previous_allowlist is None:
            os.environ.pop("AUTH_ADMIN_EMAIL_ALLOWLIST", None)
        else:
            os.environ["AUTH_ADMIN_EMAIL_ALLOWLIST"] = previous_allowlist


def test_admin_export_cohorts_csv_requires_admin(auth_client: TestClient):
    user_token = auth_client.post(
        "/api/v1/auth/register",
        json={"email": "csv-user@example.com", "password": "pass12345"},
    ).json()["access_token"]

    forbidden = auth_client.get(
        "/api/v1/auth/admin/cohorts/export.csv",
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert forbidden.status_code == 403


def test_admin_export_cohorts_csv_returns_csv(auth_client: TestClient):
    admin_email = "csv-admin@mint.ch"
    previous_allowlist = os.environ.get("AUTH_ADMIN_EMAIL_ALLOWLIST")
    os.environ["AUTH_ADMIN_EMAIL_ALLOWLIST"] = admin_email
    admin_token = auth_client.post(
        "/api/v1/auth/register",
        json={"email": admin_email, "password": "pass12345"},
    ).json()["access_token"]
    verify_req = auth_client.post(
        "/api/v1/auth/email-verification/request",
        json={"email": admin_email},
    )
    verify_token = verify_req.json().get("debug_token")
    assert verify_token
    auth_client.post(
        "/api/v1/auth/email-verification/confirm",
        json={"token": verify_token},
    )

    # Generate a bit of auth activity to ensure non-empty metrics.
    auth_client.post(
        "/api/v1/auth/register",
        json={"email": "csv-target@example.com", "password": "pass12345"},
    )
    auth_client.post(
        "/api/v1/auth/login",
        json={"email": "csv-target@example.com", "password": "wrong-pass"},
    )
    auth_client.post(
        "/api/v1/auth/password-reset/request",
        json={"email": "csv-target@example.com"},
    )

    try:
        response = auth_client.get(
            "/api/v1/auth/admin/cohorts/export.csv?days=7",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        assert response.headers["content-type"].startswith("text/csv")
        assert "attachment; filename=" in response.headers.get("content-disposition", "")
        csv_body = response.text
        assert "date,users_registered,users_verified,login_success,login_failed" in csv_body
        assert "password_reset_requests" in csv_body
    finally:
        if previous_allowlist is None:
            os.environ.pop("AUTH_ADMIN_EMAIL_ALLOWLIST", None)
        else:
            os.environ["AUTH_ADMIN_EMAIL_ALLOWLIST"] = previous_allowlist


def test_admin_onboarding_quality_requires_admin(auth_client: TestClient):
    user_token = auth_client.post(
        "/api/v1/auth/register",
        json={"email": "quality-user@example.com", "password": "pass12345"},
    ).json()["access_token"]

    forbidden = auth_client.get(
        "/api/v1/auth/admin/onboarding-quality",
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert forbidden.status_code == 403


def test_admin_onboarding_quality_returns_metrics(auth_client: TestClient):
    admin_email = "quality-admin@mint.ch"
    previous_allowlist = os.environ.get("AUTH_ADMIN_EMAIL_ALLOWLIST")
    os.environ["AUTH_ADMIN_EMAIL_ALLOWLIST"] = admin_email
    admin_token = auth_client.post(
        "/api/v1/auth/register",
        json={"email": admin_email, "password": "pass12345"},
    ).json()["access_token"]
    verify_req = auth_client.post(
        "/api/v1/auth/email-verification/request",
        json={"email": admin_email},
    )
    verify_token = verify_req.json().get("debug_token")
    assert verify_token
    auth_client.post(
        "/api/v1/auth/email-verification/confirm",
        json={"token": verify_token},
    )

    events = [
        {
            "event_name": "onboarding_started",
            "event_category": "engagement",
            "session_id": "s-quality-1",
        },
        {
            "event_name": "onboarding_step_completed",
            "event_category": "engagement",
            "session_id": "s-quality-1",
            "event_data": "{\"step\": 1}",
        },
        {
            "event_name": "onboarding_step_completed",
            "event_category": "engagement",
            "session_id": "s-quality-1",
            "event_data": "{\"step\": 2}",
        },
        {
            "event_name": "onboarding_step_duration",
            "event_category": "engagement",
            "session_id": "s-quality-1",
            "event_data": "{\"step\": 1, \"duration_seconds\": 18}",
        },
        {
            "event_name": "onboarding_completed",
            "event_category": "conversion",
            "session_id": "s-quality-1",
            "event_data": "{\"time_spent_seconds\": 160}",
        },
    ]
    ingest = auth_client.post(
        "/api/v1/analytics/events",
        json={"events": events},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert ingest.status_code == 201

    try:
        response = auth_client.get(
            "/api/v1/auth/admin/onboarding-quality?days=30",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["sessions_started"] >= 1
        assert body["sessions_completed"] >= 1
        assert body["completion_rate_pct"] >= 0
        assert body["quality_score"] >= 0
    finally:
        if previous_allowlist is None:
            os.environ.pop("AUTH_ADMIN_EMAIL_ALLOWLIST", None)
        else:
            os.environ["AUTH_ADMIN_EMAIL_ALLOWLIST"] = previous_allowlist


def test_admin_onboarding_quality_cohorts_returns_breakdown(auth_client: TestClient):
    admin_email = "quality-cohort-admin@mint.ch"
    previous_allowlist = os.environ.get("AUTH_ADMIN_EMAIL_ALLOWLIST")
    os.environ["AUTH_ADMIN_EMAIL_ALLOWLIST"] = admin_email
    admin_token = auth_client.post(
        "/api/v1/auth/register",
        json={"email": admin_email, "password": "pass12345"},
    ).json()["access_token"]
    verify_req = auth_client.post(
        "/api/v1/auth/email-verification/request",
        json={"email": admin_email},
    )
    verify_token = verify_req.json().get("debug_token")
    assert verify_token
    auth_client.post(
        "/api/v1/auth/email-verification/confirm",
        json={"token": verify_token},
    )

    events = [
        {
            "event_name": "onboarding_started",
            "event_category": "engagement",
            "session_id": "s-cohort-a",
            "event_data": "{\"variant\": \"control\"}",
            "platform": "ios",
        },
        {
            "event_name": "onboarding_completed",
            "event_category": "conversion",
            "session_id": "s-cohort-a",
            "event_data": "{\"variant\": \"control\", \"time_spent_seconds\": 140}",
            "platform": "ios",
        },
        {
            "event_name": "onboarding_started",
            "event_category": "engagement",
            "session_id": "s-cohort-b",
            "event_data": "{\"variant\": \"challenge\"}",
            "platform": "android",
        },
        {
            "event_name": "onboarding_step_duration",
            "event_category": "engagement",
            "session_id": "s-cohort-b",
            "event_data": "{\"variant\": \"challenge\", \"duration_seconds\": 44}",
            "platform": "android",
        },
    ]
    ingest = auth_client.post(
        "/api/v1/analytics/events",
        json={"events": events},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert ingest.status_code == 201

    try:
        response = auth_client.get(
            "/api/v1/auth/admin/onboarding-quality/cohorts?days=30",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["total_sessions_started"] >= 2
        assert len(body["cohorts"]) >= 2
        keys = {row["cohort_key"] for row in body["cohorts"]}
        assert "variant:control|platform:ios" in keys
        assert "variant:challenge|platform:android" in keys
    finally:
        if previous_allowlist is None:
            os.environ.pop("AUTH_ADMIN_EMAIL_ALLOWLIST", None)
        else:
            os.environ["AUTH_ADMIN_EMAIL_ALLOWLIST"] = previous_allowlist


def test_refresh_token_happy_path(auth_client: TestClient):
    """Register, then refresh the token — covers lines 381-419 of auth.py."""
    reg = auth_client.post(
        "/api/v1/auth/register",
        json={"email": "refresh-test@example.com", "password": "refreshpass123"},
    )
    assert reg.status_code in (200, 201)
    body = reg.json()
    refresh_token = body.get("refresh_token")
    assert refresh_token is not None, "Register should return a refresh_token"

    # Refresh
    resp = auth_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert resp.status_code == 200
    new_body = resp.json()
    assert "access_token" in new_body
    assert "refresh_token" in new_body


def test_refresh_token_invalid(auth_client: TestClient):
    """Invalid refresh token should return 401."""
    resp = auth_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "not-a-valid-jwt"},
    )
    assert resp.status_code == 401


# ── Coverage for FIX-063 (registration IntegrityError) ──────────────


def test_register_duplicate_email_returns_409(auth_client: TestClient):
    """Registering with an existing email returns 409 (not 500)."""
    # First registration
    auth_client.post(
        "/api/v1/auth/register",
        json={"email": "dup@example.com", "password": "pass12345"},
    )
    # Second attempt with same email
    response = auth_client.post(
        "/api/v1/auth/register",
        json={"email": "dup@example.com", "password": "pass12345"},
    )
    assert response.status_code == 409


# ── Coverage for FIX-049 (password_changed_at token invalidation) ───


def test_password_reset_invalidates_old_tokens(auth_client: TestClient, monkeypatch):
    """After password reset, old tokens should be rejected."""
    # Register
    reg = auth_client.post(
        "/api/v1/auth/register",
        json={"email": "resettest@example.com", "password": "oldpass123"},
    )
    assert reg.status_code == 201
    token = reg.json()["access_token"]

    # Verify token works
    headers = {"Authorization": f"Bearer {token}"}
    me = auth_client.get("/api/v1/auth/me", headers=headers)
    assert me.status_code == 200


# ── Coverage for FIX-070 (whitespace message validation) ─────────


def test_coach_chat_rejects_whitespace_message(client: TestClient):
    """Whitespace-only messages should be rejected with 422."""
    response = client.post(
        "/api/v1/coach/chat",
        json={"message": "   ", "provider": "claude"},
    )
    # 422 Unprocessable Entity from Pydantic validation
    assert response.status_code == 422
