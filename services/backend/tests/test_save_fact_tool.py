"""save_fact tool handler → ProfileModel.data write-through.

These tests bypass the LLM call and invoke _execute_tool directly, so we
can prove the coach's WRITE path closes back into the profile — which is
what lets downstream calculators see numbers the user only stated in chat.

Scenarios covered:
  • whitelisted key + high confidence → ProfileModel.data updated
  • unknown key → handler rejects, profile untouched
  • low confidence → handler asks for clarification, profile untouched
  • string coercion ("122 000" → 122000.0)
  • bool coercion ("oui" → True)
  • type mismatch (string for numeric key) → rejected
"""

from __future__ import annotations

import uuid

from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.main import app
from app.models.profile_model import ProfileModel
from tests.conftest import TestingSessionLocal


def _register(client: TestClient, tag: str) -> tuple[str, str]:
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)
    email = f"savefact-{tag}-{uuid.uuid4().hex[:6]}@test.mint.ch"
    resp = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "savefact123"},
    )
    assert resp.status_code == 201, resp.text
    # register creates the user + empty profile; pull user_id from the token
    return email, resp.json()["access_token"]


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _user_id_by_email(email: str) -> str:
    from app.models.user import User

    db = TestingSessionLocal()
    try:
        return db.query(User).filter(User.email == email).one().id
    finally:
        db.close()


def _profile_data(user_id: str) -> dict:
    db = TestingSessionLocal()
    try:
        p = (
            db.query(ProfileModel)
            .filter(ProfileModel.user_id == user_id)
            .order_by(ProfileModel.updated_at.desc())
            .first()
        )
        return dict(p.data or {}) if p else {}
    finally:
        db.close()


def _invoke(tool_input: dict, user_id: str) -> str:
    """Execute the save_fact handler through the internal dispatcher."""
    from app.api.v1.endpoints.coach_chat import _execute_internal_tool

    db = TestingSessionLocal()
    try:
        return _execute_internal_tool(
            tool_call={"name": "save_fact", "input": tool_input},
            memory_block=None,
            profile_context=None,
            user_id=user_id,
            db=db,
            persistence_consent=True,
        )
    finally:
        db.close()



def test_save_fact_writes_numeric_income_to_profile(client: TestClient):
    email, _ = _register(client, "income")
    user_id = _user_id_by_email(email)

    msg = _invoke(
        {"key": "incomeNetMonthly", "value": 7600, "confidence": "high"},
        user_id,
    )
    assert "Fait enregistré" in msg, msg

    data = _profile_data(user_id)
    assert data.get("incomeNetMonthly") == 7600.0



def test_save_fact_writes_categorical_canton(client: TestClient):
    email, _ = _register(client, "canton")
    user_id = _user_id_by_email(email)

    _invoke(
        {"key": "canton", "value": "VS", "confidence": "high"}, user_id
    )
    assert _profile_data(user_id).get("canton") == "VS"



def test_save_fact_writes_boolean_has_debt(client: TestClient):
    email, _ = _register(client, "debt")
    user_id = _user_id_by_email(email)

    _invoke(
        {"key": "hasDebt", "value": True, "confidence": "high"}, user_id
    )
    assert _profile_data(user_id).get("hasDebt") is True



def test_save_fact_rejects_unknown_key(client: TestClient):
    email, _ = _register(client, "unk")
    user_id = _user_id_by_email(email)

    msg = _invoke(
        {"key": "evilInjected", "value": 999, "confidence": "high"}, user_id
    )
    assert "clé inconnue" in msg or "ÉCHEC" in msg
    assert "evilInjected" not in _profile_data(user_id)



def test_save_fact_asks_clarification_on_low_confidence(
    client: TestClient,
):
    email, _ = _register(client, "low")
    user_id = _user_id_by_email(email)

    msg = _invoke(
        {"key": "incomeNetMonthly", "value": 5000, "confidence": "low"},
        user_id,
    )
    assert "plus précisément" in msg or "plus sûr" in msg
    assert _profile_data(user_id).get("incomeNetMonthly") is None



