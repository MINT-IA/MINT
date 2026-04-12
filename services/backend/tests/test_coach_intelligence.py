"""
Tests for Phase 15 — Coach Intelligence (INTL-01, INTL-02, INTL-03, INTL-04).

Covers:
    - ProvenanceRecord and EarmarkTag model instantiation and defaults
    - Tool registration (save_provenance, save_earmark, remove_earmark)
    - System prompt directives (PROVENANCE, ARGENT MARQUE)
    - Internal tool handler messages
    - Intelligence memory block builder

Run: cd services/backend && python3 -m pytest tests/test_coach_intelligence.py -v
"""

from datetime import datetime, timezone
from typing import Optional
from unittest.mock import MagicMock

from app.models.earmark import EarmarkTag, ProvenanceRecord
from app.services.coach.coach_tools import COACH_TOOLS, INTERNAL_TOOL_NAMES
from app.services.coach.claude_coach_service import build_system_prompt


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _find_tool(name: str) -> Optional[dict]:
    """Return the tool definition with the given name, or None."""
    return next((t for t in COACH_TOOLS if t["name"] == name), None)


# ===========================================================================
# Model tests
# ===========================================================================


class TestProvenanceRecordModel:
    """ProvenanceRecord SQLAlchemy model."""

    def test_provenance_create_all_fields(self):
        """ProvenanceRecord instantiates with all fields."""
        p = ProvenanceRecord(
            user_id="user-123",
            product_type="3a",
            recommended_by="mon banquier",
            institution="UBS",
            context_note="Proposé lors du dernier rendez-vous",
        )
        assert p.user_id == "user-123"
        assert p.product_type == "3a"
        assert p.recommended_by == "mon banquier"
        assert p.institution == "UBS"
        assert p.context_note == "Proposé lors du dernier rendez-vous"

    def test_provenance_create_minimal(self):
        """ProvenanceRecord instantiates with optional fields None."""
        p = ProvenanceRecord(
            user_id="user-123",
            product_type="lpp",
            recommended_by="Uncle Patrick",
            institution=None,
            context_note=None,
        )
        assert p.institution is None
        assert p.context_note is None

    def test_provenance_tablename(self):
        """Table name is provenance_records."""
        assert ProvenanceRecord.__tablename__ == "provenance_records"

    def test_provenance_defaults(self):
        """id auto-generated, created_at has default factory."""
        assert ProvenanceRecord.id.default is not None
        assert ProvenanceRecord.created_at.default is not None

    def test_provenance_table_args_index(self):
        """Composite index on (user_id, product_type) exists."""
        index_names = [idx.name for idx in ProvenanceRecord.__table_args__ if hasattr(idx, "name")]
        assert "ix_provenance_records_user_product" in index_names


class TestEarmarkTagModel:
    """EarmarkTag SQLAlchemy model."""

    def test_earmark_create_all_fields(self):
        """EarmarkTag instantiates with all fields."""
        e = EarmarkTag(
            user_id="user-456",
            label="l'argent de mamie",
            source_description="heritage de grand-mere en 2019",
            amount_hint="environ 50k",
        )
        assert e.user_id == "user-456"
        assert e.label == "l'argent de mamie"
        assert e.source_description == "heritage de grand-mere en 2019"
        assert e.amount_hint == "environ 50k"

    def test_earmark_create_minimal(self):
        """EarmarkTag instantiates with label only."""
        e = EarmarkTag(
            user_id="user-456",
            label="le compte pour les enfants",
        )
        assert e.label == "le compte pour les enfants"
        assert e.source_description is None
        assert e.amount_hint is None

    def test_earmark_tablename(self):
        """Table name is earmark_tags."""
        assert EarmarkTag.__tablename__ == "earmark_tags"

    def test_earmark_defaults(self):
        """id auto-generated, created_at has default factory."""
        assert EarmarkTag.id.default is not None
        assert EarmarkTag.created_at.default is not None

    def test_earmark_table_args_index(self):
        """Composite index on (user_id, label) exists."""
        index_names = [idx.name for idx in EarmarkTag.__table_args__ if hasattr(idx, "name")]
        assert "ix_earmark_tags_user_label" in index_names


# ===========================================================================
# Tool registration tests
# ===========================================================================


