"""Scan-confirmation → ProfileModel.data merge (P0 FLOW#4 fix, 2026-04-15).

Before this fix confirm_document_scan only persisted DocumentModel audit
rows — extracted LPP/3a/salary fields never landed in ProfileModel.data,
so GET /profiles/me and the coach user_facts_block saw null. These tests
pin the merge behaviour end-to-end through the FastAPI client.
"""

import uuid

from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.main import app


def _auth_client(client: TestClient):
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)
    return client


def _register_and_token(client: TestClient, tag: str) -> str:
    email = f"scan-merge-{tag}-{uuid.uuid4().hex[:6]}@test.mint.ch"
    resp = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "scanmerge123"},
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["access_token"]


def test_scan_confirmation_merges_high_confidence_lpp_fields(client: TestClient):
    c = _auth_client(client)
    token = _register_and_token(c, "lpp")
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "documentType": "lpp_certificate",
        "overallConfidence": 0.9,
        "extractionMethod": "claude_vision",
        "confirmedFields": [
            {"fieldName": "avoirLpp", "value": 70376.6, "confidence": "high"},
            {"fieldName": "lppInsuredSalary", "value": 91967, "confidence": "high"},
            {"fieldName": "lppBuybackMax", "value": 539413.7, "confidence": "high"},
            {"fieldName": "salaireBrutAnnuel", "value": 122206.8, "confidence": "high"},
        ],
    }
    resp = c.post(
        "/api/v1/documents/scan-confirmation", json=payload, headers=headers
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["status"] == "confirmed"
    assert body["fieldsUpdated"] == 4

    me = c.get("/api/v1/profiles/me", headers=headers).json()
    assert me["avoirLpp"] == 70376.6
    assert me["lppInsuredSalary"] == 91967
    assert me["lppBuybackMax"] == 539413.7
    assert me["incomeGrossYearly"] == 122206.8


def test_scan_confirmation_skips_low_confidence_fields(client: TestClient):
    c = _auth_client(client)
    token = _register_and_token(c, "low")
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "documentType": "lpp_certificate",
        "overallConfidence": 0.4,
        "extractionMethod": "ocr_mlkit",
        "confirmedFields": [
            {"fieldName": "avoirLpp", "value": 9999, "confidence": "low"},
            {"fieldName": "lppInsuredSalary", "value": 40000, "confidence": "medium"},
        ],
    }
    resp = c.post(
        "/api/v1/documents/scan-confirmation", json=payload, headers=headers
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["fieldsUpdated"] == 1

    me = c.get("/api/v1/profiles/me", headers=headers).json()
    assert me["avoirLpp"] is None
    assert me["lppInsuredSalary"] == 40000


def test_scan_confirmation_ignores_unknown_fieldnames(client: TestClient):
    """Whitelist prevents arbitrary keys from polluting profile state."""
    c = _auth_client(client)
    token = _register_and_token(c, "unk")
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "documentType": "lpp_certificate",
        "overallConfidence": 0.9,
        "extractionMethod": "claude_vision",
        "confirmedFields": [
            {"fieldName": "avoirLpp", "value": 50000, "confidence": "high"},
            {"fieldName": "evilInjectedKey", "value": "gotcha", "confidence": "high"},
            {"fieldName": "passwordHash", "value": "nope", "confidence": "high"},
        ],
    }
    resp = c.post(
        "/api/v1/documents/scan-confirmation", json=payload, headers=headers
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["fieldsUpdated"] == 1

    me = c.get("/api/v1/profiles/me", headers=headers).json()
    assert me["avoirLpp"] == 50000


def test_scan_confirmation_exposes_pillar3a_balance(client: TestClient):
    c = _auth_client(client)
    token = _register_and_token(c, "3a")
    headers = {"Authorization": f"Bearer {token}"}

    c.post(
        "/api/v1/documents/scan-confirmation",
        json={
            "documentType": "pillar_3a_attestation",
            "overallConfidence": 0.92,
            "extractionMethod": "claude_vision",
            "confirmedFields": [
                {"fieldName": "pillar3aBalance", "value": 32000, "confidence": "high"},
            ],
        },
        headers=headers,
    )
    me = c.get("/api/v1/profiles/me", headers=headers).json()
    assert me["pillar3aBalance"] == 32000
