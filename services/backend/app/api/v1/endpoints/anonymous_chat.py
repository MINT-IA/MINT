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


_ANONYMOUS_STATE_CONFIRMATION_RE = re.compile(
    r"("
    r"\b(?:je|on)\s+repars?\b.{0,40}\bz[eé]ro\b|"
    r"\brepart(?:ir|ons?|ez|ent)?\b.{0,40}\bz[eé]ro\b|"
    r"\bplus\s+acc[èe]s\s+[àa]\s+aucune\b|"
    r"\bsans\s+laisser\s+de\s+trace\b|"
    r"\b(?:je|on)\s+repar(?:s|t)\b[^.\n!?]{0,40}\bfeuille\s+blanche\b|"
    r"\b(?:aucun|aucune)\s+(?:donn[ée]es?|informations?|historique|trace)\b"
    r"[^.\n!?]{0,80}\b(?:conserv[ée]e?s?|gard[ée]e?s?|stock[ée]e?s?|"
    r"enregistr[ée]e?s?|rest(?:e|ent)?)\b|"
    r"\b(?:ton|ta|tes|votre|vos|ce|cet|cette|ces|des|l['’]|la|le|les)?\s*"
    r"(?:historique|conversation|donn[ée]es?|informations?)\b(?:\s+locales?)?"
    r"[^.\n!?]{0,80}\b(?:effac[ée]e?s?|supprim[ée]e?s?|"
    r"r[ée]initialis[ée]e?s?|purg[ée]e?s?|vid[ée]e?s?|nettoy[ée]e?s?)\b|"
    r"\b(?:suppression|effacement|r[ée]initialisation)\b[^.\n!?]{0,40}"
    r"\b(?:locale|donn[ée]es?|informations?|app|compte|conversation|historique)\b"
    r"[^.\n!?]{0,80}\b(?:termin[ée]e?|faite?|confirm[ée]e?|r[ée]ussie?)\b|"
    r"\b(?:start(?:ing)?|restart(?:ing)?|reset(?:ting)?)\b[^.\n!?]{0,40}"
    r"\b(?:from zero|fresh|blank slate)\b|"
    r"\bno\s+(?:data|trace)\s+(?:left|kept|stored|remain(?:s|ing)?)\b|"
    r"\bwithout(?:\s+leaving)?\s+(?:a\s+)?trace\b|"
    r"\b(?:local\s+)?(?:deletion|reset)\b[^.\n!?]{0,80}"
    r"\b(?:complete|completed|confirmed|done|successful)\b"
    r")",
    re.IGNORECASE,
)


