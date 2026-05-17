"""Wave 1a coach-tools response models + Wave 1c-A3 envelope (D-CE-04).

Plans 01-05 each append their per-tool response model import to this
module. Wave 0 (this plan) ships only the empty marker so plans 01-05
can append without race conditions during parallel execution.

Wave 1c-A3 envelope cherry-picked into mint-calc-engine-v1 W1 base per
D-CE-04 + D-CE-19 Parallel Change pattern. The 4-class discriminated
union is the canonical tool-response contract for all coach internal
tools and (via `_resolve_defaults` + `raise_incomplete_as_422`) the
REST endpoint 422 handshake.
"""
from app.models.coach_tools._response import (
    CoachToolIncomplete,
    CoachToolIncompleteV2,
    CoachToolOk,
    CoachToolOkV2,
    CoachToolPolicyBlocked,
    CoachToolPolicyBlockedV2,
    CoachToolResponse,
    CoachToolResponseV2,
    LatencyTier,
)

__all__: list[str] = [
    # V1 (Wave 1c-A3 canonical, cherry-picked into mint-calc-engine-v1 Plan 01)
    "CoachToolIncomplete",
    "CoachToolOk",
    "CoachToolPolicyBlocked",
    "CoachToolResponse",
    # V2 (mint-calc-engine-v1 Plan 10 W2-04, Parallel Change D-CE-19, Concern B)
    "CoachToolIncompleteV2",
    "CoachToolOkV2",
    "CoachToolPolicyBlockedV2",
    "CoachToolResponseV2",
    "LatencyTier",
]
