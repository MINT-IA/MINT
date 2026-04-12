"""
Tests for Phase 14 — Commitment Devices (CMIT-01, CMIT-05, CMIT-06, LOOP-02).

Covers:
    - CommitmentDevice and PreMortemEntry model instantiation and defaults
    - Tool registration (record_commitment, save_pre_mortem, show_commitment_card)
    - System prompt directives (IMPLEMENTATION INTENTIONS, PRE-MORTEM)
    - Internal tool handler ack messages
    - Commitment memory block builder

Run: cd services/backend && python3 -m pytest tests/test_commitment_devices.py -v
"""

from datetime import datetime, timezone
from typing import Optional
from unittest.mock import MagicMock, patch

from app.models.commitment import CommitmentDevice, PreMortemEntry
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


class TestCommitmentDeviceModel:
    """CommitmentDevice SQLAlchemy model."""

    def test_commitment_model_create(self):
        """CommitmentDevice instantiates with required fields."""
        c = CommitmentDevice(
            user_id="user-123",
            when_text="Lundi matin",
            where_text="App bancaire",
            if_then_text="Si solde > 500, verser 200",
        )
        assert c.user_id == "user-123"
        assert c.when_text == "Lundi matin"
        assert c.where_text == "App bancaire"
        assert c.if_then_text == "Si solde > 500, verser 200"

    def test_commitment_model_defaults(self):
        """Status defaults to 'pending', type to 'implementation_intention', id auto-generated."""
        # SQLAlchemy Column defaults are callables applied at flush time,
        # so we verify the Column.default attribute is set correctly.
        assert CommitmentDevice.status.default is not None
        assert CommitmentDevice.status.default.arg == "pending"
        assert CommitmentDevice.type.default is not None
        assert CommitmentDevice.type.default.arg == "implementation_intention"
        assert CommitmentDevice.id.default is not None

    def test_commitment_tablename(self):
        """Table name is commitment_devices."""
        assert CommitmentDevice.__tablename__ == "commitment_devices"


class TestPreMortemEntryModel:
    """PreMortemEntry SQLAlchemy model."""

    def test_premortem_model_create(self):
        """PreMortemEntry instantiates with required fields."""
        pm = PreMortemEntry(
            user_id="user-456",
            decision_type="epl",
            user_response="Le marché immobilier pourrait baisser",
        )
        assert pm.user_id == "user-456"
        assert pm.decision_type == "epl"
        assert pm.user_response == "Le marché immobilier pourrait baisser"

    def test_premortem_model_defaults(self):
        """id auto-generated, created_at has default factory."""
        pm = PreMortemEntry(
            user_id="user-456",
            decision_type="capital_withdrawal",
            user_response="test",
        )
        assert PreMortemEntry.id.default is not None
        assert PreMortemEntry.created_at.default is not None

    def test_premortem_tablename(self):
        """Table name is pre_mortem_entries."""
        assert PreMortemEntry.__tablename__ == "pre_mortem_entries"

    def test_premortem_optional_context(self):
        """decision_context is optional (nullable)."""
        pm = PreMortemEntry(
            user_id="user-456",
            decision_type="pillar_3a_closure",
            user_response="test",
            decision_context=None,
        )
        assert pm.decision_context is None


# ===========================================================================
# Tool registration tests
# ===========================================================================


class TestCommitmentToolRegistration:
    """Verify tool registration in COACH_TOOLS and INTERNAL_TOOL_NAMES."""

    def test_record_commitment_tool_defined(self):
        """record_commitment exists in COACH_TOOLS."""
        tool = _find_tool("record_commitment")
        assert tool is not None
        assert tool["category"] == "write"
        assert "when_text" in tool["input_schema"]["properties"]
        assert "where_text" in tool["input_schema"]["properties"]
        assert "if_then_text" in tool["input_schema"]["properties"]

    def test_record_commitment_in_internal_tools(self):
        """record_commitment is in INTERNAL_TOOL_NAMES."""
        assert "record_commitment" in INTERNAL_TOOL_NAMES

    def test_save_premortem_tool_defined(self):
        """save_pre_mortem exists in COACH_TOOLS."""
        tool = _find_tool("save_pre_mortem")
        assert tool is not None
        assert tool["category"] == "write"
        assert "decision_type" in tool["input_schema"]["properties"]
        assert "user_response" in tool["input_schema"]["properties"]

    def test_save_premortem_in_internal_tools(self):
        """save_pre_mortem is in INTERNAL_TOOL_NAMES."""
        assert "save_pre_mortem" in INTERNAL_TOOL_NAMES

    def test_show_commitment_card_defined(self):
        """show_commitment_card exists in COACH_TOOLS."""
        tool = _find_tool("show_commitment_card")
        assert tool is not None
        assert tool["category"] == "read"
        assert "when_text" in tool["input_schema"]["properties"]
        assert "where_text" in tool["input_schema"]["properties"]
        assert "if_then_text" in tool["input_schema"]["properties"]

    def test_show_commitment_card_not_internal(self):
        """show_commitment_card is NOT in INTERNAL_TOOL_NAMES (Flutter-bound)."""
        assert "show_commitment_card" not in INTERNAL_TOOL_NAMES

    def test_record_commitment_required_fields(self):
        """record_commitment requires when_text, where_text, if_then_text."""
        tool = _find_tool("record_commitment")
        assert tool is not None
        required = tool["input_schema"]["required"]
        assert "when_text" in required
        assert "where_text" in required
        assert "if_then_text" in required

    def test_save_premortem_decision_type_enum(self):
        """save_pre_mortem decision_type has correct enum values."""
        tool = _find_tool("save_pre_mortem")
        assert tool is not None
        dt_prop = tool["input_schema"]["properties"]["decision_type"]
        assert set(dt_prop["enum"]) == {"epl", "capital_withdrawal", "pillar_3a_closure"}


