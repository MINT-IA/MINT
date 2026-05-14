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

from typing import Dict, Literal, Optional

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
    extra_tags: Optional[Dict[str, str]] = None,
) -> None:
    """Fail-open Sentry breadcrumb for Wave 1a coach tools.

    Payload is non-PII by construction:
      - inputs_hash : SHA-256 of canonical-JSON profile slice (irreversible).
      - profile_id_hashed : 16-char SHA-256 prefix (irreversible).
      - elapsed_ms, flag_state : scalar telemetry.
      - extra_tags (Wave 1a D-15 + RESEARCH §3 caveat #3) : optional dict
        of enum-string tags for data-quality observability (e.g.
        `lpp_buyback_source`, `tax_saving_source`). Values MUST be enum
        strings (never raw CHF, user_id, canton). Plan-03 cross_pillar
        first consumer; plan-00 shipped without this kwarg, plan-03 added
        it backward-compatibly (default None preserves plan-01/02 calls).
    """
    if sentry_sdk is None:
        return
    try:
        data: Dict[str, object] = {
            "inputs_hash": inputs_hash,
            "profile_id_hashed": profile_id_hashed,
            "elapsed_ms": elapsed_ms,
            "flag_state": flag_state,
        }
        if extra_tags:
            # Merge enum-string tags. Existing keys are NOT overwritten
            # so callers cannot accidentally clobber the D-15 5-kwarg
            # invariant payload.
            for tag_k, tag_v in extra_tags.items():
                if tag_k not in data:
                    data[tag_k] = tag_v
        sentry_sdk.add_breadcrumb(  # type: ignore[union-attr]
            category=f"coach.tool.{tool_name}",
            message="invoked",
            level="info",
            data=data,
        )
    except Exception:
        # Never let telemetry break the coach response path.
        pass
