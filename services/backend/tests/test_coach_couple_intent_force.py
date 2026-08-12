"""Forced get_couple_optimization on couple/prévoyance-à-deux intent.

Branch: codex/journey-os-coach-intent-couple-forcage (2026-08).

Root cause (investigation): a couple-prévoyance question such as
« Notre prévoyance à deux ? » classified as `retirement` ONLY (the substring
« prevoyance » fires retirement), never `family`, because the couple lexicon
(« couple », « à deux », « conjoint », « partenaire ») was absent from
`_INTENT_KEYWORDS["family"]`. Tool-eligibility (retirement) merely suppressed
RAG; NO tool was forced (only get_regulatory_constant and explain_concept were
force-wired). The LLM then free-generated an ungrounded couple answer that the
ComplianceGuard blanked to `_SAFE_FALLBACK_FR` (« Je suis là pour t'aider… »),
a pure deflection — the forced-tool-invocation doctrine violation.

Fix under test (mirror of the explain_concept force pattern, Plan 05):
  1. Couple lexicon added to `_INTENT_KEYWORDS["family"]` so the classifier
     surfaces `family` on couple phrasings (reuses the existing `family` tag —
     no change to the frozen intent contract `_route_intents_generated.py`).
  2. `_should_force_couple` (symmetric to `_should_force_regulatory_constant`)
     gates a FIRST-CALL-ONLY tool_choice
     {"type":"tool","name":"get_couple_optimization"} so the answer is grounded
     in the couple engine (AVS cap 150 % LAVS art. 35, LPP ×2, 3a ×2) instead
     of a free-generated reply.

Test strategy: mock orchestrator.query (AsyncMock) and assert on the tool_choice
kwarg passed to each call, exactly like test_coach_chat_intent_force.py.
"""

from __future__ import annotations

import asyncio
from typing import Optional
from unittest.mock import AsyncMock, MagicMock

from app.api.v1.endpoints.coach_chat import (
    _classify_user_intent,
    _run_agent_loop,
    _should_force_couple,
)


# ---------------------------------------------------------------------------
# Helpers (mirror test_coach_chat_intent_force.py)
# ---------------------------------------------------------------------------


