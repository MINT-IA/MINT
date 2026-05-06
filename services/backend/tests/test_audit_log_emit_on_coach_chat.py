"""Phase 93 — Plan 01 — coach_message_audits row on /coach/chat.

Asserts the inspector contract: every successful POST /api/v1/coach/chat
writes one row to coach_message_audits with:
- session_id == str(user.id)
- prompt_hash == sha256(sanitized user message)
- response_hash == sha256(loop_result.answer)
- archetype defaulting to "swiss_native" when not in profile_context
- banned_term_hit reflecting the response

Per OAR-G art. 24 + FINMA Guidance 8/2024 SS VI.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.auth import require_current_user, get_current_user
from app.core.database import get_db
from app.models.coach_message_audit import CoachMessageAudit
from app.utils.audit_hash import hash_for_audit
from tests.conftest import override_get_db


# ---------------------------------------------------------------------------
# Fixtures (mirror tests/test_coach_chat_endpoint.py for consistency)
# ---------------------------------------------------------------------------


def _fake_user():
    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    user.display_name = "Test User"
    return user


_VALID_BODY = {
    "message": "Comment fonctionne le pilier 3a en Suisse ?",
    "api_key": "sk-test-key-12345",
    "provider": "claude",
}

_ORCHESTRATOR_OK_RESULT = {
    "answer": "Le pilier 3a est un outil de prevoyance fiscalement avantageux.",
    "sources": [],
    "disclaimers": ["Outil educatif, ne constitue pas un conseil financier (LSFin)."],
    "tokens_used": 200,
}

_ORCHESTRATOR_BANNED_RESULT = {
    "answer": "Le pilier 3a est une option optimale pour ta situation.",
    "sources": [],
    "disclaimers": ["Outil educatif, ne constitue pas un conseil financier (LSFin)."],
    "tokens_used": 220,
}


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


@pytest.fixture
def client_with_auth():
    # CRITICAL: override get_db so coach_chat's `db = Depends(get_db)`
    # writes to the same in-memory SQLite the test then reads from.
    # Without this, coach_chat would write to the prod sqlite:///./mint.db
    # and the audit row would never show up in TestingSessionLocal().
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user
    with _mock_entitlements_premium(), TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(get_db, None)
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)


def _audit_rows_for_user(user_id: str) -> list[CoachMessageAudit]:
    """Read audit rows from the in-memory test DB session."""
    from tests.conftest import TestingSessionLocal

    session = TestingSessionLocal()
    try:
        return (
            session.query(CoachMessageAudit)
            .filter(CoachMessageAudit.session_id == user_id)
            .all()
        )
    finally:
        session.close()


@pytest.fixture(autouse=True)
def _wipe_audit_rows_between_tests():
    """conftest.clean_database doesn't wipe coach_message_audits (added in
    Phase 93). Wipe here so per-test audit-row counts are deterministic."""
    from tests.conftest import TestingSessionLocal

    session = TestingSessionLocal()
    try:
        session.query(CoachMessageAudit).delete()
        session.commit()
    finally:
        session.close()
    yield


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


def test_coach_chat_happy_path_emits_one_audit_row(client_with_auth):
    """Authenticated POST /coach/chat writes exactly one audit row."""
    with _mock_orchestrator(_ORCHESTRATOR_OK_RESULT):
        resp = client_with_auth.post("/api/v1/coach/chat", json=_VALID_BODY)
    assert resp.status_code == 200, resp.text

    rows = _audit_rows_for_user("test-user-id")
    assert len(rows) == 1, f"Expected 1 audit row, got {len(rows)}"

    row = rows[0]
    assert row.session_id == "test-user-id"
    assert row.prompt_hash == hash_for_audit(_VALID_BODY["message"])
    assert row.response_hash == hash_for_audit(_ORCHESTRATOR_OK_RESULT["answer"])
    # No archetype provided in the payload → defaults to "swiss_native".
    assert row.archetype == "swiss_native"
    assert row.banned_term_hit is False
    assert row.eclairage_kind is None
    assert row.created_at is not None
    assert row.retained_until is not None
    # 10y retention default (allow ±2 days for leap-year jitter).
    retention_days = (row.retained_until - row.created_at).days
    assert retention_days >= 3650


def test_coach_chat_banned_term_hit_propagates_to_audit_row(client_with_auth):
    """When the LLM response contains a banned term, audit row reflects it."""
    with _mock_orchestrator(_ORCHESTRATOR_BANNED_RESULT):
        resp = client_with_auth.post("/api/v1/coach/chat", json=_VALID_BODY)
    assert resp.status_code == 200, resp.text

    rows = _audit_rows_for_user("test-user-id")
    assert len(rows) == 1
    # « optimale » is a banned LSFin term — surfaced in audit.
    assert rows[0].banned_term_hit is True


def test_coach_chat_archetype_from_profile_context_used_in_audit(client_with_auth):
    """When profile_context provides archetype, audit row uses it."""
    body = {
        **_VALID_BODY,
        "profile_context": {"archetype": "expat_us"},
    }
    with _mock_orchestrator(_ORCHESTRATOR_OK_RESULT):
        resp = client_with_auth.post("/api/v1/coach/chat", json=body)
    assert resp.status_code == 200, resp.text

    rows = _audit_rows_for_user("test-user-id")
    assert len(rows) == 1
    assert rows[0].archetype == "expat_us"
