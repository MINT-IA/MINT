"""Shared profile-resolver helpers for the MINT Lucidité Engine (calc-engine-v1).

Three primitives + one FastAPI dependency, consumed by every REST endpoint
that flows real `_user.profile` values into a Pydantic request schema:

  - `_resolve_defaults(profile_data, body, schema_class)` — merge body > profile
    > Pydantic default, honoring `body.model_fields_set` so explicit-None from
    the client is preserved (D-CE-07).
  - `_required_profile_fields_missing(resolved, schema_class)` — report the
    PROFILE KEYS (not body field names) whose `from_profile` marker resolved
    to None, capped at 3 (D-A3-01 conversational handshake cap).
  - `raise_incomplete_as_422(missing_fields, hint_fr, ...)` — D-CE-08 feature
    flag : strict mode raises HTTPException(422) carrying the
    `CoachToolIncomplete` envelope verbatim (D-CE-04) ; non-strict mode logs a
    warning + returns the resolved body for graceful Flutter rollout.
  - `get_profile_filled(...)` — FastAPI dependency returning the authenticated
    user's most recent `profile.data` dict, or `{}` if none exists.

D-CE-07 rationale (REJECT ContextVar): magic-of-invisible-ambient-context is
the OPPOSITE of what a finance app needs. Explicit body+profile+schema args
are testable in isolation (no TestClient required).

LSFin (CLAUDE.md §1): all caller-supplied `hint_fr` strings must use «
pourrait / envisager / adapté » vocabulary. The narrator-output ban-list
lives in `tools/checks/banned_terms_python.py` and is enforced at commit
time by the lefthook pre-commit hook.
"""
from __future__ import annotations

import logging
import os
from typing import Any

from fastapi import Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.database import get_db
from app.models.coach_tools._response import CoachToolIncomplete
from app.models.profile_model import ProfileModel
from app.models.user import User


def _resolve_defaults(
    profile_data: dict[str, Any] | None,
    body: BaseModel,
    schema_class: type[BaseModel],
) -> dict[str, Any]:
    """Merge body > profile > default into a flat dict.

    Verified semantics (RESEARCH §Q-B):
      - field in `body.model_fields_set` → respect body value (even None =
        explicit clear from the client) — body always wins when set.
      - field NOT in body.model_fields_set AND
        `field_info.json_schema_extra["from_profile"]` present AND
        profile has the key with a non-None value → fill from profile.
      - otherwise → fall through to the Pydantic default (typically None).

    Returns a fresh dict ; never mutates `profile_data` or `body`.

    Note (Plan 17) : prefer `_resolve_with_provenance` when the caller needs
    the D-CE-17 `inputs_provenance` audit dict. This function is the V1
    contract — kept unchanged for Wave 1 callers that don't need provenance.
    """
    resolved, _ = _resolve_with_provenance(profile_data, body, schema_class)
    return resolved


def _resolve_with_provenance(
    profile_data: dict[str, Any] | None,
    body: BaseModel,
    schema_class: type[BaseModel],
) -> tuple[dict[str, Any], dict[str, str]]:
    """Plan 17 W4-01-03 (D-CE-17) — `_resolve_defaults` variant returning a
    per-field provenance dict alongside the resolved values.

    Returns:
        `(resolved, provenance)` where `provenance[field_name]` is exactly
        one of :
          - ``"user_input"`` — field was in ``body.model_fields_set``
            (client supplied it explicitly, even if None).
          - ``"default"``    — field was filled from the user's profile via
            the ``from_profile`` marker (server-side fallback). This
            semantic-choice naming follows RESEARCH §Q-H — « default » in
            the audit trail means « profile-driven default », distinct from
            « Pydantic default » (which is ``"derived"`` below).
          - ``"derived"``    — field was NOT in body, has no profile_key
            with a value, fell through to ``getattr(body, name)`` (the
            Pydantic default — typically None or a schema-defined fallback).

    The 3 values match the ``Literal["user_input", "default", "derived"]``
    type on ``CoachToolOkV2.inputs_provenance`` and are auditable per
    D-CE-17 composite scorecard.
    """
    if profile_data is None:
        profile_data = {}
    resolved: dict[str, Any] = {}
    provenance: dict[str, str] = {}
    body_set = body.model_fields_set
    for name, field_info in schema_class.model_fields.items():
        if name in body_set:
            resolved[name] = getattr(body, name)
            provenance[name] = "user_input"
            continue
        extra = field_info.json_schema_extra or {}
        profile_key = (
            extra.get("from_profile") if isinstance(extra, dict) else None
        )
        if (
            profile_key
            and profile_key in profile_data
            and profile_data[profile_key] is not None
        ):
            resolved[name] = profile_data[profile_key]
            provenance[name] = "default"  # server-side fallback from profile
        else:
            resolved[name] = getattr(body, name)
            provenance[name] = "derived"  # Pydantic default / no profile_key
    return resolved, provenance


