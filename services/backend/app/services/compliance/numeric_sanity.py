"""Numeric sanity checker — reject impossible Vision-extracted values.

PRIV-05 (numeric half) — Phase 29-04.

Deterministic bounds on critical extracted fields (OFAS statistics +
LPP legal ranges). Runs BEFORE the LLM-as-judge (vision_guard) because
it is cheap, has zero API cost, and catches the crudest prompt-injection
attacks ("rendement 50%") at the gate.

Dispositions:
    - ok           : value is in-bounds
    - reject       : value is impossible — block persistence, render reject
    - human_review : value is rare-but-legal (ultra-HNW avoir_lpp > 5M) —
                     persist BUT flag for human review; never auto-promote
                     to user_validated.

Bounds (from CONTEXT.md §ComplianceGuard sur Vision + OFAS 2024 stats):
    rendement        > 8%      reject         (max OFAS historical = ~7%)
    avoir_lpp        > 5M CHF  human_review   (legal, rare, needs eyes on)
    salaire          > 2M CHF  reject         (P99 OFS ~1.2M)
    taux_conversion  > 7%      reject         (LPP max legal = 6.8%)

Field-name detection uses a fuzzy contains-match on the canonical enum
values from Phase 28 ROUTE_AND_EXTRACT_TOOL schema + camelCase variants
emitted by the fused Vision tool (avoirLppTotal, salaireAssure, etc.).
"""
from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Callable, Dict, List, Literal, Optional, Sequence, Tuple

from pydantic import BaseModel, ConfigDict

Disposition = Literal["ok", "reject", "human_review"]


# ---------------------------------------------------------------------------
# Bounds table — canonical source of truth.
# ---------------------------------------------------------------------------
# Each entry: (disposition_on_violation, predicate, human_readable_bound)
BoundEntry = Tuple[Disposition, Callable[[Decimal], bool], str]

BOUNDS: Dict[str, BoundEntry] = {
    # Rendement / performance rate — decimal form (6.8% = 0.068).
    "rendement": (
        "reject",
        lambda v: v > Decimal("0.08"),
        "rendement > 8% impossible (OFAS historical max ~7%)",
    ),
    # LPP avoir — legal but rare when ultra-HNW. Human review.
    "avoir_lpp": (
        "human_review",
        lambda v: v > Decimal("5000000"),
        "avoir_lpp > 5M CHF — rare, needs human review (not rejected)",
    ),
    # Salary — both brut and assure. OFS P99 ~1.2M; > 2M impossible.
    "salaire": (
        "reject",
        lambda v: v > Decimal("2000000"),
        "salaire > 2M CHF impossible (OFS P99 ~1.2M)",
    ),
    # LPP conversion rate — legal max 6.8%.
    "taux_conversion": (
        "reject",
        lambda v: v > Decimal("0.07"),
        "taux_conversion > 7% impossible (LPP legal max 6.8%)",
    ),
}


# Field-name aliases — maps Vision-emitted field names (camelCase from the
# fused tool + snake_case from legacy scans) to the bound key.
# Keep the matcher cheap: contains-on-lowercase, longest-first to avoid
# `salaire_assure` mis-matching the `avoir_lpp` bound.
_ALIASES: Sequence[Tuple[str, str]] = (
    ("tauxconversion", "taux_conversion"),
    ("taux_conversion", "taux_conversion"),
    ("avoirlpp", "avoir_lpp"),
    ("avoir_lpp", "avoir_lpp"),
    ("salaire", "salaire"),
    ("rendement", "rendement"),
)


def _bound_key_for(field_name: str) -> Optional[str]:
    """Return the BOUNDS key matching a Vision-emitted field name, or None."""
    if not field_name:
        return None
    lowered = field_name.lower().replace(" ", "")
    for alias, key in _ALIASES:
        if alias in lowered:
            return key
    return None


def _to_decimal(value: object) -> Optional[Decimal]:
    """Coerce a Vision-extracted value to Decimal, or None if not numeric."""
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float, Decimal)):
        try:
            return Decimal(str(value))
        except InvalidOperation:
            return None
    if isinstance(value, str):
        # Strip Swiss thousands separators (space, apostrophe) before parsing.
        cleaned = value.replace("'", "").replace(" ", "").replace("CHF", "")
        cleaned = cleaned.strip()
        try:
            return Decimal(cleaned)
        except InvalidOperation:
            return None
    return None


# ---------------------------------------------------------------------------
# Pydantic models — explicit contract for callers (document_vision_service).
# ---------------------------------------------------------------------------


class FieldReject(BaseModel):
    """A single field that violated a numeric sanity bound."""

    model_config = ConfigDict(frozen=True)

    field_name: str
    value: Decimal
    bound: str  # human-readable reason
    disposition: Disposition = "reject"


class SanityVerdict(BaseModel):
    """Outcome of a numeric sanity check over a batch of fields."""

    fields: Dict[str, Disposition]
    rejects: List[FieldReject]
    human_reviews: List[FieldReject]

    @property
    def has_reject(self) -> bool:
        return any(r.disposition == "reject" for r in self.rejects)

    @property
    def has_human_review(self) -> bool:
        return bool(self.human_reviews)


# ---------------------------------------------------------------------------
# Public API.
# ---------------------------------------------------------------------------


def check(fields: Sequence[object]) -> SanityVerdict:
    """Run numeric sanity over a list of Vision-extracted field objects.

    The input is duck-typed — each item needs ``field_name`` and ``value``
    attributes (matches both ``ExtractedField`` and ``ExtractedFieldConfirmation``
    from the existing schemas, so callers don't have to convert).

    Fields with a non-numeric value or no matching bound are marked "ok"
    (they're simply out-of-scope for this check).
    """
    dispositions: Dict[str, Disposition] = {}
    rejects: List[FieldReject] = []
    human_reviews: List[FieldReject] = []

    for field in fields:
        name = getattr(field, "field_name", None) or getattr(field, "name", None) or ""
        value = getattr(field, "value", None)

        key = _bound_key_for(name)
        if key is None:
            dispositions[name] = "ok"
            continue

        dec = _to_decimal(value)
        if dec is None:
            dispositions[name] = "ok"
            continue

        disposition, predicate, bound_text = BOUNDS[key]
        if predicate(dec):
            dispositions[name] = disposition
            entry = FieldReject(
                field_name=name,
                value=dec,
                bound=bound_text,
                disposition=disposition,
            )
            if disposition == "reject":
                rejects.append(entry)
            else:
                human_reviews.append(entry)
        else:
            dispositions[name] = "ok"

    return SanityVerdict(
        fields=dispositions,
        rejects=rejects,
        human_reviews=human_reviews,
    )


__all__ = [
    "BOUNDS",
    "Disposition",
    "FieldReject",
    "SanityVerdict",
    "check",
]
