"""
Phase 71b — Premier Éclairage payload tests for POST /api/v1/anonymous/chat.

Covers the orchestrator gate that emits an `EclairagePayload` exactly once
per anonymous session, after coach turn 2, with LSFin-compliant conditional
CHF range and disclaimer.

Locked spec (Phase 71 panel verdict): see
.planning/phases/71-anonymous-chat-cleo/PANEL-VERDICT.md.

Run:
    cd services/backend && python3 -m pytest tests/api/test_anonymous_chat_eclairage.py -v
"""

from __future__ import annotations

import os

import pytest
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ["TESTING"] = "1"
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-test-anonymous-eclairage-key")

from app.main import app
from app.core.database import Base, get_db


# ---------------------------------------------------------------------------
# Test DB setup — in-memory SQLite, isolated per test file
# ---------------------------------------------------------------------------

TEST_DB_URL = "sqlite:///./test_anonymous_chat_eclairage.db"
test_engine = create_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


def override_get_db():
    db = TestSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=test_engine)
    app.dependency_overrides[get_db] = override_get_db
    yield
    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture
def client():
    return TestClient(app)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

_MOCK_LLM_RESULT = {
    "answer": "Réponse coach mock — insight Suisse.",
    "sources": [],
    "disclaimers": ["Outil éducatif, ne constitue pas un conseil financier (LSFin)."],
    "tokens_used": 120,
}

_VALID_BODY = {"message": "Je me sens un peu perdu sur mes finances."}
_SESSION_HEADER = "X-Anonymous-Session"
_SESSION_ID = "11112222-3333-4444-5555-666677778888"


def _post(client: TestClient, session_id: str = _SESSION_ID):
    """Helper: POST one anonymous chat message, return the response."""
    return client.post(
        "/api/v1/anonymous/chat",
        json=_VALID_BODY,
        headers={_SESSION_HEADER: session_id},
    )


# ---------------------------------------------------------------------------
# Test 1 — No eclairage on turn 1
# ---------------------------------------------------------------------------


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_no_eclairage_on_turn_1(mock_query, client):
    """First coach turn must NOT emit an eclairage payload."""
    mock_query.return_value = _MOCK_LLM_RESULT

    resp = _post(client)
    assert resp.status_code == 200
    data = resp.json()
    # camelCase per ConfigDict alias_generator
    assert data.get("eclairage") is None, (
        "eclairage must be None on turn 1; got " f"{data.get('eclairage')!r}"
    )


# ---------------------------------------------------------------------------
# Test 2 — Eclairage emitted on turn 2 with kind=fiscal_margin_3a
# ---------------------------------------------------------------------------


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_eclairage_emitted_on_turn_2(mock_query, client):
    """Second coach turn must emit eclairage with kind=fiscal_margin_3a."""
    mock_query.return_value = _MOCK_LLM_RESULT

    # Turn 1 — no eclairage
    r1 = _post(client)
    assert r1.status_code == 200
    assert r1.json().get("eclairage") is None

    # Turn 2 — eclairage delivered
    r2 = _post(client)
    assert r2.status_code == 200
    eclairage = r2.json().get("eclairage")
    assert eclairage is not None, "eclairage must be present on turn 2"
    assert eclairage["kind"] == "fiscal_margin_3a"
    assert eclairage["headline"] == "Marge fiscale 3a non utilisée"
    assert "3a" in eclairage["body"]
    assert eclairage["softAccountHint"] == "Crée ton compte pour suivre ça."


# ---------------------------------------------------------------------------
# Test 3 — Eclairage only emitted once per session
# ---------------------------------------------------------------------------


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_eclairage_only_emitted_once_per_session(mock_query, client):
    """Turn 3 must NOT re-emit the eclairage (one-shot per session)."""
    mock_query.return_value = _MOCK_LLM_RESULT

    _post(client)  # turn 1 — no eclairage
    r2 = _post(client)  # turn 2 — eclairage delivered
    assert r2.json().get("eclairage") is not None

    r3 = _post(client)  # turn 3 — eclairage must be None again
    assert r3.status_code == 200
    assert r3.json().get("eclairage") is None, (
        "eclairage must be re-emitted at most once per session"
    )


# ---------------------------------------------------------------------------
# Test 4 — CHF range is conditional (low + high + period), never absolute
# ---------------------------------------------------------------------------


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_eclairage_chf_range_is_conditional(mock_query, client):
    """LSFin: never absolute CHF figure for anonymous user; always low+high+period."""
    mock_query.return_value = _MOCK_LLM_RESULT

    _post(client)
    r2 = _post(client)
    eclairage = r2.json().get("eclairage")
    assert eclairage is not None

    # Both bounds present and distinct → range, not absolute
    assert eclairage["chfRangeLow"] == 1500
    assert eclairage["chfRangeHigh"] == 2500
    assert eclairage["chfRangeLow"] < eclairage["chfRangeHigh"]
    assert eclairage["chfRangePeriod"] == "year"

    # Body must contain the conditional language ("selon", "~CHF")
    body = eclairage["body"].lower()
    assert "selon" in body, "body must use conditional language ('selon …')"
    # No promise / certainty marker — sanity check on the locked copy
    assert "garanti" not in body
    assert "certain" not in body


# ---------------------------------------------------------------------------
# Test 5 — LSFin disclaimer present
# ---------------------------------------------------------------------------


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_eclairage_lsfin_disclaimer_present(mock_query, client):
    """LSFin disclaimer must include 'pas un conseil financier personnalisé'."""
    mock_query.return_value = _MOCK_LLM_RESULT

    _post(client)
    r2 = _post(client)
    eclairage = r2.json().get("eclairage")
    assert eclairage is not None

    disclaimer = eclairage["lsfinDisclaimer"]
    assert "pas un conseil financier personnalisé" in disclaimer.lower()
    assert "éducative" in disclaimer.lower() or "educative" in disclaimer.lower()


# ---------------------------------------------------------------------------
# Test 6 — Body contains zero LSFin banned terms
# ---------------------------------------------------------------------------


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_eclairage_no_banned_terms(mock_query, client):
    """Eclairage body, headline, and disclaimer must contain zero banned terms."""
    from app.services.coach.compliance_guard import ComplianceGuard

    mock_query.return_value = _MOCK_LLM_RESULT

    _post(client)
    r2 = _post(client)
    eclairage = r2.json().get("eclairage")
    assert eclairage is not None

    guard = ComplianceGuard()
    full_text = " ".join(
        [
            eclairage["headline"],
            eclairage["body"],
            eclairage["softAccountHint"],
            eclairage["lsfinDisclaimer"],
        ]
    )
    found = guard._check_banned_terms(full_text)  # noqa: SLF001 — intended internal use
    assert found == [], f"Eclairage payload contains banned terms: {found}"


# ---------------------------------------------------------------------------
# Test 7 (bonus) — Eclairage is independent across distinct sessions
# ---------------------------------------------------------------------------


@patch(
    "app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query",
    new_callable=AsyncMock,
)
def test_eclairage_per_session_isolation(mock_query, client):
    """Two distinct sessions each get their own one-shot eclairage."""
    mock_query.return_value = _MOCK_LLM_RESULT
    other_session = "99998888-7777-6666-5555-444433332222"

    # Session A: turn 1, then turn 2 → eclairage
    _post(client, _SESSION_ID)
    rA2 = _post(client, _SESSION_ID)
    assert rA2.json().get("eclairage") is not None

    # Session B: turn 1, then turn 2 → its own eclairage
    _post(client, other_session)
    rB2 = _post(client, other_session)
    assert rB2.json().get("eclairage") is not None
