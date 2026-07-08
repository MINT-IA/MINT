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


def _invoke(
    tool_input: dict,
    user_id: str,
    profile_context: dict | None = None,
) -> str:
    """Execute the save_fact handler through the internal dispatcher."""
    from app.api.v1.endpoints.coach_chat import _execute_internal_tool

    db = TestingSessionLocal()
    try:
        return _execute_internal_tool(
            tool_call={"name": "save_fact", "input": tool_input},
            memory_block=None,
            profile_context=profile_context,
            user_id=user_id,
            db=db,
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


def test_save_fact_rejects_spouse_fact_without_confirmed_coupled_household(
    client: TestClient,
):
    cases = [
        ("spouse-no-household", None, None, "spouseIncomeNetMonthly", 5200),
        ("spouse-single", "single", None, "spouseBirthYear", 1984),
        (
            "spouse-context-single",
            "single",
            {"civil_status": "married"},
            "spouseIncomeNetMonthly",
            5200,
        ),
    ]
    for tag, household_type, profile_context, key, value in cases:
        email, _ = _register(client, tag)
        user_id = _user_id_by_email(email)
        if household_type is not None:
            _invoke(
                {"key": "householdType", "value": household_type, "confidence": "high"},
                user_id,
            )

        msg = _invoke(
            {"key": key, "value": value, "confidence": "high"},
            user_id,
            profile_context=profile_context,
        )

        assert "householdType" in msg
        data = _profile_data(user_id)
        if household_type is not None:
            assert data["householdType"] == household_type
        assert key not in data


def test_save_fact_accepts_spouse_fact_with_coupled_context(client: TestClient):
    cases = [
        ("spouse-couple", "couple", None),
        ("spouse-context", None, {"civil_status": "married"}),
    ]
    for tag, household_type, profile_context in cases:
        email, _ = _register(client, tag)
        user_id = _user_id_by_email(email)
        if household_type is not None:
            _invoke(
                {"key": "householdType", "value": household_type, "confidence": "high"},
                user_id,
            )

        msg = _invoke(
            {"key": "spouseIncomeNetMonthly", "value": 5200, "confidence": "high"},
            user_id,
            profile_context=profile_context,
        )

        assert "Fait enregistré" in msg, msg
        data = _profile_data(user_id)
        assert data["householdType"] == "couple"
        assert data["spouseIncomeNetMonthly"] == 5200.0


def test_save_fact_non_coupled_household_purges_stale_spouse_facts(
    client: TestClient,
):
    email, _ = _register(client, "spouse-purge")
    user_id = _user_id_by_email(email)

    _invoke({"key": "householdType", "value": "couple", "confidence": "high"}, user_id)
    _invoke(
        {"key": "spouseIncomeNetMonthly", "value": 5200, "confidence": "high"},
        user_id,
    )

    msg = _invoke(
        {"key": "householdType", "value": "single", "confidence": "high"},
        user_id,
    )

    assert "Fait enregistré" in msg, msg
    data = _profile_data(user_id)
    assert data["householdType"] == "single"
    assert "spouseIncomeNetMonthly" not in data
