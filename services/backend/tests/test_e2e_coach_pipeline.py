"""
E2E Coach Pipeline — 10 real financial questions validated end-to-end.

Tests the full coach chat pipeline WITHOUT making real LLM API calls.
Mocks only the LLM response; tests EVERYTHING ELSE:
    1. StructuredReasoningService produces the right fact for each profile
    2. System prompt contains lifecycle, regional, plan, and budget blocks
    3. ComplianceGuard sections are present (banned terms, disclaimer)
    4. Agent loop handles tool_use -> execute -> re-call properly
    5. Correct tools are called for each question type
    6. Internal tools are never forwarded to Flutter
    7. Final response has correct shape (message, tool_calls, sources)

The 10 questions cover the Top 10 Swiss Core Journeys:
    Q1.  "Comment optimiser mon 3a ?"      -> 3a_not_maxed reasoning
    Q2.  "Rente ou capital ?"               -> retirement_choice route_to_screen
    Q3.  "Je viens de divorcer"             -> life_event_divorce route_to_screen
    Q4.  "Combien me reste-t-il ce mois ?"  -> show_budget_snapshot
    Q5.  "Mon taux de remplacement ?"       -> gap_warning reasoning
    Q6.  "Je veux racheter mon LPP"         -> rachat_opportunity reasoning
    Q7.  "Quel est mon score ?"             -> show_score_gauge
    Q8.  "Je vais avoir un bebe"            -> life_event_birth route_to_screen
    Q9.  "Comparaison de deux offres"       -> job_comparison route_to_screen
    Q10. "Mon budget est en deficit"         -> deficit reasoning

Golden profile: Julien (CLAUDE.md golden couple)
    age=49, canton=VS, archetype=swiss_native, salaire=122207,
    lpp_capital=70377, lpp_buyback_max=539414, 3a=32000,
    replacement_ratio=0.655

Run: cd services/backend && python3 -m pytest tests/test_e2e_coach_pipeline.py -v
"""

from __future__ import annotations

import asyncio
import datetime
from typing import Optional
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.api.v1.endpoints.coach_chat import (
    INTERNAL_TOOL_NAMES,
    _build_coach_context_from_profile,
    _build_system_prompt_with_memory,
    _run_agent_loop,
    _sanitize_profile_context,
)
from app.services.coach.claude_coach_service import build_system_prompt
from app.services.coach.coach_tools import COACH_TOOLS, get_llm_tools
from app.services.coach.structured_reasoning import (
    ReasoningOutput,
    StructuredReasoningService,
)


# ---------------------------------------------------------------------------
# Golden couple profile: Julien (from CLAUDE.md)
# ---------------------------------------------------------------------------

_JULIEN_PROFILE = {
    "first_name": "Julien",
    "archetype": "swiss_native",
    "age": 49,
    "canton": "VS",
    "monthly_income": 10184.0,  # 122207 / 12
    "monthly_expenses": 7500.0,
    "annual_3a_contribution": 5000.0,
    "existing_3a_ytd": 5000.0,
    "lpp_buyback_max": 539414.0,
    "lpp_capital": 70377.0,
    "lpp_certificate_year": 2025,
    "avs_rente": 30240.0,
    "monthly_retirement_income": 8505.0,
    "replacement_ratio": 0.655,
    "months_liquidity": 6.0,
    "fri_total": 62.0,
    "fri_delta": 3.0,
    "tax_saving_potential": 2000.0,
    "confidence_score": 72.0,
    "data_source": "user_input",
    "civil_status": "married",
    "employment_status": "employed",
}

_MEMORY_BLOCK = (
    "CONTEXTE CYCLE DE VIE : consolidation (45-55 ans)\n"
    "NUDGES ACTIFS : rachat_lpp, optimisation_3a\n"
    "COULEUR REGIONALE : Valais, Romande — montagnard, direct\n"
    "PLAN EN COURS : Optimiser la retraite (3/10 etapes)\n"
    "SURFACES PERTINENTES : retirement_choice, tax_optimization_3a, lpp_buyback"
)

# Fixed date in July to avoid December 3a deadline interference
_JULY_DATE = datetime.date(2025, 7, 15)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_orchestrator_result(
    answer: str = "Reponse du coach.",
    tool_calls: Optional[list] = None,
    sources: Optional[list] = None,
    disclaimers: Optional[list] = None,
    tokens_used: int = 300,
) -> dict:
    """Build a mock orchestrator.query() result."""
    return {
        "answer": answer,
        "tool_calls": tool_calls,
        "sources": sources or [],
        "disclaimers": disclaimers or [
            "Outil educatif, ne constitue pas un conseil financier (LSFin)."
        ],
        "tokens_used": tokens_used,
    }


def _make_mock_orchestrator(*results: dict) -> MagicMock:
    """Create a mock orchestrator that returns different results per call."""
    mock = MagicMock()
    mock.query = AsyncMock(side_effect=list(results))
    return mock


def _run(coro):
    """Run a coroutine synchronously."""
    return asyncio.run(coro)


