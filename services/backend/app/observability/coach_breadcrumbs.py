"""Wave 1a D-15 — uniform Sentry breadcrumb emitter for coach server-side tools.

Every _compute_<tool> path in plans 01-05 calls emit_coach_tool_breadcrumb
with the EXACT 5-kwarg payload mandated by D-15:
  - tool_name        : str  — e.g. "budget_status"
  - inputs_hash      : str  — 64-char hex SHA-256 of profile slice
  - profile_id_hashed: str  — 16-char hex SHA-256 prefix (irreversible)
  - elapsed_ms       : int  — wall-clock ms for the compute path
  - flag_state       : Literal["on", "off"] — staged-rollout flag state

The `coach.tool.*` breadcrumb category prefix is locked at scaffolding time.
Non-tool coach paths need their own helper. Plan-06 (cap_status garde) does
NOT use this helper — it has its own coach.cap.cap_chf_uncited breadcrumb
with snippet payload (D-09).
"""
from __future__ import annotations

from typing import Literal

try:
    import sentry_sdk  # type: ignore
except Exception:  # pragma: no cover — fail-open if SDK unavailable
    sentry_sdk = None  # type: ignore


def emit_coach_tool_breadcrumb(
    tool_name: str,
    inputs_hash: str,
    profile_id_hashed: str,
    elapsed_ms: int,
    flag_state: Literal["on", "off"],
) -> None:
    """Fail-open Sentry breadcrumb for Wave 1a coach tools.

    Payload is non-PII by construction:
      - inputs_hash : SHA-256 of canonical-JSON profile slice (irreversible).
      - profile_id_hashed : 16-char SHA-256 prefix (irreversible).
      - elapsed_ms, flag_state : scalar telemetry.
    """
    if sentry_sdk is None:
        return
    try:
        sentry_sdk.add_breadcrumb(  # type: ignore[union-attr]
            category=f"coach.tool.{tool_name}",
            message="invoked",
            level="info",
            data={
                "inputs_hash": inputs_hash,
                "profile_id_hashed": profile_id_hashed,
                "elapsed_ms": elapsed_ms,
                "flag_state": flag_state,
            },
        )
    except Exception:
        # Never let telemetry break the coach response path.
        pass
