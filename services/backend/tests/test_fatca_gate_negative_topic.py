"""Phase 93 — Plan 02 — FATCA gate negative test (topic).

When archetype == ``expat_us`` BUT the user's message is NOT
FATCA-sensitive (e.g. budget question, mortgage, AVS), the gate must
NOT fire. The LLM call must proceed normally — over-blocking would
break ``expat_us`` users for unrelated questions.

Per OAR-G art. 24 + FINMA Guidance 8/2024 §VI.

Closes:
    - REQUIREMENTS.md COMP-04
    - threat T-93-07 (over-matching regex false positives)
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.core.database import get_db
from app.main import app
from app.models.coach_message_audit import CoachMessageAudit
from tests.conftest import override_get_db


def _fake_user():
    user = MagicMock()
    user.id = "fatca-neg-topic-id"
    user.email = "expat@mint.ch"
    user.display_name = "Expat User"
    return user


_BUDGET_BODY = {
    "message": "Je veux faire un budget mensuel pour mon foyer",
    "api_key": "sk-test-key-12345",
    "provider": "claude",
    "profile_context": {"archetype": "expat_us"},
}


_LLM_ANSWER = (
    "Voici quelques pistes pour un budget mensuel : commence par "
    "lister tes revenus et tes charges fixes."
)


def _mock_entitlements_premium():
    from app.services.billing_service import ALL_FEATURES

    return patch(
        "app.api.v1.endpoints.coach_chat.recompute_entitlements",
        return_value=("premium", ALL_FEATURES),
    )


def _mock_orchestrator_with_counter():
    counter = {"calls": 0}
    mock_orch = MagicMock()

    async def _query(*_args, **_kwargs):
        counter["calls"] += 1
        return {
            "answer": _LLM_ANSWER,
            "sources": [],
            "disclaimers": [],
            "tokens_used": 150,
        }

    mock_orch.query = AsyncMock(side_effect=_query)
    return (
        patch(
            "app.api.v1.endpoints.coach_chat._get_orchestrator",
            return_value=mock_orch,
        ),
        counter,
    )


@pytest.fixture
def client_with_auth():
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user
    with _mock_entitlements_premium(), TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(get_db, None)
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)


@pytest.fixture(autouse=True)
def _wipe_audit_rows_between_tests():
    from tests.conftest import TestingSessionLocal

    session = TestingSessionLocal()
    try:
        session.query(CoachMessageAudit).delete()
        session.commit()
    finally:
        session.close()
    yield


def test_expat_us_budget_question_does_not_trigger_fatca_gate(client_with_auth):
    """expat_us user asking a budget question reaches the LLM normally."""
    orch_patch, counter = _mock_orchestrator_with_counter()
    with orch_patch:
        resp = client_with_auth.post("/api/v1/coach/chat", json=_BUDGET_BODY)

    assert resp.status_code == 200, resp.text
    payload = resp.json()

    # The LLM IS called (counter == 1) — no over-blocking.
    assert counter["calls"] == 1, (
        f"LLM should be called for budget question, counter={counter['calls']}"
    )

    # Response is the LLM answer, not the hand-off body.
    assert payload["message"] == _LLM_ANSWER
    assert "FATCA" not in payload["message"]

    # No show_handoff_card tool_call attached. Response uses camelCase
    # alias (toolCalls / responseMeta / modelUsed).
    tool_calls = payload.get("toolCalls") or payload.get("tool_calls") or []
    assert not any(
        (tc or {}).get("name") == "show_handoff_card" for tc in tool_calls
    )

    # response_meta does NOT advertise the gate model.
    response_meta = payload.get("responseMeta") or payload.get("response_meta") or {}
    assert response_meta.get("modelUsed") != "fatca_handoff_gate"
    assert response_meta.get("model_used") != "fatca_handoff_gate"