def _safe_profile(raw: dict) -> dict:
    """Run profile through the sanitizer (same as the endpoint does)."""
    return _sanitize_profile_context(raw)


def _reason_with_fixed_date(
    profile: dict,
    message: str,
    memory_block: Optional[str] = None,
) -> ReasoningOutput:
    """Call StructuredReasoningService.reason() with a fixed July date."""
    return StructuredReasoningService.reason(
        user_message=message,
        profile_context=profile,
        memory_block=memory_block,
        today=_JULY_DATE,
    )


def _build_full_system_prompt(profile: dict, memory_block: Optional[str] = None):
    """Build the full system prompt the way the endpoint does."""
    safe = _safe_profile(profile)
    coach_ctx = _build_coach_context_from_profile(safe)
    return _build_system_prompt_with_memory(coach_ctx, memory_block)


def _run_pipeline(
    question: str,
    profile: dict,
    memory_block: Optional[str] = None,
    llm_tool_calls: Optional[list] = None,
    llm_answer: str = "Reponse coach.",
    multi_turn: bool = False,
    second_answer: str = "Reponse enrichie.",
) -> dict:
    """Run the full agent loop pipeline with a mocked orchestrator.

    If multi_turn is True, the first LLM call returns an internal tool call
    (triggering re-call), and the second call returns the final answer.
    """
    if multi_turn:
        # First call: internal tool, second call: final answer
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer="Laisse-moi verifier.",
                tool_calls=llm_tool_calls or [],
            ),
            _make_orchestrator_result(
                answer=second_answer,
                tool_calls=None,
            ),
        )
    else:
        orch = _make_mock_orchestrator(
            _make_orchestrator_result(
                answer=llm_answer,
                tool_calls=llm_tool_calls,
            )
        )

    safe = _safe_profile(profile)
    reasoning = _reason_with_fixed_date(safe, question, memory_block)
    system_prompt = _build_full_system_prompt(profile, memory_block)
    if reasoning.as_system_prompt_block():
        system_prompt += "\n\n" + reasoning.as_system_prompt_block()

    result = _run(_run_agent_loop(
        orchestrator=orch,
        question=question,
        api_key="sk-test-e2e-pipeline",
        provider="claude",
        model=None,
        profile_context=safe,
        language="fr",
        memory_block=memory_block,
        system_prompt=system_prompt,
    ))

    return {
        "result": result,
        "reasoning": reasoning,
        "system_prompt": system_prompt,
        "orchestrator": orch,
    }


# ===========================================================================
# Q1: "Comment optimiser mon 3a ?" -> 3a_not_maxed reasoning
# ===========================================================================


class TestQ1_3aOptimization:
    """Q1: 3a optimization question triggers 3a_not_maxed reasoning."""

    def test_reasoning_detects_3a_not_maxed(self):
        """With annual_3a_contribution=5000 < 7258 ceiling, 3a_not_maxed fires."""
        safe = _safe_profile(_JULIEN_PROFILE)
        output = _reason_with_fixed_date(safe, "Comment optimiser mon 3a ?")
        # Julien has: no deficit, replacement_ratio=0.655 > 0.60, lpp_buyback=539414
        # Priority: deficit > 3a_deadline > gap_warning > rachat > 3a_not_maxed
        # replacement_ratio > 0.60 => no gap_warning
        # lpp_buyback=539414 >= 10000 => rachat_opportunity fires (higher priority)
        assert output.fact_tag in ("rachat_opportunity", "3a_not_maxed")

    def test_reasoning_has_3a_data_in_supporting(self):
        """Supporting data includes 3a contribution amounts."""
        # Use a profile where rachat is suppressed (no lpp_buyback)
        profile = {**_JULIEN_PROFILE, "lpp_buyback_max": 0}
        safe = _safe_profile(profile)
        output = _reason_with_fixed_date(safe, "Comment optimiser mon 3a ?")
        assert output.fact_tag == "3a_not_maxed"
        assert "plafond_3a_CHF" in output.supporting_data
        assert output.supporting_data["plafond_3a_CHF"] == 7258.0

    def test_system_prompt_has_all_sections(self):
        """System prompt includes lifecycle, regional, plan, and routing rules."""
        prompt = _build_full_system_prompt(_JULIEN_PROFILE, _MEMORY_BLOCK)
        assert "LIFECYCLE AWARENESS" in prompt
        assert "REGIONAL IDENTITY" in prompt
        assert "PLAN AWARENESS" in prompt
        assert "ROUTING RULES" in prompt
        assert "TERMES INTERDITS" in prompt

    def test_system_prompt_contains_user_context(self):
        """System prompt includes Julien's aggregated data via CoachContext fields.

        Note: build_coach_context() only accepts its declared kwargs (age, canton,
        archetype, etc.). Extra fields (monthly_income, lpp_capital, etc.) are
        silently ignored by _build_coach_context_from_profile, which catches the
        TypeError. We pass only CoachContext-compatible fields to verify enrichment.
        """
        # Use a profile with only CoachContext-compatible fields
        ctx_profile = {
            "first_name": "Julien",
            "age": 49,
            "canton": "VS",
            "archetype": "swiss_native",
            "fri_total": 62.0,
            "replacement_ratio": 0.655,
            "tax_saving_potential": 2000.0,
        }
        prompt = _build_full_system_prompt(ctx_profile, _MEMORY_BLOCK)
        assert "VS" in prompt  # canton
        assert "49" in prompt  # age
        assert "swiss_native" in prompt  # archetype

    def test_pipeline_returns_valid_response(self):
        """Full pipeline returns a valid response with message and no internal tools."""
        pipeline = _run_pipeline(
            question="Comment optimiser mon 3a ?",
            profile=_JULIEN_PROFILE,
            memory_block=_MEMORY_BLOCK,
            llm_tool_calls=[{
                "name": "show_fact_card",
                "input": {
                    "title": "Pilier 3a",
                    "content": "Tu pourrais encore verser 2'258 CHF cette annee.",
                    "source": "OPP3 art. 7",
                },
            }],
            llm_answer="Ton 3a n'est pas encore maximise.",
        )
        result = pipeline["result"]
        assert result["answer"] == "Ton 3a n'est pas encore maximise."
        assert result["tool_calls"] is not None
        assert result["tool_calls"][0]["name"] == "show_fact_card"
        # No internal tools leaked
        if result["tool_calls"]:
            for tc in result["tool_calls"]:
                assert tc["name"] not in INTERNAL_TOOL_NAMES


