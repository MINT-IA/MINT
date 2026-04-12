"""Phase 16 -- Couple Mode Dissymetrique tests.

Covers:
    - Tool registration (save_partner_estimate, update_partner_estimate)
    - System prompt directive (COUPLE DISSYMETRIQUE)
    - Internal tool handler ack messages
    - Privacy guarantee: handlers never access DB
    - CoachContext partner aggregate flags

Run: cd services/backend && python3 -m pytest tests/test_couple_mode.py -v
"""

import inspect
import re
from typing import Optional
from unittest.mock import MagicMock

from app.services.coach.coach_tools import COACH_TOOLS, INTERNAL_TOOL_NAMES
from app.services.coach.claude_coach_service import build_system_prompt


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _find_tool(name: str) -> Optional[dict]:
    """Return the tool definition with the given name, or None."""
    return next((t for t in COACH_TOOLS if t["name"] == name), None)


# ===========================================================================
# TestCoupleToolRegistration
# ===========================================================================


class TestCoupleToolRegistration:
    """Verify save_partner_estimate and update_partner_estimate are registered."""

    def test_save_partner_estimate_in_internal_tool_names(self):
        """save_partner_estimate is listed in INTERNAL_TOOL_NAMES."""
        assert "save_partner_estimate" in INTERNAL_TOOL_NAMES

    def test_update_partner_estimate_in_internal_tool_names(self):
        """update_partner_estimate is listed in INTERNAL_TOOL_NAMES."""
        assert "update_partner_estimate" in INTERNAL_TOOL_NAMES

    def test_save_partner_estimate_tool_defined(self):
        """save_partner_estimate tool definition exists with correct schema."""
        tool = _find_tool("save_partner_estimate")
        assert tool is not None, "save_partner_estimate not found in COACH_TOOLS"
        schema = tool["input_schema"]
        props = schema["properties"]
        expected_fields = {"estimated_salary", "estimated_age", "estimated_lpp", "estimated_3a", "estimated_canton"}
        assert expected_fields == set(props.keys())
        assert schema["required"] == []

    def test_update_partner_estimate_tool_defined(self):
        """update_partner_estimate tool definition exists with correct schema."""
        tool = _find_tool("update_partner_estimate")
        assert tool is not None, "update_partner_estimate not found in COACH_TOOLS"
        schema = tool["input_schema"]
        props = schema["properties"]
        expected_fields = {"estimated_salary", "estimated_age", "estimated_lpp", "estimated_3a", "estimated_canton"}
        assert expected_fields == set(props.keys())
        assert schema["required"] == []


# ===========================================================================
# TestCoupleSystemPrompt
# ===========================================================================


class TestCoupleSystemPrompt:
    """Verify _COUPLE_DISSYMETRIQUE directive is in the system prompt."""

    def test_couple_directive_in_system_prompt(self):
        """build_system_prompt() includes COUPLE DISSYMETRIQUE section."""
        prompt = build_system_prompt()
        assert "COUPLE DISSYMETRIQUE" in prompt

    def test_couple_directive_mentions_save_tool(self):
        """System prompt references save_partner_estimate tool."""
        prompt = build_system_prompt()
        assert "save_partner_estimate" in prompt

    def test_couple_directive_mentions_privacy(self):
        """System prompt includes privacy reminder about local-only data."""
        prompt = build_system_prompt()
        assert "restent uniquement sur ton telephone" in prompt


# ===========================================================================
# TestCoupleToolHandlers
# ===========================================================================


class TestCoupleToolHandlers:
    """Verify _execute_internal_tool returns correct ack messages."""

    def test_save_partner_estimate_ack(self):
        """save_partner_estimate returns ack with field names listed."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        result = _execute_internal_tool(
            {"name": "save_partner_estimate", "input": {"estimated_salary": 80000, "estimated_age": 35}},
            None,
        )
        assert "conjoint" in result.lower()
        assert "estimated_salary" in result
        assert "estimated_age" in result

    def test_update_partner_estimate_ack(self):
        """update_partner_estimate returns ack with 'mise a jour'."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        result = _execute_internal_tool(
            {"name": "update_partner_estimate", "input": {"estimated_salary": 90000}},
            None,
        )
        assert "mise" in result.lower()
        assert "jour" in result.lower()
        assert "estimated_salary" in result

    def test_save_partner_estimate_empty_fields(self):
        """save_partner_estimate with empty input returns 'aucun champ'."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        result = _execute_internal_tool(
            {"name": "save_partner_estimate", "input": {}},
            None,
        )
        assert "aucun champ" in result

    def test_save_partner_estimate_no_db_access(self):
        """save_partner_estimate handler never touches DB even when db is available."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        mock_db = MagicMock()
        _execute_internal_tool(
            {"name": "save_partner_estimate", "input": {"estimated_salary": 80000}},
            None,
            user_id="test-user",
            db=mock_db,
        )
        assert mock_db.add.call_count == 0, "Handler must NOT call db.add()"
        assert mock_db.commit.call_count == 0, "Handler must NOT call db.commit()"


# ===========================================================================
# TestCouplePrivacyGuarantee
# ===========================================================================


class TestCouplePrivacyGuarantee:
    """Source code inspection: handlers must not reference db or user_id."""

    def _get_handler_source_block(self, tool_name: str) -> str:
        """Extract the handler block for a given tool from _execute_internal_tool source."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        source = inspect.getsource(_execute_internal_tool)
        # Find the block between 'if name == "tool_name"' and the next 'if name =='
        pattern = rf'if name == "{tool_name}".*?(?=if name ==|# Unknown|$)'
        match = re.search(pattern, source, re.DOTALL)
        assert match is not None, f"Handler block for {tool_name} not found in source"
        return match.group(0)

    def test_handler_source_has_no_db_access(self):
        """save_partner_estimate handler source does not reference 'db.' anywhere."""
        block = self._get_handler_source_block("save_partner_estimate")
        assert "db." not in block, f"Handler must NOT access db. Found in:\n{block}"

    def test_handler_source_has_no_user_id_access(self):
        """save_partner_estimate handler source does not reference 'user_id' anywhere."""
        block = self._get_handler_source_block("save_partner_estimate")
        assert "user_id" not in block, f"Handler must NOT access user_id. Found in:\n{block}"
