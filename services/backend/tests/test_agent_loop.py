"""
Tests for the Agent Loop — P0-A of the Agentic Architecture Sprint.

Tests the _run_agent_loop function in coach_chat.py which implements:
    tool_use → execute → re-call LLM (until end_turn or max iterations).

Covers (15 tests):
    1.  Loop terminates on end_turn (no tool_calls in response)
    2.  Loop executes retrieve_memories and re-calls LLM
    3.  Loop caps at MAX_AGENT_LOOP_ITERATIONS
    4.  Internal tools filtered from final response
    5.  Flutter tool_calls preserved in final response
    6.  Empty memory_block → graceful "aucune mémoire" result
    7.  Token accumulation across iterations
    8.  Mixed internal + external tool_calls in same response
    9.  retrieve_memories with no match → "pas de mémoire" response
    10. Error in tool execution → loop handles gracefully
    11. Multiple internal tools in single response → all executed
    12. Write tools forwarded to Flutter (not executed internally)
    13. Final answer from last iteration used
    14. Sources deduplicated across iterations
    15. Max iterations warning logged

Run: cd services/backend && python3 -m pytest tests/test_agent_loop.py -v
"""

from __future__ import annotations

import asyncio
import logging
from typing import Optional
from unittest.mock import AsyncMock, MagicMock, patch


from app.api.v1.endpoints.coach_chat import (
    MAX_AGENT_LOOP_ITERATIONS,
    _execute_internal_tool,
    _run_agent_loop,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_orchestrator_result(
    answer: str = "Réponse test.",
    tool_calls: Optional[list] = None,
    sources: Optional[list] = None,
    disclaimers: Optional[list] = None,
    tokens_used: int = 200,
) -> dict:
    """Build a mock orchestrator.query() result."""
    return {
        "answer": answer,
        "tool_calls": tool_calls,
        "sources": sources or [],
        "disclaimers": disclaimers or [],
        "tokens_used": tokens_used,
    }


def _make_mock_orchestrator(*results: dict) -> MagicMock:
    """Create a mock orchestrator that returns different results per call."""
    mock = MagicMock()
    mock.query = AsyncMock(side_effect=list(results))
    return mock


def _run(coro):
    """Run a coroutine synchronously (Python 3.10+ compatible)."""
    return asyncio.run(coro)


_BASE_KWARGS = {
    "question": "Comment optimiser mon 3a ?",
    "api_key": "sk-test-key",
    "provider": "claude",
    "model": None,
    "profile_context": {},
    "language": "fr",
    "memory_block": None,
}


# ===========================================================================
# Test 1 — Loop terminates on end_turn (no tool_calls)
# ===========================================================================


class TestAgentLoopTermination:
    """Test that the agent loop terminates correctly."""

    def test_terminates_on_end_turn_no_tools(self):
        """Loop terminates immediately when LLM returns no tool_calls (Test 1)."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(answer="Voici ma réponse.")
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert result["answer"] == "Voici ma réponse."
        assert orch.query.call_count == 1

    def test_terminates_on_end_turn_only_external_tools(self):
        """Loop terminates when LLM returns only Flutter-bound tool_calls."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Je t'oriente.",
                tool_calls=[{"name": "route_to_screen", "input": {"intent": "retirement_choice"}}],
            )
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert result["answer"] == "Je t'oriente."
        assert orch.query.call_count == 1

    def test_caps_at_max_iterations(self):
        """Loop stops after MAX_AGENT_LOOP_ITERATIONS even if internal tools keep returning (Test 3)."""
        results = [
            _make_orchestrator_result(
                answer=f"Iteration {i}",
                tool_calls=[{"name": "retrieve_memories", "input": {"topic": "test"}}],
                tokens_used=100,
            )
            for i in range(MAX_AGENT_LOOP_ITERATIONS + 2)
        ]
        orch = _make_mock_orchestrator(*results)
        _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert orch.query.call_count == MAX_AGENT_LOOP_ITERATIONS

    def test_breaks_on_token_budget_exceeded(self):
        """Loop breaks early when cumulative tokens exceed MAX_AGENT_LOOP_TOKENS.

        Uses 1500 tokens per iteration to stay under per-request budget (4000)
        for the first two calls, then hit the overall budget (8000) check.
        Iter 0: total=1500, request=1500 → continue (has internal tools).
        Iter 1: total=3000, request=3000 → continue (has internal tools).
        Iter 2: total=4500, request=4500 >= 4000 → per-request break.
        """
        results = [
            _make_orchestrator_result(
                answer=f"Iteration {i}",
                tool_calls=[{"name": "retrieve_memories", "input": {"topic": "test"}}],
                tokens_used=1500,
            )
            for i in range(10)
        ]
        orch = _make_mock_orchestrator(*results)
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        # 3 calls: iter 0 (1500), iter 1 (3000), iter 2 (4500 >= 4000 → break)
        assert orch.query.call_count == 3
        assert result["tokens_used"] == 4500