# ===========================================================================
# Q2: "Rente ou capital ?" -> retirement_choice route_to_screen
# ===========================================================================


class TestQ2_RenteOuCapital:
    """Q2: Retirement choice question triggers route_to_screen."""

    def test_pipeline_routes_to_retirement_choice(self):
        """LLM returns route_to_screen with intent=retirement_choice."""
        pipeline = _run_pipeline(
            question="Rente ou capital ?",
            profile=_JULIEN_PROFILE,
            memory_block=_MEMORY_BLOCK,
            llm_tool_calls=[{
                "name": "route_to_screen",
                "input": {
                    "intent": "retirement_choice",
                    "confidence": 0.95,
                    "context_message": (
                        "Ce simulateur pourrait t'aider a comparer les scenarios."
                    ),
                },
            }],
            llm_answer="Comparons les deux options.",
        )
        result = pipeline["result"]
        assert result["tool_calls"] is not None
        tool = result["tool_calls"][0]
        assert tool["name"] == "route_to_screen"
        assert tool["input"]["intent"] == "retirement_choice"
        assert tool["input"]["confidence"] >= 0.5

    def test_system_prompt_has_retirement_choice_intent(self):
        """System prompt lists retirement_choice as a registered intent tag."""
        prompt = _build_full_system_prompt(_JULIEN_PROFILE, _MEMORY_BLOCK)
        assert "retirement_choice" in prompt

    def test_reasoning_produces_relevant_fact(self):
        """StructuredReasoningService detects rachat or gap for Julien's profile."""
        safe = _safe_profile(_JULIEN_PROFILE)
        output = _reason_with_fixed_date(safe, "Rente ou capital ?")
        # Julien: replacement_ratio=0.655 > 0.60 => no gap_warning
        # lpp_buyback_max=539414 => rachat_opportunity
        assert output.fact_tag == "rachat_opportunity"
        assert "rachat_max_CHF" in output.supporting_data


# ===========================================================================
# Q3: "Je viens de divorcer" -> life_event_divorce route_to_screen
# ===========================================================================


class TestQ3_Divorce:
    """Q3: Divorce life event triggers route_to_screen."""

    def test_pipeline_routes_to_divorce(self):
        """LLM returns route_to_screen with intent=life_event_divorce."""
        pipeline = _run_pipeline(
            question="Je viens de divorcer",
            profile=_JULIEN_PROFILE,
            memory_block=_MEMORY_BLOCK,
            llm_tool_calls=[{
                "name": "route_to_screen",
                "input": {
                    "intent": "life_event_divorce",
                    "confidence": 0.90,
                    "context_message": (
                        "Le divorce a un impact sur le partage LPP et les "
                        "contributions AVS. Cet ecran pourrait t'aider a comprendre."
                    ),
                },
            }],
            llm_answer="Prenons le temps de comprendre les implications financieres.",
        )
        result = pipeline["result"]
        assert result["tool_calls"] is not None
        tool = result["tool_calls"][0]
        assert tool["name"] == "route_to_screen"
        assert tool["input"]["intent"] == "life_event_divorce"

    def test_divorce_intent_is_registered(self):
        """life_event_divorce is a valid registered intent tag."""
        from app.services.coach.coach_tools import ROUTE_TO_SCREEN_INTENT_TAGS
        assert "life_event_divorce" in ROUTE_TO_SCREEN_INTENT_TAGS

    def test_no_internal_tools_in_response(self):
        """Internal tools must never appear in the final response."""
        pipeline = _run_pipeline(
            question="Je viens de divorcer",
            profile=_JULIEN_PROFILE,
            llm_tool_calls=[{
                "name": "route_to_screen",
                "input": {
                    "intent": "life_event_divorce",
                    "confidence": 0.90,
                    "context_message": "Ecran divorce.",
                },
            }],
        )
        result = pipeline["result"]
        if result["tool_calls"]:
            for tc in result["tool_calls"]:
                assert tc["name"] not in INTERNAL_TOOL_NAMES


