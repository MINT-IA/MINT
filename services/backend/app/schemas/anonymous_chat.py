"""
Pydantic v2 schemas for the Anonymous Chat endpoint (Phase 13).

POST /api/v1/anonymous/chat — anonymous discovery chat with rate limiting.

API convention: camelCase field names via alias_generator, ConfigDict.

Compliance:
    - LSFin art. 3 (information financiere)
    - LPD art. 6 (protection des donnees)
"""

from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic.alias_generators import to_camel


class AnonymousChatRequest(BaseModel):
    """Request for anonymous discovery chat.

    No authentication required. Limited to 3 messages per device token.
    """

    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    message: str = Field(
        ...,
        min_length=1,
        max_length=2000,
        description="Message de l'utilisateur anonyme.",
    )

    @field_validator("message")
    @classmethod
    def validate_message_not_whitespace(cls, v: str) -> str:
        """Reject whitespace-only messages."""
        if not v.strip():
            raise ValueError("Le message ne peut pas etre vide.")
        return v.strip()

    intent: Optional[str] = Field(
        None,
        description="Felt-state pill text selected by the user (e.g. 'Je me sens perdu').",
    )
    language: str = Field(
        default="fr",
        description="Langue de la reponse: 'fr', 'de', 'en', 'it'.",
    )


class AnonymousChatResponse(BaseModel):
    """Response for anonymous discovery chat.

    Includes compliance disclaimers and remaining message count.
    """

    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    message: str = Field(
        ...,
        description="Reponse du coach en mode decouverte.",
    )
    disclaimers: list[str] = Field(
        default_factory=list,
        description="Disclaimers de conformite.",
    )
    messages_remaining: int = Field(
        ...,
        ge=0,
        le=3,
        description="Nombre de messages restants pour cette session anonyme.",
    )
    tokens_used: int = Field(
        default=0,
        ge=0,
        description="Estimation de l'utilisation de tokens.",
    )
    follow_up_questions: list[str] = Field(
        default_factory=list,
        description=(
            "Up to 2 genuine follow-up questions the user might ask next. "
            "Parsed server-side from a <followups>[\"q1\",\"q2\"]</followups> "
            "JSON block emitted by the LLM. Empty when absent or malformed. "
            "Never a reformulation of the user's own question."
        ),
    )

    @field_validator("follow_up_questions")
    @classmethod
    def cap_follow_ups(cls, v: list[str]) -> list[str]:
        """Silently cap follow-up questions at 2 items."""
        if not v:
            return []
        cleaned = [s.strip() for s in v if isinstance(s, str) and s.strip()]
        return cleaned[:2]
