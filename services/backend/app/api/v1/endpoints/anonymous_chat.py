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


# Prompt version — bumped on every rewrite so telemetry can A/B cleanly.
# Never remove or rename. Increment on content changes.
PROMPT_VERSION = "v2"


def build_discovery_system_prompt(
    intent: str | None = None,
    language: str = "fr",
    facts: list[str] | None = None,
) -> str:
    """Build the v2 discovery system prompt for anonymous users.

    v2 (2026-04-15) — audit-driven rewrite:
    - Tight length cap (≤ 3 phrases, verdict-first) — was 3-5 in v1.
    - Directive to cite user-declared numbers verbatim (fixes MSG1 regressions
      where Claude generalised instead of using the figures the user typed).
    - Optional `facts` parameter injected as a `<facts_user>` block so the
      deterministic regex extractor (phase B) can ground the LLM without
      relying on compliance-fragile tool-calls.

    Security contract preserved (T-13-05): the prompt contains NO references
    to any internal feature — the strings `outil`, `dossier`, `profil`,
    `memoire`, `tool` are forbidden and asserted by tests.

    Disclaimers are NOT included in the prompt body (doctrine violation +
    lexicon clash). They are appended by the endpoint via the response's
    `disclaimers[]` list so the legal obligation is met at the API layer.
    """
    parts: list[str] = [
        "Tu es MINT, un compagnon de lucidite financiere suisse.",
        "",
        "Contexte : mode decouverte. La personne n'a pas encore de compte.",
    ]

    if intent:
        parts.append(
            f"Elle a exprime ce sentiment : \u00ab\u202f{intent}\u202f\u00bb."
        )

    parts.append("")
    parts.extend([
        "Regles :",
        "- Reponse en 3 phrases maximum.",
        "- Premiere ligne = le verdict ou le chiffre le plus pertinent.",
        "- Reprends textuellement les chiffres que la personne te donne "
        "(salaire, valeur de rachat, avoir, etc.) — ne les parapharse pas.",
        "- Tutoie. Ton calme, precis, sans jargon non traduit.",
        "- Une seule question de relance a la fin, si utile.",
        "- Jamais de recommandation de produit nomme. Jamais de promesse "
        "de rendement. Jamais de comparaison sociale. Jamais de langage "
        "absolu : utilise le conditionnel.",
    ])

    # User-declared facts block (phase B) — appears only when populated.
    if facts:
        parts.append("")
        parts.append("<facts_user>")
        for fact in facts:
            parts.append(f"- {fact}")
        parts.append("</facts_user>")
        parts.append(
            "Appuie-toi sur ces elements pour ancrer ta reponse. "
            "Cite-les explicitement."
        )

    parts.append("")
    parts.append(
        "Objectif : eclairer avec un angle concret et surprenant."
    )

    return "\n".join(parts)


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

    # --- Step 3a: Extract deterministic facts from the RAW message (phase B).
    #
    # Must run BEFORE _scrub_pii — the scrubber replaces any "NNNN CHF/fr"
    # token with "[***]", which would destroy every salary/LPP figure the
    # extractor relies on.  Facts are kept in-memory only (no user_id, no DB
    # writes) — logged by topic list only (no values) to avoid PII in logs.
    extracted_facts_texts: list[str] = []
    try:
        from app.services.coach.profile_extractor import extract_profile_facts
        _facts = extract_profile_facts(body.message)
        extracted_facts_texts = [f.text for f in _facts]
        if _facts:
            logger.info(
                "anonymous_chat.extracted_facts session=%s topics=%s",
                session_id,
                sorted({f.topic for f in _facts}),
            )
    except Exception as exc:  # pragma: no cover — belt-and-braces
        # PII-safe: log the exception TYPE only. The extractor runs on the
        # raw (pre-scrub) message so any exception message could carry a
        # fragment of user input.
        logger.warning(
            "anonymous_chat.profile_extractor_failed: %s",
            type(exc).__name__,
        )

    # --- Step 3b: Scrub PII from input (T-13-02) ---
    clean_message = _scrub_pii(body.message)

    # --- Step 4: Build discovery system prompt (T-13-05) ---
    discovery_prompt = build_discovery_system_prompt(
        intent=body.intent,
        language=body.language,
        facts=extracted_facts_texts or None,
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
