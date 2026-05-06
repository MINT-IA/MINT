"""Phase 93 — Plan 01 — coach_message_audits row on /anonymous/chat.

Asserts the inspector contract: every successful POST /api/v1/anonymous/chat
writes one row to coach_message_audits in the same transaction as
``anon_session.eclairage_delivered=True``. The second turn (which fires
the Premier Eclairage gate) records eclairage_kind="fiscal_margin_3a".

Per OAR-G art. 24 + FINMA Guidance 8/2024 SS VI.
"""

from __future__ import annotations

import os

# Mirror tests/test_anonymous_chat.py: set BEFORE importing app.main so the
# /anonymous/chat endpoint's `os.environ["ANTHROPIC_API_KEY"]` check passes.
os.environ["TESTING"] = "1"
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-test-anonymous-audit-key")

from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import get_db
from app.models.coach_message_audit import CoachMessageAudit
from app.utils.audit_hash import hash_for_audit
from tests.conftest import override_get_db, TestingSessionLocal


_VALID_BODY = {"message": "Je me sens perdu avec mes finances suisses"}
_SESSION_HEADER = "X-Anonymous-Session"
_VALID_SESSION_ID = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"

_MOCK_LLM_RESULT = {
    "answer": "En Suisse, ton 2e pilier est souvent le plus gros actif que tu possedes.",
    "sources": [],
    "disclaimers": ["Outil educatif, ne constitue pas un conseil financier (LSFin)."],
    "tokens_used": 150,
}


@pytest.fixture
def client():
    """Test client with the in-memory SQLite override (so audit rows
    written by the endpoint land in the same DB the test queries)."""
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(get_db, None)


@pytest.fixture(autouse=True)
def _wipe_audit_and_anon_sessions_between_tests():
    """conftest.clean_database doesn't wipe coach_message_audits or
    anonymous_sessions (the latter holds the eclairage_delivered flag).
    Wipe both so per-test counts + gating are deterministic."""
    from app.models.anonymous_session import AnonymousSession

    session = TestingSessionLocal()
    try:
        session.query(CoachMessageAudit).delete()
        session.query(AnonymousSession).delete()
        session.commit()
    finally:
        session.close()
    yield


def _audit_rows_for_session(session_id: str) -> list[CoachMessageAudit]:
    s = TestingSessionLocal()
    try:
        return (
            s.query(CoachMessageAudit)
            .filter(CoachMessageAudit.session_id == session_id)
            .order_by(CoachMessageAudit.created_at.asc())
            .all()
        )
    finally:
        s.close()


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_anonymous_chat_turn_one_writes_audit_row_no_eclairage(mock_query, client):
    """Turn 1 of an anonymous session writes one audit row, eclairage_kind=None.

    The Premier Eclairage gate only fires on turn 2+, so turn 1's
    audit row must have ``eclairage_kind == None``.
    """
    mock_query.return_value = _MOCK_LLM_RESULT

    resp = client.post(
        "/api/v1/anonymous/chat",
        json=_VALID_BODY,
        headers={_SESSION_HEADER: _VALID_SESSION_ID},
    )
    assert resp.status_code == 200, resp.text

    rows = _audit_rows_for_session(_VALID_SESSION_ID)
    assert len(rows) == 1, f"Expected 1 audit row after turn 1, got {len(rows)}"

    row = rows[0]
    assert row.session_id == _VALID_SESSION_ID
    assert row.archetype == "anonymous"
    assert row.prompt_hash == hash_for_audit(_VALID_BODY["message"])
    assert row.response_hash == hash_for_audit(_MOCK_LLM_RESULT["answer"])
    assert row.banned_term_hit is False
    assert row.eclairage_kind is None  # no eclairage on turn 1


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_anonymous_chat_turn_two_writes_audit_row_with_eclairage_kind(mock_query, client):
    """Turn 2 fires the Premier Eclairage gate → audit row records the kind.

    Sends 2 messages with the same session header. Asserts:
      - 2 audit rows total for the session.
      - The second row has ``eclairage_kind == "fiscal_margin_3a"``
        (the kind emitted by ``build_default_fiscal_margin_3a_eclairage``).
    """
    mock_query.return_value = _MOCK_LLM_RESULT

    # Turn 1
    r1 = client.post(
        "/api/v1/anonymous/chat",
        json=_VALID_BODY,
        headers={_SESSION_HEADER: _VALID_SESSION_ID},
    )
    assert r1.status_code == 200, r1.text
    assert r1.json().get("eclairage") is None  # turn 1: no eclairage

    # Turn 2 — fires eclairage gate.
    r2 = client.post(
        "/api/v1/anonymous/chat",
        json={"message": "et concretement, comment je commence ?"},
        headers={_SESSION_HEADER: _VALID_SESSION_ID},
    )
    assert r2.status_code == 200, r2.text
    eclairage_resp = r2.json().get("eclairage")
    assert eclairage_resp is not None, (
        "Turn 2 should fire the Premier Eclairage gate (eclairage_delivered=False, "
        "message_count == 2)."
    )

    rows = _audit_rows_for_session(_VALID_SESSION_ID)
    assert len(rows) == 2, f"Expected 2 audit rows after turn 2, got {len(rows)}"

    # Row 1 (turn 1): no eclairage.
    assert rows[0].eclairage_kind is None
    # Row 2 (turn 2): eclairage fired.
    assert rows[1].eclairage_kind == "fiscal_margin_3a"
    # Both rows must have archetype="anonymous".
    assert rows[0].archetype == "anonymous"
    assert rows[1].archetype == "anonymous"
