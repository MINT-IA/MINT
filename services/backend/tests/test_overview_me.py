"""GET /overview/me — aperçu financier aggregator.

Validates the single-shot aggregator that powers the Aperçu financier
screen: reads ProfileModel.data, runs AVS/LPP calculators when enough
facts are known, returns section-by-section status + completeness index
+ alertes + premier éclairage.
"""

from __future__ import annotations

import uuid

from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.main import app


def _auth_client(client: TestClient) -> TestClient:
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)
    return client


def _register(client: TestClient, tag: str) -> tuple[str, str]:
    email = f"overview-{tag}-{uuid.uuid4().hex[:6]}@test.mint.ch"
    resp = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "overviewpw123"},
    )
    assert resp.status_code == 201
    return email, resp.json()["access_token"]


def test_overview_empty_profile_returns_low_completeness(client: TestClient):
    c = _auth_client(client)
    _, token = _register(c, "empty")
    h = {"Authorization": f"Bearer {token}"}

    resp = c.get("/api/v1/overview/me", headers=h)
    assert resp.status_code == 200
    body = resp.json()
    # Fresh user has schema-default hasDebt=false and householdType=single,
    # so the dettes and couple sections register as "present" (legitimate
    # baseline answers, not missing data). 0.15 = 0.10 (dettes) + 0.05
    # (couple non-applicable). Everything else is gap.
    assert body["completenessIndex"] < 0.20
    assert body["profileGaps"]  # non-empty list
    assert body["alertes"] == []
    assert body["premierEclairage"].startswith("On vient de commencer")
    # Every section is an OverviewSection object
    for section in ("identity", "income", "patrimoine", "prevoyance",
                     "assurancesSociales", "dettes", "couple"):
        assert section in body
        assert "present" in body[section]


def test_overview_julien_cruise_state(client: TestClient):
    """Julien after full flow: identity + income + LPP + 3a → completeness high."""
    c = _auth_client(client)
    _, token = _register(c, "julien")
    h = {"Authorization": f"Bearer {token}"}
    pid = c.get("/api/v1/profiles/me", headers=h).json()["id"]

    c.patch(
        f"/api/v1/profiles/{pid}",
        headers=h,
        json={
            "birthYear": 1977,
            "canton": "VS",
            "householdType": "couple",
            "incomeNetMonthly": 7600,
            "lppInsuredSalary": 91967,
            "has2ndPillar": True,
            "pillar3aAnnual": 7258,
            "totalSavings": 40_000,
            "commune": "Sion",
            "employmentStatus": "salarie",
            "goal": "retire",
            "hasDebt": False,
        },
    )
    # Simulate a scan adding avoirLpp + pillar3aBalance
    c.post(
        "/api/v1/documents/scan-confirmation",
        headers=h,
        json={
            "documentType": "lpp_certificate",
            "overallConfidence": 0.9,
            "extractionMethod": "claude_vision",
            "confirmedFields": [
                {"fieldName": "avoirLpp", "value": 70376.6, "confidence": "high"},
                {"fieldName": "lppBuybackMax", "value": 539413.7, "confidence": "high"},
            ],
        },
    )

    resp = c.get("/api/v1/overview/me", headers=h)
    assert resp.status_code == 200
    body = resp.json()

    # Completeness must reflect the rich profile — threshold 0.75+
    assert body["completenessIndex"] >= 0.75, body

    # Identity filled with derived age
    assert body["identity"]["present"] is True
    assert body["identity"]["values"]["age"] == 2026 - 1977
    assert body["identity"]["values"]["canton"] == "VS"

    # Prevoyance now has AVS + LPP projections computed
    prev = body["prevoyance"]["values"]
    assert prev.get("avsRenteMensuelle") is not None
    assert prev["avsRenteMensuelle"] > 0
    assert prev.get("lppProjectedCapital") is not None
    assert prev["lppProjectedCapital"] > 70376  # projected forward > current
    assert prev.get("lppRenteMensuelleNette") is not None
    assert prev.get("lppCapitalNet") is not None
    assert prev.get("lppBreakevenAge") is not None

    # Debt section marks present (hasDebt=false is a valid answer)
    assert body["dettes"]["present"] is True
    assert body["dettes"]["values"]["hasDebt"] is False

    # Couple section partial because no spouseIncomeNetMonthly
    assert body["couple"]["values"]["status"] == "partial"
    assert "spouseIncomeNetMonthly" in body["couple"]["missingFields"]

    # Premier éclairage must be personalised now (not the starter line)
    assert "On vient de commencer" not in body["premierEclairage"]


