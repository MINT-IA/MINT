"""
Backend ResponseCard schema — Plan 08a-01.

Carries the optional ``EnhancedConfidence`` payload (Plan 08a-01 wire
extension). The full ResponseCard surface lives client-side
(``apps/mobile/lib/models/response_card.dart``); this schema mirrors
only the fields the backend needs to emit/validate, plus the new
``confidence`` field that unblocks the 11-surface MTC migration
(Plan 08a-02).

Backwards compatible: ``confidence`` is optional and defaults to
``None`` per the Phase 4 null-fallback posture.
"""

from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

from app.schemas.enhanced_confidence import EnhancedConfidence


class PremierEclairageSchema(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    value: float
    unit: str
    explanation: str


class CardCtaSchema(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    label: str
    route: str
    icon: Optional[str] = None


class ResponseCard(BaseModel):
    """Backend mirror of the mobile ResponseCard.

    Only the fields that travel over the wire are modeled here. The
    new ``confidence`` field is the Plan 08a-01 deliverable.
    """

    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)

    id: str
    type: str
    title: str
    subtitle: str
    premier_eclairage: PremierEclairageSchema
    cta: CardCtaSchema
    urgency: str = "low"
    disclaimer: str
    sources: List[str] = Field(default_factory=list)
    alertes: List[str] = Field(default_factory=list)
    impact_points: int = 0
    category: str = ""
    impact_chf: Optional[float] = None
    confidence: Optional[EnhancedConfidence] = None


__all__ = ["ResponseCard", "PremierEclairageSchema", "CardCtaSchema"]
