"""
Pydantic v2 schemas for the Coach Chat endpoint (Sprint S56+).

POST /api/v1/coach/chat — dedicated coach chat with tools + system prompt + RAG.

API convention: camelCase field names via alias_generator, ConfigDict.

Compliance:
    - LSFin art. 3 (information financiere)
    - LPD art. 6 (protection des donnees)
    - FINMA circular 2008/21

Sources:
    - docs/BLUEPRINT_COACH_AI_LAYER.md
    - docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §6
"""

from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic.alias_generators import to_camel

# Phase 96 D-13 / D-15 — additive optional fields point to these schemas.
from app.schemas.card_context import SerializedCardContext
from app.schemas.narrative_sleeve import NarrativeSleeve


# ===========================================================================
# Base config — camelCase aliases for mobile interop
# ===========================================================================


class CoachChatBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


# ===========================================================================
# Request schema
# ===========================================================================


class CoachChatRequest(CoachChatBaseModel):
    """Requete de chat coach.

    Combines BYOK LLM access with user profile context for personalized,
    tool-aware, RAG-enriched responses.

    Privacy: profile_context and memory_block MUST NOT contain IBAN, full name,
    NPA, employer, or any directly identifying information.
    """

    message: str = Field(
        ...,
        min_length=1,
        max_length=2000,
        description="Message de l'utilisateur au coach.",
    )

    @field_validator('message')
    @classmethod
    def validate_message_not_whitespace(cls, v: str) -> str:
        """FIX-070: Reject whitespace-only messages before hitting the LLM."""
        if not v.strip():
            raise ValueError('Le message ne peut pas être vide.')
        return v.strip()
    api_key: Optional[str] = Field(
        None,
        description=(
            "Cle API LLM de l'utilisateur (BYOK). Optionnel en beta: "
            "quand absent, le serveur utilise sa propre cle ANTHROPIC_API_KEY. "
            "Jamais stockee, jamais loggee par MINT."
        ),
    )
    provider: str = Field(
        default="claude",
        description="Fournisseur LLM: 'claude', 'openai', 'mistral'.",
    )
    model: Optional[str] = Field(
        None,
        description="Modele LLM specifique (utilise le defaut du provider si absent).",
    )
    profile_context: Optional[dict[str, Any]] = Field(
        None,
        description=(
            "Contexte profil agrege (non identifiant). "
            "Cles autorisees: age, canton, archetype, fri_total, fri_delta, "
            "replacement_ratio, months_liquidity, tax_saving_potential, "
            "confidence_score, fiscal_season, upcoming_event, check_in_streak, "
            "primary_focus. Jamais: IBAN, nom complet, NPA, employeur."
        ),
    )
    memory_block: Optional[str] = Field(
        None,
        max_length=8000,
        description=(
            "Bloc memoire serialise (CapMemory format). Contient le cycle de vie, "
            "les nudges actifs, la couleur regionale, et le plan en cours. "
            "Injecte dans le system prompt pour la personnalisation contextuelle."
        ),
    )
    conversation_history: Optional[list[dict[str, str]]] = Field(
        None,
        max_length=20,
        description=(
            "Prior conversation messages for multi-turn context. "
            "Each item: {role: 'user'|'assistant', content: str}. "
            "Last 8 messages max. Sanitized client-side."
        ),
    )
    language: str = Field(
        default="fr",
        description="Langue de la reponse: 'fr', 'de', 'en', 'it'.",
    )
    cash_level: int = Field(
        default=3,
        ge=1,
        le=5,
        description="Voice intensity 1-5 (1=factual, 5=brut).",
    )
    persistence_consent: bool = Field(
        default=False,
        description=(
            "Phase 52.1 PR 2 — cloud-sync toggle state from the mobile app. "
            "When False (the safest default), the backend MUST refuse every "
            "WRITE-tier tool call (save_fact, save_insight, save_pre_mortem, "
            "save_provenance, save_earmark, save_partner_estimate, "
            "record_check_in, n5 emission marks) and instead return a stable "
            "string '[persistence_off: write skipped — sync disabled]' to the "
            "LLM. The LLM call itself proceeds normally — there is no "
            "on-device LLM. See "
            ".planning/decisions/2026-05-03-chat-under-cloud-sync-off.md."
        ),
    )

    # ------------------------------------------------------------------
    # Phase 96 W2 D-08 / D-13 — chat-as-verb additions (all optional, additive,
    # backward-compatible with pre-96 clients).
    # ------------------------------------------------------------------
    source_card: Optional[SerializedCardContext] = Field(
        default=None,
        description=(
            "Phase 96 D-13 — optional card snapshot. When non-None, the narrator "
            "system prompt receives a <source_card> block with computed_facts + "
            "grounding_keys + life_event + canton + archetype. None preserves "
            "Phase 94/95 byte-identical behavior (legacy chat-tab path)."
        ),
    )
    turn_count: int = Field(
        default=0,
        ge=0,
        description=(
            "Phase 96 D-08 — client-supplied turn counter for UX transparency. "
            "The server IGNORES this value when enforcing the 3-turn cap "
            "(T-96-W2-TurnCountTamper mitigation) ; the server's in-memory "
            "TURN_COUNTER dict at app.services.coach.turn_cap is the source of "
            "truth. Accepted on the wire so the client can render its own "
            "counter in MintChatOverlay."
        ),
    )
    intent: Optional[Literal["explain", "reassure"]] = Field(
        default=None,
        description=(
            "Phase 96 D-06 — verb dispatch intent. 'explain' opens from "
            "« Explique-moi », 'reassure' from « Rassure-moi ». None on legacy "
            "chat-tab path (pre-96 compatibility)."
        ),
    )

    # ------------------------------------------------------------------
    # Tranche firstJob PR-E (E1) — handoff /first-job → coach porteur du
    # MoneyTruthReceipt. Le coach REÇOIT receiptId + inputsHash (SPEC §4.3) et
    # résout server-side le MÊME receipt (owner-scoped) pour grounder sur la
    # MÊME valeur. Tous optionnels + additifs (aucun impact sur le chemin
    # coach classique — receiptId absent = comportement inchangé).
    # ------------------------------------------------------------------
    receipt_id: Optional[str] = Field(
        default=None,
        max_length=64,
        description=(
            "firstJob PR-E — id du MoneyTruthReceipt à résoudre pour ce tour. "
            "Le backend résout le receipt scopé au propriétaire (SPEC §4.3) et "
            "ground le coach sur receipt.value. None sur le chemin chat "
            "classique."
        ),
    )
    inputs_hash: Optional[str] = Field(
        default=None,
        max_length=64,
        description=(
            "firstJob PR-E — hash déterministe des inputs du receipt "
            "(compute_inputs_hash). Accompagne receiptId pour la résolution."
        ),
    )
    receipt_inputs: Optional[dict[str, Any]] = Field(
        default=None,
        description=(
            "firstJob PR-E — inputs normalisés portés par le payload d'entrée "
            "(cas pending : receipt pas encore synchronisé). Le coach répond "
            "depuis ces inputs quand la résolution serveur ne trouve pas le "
            "receipt du propriétaire."
        ),
    )


