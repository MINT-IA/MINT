"""Wave 1b Plan 04 — citationChips field on CoachChatResponse.

Tests the additive `citation_chips` field on the chat response schema +
verifies camelCase serialization (the wire-format Flutter parses).

Per wave-1b-04-AUDIT.md §3 Route (b) decision: a new top-level
`citationChips: List[CitationChipPayload]` field carries per-tool
inputs_hash + computed_at + raw_response. Internal tools (the 6 Wave 1a
tools) are filtered out of `flutter_tool_calls` upstream (see
INTERNAL_TOOL_NAMES at services/backend/app/services/coach/coach_tools.py:57),
so route (a) — enriching toolCalls — cannot work. Route (b) is the only
viable path.
"""
from app.schemas.coach_chat import CoachChatResponse


def test_response_accepts_citation_chips_field_camelcase_alias():
    """citationChips is the camelCase wire alias for the new field."""
    chip = {
        "toolName": "budget_snapshot",
        "inputsHash": "a" * 64,
        "computedAt": "2026-05-15T10:00:00Z",
        "rawResponse": {"monthlyIncome": "7500"},
    }
    response = CoachChatResponse(
        message="ok",
        citation_chips=[chip],
    )
    dumped = response.model_dump(by_alias=True)
    assert "citationChips" in dumped
    assert len(dumped["citationChips"]) == 1
    assert dumped["citationChips"][0]["toolName"] == "budget_snapshot"
    assert dumped["citationChips"][0]["inputsHash"] == "a" * 64


def test_response_default_citation_chips_is_none():
    """Legacy path: citationChips absent → None default → omitted/null on the wire."""
    response = CoachChatResponse(message="ok")
    dumped = response.model_dump(by_alias=True)
    # field exists in schema but defaults to None (camelCase key on the wire)
    assert dumped.get("citationChips") is None


def test_response_carries_all_6_wave_1a_tools():
    """Synthetic-hash adoption (Q9_DECISION) — 6 chips, one per Wave 1a tool."""
    tool_names = [
        "budget_snapshot",
        "retirement_projection",
        "cross_pillar_analysis",
        "couple_optimization",
        "cap_status",
        "retrieve_memories",
    ]
    chips = [
        {
            "toolName": name,
            "inputsHash": "b" * 64,
            "computedAt": "2026-05-15T10:00:00Z",
            "rawResponse": {"text": f"placeholder for {name}"},
        }
        for name in tool_names
    ]
    response = CoachChatResponse(message="ok", citation_chips=chips)
    dumped = response.model_dump(by_alias=True)
    assert len(dumped["citationChips"]) == 6
    rendered_names = {c["toolName"] for c in dumped["citationChips"]}
    assert rendered_names == set(tool_names)
