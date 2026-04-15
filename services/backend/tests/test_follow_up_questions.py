"""
Contract tests for backend-piloted follow_up_questions (Phase D).

Covers:
1. CoachChatResponse / AnonymousChatResponse schema cap at 2 items.
2. The anonymous prompt carries the <followups> directive.
3. extract_follow_ups() parses the block, strips it from the text, and
   fails open on malformed input.
4. The coach-chat prompt (claude_coach_service) carries the suggest_followups
   directive so Claude knows to call the tool.
5. `suggest_followups` is registered as an internal tool and declared in
   the COACH_TOOLS list.
"""
from __future__ import annotations

import pytest


# ---------------------------------------------------------------------------
# Schema caps
# ---------------------------------------------------------------------------


def test_coach_chat_response_caps_follow_ups_at_two():
    from app.schemas.coach_chat import CoachChatResponse

    resp = CoachChatResponse(
        message="Voici ta situation.",
        follow_up_questions=["q1", "q2", "q3", "q4"],
    )
    assert resp.follow_up_questions == ["q1", "q2"]


def test_coach_chat_response_strips_empty_follow_ups():
    from app.schemas.coach_chat import CoachChatResponse

    resp = CoachChatResponse(
        message="ok",
        follow_up_questions=["  ", "réel", "", "autre"],
    )
    assert resp.follow_up_questions == ["réel", "autre"]


def test_coach_chat_response_defaults_to_empty_list():
    from app.schemas.coach_chat import CoachChatResponse

    resp = CoachChatResponse(message="ok")
    assert resp.follow_up_questions == []


def test_anonymous_chat_response_caps_follow_ups_at_two():
    from app.schemas.anonymous_chat import AnonymousChatResponse

    resp = AnonymousChatResponse(
        message="ok",
        messages_remaining=2,
        follow_up_questions=["q1", "q2", "q3"],
    )
    assert resp.follow_up_questions == ["q1", "q2"]


def test_anonymous_chat_response_defaults_to_empty_list():
    from app.schemas.anonymous_chat import AnonymousChatResponse

    resp = AnonymousChatResponse(message="ok", messages_remaining=2)
    assert resp.follow_up_questions == []


# ---------------------------------------------------------------------------
# Prompt directives
# ---------------------------------------------------------------------------


def test_anonymous_prompt_contains_followups_directive():
    from app.api.v1.endpoints.anonymous_chat import build_discovery_system_prompt

    prompt = build_discovery_system_prompt()
    assert "<followups>" in prompt
    assert "</followups>" in prompt
    # The prompt must forbid reformulating the user's own question.
    assert "reformuler" in prompt.lower()


def test_coach_system_prompt_contains_suggest_followups_directive():
    from app.services.coach.claude_coach_service import build_system_prompt

    prompt = build_system_prompt()
    assert "suggest_followups" in prompt


# ---------------------------------------------------------------------------
# Parser (anonymous path, tools=None)
# ---------------------------------------------------------------------------


def test_extract_follow_ups_happy_path():
    from app.api.v1.endpoints.anonymous_chat import extract_follow_ups

    raw = (
        "Voici ta réponse.\n"
        '<followups>["Ça vaut le coup de racheter du LPP ?", "Et le 3a ?"]</followups>'
    )
    cleaned, qs = extract_follow_ups(raw)
    assert cleaned == "Voici ta réponse."
    assert qs == ["Ça vaut le coup de racheter du LPP ?", "Et le 3a ?"]


def test_extract_follow_ups_caps_at_two():
    from app.api.v1.endpoints.anonymous_chat import extract_follow_ups

    raw = 'Texte.\n<followups>["a","b","c","d"]</followups>'
    _, qs = extract_follow_ups(raw)
    assert qs == ["a", "b"]


def test_extract_follow_ups_missing_block_returns_empty():
    from app.api.v1.endpoints.anonymous_chat import extract_follow_ups

    cleaned, qs = extract_follow_ups("Juste du texte, pas de bloc.")
    assert cleaned == "Juste du texte, pas de bloc."
    assert qs == []


