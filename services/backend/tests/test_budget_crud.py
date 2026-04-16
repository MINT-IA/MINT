"""Budget CRUD — GET/PUT/POST/DELETE under /api/v1/budget/me.

Covers the full money-flow surface: read empty default, upsert a budget,
add/update individual lines, delete one, derive freeMargin/savingsRate/
riskLevel/alertes correctly under each scenario.
"""

from __future__ import annotations

import uuid

from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.main import app


def _auth(client: TestClient) -> TestClient:
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)
    return client


def _register(client: TestClient, tag: str) -> tuple[str, str]:
    email = f"budget-{tag}-{uuid.uuid4().hex[:6]}@test.mint.ch"
    r = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "budgetpw123"},
    )
    assert r.status_code == 201
    return email, r.json()["access_token"]


def _set_income_via_profile(client, headers, income):
    pid = client.get("/api/v1/profiles/me", headers=headers).json()["id"]
    client.patch(
        f"/api/v1/profiles/{pid}",
        headers=headers,
        json={"incomeNetMonthly": income, "householdType": "single"},
    )


def test_get_budget_me_empty_returns_unknown_income(client: TestClient):
    c = _auth(client)
    _, token = _register(c, "empty")
    h = {"Authorization": f"Bearer {token}"}

    r = c.get("/api/v1/budget/me", headers=h)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["incomeMonthly"] == 0.0
    assert body["incomeSource"] == "unknown"
    assert body["fixedLines"] == []
    assert body["riskLevel"] == "red"
    assert any("Aucun revenu" in a for a in body["alertes"])


def test_get_budget_me_uses_profile_income_when_no_override(
    client: TestClient,
):
    c = _auth(client)
    _, token = _register(c, "profile-income")
    h = {"Authorization": f"Bearer {token}"}
    _set_income_via_profile(c, h, 7600)

    body = c.get("/api/v1/budget/me", headers=h).json()
    assert body["incomeMonthly"] == 7600.0
    assert body["incomeSource"] == "profile"


def test_put_budget_me_persists_full_payload_and_computes_signals(
    client: TestClient,
):
    c = _auth(client)
    _, token = _register(c, "put")
    h = {"Authorization": f"Bearer {token}"}
    _set_income_via_profile(c, h, 8000)

    payload = {
        "fixedLines": [
            {"label": "Loyer", "amount": 2200, "category": "housing"},
            {"label": "Assurance maladie", "amount": 480, "category": "insurance"},
            {"label": "Leasing voiture", "amount": 590, "category": "leasing"},
        ],
        "variableTargetMonthly": 1500,
        "savingsTargetMonthly": 1000,
    }
    r = c.put("/api/v1/budget/me", headers=h, json=payload)
    assert r.status_code == 200, r.text
    body = r.json()

    # Income inherited from profile
    assert body["incomeMonthly"] == 8000.0
    assert body["incomeSource"] == "profile"
    # 3 lines persisted with stable ids assigned
    assert len(body["fixedLines"]) == 3
    for ln in body["fixedLines"]:
        assert ln["id"] and isinstance(ln["id"], str)
    # Sums + derived fields
    assert body["totalFixedMonthly"] == 2200 + 480 + 590
    assert body["freeMarginMonthly"] == 8000 - 3270 - 1500 - 1000  # = 2230
    assert body["savingsRate"] == round(1000 / 8000, 4)  # 0.125
    assert body["riskLevel"] == "green"  # margin>=0 AND savings>=10%
    assert body["alertes"] == []

    # Read-after-write
    r2 = c.get("/api/v1/budget/me", headers=h).json()
    assert r2["totalFixedMonthly"] == body["totalFixedMonthly"]
    assert len(r2["fixedLines"]) == 3


def test_put_budget_me_income_override_wins(client: TestClient):
    c = _auth(client)
    _, token = _register(c, "override")
    h = {"Authorization": f"Bearer {token}"}
    _set_income_via_profile(c, h, 7000)

    body = c.put(
        "/api/v1/budget/me",
        headers=h,
        json={
            "incomeMonthly": 9500,
            "fixedLines": [],
            "variableTargetMonthly": 0,
            "savingsTargetMonthly": 0,
        },
    ).json()
    assert body["incomeMonthly"] == 9500.0
    assert body["incomeSource"] == "override"


