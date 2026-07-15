"""G1 BND-02A: isolated, JWT-bound partner accountability boundary."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
import hashlib
import json
from types import SimpleNamespace
from uuid import uuid4

from fastapi.routing import APIRoute
import pytest

from app.core.auth import require_current_user
from app.main import app
from app.services.feature_flags import FeatureFlags
from tests.conftest import TestingSessionLocal


_CREATE_PATH = "/api/v1/partner-accountability/receipts"
_LIFECYCLE_ROUTES = {
    ("POST", _CREATE_PATH),
    ("GET", _CREATE_PATH),
    ("GET", f"{_CREATE_PATH}/{{receipt_id}}/status"),
    ("POST", f"{_CREATE_PATH}/{{receipt_id}}/revoke"),
    ("DELETE", f"{_CREATE_PATH}/{{receipt_id}}"),
}
_FLAG_ENV = "FF_PARTNER_LPP_ACCOUNTABILITY_ENABLED"
_FLAG_NAME = "partner_lpp_accountability_enabled"
_SUBJECT_KIND = "manualPartner"
_ACCOUNTABILITY_KIND = "acting_user_partner_authorization_declaration"
_PURPOSE = "one_shot_lpp_extraction"
_HMAC_KEY_ENV = "MINT_PARTNER_ACCOUNTABILITY_HMAC_KEY"
_NOTICE_VERSION_ENV = "PARTNER_LPP_NOTICE_VERSION"
_POLICY_VERSION_ENV = "PARTNER_LPP_POLICY_VERSION"
_NOTICE_VERSION = "synthetic-partner-lpp-notice-v1"
_POLICY_VERSION = "synthetic-partner-accountability-policy-v1"
_HMAC_KEY = "synthetic-test-key-not-for-production"
_ROTATED_HMAC_KEY = "rotated-synthetic-test-key-not-production"
_PREVIOUS_KEYS_ENV = "MINT_PARTNER_ACCOUNTABILITY_PREVIOUS_HMAC_KEYS_JSON"


def _key_id(key: str) -> str:
    return hashlib.sha256(
        b"mint.partner-accountability.key-id.v1\x00" + key.encode("utf-8")
    ).hexdigest()[:32]


def _request_body(*, receipt_id: str | None = None, owner_token: str | None = None) -> dict:
    return {
        "receiptId": receipt_id or str(uuid4()),
        "subjectOwnerToken": owner_token or str(uuid4()),
        "subjectKind": _SUBJECT_KIND,
        "accountabilityKind": _ACCOUNTABILITY_KIND,
        "purpose": _PURPOSE,
        "noticeVersion": _NOTICE_VERSION,
        "policyVersion": _POLICY_VERSION,
    }


def _enable_synthetic_contract(monkeypatch) -> None:
    monkeypatch.setenv(_FLAG_ENV, "true")
    monkeypatch.setenv(_HMAC_KEY_ENV, _HMAC_KEY)
    monkeypatch.delenv(_PREVIOUS_KEYS_ENV, raising=False)
    monkeypatch.setenv(_NOTICE_VERSION_ENV, _NOTICE_VERSION)
    monkeypatch.setenv(_POLICY_VERSION_ENV, _POLICY_VERSION)


def _create_route() -> APIRoute:
    matches = [
        route
        for route in app.routes
        if isinstance(route, APIRoute)
        and route.path == _CREATE_PATH
        and "POST" in route.methods
    ]
    assert len(matches) == 1, (
        "BND-02A requires one dedicated POST /partner-accountability/receipts "
        "boundary; the legacy /consents/grant-nominative route is not a substitute"
    )
    return matches[0]


def test_partner_accountability_lifecycle_routes_are_isolated_and_jwt_gated():
    """Create/list/status/revoke/erase cannot fall back to legacy consent APIs."""
    routes = {
        (method, route.path): route
        for route in app.routes
        if isinstance(route, APIRoute)
        for method in route.methods
    }

    missing = _LIFECYCLE_ROUTES - routes.keys()
    assert not missing, (
        "BND-02A requires dedicated create/list/status/revoke/erase routes; "
        f"missing {sorted(missing)}"
    )
    for route_key in _LIFECYCLE_ROUTES:
        dependency_calls = {
            dependency.call for dependency in routes[route_key].dependant.dependencies
        }
        assert require_current_user in dependency_calls, (
            f"{route_key} must derive the acting principal from JWT auth"
        )


def test_partner_accountability_boundary_is_registered_default_off(monkeypatch):
    """The isolated JWT-gated receipt path must exist but default to disabled."""
    monkeypatch.delenv(_FLAG_ENV, raising=False)

    flags = FeatureFlags.get_flags()

    assert _FLAG_NAME in flags, (
        "BND-02A is missing its backend kill switch; implementation must not "
        "borrow a generic consent or document flag"
    )
    assert flags[_FLAG_NAME] is False
    route = _create_route()
    dependency_calls = {dependency.call for dependency in route.dependant.dependencies}

    assert require_current_user in dependency_calls, (
        "BND-02A receipt creation must derive its actor from require_current_user"
    )


def test_partner_accountability_default_off_fails_closed(client, monkeypatch):
    """A disabled boundary rejects creation and writes no fallback consent."""
    monkeypatch.setenv(_FLAG_ENV, "false")

    response = client.post(_CREATE_PATH, json=_request_body())

    assert response.status_code == 403, (
        "BND-02A default-off receipt creation must fail closed with 403; "
        f"received {response.status_code}: {response.text}"
    )
    assert response.json()["detail"]["code"] == "partner_accountability_disabled"


@pytest.mark.parametrize(
    "invalid_owner",
    ["RAW-OWNER", 987654321, "partner.person+private@example.invalid"],
)
def test_invalid_owner_token_never_echoes_raw_input(
    client,
    monkeypatch,
    invalid_owner,
):
    """Validation errors are sanitized because owner tokens are sensitive."""
    _enable_synthetic_contract(monkeypatch)
    body = _request_body()
    body["subjectOwnerToken"] = invalid_owner
    response = client.post(_CREATE_PATH, json=body)

    assert response.status_code == 422, response.text
    assert response.json()["detail"]["code"] == (
        "partner_accountability_owner_token_invalid"
    )
    assert str(invalid_owner) not in response.text
    from app.models.partner_accountability_receipt import (
        PartnerAccountabilityReceipt,
    )

    db = TestingSessionLocal()
    try:
        assert db.query(PartnerAccountabilityReceipt).count() == 0
    finally:
        db.close()


def test_partner_accountability_receipt_is_exact_scope_minimized_and_idempotent(
    client,
    monkeypatch,
):
    """Enabled test boundary binds receipt id, JWT actor, owner and one-shot scope."""
    _enable_synthetic_contract(monkeypatch)
    receipt_id = str(uuid4())
    owner_token = str(uuid4())
    body = _request_body(receipt_id=receipt_id, owner_token=owner_token)

    first = client.post(_CREATE_PATH, json=body)
    assert first.status_code in {200, 201}, (
        "BND-02A enabled boundary must create the isolated minimized receipt; "
        f"received {first.status_code}: {first.text}"
    )
    first_json = first.json()
    assert first_json["receiptId"] == receipt_id
    assert first_json["subjectKind"] == _SUBJECT_KIND
    assert first_json["accountabilityKind"] == _ACCOUNTABILITY_KIND
    assert first_json["purpose"] == _PURPOSE
    assert first_json["noticeVersion"] == body["noticeVersion"]
    assert first_json["policyVersion"] == body["policyVersion"]
    assert first_json["declaredAt"]
    assert first_json["expiresAt"]
    assert first_json.get("revokedAt") is None
    assert first_json.get("erasedAt") is None

    serialized = first.text
    assert owner_token not in serialized
    assert "test-user-id" not in serialized
    for forbidden_key in (
        "subjectName",
        "partnerName",
        "partnerEmail",
        "declaredFromIp",
        "declaredDocHash",
        "documentSha",
        "acquisitionId",
        "filename",
        "sourceText",
        "financialValue",
        "grantId",
        "directPartnerConsent",
    ):
        assert forbidden_key not in first_json

    retry = client.post(_CREATE_PATH, json=body)
    assert retry.status_code == 200, retry.text
    assert retry.json() == first_json

    monkeypatch.setenv(_NOTICE_VERSION_ENV, "synthetic-partner-lpp-notice-v2")
    rotated_retry = client.post(_CREATE_PATH, json=body)
    assert rotated_retry.status_code == 200, rotated_retry.text
    assert rotated_retry.json()["receiptId"] == receipt_id
    assert rotated_retry.json()["status"] == "stale"
    stale_new_uuid = client.post(_CREATE_PATH, json=_request_body())
    assert stale_new_uuid.status_code == 409, stale_new_uuid.text

    conflicting_owner = client.post(
        _CREATE_PATH,
        json=_request_body(receipt_id=receipt_id),
    )
    assert conflicting_owner.status_code == 409, conflicting_owner.text

    app.dependency_overrides[require_current_user] = lambda: SimpleNamespace(
        id="synthetic-other-actor",
    )
    conflicting_actor = client.post(_CREATE_PATH, json=body)
    assert conflicting_actor.status_code == 409, conflicting_actor.text


def test_partner_accountability_enabled_without_approved_bundle_fails_closed(
    client,
    monkeypatch,
):
    """The kill switch alone is never a production activation mechanism."""
    monkeypatch.setenv(_FLAG_ENV, "true")
    monkeypatch.delenv(_HMAC_KEY_ENV, raising=False)
    monkeypatch.delenv(_NOTICE_VERSION_ENV, raising=False)
    monkeypatch.delenv(_POLICY_VERSION_ENV, raising=False)

    response = client.post(_CREATE_PATH, json=_request_body())

    assert response.status_code == 503, response.text
    assert response.json()["detail"]["code"] == (
        "partner_accountability_configuration_incomplete"
    )


def test_receipt_create_fails_closed_when_actor_disappears(
    client,
    monkeypatch,
):
    """A deletion race returns a stable conflict instead of writing an orphan."""
    from app.services.partner_accountability.service import (
        PartnerAccountabilityActorUnavailable,
        PartnerAccountabilityService,
    )

    _enable_synthetic_contract(monkeypatch)

    def unavailable(_service, *, actor_id, body):
        raise PartnerAccountabilityActorUnavailable

    monkeypatch.setattr(PartnerAccountabilityService, "create", unavailable)
    response = client.post(_CREATE_PATH, json=_request_body())

    assert response.status_code == 409, response.text
    assert response.json()["detail"]["code"] == (
        "partner_accountability_actor_unavailable"
    )
    assert 409 in _create_route().responses
    assert "actor deletion race" in _create_route().responses[409][
        "description"
    ].lower()


def test_hmac_rotation_uses_explicit_previous_keyring_for_existing_receipts(
    client,
    monkeypatch,
):
    """Old receipts remain actor-scoped only while their exact key is configured."""
    _enable_synthetic_contract(monkeypatch)
    body = _request_body()
    assert client.post(_CREATE_PATH, json=body).status_code == 201

    from app.models.partner_accountability_receipt import (
        PartnerAccountabilityReceipt,
    )

    db = TestingSessionLocal()
    try:
        row = db.get(PartnerAccountabilityReceipt, body["receiptId"])
        assert row is not None
        assert row.hmac_key_id == _key_id(_HMAC_KEY)
    finally:
        db.close()

    monkeypatch.setenv(_HMAC_KEY_ENV, _ROTATED_HMAC_KEY)
    for method, path in (
        (client.post, _CREATE_PATH),
        (client.get, _CREATE_PATH),
        (client.get, f"{_CREATE_PATH}/{body['receiptId']}/status"),
        (client.post, f"{_CREATE_PATH}/{body['receiptId']}/revoke"),
        (client.delete, f"{_CREATE_PATH}/{body['receiptId']}"),
    ):
        kwargs = {"json": body} if method == client.post and path == _CREATE_PATH else {}
        blocked = method(path, **kwargs)
        assert blocked.status_code == 503, (path, blocked.text)
        assert blocked.json()["detail"]["code"] == (
            "partner_accountability_configuration_incomplete"
        )

    monkeypatch.setenv(
        _PREVIOUS_KEYS_ENV,
        json.dumps({_key_id(_HMAC_KEY): _HMAC_KEY}),
    )
    retry = client.post(_CREATE_PATH, json=body)
    assert retry.status_code == 200, retry.text
    assert client.get(_CREATE_PATH).status_code == 200
    assert client.get(f"{_CREATE_PATH}/{body['receiptId']}/status").status_code == 200
    assert client.post(f"{_CREATE_PATH}/{body['receiptId']}/revoke").status_code == 200
    assert client.delete(f"{_CREATE_PATH}/{body['receiptId']}").status_code == 204


def test_partner_accountability_lifecycle_is_actor_scoped_and_revoke_is_idempotent(
    client,
    monkeypatch,
):
    """List/status/revoke expose only the JWT actor's durable receipt lifecycle."""
    _enable_synthetic_contract(monkeypatch)
    body = _request_body()
    created = client.post(_CREATE_PATH, json=body)
    assert created.status_code == 201, created.text

    listed = client.get(_CREATE_PATH)
    assert listed.status_code == 200, listed.text
    assert [item["receiptId"] for item in listed.json()["receipts"]] == [
        body["receiptId"]
    ]
    assert listed.json()["receipts"][0]["status"] == "active"

    status_response = client.get(f"{_CREATE_PATH}/{body['receiptId']}/status")
    assert status_response.status_code == 200, status_response.text
    assert status_response.json()["status"] == "active"

    revoked = client.post(f"{_CREATE_PATH}/{body['receiptId']}/revoke")
    assert revoked.status_code == 200, revoked.text
    assert revoked.json()["status"] == "revoked"
    revoked_at = revoked.json()["revokedAt"]
    assert revoked_at

    retry = client.post(f"{_CREATE_PATH}/{body['receiptId']}/revoke")
    assert retry.status_code == 200, retry.text
    assert retry.json()["revokedAt"] == revoked_at

    app.dependency_overrides[require_current_user] = lambda: SimpleNamespace(
        id="synthetic-other-actor",
    )
    assert client.get(_CREATE_PATH).json()["receipts"] == []
    assert client.get(f"{_CREATE_PATH}/{body['receiptId']}/status").status_code == 404
    assert client.post(f"{_CREATE_PATH}/{body['receiptId']}/revoke").status_code == 404


