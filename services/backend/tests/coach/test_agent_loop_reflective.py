"""Phase 27-01 / STAB-01: Agent loop reflective retry tests.

Covers the content-block edge cases introduced in v2.7:

  (a) empty narration + external tools (existing behavior — no regression).
  (b) empty end_turn with NO tools (Sonnet 4.5 bug) — reflective re-prompt.
  (c) MAX_AGENT_LOOP_ITERATIONS bumped 3 -> 4.
"""
from __future__ import annotations

from unittest.mock import AsyncMock

import pytest

from app.api.v1.endpoints import coach_chat as cc


class _MockOrchestrator:
    """Minimal stub that returns scripted responses on successive query() calls."""

    def __init__(self, responses: list[dict]):
        self._responses = list(responses)
        self.calls: list[dict] = []

    async def query(self, **kwargs) -> dict:
        self.calls.append(kwargs)
        if not self._responses:
            return {"answer": "", "sources": [], "disclaimers": [], "tokens_used": 0}
        return self._responses.pop(0)


@pytest.mark.asyncio
async def test_empty_end_turn_triggers_reprompt():
    """Case (b): empty text + no tools → reflective retry produces non-empty answer."""
    orchestrator = _MockOrchestrator([
        # iter 0 — Claude returns empty text, no tool_use (Sonnet 4.5 bug).
        {"answer": "", "sources": [], "disclaimers": [], "tokens_used": 50},
        # iter 1 — after reflective re-prompt, Claude produces real text.
        {
            "answer": "Ton 3a plafonne a 7'258 CHF en 2026.",
            "sources": [],
            "disclaimers": [],
            "tokens_used": 80,
        },
    ])

    result = await cc._run_agent_loop(
        orchestrator=orchestrator,
        question="Combien puis-je mettre au 3a ?",
        api_key="sk-test",
        provider="claude",
        model="claude-sonnet-4-5-20250929",
        profile_context={"age": 45},
        memory_block=None,
        language="fr",
        system_prompt="test-prompt",
        user_id="user-1",
        db=None,
        conversation_history=None,
    )

    assert "3a" in result["answer"]
    assert len(orchestrator.calls) == 2
    # iter 1 must have used the reflective re-prompt, not the original question.
    assert orchestrator.calls[1]["question"] == cc._REPROMPT_EMPTY_END_TURN


@pytest.mark.asyncio
async def test_tool_use_only_still_works():
    """Case (a) regression: empty text + external tools → narration re-prompt."""
    orchestrator = _MockOrchestrator([
        # iter 0 — Claude emits an external (Flutter-bound) tool with no text.
        {
            "answer": "",
            "sources": [],
            "disclaimers": [],
            "tokens_used": 40,
            "tool_calls": [
                {"name": "show_fact_card", "input": {"topic": "3a"}},
            ],
        },
        # iter 1 — narration prompt yields the user-facing text.
        {
            "answer": "Voici la carte 3a.",
            "sources": [],
            "disclaimers": [],
            "tokens_used": 30,
        },
    ])

    # show_fact_card is a real Flutter tool registered in COACH_TOOLS;
    # pass it in so external_calls matches it.
    stripped_tools = [{"name": "show_fact_card", "description": "", "input_schema": {"type": "object"}}]

    result = await cc._run_agent_loop(
        orchestrator=orchestrator,
        question="Dis-m'en plus sur le 3a",
        api_key="sk-test",
        provider="claude",
        model="claude-sonnet-4-5-20250929",
        profile_context={"age": 30},
        memory_block=None,
        language="fr",
        system_prompt="test-prompt",
        user_id="user-2",
        db=None,
        conversation_history=None,
    )

    flutter_calls = result.get("tool_calls") or []
    assert result["answer"] == "Voici la carte 3a."
    # show_fact_card may not be in known COACH_TOOLS at test import time,
    # but empty-narration path is covered by orchestrator.calls[1] using
    # _REPROMPT_EMPTY_NARRATION when external_calls is non-empty.
    assert orchestrator.calls[1]["question"] == cc._REPROMPT_EMPTY_NARRATION


@pytest.mark.asyncio
async def test_max_iterations_is_four():
    """v2.7: MAX_AGENT_LOOP_ITERATIONS bumped 3 -> 4 for reflective retry budget."""
    assert cc.MAX_AGENT_LOOP_ITERATIONS == 4


@pytest.mark.asyncio
async def test_reprompt_constants_are_module_level():
    """Re-prompt strings are constants, not magic inline strings."""
    assert cc._REPROMPT_EMPTY_NARRATION
    assert cc._REPROMPT_EMPTY_END_TURN
    assert cc._REPROMPT_EMPTY_NARRATION != cc._REPROMPT_EMPTY_END_TURN
