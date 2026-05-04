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


# Verified WRITE-tier handlers in coach_chat.py — those that ACTUALLY
# write to DB through the chat dispatcher. Re-verified after the
# T-52-08 close-out audit (2026-05-03) caught 3 false negatives in
# the first version: save_provenance / save_earmark / remove_earmark
# DO write to DB (db.add(ProvenanceRecord), db.add(EarmarkTag),
# db.delete(tag)) at coach_chat.py:1510-1558 — they're not ack-only
# despite the « # P14 commitment devices — ack-only handlers » comment
# (which only applied to record_commitment + save_pre_mortem).
WRITE_TIER_FIXTURES = [
    ("save_fact", {"key": "age", "value": 40}),
    ("save_insight", {"summary": "user lives in GE", "topic": "canton"}),
    ("save_provenance",
     {"product_type": "3a", "recommended_by": "mon banquier", "institution": "UBS"}),
    ("save_earmark",
     {"label": "argent de mamie", "source_description": "héritage", "amount_hint": "~50k"}),
    ("remove_earmark", {"label": "argent de mamie"}),
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
    """Hard-asserts the WRITE-tier whitelist matches what is verified by
    direct inspection of `coach_chat.py` (NOT the panel's first pass —
    several panel-listed tools are ack-only or Flutter-bound, see the
    inventory at .planning/phases/52.1-cloud-sync-actual-gating/
    BACKEND-WRITE-SURFACE.md).

    Adding a new tool that performs a real DB write inside the chat
    dispatcher requires extending BOTH `_WRITE_TIER_TOOLS` AND this
    assertion — the safety net against the « shipped a new write-tier
    handler but forgot to gate it » regression class."""
    expected = {
        "save_fact",        # writes ProfileModel.data
        "save_insight",     # writes CoachInsightRecord
        "save_provenance",  # writes ProvenanceRecord (db.add @ coach_chat.py:1510)
        "save_earmark",     # writes EarmarkTag (db.add @ coach_chat.py:1531)
        "remove_earmark",   # deletes EarmarkTag (db.delete @ coach_chat.py:1550)
    }
    assert _WRITE_TIER_TOOLS == frozenset(expected), (
        f"WRITE-tier whitelist drift detected. Expected: {expected!r} "
        f"Got: {set(_WRITE_TIER_TOOLS)!r}"
    )


@pytest.mark.parametrize(
    "tool_name",
    [
        # Read-tier tools — never affected
        "get_cap_status",
        "get_couple_optimization",
        "get_regulatory_constant",
        # Acknowledgement-only tools — return a confirmation string but
        # never write to DB. Must NOT be in the WRITE-tier whitelist
        # (gating these would block the LLM's ability to acknowledge
        # the user's intent within the conversation). Verified at
        # coach_chat.py:1482-1495 (« # P14 commitment devices — ack-only
        # handlers » applies ONLY to record_commitment + save_pre_mortem;
        # save_provenance / save_earmark / remove_earmark below them DO
        # write to DB and are gated — see test_write_tier_set_is_complete).
        "set_goal",
        "mark_step_completed",
        "save_pre_mortem",
        "record_commitment",
        # Flutter-bound tools — never reach the backend dispatcher.
        # Mobile-side gates in PR #438 cover the device-side persistence.
        "save_partner_estimate",
        "update_partner_estimate",
        "record_check_in",
    ],
)
def test_read_tier_tools_not_affected_by_persistence_consent(tool_name):
    """Tools that don't perform a DB write through the chat dispatcher
    must NOT be in the WRITE-tier whitelist (they're allowed regardless
    of sync state, OR they're handled mobile-side)."""
    assert tool_name not in _WRITE_TIER_TOOLS, (
        f"Tool {tool_name!r} should not be in WRITE_TIER "
        f"(not a backend DB writer)"
    )