def test_kill_switch_does_not_disable_privacy_rights_lifecycle(
    client,
    monkeypatch,
):
    """Turning the product path off must not disable rights or erasure."""
    _enable_synthetic_contract(monkeypatch)
    body = _request_body()
    assert client.post(_CREATE_PATH, json=body).status_code == 201

    monkeypatch.setenv(_FLAG_ENV, "false")
    monkeypatch.delenv(_NOTICE_VERSION_ENV)
    monkeypatch.delenv(_POLICY_VERSION_ENV)
    assert client.post(_CREATE_PATH, json=_request_body()).status_code == 403
    listed = client.get(_CREATE_PATH)
    assert listed.status_code == 200, listed.text
    assert listed.json()["receipts"][0]["status"] == "stale"
    assert client.get(f"{_CREATE_PATH}/{body['receiptId']}/status").status_code == 200
    assert client.post(f"{_CREATE_PATH}/{body['receiptId']}/revoke").status_code == 200
    assert client.delete(f"{_CREATE_PATH}/{body['receiptId']}").status_code == 204


def test_erasure_without_hmac_key_fails_explicitly_and_keeps_receipt(
    client,
    monkeypatch,
):
    """A missing scoping key must never turn an apparent 204 into a no-op."""
    _enable_synthetic_contract(monkeypatch)
    body = _request_body()
    assert client.post(_CREATE_PATH, json=body).status_code == 201

    monkeypatch.delenv(_HMAC_KEY_ENV)
    blocked = client.delete(f"{_CREATE_PATH}/{body['receiptId']}")
    assert blocked.status_code == 503, blocked.text
    assert blocked.json()["detail"]["code"] == (
        "partner_accountability_configuration_incomplete"
    )

    monkeypatch.setenv(_HMAC_KEY_ENV, _HMAC_KEY)
    assert client.get(f"{_CREATE_PATH}/{body['receiptId']}/status").status_code == 200
    assert client.delete(f"{_CREATE_PATH}/{body['receiptId']}").status_code == 204