class TestIntelligenceToolRegistration:
    """Verify tool registration in COACH_TOOLS and INTERNAL_TOOL_NAMES."""

    def test_save_provenance_in_internal_tools(self):
        """save_provenance is in INTERNAL_TOOL_NAMES."""
        assert "save_provenance" in INTERNAL_TOOL_NAMES

    def test_save_earmark_in_internal_tools(self):
        """save_earmark is in INTERNAL_TOOL_NAMES."""
        assert "save_earmark" in INTERNAL_TOOL_NAMES

    def test_remove_earmark_in_internal_tools(self):
        """remove_earmark is in INTERNAL_TOOL_NAMES."""
        assert "remove_earmark" in INTERNAL_TOOL_NAMES

    def test_save_provenance_tool_defined(self):
        """save_provenance exists in COACH_TOOLS with correct schema."""
        tool = _find_tool("save_provenance")
        assert tool is not None
        assert tool["category"] == "write"
        assert "product_type" in tool["input_schema"]["properties"]
        assert "recommended_by" in tool["input_schema"]["properties"]

    def test_save_provenance_required_fields(self):
        """save_provenance requires product_type and recommended_by."""
        tool = _find_tool("save_provenance")
        assert tool is not None
        required = tool["input_schema"]["required"]
        assert "product_type" in required
        assert "recommended_by" in required

    def test_save_earmark_tool_defined(self):
        """save_earmark exists in COACH_TOOLS with correct schema."""
        tool = _find_tool("save_earmark")
        assert tool is not None
        assert tool["category"] == "write"
        assert "label" in tool["input_schema"]["properties"]

    def test_save_earmark_required_fields(self):
        """save_earmark requires label."""
        tool = _find_tool("save_earmark")
        assert tool is not None
        required = tool["input_schema"]["required"]
        assert "label" in required

    def test_remove_earmark_tool_defined(self):
        """remove_earmark exists in COACH_TOOLS with correct schema."""
        tool = _find_tool("remove_earmark")
        assert tool is not None
        assert tool["category"] == "write"
        assert "label" in tool["input_schema"]["properties"]

    def test_remove_earmark_required_fields(self):
        """remove_earmark requires label."""
        tool = _find_tool("remove_earmark")
        assert tool is not None
        required = tool["input_schema"]["required"]
        assert "label" in required


# ===========================================================================
# System prompt directive tests
# ===========================================================================


class TestIntelligenceSystemPromptDirectives:
    """Verify system prompt includes intelligence directives."""

    def test_system_prompt_has_provenance_directive(self):
        """build_system_prompt() output contains PROVENANCE."""
        prompt = build_system_prompt()
        assert "PROVENANCE" in prompt

    def test_system_prompt_has_earmark_directive(self):
        """build_system_prompt() output contains ARGENT MARQUE."""
        prompt = build_system_prompt()
        assert "ARGENT MARQUE" in prompt

    def test_system_prompt_provenance_mentions_save_provenance(self):
        """Provenance directive references save_provenance tool."""
        prompt = build_system_prompt()
        assert "save_provenance" in prompt

    def test_system_prompt_earmark_mentions_save_earmark(self):
        """Earmark directive references save_earmark tool."""
        prompt = build_system_prompt()
        assert "save_earmark" in prompt


# ===========================================================================
# Internal tool handler tests
# ===========================================================================