def test_extract_follow_ups_malformed_json_fails_open():
    from app.api.v1.endpoints.anonymous_chat import extract_follow_ups

    # Well-formed block shape but invalid JSON inside: block IS stripped,
    # follow_ups empty on parse failure.
    raw = 'Texte.\n<followups>[not json,]</followups>'
    cleaned, qs = extract_follow_ups(raw)
    assert "<followups>" not in cleaned
    assert qs == []


def test_extract_follow_ups_unterminated_block_fails_open():
    from app.api.v1.endpoints.anonymous_chat import extract_follow_ups

    # No closing `]` inside the tags — regex can't match. Fail-open: text
    # returned unchanged, follow_ups empty.
    raw = "Texte.\n<followups>[not json</followups>"
    cleaned, qs = extract_follow_ups(raw)
    assert cleaned == raw
    assert qs == []


def test_extract_follow_ups_non_list_payload_fails_open():
    from app.api.v1.endpoints.anonymous_chat import extract_follow_ups

    # JSON object, not array. Must fail open.
    raw = 'Texte.\n<followups>{"questions": ["a"]}</followups>'
    # Regex requires `[...]` — should not match at all.
    cleaned, qs = extract_follow_ups(raw)
    assert qs == []
    # Block wasn't `[...]`, so it isn't stripped either.
    assert "<followups>" in cleaned or cleaned.startswith("Texte")


def test_extract_follow_ups_filters_non_string_items():
    from app.api.v1.endpoints.anonymous_chat import extract_follow_ups

    raw = 'Texte.\n<followups>[1, "vraie question", null]</followups>'
    _, qs = extract_follow_ups(raw)
    assert qs == ["vraie question"]


# ---------------------------------------------------------------------------
# Tool registration (coach-chat path)
# ---------------------------------------------------------------------------


def test_suggest_followups_is_internal_tool():
    from app.services.coach.coach_tools import INTERNAL_TOOL_NAMES

    assert "suggest_followups" in INTERNAL_TOOL_NAMES


def test_suggest_followups_declared_in_coach_tools():
    from app.services.coach.coach_tools import COACH_TOOLS

    names = [t.get("name") for t in COACH_TOOLS]
    assert "suggest_followups" in names
    tool = next(t for t in COACH_TOOLS if t.get("name") == "suggest_followups")
    schema = tool["input_schema"]
    assert "questions" in schema["properties"]
    assert schema["properties"]["questions"]["type"] == "array"
    assert schema["properties"]["questions"]["maxItems"] == 2
    assert schema["required"] == ["questions"]


# ---------------------------------------------------------------------------
# Agent-loop inline capture (covers coach_chat.py lines 1545-1552 + 1607-1611)
# ---------------------------------------------------------------------------
#
# The capture lives INSIDE `_run_agent_loop` so we exercise it end-to-end via a
# stubbed orchestrator that yields the exact tool_use shape Claude would emit.
# This locks down the contract : questions accumulate across iterations, are
# trimmed to 160 chars, deduped, and capped at 2.
# ---------------------------------------------------------------------------


import asyncio


class _StubOrchestrator:
    """Minimal orchestrator that replays pre-canned responses iteration by
    iteration.  Matches the narrow interface `_run_agent_loop` consumes."""

    def __init__(self, responses):
        self._responses = list(responses)
        self.calls = 0

    async def query(self, **kwargs):  # noqa: ANN001 — duck-typed
        self.calls += 1
        if self._responses:
            return self._responses.pop(0)
        # Exhaustion — return a benign final response so the loop exits
        # cleanly instead of raising. Mirrors Claude's end_turn on
        # follow-up iterations that add nothing new.
        return {
            "answer": "",
            "tool_calls": [],
            "tokens_used": 0,
            "sources": [],
            "disclaimers": [],
        }


def _make_tool_call(name, questions):
    return {"name": name, "input": {"questions": questions}}


def _run_loop_sync(orchestrator):
    from app.api.v1.endpoints.coach_chat import _run_agent_loop

    return asyncio.run(
        _run_agent_loop(
            orchestrator=orchestrator,
            question="Salut, peux-tu me préparer un plan retraite ?",
            api_key="test",
            provider="claude",
            model=None,
            profile_context={},
            language="fr",
            memory_block=None,
            system_prompt="Tu es un coach. Appelle suggest_followups si pertinent.",
            user_id=None,
            db=None,
            conversation_history=None,
        )
    )


