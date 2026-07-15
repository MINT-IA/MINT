"""G1 BND-02A: isolated, JWT-bound partner accountability boundary."""

from __future__ import annotations

from types import SimpleNamespace
from uuid import uuid4

from fastapi.routing import APIRoute

from app.core.auth import require_current_user
from app.main import app
from app.services.feature_flags import FeatureFlags


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


def _request_body(*, receipt_id: str | None = None, owner_token: str | None = None) -> dict:
    return {
        "receiptId": receipt_id or str(uuid4()),
        "subjectOwnerToken": owner_token or str(uuid4()),
        "subjectKind": _SUBJECT_KIND,
        "accountabilityKind": _ACCOUNTABILITY_KIND,
        "purpose": _PURPOSE,
        "noticeVersion": "synthetic-partner-lpp-notice-v1",
        "policyVersion": "synthetic-partner-accountability-policy-v1",
    }


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


def test_partner_accountability_receipt_is_exact_scope_minimized_and_idempotent(
    client,
    monkeypatch,
):
    """Enabled test boundary binds receipt id, JWT actor, owner and one-shot scope."""
    monkeypatch.setenv(_FLAG_ENV, "true")
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