def test_partner_accountability_status_reports_stale_and_expired(
    client,
    monkeypatch,
):
    """Status is computed against current versions and the fixed expiry."""
    _enable_synthetic_contract(monkeypatch)
    stale_body = _request_body()
    expired_body = _request_body()
    drift_body = _request_body()
    future_body = _request_body()
    null_body = _request_body()
    null_expiry_body = _request_body()
    invalid_window_body = _request_body()
    assert client.post(_CREATE_PATH, json=stale_body).status_code == 201
    assert client.post(_CREATE_PATH, json=expired_body).status_code == 201
    assert client.post(_CREATE_PATH, json=drift_body).status_code == 201
    assert client.post(_CREATE_PATH, json=future_body).status_code == 201
    assert client.post(_CREATE_PATH, json=null_body).status_code == 201
    assert client.post(_CREATE_PATH, json=null_expiry_body).status_code == 201
    assert client.post(_CREATE_PATH, json=invalid_window_body).status_code == 201

    monkeypatch.setenv(_NOTICE_VERSION_ENV, "synthetic-partner-lpp-notice-v2")
    stale = client.get(f"{_CREATE_PATH}/{stale_body['receiptId']}/status")
    assert stale.status_code == 200, stale.text
    assert stale.json()["status"] == "stale"

    monkeypatch.setenv(_NOTICE_VERSION_ENV, _NOTICE_VERSION)
    db = TestingSessionLocal()
    try:
        from app.models.partner_accountability_receipt import (
            PartnerAccountabilityReceipt,
        )

        row = db.get(PartnerAccountabilityReceipt, expired_body["receiptId"])
        assert row is not None
        row.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        row.declared_at = row.expires_at - timedelta(days=365)
        drifted = db.get(PartnerAccountabilityReceipt, drift_body["receiptId"])
        assert drifted is not None
        drifted.purpose = "drifted-purpose"
        future = db.get(PartnerAccountabilityReceipt, future_body["receiptId"])
        assert future is not None
        future.declared_at = datetime.now(timezone.utc) + timedelta(minutes=5)
        future.expires_at = future.declared_at + timedelta(days=365)
        null_declared = db.get(PartnerAccountabilityReceipt, null_body["receiptId"])
        assert null_declared is not None
        null_declared.declared_at = None
        null_expiry = db.get(
            PartnerAccountabilityReceipt,
            null_expiry_body["receiptId"],
        )
        assert null_expiry is not None
        null_expiry.expires_at = None
        invalid_window = db.get(
            PartnerAccountabilityReceipt,
            invalid_window_body["receiptId"],
        )
        assert invalid_window is not None
        invalid_window.expires_at = invalid_window.declared_at + timedelta(days=364)
        db.commit()
    finally:
        db.close()
    expired = client.get(f"{_CREATE_PATH}/{expired_body['receiptId']}/status")
    assert expired.status_code == 200, expired.text
    assert expired.json()["status"] == "expired"
    drift = client.get(f"{_CREATE_PATH}/{drift_body['receiptId']}/status")
    assert drift.status_code == 200, drift.text
    assert drift.json()["status"] == "stale"
    for body in (future_body, null_body, null_expiry_body, invalid_window_body):
        invalid = client.get(f"{_CREATE_PATH}/{body['receiptId']}/status")
        assert invalid.status_code == 200, invalid.text
        assert invalid.json()["status"] == "stale"


