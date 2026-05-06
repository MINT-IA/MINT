"""
Pydantic v2 schemas for the Anonymous Chat endpoint (Phase 13).

POST /api/v1/anonymous/chat — anonymous discovery chat with rate limiting.

API convention: camelCase field names via alias_generator, ConfigDict.

Compliance:
    - LSFin art. 3 (information financiere)
    - LPD art. 6 (protection des donnees)

Phase 71b extension: EclairagePayload — Premier Éclairage emitted on coach
turn 2 (LSFin-compliant conditional CHF range, no absolute figure).
"""

from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic.alias_generators import to_camel


# ---------------------------------------------------------------------------
# Phase 71b — Premier Éclairage payload
# ---------------------------------------------------------------------------


# Locked LSFin disclaimer (panel-validated FR, Phase 71)
_LSFIN_DISCLAIMER_FR = (
    "Information éducative basée sur le droit suisse en vigueur. "
    "Ce n'est pas un conseil financier personnalisé."
)


class EclairagePayload(BaseModel):
    """Premier Éclairage — single insight delivered after coach turn 2.

    LSFin compliance: NO absolute CHF figure for anonymous users (no KYC).
    Always conditional range (low + high + period) with disclaimer.

    Locked spec (Phase 71 panel verdict):
        - kind: enum of supported insight types
        - headline: ≤80 chars hook
        - body: ≤240 chars educational explanation
        - chf_range_low/high/period: conditional, never absolute
        - soft_account_hint: ≤80 chars CTA toward account creation
        - lsfin_disclaimer: required educational-purpose disclaimer
    """

    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    kind: Literal["fiscal_margin_3a", "lpp_gap", "tax_friction"] = Field(
        default="fiscal_margin_3a",
        description="Insight category (locked enum).",
    )
    headline: str = Field(
        ...,
        max_length=80,
        description="Hook headline, ≤80 chars.",
    )
    body: str = Field(
        ...,
        max_length=240,
        description="Educational body, ≤240 chars.",
    )
    chf_range_low: Optional[int] = Field(
        default=None,
        description="Conditional CHF range low bound (never absolute).",
    )
    chf_range_high: Optional[int] = Field(
        default=None,
        description="Conditional CHF range high bound (never absolute).",
    )
    chf_range_period: Literal["year", "month", "lifetime"] = Field(
        default="year",
        description="Period for the CHF range.",
    )
    soft_account_hint: str = Field(
        ...,
        max_length=80,
        description="Soft CTA toward account creation, ≤80 chars.",
    )
    lsfin_disclaimer: str = Field(
        default=_LSFIN_DISCLAIMER_FR,
        max_length=240,
        description="LSFin educational-purpose disclaimer.",
    )


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
    eclairage: Optional[EclairagePayload] = Field(
        default=None,
        description=(
            "Premier Éclairage payload, emitted exactly once per session "
            "after coach turn 2 (LSFin-compliant conditional insight)."
        ),
    )