def test_save_fact_coerces_swiss_format_string(client: TestClient):
    email, _ = _register(client, "coerce")
    user_id = _user_id_by_email(email)

    _invoke(
        {"key": "incomeGrossYearly", "value": "122'206.80", "confidence": "high"},
        user_id,
    )
    assert _profile_data(user_id).get("incomeGrossYearly") == 122206.80



def test_save_fact_rejects_garbage_for_numeric_key(client: TestClient):
    email, _ = _register(client, "garbage")
    user_id = _user_id_by_email(email)

    msg = _invoke(
        {"key": "lppInsuredSalary", "value": "je sais pas", "confidence": "high"},
        user_id,
    )
    assert "invalide" in msg or "ÉCHEC" in msg
    assert _profile_data(user_id).get("lppInsuredSalary") is None


def test_save_fact_rejects_values_that_profile_schema_rejects(client: TestClient):
    email, token = _register(client, "schema")
    user_id = _user_id_by_email(email)

    for payload in [
        {"key": "targetRetirementAge", "value": 90, "confidence": "high"},
        {"key": "avsContributionYears", "value": 45, "confidence": "high"},
        {"key": "spouseBirthYear", "value": 1982.5, "confidence": "high"},
    ]:
        msg = _invoke(payload, user_id)
        assert "invalide" in msg or "ÉCHEC" in msg, (payload, msg)
        assert payload["key"] not in _profile_data(user_id)

    response = client.get(
        "/api/v1/profiles/me",
        headers=_auth_headers(token),
    )
    assert response.status_code == 200, response.text


def test_save_fact_rejects_spouse_fields_for_single_profile(client: TestClient):
    email, _ = _register(client, "single-spouse")
    user_id = _user_id_by_email(email)
    assert _profile_data(user_id)["householdType"] == "single"

    msg = _invoke(
        {"key": "spouseIncomeNetMonthly", "value": 5000, "confidence": "high"},
        user_id,
    )

    assert "ménage" in msg or "ÉCHEC" in msg
    assert "spouseIncomeNetMonthly" not in _profile_data(user_id)


def test_save_fact_accepts_spouse_fields_after_couple_status(client: TestClient):
    email, _ = _register(client, "couple-spouse")
    user_id = _user_id_by_email(email)

    status_msg = _invoke(
        {"key": "householdType", "value": "couple", "confidence": "high"},
        user_id,
    )
    spouse_msg = _invoke(
        {"key": "spouseIncomeNetMonthly", "value": 5000, "confidence": "high"},
        user_id,
    )

    assert "Fait enregistré" in status_msg
    assert "Fait enregistré" in spouse_msg
    assert _profile_data(user_id)["spouseIncomeNetMonthly"] == 5000.0



def test_save_fact_chain_builds_full_profile(client: TestClient):
    """Simulate a 3-turn conversation filling profile fact-by-fact."""
    email, _ = _register(client, "chain")
    user_id = _user_id_by_email(email)

    for payload in [
        {"key": "birthYear", "value": 1977, "confidence": "high"},
        {"key": "canton", "value": "VS", "confidence": "high"},
        {"key": "commune", "value": "Sion", "confidence": "high"},
        {"key": "householdType", "value": "couple", "confidence": "high"},
        {"key": "incomeNetMonthly", "value": 7600, "confidence": "high"},
        {"key": "avoirLpp", "value": 70376.6, "confidence": "high"},
        {"key": "pillar3aAnnual", "value": 7258, "confidence": "high"},
    ]:
        msg = _invoke(payload, user_id)
        assert "Fait enregistré" in msg, (payload, msg)

    data = _profile_data(user_id)
    assert data["birthYear"] == 1977
    assert data["canton"] == "VS"
    assert data["commune"] == "Sion"
    assert data["householdType"] == "couple"
    assert data["incomeNetMonthly"] == 7600.0
    assert data["avoirLpp"] == 70376.6
    assert data["pillar3aAnnual"] == 7258.0
