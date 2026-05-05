"""
Pydantic v2 schemas for the Anonymous Chat endpoint (Phase 13).

POST /api/v1/anonymous/chat — anonymous discovery chat with rate limiting.

API convention: camelCase field names via alias_generator, ConfigDict.

Phase 81 (v2.11) — Backend eclairage contract:
    - AnonymousChatRequest accepts optional `archetype` body field (4 v2.10 slugs).
    - AnonymousChatResponse carries optional `eclairage: EclairageSchema | None`.
    - EclairageSchema mirrors `EclairageCardData` consumed by Flutter (Phase 80).

Compliance:
    - LSFin art. 3 (information financiere)
    - LSFin art. 7-10 (no promise of returns) — eclairage MUST use range, not absolute CHF.
    - LPD art. 6 (protection des donnees)
"""

from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic.alias_generators import to_camel


# ---------------------------------------------------------------------------
# Phase 81 — Eclairage payload (anti phantom contract C2)
# ---------------------------------------------------------------------------

# 4 v2.10 archetype slugs (locked spec REQUIREMENTS.md §ECLB-01).
ArchetypeSlug = Literal[
    "julien_swiss",
    "couple_acheteurs_lausanne",
    "jeune_diplome_zurich",
    "cadre_40_55_lpp_rachat",
]

# Eclairage kinds shipped in v2.11. Extending requires updating the deterministic
# emitter (services/coach/anonymous_eclairage_emitter.py) AND the Flutter
# `EclairageCardData.kind` switch.
EclairageKind = Literal[
    "fiscal_margin_3a",
    "lpp_rachat_3a_nantissement",
]

EclairageRangePeriod = Literal["year", "month", "lifetime"]


class EclairageSchema(BaseModel):
    """Premier Éclairage payload — Phase 81 ECLB-02 + ECLB-04.

    Mirrors Flutter `EclairageCardData` (Phase 80 consumer contract). Field
    names use snake_case at storage time but are serialized as camelCase via
    `alias_generator=to_camel` (`chf_range_low` → `chfRangeLow`, etc.) so the
    mobile client receives the same convention as every other MINT response.

    LSFin compliance (ECLB-04, locked):
        - chf_range_low + chf_range_high are ALWAYS both set OR both null —
          a single absolute CHF figure is forbidden (no promise of returns).
        - lsfin_disclaimer is non-optional (always rendered alongside the card).
        - banned-terms enforcement is performed at emitter time
          (anonymous_eclairage_emitter.build_payload), not in this schema —
          the schema is the contract surface, not the guardrail.
    """

    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    kind: EclairageKind = Field(
        ...,
        description="Insight family. Drives Flutter card template selection.",
    )
    headline: str = Field(
        ...,
        min_length=1,
        max_length=80,
        description="Headline phrase (≤80 chars). Renders as primary card title.",
    )
    body: str = Field(
        ...,
        min_length=1,
        max_length=240,
        description="Body copy (≤240 chars). Two-layer insight (fait + traduction humaine).",
    )
    chf_range_low: Optional[int] = Field(
        None,
        ge=0,
        description="Lower bound of conditional CHF range. None if range not applicable.",
    )
    chf_range_high: Optional[int] = Field(
        None,
        ge=0,
        description="Upper bound of conditional CHF range. None if range not applicable.",
    )
    chf_range_period: EclairageRangePeriod = Field(
        default="year",
        description="Period the CHF range applies to.",
    )
    soft_account_hint: str = Field(
        ...,
        min_length=1,
        max_length=80,
        description="Soft hint copy nudging account creation. ≤80 chars, no hard CTA.",
    )
    lsfin_disclaimer: str = Field(
        ...,
        min_length=1,
        max_length=240,
        description="LSFin compliance disclaimer (always rendered, never optional).",
    )

    @field_validator("chf_range_high")
    @classmethod
    def validate_range_paired(cls, v: Optional[int], info) -> Optional[int]:
        """Enforce ECLB-04: low+high must be both set or both null."""
        low = info.data.get("chf_range_low")
        if (low is None) != (v is None):
            raise ValueError(
                "chf_range_low and chf_range_high must both be set or both be null "
                "(LSFin: never absolute CHF, always conditional range)."
            )
        if v is not None and low is not None and v < low:
            raise ValueError("chf_range_high must be >= chf_range_low.")
        return v


class AnonymousChatRequest(BaseModel):
    """Request for anonymous discovery chat.

    No authentication required. Limited to 3 messages per device token.

    Phase 81 ECLB-01: optional `archetype` field. When set, the orchestrator
    consults `MINT_E2E_FORCE_ECLAIRAGE_KIND` (env or `forced_eclairage_kind`
    body field) to determine whether to emit a deterministic eclairage payload
    at coach turn 2.
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
    archetype: Optional[ArchetypeSlug] = Field(
        None,
        description=(
            "Phase 81 ECLB-01: optional v2.10 archetype slug. When present "
            "AND turn 2 AND emitter pinned (env or body), backend emits a "
            "deterministic eclairage payload."
        ),
    )
    forced_eclairage_kind: Optional[EclairageKind] = Field(
        None,
        description=(
            "Phase 81 ECLB-03: optional emitter pin override. When set, takes "
            "precedence over the MINT_E2E_FORCE_ECLAIRAGE_KIND env var. "
            "Intended for E2E tests + walker runs."
        ),
    )


class AnonymousChatResponse(BaseModel):
    """Response for anonymous discovery chat.

    Includes compliance disclaimers and remaining message count.

    Phase 81 ECLB-02: optional `eclairage: EclairageSchema | None` field.
    None when the orchestrator emits free-form prose (default behaviour).
    Set when archetype is present + emitter is pinned at coach turn 2.
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
    eclairage: Optional[EclairageSchema] = Field(
        default=None,
        description=(
            "Phase 81 ECLB-02: optional Premier Éclairage payload. None when "
            "the response is free-form prose. Set when the deterministic "
            "emitter fires at coach turn 2 with a pinned kind."
        ),
    )
