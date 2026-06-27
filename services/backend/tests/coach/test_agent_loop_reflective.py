"""Phase 27-01 / STAB-01: Agent loop reflective retry tests.

Covers the content-block edge cases introduced in v2.7:

  (a) empty narration + external tools (existing behavior — no regression).
  (b) empty end_turn with NO tools (Sonnet 4.5 bug) — reflective re-prompt.
  (c) MAX_AGENT_LOOP_ITERATIONS bumped 3 -> 4.
"""
from __future__ import annotations


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
async def test_empty_end_turn_exhaustion_returns_degraded_fallback():
    """Repeated empty end_turn must never ship as a 200 response with empty text."""
    orchestrator = _MockOrchestrator([
        {"answer": "", "sources": [], "disclaimers": [], "tokens_used": 25}
        for _ in range(cc.MAX_AGENT_LOOP_ITERATIONS)
    ])

    result = await cc._run_agent_loop(
        orchestrator=orchestrator,
        question="Comment réduire mes impôts ?",
        api_key="sk-test",
        provider="claude",
        model="claude-sonnet-4-5-20250929",
        profile_context={"canton": "VD", "lpp_buyback_room_chf": 12000},
        memory_block=None,
        language="fr",
        system_prompt="test-prompt",
        user_id="user-3",
        db=None,
        conversation_history=None,
    )

    assert result["answer"].strip()
    assert "réponse fiable" in result["answer"]
    assert result["degraded"] is True
    assert len(orchestrator.calls) == cc.MAX_AGENT_LOOP_ITERATIONS
    assert all(
        call["question"] == cc._REPROMPT_EMPTY_END_TURN
        for call in orchestrator.calls[1:]
    )


@pytest.mark.asyncio
async def test_high_token_internal_tool_use_still_reaches_text_answer():
    """High input-token tool_use turns must not be cut before tool execution."""
    high_token_count = max(cc.MAX_REQUEST_TOKENS, cc.MAX_AGENT_LOOP_TOKENS) + 1
    orchestrator = _MockOrchestrator([
        {
            "answer": "",
            "sources": [],
            "disclaimers": [],
            "tokens_used": high_token_count,
            "tool_calls": [
                {
                    "name": "get_regulatory_constant",
                    "input": {"key": "pillar3a.max_with_lpp"},
                },
            ],
        },
        {
            "answer": "Le plafond 3a 2026 avec LPP est 7'258 CHF.",
            "sources": [],
            "disclaimers": [],
            "tokens_used": 120,
        },
    ])

    result = await cc._run_agent_loop(
        orchestrator=orchestrator,
        question="Quel est le plafond legal 3a 2026 avec LPP ?",
        api_key="sk-test",
        provider="claude",
        model="claude-sonnet-4-5-20250929",
        profile_context={"age": 33, "has_2nd_pillar": True},
        memory_block=None,
        language="fr",
        system_prompt="test-prompt",
        user_id="user-4",
        db=None,
        conversation_history=None,
    )

    assert result["answer"] == "Le plafond 3a 2026 avec LPP est 7'258 CHF."
    assert len(orchestrator.calls) == 2
    assert "Résultats outils internes" in orchestrator.calls[1]["question"]
    assert "get_regulatory_constant" in orchestrator.calls[1]["question"]


@pytest.mark.asyncio
async def test_cumulative_token_budget_appends_note_to_partial_answer(monkeypatch):
    """Cumulative cap preserves a partial answer instead of replacing it."""
    monkeypatch.setattr(cc, "MAX_AGENT_LOOP_TOKENS", 100)
    monkeypatch.setattr(cc, "MAX_REQUEST_TOKENS", 10_000)
    orchestrator = _MockOrchestrator([
        {
            "answer": "Je vérifie ta mémoire.",
            "sources": [],
            "disclaimers": [],
            "tokens_used": 60,
            "tool_calls": [
                {"name": "retrieve_memories", "input": {"topic": "3a"}},
            ],
        },
        {
            "answer": "Le plafond 3a dépend de ton affiliation LPP.",
            "sources": [],
            "disclaimers": [],
            "tokens_used": 60,
            "tool_calls": [
                {"name": "retrieve_memories", "input": {"topic": "lpp"}},
            ],
        },
    ])

    result = await cc._run_agent_loop(
        orchestrator=orchestrator,
        question="Quel plafond 3a pour moi ?",
        api_key="sk-test",
        provider="claude",
        model="claude-sonnet-4-5-20250929",
        profile_context={"has_2nd_pillar": True},
        memory_block="3a: plafond à vérifier",
        language="fr",
        system_prompt="test-prompt",
        user_id="user-5",
        db=None,
        conversation_history=None,
    )

    assert len(orchestrator.calls) == 2
    assert result["answer"].startswith("Le plafond 3a dépend")
    assert "certaines informations" in result["answer"]


@pytest.mark.asyncio
async def test_cumulative_token_budget_empty_answer_returns_degraded_fallback(monkeypatch):
    """Cumulative cap must not return message='' after empty end_turn retries."""
    monkeypatch.setattr(cc, "MAX_AGENT_LOOP_TOKENS", 100)
    monkeypatch.setattr(cc, "MAX_REQUEST_TOKENS", 10_000)
    orchestrator = _MockOrchestrator([
        {
            "answer": "",
            "sources": [],
            "disclaimers": [],
            "tokens_used": 120,
        },
    ])

    result = await cc._run_agent_loop(
        orchestrator=orchestrator,
        question="Quel plafond 3a pour moi ?",
        api_key="sk-test",
        provider="claude",
        model="claude-sonnet-4-5-20250929",
        profile_context={"has_2nd_pillar": True},
        memory_block=None,
        language="fr",
        system_prompt="test-prompt",
        user_id="user-6",
        db=None,
        conversation_history=None,
    )

    assert len(orchestrator.calls) == 1
    assert result["answer"] == cc._EMPTY_AGENT_LOOP_FALLBACK_FR
    assert result["degraded"] is True


@pytest.mark.asyncio
async def test_request_token_budget_empty_no_tool_returns_degraded_fallback():
    """Per-request cap also fails closed when Claude returns no text and no tool."""
    orchestrator = _MockOrchestrator([
        {
            "answer": "",
            "sources": [],
            "disclaimers": [],
            "tokens_used": cc.MAX_REQUEST_TOKENS,
        },
    ])

    result = await cc._run_agent_loop(
        orchestrator=orchestrator,
        question="Quel plafond 3a pour moi ?",
        api_key="sk-test",
        provider="claude",
        model="claude-sonnet-4-5-20250929",
        profile_context={"has_2nd_pillar": True},
        memory_block=None,
        language="fr",
        system_prompt="test-prompt",
        user_id="user-7",
        db=None,
        conversation_history=None,
    )

    assert len(orchestrator.calls) == 1
    assert result["answer"] == cc._EMPTY_AGENT_LOOP_FALLBACK_FR
    assert result["degraded"] is True


@pytest.mark.asyncio
async def test_reprompt_constants_are_module_level():
    """Re-prompt strings are constants, not magic inline strings."""
    assert cc._REPROMPT_EMPTY_NARRATION
    assert cc._REPROMPT_EMPTY_END_TURN
    assert cc._REPROMPT_EMPTY_NARRATION != cc._REPROMPT_EMPTY_END_TURN