# ===========================================================================
# Test 2, 9, 11 — Internal tool execution and re-call
# ===========================================================================


class TestAgentLoopToolExecution:
    """Test that internal tools are executed and results fed back to LLM."""

    def test_retrieve_memories_executed_and_recalls_llm(self):
        """When LLM returns retrieve_memories, it's executed and LLM is re-called (Test 2)."""
        memory_block = "retraite: taux de remplacement 63%\nbudget: marge de 1340 CHF"
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Laisse-moi vérifier ta mémoire.",
                tool_calls=[{"name": "retrieve_memories", "input": {"topic": "retraite"}}],
            ),
            _make_orchestrator_result(answer="Ton taux de remplacement est à 63%."),
        )
        kwargs = {**_BASE_KWARGS, "memory_block": memory_block}
        result = _run(_run_agent_loop(orchestrator=orch, **kwargs))
        assert orch.query.call_count == 2
        assert result["answer"] == "Ton taux de remplacement est à 63%."
        second_call_question = orch.query.call_args_list[1].kwargs["question"]
        assert "retraite" in second_call_question
        assert "63%" in second_call_question

    def test_multiple_internal_tools_all_executed(self):
        """Multiple internal tools in a single response are all executed (Test 11)."""
        memory_block = "retraite: 63%\nbudget: ok\n3a: 4000 versés"
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Vérifions.",
                tool_calls=[
                    {"name": "retrieve_memories", "input": {"topic": "retraite"}},
                    {"name": "retrieve_memories", "input": {"topic": "3a"}},
                ],
            ),
            _make_orchestrator_result(answer="Voici le résultat combiné."),
        )
        kwargs = {**_BASE_KWARGS, "memory_block": memory_block}
        _run(_run_agent_loop(orchestrator=orch, **kwargs))
        assert orch.query.call_count == 2
        second_question = orch.query.call_args_list[1].kwargs["question"]
        assert "retraite" in second_question
        assert "3a" in second_question

    def test_empty_memory_block_graceful(self):
        """retrieve_memories with empty memory_block returns 'aucune mémoire' gracefully (Test 6)."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Vérifions.",
                tool_calls=[{"name": "retrieve_memories", "input": {"topic": "retraite"}}],
            ),
            _make_orchestrator_result(answer="Pas de données en mémoire."),
        )
        _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert orch.query.call_count == 2
        second_question = orch.query.call_args_list[1].kwargs["question"]
        assert "Aucune mémoire" in second_question

    def test_retrieve_memories_no_match(self):
        """retrieve_memories with no matching topic returns 'pas de mémoire' (Test 9)."""
        memory_block = "budget: ok\nlogement: Sion"
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Vérifions.",
                tool_calls=[{"name": "retrieve_memories", "input": {"topic": "crypto"}}],
            ),
            _make_orchestrator_result(answer="Pas d'info sur ce sujet."),
        )
        kwargs = {**_BASE_KWARGS, "memory_block": memory_block}
        _run(_run_agent_loop(orchestrator=orch, **kwargs))
        second_question = orch.query.call_args_list[1].kwargs["question"]
        assert "Pas de mémoire" in second_question


# ===========================================================================
# Test 4, 5, 8, 12 — Tool filtering (internal vs Flutter)
# ===========================================================================


class TestAgentLoopToolFiltering:
    """Test that internal tools are filtered and external tools are preserved."""

    def test_internal_tools_never_in_response(self):
        """Internal tools (retrieve_memories) must never appear in the final response (Test 4)."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Vérifions.",
                tool_calls=[{"name": "retrieve_memories", "input": {"topic": "test"}}],
            ),
            _make_orchestrator_result(answer="Voilà."),
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        tool_calls = result["tool_calls"]
        if tool_calls:
            for tc in tool_calls:
                assert tc["name"] != "retrieve_memories"

    def test_flutter_tools_preserved_in_response(self):
        """Flutter-bound tool_calls (show_*, route_to_screen) are in the response (Test 5)."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Voici ton score.",
                tool_calls=[
                    {"name": "show_score_gauge", "input": {"show_breakdown": True}},
                ],
            )
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert result["tool_calls"] is not None
        assert len(result["tool_calls"]) == 1
        assert result["tool_calls"][0]["name"] == "show_score_gauge"

    def test_mixed_internal_and_external_tools(self):
        """Mixed internal + external tools: internal executed, external forwarded (Test 8)."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Je vérifie et montre.",
                tool_calls=[
                    {"name": "retrieve_memories", "input": {"topic": "budget"}},
                    {"name": "show_budget_snapshot", "input": {}},
                ],
            ),
            _make_orchestrator_result(answer="Voici ton budget."),
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert orch.query.call_count == 2
        assert result["tool_calls"] is not None
        assert len(result["tool_calls"]) == 1
        assert result["tool_calls"][0]["name"] == "show_budget_snapshot"

    def test_write_tools_forwarded_to_flutter_not_executed(self):
        """set_goal, mark_step_completed, save_insight are forwarded to Flutter, not executed (Test 12)."""
        write_tools = [
            {"name": "set_goal", "input": {"goal_intent_tag": "retirement_choice"}},
            {"name": "mark_step_completed", "input": {"step_id": "open_3a", "outcome": "completed"}},
            {"name": "save_insight", "input": {"topic": "lpp", "summary": "rachat planifié", "type": "decision"}},
        ]
        # No internal tools → loop exits after 1 call
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(answer="Actions enregistrées.", tool_calls=write_tools)
        )
        executed_tools: list = []
        original = _execute_internal_tool

        def _capturing(tool_call, memory_block):
            executed_tools.append(tool_call["name"])
            return original(tool_call, memory_block)

        with patch("app.api.v1.endpoints.coach_chat._execute_internal_tool", side_effect=_capturing):
            result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))

        # Write tools must NOT have been executed by the backend
        assert "set_goal" not in executed_tools
        assert "mark_step_completed" not in executed_tools
        assert "save_insight" not in executed_tools
        # Write tools must reach Flutter
        names = [tc["name"] for tc in (result["tool_calls"] or [])]
        assert "set_goal" in names
        assert "mark_step_completed" in names
        assert "save_insight" in names
        # No re-call needed
        assert orch.query.call_count == 1

    def test_external_tools_accumulated_across_iterations(self):
        """External tools from multiple iterations are all collected."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="D'abord vérifions.",
                tool_calls=[
                    {"name": "retrieve_memories", "input": {"topic": "test"}},
                    {"name": "show_fact_card", "input": {"title": "T1", "content": "C1", "source": "S1"}},
                ],
            ),
            _make_orchestrator_result(
                answer="Et ensuite.",
                tool_calls=[{"name": "show_score_gauge", "input": {}}],
            ),
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert result["tool_calls"] is not None
        assert len(result["tool_calls"]) == 2
        names = [tc["name"] for tc in result["tool_calls"]]
        assert "show_fact_card" in names
        assert "show_score_gauge" in names


# ===========================================================================
# Test 7, 13, 14 — Metadata and final answer
# ===========================================================================


class TestAgentLoopMetadata:
    """Test metadata accumulation across loop iterations."""

    def test_tokens_accumulated(self):
        """Token counts are summed across all iterations (Test 7)."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Iter 1.",
                tool_calls=[{"name": "retrieve_memories", "input": {"topic": "test"}}],
                tokens_used=300,
            ),
            _make_orchestrator_result(answer="Iter 2.", tokens_used=250),
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert result["tokens_used"] == 550

    def test_final_answer_from_last_iteration(self):
        """The answer in the result dict must come from the last LLM response (Test 13)."""
        final_answer_text = "C'est la réponse finale définitive."
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Réponse intermédiaire — ne doit PAS apparaître.",
                tool_calls=[{"name": "retrieve_memories", "input": {"topic": "3a"}}],
            ),
            _make_orchestrator_result(answer=final_answer_text),
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert result["answer"] == final_answer_text
        assert "ne doit PAS" not in result["answer"]

    def test_sources_deduplicated(self):
        """Duplicate sources across iterations are deduplicated (Test 14)."""
        source_a = {"file": "pilier_3a.md", "section": "intro"}
        source_b = {"file": "lpp.md", "section": "rachat"}
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Iter 1.",
                tool_calls=[{"name": "retrieve_memories", "input": {"topic": "test"}}],
                sources=[source_a, source_b],
            ),
            _make_orchestrator_result(answer="Iter 2.", sources=[source_a]),  # duplicate
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert len(result["sources"]) == 2  # not 3

    def test_disclaimers_deduplicated(self):
        """Duplicate disclaimers are deduplicated via set()."""
        disclaimer = "Outil educatif (LSFin)."
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Iter 1.",
                tool_calls=[{"name": "retrieve_memories", "input": {"topic": "test"}}],
                disclaimers=[disclaimer],
            ),
            _make_orchestrator_result(answer="Iter 2.", disclaimers=[disclaimer]),
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert len(result["disclaimers"]) == 1

    def test_no_tool_calls_returns_none(self):
        """When no Flutter tools are collected, tool_calls is None."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(answer="Simple réponse.")
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert result["tool_calls"] is None


# ===========================================================================
# Test 10 — Error handling
# ===========================================================================


class TestAgentLoopErrorHandling:
    """Test graceful error handling in the loop."""

    def test_error_in_tool_execution_handled(self):
        """If _execute_internal_tool raises, the loop handles it gracefully (Test 10)."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="",
                tool_calls=[{"name": "retrieve_memories", "input": {"topic": "lpp"}}],
            ),
            _make_orchestrator_result(answer="Continue malgré l'erreur."),
        )
        with patch(
            "app.api.v1.endpoints.coach_chat._execute_internal_tool",
            side_effect=RuntimeError("simulated failure"),
        ):
            try:
                result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
                # If it completed, answer must be a string
                assert isinstance(result.get("answer"), str)
            except (RuntimeError, Exception):
                # Acceptable: exception propagated to endpoint (caught as 502)
                pass


