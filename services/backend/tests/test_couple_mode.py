"""Phase 16 -- Couple Mode Dissymetrique tests.

Covers:
    - Tool registration (save_partner_estimate, update_partner_estimate)
    - System prompt directive (COUPLE DISSYMETRIQUE)
    - Privacy guarantee: partner tools are Flutter-bound (never touch backend)
    - Routing contract: partner tools MUST NOT be in INTERNAL_TOOL_NAMES so
      they flow through external_calls to widget_renderer for SecureStorage
      persistence on device (COUP-01, COUP-04).

Run: cd services/backend && python3 -m pytest tests/test_couple_mode.py -v
"""

import inspect
from typing import Optional

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
    """Verify partner estimate tools are registered for Claude but routed to Flutter."""

    def test_save_partner_estimate_NOT_in_internal_tool_names(self):
        """save_partner_estimate MUST NOT be in INTERNAL_TOOL_NAMES.

        If it were, it would be intercepted by the backend internal-tool
        dispatcher and never reach Flutter's widget_renderer, breaking
        SecureStorage persistence on device (COUP-01).
        """
        assert "save_partner_estimate" not in INTERNAL_TOOL_NAMES

    def test_update_partner_estimate_NOT_in_internal_tool_names(self):
        """update_partner_estimate MUST NOT be in INTERNAL_TOOL_NAMES (see above)."""
        assert "update_partner_estimate" not in INTERNAL_TOOL_NAMES

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
# TestCouplePrivacyGuarantee
# ===========================================================================


class TestCouplePrivacyGuarantee:
    """Source code inspection: backend MUST NOT define a handler for partner tools.

    If a handler existed in _execute_internal_tool, the LLM tool call would be
    silently acknowledged server-side and Flutter's widget_renderer would never
    see it — defeating the on-device-only persistence contract.
    """

    def test_no_backend_handler_for_save_partner_estimate(self):
        """_execute_internal_tool source does not contain a save_partner_estimate branch."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        source = inspect.getsource(_execute_internal_tool)
        assert 'if name == "save_partner_estimate"' not in source, (
            "Backend must NOT handle save_partner_estimate. "
            "This tool is Flutter-bound (COUP-01/COUP-04)."
        )

    def test_no_backend_handler_for_update_partner_estimate(self):
        """_execute_internal_tool source does not contain an update_partner_estimate branch."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool

        source = inspect.getsource(_execute_internal_tool)
        assert 'if name == "update_partner_estimate"' not in source, (
            "Backend must NOT handle update_partner_estimate. "
            "This tool is Flutter-bound (COUP-01/COUP-04)."
        )