# ===========================================================================
# System prompt directive tests
# ===========================================================================


class TestSystemPromptDirectives:
    """Verify system prompt includes commitment device directives."""

    def test_system_prompt_has_intention_directive(self):
        """build_system_prompt() output contains IMPLEMENTATION INTENTIONS."""
        prompt = build_system_prompt()
        assert "IMPLEMENTATION INTENTIONS" in prompt

    def test_system_prompt_has_premortem_directive(self):
        """build_system_prompt() output contains PRE-MORTEM."""
        prompt = build_system_prompt()
        assert "PRÉ-MORTEM" in prompt

    def test_system_prompt_intention_mentions_show_commitment_card(self):
        """Intention directive references show_commitment_card tool."""
        prompt = build_system_prompt()
        assert "show_commitment_card" in prompt

    def test_system_prompt_premortem_mentions_save_pre_mortem(self):
        """Pre-mortem directive references save_pre_mortem tool."""
        prompt = build_system_prompt()
        assert "save_pre_mortem" in prompt


# ===========================================================================
# Internal tool handler ack tests
# ===========================================================================


class TestInternalToolHandlers:
    """Verify _execute_internal_tool returns correct ack strings."""

    def test_commitment_ack_message(self):
        """_execute_internal_tool returns ack for record_commitment."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        result = _execute_internal_tool(
            tool_call={
                "name": "record_commitment",
                "input": {
                    "when_text": "Lundi matin",
                    "where_text": "App 3a",
                    "if_then_text": "Verser 200 CHF",
                },
            },
            memory_block=None,
        )
        assert "Engagement noté" in result
        assert "QUAND=Lundi matin" in result
        assert "SI-ALORS=Verser 200 CHF" in result

    def test_premortem_ack_message(self):
        """_execute_internal_tool returns ack for save_pre_mortem."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        result = _execute_internal_tool(
            tool_call={
                "name": "save_pre_mortem",
                "input": {
                    "decision_type": "epl",
                    "user_response": "Le marché pourrait baisser",
                },
            },
            memory_block=None,
        )
        assert "Pré-mortem enregistré" in result
        assert "epl" in result


# ===========================================================================
# Commitment memory block builder tests
# ===========================================================================


class TestBuildCommitmentMemoryBlock:
    """Verify _build_commitment_memory_block output."""

    def test_build_commitment_memory_block_empty(self):
        """Returns empty string when no data exists."""
        from app.api.v1.endpoints.coach_chat import _build_commitment_memory_block

        # No user_id
        assert _build_commitment_memory_block(None, None) == ""
        # No db
        assert _build_commitment_memory_block("user-1", None) == ""

    def test_build_commitment_memory_block_empty_db(self):
        """Returns empty string when DB has no commitment data."""
        from app.api.v1.endpoints.coach_chat import _build_commitment_memory_block

        mock_db = MagicMock()
        # Mock the query chain to return empty lists
        mock_query = MagicMock()
        mock_db.query.return_value = mock_query
        mock_query.filter.return_value = mock_query
        mock_query.order_by.return_value = mock_query
        mock_query.limit.return_value = mock_query
        mock_query.all.return_value = []

        result = _build_commitment_memory_block("user-1", mock_db)
        assert result == ""

    def test_build_commitment_memory_block_with_data(self):
        """Returns formatted markdown with ENGAGEMENTS and RISQUES sections."""
        from app.api.v1.endpoints.coach_chat import _build_commitment_memory_block

        mock_commitment = MagicMock()
        mock_commitment.when_text = "Lundi"
        mock_commitment.where_text = "App 3a"
        mock_commitment.if_then_text = "Verser 200"
        mock_commitment.created_at = datetime(2026, 4, 10, tzinfo=timezone.utc)
        mock_commitment.status = "pending"

        mock_premortem = MagicMock()
        mock_premortem.decision_type = "epl"
        mock_premortem.user_response = "Marché en baisse"
        mock_premortem.created_at = datetime(2026, 4, 11, tzinfo=timezone.utc)

        mock_db = MagicMock()
        mock_query = MagicMock()
        mock_db.query.return_value = mock_query
        mock_query.filter.return_value = mock_query
        mock_query.order_by.return_value = mock_query
        mock_query.limit.return_value = mock_query
        # First .all() call returns commitments, second returns pre-mortems
        mock_query.all.side_effect = [[mock_commitment], [mock_premortem]]

        result = _build_commitment_memory_block("user-1", mock_db)
        assert "ENGAGEMENTS ACTIFS" in result
        assert "Lundi" in result
        assert "App 3a" in result
        assert "Verser 200" in result
        assert "RISQUES IDENTIFIÉS" in result
        assert "epl" in result
        assert "Marché en baisse" in result

    def test_build_commitment_memory_block_db_error(self):
        """Returns empty string on DB error (graceful fallback)."""
        from app.api.v1.endpoints.coach_chat import _build_commitment_memory_block

        mock_db = MagicMock()
        mock_db.query.side_effect = Exception("DB connection error")

        result = _build_commitment_memory_block("user-1", mock_db)
        assert result == ""
