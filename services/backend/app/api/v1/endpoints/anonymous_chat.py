"""
Anonymous Chat endpoint — Phase 13.

POST /api/v1/anonymous/chat

Public endpoint for anonymous discovery chat. No authentication required.
Rate-limited to 3 messages per device token (lifetime).

Uses a stripped-down "mode decouverte" system prompt:
    - Layer 1-2 insights only (factual + human translation)
    - No tools, no profile, no memory, no dossier
    - Compliance filtering via ComplianceGuardrails

Architecture:
    - Separate from authenticated coach_chat — no shared auth deps
    - DB-backed session tracking (AnonymousSession model)
    - Device token via X-Anonymous-Session header (UUID format)
    - IP-based secondary rate limit via slowapi

Compliance:
    - LSFin art. 3 (information financiere)
    - LPD art. 6 (protection des donnees)

Threat mitigations:
    - T-13-01: UUID format validation on session header
    - T-13-02: Pydantic validator + PII scrubbing
    - T-13-03: 3-message lifetime + IP slowapi
    - T-13-05: Discovery prompt written from scratch (no tool/profile/memory refs)
    - T-13-06: Separate router, no auth deps, separate DB model
"""

from __future__ import annotations

import logging
import os
import re
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.rate_limit import limiter
from app.models.anonymous_session import AnonymousSession
from app.schemas.anonymous_chat import AnonymousChatRequest, AnonymousChatResponse

logger = logging.getLogger(__name__)

router = APIRouter()

# Maximum messages per anonymous session (lifetime)
MAX_ANONYMOUS_MESSAGES = 3

# UUID format regex for session ID validation (T-13-01)
_UUID_RE = re.compile(r"^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$")

# PII patterns (same as coach_chat.py — defense in depth)
_PII_PATTERNS = [
    re.compile(r"CH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{1}"),  # IBAN
    re.compile(r"\b756[.\s]?\d{4}[.\s]?\d{4}[.\s]?\d{2}\b"),  # AHV/AVS
    re.compile(r"\b\d{4,7}\s*(?:CHF|francs?)\b", re.IGNORECASE),  # salary
]


def _scrub_pii(text: str) -> str:
    """Remove PII patterns from text (defense-in-depth)."""
    for pattern in _PII_PATTERNS:
        text = pattern.sub("[***]", text)
    return text


# ---------------------------------------------------------------------------
# Discovery system prompt — written from scratch (T-13-05)
# ---------------------------------------------------------------------------


def build_discovery_system_prompt(
    intent: str | None = None,
    language: str = "fr",
) -> str:
    """Build the discovery system prompt for anonymous users.

    This prompt is intentionally minimal and written from scratch (NOT derived
    from the authenticated coach system prompt). It contains NO references to:
    - Any available functions or capabilities
    - User data, accounts, or saved information
    - Conversation history or past interactions
    - Any internal system or feature names

    Threat mitigation T-13-05: prevents information disclosure about
    authenticated capabilities.
    """
    # Base identity and rules
    prompt_parts = [
        "Tu es MINT, un compagnon de lucidite financiere suisse.",
        "",
        "Contexte : mode decouverte. La personne n'a pas encore de compte.",
        "Tu ne sais rien sur elle. Tu ne disposes d'aucune donnee personnelle.",
        "",
    ]

    # Intent injection (if user selected a felt-state pill)
    if intent:
        prompt_parts.append(
            f"La personne a exprime ce sentiment : \u00ab\u202f{intent}\u202f\u00bb."
        )
        prompt_parts.append(
            "Utilise ce sentiment comme point de depart pour ta reponse."
        )
        prompt_parts.append("")

    # Rules and constraints
    prompt_parts.extend([
        "Regles strictes :",
        "- Reponds avec un insight surprenant sur la finance suisse (un fait, un angle mort, une implication concrete).",
        "- Couche 1 (fait) + couche 2 (traduction humaine) uniquement.",
        "- Tutoie. Ton calme, precis, fin, rassurant, net.",
        "- Maximum 1 question de relance a la fin.",
        "- Jamais de recommandation de produit specifique.",
        "- Jamais de promesse de rendement ni de certitude sur les resultats.",
        "- Jamais de comparaison sociale ('top X%').",
        "- Jamais de langage absolu ou prescriptif. Utilise le conditionnel.",
        "- Reponse courte (3-5 phrases max).",
        "",
        "Objectif : surprendre la personne avec un eclairage qu'elle ne connaissait pas.",
    ])

    return "\n".join(prompt_parts)


