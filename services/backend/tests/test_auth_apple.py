"""Apple Sign-In auth contract tests."""

from __future__ import annotations

import base64
import json
import time

import pytest
from fastapi.testclient import TestClient

from app.api.v1.endpoints import auth as auth_endpoint
from app.core.auth import get_current_user, require_current_user
from app.main import app
from app.models.audit_event import AuditEventModel
from app.models.user import User
from tests.conftest import TestingSessionLocal


def _b64url_json(payload: dict[str, object]) -> str:
    raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _forged_apple_identity_token() -> str:
    header = _b64url_json({"alg": "none", "kid": "forged"})
    payload = _b64url_json(
        {
            "iss": "https://appleid.apple.com",
            "aud": "ch.mint.app",
            "exp": int(time.time()) + 3600,
            "iat": int(time.time()),
            "sub": "001999.forged-apple-sub",
            "email": "forged-apple@example.invalid",
        }
    )
    return f"{header}.{payload}.forged-signature"


def test_apple_verify_rejects_forged_identity_token(client: TestClient):
    """Unsigned Apple-shaped JWTs must not create or restore Mint accounts."""
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)

    response = client.post(
        "/api/v1/auth/apple/verify",
        json={
            "identity_token": _forged_apple_identity_token(),
            "nonce": "plain-nonce-from-client",
        },
    )

    assert response.status_code in {400, 401}


class _FakeAppleSigningKey:
    key = object()


def _patch_valid_apple_header_and_key(monkeypatch) -> None:
    monkeypatch.setattr(
        auth_endpoint.jwt,
        "get_unverified_header",
        lambda identity_token: {"alg": "RS256", "kid": "apple-key"},
    )
    monkeypatch.setattr(
        auth_endpoint._APPLE_JWKS_CLIENT,
        "get_signing_key_from_jwt",
        lambda identity_token: _FakeAppleSigningKey(),
    )


def test_verify_apple_identity_token_requires_nonce():
    with pytest.raises(auth_endpoint.HTTPException) as exc_info:
        auth_endpoint._verify_apple_identity_token("signed-token", "")

    assert exc_info.value.status_code == 400


def test_verify_apple_identity_token_requires_non_null_nonce():
    with pytest.raises(auth_endpoint.HTTPException) as exc_info:
        auth_endpoint._verify_apple_identity_token("signed-token", None)

    assert exc_info.value.status_code == 400


def test_verify_apple_identity_token_rejects_nonce_mismatch(monkeypatch):
    _patch_valid_apple_header_and_key(monkeypatch)
    monkeypatch.setattr(
        auth_endpoint.jwt,
        "decode",
        lambda *args, **kwargs: {
            "sub": "001999.apple-sub",
            "nonce": "wrong-nonce-hash",
        },
    )

    with pytest.raises(auth_endpoint.HTTPException) as exc_info:
        auth_endpoint._verify_apple_identity_token("signed-token", "plain-nonce")

    assert exc_info.value.status_code == 401


def test_verify_apple_identity_token_accepts_configured_audience_list(monkeypatch):
    _patch_valid_apple_header_and_key(monkeypatch)
    captured = {}
    expected_nonce = auth_endpoint.hashlib.sha256(b"plain-nonce").hexdigest()

    monkeypatch.setenv("APPLE_SIGN_IN_AUDIENCE", "ch.mint.dev, ch.mint.app")

    def fake_decode(*args, **kwargs):
        captured["audience"] = kwargs["audience"]
        return {
            "sub": "001999.apple-sub",
            "nonce": expected_nonce,
        }

    monkeypatch.setattr(auth_endpoint.jwt, "decode", fake_decode)

    payload = auth_endpoint._verify_apple_identity_token(
        "signed-token",
        "plain-nonce",
    )

    assert payload["sub"] == "001999.apple-sub"
    assert captured["audience"] == ["ch.mint.dev", "ch.mint.app"]