def emit_calc_invoke_metric(
    kind: str,
    resolved: dict[str, Any],
    schema_class: type[BaseModel],
) -> None:
    """Plan 17 W4-01-02 (D-CE-17 PRIMARY) — fire `mint_calc_invoke_total`.

    `profile_grounded` label is "true" iff ANY field declaring a
    ``from_profile`` marker resolved to a non-None value (the calc had
    real profile data available, vs falling back to body/default only).

    Late-imports `app.core.metrics` to avoid a circular import at module
    load time (metrics.py imports nothing from profile_resolver but tests
    that mock the resolver can preempt the registry).

    Args:
        kind: calculator kind / tool name used as the Prometheus `kind` label.
            Convention : the REST path tail (e.g. ``"allocation_annuelle"``)
            OR the chip-emitter name (e.g. ``"get_budget_status"``).
        resolved: the resolved dict returned by `_resolve_defaults` /
            `_resolve_with_provenance`.
        schema_class: the Pydantic request schema (used to inspect
            ``from_profile`` markers).

    Safe to call from any handler — never raises ; metric increments are
    fire-and-forget.
    """
    try:  # pragma: no cover — defensive : metric must never break the request
        any_grounded = False
        for name, field_info in schema_class.model_fields.items():
            extra = field_info.json_schema_extra or {}
            if not isinstance(extra, dict) or "from_profile" not in extra:
                continue
            if resolved.get(name) is not None:
                any_grounded = True
                break
        from app.core.metrics import calc_invoke_total

        calc_invoke_total.labels(
            kind=kind, profile_grounded=str(any_grounded).lower()
        ).inc()
    except Exception:  # pragma: no cover
        _logger.warning(
            "emit_calc_invoke_metric failed (swallowed): kind=%r", kind
        )


def _required_profile_fields_missing(
    resolved: dict[str, Any],
    schema_class: type[BaseModel],
) -> list[str]:
    """Report PROFILE KEYS (not body field names) that resolved to None.

    Only walks fields that declare `json_schema_extra["from_profile"]` — fields
    without the marker are not considered profile-grounded and are excluded
    from the missing list (Test 6 of W1-01-01).

    The returned list is capped at 3 entries per the D-A3-01 conversational
    handshake decision inherited via D-CE-04. The caller MUST pass the result
    straight to `raise_incomplete_as_422` (or `CoachToolIncomplete` directly)
    — do not pad, do not truncate further.
    """
    missing: list[str] = []
    for name, field_info in schema_class.model_fields.items():
        extra = field_info.json_schema_extra or {}
        if isinstance(extra, dict) and "from_profile" in extra:
            if resolved.get(name) is None:
                missing.append(extra["from_profile"])
    return missing[:3]


# D-CE-08 feature flag for graceful Flutter rollout.
# Rollout sequence (per CONTEXT.md D-CE-08) :
#   staging strict=true → production strict=false (1 release) → production strict=true.
# Default = "false" so running the test suite WITHOUT setting the env var
# leaves the helper in non-strict mode (strict mode requires explicit opt-in).
PROFILE_GROUNDING_STRICT_MODE: bool = (
    os.getenv("PROFILE_GROUNDING_STRICT_MODE", "false").lower() == "true"
)

_logger = logging.getLogger(__name__)


def raise_incomplete_as_422(
    missing_fields: list[str],
    hint_fr: str,
    *,
    resolved_body: dict[str, Any] | None = None,
    endpoint: str | None = None,
) -> dict[str, Any]:
    """D-CE-08 helper : turn a missing-profile-fields list into a 422 (strict)
    or a logged warning + body passthrough (non-strict).

    Strict path : raises `HTTPException(422)` whose `detail` is the
    `CoachToolIncomplete` envelope dumped by-alias (camelCase: `status`,
    `missingFields`, `hintFr`). Inherits the D-A3-01 cap=3 validator — passing
    >3 entries raises `ValueError` BEFORE the HTTPException is built (the cap
    belongs to the envelope, mode-independent).

    Non-strict path : emits a `WARNING` log via the module logger with
    `extra={endpoint, missing_fields, hint_fr}` so observability can surface
    silent grounding gaps, then returns `resolved_body` (defaults to `{}`) so
    the caller can continue computation in the legacy hardcoded-defaults
    branch.

    Returns the body dict ONLY in non-strict path — in strict path the
    function never returns (raises HTTPException).
    """
    incomplete = CoachToolIncomplete(missing_fields=missing_fields, hint_fr=hint_fr)
    if PROFILE_GROUNDING_STRICT_MODE:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=incomplete.model_dump(by_alias=True),
        )
    # Graceful fallback : log + return resolved body (legacy behavior continues).
    _logger.warning(
        "profile_grounding_incomplete_non_strict",
        extra={
            "endpoint": endpoint or "unknown",
            "missing_fields": missing_fields,
            "hint_fr": hint_fr,
        },
    )
    return resolved_body or {}


def get_profile_filled(
    user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """FastAPI dependency : return the authenticated user's profile.data dict.

    Returns `{}` when:
      - no `ProfileModel` row exists for the user, or
      - the most recent profile has `data` set to None/empty.

    Picks the most recent profile by `updated_at DESC` to handle the rare race
    where two profile rows exist for the same user (e.g. a stale fixture row
    + a freshly migrated row).

    Only reads the authenticated user's OWN profile (filter
    `ProfileModel.user_id == user.id`) — no cross-user access path.
    """
    profile = (
        db.query(ProfileModel)
        .filter(ProfileModel.user_id == user.id)
        .order_by(ProfileModel.updated_at.desc())
        .first()
    )
    return profile.data if profile and profile.data else {}
