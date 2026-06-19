"""
Tests for admin local-data claim summary readback.

The endpoint exists for staging/runtime proof only: it must not expose the raw
localDataClaim payload, wizard answers, device id, or user PII.
"""

import json

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.main import app
from tests.conftest import TestingSessionLocal


@pytest.fixture
def auth_client(client: TestClient):
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)
    yield client


def _register(client: TestClient, email: str) -> dict:
    response = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "pass12345"},
    )
    assert response.status_code == 201
    return response.json()


def _promote_admin(email: str) -> None:
    from app.models.user import User

    db = TestingSessionLocal()
    try:
        user = db.query(User).filter(User.email == email).one()
        user.role = "support_admin"
        user.email_verified = True
        db.commit()
    finally:
        db.close()


def test_admin_local_data_claim_summary_is_whitelisted(
    auth_client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
):
    owner = _register(auth_client, "claim-owner@example.com")
    owner_token = owner["access_token"]

    claim_response = auth_client.post(
        "/api/v1/sync/claim-local-data",
        headers={"Authorization": f"Bearer {owner_token}"},
        json={
            "local_data_version": 1,
            "device_id": "ios-device-claim-readback",
            "updated_at": "2026-06-19T08:00:00Z",
            "wizard_answers": {
                "q_income_monthly": 9200,
                "q_canton": "VS",
            },
            "mint2_axis_handoff": {
                "onb_axis_v2": "lpp_rente_capital",
                "onb_axis_schema_version": 2,
                "legacy_onb_intent": "claim-owner@example.com",
                "source_engine": "9200 CHF must-not-leak",
                "receipt_hash": "claim-owner@example.com",
                "receipt_ref": "ios-device-claim-readback",
                "generated_at": "9200",
                "calculation_version": "must-not-leak",
                "regulatory_constants_version_hash": "claim-owner@example.com",
                "raw_note": "must-not-leak",
            },
        },
    )
    assert claim_response.status_code == 200
    profile_id = claim_response.json()["profile_id"]

    admin_email = "claim-admin@example.com"
    admin = _register(auth_client, admin_email)
    _promote_admin(admin_email)

    monkeypatch.setenv("FF_ENABLE_ADMIN_SCREENS", "true")
    monkeypatch.setenv("AUTH_ADMIN_EMAIL_ALLOWLIST", admin_email)
    response = auth_client.get(
        f"/api/v1/admin/local-data-claim-summary/{profile_id}",
        headers={"Authorization": f"Bearer {admin['access_token']}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body == {
        "profile_id": profile_id,
        "has_local_data_claim": True,
        "wizard_answers_count": 2,
        "wizard_answers_contains_axis": False,
        "mint2_axis_handoff_present": True,
        "mint2_axis_id": "lpp_rente_capital",
        "schema_version": 2,
        "legacy_intent_present": True,
        "source_engine_present": True,
        "receipt_hash_present": True,
        "receipt_ref_present": True,
        "generated_at_present": True,
        "calculation_version_present": True,
        "regulatory_constants_version_hash_present": True,
        "meta": {
            "claimed_at_present": True,
            "updated_at_present": True,
            "device_id_present": True,
            "local_data_version": 1,
        },
    }
    serialized = json.dumps(body)
    assert "q_income_monthly" not in serialized
    assert "9200" not in serialized
    assert "CHF" not in serialized
    assert "ios-device-claim-readback" not in serialized
    assert "claim-owner@example.com" not in serialized
    assert "must-not-leak" not in serialized


def test_admin_local_data_claim_summary_requires_flag(
    auth_client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
):
    admin_email = "claim-admin-flag@example.com"
    admin = _register(auth_client, admin_email)
    _promote_admin(admin_email)

    monkeypatch.setenv("FF_ENABLE_ADMIN_SCREENS", "false")
    monkeypatch.setenv("AUTH_ADMIN_EMAIL_ALLOWLIST", admin_email)
    response = auth_client.get(
        "/api/v1/admin/local-data-claim-summary/missing-profile",
        headers={"Authorization": f"Bearer {admin['access_token']}"},
    )

    assert response.status_code == 403
    assert "enable_admin_screens" in response.json()["detail"]


def test_admin_local_data_claim_summary_requires_support_admin_role(
    auth_client: TestClient,
    monkeypatch: pytest.MonkeyPatch,
):
    user_email = "claim-non-admin@example.com"
    user = _register(auth_client, user_email)

    monkeypatch.setenv("FF_ENABLE_ADMIN_SCREENS", "true")
    monkeypatch.setenv("AUTH_ADMIN_EMAIL_ALLOWLIST", user_email)
    response = auth_client.get(
        "/api/v1/admin/local-data-claim-summary/missing-profile",
        headers={"Authorization": f"Bearer {user['access_token']}"},
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "Role support_admin requis"
