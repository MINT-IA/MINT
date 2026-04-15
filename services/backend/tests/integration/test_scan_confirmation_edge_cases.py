"""Edge cases in /documents/scan-confirmation merge.

Targets documents.py coverage gaps flagged by diff-cover on PR #328
(lines 947, 958, 971-973, 991-992, 1001, 1003, 1008-1011):
- unknown fieldName skipped
- null value skipped
- low confidence dropped
- near-duplicate (<1% drift) no-op
- distinct value (>1%) overwrites
- completion index bumps and caps
"""
from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app


@pytest.fixture
def client_and_token():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)

    def _override_get_db():
        s = TestSession()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_db] = _override_get_db
    client = TestClient(app)

    email = f"edge-{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "EdgeTest2026!"},
    )
    assert resp.status_code in (200, 201), resp.text
    token = resp.json()["access_token"]
    yield client, token
    app.dependency_overrides.clear()


def _confirm(client, token, fields):
    return client.post(
        "/api/v1/documents/scan-confirmation",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "documentType": "lpp_certificate",
            "overallConfidence": 0.9,
            "extractionMethod": "claude_vision",
            "confirmedFields": fields,
        },
    )


def _get_profile(client, token):
    return client.get(
        "/api/v1/profiles/me",
        headers={"Authorization": f"Bearer {token}"},
    ).json()


def test_low_confidence_field_not_merged(client_and_token):
    client, token = client_and_token
    resp = _confirm(client, token, [
        {"fieldName": "avoirLppTotal", "value": 50000,
         "confidence": "low", "sourceText": "blurry"},
    ])
    assert resp.status_code == 200
    assert _get_profile(client, token).get("avoirLpp") is None


def test_null_value_rejected_by_schema(client_and_token):
    """Pydantic rejects `value: null` before the handler runs — that is the
    first line of defence. The handler's inner null-check (line 958) is a
    belt-and-braces guard against future schema relaxations."""
    client, token = client_and_token
    resp = _confirm(client, token, [
        {"fieldName": "avoirLppTotal", "value": None,
         "confidence": "high", "sourceText": "missing"},
    ])
    assert resp.status_code == 422


def test_unknown_field_name_is_dropped(client_and_token):
    client, token = client_and_token
    resp = _confirm(client, token, [
        {"fieldName": "unknownFieldXYZ", "value": 42000,
         "confidence": "high", "sourceText": "whatever"},
        {"fieldName": "avoirLppTotal", "value": 70000,
         "confidence": "high", "sourceText": "ok"},
    ])
    assert resp.status_code == 200
    assert _get_profile(client, token).get("avoirLpp") == 70000


def test_near_duplicate_value_does_not_churn(client_and_token):
    client, token = client_and_token
    _confirm(client, token, [
        {"fieldName": "avoirLppTotal", "value": 70000,
         "confidence": "high", "sourceText": "first"},
    ])
    # 70350 is 0.5% drift — below 1% threshold → no overwrite
    _confirm(client, token, [
        {"fieldName": "avoirLppTotal", "value": 70350,
         "confidence": "high", "sourceText": "rescan"},
    ])
    assert _get_profile(client, token).get("avoirLpp") == 70000


def test_distinct_value_does_overwrite(client_and_token):
    client, token = client_and_token
    _confirm(client, token, [
        {"fieldName": "avoirLppTotal", "value": 70000,
         "confidence": "high", "sourceText": "first"},
    ])
    # 5% drift → should overwrite
    _confirm(client, token, [
        {"fieldName": "avoirLppTotal", "value": 73500,
         "confidence": "high", "sourceText": "newer"},
    ])
    assert _get_profile(client, token).get("avoirLpp") == 73500


def test_completion_index_bumps_on_merge(client_and_token):
    client, token = client_and_token
    before = _get_profile(client, token).get("factfindCompletionIndex", 0.0) or 0.0
    _confirm(client, token, [
        {"fieldName": "avoirLppTotal", "value": 70000,
         "confidence": "high", "sourceText": "a"},
        {"fieldName": "salaireAssure", "value": 91967,
         "confidence": "high", "sourceText": "b"},
        {"fieldName": "rachatMaximum", "value": 539414,
         "confidence": "high", "sourceText": "c"},
    ])
    after = _get_profile(client, token).get("factfindCompletionIndex", 0.0) or 0.0
    assert after > before
    assert after <= 1.0


def test_completion_index_caps_at_one(client_and_token):
    client, token = client_and_token
    # Five rounds of varying values, each high conf → saturates but never > 1.0
    for i in range(5):
        _confirm(client, token, [
            {"fieldName": "avoirLppTotal", "value": 70000 + i * 5000,
             "confidence": "high", "sourceText": f"run{i}"},
            {"fieldName": "salaireAssure", "value": 91000 + i * 5000,
             "confidence": "high", "sourceText": f"run{i}"},
        ])
    assert _get_profile(client, token).get("factfindCompletionIndex", 0.0) <= 1.0


def test_repeated_confirmations_do_not_crash(client_and_token):
    """Smoke: three rescans of the same doc keep returning 200
    (covers lastDocumentScan overwrite path)."""
    client, token = client_and_token
    for i in range(3):
        r = _confirm(client, token, [
            {"fieldName": "avoirLppTotal", "value": 70000 + i * 10000,
             "confidence": "high", "sourceText": "rerun"},
        ])
        assert r.status_code == 200, r.text