def test_partner_accountability_erasure_severs_pseudonyms_and_is_non_disclosing(
    client,
    monkeypatch,
):
    """Erasure keeps only a non-person-linked tombstone and generic DELETE retry."""
    _enable_synthetic_contract(monkeypatch)
    body = _request_body()
    assert client.post(_CREATE_PATH, json=body).status_code == 201

    first = client.delete(f"{_CREATE_PATH}/{body['receiptId']}")
    assert first.status_code == 204, first.text
    retry = client.delete(f"{_CREATE_PATH}/{body['receiptId']}")
    assert retry.status_code == 204, retry.text
    unknown = client.delete(f"{_CREATE_PATH}/{uuid4()}")
    assert unknown.status_code == 204, unknown.text

    assert client.get(_CREATE_PATH).json()["receipts"] == []
    assert client.get(f"{_CREATE_PATH}/{body['receiptId']}/status").status_code == 404

    db = TestingSessionLocal()
    try:
        from app.models.partner_accountability_receipt import (
            PartnerAccountabilityReceipt,
        )

        tombstone = db.get(PartnerAccountabilityReceipt, body["receiptId"])
        assert tombstone is not None
        assert tombstone.erased_at is not None
        assert tombstone.acting_principal_pseudonym is None
        assert tombstone.subject_owner_pseudonym is None
        assert tombstone.subject_kind is None
        assert tombstone.accountability_kind is None
        assert tombstone.purpose is None
        assert tombstone.notice_version is None
        assert tombstone.policy_version is None
        assert tombstone.declared_at is None
        assert tombstone.expires_at is None
        assert tombstone.revoked_at is None
        assert tombstone.consumed_at is None
        assert tombstone.hmac_key_id is None
    finally:
        db.close()


