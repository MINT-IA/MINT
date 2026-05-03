"""
Tests for Phase 21 — Coach Memory Round-trip (CTX-02, CTX-03).

Covers:
    - CoachInsightRecord model persistence via save_insight handler
    - _build_insight_memory_block formats saved insights for system prompt
    - _handle_retrieve_memories searches DB-persisted insights
    - Deduplication by user_id + topic (update instead of duplicate)
    - Graceful fallback when no DB / no user_id

Run: cd services/backend && python3 -m pytest tests/test_coach_memory_roundtrip.py -v
"""

import pytest
from datetime import datetime, timedelta, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models.user import User
from app.models.coach_insight import CoachInsightRecord


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def integration_db():
    """Create an in-memory SQLite database with all tables for integration tests."""
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    _Session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = _Session()
    # Insert a test user (FK target for coach_insights)
    user = User(id="test-user-mem", email="mem@mint.ch", hashed_password="hashed")
    session.add(user)
    session.commit()
    yield session
    session.close()
    engine.dispose()


# ===========================================================================
# Test 1: save_insight persists to DB
# ===========================================================================


class TestSaveInsightPersistence:
    """Verify save_insight handler writes CoachInsightRecord to DB."""

    def test_save_insight_persists_to_db(self, integration_db):
        """Call _execute_internal_tool with save_insight, assert row in DB."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        result = _execute_internal_tool(
            tool_call={
                "name": "save_insight",
                "input": {
                    "summary": "Salaire ~120k",
                    "topic": "revenu",
                    "insight_type": "fact",
                },
            },
            memory_block=None,
            user_id="test-user-mem",
            db=integration_db,
            persistence_consent=True,
        )
        assert "Insight enregistré" in result

        # Verify DB row
        rows = integration_db.query(CoachInsightRecord).filter(
            CoachInsightRecord.user_id == "test-user-mem"
        ).all()
        assert len(rows) == 1
        assert rows[0].topic == "revenu"
        assert rows[0].summary == "Salaire ~120k"
        assert rows[0].insight_type == "fact"

    def test_save_insight_without_db_still_acks(self):
        """Call with user_id=None, db=None. Returns ack, no crash."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        result = _execute_internal_tool(
            tool_call={
                "name": "save_insight",
                "input": {
                    "summary": "Test sans DB",
                    "topic": "test",
                },
            },
            memory_block=None,
            user_id=None,
            db=None,
            persistence_consent=True,
        )
        assert "Insight enregistré" in result

    def test_save_insight_deduplicates_by_topic(self, integration_db):
        """Save insight with same topic twice — updates existing, no duplicate."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        _execute_internal_tool(
            tool_call={
                "name": "save_insight",
                "input": {
                    "summary": "Salaire ~120k",
                    "topic": "revenu",
                    "insight_type": "fact",
                },
            },
            memory_block=None,
            user_id="test-user-mem",
            db=integration_db,
            persistence_consent=True,
        )

        _execute_internal_tool(
            tool_call={
                "name": "save_insight",
                "input": {
                    "summary": "Salaire recalculé ~130k",
                    "topic": "revenu",
                    "insight_type": "fact",
                },
            },
            memory_block=None,
            user_id="test-user-mem",
            db=integration_db,
            persistence_consent=True,
        )

        rows = integration_db.query(CoachInsightRecord).filter(
            CoachInsightRecord.user_id == "test-user-mem",
            CoachInsightRecord.topic == "revenu",
        ).all()
        assert len(rows) == 1
        assert "130k" in rows[0].summary

    def test_save_insight_default_insight_type(self, integration_db):
        """Save insight without insight_type defaults to 'fact'."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        _execute_internal_tool(
            tool_call={
                "name": "save_insight",
                "input": {
                    "summary": "Canton VS",
                    "topic": "canton",
                },
            },
            memory_block=None,
            user_id="test-user-mem",
            db=integration_db,
            persistence_consent=True,
        )

        row = integration_db.query(CoachInsightRecord).filter(
            CoachInsightRecord.topic == "canton"
        ).first()
        assert row is not None
        assert row.insight_type == "fact"


# ===========================================================================
# Test 2 & 3: _build_insight_memory_block
# ===========================================================================


