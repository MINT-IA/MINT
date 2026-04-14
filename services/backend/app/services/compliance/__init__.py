"""Compliance package — Phase 29-04.

New home for compliance services that gate user-facing LLM output:
    - vision_guard: LLM-as-judge (Claude Haiku 4.5) on Vision critical outputs
    - numeric_sanity: deterministic bounds on extracted numeric fields

The existing coach-side ``app.services.coach.compliance_guard.ComplianceGuard``
is untouched — it keeps handling the 5-layer banned-term / hallucination /
disclaimer pipeline on coach chat. This package adds a LSFin-specific judge
on Vision-derived free text (summary, narrative, premier_eclairage) before
any of that text is surfaced to the user.

See also: plan 29-04, CONTEXT.md §ComplianceGuard sur Vision (PRIV-05).
"""

from app.services.compliance.vision_guard import (
    GuardVerdict,
    judge_vision_output,
)
from app.services.compliance.numeric_sanity import (
    FieldReject,
    SanityVerdict,
    check,
    BOUNDS,
)

__all__ = [
    "GuardVerdict",
    "judge_vision_output",
    "FieldReject",
    "SanityVerdict",
    "check",
    "BOUNDS",
]