# ---------------------------------------------------------------------------
# Minimal orchestrator for anonymous chat (no RAG, no tools)
# ---------------------------------------------------------------------------


class _NoRagOrchestrator:
    """Minimal LLM orchestrator for anonymous discovery chat.

    Same interface as coach_chat._NoRagOrchestrator but even simpler:
    no tools, no RAG, no profile context.
    """

    async def query(
        self,
        question: str,
        system_prompt: str,
        api_key: str,
        provider: str = "claude",
        model: Optional[str] = None,
        language: str = "fr",
    ) -> dict:
        from app.services.rag.llm_client import LLMClient
        from app.services.rag.guardrails import ComplianceGuardrails

        llm_client = LLMClient(provider=provider, api_key=api_key, model=model)
        guardrails = ComplianceGuardrails()

        raw_response = await llm_client.generate(
            system_prompt=system_prompt,
            user_message=question,
            context_chunks=[],
            tools=None,
        )

        if isinstance(raw_response, dict):
            response_text = raw_response.get("text", "")
            actual_usage_tokens = raw_response.get("usage_tokens")
        else:
            response_text = raw_response

        filtered = guardrails.filter_response(response_text, language)
        tokens_used = (
            actual_usage_tokens
            if isinstance(raw_response, dict) and raw_response.get("usage_tokens") is not None
            else len(question) // 4
        )

        return {
            "answer": filtered["text"],
            "sources": [],
            "disclaimers": filtered["disclaimers_added"],
            "tokens_used": tokens_used,
        }


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------


@router.post("/chat", response_model=AnonymousChatResponse)
@limiter.limit("10/minute")
async def anonymous_chat(
    request: Request,
    body: AnonymousChatRequest,
    db: Session = Depends(get_db),
) -> AnonymousChatResponse:
    """Anonymous discovery chat with device-scoped rate limiting.

    Requires X-Anonymous-Session header (UUID format).
    Limited to 3 messages per device token (lifetime).
    Uses stripped-down discovery system prompt (no tools, no profile).
    """
    # --- Step 1: Extract and validate session header (T-13-01) ---
    session_id = request.headers.get("X-Anonymous-Session")
    if not session_id:
        raise HTTPException(
            status_code=400,
            detail="Session anonyme requise. Envoie le header X-Anonymous-Session.",
        )

    session_id = session_id.strip().lower()
    if not _UUID_RE.match(session_id):
        raise HTTPException(
            status_code=400,
            detail="Format de session invalide. Un UUID est requis.",
        )

    # --- Step 2: Check/create session and enforce rate limit (T-13-03) ---
    anon_session = db.query(AnonymousSession).filter(
        AnonymousSession.session_id == session_id
    ).first()

    if not anon_session:
        anon_session = AnonymousSession(session_id=session_id, message_count=0)
        db.add(anon_session)
        db.flush()

    if anon_session.message_count >= MAX_ANONYMOUS_MESSAGES:
        raise HTTPException(
            status_code=429,
            detail="Limite atteinte. Cree un compte pour continuer.",
        )

    # --- Step 3: Scrub PII from input (T-13-02) ---
    clean_message = _scrub_pii(body.message)

    # --- Step 4: Build discovery system prompt (T-13-05) ---
    discovery_prompt = build_discovery_system_prompt(
        intent=body.intent,
        language=body.language,
    )

    # --- Step 5: Call LLM ---
    server_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not server_key:
        raise HTTPException(
            status_code=503,
            detail="Service temporairement indisponible.",
        )

    orchestrator = _NoRagOrchestrator()
    result = await orchestrator.query(
        question=clean_message,
        system_prompt=discovery_prompt,
        api_key=server_key,
        provider="claude",
        language=body.language,
    )

    # --- Step 6: Increment message count ---
    anon_session.message_count += 1
    db.commit()

    new_count = anon_session.message_count
    messages_remaining = MAX_ANONYMOUS_MESSAGES - new_count

    # --- Step 7: Return response ---
    return AnonymousChatResponse(
        message=result["answer"],
        disclaimers=result["disclaimers"],
        messages_remaining=messages_remaining,
        tokens_used=result["tokens_used"],
    )
