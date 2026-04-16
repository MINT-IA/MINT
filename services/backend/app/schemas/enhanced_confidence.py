"""
Enhanced 4-axis confidence — wire schema (Plan 08a-01, D-05).

Locked wire shape carrying the 4 confidence axes plus the computed
combined ``score`` for quick rendering. Enrichment prompts are NOT
shipped over the wire — clients derive them locally.

Mirrors the mobile ``EnhancedConfidence`` class
(``apps/mobile/lib/services/financial_core/confidence_scorer.dart``).

All values are in the [0.0, 1.0] range.

References:
    - docs/AUDIT-01-confidence-semantics.md
    - .planning/phases/08a-l1.2b-mtc-11-surface-migration/08a-CONTEXT.md (D-05)
"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class EnhancedConfidence(BaseModel):
    """4-axis confidence wire payload (Plan 08a-01).

    Wire shape::

        {
            "completeness": 0.8,
            "accuracy": 0.9,
            "freshness": 0.7,
            "understanding": 0.6,
            "score": 0.74
        }
    """

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    completeness: float = Field(..., ge=0.0, le=1.0)
    accuracy: float = Field(..., ge=0.0, le=1.0)
    freshness: float = Field(..., ge=0.0, le=1.0)
    understanding: float = Field(..., ge=0.0, le=1.0)
    score: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Computed combined score (e.g. geometric mean of the 4 axes).",
    )


__all__ = ["EnhancedConfidence"]
