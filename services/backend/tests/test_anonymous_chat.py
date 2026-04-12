"""
Tests for the Anonymous Chat endpoint — POST /api/v1/anonymous/chat.

Phase 13-01: Anonymous discovery chat with device-scoped rate limiting.

Covers:
    - HTTP contract: 200 on valid request, 400 on missing session header
    - Rate limiting: 3 messages per device token (lifetime), 429 after
    - Response schema: message, disclaimers, messages_remaining, tokens_used
    - Discovery system prompt: no tools, no profile, no memory references
    - Intent injection into system prompt
    - AnonymousSession DB model: session_id, message_count, created_at
    - Compliance: disclaimers always present
    - Session isolation: different session_ids are independent

Run: cd services/backend && python3 -m pytest tests/test_anonymous_chat.py -v
"""

import os
import re

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ["TESTING"] = "1"

from app.main import app
from app.core.database import Base, get_db


# ---------------------------------------------------------------------------
# Test DB setup — in-memory SQLite
# ---------------------------------------------------------------------------

TEST_DB_URL = "sqlite:///./test_anonymous_chat.db"
test_engine = create_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


def override_get_db():
    db = TestSessionLocal()
    try:
        yield db
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def setup_db():
    """Create tables before each test and drop after."""
    Base.metadata.create_all(bind=test_engine)
    app.dependency_overrides[get_db] = override_get_db
    yield
    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture
def client():
    return TestClient(app)


_MOCK_LLM_RESULT = {
    "answer": "En Suisse, ton 2e pilier est souvent le plus gros actif que tu possedes.",
    "sources": [],
    "disclaimers": ["Outil educatif, ne constitue pas un conseil financier (LSFin)."],
    "tokens_used": 150,
}

_VALID_BODY = {"message": "Je me sens perdu avec mes finances"}
_SESSION_HEADER = "X-Anonymous-Session"
_VALID_SESSION_ID = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"


# ---------------------------------------------------------------------------
# Test 1: Valid POST returns 200 with expected fields
# ---------------------------------------------------------------------------

