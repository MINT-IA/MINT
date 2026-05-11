"""Phase 96 D-14 — NarrativeSleeve response envelope.

4-field contract :
- ``hook`` — 1-line attention-grabbing opener. MUST be digit-free at
  runtime ; the response middleware (lands in Plan 96-03 per D-16)
  swaps the hook to a generic fallback on `\\d` match. Pydantic does
  NOT enforce the digit-free invariant here because Pydantic raising
  would 500 the response — the middleware swap is the chosen safety
  surface.
- ``caption`` — main body ; the Phase 94 citation gate has already
  applied (numbers wrapped in ``{{cite:<key>}}`` then substituted via
  the Phase 95 W2 double-lookup at
  ``citation_parser._substitute_placeholders(*, pack=)``).
- ``next_step`` — verb-first call-to-action, ≤12 words at lint time
  (the word-count + verb-first linter lands in Plan 96-03 ; this
  schema enforces only the byte-length cap).
- ``metaphor`` — static TOML lookup result by
  ``archetype × canton × life_event`` from
  ``apps/mobile/assets/metaphors.toml`` (loaded at app boot in W1).
  Empty string when no entry matches.

Phase 96 W2 lands the contract (this file) + the additive optional
``CoachChatResponse.narrative_sleeve`` field. The response middleware
that enforces hook-digit-free + next_step word-count lands in
Plan 96-03 (W3) per D-16. Frozen + extra-forbid match the
``GroundingPackEntry`` precedent at
``services/backend/app/services/coach/grounding_pack.py:51``.
"""
from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class NarrativeSleeve(BaseModel):
    """4-field response envelope per CONTEXT D-14."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    hook: str = Field(..., min_length=1, max_length=200)
    caption: str = Field(..., min_length=1, max_length=2000)
    next_step: str = Field(..., min_length=1, max_length=120)
    metaphor: str = Field(default="", max_length=200)
