"""Wave 1a plan-05 — _compute_retrieve_memories dispatcher tests.

Per `wave-1a-05-PLAN.md` <behavior> for Task 2. 7 tests covering:
- Flag OFF passthrough byte-identical to legacy handler.
- Flag ON success path emits legacy line format `[insight_type] topic: summary`.
- Flag ON empty corpus falls back to legacy fallback string.
- BM25 score floor reject falls back to legacy.
- Cross-user isolation (user_b's data never appears in user_a's response).
- D-15 5-kwarg Sentry breadcrumb non-PII payload.
- db=None defensive passthrough.
"""
from __future__ import annotations

from unittest.mock import patch

import pytest

from tests.conftest import TestingSessionLocal


@pytest.fixture
def db():
    """SQLAlchemy session; cleans CoachInsightRecord between tests."""
    from app.models.coach_insight import CoachInsightRecord

    session = TestingSessionLocal()
    try:
        session.query(CoachInsightRecord).delete()
        session.commit()
        yield session
    finally:
        session.close()


def _ensure_user(db, user_id: str) -> None:
    from app.models import User

    existing = db.query(User).filter(User.id == user_id).first()
    if existing is not None:
        return
    db.add(
        User(
            id=user_id,
            email=f"{user_id}@example.com",
            hashed_password="x",
            display_name=user_id,
        )
    )
    db.commit()


def _add_insight(db, user_id: str, topic: str, summary: str, insight_type: str = "fact"):
    from app.models.coach_insight import CoachInsightRecord

    rec = CoachInsightRecord(
        user_id=user_id,
        topic=topic,
        summary=summary,
        insight_type=insight_type,
    )
    db.add(rec)
    db.commit()
    return rec


# ---------------------------------------------------------------------------


def test_flag_off_byte_identical_to_legacy(db, monkeypatch):
    """Test 1: flag OFF -> _compute_retrieve_memories == _handle_retrieve_memories output."""
    from app.api.v1.endpoints.coach_chat import (
        _compute_retrieve_memories,
        _handle_retrieve_memories,
    )
    from app.core.config import settings

    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED", False
    )

    _ensure_user(db, "u")
    _add_insight(db, "u", "3a", "Plafond 7258 CHF")
    memory_block = "some block\n3a related line\n"

    computed = _compute_retrieve_memories(
        topic="3a", user_id="u", db=db, max_results=3, memory_block=memory_block
    )
    legacy = _handle_retrieve_memories(
        topic="3a", memory_block=memory_block, max_results=3, user_id="u", db=db
    )

    assert computed == legacy


def test_flag_on_emits_legacy_line_format(db, monkeypatch):
    """Test 2: flag ON + hits -> output contains '[fact] 3a: Plafond 7258 CHF salarié'."""
    from app.api.v1.endpoints.coach_chat import _compute_retrieve_memories
    from app.core.config import settings

    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED", True
    )

    _ensure_user(db, "user_a")
    _add_insight(
        db, "user_a", "3a", "Plafond 7258 CHF salarie", insight_type="fact"
    )
    # Filler so BM25 IDF works.
    _add_insight(db, "user_a", "lpp", "rachats lpp possibles")
    _add_insight(db, "user_a", "canton", "habite Vaud")
    _add_insight(db, "user_a", "revenu", "salaire mensuel")

    out = _compute_retrieve_memories(
        topic="3a", user_id="user_a", db=db, max_results=3, memory_block=None
    )

    assert "[fact] 3a: Plafond 7258 CHF salarie" in out


def test_flag_on_no_hits_falls_back_to_legacy_string(db, monkeypatch):
    """Test 3: flag ON, empty CoachInsightRecord, no profile, no memory_block ->
    legacy fallback string 'Aucune memoire disponible pour ce sujet.'.
    """
    from app.api.v1.endpoints.coach_chat import (
        _compute_retrieve_memories,
        _handle_retrieve_memories,
    )
    from app.core.config import settings

    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED", True
    )

    _ensure_user(db, "user_a")

    computed = _compute_retrieve_memories(
        topic="3a", user_id="user_a", db=db, max_results=3, memory_block=None
    )
    legacy = _handle_retrieve_memories(
        topic="3a", memory_block=None, max_results=3, user_id="user_a", db=db
    )

    assert computed == legacy
    assert "Aucune m" in computed  # 'Aucune mémoire disponible pour ce sujet.'


