"""Phase 52.1 PR 2 — backend gating test for the chat WRITE-tier tools.

Asserts that when the chat request carries `persistence_consent=False`
(i.e. the mobile cloud-sync toggle is OFF), every WRITE-tier tool
(`save_fact`, `save_insight`, `save_pre_mortem`, `save_provenance`,
`save_earmark`, `save_partner_estimate`, `update_partner_estimate`,
`record_check_in`) is refused server-side and the LLM receives a stable
rejection marker. LLM call itself is unaffected — there is no on-device
LLM. See `.planning/decisions/2026-05-03-chat-under-cloud-sync-off.md`.

Read-tier tools (`get_*`, `set_goal`, `mark_step_completed`) are
unaffected by the gate — they can run regardless of sync state.

Run:
    cd services/backend && python3 -m pytest tests/test_coach_chat_persistence_gate.py -v
"""

import pytest

from app.api.v1.endpoints.coach_chat import (
    _execute_internal_tool,
    _PERSISTENCE_OFF_MARKER,
    _WRITE_TIER_TOOLS,
)


WRITE_TIER_FIXTURES = [
    ("save_fact", {"key": "age", "value": 40}),
    ("save_insight", {"summary": "user lives in GE", "topic": "canton"}),
    ("save_pre_mortem", {"decision_type": "buy_house"}),
    ("save_provenance", {"product_type": "3a", "recommended_by": "coach"}),
    ("save_earmark", {"label": "vacances 2027"}),
    ("save_partner_estimate", {"category": "income", "value": 80000}),
    ("update_partner_estimate", {"category": "income", "value": 85000}),
    ("record_check_in", {"month": "2026-05", "summary": "ok", "versements": 0}),
]


@pytest.mark.parametrize("tool_name, tool_input", WRITE_TIER_FIXTURES)
def test_write_tier_tool_refused_when_persistence_consent_false(
    tool_name, tool_input
):
    """With sync OFF, every WRITE-tier tool returns the rejection marker."""
    result = _execute_internal_tool(
        tool_call={"name": tool_name, "input": tool_input},
        memory_block=None,
        profile_context=None,
        user_id="test-user",
        db=None,
        persistence_consent=False,
    )
    assert result == _PERSISTENCE_OFF_MARKER, (
        f"Tool {tool_name!r} must return _PERSISTENCE_OFF_MARKER when "
        f"persistence_consent=False; got: {result!r}"
    )


def test_persistence_off_marker_contains_actionable_instruction():
    """The marker must tell the LLM what to do (acknowledge in-conversation only)."""
    marker_lower = _PERSISTENCE_OFF_MARKER.lower()
    assert "conversation" in marker_lower, (
        f"_PERSISTENCE_OFF_MARKER should instruct the LLM to acknowledge "
        f"the fact within the conversation only; got: {_PERSISTENCE_OFF_MARKER!r}"
    )
    assert "skipped" in marker_lower, (
        "marker must clearly state the write was skipped"
    )
    assert "sync" in marker_lower, (
        "marker must reference the sync-disabled cause so the LLM knows why"
    )


def test_write_tier_set_is_complete():
    """Hard-asserts the WRITE-tier whitelist matches the locked panel
    decision (`.planning/decisions/2026-05-03-chat-under-cloud-sync-off.md`).
    Adding a new write-tier tool requires explicitly extending this set
    AND this assertion — that's the safety net against the « shipped a
    new tool but forgot to gate it » regression class."""
    expected = {
        "save_fact",
        "save_insight",
        "save_pre_mortem",
        "save_provenance",
        "save_earmark",
        "save_partner_estimate",
        "update_partner_estimate",
        "record_check_in",
    }
    assert _WRITE_TIER_TOOLS == frozenset(expected), (
        f"WRITE-tier whitelist drift detected. Expected: {expected!r} "
        f"Got: {set(_WRITE_TIER_TOOLS)!r}"
    )


@pytest.mark.parametrize(
    "tool_name",
    [
        "get_cap_status",
        "get_couple_optimization",
        "get_regulatory_constant",
        "set_goal",
        "mark_step_completed",
    ],
)
def test_read_tier_tools_not_affected_by_persistence_consent(tool_name):
    """Read-tier and acknowledgement tools must NOT be in the write-tier
    whitelist (they're allowed regardless of sync state)."""
    assert tool_name not in _WRITE_TIER_TOOLS, (
        f"Tool {tool_name!r} should not be in WRITE_TIER (not a PII writer)"
    )
