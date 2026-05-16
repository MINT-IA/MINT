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
    """
    if profile_data is None:
        profile_data = {}
    resolved: dict[str, Any] = {}
    body_set = body.model_fields_set
    for name, field_info in schema_class.model_fields.items():
        if name in body_set:
            resolved[name] = getattr(body, name)
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
        else:
            resolved[name] = getattr(body, name)
    return resolved


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