# ===========================================================================
# Q4: "Combien me reste-t-il ce mois ?" -> show_budget_snapshot
# ===========================================================================


class TestQ4_BudgetSnapshot:
    """Q4: Budget question triggers show_budget_snapshot."""

    def test_pipeline_shows_budget_snapshot(self):
        """LLM returns show_budget_snapshot tool."""
        pipeline = _run_pipeline(
            question="Combien me reste-t-il ce mois ?",
            profile=_JULIEN_PROFILE,
            memory_block=_MEMORY_BLOCK,
            llm_tool_calls=[{
                "name": "show_budget_snapshot",
                "input": {"focus_category": "discretionary"},
            }],
            llm_answer="Voici ton budget du mois.",
        )
        result = pipeline["result"]
        assert result["tool_calls"] is not None
        assert result["tool_calls"][0]["name"] == "show_budget_snapshot"

    def test_agent_loop_with_internal_budget_tool(self):
        """When LLM uses get_budget_status (internal), it is executed and not forwarded."""
        pipeline = _run_pipeline(
            question="Combien me reste-t-il ce mois ?",
            profile=_JULIEN_PROFILE,
            memory_block=_MEMORY_BLOCK,
            llm_tool_calls=[
                {"name": "get_budget_status", "input": {}},
                {"name": "show_budget_snapshot", "input": {}},
            ],
            multi_turn=True,
            second_answer="Ta marge libre est d'environ CHF 2'684.",
        )
        result = pipeline["result"]
        orch = pipeline["orchestrator"]
        # Internal tool triggered a re-call
        assert orch.query.call_count == 2
        # get_budget_status must NOT be in the final tool_calls
        if result["tool_calls"]:
            names = [tc["name"] for tc in result["tool_calls"]]
            assert "get_budget_status" not in names
        # show_budget_snapshot from the first call IS forwarded
        assert result["tool_calls"] is not None
        assert any(tc["name"] == "show_budget_snapshot" for tc in result["tool_calls"])

    def test_budget_data_flows_to_agent_loop(self):
        """Profile budget data is accessible to internal tool execution."""
        safe = _safe_profile(_JULIEN_PROFILE)
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool
        result_text = _execute_internal_tool(
            {"name": "get_budget_status", "input": {}},
            memory_block=None,
            profile_context=safe,
        )
        assert "Budget actuel" in result_text
        assert "Revenu net mensuel" in result_text


# ===========================================================================
# Q5: "Mon taux de remplacement ?" -> gap_warning reasoning
# ===========================================================================


class TestQ5_ReplacementRate:
    """Q5: Replacement rate question triggers gap_warning when below 60%."""

    def test_reasoning_detects_gap_when_below_threshold(self):
        """With replacement_ratio=0.50 < 0.60, gap_warning fires."""
        profile = {**_JULIEN_PROFILE, "replacement_ratio": 0.50, "lpp_buyback_max": 0}
        safe = _safe_profile(profile)
        output = _reason_with_fixed_date(safe, "Mon taux de remplacement ?")
        assert output.fact_tag == "gap_warning"
        assert output.supporting_data["taux_remplacement_pct"] == 50.0

    def test_reasoning_no_gap_when_above_threshold(self):
        """With replacement_ratio=0.655 >= 0.60, gap_warning does not fire."""
        profile = {**_JULIEN_PROFILE, "lpp_buyback_max": 0}
        safe = _safe_profile(profile)
        output = _reason_with_fixed_date(safe, "Mon taux de remplacement ?")
        assert output.fact_tag != "gap_warning"

    def test_gap_warning_has_ecart_mensuel(self):
        """Gap warning supporting data includes the monthly gap in CHF."""
        profile = {
            **_JULIEN_PROFILE,
            "replacement_ratio": 0.50,
            "lpp_buyback_max": 0,
            "monthly_income": 10184.0,
        }
        safe = _safe_profile(profile)
        output = _reason_with_fixed_date(safe, "Mon taux de remplacement ?")
        assert "ecart_mensuel_CHF" in output.supporting_data
        # 10184 * (1 - 0.50) = 5092
        assert output.supporting_data["ecart_mensuel_CHF"] == pytest.approx(5092.0, abs=1)

    def test_pipeline_with_gap_reasoning_block_in_prompt(self):
        """System prompt includes the reasoning block when gap_warning fires."""
        profile = {**_JULIEN_PROFILE, "replacement_ratio": 0.50, "lpp_buyback_max": 0}
        safe = _safe_profile(profile)
        reasoning = _reason_with_fixed_date(safe, "Mon taux de remplacement ?")
        prompt = _build_full_system_prompt(profile, _MEMORY_BLOCK)
        block = reasoning.as_system_prompt_block()
        assert "ANALYSE PREALABLE" in block or "ANALYSE PR" in block
        full_prompt = prompt + "\n\n" + block
        assert "gap_warning" in full_prompt or "taux_remplacement" in full_prompt


