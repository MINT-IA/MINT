"""Phase 95 DAG-INVALIDATION — ProjectionGroundingPack JSON contract.

Replaces the Phase 93.5 frozenset stub. The 18-key namespace is
inherited verbatim from `citation_registry.CITATION_REGISTRY` ; any
key drift between this model's `entries` dict and the registry triggers
the D-09 double-lookup fallback path (citation_parser._substitute_placeholders).

Per CONTEXT D-07 + D-08 + RESEARCH §D-07/D-08 :
- `model_config = ConfigDict(frozen=True, extra="forbid")` — Pydantic v2
  invariant project-wide (precedent : citation_registry.py:51).
- Decimal serialisation uses `field_serializer` to stringify (JSON has
  no native Decimal — `json.dumps(Decimal("1.50"))` raises TypeError).
- `staleness_iso` is ISO 8601 string, NOT datetime (cross-runtime
  determinism — Python and Dart serialise datetime objects differently).

Phase 95 Wave 2 emitter wires this into financial_core consumer wrappers
(pareto.py + sensitivity.py + bootstrap_ci.py). Phase 96 narrator templates
will consume the pack through citation_parser._substitute_placeholders.

Backward-compat : `GROUNDING_PACK_KEYS_REGISTRY` frozenset is kept for one
cycle so that pre-existing consumers
(`tests/bundles/test_bundle_contract.py:35`) keep importing without
breaking. It is retired in the post-96 cleanup phase per CONTEXT
§"Deferred Ideas".
"""
from __future__ import annotations

from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_serializer


class GroundingPackEntry(BaseModel):
    """One cited value in a ProjectionGroundingPack.

    Per CONTEXT D-08 :
    - `value` : canonical Decimal (CHF or pct depending on key).
    - `raw` : full financial_core trace dict (audit-trail).
    - `source_ref` : calc-call signature (e.g. `pareto.compute_3a_ceiling`).
    - `credible_low` / `credible_high` : bootstrap P5/P95 percentiles
      (None when the underlying calc is deterministic, not stochastic).
    - `staleness_iso` : ISO 8601 timestamp of the input snapshot.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    value: Decimal
    raw: dict
    source_ref: str
    credible_low: Optional[Decimal] = None
    credible_high: Optional[Decimal] = None
    staleness_iso: str

    @field_serializer("value", "credible_low", "credible_high")
    def _ser_decimal(self, v: Optional[Decimal]) -> Optional[str]:
        # Decimal -> str preserves precision in JSON ; clients re-hydrate
        # via Decimal(value_str).
        return None if v is None else str(v)


class ParetoPoint(BaseModel):
    """3-point scalarisation result per CONTEXT D-10.

    Three fixed weight sets (fiscal_pure / liquidity_prioritized /
    ruin_reduction_prioritized) — `label` identifies which one.
    Allocation is the recommended CHF split across the 3 leviers
    (3a / rachat_lpp / amort_indirect).
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    label: str
    weights: dict
    allocation: dict
    projected_outcomes: dict

    @field_serializer("weights", "allocation", "projected_outcomes")
    def _ser_dec_dict(self, d: dict) -> dict:
        return {k: str(v) for k, v in d.items()}


class ProjectionGroundingPack(BaseModel):
    """Per CONTEXT D-07 + D-08 — the JSON contract Phase 96 narrator consumes."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    inputs_hash: str = Field(..., min_length=64, max_length=64)  # SHA256 hex
    entries: dict
    pareto_points: list = Field(..., min_length=3, max_length=3)
    what_ifs: dict = Field(..., min_length=5, max_length=5)
    legal_constraints: list
    superseded_by: Optional[str] = Field(default=None, min_length=36, max_length=36)


# Phase 93.5 backward-compat — derived view kept for one cycle so
# bundles' `citation_allowlist` references don't break. Will be retired
# in the post-96 cleanup phase per CONTEXT §"Deferred Ideas".
GROUNDING_PACK_KEYS_REGISTRY: frozenset = frozenset()


__all__ = [
    "GroundingPackEntry",
    "ParetoPoint",
    "ProjectionGroundingPack",
    "GROUNDING_PACK_KEYS_REGISTRY",
]
