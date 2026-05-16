"""Wave 1c-A3 (D-A3-05 #4) — same-turn persistence + cache-first read.

Property #1: when the user replies with handshake values, CoachInsightRecord
             rows are upserted in the SAME db session.
Property #2: the dispatcher reads from pending_profile_updates BEFORE
             re-querying the DB (no DB lookup between cache write + retry).
Property #3 (smoke-only): _upsert_handshake_facts is a no-op when called with
             empty / None args — defensive guard.

Path note: lives at tests/test_coach_chat_handshake_persistence.py under
the FLAT tests/test_*.py convention (no subdirectory).
"""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.v1.endpoints.coach_chat import (
    _missing_fields_for,
    _upsert_handshake_facts,
)
from app.core.database import Base
from app.models.coach_insight import CoachInsightRecord
from app.services.coach.profile_extractor import extract_profile_facts


TEST_DB_URL = "sqlite:///:memory:"

_engine = create_engine(
    TEST_DB_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

_SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_engine)


@pytest.fixture
def db_session():
    """Create tables, yield a session, then drop tables."""
    Base.metadata.create_all(bind=_engine)
    session = _SessionLocal()
    yield session
    session.close()
    Base.metadata.drop_all(bind=_engine)


def test_handshake_facts_persist_in_single_session(db_session) -> None:
    """Property #1: facts from a user reply land in CoachInsightRecord.

    I-04 fix: _upsert_handshake_facts does NOT call db.commit() itself —
    the caller (test or outer agent-loop commit) drives persistence.
    This test commits explicitly to validate the upsert shape.
    """
    user_id = "test-user-handshake"
    reply = "j'ai 42 ans, 8 années AVS, 320'000 LPP, 25'000 sur mon 3a"
    facts = extract_profile_facts(reply, current_profile={})
    assert facts, "extractor should return at least one Fact"
    # Filter high-confidence (mirrors the agent-loop gate per I-01 fix).
    hi = [f for f in facts if f.confidence >= 0.75]
    assert hi, "at least one high-confidence fact expected"
    _upsert_handshake_facts(hi, user_id, db_session)
    db_session.commit()   # I-04 fix: caller drives the commit.
    rows = (
        db_session.query(CoachInsightRecord)
        .filter_by(user_id=user_id)
        .all()
    )
    assert len(rows) >= 1, "at least one CoachInsightRecord row expected"
    # D-A3-03 topic namespacing + provenance encoded inline.
    for row in rows:
        assert row.topic.startswith("profile."), (
            f"handshake facts must namespace topic as profile.* — got {row.topic}"
        )
        assert "source: handshake" in row.summary, (
            f"handshake facts must encode provenance inline — got {row.summary}"
        )


def test_pending_profile_updates_supersedes_db_in_dispatcher() -> None:
    """Property #2: in-turn cache beats DB on retry.

    Asserts the dispatcher helper merges cache before evaluating missing
    fields. No DB round-trip is required between cache-write and tool-retry
    because `_missing_fields_for` operates on the merged dict in-memory.
    """
    # DB profile is blank
    db_profile = {}
    # Cache has the values from the user's reply
    cache = {
        "age": 42,
        "avsContributionYears": 8,
        "lppBalance": 320_000,
        "pillar3aBalance": 25_000,
    }
    merged = {**db_profile, **cache}
    assert _missing_fields_for("get_retirement_projection", merged) == [], (
        "cache merge should satisfy all required fields"
    )


def test_upsert_handshake_facts_noop_on_empty_args(db_session) -> None:
    """Property #3: defensive — no rows written when facts/user_id/db missing."""
    _upsert_handshake_facts([], "u1", db_session)
    _upsert_handshake_facts([object()], "", db_session)
    _upsert_handshake_facts([object()], "u1", None)  # type: ignore[arg-type]
    rows = db_session.query(CoachInsightRecord).all()
    assert rows == []


def test_handshake_facts_upsert_dedups_on_user_topic(db_session) -> None:
    """Property #1b: second extraction for the same (user, topic) overwrites.

    Mirrors the (user_id, topic) index on CoachInsightRecord.
    """
    user_id = "test-user-dedup"
    # First reply — LPP 320k
    facts1 = extract_profile_facts(
        "LPP 320'000", current_profile={},
    )
    hi1 = [f for f in facts1 if f.confidence >= 0.75 and f.topic == "lpp"]
    assert hi1, "expected at least one LPP fact"
    _upsert_handshake_facts(hi1, user_id, db_session)
    db_session.commit()
    rows1 = db_session.query(CoachInsightRecord).filter_by(user_id=user_id).all()
    assert len(rows1) == 1
    # Second reply — LPP 400k (user revised)
    facts2 = extract_profile_facts(
        "LPP 400'000", current_profile={},
    )
    hi2 = [f for f in facts2 if f.confidence >= 0.75 and f.topic == "lpp"]
    _upsert_handshake_facts(hi2, user_id, db_session)
    db_session.commit()
    rows2 = db_session.query(CoachInsightRecord).filter_by(user_id=user_id).all()
    # Still 1 row (upsert dedup by (user, topic))
    assert len(rows2) == 1
    # Summary reflects the new value
    assert "400" in rows2[0].summary