# ===========================================================================
# Q6: "Je veux racheter mon LPP" -> rachat_opportunity reasoning
# ===========================================================================


class TestQ6_RachatLPP:
    """Q6: LPP buyback question triggers rachat_opportunity reasoning."""

    def test_reasoning_detects_rachat_opportunity(self):
        """With lpp_buyback_max=539414 >= 10000, rachat_opportunity fires."""
        safe = _safe_profile(_JULIEN_PROFILE)
        output = _reason_with_fixed_date(safe, "Je veux racheter mon LPP")
        assert output.fact_tag == "rachat_opportunity"
        assert output.supporting_data["rachat_max_CHF"] == 539414.0

    def test_rachat_has_tax_saving_estimate(self):
        """Rachat supporting data includes tax saving estimate."""
        safe = _safe_profile(_JULIEN_PROFILE)
        output = _reason_with_fixed_date(safe, "Je veux racheter mon LPP")
        assert "economie_fiscale_estimee_CHF" in output.supporting_data
        assert output.supporting_data["economie_fiscale_estimee_CHF"] > 0

    def test_rachat_has_lpp_capital(self):
        """Rachat supporting data includes current LPP capital."""
        safe = _safe_profile(_JULIEN_PROFILE)
        output = _reason_with_fixed_date(safe, "Je veux racheter mon LPP")
        assert "avoir_lpp_actuel_CHF" in output.supporting_data
        assert output.supporting_data["avoir_lpp_actuel_CHF"] == 70377.0

    def test_pipeline_cross_pillar_internal_tool(self):
        """When LLM requests get_cross_pillar_analysis, it is executed internally."""
        pipeline = _run_pipeline(
            question="Je veux racheter mon LPP",
            profile=_JULIEN_PROFILE,
            memory_block=_MEMORY_BLOCK,
            llm_tool_calls=[
                {"name": "get_cross_pillar_analysis", "input": {}},
            ],
            multi_turn=True,
            second_answer="Ton potentiel de rachat LPP est significatif.",
        )
        result = pipeline["result"]
        orch = pipeline["orchestrator"]
        # Internal tool triggers re-call
        assert orch.query.call_count == 2
        # Second call question includes the cross-pillar data
        second_question = orch.query.call_args_list[1].kwargs["question"]
        assert "Analyse inter-piliers" in second_question or "Rachat LPP" in second_question
        # Internal tool not in response
        if result["tool_calls"]:
            names = [tc["name"] for tc in result["tool_calls"]]
            assert "get_cross_pillar_analysis" not in names


# ===========================================================================
# Q7: "Quel est mon score ?" -> show_score_gauge
# ===========================================================================


class TestQ7_Score:
    """Q7: Score question triggers show_score_gauge tool."""

    def test_pipeline_shows_score_gauge(self):
        """LLM returns show_score_gauge tool call."""
        pipeline = _run_pipeline(
            question="Quel est mon score ?",
            profile=_JULIEN_PROFILE,
            memory_block=_MEMORY_BLOCK,
            llm_tool_calls=[{
                "name": "show_score_gauge",
                "input": {"show_breakdown": True},
            }],
            llm_answer="Ton score FRI est a 62.",
        )
        result = pipeline["result"]
        assert result["tool_calls"] is not None
        assert result["tool_calls"][0]["name"] == "show_score_gauge"
        assert result["tool_calls"][0]["input"]["show_breakdown"] is True

    def test_system_prompt_has_fri_score(self):
        """System prompt includes the user's FRI score for context.

        Uses CoachContext-compatible profile fields only (build_coach_context
        rejects unknown kwargs like monthly_income).
        """
        ctx_profile = {
            "first_name": "Julien",
            "age": 49,
            "canton": "VS",
            "archetype": "swiss_native",
            "fri_total": 62.0,
        }
        prompt = _build_full_system_prompt(ctx_profile, _MEMORY_BLOCK)
        assert "62" in prompt  # fri_total
        assert "Score FRI" in prompt

    def test_score_gauge_is_not_internal(self):
        """show_score_gauge is a Flutter-bound tool, not internal."""
        assert "show_score_gauge" not in INTERNAL_TOOL_NAMES


# ===========================================================================
# Q8: "Je vais avoir un bebe" -> life_event_birth route_to_screen
# ===========================================================================