def test_partner_accountability_store_never_contains_forbidden_identity_fields(
    client,
    monkeypatch,
):
    """The dedicated table stores HMAC pseudonyms, never raw identity or payload data."""
    _enable_synthetic_contract(monkeypatch)
    owner_token = str(uuid4())
    body = _request_body(owner_token=owner_token)
    assert client.post(_CREATE_PATH, json=body).status_code == 201

    from app.models.partner_accountability_receipt import (
        PartnerAccountabilityReceipt,
    )

    column_names = {column.name for column in PartnerAccountabilityReceipt.__table__.columns}
    for forbidden in {
        "user_id",
        "actor_id",
        "subject_name",
        "partner_name",
        "partner_email",
        "ip",
        "ip_hash",
        "document_sha",
        "declared_doc_hash",
        "acquisition_id",
        "filename",
        "source_text",
        "financial_value",
        "grant_id",
        "direct_partner_consent",
    }:
        assert forbidden not in column_names

    db = TestingSessionLocal()
    try:
        row = db.get(PartnerAccountabilityReceipt, body["receiptId"])
        assert row is not None
        assert row.acting_principal_pseudonym != "test-user-id"
        assert row.subject_owner_pseudonym != owner_token
        assert len(row.acting_principal_pseudonym) == 64
        assert len(row.subject_owner_pseudonym) == 64
        assert row.hmac_key_id == _key_id(_HMAC_KEY)
    finally:
        db.close()