def test_agent_loop_captures_suggest_followups_inputs():
    """Lines 1545-1552 — the `suggest_followups` tool payload is captured
    into `follow_up_questions` and never reinjected as text."""
    orchestrator = _StubOrchestrator([
        {
            "answer": "Voici ton angle d'attaque sur la retraite.",
            "tool_calls": [
                _make_tool_call(
                    "suggest_followups",
                    ["Faut-il racheter du LPP ?", "Et le 3a dans ce plan ?"],
                ),
            ],
            "tokens_used": 42,
            "sources": [],
            "disclaimers": [],
        },
    ])

    result = _run_loop_sync(orchestrator)

    assert result["follow_up_questions"] == [
        "Faut-il racheter du LPP ?",
        "Et le 3a dans ce plan ?",
    ]
    # Internal tool: never forwarded to Flutter.
    assert result["tool_calls"] in (None, [])


def test_agent_loop_follow_ups_dedup_and_cap_at_two():
    """Lines 1607-1611 — duplicates across iterations collapse; the cap
    holds even if Claude calls the tool multiple times with overlap."""
    orchestrator = _StubOrchestrator([
        {
            "answer": "Analyse intermédiaire.",
            "tool_calls": [
                _make_tool_call("suggest_followups", ["Question A", "Question A"]),
            ],
            "tokens_used": 10,
            "sources": [],
            "disclaimers": [],
        },
        {
            "answer": "Réponse finale.",
            "tool_calls": [
                _make_tool_call(
                    "suggest_followups",
                    ["Question A", "Question B", "Question C"],
                ),
            ],
            "tokens_used": 10,
            "sources": [],
            "disclaimers": [],
        },
        {
            "answer": "Wrap-up.",
            "tool_calls": [],
            "tokens_used": 5,
            "sources": [],
            "disclaimers": [],
        },
    ])

    result = _run_loop_sync(orchestrator)

    # Dedup + cap at 2; the extra "Question C" is silently dropped.
    assert result["follow_up_questions"] == ["Question A", "Question B"]


def test_agent_loop_truncates_long_follow_up_at_160_chars():
    """Lines 1548-1551 — oversized questions are truncated to 160 chars."""
    long_q = "Q" * 250
    orchestrator = _StubOrchestrator([
        {
            "answer": "Texte.",
            "tool_calls": [_make_tool_call("suggest_followups", [long_q])],
            "tokens_used": 5,
            "sources": [],
            "disclaimers": [],
        },
    ])

    result = _run_loop_sync(orchestrator)

    assert len(result["follow_up_questions"]) == 1
    assert len(result["follow_up_questions"][0]) == 160


def test_agent_loop_rejects_non_string_follow_up_items():
    """Lines 1546-1551 — defensive: non-string items in the LLM payload
    must be skipped silently."""
    orchestrator = _StubOrchestrator([
        {
            "answer": "Texte.",
            "tool_calls": [
                {
                    "name": "suggest_followups",
                    "input": {"questions": [1, "vraie question", None, "autre"]},
                },
            ],
            "tokens_used": 5,
            "sources": [],
            "disclaimers": [],
        },
    ])

    result = _run_loop_sync(orchestrator)

    assert result["follow_up_questions"] == ["vraie question", "autre"]


def test_agent_loop_ignores_malformed_suggest_followups_payload():
    """Lines 1544-1547 — when `questions` is missing or not a list, the
    capture block must no-op instead of crashing."""
    orchestrator = _StubOrchestrator([
        {
            "answer": "Texte.",
            # input.questions is a string, not a list — defensive path.
            "tool_calls": [
                {"name": "suggest_followups", "input": {"questions": "not a list"}},
            ],
            "tokens_used": 5,
            "sources": [],
            "disclaimers": [],
        },
    ])

    result = _run_loop_sync(orchestrator)

    assert result["follow_up_questions"] == []


def test_agent_loop_empty_when_tool_never_called():
    """Regression guard — a conversation without `suggest_followups` must
    yield an empty list, never None, never any leaked state."""
    orchestrator = _StubOrchestrator([
        {
            "answer": "Réponse sans relance.",
            "tool_calls": [],
            "tokens_used": 5,
            "sources": [],
            "disclaimers": [],
        },
    ])

    result = _run_loop_sync(orchestrator)

    assert result["follow_up_questions"] == []