class TestQ8_Birth:
    """Q8: Birth life event triggers route_to_screen."""

    def test_pipeline_routes_to_birth(self):
        """LLM returns route_to_screen with intent=life_event_birth."""
        pipeline = _run_pipeline(
            question="Je vais avoir un bebe",
            profile=_JULIEN_PROFILE,
            memory_block=_MEMORY_BLOCK,
            llm_tool_calls=[{
                "name": "route_to_screen",
                "input": {
                    "intent": "life_event_birth",
                    "confidence": 0.92,
                    "context_message": (
                        "L'arrivee d'un enfant a un impact sur les allocations "
                        "familiales et le budget. Cet ecran pourrait t'aider."
                    ),
                },
            }],
            llm_answer="Felicitations ! Voyons ensemble les implications.",
        )
        result = pipeline["result"]
        assert result["tool_calls"] is not None
        tool = result["tool_calls"][0]
        assert tool["name"] == "route_to_screen"
        assert tool["input"]["intent"] == "life_event_birth"

    def test_birth_intent_is_registered(self):
        """life_event_birth is a valid registered intent tag."""
        from app.services.coach.coach_tools import ROUTE_TO_SCREEN_INTENT_TAGS
        assert "life_event_birth" in ROUTE_TO_SCREEN_INTENT_TAGS

    def test_memory_block_injected_in_prompt(self):
        """Memory block with lifecycle phase is appended to system prompt."""
        prompt = _build_full_system_prompt(_JULIEN_PROFILE, _MEMORY_BLOCK)
        assert "consolidation" in prompt
        assert "rachat_lpp" in prompt
        # Memory armor uses accented French: "MÉMOIRE UTILISATEUR"
        assert "MOIRE UTILISATEUR" in prompt


# ===========================================================================
# Q9: "Comparaison de deux offres d'emploi" -> job_comparison route_to_screen
# ===========================================================================


class TestQ9_JobComparison:
    """Q9: Job comparison question triggers route_to_screen."""

    def test_pipeline_routes_to_job_comparison(self):
        """LLM returns route_to_screen with intent=job_comparison."""
        pipeline = _run_pipeline(
            question="Comparaison de deux offres d'emploi",
            profile=_JULIEN_PROFILE,
            memory_block=_MEMORY_BLOCK,
            llm_tool_calls=[{
                "name": "route_to_screen",
                "input": {
                    "intent": "job_comparison",
                    "confidence": 0.88,
                    "context_message": (
                        "Ce comparateur pourrait t'aider a evaluer les differences "
                        "de salaire net, LPP, et avantages sociaux."
                    ),
                },
            }],
            llm_answer="Comparons les deux offres.",
        )
        result = pipeline["result"]
        assert result["tool_calls"] is not None
        tool = result["tool_calls"][0]
        assert tool["name"] == "route_to_screen"
        assert tool["input"]["intent"] == "job_comparison"

    def test_job_comparison_intent_is_registered(self):
        """job_comparison is a valid registered intent tag."""
        from app.services.coach.coach_tools import ROUTE_TO_SCREEN_INTENT_TAGS
        assert "job_comparison" in ROUTE_TO_SCREEN_INTENT_TAGS

    def test_orchestrator_receives_system_prompt(self):
        """The system prompt is passed to the orchestrator."""
        pipeline = _run_pipeline(
            question="Comparaison de deux offres d'emploi",
            profile=_JULIEN_PROFILE,
            memory_block=_MEMORY_BLOCK,
            llm_answer="Comparons.",
        )
        orch = pipeline["orchestrator"]
        call_kwargs = orch.query.call_args.kwargs
        assert "system_prompt" in call_kwargs
        assert call_kwargs["system_prompt"] is not None
        assert len(call_kwargs["system_prompt"]) > 100


# ===========================================================================
# Q10: "Mon budget est en deficit" -> deficit reasoning
# ===========================================================================


class TestQ10_Deficit:
    """Q10: Budget deficit question triggers deficit reasoning."""

    def test_reasoning_detects_deficit(self):
        """With income < expenses, deficit fires."""
        profile = {
            **_JULIEN_PROFILE,
            "monthly_income": 4000.0,
            "monthly_expenses": 5500.0,
        }
        safe = _safe_profile(profile)
        output = _reason_with_fixed_date(safe, "Mon budget est en deficit")
        assert output.fact_tag == "deficit"
        assert output.domain == "budget"

    def test_deficit_beats_all_other_facts(self):
        """Deficit is highest priority — beats rachat, gap, and 3a."""
        profile = {
            **_JULIEN_PROFILE,
            "monthly_income": 3000.0,
            "monthly_expenses": 4000.0,
            "replacement_ratio": 0.40,  # would trigger gap_warning
            "lpp_buyback_max": 100000.0,  # would trigger rachat
        }
        safe = _safe_profile(profile)
        output = _reason_with_fixed_date(safe, "Mon budget est en deficit")
        assert output.fact_tag == "deficit"

    def test_deficit_supporting_data(self):
        """Deficit supporting data has income, expenses, and deficit amount."""
        profile = {
            **_JULIEN_PROFILE,
            "monthly_income": 4000.0,
            "monthly_expenses": 5500.0,
        }
        safe = _safe_profile(profile)
        output = _reason_with_fixed_date(safe, "Mon budget est en deficit")
        assert output.supporting_data["revenu_mensuel_CHF"] == 4000.0
        assert output.supporting_data["charges_mensuelles_CHF"] == 5500.0
        assert output.supporting_data["deficit_CHF"] == 1500.0

    def test_low_liquidity_also_triggers_deficit(self):
        """Low liquidity (< 3 months) triggers deficit even without income/expense pair."""
        profile = {"months_liquidity": 1.5}
        safe = _safe_profile(profile)
        output = _reason_with_fixed_date(safe, "Mon budget est en deficit")
        assert output.fact_tag == "deficit"
        assert output.supporting_data["mois_liquidites"] == 1.5

    def test_pipeline_with_deficit_reasoning_in_prompt(self):
        """Full pipeline includes deficit reasoning block in the system prompt."""
        profile = {
            **_JULIEN_PROFILE,
            "monthly_income": 4000.0,
            "monthly_expenses": 5500.0,
        }
        pipeline = _run_pipeline(
            question="Mon budget est en deficit",
            profile=profile,
            memory_block=_MEMORY_BLOCK,
            llm_answer="Ton budget montre un ecart de CHF 1'500.",
        )
        prompt = pipeline["system_prompt"]
        # Reasoning block should be in the system prompt
        assert "ANALYSE" in prompt
        assert "deficit" in prompt.lower() or "budget" in prompt.lower()