def test_verify_apple_identity_token_rejects_wrong_audience(monkeypatch):
    _patch_valid_apple_header_and_key(monkeypatch)

    def fake_decode(*args, **kwargs):
        raise auth_endpoint.jwt.InvalidAudienceError("bad audience")

    monkeypatch.setattr(auth_endpoint.jwt, "decode", fake_decode)

    with pytest.raises(auth_endpoint.HTTPException) as exc_info:
        auth_endpoint._verify_apple_identity_token("signed-token", "nonce")

    assert exc_info.value.status_code == 401


def test_verify_apple_identity_token_returns_503_when_jwks_unavailable(
    monkeypatch,
):
    monkeypatch.setattr(
        auth_endpoint.jwt,
        "get_unverified_header",
        lambda identity_token: {"alg": "RS256", "kid": "apple-key"},
    )
    monkeypatch.setattr(
        auth_endpoint._APPLE_JWKS_CLIENT,
        "get_signing_key_from_jwt",
        lambda identity_token: (_ for _ in ()).throw(RuntimeError("jwks down")),
    )

    with pytest.raises(auth_endpoint.HTTPException) as exc_info:
        auth_endpoint._verify_apple_identity_token("signed-token", "nonce")

    assert exc_info.value.status_code == 503


def test_apple_verify_reuses_account_by_stable_sub_when_email_changes(
    client: TestClient,
    monkeypatch,
):
    """Apple relay email changes must not create a second Mint account."""
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)

    payloads = {
        "first-token": {
            "sub": "001999.stable-apple-sub",
            "email": "first-relay@privaterelay.appleid.com",
        },
        "second-token": {
            "sub": "001999.stable-apple-sub",
            "email": "second-relay@privaterelay.appleid.com",
        },
    }

    def fake_verify(identity_token: str, nonce: str | None) -> dict[str, str]:
        return payloads[identity_token]

    monkeypatch.setattr(
        auth_endpoint,
        "_verify_apple_identity_token",
        fake_verify,
    )

    first = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "first-token", "nonce": "nonce"},
    )
    second = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "second-token", "nonce": "nonce"},
    )

    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["userId"] == first.json()["userId"]


def test_apple_verify_after_account_delete_returns_recreate_required_without_token(
    client: TestClient,
    monkeypatch,
):
    """Deleted Apple subjects must not silently create a fresh authenticated session."""
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)

    payloads = {
        "first-token": {
            "sub": "001999.deleted-apple-sub",
            "email": "deleted-apple@example.invalid",
        },
        "second-token": {
            "sub": "001999.deleted-apple-sub",
            "email": "deleted-apple@example.invalid",
        },
    }

    def fake_verify(identity_token: str, nonce: str | None) -> dict[str, str]:
        return payloads[identity_token]

    monkeypatch.setattr(
        auth_endpoint,
        "_verify_apple_identity_token",
        fake_verify,
    )

    first = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "first-token", "nonce": "nonce"},
    )
    assert first.status_code == 200
    first_body = first.json()
    access_token = first_body["accessToken"]

    deleted = client.delete(
        "/api/v1/auth/account",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert deleted.status_code == 200

    stale_me = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert stale_me.status_code == 401

    second = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "second-token", "nonce": "nonce"},
    )

    assert second.status_code == 409
    second_body = second.json()
    assert second_body["detail"] == {
        "code": "recreate_required",
        "message": "Apple account was deleted. Recreate it explicitly to continue.",
    }
    assert "accessToken" not in second_body
    assert "access_token" not in second_body


