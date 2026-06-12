"""Tests for the save_fact → mobile echo (mint-grounded-coach-m1 Plan 06, Task 2).

CONTEXT WS-D / audit 04 §1.3 P0-bis: `save_fact` is an INTERNAL_TOOL_NAMES tool
(coach_tools.py:104). It persists to ProfileModel.data server-side but is
filtered out of `flutter_tool_calls`, so the value the user stated in chat
(e.g. « j'ai 50 ans ») never reaches the local CoachProfile the mobile screens
read — the split-brain bug (W1 WTF-W1-04).

The minimal fix (NOT the M2 event-log cutover): when a `save_fact` internal
tool call SUCCEEDS for a whitelisted key, append a forward-safe `fact_saved`
echo entry to `flutter_tool_calls` carrying `{key, value}`. save_fact stays
internal (persistence intact); the echo is additive.

Privacy (T-m1-06-01): the echo is gated by the same persist whitelist
(_SAVE_FACT_ALLOWED_KEYS). A non-whitelisted key is never echoed.
"""

from __future__ import annotations

import asyncio
from typing import Optional
from unittest.mock import AsyncMock, MagicMock

from app.api.v1.endpoints.coach_chat import (
    _build_fact_saved_echo,
    _run_agent_loop,
)


# ---------------------------------------------------------------------------
# Helpers (mirror tests/test_agent_loop.py harness)
# ---------------------------------------------------------------------------


def _make_orchestrator_result(
    answer: str = "Réponse test.",
    tool_calls: Optional[list] = None,
    tokens_used: int = 200,
) -> dict:
    return {
        "answer": answer,
        "tool_calls": tool_calls,
        "sources": [],
        "disclaimers": [],
        "tokens_used": tokens_used,
    }


def _make_mock_orchestrator(*results: dict) -> MagicMock:
    mock = MagicMock()
    mock.query = AsyncMock(side_effect=list(results))
    return mock


def _run(coro):
    return asyncio.run(coro)


_BASE_KWARGS = {
    "question": "J'ai 50 ans.",
    "api_key": "sk-test-key",
    "provider": "claude",
    "model": None,
    "profile_context": {},
    "language": "fr",
    "memory_block": None,
    # save_fact is a WRITE-tier tool — it only persists (and therefore only
    # echoes) when the user consented to persistence. The echo correctly
    # mirrors persistence: no consent → no write → no echo.
    "persistence_consent": True,
}


def _fact_saved_calls(tool_calls: Optional[list]) -> list:
    if not tool_calls:
        return []
    return [t for t in tool_calls if t.get("name") == "fact_saved"]


# ---------------------------------------------------------------------------
# Unit: the echo builder (whitelist + coercion gate)
# ---------------------------------------------------------------------------


class TestBuildFactSavedEcho:
    def test_whitelisted_key_yields_echo_with_coerced_value(self):
        echo = _build_fact_saved_echo({"name": "save_fact", "input": {"key": "birthYear", "value": 1976}})
        assert echo is not None
        assert echo["name"] == "fact_saved"
        assert echo["input"]["key"] == "birthYear"
        # birthYear is an int key — coerced to int.
        assert echo["input"]["value"] == 1976

    def test_non_whitelisted_key_is_not_echoed(self):
        echo = _build_fact_saved_echo({"name": "save_fact", "input": {"key": "ssn", "value": "756.1234"}})
        assert echo is None

    def test_uncoercible_value_is_not_echoed(self):
        # birthYear=2099 fails the registry bound check → no persist → no echo.
        echo = _build_fact_saved_echo({"name": "save_fact", "input": {"key": "birthYear", "value": 2099}})
        assert echo is None

    def test_missing_key_is_not_echoed(self):
        assert _build_fact_saved_echo({"name": "save_fact", "input": {}}) is None


# ---------------------------------------------------------------------------
# Integration: the agent loop emits the echo for a whitelisted save_fact
# ---------------------------------------------------------------------------


class TestAgentLoopFactSavedEcho:
    def test_declared_age_yields_fact_saved_echo_in_tool_calls(self):
        """A save_fact(birthYear) success appends a fact_saved echo carrying
        {birthYear, value} so the mobile can update the local profile."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Noté.",
                tool_calls=[
                    {"name": "save_fact", "input": {"key": "birthYear", "value": 1976}},
                ],
            ),
            _make_orchestrator_result(answer="C'est noté, tu as 50 ans."),
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        echoes = _fact_saved_calls(result["tool_calls"])
        assert len(echoes) == 1
        assert echoes[0]["input"]["key"] == "birthYear"
        assert echoes[0]["input"]["value"] == 1976

    def test_non_whitelisted_field_is_not_echoed(self):
        """A save_fact on an off-whitelist key must NOT produce an echo
        (privacy parity with the persist whitelist — T-m1-06-01)."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Hmm.",
                tool_calls=[
                    {"name": "save_fact", "input": {"key": "ssn", "value": "756.1234.5678.90"}},
                ],
            ),
            _make_orchestrator_result(answer="Je ne peux pas enregistrer ça."),
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        assert _fact_saved_calls(result["tool_calls"]) == []

    def test_no_persistence_consent_no_echo(self):
        """When persistence_consent is False the fact is NOT written server-side,
        so NO echo crosses (the echo mirrors persistence, never bypasses it)."""
        kwargs = {**_BASE_KWARGS, "persistence_consent": False}
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Noté.",
                tool_calls=[
                    {"name": "save_fact", "input": {"key": "birthYear", "value": 1976}},
                ],
            ),
            _make_orchestrator_result(answer="C'est noté."),
        )
        result = _run(_run_agent_loop(orchestrator=orch, **kwargs))
        assert _fact_saved_calls(result["tool_calls"]) == []

    def test_save_fact_still_internal_not_forwarded_raw(self):
        """The raw save_fact tool_use is NOT forwarded to Flutter (it stays
        internal); only the additive fact_saved echo crosses."""
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Noté.",
                tool_calls=[
                    {"name": "save_fact", "input": {"key": "canton", "value": "VD"}},
                ],
            ),
            _make_orchestrator_result(answer="Tu vis dans le canton de Vaud."),
        )
        result = _run(_run_agent_loop(orchestrator=orch, **_BASE_KWARGS))
        calls = result["tool_calls"] or []
        names = [t.get("name") for t in calls]
        assert "save_fact" not in names  # raw internal tool never forwarded
        assert "fact_saved" in names  # additive echo crossed
        echo = _fact_saved_calls(calls)[0]
        assert echo["input"]["key"] == "canton"
        assert echo["input"]["value"] == "VD"
