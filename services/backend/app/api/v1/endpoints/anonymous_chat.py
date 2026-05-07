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
from app.schemas.anonymous_chat import (
    AnonymousChatRequest,
    AnonymousChatResponse,
    EclairagePayload,
)
from app.services.coach.anonymous_eclairage_prompt import (
    build_default_fiscal_margin_3a_eclairage,
)

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
        "Tu es MINT, un compagnon de lucidit\u00e9 financi\u00e8re suisse.",
        "",
        "Contexte : mode d\u00e9couverte. La personne n'a pas encore de compte.",
        "Tu ne disposes d'aucune donn\u00e9e biographique pr\u00e9alable sur elle.",
        "",
    ]

    # Intent injection (if user selected a felt-state pill)
    if intent:
        prompt_parts.append(
            f"La personne a exprim\u00e9 ce sentiment : \u00ab\u202f{intent}\u202f\u00bb."
        )
        prompt_parts.append(
            "Utilise ce sentiment comme point de d\u00e9part pour ta r\u00e9ponse."
        )
        prompt_parts.append("")

    # Rules and constraints
    prompt_parts.extend([
        "R\u00e8gles strictes :",
        "- R\u00e9ponds avec un insight surprenant sur la finance suisse (un fait, un angle mort, une implication concr\u00e8te).",
        "- Couche 1 (fait) + couche 2 (traduction humaine) uniquement.",
        "- Tutoie. Ton calme, pr\u00e9cis, fin, rassurant, net.",
        "- Si la personne mentionne un chiffre dans son message (\u00ab 7500 CHF \u00bb, \u00ab 850k \u00bb, \u00ab 4.2 % \u00bb), utilise ce chiffre comme ancre. Ne dis jamais que tu ne sais pas alors qu'elle vient de te le dire.",
        "- Si tu cites un chiffre suisse (taux, plafond, m\u00e9diane) qui ne provient pas du message, encadre-le explicitement comme \u00ab ordre de grandeur \u00bb et n'avance jamais une valeur exacte sans la qualifier.",
        "- Ne reproduis jamais textuellement un IBAN, un num\u00e9ro AVS ou un montant exact que la personne aurait \u00e9crit \u2014 paraphrase-le.",
        "- Maximum 1 question de relance \u00e0 la fin.",
        "- Jamais de recommandation de produit sp\u00e9cifique.",
        "- Jamais de promesse de rendement ni de certitude sur les r\u00e9sultats.",
        "- Jamais de comparaison sociale (\u00ab top X % \u00bb).",
        "- Jamais de langage absolu ou prescriptif. Utilise le conditionnel.",
        "- Termes interdits : \u00ab garanti \u00bb, \u00ab optimal \u00bb, \u00ab meilleur \u00bb, \u00ab certain \u00bb, \u00ab assur\u00e9 \u00bb, \u00ab sans risque \u00bb, \u00ab parfait \u00bb. Pr\u00e9f\u00e8re \u00ab pourrait \u00bb, \u00ab envisager \u00bb, \u00ab adapt\u00e9 \u00bb.",
        "- R\u00e9ponse courte (3-5 phrases max).",
        "",
        "Objectif : surprendre la personne avec un \u00e9clairage qu'elle ne connaissait pas.",
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

    # --- Step 3: Scrub PII for downstream artifacts only (T-13-02) ---
    # The scrub redacts IBAN / AVS-AHV / `\d{4,7} CHF` patterns. It is
    # used for any artefact that persists beyond the live conversation
    # (audit log hash, future Sentry / Anthropic log surfaces). It is
    # NOT applied to the LLM input — the user is voluntarily sharing
    # numbers (salary, savings, project amounts) and the assistant
    # needs them to give a personalized answer. Pre-LLM scrubbing
    # was a P0 walker bug: the LLM responded « je ne peux pas voir ton
    # salaire (il apparaît masqué) » when the user had just stated
    # « Je gagne 7500 CHF » in plain text. See walkthrough 2026-05-07.
    clean_message_for_audit = _scrub_pii(body.message)

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
        question=body.message,
        system_prompt=discovery_prompt,
        api_key=server_key,
        provider="claude",
        language=body.language,
    )

    # --- Step 6: Increment message count ---
    anon_session.message_count += 1

    new_count = anon_session.message_count
    messages_remaining = MAX_ANONYMOUS_MESSAGES - new_count

    # --- Step 6b: Phase 71b — Premier Éclairage gate ---
    #
    # Spec (panel-locked, Phase 71 verdict):
    #   - Emit EclairagePayload exactly once per session.
    #   - Gate fires when coach has just completed turn 2 (i.e. the user has
    #     sent 2 messages and the second response is being built).
    #   - `eclairage_delivered` flag prevents double-emission on turn 3+.
    #
    # The user-intent-signal-sufficient check is implicitly satisfied for
    # v2.10: any 2 successful coach turns through the discovery prompt
    # qualify as enough signal to surface the default fiscal_margin_3a
    # insight. Future iterations may refine this with intent classification.
    eclairage: Optional[EclairagePayload] = None
    if new_count >= 2 and not anon_session.eclairage_delivered:
        eclairage = build_default_fiscal_margin_3a_eclairage()
        anon_session.eclairage_delivered = True

    db.commit()

    # --- Step 7: Return response ---
    return AnonymousChatResponse(
        message=result["answer"],
        disclaimers=result["disclaimers"],
        messages_remaining=messages_remaining,
        tokens_used=result["tokens_used"],
        eclairage=eclairage,
    )