def _make_result(
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


def _tool_choices(orch: MagicMock) -> list:
    """Extract the tool_choice kwarg passed to each orchestrator.query() call."""
    return [c.kwargs.get("tool_choice") for c in orch.query.call_args_list]


def _base_kwargs(question: str, detected_intents: set[str]) -> dict:
    return {
        "question": question,
        "api_key": "sk-test-key",
        "provider": "claude",
        "model": None,
        "profile_context": {},
        "language": "fr",
        "memory_block": None,
        "detected_intents": detected_intents,
    }


_COUPLE_TOOL = {"type": "tool", "name": "get_couple_optimization"}

_PREVOYANCE_A_DEUX_MSG = "Notre prévoyance à deux ?"
_PREVOYANCE_COUPLE_MSG = "prévoyance couple"
_CONJOINT_MSG = "et pour mon conjoint ?"
# Counter-example: a solo definition lookup must NOT force the couple tool.
_SOLO_DEFINITION_MSG = "c'est quoi le 3e pilier ?"


# ===========================================================================
# (a) Golden — classifier surfaces the couple/family intent
# ===========================================================================


class TestCoupleIntentClassifier:
    def test_prevoyance_a_deux_surfaces_family(self):
        # The exact device-reported question.
        intents = _classify_user_intent(_PREVOYANCE_A_DEUX_MSG)
        assert "family" in intents, (
            "« Notre prévoyance à deux ? » must surface the couple/family "
            f"intent, got {sorted(intents)}"
        )
        # Regression guard: the retirement match (via « prevoyance ») remains.
        assert "retirement" in intents

    def test_prevoyance_couple_surfaces_family(self):
        assert "family" in _classify_user_intent(_PREVOYANCE_COUPLE_MSG)

    def test_conjoint_surfaces_family(self):
        # Previously classified as ∅ (empty) — « conjoint » was not a keyword.
        assert "family" in _classify_user_intent(_CONJOINT_MSG)

    def test_solo_definition_does_not_surface_family(self):
        # Counter-example: no couple cue → family must NOT fire.
        assert "family" not in _classify_user_intent(_SOLO_DEFINITION_MSG)


# ===========================================================================
# (b) _should_force_couple predicate — symmetric to regulatory_constant
# ===========================================================================


class TestShouldForceCouplePredicate:
    _TOOLS = [{"name": "get_couple_optimization"}]

    def test_prevoyance_a_deux_forces(self):
        assert _should_force_couple(
            question=_PREVOYANCE_A_DEUX_MSG,
            detected_intents=_classify_user_intent(_PREVOYANCE_A_DEUX_MSG),
            tools=self._TOOLS,
        )

    def test_prevoyance_couple_forces(self):
        assert _should_force_couple(
            question=_PREVOYANCE_COUPLE_MSG,
            detected_intents=_classify_user_intent(_PREVOYANCE_COUPLE_MSG),
            tools=self._TOOLS,
        )

    def test_conjoint_forces(self):
        assert _should_force_couple(
            question=_CONJOINT_MSG,
            detected_intents=_classify_user_intent(_CONJOINT_MSG),
            tools=self._TOOLS,
        )

    def test_solo_definition_does_not_force(self):
        assert not _should_force_couple(
            question=_SOLO_DEFINITION_MSG,
            detected_intents=_classify_user_intent(_SOLO_DEFINITION_MSG),
            tools=self._TOOLS,
        )

    def test_tool_absent_does_not_force(self):
        # If get_couple_optimization is not advertised, never force it.
        assert not _should_force_couple(
            question=_PREVOYANCE_A_DEUX_MSG,
            detected_intents=_classify_user_intent(_PREVOYANCE_A_DEUX_MSG),
            tools=[{"name": "get_regulatory_constant"}],
        )

    def test_family_without_couple_term_does_not_force(self):
        # A pure child/family event ("j'attends un enfant") fires family but
        # carries no couple cue → couple optimization is NOT forced.
        q = "j'attends un enfant"
        intents = _classify_user_intent(q)
        assert "family" in intents  # sanity: family fired
        assert not _should_force_couple(
            question=q, detected_intents=intents, tools=self._TOOLS
        )


# ===========================================================================
# (b) Agent-loop — first-call-only forced get_couple_optimization
# ===========================================================================


class TestForcedCoupleToolFirstCallOnly:
    def test_prevoyance_a_deux_forces_couple_then_reverts_to_auto(self):
        """Force turn 1; the follow-up after the tool_result reverts to auto."""
        orch = _make_mock_orchestrator(
            # Turn 1: model invokes get_couple_optimization (forced, internal).
            _make_result(
                answer="",
                tool_calls=[{"name": "get_couple_optimization", "input": {}}],
            ),
            # Turn 2: unforced → emits the grounded text answer (loop terminates).
            _make_result(
                answer=(
                    "Pour votre prévoyance à deux, voici les leviers communs "
                    "(AVS, LPP, 3a de chaque conjoint)."
                )
            ),
        )
        result = _run(
            _run_agent_loop(
                orchestrator=orch,
                tools=[{"name": "get_couple_optimization"}],
                **_base_kwargs(
                    _PREVOYANCE_A_DEUX_MSG,
                    _classify_user_intent(_PREVOYANCE_A_DEUX_MSG),
                ),
            )
        )
        choices = _tool_choices(orch)
        assert len(choices) == 2, f"expected 2 calls, got {len(choices)}"
        assert choices[0] == _COUPLE_TOOL  # first call forced
        assert choices[1] is None  # post-tool_result reverts to auto
        assert result["answer"].strip() != ""  # loop terminated with text

    def test_conjoint_forces_couple_tool(self):
        orch = _make_mock_orchestrator(
            _make_result(
                answer="",
                tool_calls=[{"name": "get_couple_optimization", "input": {}}],
            ),
            _make_result(answer="Voici ce qui s'applique à votre conjoint."),
        )
        _run(
            _run_agent_loop(
                orchestrator=orch,
                tools=[{"name": "get_couple_optimization"}],
                **_base_kwargs(
                    _CONJOINT_MSG, _classify_user_intent(_CONJOINT_MSG)
                ),
            )
        )
        assert _tool_choices(orch)[0] == _COUPLE_TOOL

    def test_solo_definition_does_not_force_couple_tool(self):
        """Counter-example: a solo 3a definition must NOT force couple."""
        orch = _make_mock_orchestrator(
            _make_result(answer="Le 3e pilier, c'est l'épargne individuelle.")
        )
        _run(
            _run_agent_loop(
                orchestrator=orch,
                tools=[{"name": "get_couple_optimization"}],
                **_base_kwargs(
                    _SOLO_DEFINITION_MSG,
                    _classify_user_intent(_SOLO_DEFINITION_MSG),
                ),
            )
        )
        for choice in _tool_choices(orch):
            assert choice != _COUPLE_TOOL, (
                "a solo definition lookup must never force the couple tool"
            )