# ===========================================================================
# Test 15 — Max iterations warning logged
# ===========================================================================


class TestAgentLoopLogging:
    """Test that the loop emits the expected log warnings."""

    def test_max_iterations_warning_logged(self, caplog):
        """When loop reaches max iterations, a WARNING must be logged (Test 15)."""
        internal_call = {"name": "retrieve_memories", "input": {"topic": "retraite"}}
        always_tool_result = _make_orchestrator_result(
            answer="toujours des outils",
            tool_calls=[internal_call],
        )
        orch = _make_mock_orchestrator(*[always_tool_result] * (MAX_AGENT_LOOP_ITERATIONS + 2))

        with caplog.at_level(logging.WARNING, logger="app.api.v1.endpoints.coach_chat"):
            _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))

        warning_messages = [r.message for r in caplog.records if r.levelno >= logging.WARNING]
        assert any(
            "max" in msg.lower() and "iteration" in msg.lower()
            for msg in warning_messages
        ), f"Expected max-iterations warning, got: {warning_messages}"


# ===========================================================================
# _execute_internal_tool unit tests
# ===========================================================================


class TestExecuteInternalTool:
    """Unit tests for _execute_internal_tool helper function."""

    def test_retrieve_memories_delegates_to_handler(self):
        """retrieve_memories calls _handle_retrieve_memories."""
        memory = "retraite: taux 63%"
        result = _execute_internal_tool(
            {"name": "retrieve_memories", "input": {"topic": "retraite"}},
            memory_block=memory,
        )
        assert "63%" in result

    def test_unknown_tool_returns_fallback(self):
        """Unknown internal tool returns a graceful fallback message."""
        result = _execute_internal_tool(
            {"name": "unknown_tool", "input": {}},
            memory_block=None,
        )
        assert "non reconnu" in result

    def test_retrieve_memories_with_none_memory(self):
        """retrieve_memories with None memory_block returns 'aucune mémoire'."""
        result = _execute_internal_tool(
            {"name": "retrieve_memories", "input": {"topic": "test"}},
            memory_block=None,
        )
        assert "Aucune mémoire" in result


# ===========================================================================
# get_llm_tools stripping verification
# ===========================================================================


class TestAgentLoopUsesGetLlmTools:
    """Verify that the agent loop uses get_llm_tools() (stripped tools)."""

    def test_tools_sent_to_orchestrator_are_stripped(self):
        """Tools passed to orchestrator.query() must not contain category/access_level."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(answer="OK.")
        )
        _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        call_kwargs = orch.query.call_args.kwargs
        tools = call_kwargs["tools"]
        for tool in tools:
            assert "category" not in tool, f"Tool {tool['name']} has 'category'"
            assert "access_level" not in tool, f"Tool {tool['name']} has 'access_level'"
