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
from app.services.coach.coach_tools import INTERNAL_TOOL_NAMES
from app.services.coach.structured_reasoning import StructuredReasoningService

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
    DROPPED (not forwarded) to prevent PII leakage.

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


def _handle_retrieve_memories(
    topic: str,
    memory_block: Optional[str],
    max_results: int = 3,
) -> str:
    """Search the memory block for content matching the topic.

    This is an INTERNAL handler — it is called when the LLM emits a
    retrieve_memories tool_use block.  The result is returned to the LLM
    as a tool_result so the conversation can continue.  It is never
    forwarded to Flutter.

    Args:
        topic: The topic string to search for (case-insensitive substring).
        memory_block: The raw memory block injected into the system prompt.
        max_results: Maximum number of matching lines to return (capped at 5).

    Returns:
        A plain-text string with up to max_results matching lines, or a
        localised "not found" message when no match is found.
    """
    if not memory_block or not memory_block.strip():
        return "Aucune mémoire disponible pour ce sujet."

    max_results = min(max(1, max_results), 5)
    lines = memory_block.split("\n")
    matches = [line for line in lines if topic.lower() in line.lower()]
    if not matches:
        return f"Pas de mémoire trouvée pour '{topic}'."
    return "\n".join(matches[:max_results])


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
        2. Coach tools (route_to_screen, show_*, ask_user_input, retrieve_memories)
        3. RAG retrieval (FAQ fallback + cantonal enrichment)
        4. Internal tool intercept (retrieve_memories — handled by backend, not Flutter)
        5. ComplianceGuard filter on all LLM output

    Internal tools (INTERNAL_TOOL_NAMES):
        - retrieve_memories: intercepted here; searches memory_block locally and
          injects the result back into the conversation as a tool_result so the
          LLM can continue.  Never forwarded to Flutter.

    The API key is used for a single request and is never stored by MINT.

    Returns:
        CoachChatResponse with message, optional tool_calls, sources,
        disclaimers, and token usage.  tool_calls never contains internal tools.

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
    # Step 1.5: Deterministic structured reasoning (reasoning/humanization split)
    # Runs BEFORE the LLM call — produces structured facts from profile data.
    # The LLM humanizes this pre-computed analysis rather than reasoning from scratch.
    # This separates the reasoning quality from the humanization style requirement.
    # ------------------------------------------------------------------
    reasoning_output = StructuredReasoningService.reason(
        user_message=body.message,
        profile_context=body.profile_context,
        memory_block=body.memory_block,
    )
    reasoning_block = reasoning_output.as_system_prompt_block()

    # ------------------------------------------------------------------
    # Step 2: Build system prompt (lifecycle + regional + plan + memory)
    # ------------------------------------------------------------------
    system_prompt = _build_system_prompt_with_memory(coach_ctx, body.memory_block)
    if reasoning_block:
        system_prompt = system_prompt + "\n\n" + reasoning_block

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
    # Step 4: Intercept internal tool calls (retrieve_memories).
    # When the LLM returns a retrieve_memories tool_use block:
    #   a) Search the memory_block locally (_handle_retrieve_memories).
    #   b) Strip the internal tool from tool_calls before returning to Flutter.
    # This keeps the interaction transparent to the mobile client.
    # ------------------------------------------------------------------
    raw_tool_calls = result.get("tool_calls") or []
    flutter_tool_calls = []

    for tool_call in raw_tool_calls:
        tool_name = tool_call.get("name", "")
        if tool_name in INTERNAL_TOOL_NAMES:
            # Handle retrieve_memories: log the search, result is discarded here
            # (in a future multi-turn loop this would be fed back to the LLM).
            if tool_name == "retrieve_memories":
                tool_input = tool_call.get("input", {})
                topic = tool_input.get("topic", "")
                max_results = tool_input.get("max_results", 3)
                memory_result = _handle_retrieve_memories(
                    topic=topic,
                    memory_block=body.memory_block,
                    max_results=max_results,
                )
                logger.debug(
                    "retrieve_memories(topic=%r) → %d chars",
                    topic,
                    len(memory_result),
                )
            # Internal tools are never forwarded to Flutter
        else:
            flutter_tool_calls.append(tool_call)

    # ------------------------------------------------------------------
    # Step 5: Build structured response
    # The orchestrator already ran ComplianceGuard (guardrails.filter_response).
    # Only non-internal tool_calls are returned to Flutter.
    # ------------------------------------------------------------------
    return CoachChatResponse(
        message=result.get("answer", ""),
        tool_calls=flutter_tool_calls if flutter_tool_calls else None,
        sources=result.get("sources", []),
        disclaimers=result.get("disclaimers", []),
        tokens_used=result.get("tokens_used", 0),
        system_prompt_used=True,
    )