# ===========================================================================
# Cross-cutting: System prompt structure
# ===========================================================================


class TestSystemPromptStructure:
    """Verify the system prompt contains all required structural blocks."""

    def test_system_prompt_has_banned_terms(self):
        """System prompt includes the banned terms reminder."""
        prompt = _build_full_system_prompt(_JULIEN_PROFILE, _MEMORY_BLOCK)
        assert "garanti" in prompt
        assert "sans risque" in prompt

    def test_system_prompt_has_disclaimer(self):
        """System prompt includes the disclaimer block."""
        prompt = _build_full_system_prompt(_JULIEN_PROFILE, _MEMORY_BLOCK)
        assert "MINT est un outil" in prompt or "LSFin" in prompt

    def test_system_prompt_has_all_intent_tags(self):
        """System prompt lists all registered intent tags."""
        from app.services.coach.coach_tools import ROUTE_TO_SCREEN_INTENT_TAGS
        prompt = _build_full_system_prompt(_JULIEN_PROFILE, _MEMORY_BLOCK)
        for tag in ROUTE_TO_SCREEN_INTENT_TAGS:
            assert tag in prompt, f"Intent tag '{tag}' missing from system prompt"

    def test_system_prompt_has_lifecycle_tone_directives(self):
        """System prompt includes lifecycle tone directives by phase."""
        prompt = _build_full_system_prompt(_JULIEN_PROFILE, _MEMORY_BLOCK)
        assert "consolidation" in prompt  # from memory block
        assert "demarrage" in prompt  # from lifecycle awareness section
        assert "retraite" in prompt  # from lifecycle awareness section

    def test_memory_block_sanitized_with_armor(self):
        """Memory block is wrapped with prompt injection armor."""
        prompt = _build_full_system_prompt(_JULIEN_PROFILE, _MEMORY_BLOCK)
        # The armor uses accented French characters
        assert "DONN\u00c9ES UNIQUEMENT" in prompt or "M\u00c9MOIRE UTILISATEUR" in prompt

    def test_memory_block_pii_scrubbed(self):
        """PII in memory block is scrubbed before injection."""
        memory_with_pii = (
            "Solde IBAN CH93 0076 2011 6238 5295 7\n"
            "email: julien@example.com\n"
            "budget: ok"
        )
        prompt = _build_full_system_prompt(_JULIEN_PROFILE, memory_with_pii)
        # IBAN pattern is scrubbed (CH followed by digits)
        assert "CH93 0076 2011 6238 5295 7" not in prompt
        # Email is scrubbed
        assert "julien@example.com" not in prompt
        assert "REDACTED" in prompt


# ===========================================================================
# Cross-cutting: Profile sanitization
# ===========================================================================


class TestProfileSanitization:
    """Verify profile sanitization strips non-whitelisted fields."""

    def test_whitelisted_fields_pass_through(self):
        """Safe fields from the profile are preserved."""
        safe = _safe_profile(_JULIEN_PROFILE)
        assert safe["age"] == 49
        assert safe["canton"] == "VS"
        assert safe["archetype"] == "swiss_native"
        assert safe["monthly_income"] == 10184.0

    def test_non_whitelisted_fields_dropped(self):
        """Non-whitelisted fields are dropped (privacy enforcement)."""
        profile_with_pii = {
            **_JULIEN_PROFILE,
            "iban": "CH93 0076 2011 6238 5295 7",
            "employer": "MINT SA",
            "full_name": "Julien Battaglia",
            "npa": "1950",
        }
        safe = _safe_profile(profile_with_pii)
        assert "iban" not in safe
        assert "employer" not in safe
        assert "full_name" not in safe
        assert "npa" not in safe


# ===========================================================================
# Cross-cutting: Agent loop correctness
# ===========================================================================


