"""
Coach Chat endpoint — Sprint S56+.

POST /api/v1/coach/chat

Dedicated coach chat endpoint that combines:
    1. System prompt from claude_coach_service (lifecycle + regional + plan awareness)
    2. Tools from coach_tools.py (route_to_screen, show_*, ask_user_input)
    3. RAG retrieval (FAQ fallback + cantonal enrichment)
    4. Compliance filter on all LLM output (ComplianceGuard)

Architecture:
    - The LLM decides intent; Flutter decides routing (RoutePlanner + ScreenRegistry).
    - The backend never emits raw navigation routes.
    - All LLM output passes through ComplianceGuard before reaching the user.
    - CoachContext is built from profile_context + memory_block (aggregated, non-identifying).
    - RAG retrieval enriches responses with MINT knowledge base content.

Compliance:
    - LSFin art. 3 (information financiere)
    - LPD art. 6 (protection des donnees)
    - FINMA circular 2008/21

Sources:
    - docs/BLUEPRINT_COACH_AI_LAYER.md
    - docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §6
"""

from __future__ import annotations

import logging
import os
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.auth import require_current_user
from app.core.rate_limit import limiter
from app.models.user import User
from app.schemas.coach_chat import CoachChatRequest, CoachChatResponse
from app.services.coach.claude_coach_service import COACH_TOOLS, build_system_prompt
from app.services.coach.coach_context_builder import build_coach_context

logger = logging.getLogger(__name__)

router = APIRouter()

# Lazy-initialized singletons (mirrors rag.py pattern)
_vector_store = None
_orchestrator = None


# ---------------------------------------------------------------------------
# Lazy RAG initialization — fails gracefully when chromadb is absent
# ---------------------------------------------------------------------------


def _get_vector_store():
    """Get or create the singleton vector store instance."""
    global _vector_store
    if _vector_store is None:
        try:
            from app.services.rag.vector_store import MintVectorStore

            backend_dir = os.path.dirname(
                os.path.dirname(
                    os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
                )
            )
            persist_dir = os.path.join(backend_dir, "data", "chromadb")
            _vector_store = MintVectorStore(persist_directory=persist_dir)
        except ImportError:
            raise HTTPException(
                status_code=503,
                detail="RAG dependencies not installed. Install with: pip install -e '.[rag]'",
            )
    return _vector_store


def _get_orchestrator():
    """Get or create the singleton RAG orchestrator instance."""
    global _orchestrator
    if _orchestrator is None:
        try:
            from app.services.rag.orchestrator import RAGOrchestrator

            _orchestrator = RAGOrchestrator(vector_store=_get_vector_store())
        except ImportError:
            raise HTTPException(
                status_code=503,
                detail="RAG dependencies not installed. Install with: pip install -e '.[rag]'",
            )
    return _orchestrator


# ---------------------------------------------------------------------------
# Context builder helpers
# ---------------------------------------------------------------------------


def _build_coach_context_from_profile(profile_context: Optional[dict]):
    """Build a CoachContext from a raw profile_context dict.

    Extracts only the fields recognized by CoachContext; unknown keys are
    forwarded as known_values for hallucination detection.

    Privacy: never includes IBAN, full name, NPA, or employer.
    """
    if not profile_context:
        return None

    _KNOWN_FIELDS = {
        "first_name", "archetype", "age", "canton",
        "fri_total", "fri_delta", "primary_focus",
        "replacement_ratio", "months_liquidity", "tax_saving_potential",
        "confidence_score", "days_since_last_visit", "fiscal_season",
        "upcoming_event", "check_in_streak", "last_milestone",
    }

    kwargs = {k: v for k, v in profile_context.items() if k in _KNOWN_FIELDS and v is not None}
    # Privacy: unknown fields are DROPPED, not forwarded.
    # This prevents PII leakage if Flutter sends unexpected fields (e.g. employer).

    try:
        return build_coach_context(**kwargs)
    except Exception as exc:
        logger.warning("Could not build CoachContext from profile_context: %s", exc)
        return None


def _build_system_prompt_with_memory(
    coach_ctx,
    memory_block: Optional[str],
) -> str:
    """Build the system prompt and optionally append the memory block.

    The memory block is injected verbatim after the system prompt so the LLM
    can access lifecycle phase, regional voice, and plan state.
    """
    prompt = build_system_prompt(ctx=coach_ctx)
    if memory_block and memory_block.strip():
        prompt = prompt + "\n\n--- MÉMOIRE UTILISATEUR ---\n" + memory_block.strip()
    return prompt


# ---------------------------------------------------------------------------
# Main endpoint
# ---------------------------------------------------------------------------


@router.post("/chat", response_model=CoachChatResponse)
@limiter.limit("30/minute")
async def coach_chat(
    request: Request,
    body: CoachChatRequest,
    _user: User = Depends(require_current_user),
) -> CoachChatResponse:
    """Coach chat endpoint — tools + system prompt + RAG.

    Combines:
        1. System prompt (lifecycle + regional voice + plan awareness)
        2. Coach tools (route_to_screen, show_*, ask_user_input)
        3. RAG retrieval (FAQ fallback + cantonal enrichment)
        4. ComplianceGuard filter on all LLM output

    The API key is used for a single request and is never stored by MINT.

    Returns:
        CoachChatResponse with message, optional tool_calls, sources,
        disclaimers, and token usage.

    Raises:
        400: Invalid request (missing fields, malformed provider).
        401: Authentication required.
        502: LLM API call failed.
        503: RAG dependencies not installed.
    """
    # ------------------------------------------------------------------
    # Step 1: Build CoachContext from profile_context
    # ------------------------------------------------------------------
    coach_ctx = _build_coach_context_from_profile(body.profile_context)

    # ------------------------------------------------------------------
    # Step 2: Build system prompt (lifecycle + regional + plan + memory)
    # ------------------------------------------------------------------
    system_prompt = _build_system_prompt_with_memory(coach_ctx, body.memory_block)

    # ------------------------------------------------------------------
    # Step 3: Get RAG orchestrator and execute the full pipeline
    # Tools are passed so the LLM may return tool_use blocks alongside text.
    # ------------------------------------------------------------------
    try:
        orchestrator = _get_orchestrator()
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("RAG orchestrator initialization failed: %s", exc)
        raise HTTPException(status_code=503, detail="RAG service unavailable")

    # Build profile context dict for retriever personalization (language, canton)
    retriever_ctx = body.profile_context or {}

    try:
        result = await orchestrator.query(
            question=body.message,
            api_key=body.api_key,
            provider=body.provider,
            model=body.model,
            profile_context=retriever_ctx,
            language=body.language,
            tools=COACH_TOOLS,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except ImportError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        logger.error("Coach chat LLM call failed: %s", exc)
        raise HTTPException(
            status_code=502,
            detail=f"LLM API call failed: {str(exc)}",
        )

    # ------------------------------------------------------------------
    # Step 4: Build structured response
    # The orchestrator already ran ComplianceGuard (guardrails.filter_response).
    # tool_calls are returned as-is for Flutter to handle.
    # ------------------------------------------------------------------
    return CoachChatResponse(
        message=result.get("answer", ""),
        tool_calls=result.get("tool_calls"),
        sources=result.get("sources", []),
        disclaimers=result.get("disclaimers", []),
        tokens_used=result.get("tokens_used", 0),
        system_prompt_used=True,
    )