def _guard_anonymous_state_claims(text: str, language: str = "fr") -> str:
    """Prevent LLM text from confirming local deletion or persistence state."""
    match = _ANONYMOUS_STATE_CONFIRMATION_RE.search(text)
    if not match:
        return text

    logger.warning(
        "Anonymous state-claim guard fired",
        extra={
            "matched": _scrub_pii(match.group(0)[:160]),
            "language": language,
        },
    )

    if language.lower().startswith("fr"):
        return (
            "Je ne peux pas confirmer depuis cette discussion qu'une suppression "
            "locale est terminée. L'app doit l'indiquer explicitement dans "
            "ses paramètres ou dans le diagnostic de redémarrage. "
            "Pour cette réponse, je m'appuie sur ce que tu viens d'écrire : "
            "quel sujet veux-tu explorer ?"
        )

    return (
        "I cannot confirm from this chat that a local deletion has completed. "
        "The app has to show that explicitly in its settings or in the restart "
        "diagnostic. For this reply, I am using what you just wrote: what topic "
        "do you want to explore?"
    )


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
        "Tu ne disposes pas d'informations biographiques pr\u00e9alables sur elle.",
        "Tu r\u00e9ponds \u00e0 partir du message re\u00e7u dans ce tour.",
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
        "- Si tu cites un chiffre suisse (taux, plafond, m\u00e9diane) qui ne provient ni du message ni d'une source l\u00e9gale cit\u00e9e (OPP3, LIFD, LPP, LAVS, LFLP), encadre-le explicitement comme \u00ab ordre de grandeur \u00bb et n'avance jamais une valeur exacte sans la qualifier.",
        "- Quand tu cites un plafond, taux ou bar\u00e8me suisse provenant d'une source l\u00e9gale (OPP3, LIFD, LPP, LAVS, LFLP), reproduis la valeur exactement et int\u00e8gre la r\u00e9f\u00e9rence l\u00e9gale verbatim (ex : \u00ab OPP3 art. 7 \u00bb, \u00ab LIFD art. 33 \u00bb) dans la m\u00eame phrase, juste apr\u00e8s le chiffre.",
        "- Ne reproduis jamais textuellement un IBAN, un num\u00e9ro AVS ou un montant exact que la personne aurait \u00e9crit \u2014 paraphrase-le.",
        "- Ne conclus jamais qu'une suppression, une r\u00e9initialisation ou un nouveau d\u00e9part a eu lieu. Tu ne peux pas confirmer l'\u00e9tat local de l'app depuis cette conversation.",
        "- Si la personne demande si des informations ont \u00e9t\u00e9 effac\u00e9es ou conserv\u00e9es, dis que seule l'app peut le confirmer, puis propose de continuer \u00e0 partir de ce qu'elle \u00e9crit maintenant.",
        "- \u00c9vite ces formulations sur l'\u00e9tat local : \u00ab je repars de z\u00e9ro \u00bb, \u00ab aucune donn\u00e9e \u00bb, \u00ab sans trace \u00bb, \u00ab feuille blanche \u00bb.",
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
        # Sub-phase 01.4 fix (F-01.1-06) — anonymous coach must invoke the
        # regulatory registry tool instead of citing training-data plafonds.
        # Authentication path already wires this via coach_chat.py:88+186.
        # Defense-in-depth couches A+B+C+D per .planning/phases/01.4-coach-runtime-stale-data/01.4-AUDIT.md
        from app.services.coach.runtime_temporal_gate import (
            fallback_for_language as _temporal_fallback_for_language,
            gate as _runtime_temporal_gate,
        )
        from app.services.rag.guardrails import ComplianceGuardrails
        from app.services.coach.coach_tools import get_llm_tools

        guardrails = ComplianceGuardrails()

        # Couche A — anonymous tool surface. Two grounded read-only tools:
        #   get_regulatory_constant — Swiss plafonds/taux/barèmes (numbers).
        #   explain_concept — curated CONCEPT_REGISTRY definitions (Codex fix_6).
        # The W1 rachat-inversion incident happened HERE (anonymous surface): the
        # LLM defined a regulated concept from its weights. Exposing + forcing
        # explain_concept disarms it on definitions the same way
        # get_regulatory_constant disarms it on numbers.
        all_tools = get_llm_tools()
        anon_tools = [
            t
            for t in all_tools
            if t.get("name") in ("get_regulatory_constant", "explain_concept")
        ]

        # Couche C — finance-keyword detector tightens tool_choice from auto to forced
        # Use word boundaries; lowercase the question for case-insensitive matching.
        _FINANCE_KW = re.compile(
            r"\b(3a|3eme|3ème|3e\s*pilier|lpp|avs|plafond|rente|cotisation|fiscal|imp[oô]t|fortune|salaire|taux|d[ée]duction|barreme|bareme|barème)\b",
            re.IGNORECASE,
        )
        # Codex fix_6 — definition-intent detector for the anonymous surface.
        # An interrogative ("c'est quoi", "explique", "comment fonctionne",
        # "ce que veut dire", "j'aimerais comprendre"…) co-occurring with a
        # registry concept term forces explain_concept on the FIRST call. Mirrors
        # the authenticated _classify_user_intent definition_request narrowness:
        # naming a concept without asking for its definition does NOT fire it.
        _DEF_INTERROGATIVE = re.compile(
            r"(c['’\s]?est\s+quoi|qu['’\s]?est[\s-]?ce\s+que|explique|explication|"
            r"d[ée]finition|d[ée]finir|comment\s+(?:fonctionne|marche|[çc]a\s+marche)|"
            r"ce\s+que\s+(?:[çc]a\s+)?veut\s+dire|veut\s+dire\s+quoi|signifie\s+quoi|"
            r"j['’\s]?aimerais\s+(?:comprendre|savoir)|tu\s+peux\s+m['’\s]?expliquer|"
            r"peux[\s-]?tu\s+m['’\s]?expliquer|[çc]a\s+veut\s+dire\s+quoi)",
            re.IGNORECASE,
        )
        _DEF_CONCEPT = re.compile(
            r"\b(rachat|epl|encouragement\s+[àa]\s+la\s+propri[ée]t[ée]|pilier\s+3[ab]|"
            r"3e(?:me)?\s+pilier|troisi[èe]me\s+pilier|splitting|taux\s+de\s+conversion|"
            r"lacune|coordination|libre\s+passage|bonification|frontalier|fatca)\b",
            re.IGNORECASE,
        )
        force_definition = bool(
            _DEF_INTERROGATIVE.search(question) and _DEF_CONCEPT.search(question)
        )
        # Definition intent takes priority over the generic finance-keyword
        # force (a definition ask is more specific than a number lookup).
        force_tool = (not force_definition) and bool(_FINANCE_KW.search(question))

        # Appels via LLMRouter (PRIV-07 / beads MINT_nosync-4lj) : le chemin
        # anonyme suit le même routage résidence que le coach authentifié
        # (Bedrock-EU si BEDROCK_EU_PRIMARY_ENABLED global, sinon US direct
        # documenté). LLMClient.generate ne supporte pas le contenu
        # multi-block tool_result, d'où la construction LLMRequest directe.
        # Pas de user_id anonyme -> résolution du flag au scope global.
        try:
            from anthropic import AsyncAnthropic
        except ImportError as exc:
            raise RuntimeError(
                "anthropic package missing — install via pip install -e '.[rag]'"
            ) from exc
        from app.services.llm.router import LLMRequest, LLMRouter

        resolved_model = model or "claude-sonnet-4-5-20250929"
        client = AsyncAnthropic(api_key=api_key, timeout=60.0)
        router = LLMRouter(anthropic_client=client)
        try:

            messages: list[dict] = [{"role": "user", "content": question}]
            # First-call-only force (Codex fix_6): definition intent → explain_concept;
            # else finance keyword → get_regulatory_constant; else auto. The follow-up
            # call after a tool_result reverts to auto (already the case below).
            if force_definition:
                tool_choice: dict = {"type": "tool", "name": "explain_concept"}
            elif force_tool:
                tool_choice = {"type": "tool", "name": "get_regulatory_constant"}
            else:
                tool_choice = {"type": "auto"}

            # First LLM turn — may emit text + tool_use blocks.
            first = await router.invoke(LLMRequest(
                model=resolved_model,
                max_tokens=600,
                system=system_prompt,
                messages=messages,
                tools=anon_tools,
                tool_choice=tool_choice,
                purpose="anonymous_chat",
            ))

            tokens_first = (first.usage.input_tokens + first.usage.output_tokens) if first.usage else 0
            tool_use_blocks = [b for b in first.content if getattr(b, "type", None) == "tool_use"]
            text_blocks_first = [b.text for b in first.content if getattr(b, "type", None) == "text"]

            # Couche B — 1-iteration tool-use agent loop. If LLM invoked the tool,
            # execute it locally and feed the result back so the LLM can produce
            # final user-facing text grounded on the registry value.
            final_text = "\n".join(text_blocks_first)
            tokens_total = tokens_first
            executed_tool_names: list[str] = []

            if tool_use_blocks:
                # Sub-phase 01.4 panel FLAG #1 — import from shared module (NOT
                # coach_chat) so the anonymous path keeps T-13-06 isolation from
                # the authenticated auth/billing/consent stack.
                from app.services.regulatory.tool_handler import (
                    handle_regulatory_constant,
                )
                # Sub-phase 01.4 panel FLAG #3 — observability for tool fire.
                from app.observability.coach_breadcrumbs import (
                    emit_coach_tool_breadcrumb,
                )
                import hashlib as _hashlib
                import json as _json
                import time as _time

                _t0 = _time.monotonic()

                # Build the assistant turn carrying the original content blocks so
                # Anthropic understands the conversation state.
                assistant_content: list[dict] = []
                for b in first.content:
                    btype = getattr(b, "type", None)
                    if btype == "text":
                        assistant_content.append({"type": "text", "text": b.text})
                    elif btype == "tool_use":
                        assistant_content.append({
                            "type": "tool_use",
                            "id": b.id,
                            "name": b.name,
                            "input": b.input,
                        })

                # Execute each tool_use and build the user turn carrying tool_result blocks.
                tool_result_content: list[dict] = []
                for b in tool_use_blocks:
                    if b.name == "get_regulatory_constant":
                        tool_input_dict = b.input or {}
                        result_str = handle_regulatory_constant(tool_input_dict)
                        executed_tool_names.append("get_regulatory_constant")
                        # Sub-phase 01.4 panel FLAG #3 — Sentry breadcrumb so prod
                        # can verify the fix is actually firing. Payload is non-PII
                        # by construction (SHA-256 hash of input dict).
                        try:  # pragma: no cover — telemetry-only
                            _inputs_hash = _hashlib.sha256(
                                _json.dumps(tool_input_dict, sort_keys=True).encode()
                            ).hexdigest()
                            emit_coach_tool_breadcrumb(
                                tool_name="regulatory_constant",
                                inputs_hash=_inputs_hash,
                                profile_id_hashed="anonymous",
                                elapsed_ms=int((_time.monotonic() - _t0) * 1000),
                                flag_state="on",
                                extra_tags={"path": "anonymous"},
                            )
                        except Exception:
                            pass  # fail-open per coach_breadcrumbs.py contract
                    elif b.name == "explain_concept":
                        # Codex fix_6 — resolve the curated CONCEPT_REGISTRY page so
                        # the anonymous LLM grounds its definition on the registry,
                        # never on its weights (the W1 rachat-inversion fix). Imported
                        # from the shared coach_tools module (no endpoint import →
                        # preserves T-13-06 isolation; handle_explain_concept touches
                        # no auth/profile/DB).
                        from app.services.coach.coach_tools import (
                            handle_explain_concept,
                        )

                        tool_input_dict = b.input or {}
                        result_str = handle_explain_concept(tool_input_dict)
                        executed_tool_names.append("explain_concept")
                        try:  # pragma: no cover — telemetry-only
                            _inputs_hash = _hashlib.sha256(
                                _json.dumps(tool_input_dict, sort_keys=True).encode()
                            ).hexdigest()
                            emit_coach_tool_breadcrumb(
                                tool_name="explain_concept",
                                inputs_hash=_inputs_hash,
                                profile_id_hashed="anonymous",
                                elapsed_ms=int((_time.monotonic() - _t0) * 1000),
                                flag_state="on",
                                extra_tags={"path": "anonymous"},
                            )
                        except Exception:
                            pass  # fail-open per coach_breadcrumbs.py contract
                    else:
                        # Unknown tool — return error so the LLM doesn't pretend it ran.
                        result_str = f"Erreur : outil '{b.name}' non disponible en mode anonyme."
                    tool_result_content.append({
                        "type": "tool_result",
                        "tool_use_id": b.id,
                        "content": result_str,
                    })

                messages_followup = [
                    *messages,
                    {"role": "assistant", "content": assistant_content},
                    {"role": "user", "content": tool_result_content},
                ]

                second = await router.invoke(LLMRequest(
                    model=resolved_model,
                    max_tokens=600,
                    system=system_prompt,
                    messages=messages_followup,
                    tools=anon_tools,
                    # Second pass = LLM should now answer with grounded text.
                    # Don't re-force the tool (already executed), let it narrate.
                    tool_choice={"type": "auto"},
                    purpose="anonymous_chat",
                ))
                tokens_total += (second.usage.input_tokens + second.usage.output_tokens) if second.usage else 0

                second_text = "\n".join(
                    b.text for b in second.content if getattr(b, "type", None) == "text"
                )
                if second_text.strip():
                    final_text = second_text
        finally:
            # Client injecté = possédé par nous (le routeur ne ferme
            # jamais un client injecté) — fermeture déterministe.
            try:
                await client.close()
            except Exception:  # pragma: no cover — hygiène best-effort
                pass

        # CJT-021 — anonymous path must share the authenticated path's
        # temporal fail-closed invariant: a current-year question must never
        # return stale timing anchors from a past tax year.
        _tg_passed, _tg_text = _runtime_temporal_gate(
            final_text,
            user_message=question,
            fallback_text=_temporal_fallback_for_language(language),
        )
        if not _tg_passed:
            try:  # pragma: no cover — telemetry-only
                import sentry_sdk

                sentry_sdk.add_breadcrumb(
                    category="coach.temporal_gate.fired",
                    message="runtime temporal-anchor gate fired",
                    level="info",
                    data={
                        "profile_id_hashed": "anonymous",
                        "fallback_emitted": True,
                    },
                )
            except Exception:
                pass
            final_text = _tg_text

        # Compliance filter (banned-term sanitization, accent normalization,
        # disclaimer injection). Same gate as before but applied to the
        # grounded text from the tool-use loop.
        final_text = _guard_anonymous_state_claims(final_text, language)
        filtered = guardrails.filter_response(final_text, language)

        tokens_used = tokens_total if tokens_total > 0 else len(question) // 4

        result: dict = {
            "answer": filtered["text"],
            "sources": [],
            "disclaimers": filtered["disclaimers_added"],
            "tokens_used": tokens_used,
        }
        if executed_tool_names:
            # Surface tool-use trace for Sentry breadcrumbs + 01.4 verification.
            result["tool_calls"] = [{"name": n} for n in executed_tool_names]
        return result


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

    # --- Step 3: Build discovery system prompt (T-13-05) ---
    # Do not scrub the live LLM input: the user voluntarily shares numbers
    # needed for personalized answers. Any future persisted audit artifact
    # must call `_scrub_pii` at the point where it is stored.
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
