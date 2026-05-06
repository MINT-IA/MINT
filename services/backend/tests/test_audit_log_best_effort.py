"""Phase 93 — Plan 01 — best-effort contract for the audit hook.

Asserts that when the audit insert raises (mocked DB error), the chat
endpoint STILL returns 200 with the LLM response and a
``"coach_message_audit insert failed"`` warning is recorded.

Per OAR-G art. 24 + FINMA Guidance 8/2024 SS VI threat model T-93-02 (D —
Denial of service): a broken audit MUST NOT take down the user response.

Both endpoints are covered:
- /api/v1/coach/chat (authenticated)
- /api/v1/anonymous/chat (public)
"""

from __future__ import annotations

import logging
import os

# Set BEFORE importing app.main so /anonymous/chat's env check passes.
os.environ["TESTING"] = "1"
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-test-best-effort-audit-key")

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.auth import require_current_user, get_current_user
from app.core.database import get_db
from app.models.coach_message_audit import CoachMessageAudit
from tests.conftest import override_get_db, TestingSessionLocal


# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------


def _fake_user():
    user = MagicMock()
    user.id = "test-user-best-effort"
    user.email = "test-best-effort@mint.ch"
    user.display_name = "Best-Effort Test User"
    return user


def _mock_entitlements_premium():
    from app.services.billing_service import ALL_FEATURES
    return patch(
        "app.api.v1.endpoints.coach_chat.recompute_entitlements",
        return_value=("premium", ALL_FEATURES),
    )


def _mock_orchestrator(result: dict):
    mock_orch = MagicMock()
    mock_orch.query = AsyncMock(return_value=result)
    return patch(
        "app.api.v1.endpoints.coach_chat._get_orchestrator",
        return_value=mock_orch,
    )


_OK_RESULT = {
    "answer": "Le pilier 3a est un outil de prevoyance.",
    "sources": [],
    "disclaimers": ["Outil educatif (LSFin)."],
    "tokens_used": 200,
}

_VALID_BODY_AUTH = {
    "message": "Comment fonctionne le 3a ?",
    "api_key": "sk-test-key",
    "provider": "claude",
}

_VALID_BODY_ANON = {"message": "Je me sens perdu avec mes finances"}
_SESSION_HEADER = "X-Anonymous-Session"
_VALID_SESSION_ID = "f0e1d2c3-b4a5-6789-abcd-ef0123456789"


@pytest.fixture
def client_authed():
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user
    with _mock_entitlements_premium(), TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(get_db, None)
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)


@pytest.fixture
def client_anon():
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(get_db, None)


@pytest.fixture(autouse=True)
def _wipe_audit_rows():
    from app.models.anonymous_session import AnonymousSession

    s = TestingSessionLocal()
    try:
        s.query(CoachMessageAudit).delete()
        s.query(AnonymousSession).delete()
        s.commit()
    finally:
        s.close()
    yield


# ---------------------------------------------------------------------------
# Coach chat: best-effort contract
# ---------------------------------------------------------------------------


def test_coach_chat_audit_insert_failure_does_not_break_response(client_authed, caplog):
    """When the CoachMessageAudit insert raises, /coach/chat still returns
    200 with the LLM response and logs a 'coach_message_audit insert
    failed' warning.

    Threat model T-93-02: best-effort persistence MUST NOT 5xx the user.
    """
    caplog.set_level(logging.WARNING, logger="app.api.v1.endpoints.coach_chat")

    # Patch CoachMessageAudit at the module path the endpoint imports
    # from. The endpoint does `from app.models.coach_message_audit import
    # CoachMessageAudit` inside the try/except so we patch the source.
    with _mock_orchestrator(_OK_RESULT), patch(
        "app.models.coach_message_audit.CoachMessageAudit",
        side_effect=RuntimeError("simulated db error: audit table missing"),
    ):
        resp = client_authed.post("/api/v1/coach/chat", json=_VALID_BODY_AUTH)

    # 1. Response is still 200 with the full LLM body.
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body.get("message") == _OK_RESULT["answer"]
    assert "tokensUsed" in body or "tokens_used" in body  # camelCase alias

    # 2. A "coach_message_audit insert failed" warning is logged.
    msgs = [r.getMessage() for r in caplog.records if r.levelno >= logging.WARNING]
    assert any("coach_message_audit insert failed" in m for m in msgs), (
        f"Expected a 'coach_message_audit insert failed' warning, got: {msgs}"
    )

    # 3. No row was persisted (the insert raised).
    s = TestingSessionLocal()
    try:
        rows = s.query(CoachMessageAudit).all()
    finally:
        s.close()
    assert rows == [], f"Expected no audit rows after failed insert, got {len(rows)}"


# ---------------------------------------------------------------------------
# Anonymous chat: best-effort contract
# ---------------------------------------------------------------------------


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_anonymous_chat_audit_insert_failure_does_not_break_response(
    mock_query, client_anon, caplog
):
    """Same best-effort contract for /anonymous/chat."""
    caplog.set_level(logging.WARNING, logger="app.api.v1.endpoints.anonymous_chat")
    mock_query.return_value = _OK_RESULT

    with patch(
        "app.models.coach_message_audit.CoachMessageAudit",
        side_effect=RuntimeError("simulated db error: audit table missing"),
    ):
        resp = client_anon.post(
            "/api/v1/anonymous/chat",
            json=_VALID_BODY_ANON,
            headers={_SESSION_HEADER: _VALID_SESSION_ID},
        )

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body.get("message") == _OK_RESULT["answer"]

    msgs = [r.getMessage() for r in caplog.records if r.levelno >= logging.WARNING]
    assert any("coach_message_audit insert failed" in m for m in msgs), (
        f"Expected a 'coach_message_audit insert failed' warning, got: {msgs}"
    )