# ===========================================================================
# Response schema
# ===========================================================================


class CoachChatResponse(CoachChatBaseModel):
    """Reponse du coach chat.

    Contient le texte genere + les appels d'outils eventuels +
    les sources RAG + les disclaimers de conformite.

    Sources:
        - LSFin art. 3 (information financiere)
        - LPD art. 6 (protection des donnees)
    """

    message: str = Field(
        ...,
        description="Reponse textuelle du coach (validee par ComplianceGuard).",
    )
    tool_calls: Optional[list[dict[str, Any]]] = Field(
        None,
        description=(
            "Appels d'outils retournes par le LLM (format Anthropic tool_use). "
            "Chaque element: {name: str, input: dict}. "
            "Le client Flutter execute l'action correspondante."
        ),
    )
    sources: list[dict[str, Any]] = Field(
        default_factory=list,
        description="Sources de la base de connaissance utilisees (RAG retrieval).",
    )
    cash_level: int = Field(default=3, ge=1, le=5, description="Voice intensity 1-5")
    disclaimers: list[str] = Field(
        default_factory=list,
        description="Disclaimers de conformite ajoutes par ComplianceGuard.",
    )
    tokens_used: int = Field(
        default=0,
        ge=0,
        description="Estimation de l'utilisation de tokens pour la requete.",
    )
    system_prompt_used: bool = Field(
        default=True,
        description="Indique si le system prompt coach a ete applique.",
    )
    response_meta: Optional[dict[str, Any]] = Field(
        default=None,
        description=(
            "Metadata sur la generation de la reponse. Cles: "
            "degraded (bool — true si fallback Haiku active), "
            "model_used (str — id du modele qui a servi la reponse)."
        ),
    )

    # ------------------------------------------------------------------
    # Phase 96 W2 D-15 — narrative envelope (optional ; None on legacy
    # chat-tab path OR when source_card was None on the request).
    # ------------------------------------------------------------------
    narrative_sleeve: Optional[NarrativeSleeve] = Field(
        default=None,
        description=(
            "Phase 96 D-15 — 4-field response envelope (hook, caption, "
            "next_step, metaphor). None when source_card is None on the "
            "request OR when the legacy unstructured fallback path is "
            "taken. The response middleware that enforces hook digit-free "
            "+ next_step word-count lands in Plan 96-03 per D-16."
        ),
    )

    # ------------------------------------------------------------------
    # Wave 1b Plan 04 — citation chips (Route b per wave-1b-04-AUDIT.md).
    # The 6 Wave 1a internal tools (budget_snapshot, retirement_projection,
    # cross_pillar_analysis, couple_optimization, cap_status,
    # retrieve_memories) are filtered out of `toolCalls` upstream because
    # they are in INTERNAL_TOOL_NAMES. This additive field carries their
    # inputs_hash + computed_at + raw_response so Flutter can render the
    # citation chip + tap-to-modal (Plans 05 / 06). Optional + defaults to
    # None — legacy clients ignore the key.
    # ------------------------------------------------------------------
    citation_chips: Optional[list[dict[str, Any]]] = Field(
        default=None,
        description=(
            "Wave 1b — per-tool citation-chip payload. Each entry: "
            "{toolName: str, inputsHash: str (64-char hex), "
            "computedAt: str (ISO-8601), rawResponse: dict}. None on "
            "legacy path or when no Wave 1a tool ran in the turn."
        ),
    )