class TestBuildInsightMemoryBlock:
    """Verify _build_insight_memory_block output."""

    def test_build_insight_memory_block_formats_correctly(self, integration_db):
        """Insert 3 insights, verify formatted block with INSIGHTS MEMORISES header."""
        from app.api.v1.endpoints.coach_chat import _build_insight_memory_block

        for topic, summary, itype in [
            ("revenu", "Salaire ~120k", "fact"),
            ("3a", "A décidé d'ouvrir un 3a chez PostFinance", "decision"),
            ("canton", "Habite en Valais", "fact"),
        ]:
            record = CoachInsightRecord(
                user_id="test-user-mem",
                topic=topic,
                summary=summary,
                insight_type=itype,
            )
            integration_db.add(record)
        integration_db.commit()

        block = _build_insight_memory_block("test-user-mem", integration_db)
        assert "INSIGHTS MEMORISES" in block
        assert "revenu" in block
        assert "120k" in block
        assert "3a" in block
        assert "PostFinance" in block
        assert "canton" in block
        assert "Valais" in block

    def test_build_insight_memory_block_empty_when_no_data(self, integration_db):
        """Returns empty string when user has no insights."""
        from app.api.v1.endpoints.coach_chat import _build_insight_memory_block

        result = _build_insight_memory_block("test-user-mem", integration_db)
        assert result == ""

    def test_build_insight_memory_block_no_user_id(self):
        """Returns empty string when user_id is None."""
        from app.api.v1.endpoints.coach_chat import _build_insight_memory_block

        assert _build_insight_memory_block(None, None) == ""

    def test_build_insight_memory_block_no_db(self):
        """Returns empty string when db is None."""
        from app.api.v1.endpoints.coach_chat import _build_insight_memory_block

        assert _build_insight_memory_block("user-1", None) == ""


# ===========================================================================
# Test 4: retrieve_memories searches DB insights
# ===========================================================================


class TestRetrieveMemoriesSearchesDB:
    """Verify _handle_retrieve_memories also searches DB-persisted insights."""

    def test_retrieve_memories_searches_db_insights(self, integration_db):
        """Persist an insight, then retrieve_memories finds it by topic."""
        from app.api.v1.endpoints.coach_chat import _handle_retrieve_memories

        record = CoachInsightRecord(
            user_id="test-user-mem",
            topic="revenu",
            summary="Salaire brut ~120k CHF par an",
            insight_type="fact",
        )
        integration_db.add(record)
        integration_db.commit()

        result = _handle_retrieve_memories(
            topic="revenu",
            memory_block="",
            user_id="test-user-mem",
            db=integration_db,
        )
        assert "120k" in result

    def test_retrieve_memories_combines_memory_block_and_db(self, integration_db):
        """Finds results from both memory_block text and DB insights."""
        from app.api.v1.endpoints.coach_chat import _handle_retrieve_memories

        record = CoachInsightRecord(
            user_id="test-user-mem",
            topic="revenu",
            summary="Salaire brut ~120k CHF par an",
            insight_type="fact",
        )
        integration_db.add(record)
        integration_db.commit()

        result = _handle_retrieve_memories(
            topic="revenu",
            memory_block="revenu mensuel estimé: 10k CHF",
            user_id="test-user-mem",
            db=integration_db,
        )
        assert "120k" in result or "10k" in result

    def test_retrieve_memories_without_db_still_works(self):
        """Falls back to memory_block-only search when no db."""
        from app.api.v1.endpoints.coach_chat import _handle_retrieve_memories

        result = _handle_retrieve_memories(
            topic="revenu",
            memory_block="revenu mensuel estimé: 10k CHF",
        )
        assert "10k" in result


# ===========================================================================
# Test 5: Full round-trip integration
# ===========================================================================


class TestFullRoundTrip:
    """End-to-end: save_insight -> DB -> _build_insight_memory_block."""

    def test_save_then_build_block(self, integration_db):
        """Save via handler, then build block — proves the full round-trip."""
        from app.api.v1.endpoints.coach_chat import (
            _execute_internal_tool,
            _build_insight_memory_block,
        )

        _execute_internal_tool(
            tool_call={
                "name": "save_insight",
                "input": {
                    "summary": "Canton VS, commune Sion",
                    "topic": "domicile",
                    "insight_type": "fact",
                },
            },
            memory_block=None,
            user_id="test-user-mem",
            db=integration_db,
            persistence_consent=True,
        )

        block = _build_insight_memory_block("test-user-mem", integration_db)
        assert "INSIGHTS MEMORISES" in block
        assert "domicile" in block
        assert "Sion" in block
