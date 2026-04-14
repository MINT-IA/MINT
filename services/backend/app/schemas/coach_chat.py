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

from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic.alias_generators import to_camel


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