def test_overview_alert_lpp_inconsistency(client: TestClient):
    """Salaried > 22'680 CHF/yr with has2ndPillar=false fires LPP art. 7 alert."""
    c = _auth_client(client)
    _, token = _register(c, "alert")
    h = {"Authorization": f"Bearer {token}"}
    pid = c.get("/api/v1/profiles/me", headers=h).json()["id"]

    c.patch(
        f"/api/v1/profiles/{pid}",
        headers=h,
        json={
            "birthYear": 1990,
            "canton": "ZH",
            "householdType": "single",
            "employmentStatus": "salarie",
            "incomeGrossYearly": 75_000,
            "has2ndPillar": False,
            "goal": "retire",
        },
    )
    body = c.get("/api/v1/overview/me", headers=h).json()
    assert any("LPP art. 7" in a for a in body["alertes"])


def test_overview_alert_3a_over_cap_with_lpp(client: TestClient):
    c = _auth_client(client)
    _, token = _register(c, "cap")
    h = {"Authorization": f"Bearer {token}"}
    pid = c.get("/api/v1/profiles/me", headers=h).json()["id"]
    c.patch(
        f"/api/v1/profiles/{pid}",
        headers=h,
        json={
            "birthYear": 1990,
            "canton": "ZH",
            "householdType": "single",
            "has2ndPillar": True,
            "pillar3aAnnual": 10_000,  # over 7'258 cap for salaried LPP
            "goal": "retire",
        },
    )
    body = c.get("/api/v1/overview/me", headers=h).json()
    assert any("plafond salarié avec LPP" in a for a in body["alertes"])


def test_overview_couple_status_complete_when_spouse_income_present(
    client: TestClient,
):
    c = _auth_client(client)
    _, token = _register(c, "couple")
    h = {"Authorization": f"Bearer {token}"}
    pid = c.get("/api/v1/profiles/me", headers=h).json()["id"]
    c.patch(
        f"/api/v1/profiles/{pid}",
        headers=h,
        json={
            "birthYear": 1980,
            "canton": "VD",
            "householdType": "couple",
            "incomeNetMonthly": 7000,
            "spouseSalaryGrossAnnual": 72_000,
            "householdGrossIncome": 150_000,
            "goal": "retire",
        },
    )
    # Also set spouseIncomeNetMonthly via save_fact to prove both entry
    # channels feed the same section.
    from app.api.v1.endpoints.coach_chat import _execute_internal_tool
    from tests.conftest import TestingSessionLocal
    from app.models.user import User

    db = TestingSessionLocal()
    user_id = db.query(User).filter(User.email.like("overview-couple-%")).one().id
    db.close()
    db = TestingSessionLocal()
    try:
        _execute_internal_tool(
            tool_call={
                "name": "save_fact",
                "input": {
                    "key": "spouseIncomeNetMonthly",
                    "value": 5200,
                    "confidence": "high",
                },
            },
            memory_block=None,
            profile_context=None,
            user_id=user_id,
            db=db,
            persistence_consent=True,  # Phase 52.1 PR 2 — test setup writes a fact
        )
    finally:
        db.close()

    body = c.get("/api/v1/overview/me", headers=h).json()
    assert body["couple"]["values"]["status"] == "complete"
    assert body["couple"]["values"]["spouseIncomeNetMonthly"] == 5200
    assert "spouseIncomeNetMonthly" not in body["couple"]["missingFields"]