class TestIntelligenceToolHandlers:
    """Verify _execute_internal_tool returns correct messages."""

    def test_save_provenance_handler(self):
        """_execute_internal_tool returns ack for save_provenance."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        result = _execute_internal_tool(
            tool_call={
                "name": "save_provenance",
                "input": {
                    "product_type": "3a",
                    "recommended_by": "mon banquier",
                    "institution": "UBS",
                },
            },
            memory_block=None,
        )
        assert "Provenance notée" in result
        assert "3a" in result
        assert "mon banquier" in result

    def test_save_earmark_handler(self):
        """_execute_internal_tool returns ack for save_earmark."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        result = _execute_internal_tool(
            tool_call={
                "name": "save_earmark",
                "input": {
                    "label": "l'argent de mamie",
                    "source_description": "heritage 2019",
                    "amount_hint": "environ 50k",
                },
            },
            memory_block=None,
        )
        assert "Marquage enregistré" in result
        assert "l'argent de mamie" in result

    def test_remove_earmark_handler_not_found(self):
        """_execute_internal_tool returns not-found for remove_earmark without db."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        result = _execute_internal_tool(
            tool_call={
                "name": "remove_earmark",
                "input": {
                    "label": "l'argent de mamie",
                },
            },
            memory_block=None,
        )
        assert "Aucun marquage" in result


# ===========================================================================
# Intelligence memory block builder tests
# ===========================================================================


class TestBuildIntelligenceMemoryBlock:
    """Verify _build_intelligence_memory_block output."""

    def test_returns_empty_when_no_user_id(self):
        """Returns empty string when user_id is None."""
        from app.api.v1.endpoints.coach_chat import _build_intelligence_memory_block

        assert _build_intelligence_memory_block(None, None) == ""

    def test_returns_empty_when_no_db(self):
        """Returns empty string when db is None."""
        from app.api.v1.endpoints.coach_chat import _build_intelligence_memory_block

        assert _build_intelligence_memory_block("user-1", None) == ""

    def test_returns_empty_when_no_data(self):
        """Returns empty string when DB has no intelligence data."""
        from app.api.v1.endpoints.coach_chat import _build_intelligence_memory_block

        mock_db = MagicMock()
        mock_query = MagicMock()
        mock_db.query.return_value = mock_query
        mock_query.filter.return_value = mock_query
        mock_query.order_by.return_value = mock_query
        mock_query.limit.return_value = mock_query
        mock_query.all.return_value = []

        result = _build_intelligence_memory_block("user-1", mock_db)
        assert result == ""

    def test_formats_provenance_records(self):
        """Returns PROVENANCE CONNUE section with formatted records."""
        from app.api.v1.endpoints.coach_chat import _build_intelligence_memory_block

        mock_prov = MagicMock()
        mock_prov.product_type = "3a"
        mock_prov.recommended_by = "mon banquier"
        mock_prov.institution = "UBS"
        mock_prov.created_at = datetime(2026, 4, 10, tzinfo=timezone.utc)

        mock_db = MagicMock()
        mock_query = MagicMock()
        mock_db.query.return_value = mock_query
        mock_query.filter.return_value = mock_query
        mock_query.order_by.return_value = mock_query
        mock_query.limit.return_value = mock_query
        # First .all() returns provenances, second returns earmarks
        mock_query.all.side_effect = [[mock_prov], []]

        result = _build_intelligence_memory_block("user-1", mock_db)
        assert "PROVENANCE CONNUE" in result
        assert "3a" in result
        assert "mon banquier" in result
        assert "chez UBS" in result

    def test_formats_earmark_tags(self):
        """Returns ARGENT MARQUE section with formatted tags."""
        from app.api.v1.endpoints.coach_chat import _build_intelligence_memory_block

        mock_earmark = MagicMock()
        mock_earmark.label = "l'argent de mamie"
        mock_earmark.amount_hint = "environ 50k"
        mock_earmark.source_description = "heritage 2019"
        mock_earmark.created_at = datetime(2026, 4, 10, tzinfo=timezone.utc)

        mock_db = MagicMock()
        mock_query = MagicMock()
        mock_db.query.return_value = mock_query
        mock_query.filter.return_value = mock_query
        mock_query.order_by.return_value = mock_query
        mock_query.limit.return_value = mock_query
        # First .all() returns provenances (empty), second returns earmarks
        mock_query.all.side_effect = [[], [mock_earmark]]

        result = _build_intelligence_memory_block("user-1", mock_db)
        assert "ARGENT MARQUÉ" in result
        assert "l'argent de mamie" in result
        assert "environ 50k" in result
        assert "heritage 2019" in result

    def test_formats_both_sections(self):
        """Returns both PROVENANCE and EARMARK sections together."""
        from app.api.v1.endpoints.coach_chat import _build_intelligence_memory_block

        mock_prov = MagicMock()
        mock_prov.product_type = "hypotheque"
        mock_prov.recommended_by = "un ami"
        mock_prov.institution = None
        mock_prov.created_at = datetime(2026, 4, 10, tzinfo=timezone.utc)

        mock_earmark = MagicMock()
        mock_earmark.label = "le compte pour les enfants"
        mock_earmark.amount_hint = None
        mock_earmark.source_description = None
        mock_earmark.created_at = datetime(2026, 4, 10, tzinfo=timezone.utc)

        mock_db = MagicMock()
        mock_query = MagicMock()
        mock_db.query.return_value = mock_query
        mock_query.filter.return_value = mock_query
        mock_query.order_by.return_value = mock_query
        mock_query.limit.return_value = mock_query
        mock_query.all.side_effect = [[mock_prov], [mock_earmark]]

        result = _build_intelligence_memory_block("user-1", mock_db)
        assert "PROVENANCE CONNUE" in result
        assert "ARGENT MARQUÉ" in result
        assert "hypotheque" in result
        assert "le compte pour les enfants" in result

    def test_db_error_returns_empty(self):
        """Returns empty string on DB error (graceful fallback)."""
        from app.api.v1.endpoints.coach_chat import _build_intelligence_memory_block

        mock_db = MagicMock()
        mock_db.query.side_effect = Exception("DB connection error")

        result = _build_intelligence_memory_block("user-1", mock_db)
        assert result == ""

    def test_provenance_without_institution(self):
        """Provenance record without institution omits 'chez' part."""
        from app.api.v1.endpoints.coach_chat import _build_intelligence_memory_block

        mock_prov = MagicMock()
        mock_prov.product_type = "assurance_vie"
        mock_prov.recommended_by = "ma soeur"
        mock_prov.institution = None
        mock_prov.created_at = datetime(2026, 4, 10, tzinfo=timezone.utc)

        mock_db = MagicMock()
        mock_query = MagicMock()
        mock_db.query.return_value = mock_query
        mock_query.filter.return_value = mock_query
        mock_query.order_by.return_value = mock_query
        mock_query.limit.return_value = mock_query
        mock_query.all.side_effect = [[mock_prov], []]

        result = _build_intelligence_memory_block("user-1", mock_db)
        assert "chez" not in result
        assert "ma soeur" in result


# ===========================================================================
# Integration tests: round-trip provenance/earmark flow (Plan 15-02)
# ===========================================================================

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models.user import User


@pytest.fixture
def integration_db():
    """Create an in-memory SQLite database with all tables for integration tests."""
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    _Session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = _Session()
    # Insert a test user (FK target for provenance/earmark records)
    user = User(id="test-user-intg", email="test@mint.ch", hashed_password="hashed")
    session.add(user)
    session.commit()
    yield session
    session.close()
    engine.dispose()


class TestProvenanceRoundtrip:
    """Verify save_provenance handler writes to DB and _build_intelligence_memory_block reads it back."""

    def test_provenance_roundtrip_formats_correctly(self, integration_db):
        """Create ProvenanceRecord via handler, call memory block builder, verify output."""
        from app.api.v1.endpoints.coach_chat import (
            _execute_internal_tool,
            _build_intelligence_memory_block,
        )

        # Step 1: Write via handler
        result = _execute_internal_tool(
            tool_call={
                "name": "save_provenance",
                "input": {
                    "product_type": "3a",
                    "recommended_by": "mon banquier",
                    "institution": "UBS",
                },
            },
            memory_block=None,
            user_id="test-user-intg",
            db=integration_db,
        )
        assert "Provenance notée" in result

        # Step 2: Read via memory block builder
        block = _build_intelligence_memory_block("test-user-intg", integration_db)
        assert "PROVENANCE CONNUE" in block
        assert "3a" in block
        assert "mon banquier" in block
        assert "chez UBS" in block

    def test_earmark_roundtrip_formats_correctly(self, integration_db):
        """Create EarmarkTag via handler, call memory block builder, verify output."""
        from app.api.v1.endpoints.coach_chat import (
            _execute_internal_tool,
            _build_intelligence_memory_block,
        )

        result = _execute_internal_tool(
            tool_call={
                "name": "save_earmark",
                "input": {
                    "label": "l'argent de mamie",
                    "source_description": "heritage 2019",
                    "amount_hint": "environ 50k",
                },
            },
            memory_block=None,
            user_id="test-user-intg",
            db=integration_db,
        )
        assert "Marquage enregistré" in result

        block = _build_intelligence_memory_block("test-user-intg", integration_db)
        assert "ARGENT MARQUÉ" in block
        assert "l'argent de mamie" in block
        assert "environ 50k" in block
        assert "heritage 2019" in block

    def test_earmark_with_amount_hint_shows_in_block(self, integration_db):
        """Earmark with amount_hint includes approximate amount with ~ prefix."""
        from app.api.v1.endpoints.coach_chat import (
            _execute_internal_tool,
            _build_intelligence_memory_block,
        )

        _execute_internal_tool(
            tool_call={
                "name": "save_earmark",
                "input": {
                    "label": "le compte pour les enfants",
                    "amount_hint": "~30'000",
                },
            },
            memory_block=None,
            user_id="test-user-intg",
            db=integration_db,
        )

        block = _build_intelligence_memory_block("test-user-intg", integration_db)
        assert "~30'000" in block
        assert "le compte pour les enfants" in block

    def test_remove_earmark_handler_deletes_from_db(self, integration_db):
        """Simulate remove_earmark tool call, verify tag is deleted from DB."""
        from app.api.v1.endpoints.coach_chat import (
            _execute_internal_tool,
            _build_intelligence_memory_block,
        )

        # Create earmark
        _execute_internal_tool(
            tool_call={
                "name": "save_earmark",
                "input": {"label": "argent vacances"},
            },
            memory_block=None,
            user_id="test-user-intg",
            db=integration_db,
        )
        # Verify it exists
        block_before = _build_intelligence_memory_block("test-user-intg", integration_db)
        assert "argent vacances" in block_before

        # Remove it
        result = _execute_internal_tool(
            tool_call={
                "name": "remove_earmark",
                "input": {"label": "argent vacances"},
            },
            memory_block=None,
            user_id="test-user-intg",
            db=integration_db,
        )
        assert "supprimé" in result

        # Verify it's gone
        block_after = _build_intelligence_memory_block("test-user-intg", integration_db)
        assert "argent vacances" not in block_after

    def test_provenance_dedup_by_product(self, integration_db):
        """Two provenances for same product_type both appear (multiple recommendations)."""
        from app.api.v1.endpoints.coach_chat import (
            _execute_internal_tool,
            _build_intelligence_memory_block,
        )

        _execute_internal_tool(
            tool_call={
                "name": "save_provenance",
                "input": {
                    "product_type": "3a",
                    "recommended_by": "mon banquier",
                    "institution": "UBS",
                },
            },
            memory_block=None,
            user_id="test-user-intg",
            db=integration_db,
        )
        _execute_internal_tool(
            tool_call={
                "name": "save_provenance",
                "input": {
                    "product_type": "3a",
                    "recommended_by": "Uncle Patrick",
                    "institution": "PostFinance",
                },
            },
            memory_block=None,
            user_id="test-user-intg",
            db=integration_db,
        )

        block = _build_intelligence_memory_block("test-user-intg", integration_db)
        assert "mon banquier" in block
        assert "Uncle Patrick" in block
        assert block.count("3a") >= 2

    def test_mixed_provenance_and_earmarks(self, integration_db):
        """Insert both provenance and earmark, verify both sections appear in memory block."""
        from app.api.v1.endpoints.coach_chat import (
            _execute_internal_tool,
            _build_intelligence_memory_block,
        )

        _execute_internal_tool(
            tool_call={
                "name": "save_provenance",
                "input": {
                    "product_type": "hypotheque",
                    "recommended_by": "un ami",
                },
            },
            memory_block=None,
            user_id="test-user-intg",
            db=integration_db,
        )
        _execute_internal_tool(
            tool_call={
                "name": "save_earmark",
                "input": {
                    "label": "le compte pour les enfants",
                    "source_description": "epargne depuis naissance",
                },
            },
            memory_block=None,
            user_id="test-user-intg",
            db=integration_db,
        )

        block = _build_intelligence_memory_block("test-user-intg", integration_db)
        assert "PROVENANCE CONNUE" in block
        assert "ARGENT MARQUÉ" in block
        assert "hypotheque" in block
        assert "un ami" in block
        assert "le compte pour les enfants" in block
        assert "epargne depuis naissance" in block