@patch("app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query", new_callable=AsyncMock)
def test_valid_post_returns_200(mock_query, client):
    """POST /api/v1/anonymous/chat with valid message + session header returns 200."""
    mock_query.return_value = _MOCK_LLM_RESULT
    resp = client.post(
        "/api/v1/anonymous/chat",
        json=_VALID_BODY,
        headers={_SESSION_HEADER: _VALID_SESSION_ID},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "message" in data
    assert "disclaimers" in data
    assert "messagesRemaining" in data
    assert data["messagesRemaining"] == 2
    assert "tokensUsed" in data


# ---------------------------------------------------------------------------
# Test 2: Missing session header returns 400
# ---------------------------------------------------------------------------

def test_missing_session_header_returns_400(client):
    """POST without X-Anonymous-Session header returns 400."""
    resp = client.post("/api/v1/anonymous/chat", json=_VALID_BODY)
    assert resp.status_code == 400
    assert "anonyme" in resp.json()["detail"].lower() or "session" in resp.json()["detail"].lower()


# ---------------------------------------------------------------------------
# Test 3: Empty/whitespace message returns 422
# ---------------------------------------------------------------------------

def test_empty_message_returns_422(client):
    """POST with empty/whitespace message returns 422 validation error."""
    resp = client.post(
        "/api/v1/anonymous/chat",
        json={"message": "   "},
        headers={_SESSION_HEADER: _VALID_SESSION_ID},
    )
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Test 4: 4th POST returns 429 (rate limit)
# ---------------------------------------------------------------------------

@patch("app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query", new_callable=AsyncMock)
def test_fourth_post_returns_429(mock_query, client):
    """After 3 successful POSTs with same session_id, 4th returns 429."""
    mock_query.return_value = _MOCK_LLM_RESULT
    for _ in range(3):
        resp = client.post(
            "/api/v1/anonymous/chat",
            json=_VALID_BODY,
            headers={_SESSION_HEADER: _VALID_SESSION_ID},
        )
        assert resp.status_code == 200

    resp = client.post(
        "/api/v1/anonymous/chat",
        json=_VALID_BODY,
        headers={_SESSION_HEADER: _VALID_SESSION_ID},
    )
    assert resp.status_code == 429
    assert "Limite" in resp.json()["detail"] or "limite" in resp.json()["detail"]


# ---------------------------------------------------------------------------
# Test 5: Different session_id can still POST
# ---------------------------------------------------------------------------

@patch("app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query", new_callable=AsyncMock)
def test_different_session_can_post(mock_query, client):
    """Different session_id can still POST after first session exhausted."""
    mock_query.return_value = _MOCK_LLM_RESULT
    # Exhaust first session
    for _ in range(3):
        client.post(
            "/api/v1/anonymous/chat",
            json=_VALID_BODY,
            headers={_SESSION_HEADER: _VALID_SESSION_ID},
        )
    # New session should work
    other_session = "11111111-2222-3333-4444-555555555555"
    resp = client.post(
        "/api/v1/anonymous/chat",
        json=_VALID_BODY,
        headers={_SESSION_HEADER: other_session},
    )
    assert resp.status_code == 200
    assert resp.json()["messagesRemaining"] == 2


# ---------------------------------------------------------------------------
# Test 6: messages_remaining decrements correctly
# ---------------------------------------------------------------------------

@patch("app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query", new_callable=AsyncMock)
def test_messages_remaining_decrements(mock_query, client):
    """messages_remaining decrements: 2, 1, 0."""
    mock_query.return_value = _MOCK_LLM_RESULT
    expected_remaining = [2, 1, 0]
    for i in range(3):
        resp = client.post(
            "/api/v1/anonymous/chat",
            json=_VALID_BODY,
            headers={_SESSION_HEADER: _VALID_SESSION_ID},
        )
        assert resp.status_code == 200
        assert resp.json()["messagesRemaining"] == expected_remaining[i]


# ---------------------------------------------------------------------------
# Test 7: Response always contains disclaimers
# ---------------------------------------------------------------------------

@patch("app.api.v1.endpoints.anonymous_chat._NoRagOrchestrator.query", new_callable=AsyncMock)
def test_response_contains_disclaimers(mock_query, client):
    """Response always contains disclaimers list (compliance)."""
    mock_query.return_value = _MOCK_LLM_RESULT
    resp = client.post(
        "/api/v1/anonymous/chat",
        json=_VALID_BODY,
        headers={_SESSION_HEADER: _VALID_SESSION_ID},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data["disclaimers"], list)
    assert len(data["disclaimers"]) > 0


# ---------------------------------------------------------------------------
# Test 8: Discovery prompt contains no tool/profile/memory references
# ---------------------------------------------------------------------------

def test_discovery_prompt_no_tool_references():
    """Discovery system prompt contains no 'outil'/'tool'/'profil'/'memoire' references."""
    from app.api.v1.endpoints.anonymous_chat import build_discovery_system_prompt

    prompt = build_discovery_system_prompt(intent=None, language="fr")
    prompt_lower = prompt.lower()
    # These terms should NOT appear in the discovery prompt
    for banned in ["outil", "tool", "profil", "memoire", "memory", "dossier"]:
        assert banned not in prompt_lower, f"Discovery prompt must not contain '{banned}'"


# ---------------------------------------------------------------------------
# Test 9: Intent field is optional; when provided, included in prompt
# ---------------------------------------------------------------------------

def test_intent_included_in_prompt():
    """When intent is provided, it appears in the discovery system prompt."""
    from app.api.v1.endpoints.anonymous_chat import build_discovery_system_prompt

    prompt_no_intent = build_discovery_system_prompt(intent=None, language="fr")
    prompt_with_intent = build_discovery_system_prompt(
        intent="Je me sens perdu", language="fr"
    )
    assert "Je me sens perdu" in prompt_with_intent
    assert "sentiment" in prompt_with_intent.lower() or "exprim" in prompt_with_intent.lower()
    # Without intent, the intent phrase should not appear
    assert "Je me sens perdu" not in prompt_no_intent


# ---------------------------------------------------------------------------
# Test 10: AnonymousSession DB model stores expected fields
# ---------------------------------------------------------------------------

def test_anonymous_session_model(setup_db):
    """AnonymousSession DB model stores session_id, message_count, created_at."""
    from app.models.anonymous_session import AnonymousSession

    db = TestSessionLocal()
    try:
        session = AnonymousSession(
            session_id="test-session-id-00000000000000000",
            message_count=0,
        )
        db.add(session)
        db.commit()
        db.refresh(session)
        assert session.session_id == "test-session-id-00000000000000000"
        assert session.message_count == 0
        assert session.created_at is not None
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Test 11 (bonus): Malformed session ID (not UUID format) returns 400
# ---------------------------------------------------------------------------

def test_malformed_session_id_returns_400(client):
    """Malformed session ID (not UUID-like) returns 400 (T-13-01 mitigation)."""
    resp = client.post(
        "/api/v1/anonymous/chat",
        json=_VALID_BODY,
        headers={_SESSION_HEADER: "not-a-valid-uuid"},
    )
    assert resp.status_code == 400
