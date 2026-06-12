"""Forced explain_concept on definition intent — authenticated surface (Plan 05).

Phase: mint-grounded-coach-m1 / Plan 05 (Task 2 + Task 3).

Generalises the anonymous_chat.py:204 force pattern to the AUTHENTICATED agent
loop: when the user asks for the DEFINITION of a registry concept ("c'est quoi un
rachat", "qu'est-ce que l'EPL", "explique le splitting AVS"), the FIRST LLM call
of the turn is forced to tool_choice {"type":"tool","name":"explain_concept"} so
the model retrieves the curated definition instead of defining from its weights.

CRITICAL first-call-only constraint (plan-check blocker): the force applies ONLY
to the first call. Subsequent agent-loop iterations (capped by
MAX_AGENT_LOOP_ITERATIONS=4) revert to {"type":"auto"} so the loop can emit a
final TEXT answer after the explain_concept tool_result ("force turn 1, answer
turn 2", mirroring the anonymous pattern). Without this the loop would re-force
the tool on every iteration and never terminate with text.

Task 3 (this same file): show_fact_card content/source are validated against the
registry before the card crosses to the mobile renderer — an inverted definition
is blocked (fallback text) and an off-registry source is repaired/rejected.

Test strategy: mock orchestrator.query (AsyncMock) and assert on the tool_choice
kwarg passed to each call (call_args_list), exactly like test_agent_loop.py mocks
the orchestrator. tool_choice=None means "auto" (the llm_client default).
"""

from __future__ import annotations

import asyncio
from typing import Optional
from unittest.mock import AsyncMock, MagicMock

from app.api.v1.endpoints.coach_chat import (
    _classify_user_intent,
    _gate_fact_card_against_registry,
    _run_agent_loop,
)


# ---------------------------------------------------------------------------
# Helpers (mirror test_agent_loop.py)
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


_DEFINITION_MSG = "c'est quoi un rachat LPP ?"
_CHITCHAT_MSG = "salut, comment ça va aujourd'hui ?"
_FACT_DECLARATION_MSG = "je gagne 8500 CHF par mois et j'ai 35 ans"


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


# ===========================================================================
# Task 2 — intent classifier: definition_request
# ===========================================================================


class TestDefinitionIntentClassifier:
    def test_cest_quoi_registry_concept_is_definition_request(self):
        assert "definition_request" in _classify_user_intent("c'est quoi un rachat ?")

    def test_quest_ce_que_registry_concept_is_definition_request(self):
        assert "definition_request" in _classify_user_intent("qu'est-ce que l'EPL ?")

    def test_explique_registry_concept_is_definition_request(self):
        assert "definition_request" in _classify_user_intent(
            "explique-moi le splitting AVS"
        )

    def test_interrogative_without_registry_concept_is_not_definition(self):
        # "c'est quoi" but no registry concept → not a forced-tool definition.
        assert "definition_request" not in _classify_user_intent(
            "c'est quoi ton plat préféré ?"
        )

    def test_registry_concept_without_interrogative_is_not_definition(self):
        # Mentions a concept but does not ASK for its definition.
        assert "definition_request" not in _classify_user_intent(
            "j'ai fait un rachat LPP de 20000 CHF l'an dernier"
        )

    def test_chitchat_is_not_definition_request(self):
        assert "definition_request" not in _classify_user_intent(_CHITCHAT_MSG)


class TestDefinitionIntentBroadenedInterrogatives:
    """Codex grounding-stack review (fix_3b): interrogative families that the
    classifier MISSED before the fix must now force explain_concept."""

    def test_comment_fonctionne_is_definition_request(self):
        # PROBE (Codex miss): "Comment fonctionne un rachat LPP ?"
        assert "definition_request" in _classify_user_intent(
            "Comment fonctionne un rachat LPP ?"
        )

    def test_ce_que_veut_dire_is_definition_request(self):
        # PROBE (Codex miss): "Tu peux me dire ce que veut dire EPL ?"
        assert "definition_request" in _classify_user_intent(
            "Tu peux me dire ce que veut dire EPL ?"
        )

    def test_jaimerais_comprendre_is_definition_request(self):
        # PROBE (Codex miss): "J'aimerais comprendre le taux de conversion."
        assert "definition_request" in _classify_user_intent(
            "J'aimerais comprendre le taux de conversion."
        )

    def test_tu_peux_mexpliquer_is_definition_request(self):
        assert "definition_request" in _classify_user_intent(
            "Tu peux m'expliquer le splitting AVS ?"
        )

    def test_past_rachat_declaration_does_not_force(self):
        # False-positive guard (Codex): a DECLARATION of a past action must NOT
        # force the tool — no interrogative present.
        assert "definition_request" not in _classify_user_intent(
            "j'ai fait un rachat l'année passée"
        )

    def test_comment_ca_va_does_not_force(self):
        # "comment" alone (greeting) must not force without a concept term.
        assert "definition_request" not in _classify_user_intent(
            "salut, comment ça va aujourd'hui ?"
        )


# ===========================================================================
# Task 2 — first-call-only forced tool_choice
# ===========================================================================