def test_bm25_score_floor_reject_falls_back(db, monkeypatch):
    """Test 4: flag ON, unrelated query -> 0 BM25 hits -> legacy fallback string."""
    from app.api.v1.endpoints.coach_chat import _compute_retrieve_memories
    from app.core.config import settings

    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED", True
    )

    _ensure_user(db, "user_a")
    _add_insight(db, "user_a", "3a", "Plafond 7258 CHF")

    out = _compute_retrieve_memories(
        topic="totally_unrelated_xyz",
        user_id="user_a",
        db=db,
        max_results=3,
        memory_block=None,
    )

    # No BM25 hit + no memory_block -> legacy 'Pas de memoire trouvee' or
    # 'Aucune memoire disponible' depending on DB-pass content. Verify it's
    # one of the legacy fallback strings (not BM25-formatted output).
    assert "[fact]" not in out
    assert ("Pas de m" in out) or ("Aucune m" in out)


def test_cross_user_isolation_dispatcher_level(db, monkeypatch):
    """Test 5: user_b's insight summary must NOT appear in user_a's response."""
    from app.api.v1.endpoints.coach_chat import _compute_retrieve_memories
    from app.core.config import settings

    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED", True
    )

    _ensure_user(db, "user_a")
    _ensure_user(db, "user_b")
    _add_insight(db, "user_a", "3a", "user_a 3a summary")
    _add_insight(db, "user_a", "lpp", "user_a lpp filler")
    _add_insight(db, "user_a", "canton", "user_a canton filler")
    _add_insight(db, "user_a", "revenu", "user_a revenu filler")
    _add_insight(db, "user_b", "3a", "user_b 3a summary SECRET")

    out = _compute_retrieve_memories(
        topic="3a", user_id="user_b", db=db, max_results=3, memory_block=None
    )

    assert "user_b 3a summary SECRET" in out
    assert "user_a 3a summary" not in out


def test_d15_breadcrumb_5kwarg_non_pii_payload(db, monkeypatch):
    """Test 6: flag ON + hits -> Sentry breadcrumb fires with EXACT 5 kwargs, hashes applied."""
    from app.core.config import settings

    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED", True
    )

    _ensure_user(db, "user_a")
    _add_insight(db, "user_a", "3a", "Plafond 7258 CHF")
    _add_insight(db, "user_a", "lpp", "rachats lpp")
    _add_insight(db, "user_a", "canton", "Vaud")
    _add_insight(db, "user_a", "revenu", "8000")

    # The compute fn imports emit_coach_tool_breadcrumb LAZILY inside its body
    # (matches the plan-01/02 _compute_budget_status pattern). Patch at source
    # module so the lazy import binds to the mock.
    with patch(
        "app.observability.coach_breadcrumbs.emit_coach_tool_breadcrumb"
    ) as mock_breadcrumb:
        from app.api.v1.endpoints import coach_chat as _coach_chat
        out = _coach_chat._compute_retrieve_memories(
            topic="3a", user_id="user_a", db=db, max_results=3, memory_block=None
        )

    # Sanity: BM25 path returned hits (not legacy fallback).
    assert "[fact] 3a: Plafond 7258 CHF" in out

    assert mock_breadcrumb.call_count == 1
    call_kwargs = mock_breadcrumb.call_args.kwargs
    assert call_kwargs["tool_name"] == "retrieve_memories"
    assert len(call_kwargs["inputs_hash"]) == 64
    assert len(call_kwargs["profile_id_hashed"]) == 16
    assert call_kwargs["profile_id_hashed"] != "user_a"  # proves hash applied
    assert isinstance(call_kwargs["elapsed_ms"], int)
    assert call_kwargs["elapsed_ms"] >= 0
    assert call_kwargs["flag_state"] == "on"
    assert set(call_kwargs.keys()) == {
        "tool_name",
        "inputs_hash",
        "profile_id_hashed",
        "elapsed_ms",
        "flag_state",
    }


def test_db_none_passthrough_no_exception(monkeypatch):
    """Test 7: flag ON, db=None -> falls back to _handle_retrieve_memories(... db=None)."""
    from app.api.v1.endpoints.coach_chat import _compute_retrieve_memories
    from app.core.config import settings

    monkeypatch.setattr(
        settings, "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED", True
    )

    # No exception, returns one of the legacy fallback strings.
    out = _compute_retrieve_memories(
        topic="3a", user_id="user_a", db=None, max_results=3, memory_block=None
    )

    assert isinstance(out, str)
    assert "[fact]" not in out  # BM25 path NOT taken
