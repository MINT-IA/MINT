"""Render mode selector — deterministic algo, never heuristic in caller.

v2.7 Phase 28 / DOC-05.

Backend computes one of 4 opaque `render_mode`s. Callers (chat bubble,
review screen, narrative card) switch UI off this single enum.

Algo (in order):
    1. extraction_status in terminal-fail set → reject
    2. extraction_status in soft-fail set     → narrative
    3. overall>=0.90 + few fields + no warns  → confirm
    4. overall>=0.75 + 1-2 below-high + no high-stakes-low → ask
    5. overall>=0.60                          → narrative
    6. else                                   → reject

`needs_full_review()` is the orthogonal escalation predicate consumed by
the (reduced) ExtractionReviewScreen.
"""
from __future__ import annotations

from app.schemas.document_understanding import (
    ConfidenceLevel,
    DocumentUnderstandingResult,
    ExtractionStatus,
    RenderMode,
)

# High-stakes fields — if confidence is low on any of these, route to ask
# (or force escalation to review). Scoped to fields where a wrong value
# would cause a measurably bad financial decision.
HIGH_STAKES = {
    "avoirLppTotal",
    "tauxConversion",
    "rachatMaximum",
    "salaireAssure",
    "revenuImposable",
    "fortuneImposable",
}

_TERMINAL_REJECT = {
    ExtractionStatus.non_financial,
    ExtractionStatus.rejected_local,
}

_SOFT_FAIL_NARRATIVE = {
    ExtractionStatus.parse_error,
    ExtractionStatus.no_fields_found,
    ExtractionStatus.encrypted_needs_password,
}


def select_render_mode(result: DocumentUnderstandingResult) -> RenderMode:
    """Compute the render_mode for a result. Pure function, deterministic."""
    if result.extraction_status in _TERMINAL_REJECT:
        return RenderMode.reject
    if result.extraction_status in _SOFT_FAIL_NARRATIVE:
        return RenderMode.narrative

    overall = result.overall_confidence
    fields_below = [
        f for f in result.extracted_fields
        if f.confidence != ConfidenceLevel.high
    ]
    has_high_stakes_low_conf = any(
        f.field_name in HIGH_STAKES and f.confidence != ConfidenceLevel.high
        for f in result.extracted_fields
    )

    if (
        overall >= 0.90
        and len(result.extracted_fields) <= 8
        and not fields_below
        and not result.coherence_warnings
    ):
        return RenderMode.confirm

    if (
        overall >= 0.75
        and 1 <= len(fields_below) <= 2
        and not has_high_stakes_low_conf
    ):
        return RenderMode.ask

    if overall >= 0.60:
        return RenderMode.narrative

    return RenderMode.reject


def needs_full_review(result: DocumentUnderstandingResult) -> bool:
    """Orthogonal escalation: should ExtractionReviewScreen be opened?"""
    has_high_stakes_low_conf = any(
        f.field_name in HIGH_STAKES and f.confidence != ConfidenceLevel.high
        for f in result.extracted_fields
    )
    return (
        has_high_stakes_low_conf
        or bool(result.coherence_warnings)
        or result.plan_type == "1e"
        or result.overall_confidence < 0.75
    )


__all__ = ["select_render_mode", "needs_full_review", "HIGH_STAKES"]