class TestForcedToolChoiceFirstCallOnly:
    def test_definition_forces_explain_concept_on_first_call_only(self):
        """Force turn 1; the follow-up after the tool_result reverts to auto."""
        orch = _make_mock_orchestrator(
            # Turn 1: model invokes explain_concept (forced).
            _make_result(
                answer="",
                tool_calls=[
                    {"name": "explain_concept", "input": {"concept_key": "rachat_lpp"}}
                ],
            ),
            # Turn 2: unforced → emits the grounded text answer (loop terminates).
            _make_result(
                answer="Un rachat LPP, c'est verser dans ta caisse de pension."
            ),
        )
        result = _run(
            _run_agent_loop(
                orchestrator=orch,
                **_base_kwargs(_DEFINITION_MSG, {"definition_request"}),
            )
        )
        choices = _tool_choices(orch)
        assert len(choices) == 2, f"expected 2 calls, got {len(choices)}"
        # First call forced to explain_concept.
        assert choices[0] == {"type": "tool", "name": "explain_concept"}
        # Second (post-tool_result) call reverted to auto (None == llm default auto).
        assert choices[1] is None
        # Loop TERMINATED with a text answer after the tool_result.
        assert "rachat LPP" in result["answer"]

    def test_loop_terminates_with_text_after_tool_result(self):
        """Termination guard: no infinite re-force; final answer is text."""
        orch = _make_mock_orchestrator(
            _make_result(
                answer="",
                tool_calls=[
                    {"name": "explain_concept", "input": {"concept_key": "epl"}}
                ],
            ),
            _make_result(answer="L'EPL, c'est un retrait anticipé du 2e pilier."),
        )
        result = _run(
            _run_agent_loop(
                orchestrator=orch,
                **_base_kwargs("qu'est-ce que l'EPL ?", {"definition_request"}),
            )
        )
        assert result["answer"].strip() != ""
        assert orch.query.call_count == 2  # did NOT spin to MAX iterations

    def test_chitchat_stays_auto_on_all_calls(self):
        orch = _make_mock_orchestrator(_make_result(answer="Salut ! Ça va bien."))
        _run(
            _run_agent_loop(
                orchestrator=orch, **_base_kwargs(_CHITCHAT_MSG, set())
            )
        )
        for choice in _tool_choices(orch):
            assert choice is None  # auto everywhere

    def test_fact_declaration_stays_auto(self):
        """save_fact path unaffected — a fact declaration is never force-routed.

        save_fact is an INTERNAL tool, so the loop re-calls the LLM after
        executing it (turn 2 emits the narration). tool_choice must stay auto on
        BOTH calls — the definition force never applies to a fact declaration.
        """
        orch = _make_mock_orchestrator(
            _make_result(
                answer="",
                tool_calls=[
                    {"name": "save_fact", "input": {"key": "salary", "value": "8500"}}
                ],
            ),
            _make_result(answer="Noté, je garde ça en tête."),
        )
        _run(
            _run_agent_loop(
                orchestrator=orch,
                **_base_kwargs(_FACT_DECLARATION_MSG, {"taxes"}),
            )
        )
        choices = _tool_choices(orch)
        assert len(choices) == 2
        for choice in choices:
            assert choice is None


# ===========================================================================
# Task 3 — show_fact_card gated against the registry
# ===========================================================================


class TestFactCardRegistryGate:
    def test_inverted_content_card_blocked(self):
        """A fact card whose content inverts a registry definition is dropped."""
        card = {
            "name": "show_fact_card",
            "input": {
                "title": "Le rachat LPP",
                "content": "Un rachat LPP, c'est sortir ton capital du 2e pilier avant l'heure.",
                "source": "LPP art. 79b",
            },
        }
        kept = _gate_fact_card_against_registry(card)
        assert kept is None  # blocked → caller emits fallback text

    def test_correct_card_passes(self):
        card = {
            "name": "show_fact_card",
            "input": {
                "title": "Le rachat LPP",
                "content": "Un rachat LPP, c'est verser de l'argent dans ta caisse de pension.",
                "source": "LPP art. 79b",
            },
        }
        kept = _gate_fact_card_against_registry(card)
        assert kept is not None
        assert kept["input"]["content"].startswith("Un rachat LPP")

    def test_fabricated_source_repaired_to_page_source(self):
        """Correct content but an off-registry source → repaired to the page source."""
        card = {
            "name": "show_fact_card",
            "input": {
                "title": "Le rachat LPP",
                "content": "Un rachat LPP, c'est verser de l'argent dans ta caisse de pension.",
                "source": "Source inventée art. 999",
            },
        }
        kept = _gate_fact_card_against_registry(card)
        assert kept is not None
        assert kept["input"]["source"] == "LPP art. 79b"

    def test_non_registry_card_passes_untouched(self):
        """A card about a non-registry topic is not gated (no false rejection)."""
        card = {
            "name": "show_fact_card",
            "input": {
                "title": "Astuce budget",
                "content": "Pense à mettre de côté chaque mois.",
                "source": "MINT",
            },
        }
        kept = _gate_fact_card_against_registry(card)
        assert kept is not None
        assert kept["input"]["source"] == "MINT"