def test_put_budget_me_negative_margin_flagged_red(client: TestClient):
    c = _auth(client)
    _, token = _register(c, "negative")
    h = {"Authorization": f"Bearer {token}"}
    _set_income_via_profile(c, h, 4500)

    body = c.put(
        "/api/v1/budget/me",
        headers=h,
        json={
            "fixedLines": [
                {"label": "Loyer", "amount": 2400, "category": "housing"},
                {"label": "Crédit conso", "amount": 1100, "category": "credit"},
                {"label": "Assurance", "amount": 420, "category": "insurance"},
            ],
            "variableTargetMonthly": 1200,
            "savingsTargetMonthly": 0,
        },
    ).json()
    assert body["freeMarginMonthly"] < 0
    assert body["riskLevel"] == "red"
    assert any("dépassent ton revenu" in a for a in body["alertes"])
    assert "à crédit" in body["premierEclairage"]


def test_post_line_appends_then_replaces_by_id(client: TestClient):
    c = _auth(client)
    _, token = _register(c, "lines")
    h = {"Authorization": f"Bearer {token}"}
    _set_income_via_profile(c, h, 7600)

    # Append #1
    r = c.post(
        "/api/v1/budget/me/lines",
        headers=h,
        json={"label": "Loyer", "amount": 2200, "category": "housing"},
    )
    assert r.status_code == 201, r.text
    line_id = r.json()["fixedLines"][0]["id"]

    # Append #2
    r = c.post(
        "/api/v1/budget/me/lines",
        headers=h,
        json={"label": "Internet", "amount": 75, "category": "utilities"},
    )
    body = r.json()
    assert len(body["fixedLines"]) == 2
    assert body["totalFixedMonthly"] == 2275

    # Update #1 by id (loyer increases)
    r = c.post(
        "/api/v1/budget/me/lines",
        headers=h,
        json={"id": line_id, "label": "Loyer", "amount": 2350, "category": "housing"},
    )
    body = r.json()
    assert len(body["fixedLines"]) == 2  # not appended again
    loyer = next(ln for ln in body["fixedLines"] if ln["id"] == line_id)
    assert loyer["amount"] == 2350
    assert body["totalFixedMonthly"] == 2350 + 75


def test_delete_line_removes_then_returns_404(client: TestClient):
    c = _auth(client)
    _, token = _register(c, "delete")
    h = {"Authorization": f"Bearer {token}"}
    _set_income_via_profile(c, h, 7600)

    r = c.post(
        "/api/v1/budget/me/lines",
        headers=h,
        json={"label": "Loyer", "amount": 2200, "category": "housing"},
    )
    line_id = r.json()["fixedLines"][0]["id"]

    r = c.delete(f"/api/v1/budget/me/lines/{line_id}", headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["fixedLines"] == []

    # 404 on second delete (idempotency without silent success)
    r = c.delete(f"/api/v1/budget/me/lines/{line_id}", headers=h)
    assert r.status_code == 404


def test_unknown_category_normalised_to_other(client: TestClient):
    c = _auth(client)
    _, token = _register(c, "cat")
    h = {"Authorization": f"Bearer {token}"}
    _set_income_via_profile(c, h, 7600)

    body = c.post(
        "/api/v1/budget/me/lines",
        headers=h,
        json={"label": "Bizarre", "amount": 50, "category": "evilInjected"},
    ).json()
    assert body["fixedLines"][0]["category"] == "other"


def test_low_savings_rate_amber_alert(client: TestClient):
    c = _auth(client)
    _, token = _register(c, "amber")
    h = {"Authorization": f"Bearer {token}"}
    _set_income_via_profile(c, h, 8000)

    body = c.put(
        "/api/v1/budget/me",
        headers=h,
        json={
            "fixedLines": [{"label": "Loyer", "amount": 2200, "category": "housing"}],
            "variableTargetMonthly": 4000,
            "savingsTargetMonthly": 200,  # 200/8000 = 2.5% < 10%
        },
    ).json()
    assert body["riskLevel"] == "amber"
    assert any("Taux d'épargne sous 10%" in a for a in body["alertes"])


def test_anomaly_detection_endpoint_still_works(client: TestClient):
    """Existing JITAI endpoint is not regressed by CRUD additions."""
    c = _auth(client)
    _, token = _register(c, "anom")
    h = {"Authorization": f"Bearer {token}"}

    r = c.post(
        "/api/v1/budget/anomalies",
        headers=h,
        json={
            "transactions": [
                {"amount": 50, "category": "food"},
                {"amount": 60, "category": "food"},
                {"amount": 55, "category": "food"},
                {"amount": 800, "category": "food"},  # outlier
            ]
        },
    )
    assert r.status_code == 200
    body = r.json()
    assert body["totalTransactions"] == 4
    assert body["anomalyCount"] >= 0