def test_apple_verify_recreates_deleted_subject_only_with_explicit_create_opt_in(
    client: TestClient,
    monkeypatch,
):
    """Register Apple can create a fresh account after delete; login cannot."""
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)

    payloads = {
        "first-token": {
            "sub": "001999.recreate-apple-sub",
            "email": "recreate-apple@example.invalid",
        },
        "second-token": {
            "sub": "001999.recreate-apple-sub",
            "email": "recreate-apple@example.invalid",
        },
        "third-token": {
            "sub": "001999.recreate-apple-sub",
            "email": "recreate-apple@example.invalid",
        },
    }

    def fake_verify(identity_token: str, nonce: str | None) -> dict[str, str]:
        return payloads[identity_token]

    monkeypatch.setattr(
        auth_endpoint,
        "_verify_apple_identity_token",
        fake_verify,
    )

    first = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "first-token", "nonce": "nonce"},
    )
    assert first.status_code == 200
    first_body = first.json()

    deleted = client.delete(
        "/api/v1/auth/account",
        headers={"Authorization": f"Bearer {first_body['accessToken']}"},
    )
    assert deleted.status_code == 200

    recreated = client.post(
        "/api/v1/auth/apple/verify",
        json={
            "identity_token": "second-token",
            "nonce": "nonce",
            "allowRecreateAfterDelete": True,
        },
    )
    assert recreated.status_code == 200
    recreated_body = recreated.json()
    assert recreated_body["userId"] != first_body["userId"]
    assert recreated_body["email"] == "recreate-apple@example.invalid"

    db = TestingSessionLocal()
    try:
        event = (
            db.query(AuditEventModel)
            .filter(
                AuditEventModel.event_type == "auth.apple_verify",
                AuditEventModel.status == "recreate_confirmed",
            )
            .one()
        )
        details = json.loads(event.details_json or "{}")
        assert details["provider"] == "apple"
        assert details["provider_subject_hash"] == auth_endpoint._provider_subject_hash(
            "apple",
            "001999.recreate-apple-sub",
        )
    finally:
        db.close()

    login_existing_recreated = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "third-token", "nonce": "nonce"},
    )
    assert login_existing_recreated.status_code == 200
    assert login_existing_recreated.json()["userId"] == recreated_body["userId"]


def test_apple_register_intent_creates_new_account_without_prior_delete(
    client: TestClient,
    monkeypatch,
):
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)

    payloads = {
        "first-token": {
            "sub": "001999.brand-new-register-intent",
            "email": "brand-new-register@example.ch",
        },
        "second-token": {
            "sub": "001999.brand-new-register-intent",
            "email": "brand-new-register@example.ch",
        },
    }

    def fake_verify(identity_token: str, nonce: str | None) -> dict[str, str]:
        return payloads[identity_token]

    monkeypatch.setattr(
        auth_endpoint,
        "_verify_apple_identity_token",
        fake_verify,
    )

    created = client.post(
        "/api/v1/auth/apple/verify",
        json={
            "identity_token": "first-token",
            "nonce": "nonce",
            "allowRecreateAfterDelete": True,
        },
    )

    assert created.status_code == 200
    created_body = created.json()
    assert created_body["email"] == "brand-new-register@example.ch"

    login_existing = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "second-token", "nonce": "nonce"},
    )
    assert login_existing.status_code == 200
    assert login_existing.json()["userId"] == created_body["userId"]


def test_apple_register_intent_does_not_link_to_live_email_without_prior_delete(
    client: TestClient,
    monkeypatch,
):
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)

    payloads = {
        "apple-token": {
            "sub": "001999.register-intent-live-email",
            "email": "live-register-intent@example.ch",
        },
    }

    def fake_verify(identity_token: str, nonce: str | None) -> dict[str, str]:
        return payloads[identity_token]

    monkeypatch.setattr(
        auth_endpoint,
        "_verify_apple_identity_token",
        fake_verify,
    )

    email_account = client.post(
        "/api/v1/auth/register",
        json={
            "email": "live-register-intent@example.ch",
            "password": "correct horse battery staple",
        },
    )
    assert email_account.status_code == 201

    register_intent = client.post(
        "/api/v1/auth/apple/verify",
        json={
            "identity_token": "apple-token",
            "nonce": "nonce",
            "allowRecreateAfterDelete": True,
        },
    )

    assert register_intent.status_code == 409
    assert register_intent.json()["detail"]["code"] == "apple_email_already_linked"

    db = TestingSessionLocal()
    try:
        live_user = (
            db.query(User)
            .filter(User.email == "live-register-intent@example.ch")
            .one()
        )
        assert live_user.apple_sub is None
        event = (
            db.query(AuditEventModel)
            .filter(
                AuditEventModel.event_type == "auth.apple_verify",
                AuditEventModel.status == "apple_email_already_linked",
            )
            .one()
        )
        assert event.user_id == live_user.id
        details = json.loads(event.details_json or "{}")
        assert details["allow_recreate_after_delete"] is True
    finally:
        db.close()