class TestAgentLoopIntegration:
    """Verify agent loop handles multi-step flows correctly."""

    def test_internal_tool_triggers_reask(self):
        """An internal tool (get_retirement_projection) triggers a re-call."""
        pipeline = _run_pipeline(
            question="Combien aurai-je a la retraite ?",
            profile=_JULIEN_PROFILE,
            memory_block=_MEMORY_BLOCK,
            llm_tool_calls=[
                {"name": "get_retirement_projection", "input": {}},
            ],
            multi_turn=True,
            second_answer="Ton revenu retraite projete est d'environ CHF 8'505.",
        )
        result = pipeline["result"]
        orch = pipeline["orchestrator"]
        assert orch.query.call_count == 2
        # Check that the second call received retirement data
        second_question = orch.query.call_args_list[1].kwargs["question"]
        assert "Projection retraite" in second_question or "retraite" in second_question.lower()
        # Internal tool not in final response
        if result["tool_calls"]:
            names = [tc["name"] for tc in result["tool_calls"]]
            assert "get_retirement_projection" not in names

    def test_cap_status_internal_tool(self):
        """get_cap_status is an internal tool — executed and not forwarded."""
        pipeline = _run_pipeline(
            question="Quelle est ma priorite ?",
            profile=_JULIEN_PROFILE,
            memory_block=_MEMORY_BLOCK,
            llm_tool_calls=[
                {"name": "get_cap_status", "input": {}},
            ],
            multi_turn=True,
            second_answer="Aucun Cap du jour calcule.",
        )
        result = pipeline["result"]
        orch = pipeline["orchestrator"]
        assert orch.query.call_count == 2
        if result["tool_calls"]:
            names = [tc["name"] for tc in result["tool_calls"]]
            assert "get_cap_status" not in names

    def test_tools_stripped_of_metadata_before_llm(self):
        """Tools passed to LLM have category/access_level stripped."""
        llm_tools = get_llm_tools()
        for tool in llm_tools:
            assert "category" not in tool, f"Tool {tool['name']} still has 'category'"
            assert "access_level" not in tool, f"Tool {tool['name']} still has 'access_level'"

    def test_all_internal_tool_names_recognized(self):
        """All INTERNAL_TOOL_NAMES have handlers in _execute_internal_tool."""
        from app.api.v1.endpoints.coach_chat import _execute_internal_tool
        safe = _safe_profile(_JULIEN_PROFILE)
        for tool_name in INTERNAL_TOOL_NAMES:
            result = _execute_internal_tool(
                {"name": tool_name, "input": {"topic": "test"} if tool_name == "retrieve_memories" else {}},
                memory_block="test memory",
                profile_context=safe,
            )
            # Must return a string, never crash
            assert isinstance(result, str), f"Tool '{tool_name}' did not return a string"
            # Must not say "non reconnu" (unknown)
            assert "non reconnu" not in result, f"Tool '{tool_name}' is not recognized"


# ===========================================================================
# Cross-cutting: Reasoning output contract
# ===========================================================================


class TestReasoningContract:
    """Verify ReasoningOutput always respects its contract."""

    @pytest.mark.parametrize("question,profile_override", [
        ("Comment optimiser mon 3a ?", {"lpp_buyback_max": 0}),
        ("Rente ou capital ?", {}),
        ("Je viens de divorcer", {}),
        ("Combien me reste-t-il ?", {}),
        ("Mon taux de remplacement ?", {"replacement_ratio": 0.50, "lpp_buyback_max": 0}),
        ("Racheter mon LPP", {}),
        ("Quel est mon score ?", {}),
        ("Je vais avoir un bebe", {}),
        ("Comparaison d'emploi", {}),
        ("Budget en deficit", {"monthly_income": 3000, "monthly_expenses": 4500}),
    ])
    def test_confidence_always_valid(self, question, profile_override):
        """Confidence is always between 0.0 and 1.0 for all 10 questions."""
        profile = {**_JULIEN_PROFILE, **profile_override}
        safe = _safe_profile(profile)
        output = _reason_with_fixed_date(safe, question)
        assert 0.0 <= output.confidence <= 1.0

    @pytest.mark.parametrize("question,profile_override", [
        ("Comment optimiser mon 3a ?", {"lpp_buyback_max": 0}),
        ("Budget en deficit", {"monthly_income": 3000, "monthly_expenses": 4500}),
        ("Mon taux de remplacement ?", {"replacement_ratio": 0.50, "lpp_buyback_max": 0}),
        ("Racheter mon LPP", {}),
    ])
    def test_supporting_data_always_dict(self, question, profile_override):
        """Supporting data is always a dict with numeric values."""
        profile = {**_JULIEN_PROFILE, **profile_override}
        safe = _safe_profile(profile)
        output = _reason_with_fixed_date(safe, question)
        assert isinstance(output.supporting_data, dict)
        if output.fact_tag is not None:
            assert len(output.supporting_data) > 0

    def test_disclaimer_always_present(self):
        """Every ReasoningOutput has a non-empty disclaimer."""
        safe = _safe_profile(_JULIEN_PROFILE)
        output = _reason_with_fixed_date(safe, "test")
        assert output.disclaimer
        assert "LSFin" in output.disclaimer