def test_apple_recreate_does_not_link_to_live_email_account(
    client: TestClient,
    monkeypatch,
):
    """Register/recreate intent must not attach Apple to an existing email account."""
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)

    payloads = {
        "first-token": {
            "sub": "001999.deleted-then-email-live",
            "email": "live-after-delete@example.ch",
        },
        "second-token": {
            "sub": "001999.deleted-then-email-live",
            "email": "live-after-delete@example.ch",
        },
    }

    def fake_verify(identity_token: str, nonce: str | None) -> dict[str, str]:
        return payloads[identity_token]

    monkeypatch.setattr(
        auth_endpoint,
        "_verify_apple_identity_token",
        fake_verify,
    )

    first = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "first-token", "nonce": "nonce"},
    )
    assert first.status_code == 200

    deleted = client.delete(
        "/api/v1/auth/account",
        headers={"Authorization": f"Bearer {first.json()['accessToken']}"},
    )
    assert deleted.status_code == 200

    email_account = client.post(
        "/api/v1/auth/register",
        json={
            "email": "live-after-delete@example.ch",
            "password": "correct horse battery staple",
        },
    )
    assert email_account.status_code == 201

    recreated = client.post(
        "/api/v1/auth/apple/verify",
        json={
            "identity_token": "second-token",
            "nonce": "nonce",
            "allowRecreateAfterDelete": True,
        },
    )

    assert recreated.status_code == 409
    assert recreated.json()["detail"]["code"] == "apple_email_already_linked"

    db = TestingSessionLocal()
    try:
        live_user = (
            db.query(User)
            .filter(User.email == "live-after-delete@example.ch")
            .one()
        )
        assert live_user.apple_sub is None
        event = (
            db.query(AuditEventModel)
            .filter(
                AuditEventModel.event_type == "auth.apple_verify",
                AuditEventModel.status == "apple_email_already_linked",
            )
            .one()
        )
        assert event.user_id == live_user.id
        details = json.loads(event.details_json or "{}")
        assert details["code"] == "apple_email_already_linked"
        assert details["allow_recreate_after_delete"] is True
    finally:
        db.close()


def test_apple_verify_rejects_email_already_linked_to_different_sub(
    client: TestClient,
    monkeypatch,
):
    """A reused relay email must not let a different Apple sub into an account."""
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)

    payloads = {
        "first-token": {
            "sub": "001999.original-apple-sub",
            "email": "shared-relay@privaterelay.appleid.com",
        },
        "second-token": {
            "sub": "001999.other-apple-sub",
            "email": "shared-relay@privaterelay.appleid.com",
        },
    }

    def fake_verify(identity_token: str, nonce: str | None) -> dict[str, str]:
        return payloads[identity_token]

    monkeypatch.setattr(
        auth_endpoint,
        "_verify_apple_identity_token",
        fake_verify,
    )

    first = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "first-token", "nonce": "nonce"},
    )
    second = client.post(
        "/api/v1/auth/apple/verify",
        json={"identity_token": "second-token", "nonce": "nonce"},
    )

    assert first.status_code == 200
    assert second.status_code == 409
    assert second.json()["detail"] == {
        "code": "apple_email_already_linked",
        "message": "Apple email is already linked to another account",
    }

    db = TestingSessionLocal()
    try:
        event = (
            db.query(AuditEventModel)
            .filter(
                AuditEventModel.event_type == "auth.apple_verify",
                AuditEventModel.status == "apple_email_already_linked",
            )
            .one()
        )
        details = json.loads(event.details_json or "{}")
        assert details["code"] == "apple_email_already_linked"
        assert details["allow_recreate_after_delete"] is False
    finally:
        db.close()
