"""
Admin endpoints for operational observability.

All endpoints require admin role (RBAC: role=support_admin AND email in allowlist).
Gated by feature flag: enable_admin_screens.
"""

import os
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.config import settings
from app.core.database import get_db
from app.models.audit_event import AuditEventModel
from app.models.user import User
from app.schemas.audit import AuditEventResponse, PaginatedAuditResponse
from app.services.feature_flags import FeatureFlags

router = APIRouter()


def _require_admin(current_user: User) -> None:
    """Require BOTH DB role AND email in allowlist (defense in depth).

    Matches the RBAC pattern from analytics.py admin endpoints.
    Reads allowlist from env var first, falls back to settings.
    """
    has_role = getattr(current_user, "role", None) == "support_admin"
    allowlist_raw = os.getenv("AUTH_ADMIN_EMAIL_ALLOWLIST")
    if allowlist_raw is None:
        allowlist_raw = settings.AUTH_ADMIN_EMAIL_ALLOWLIST
    allowlist_raw = allowlist_raw.strip()
    admin_emails = {
        e.strip().lower() for e in allowlist_raw.split(",") if e.strip()
    }
    has_email = (current_user.email or "").strip().lower() in admin_emails
    if not has_role or not has_email:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Role support_admin requis",
        )


@router.get("/audit", response_model=PaginatedAuditResponse)
def list_audit_events(
    event_type: Optional[str] = Query(None, description="Filter by event_type"),
    user_id: Optional[str] = Query(None, description="Filter by user_id"),
    audit_status: Optional[str] = Query(None, alias="status", description="Filter by status"),
    limit: int = Query(default=50, ge=1, le=500, description="Max results"),
    offset: int = Query(default=0, ge=0, description="Pagination offset"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> PaginatedAuditResponse:
    """List audit events with optional filters.

    Requires admin role + feature flag enable_admin_screens.
    Results are ordered by created_at descending (most recent first).
    """
    FeatureFlags.require_flag("enable_admin_screens")
    _require_admin(current_user)

    query = db.query(AuditEventModel)

    if event_type:
        query = query.filter(AuditEventModel.event_type == event_type)
    if user_id:
        query = query.filter(AuditEventModel.user_id == user_id)
    if audit_status:
        query = query.filter(AuditEventModel.status == audit_status)

    total = query.count()

    events = (
        query.order_by(AuditEventModel.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )

    return PaginatedAuditResponse(
        items=[AuditEventResponse.model_validate(e) for e in events],
        total=total,
        limit=limit,
        offset=offset,
    )


# ---------------------------------------------------------------------------
# v2.7 Task 5: Feature flag admin endpoints
# Protected by MINT_ADMIN_TOKEN env var (header X-Admin-Token). This is a
# simpler contract than the support_admin RBAC because flag toggling is ops-
# level (not user-facing analytics) and must work in bootstrap scenarios
# before any DB role exists.
# ---------------------------------------------------------------------------

from fastapi import Header  # noqa: E402
from app.services.flags_service import REGISTERED_FLAGS, flags  # noqa: E402


def _require_admin_token(x_admin_token: Optional[str]) -> None:
    expected = os.environ.get("MINT_ADMIN_TOKEN")
    if not expected:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="MINT_ADMIN_TOKEN not configured on this server.",
        )
    if not x_admin_token or x_admin_token != expected:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid admin token.",
        )


@router.post("/flags/{flag}")
async def set_feature_flag(
    flag: str,
    value: bool = Query(..., description="True to enable, False to disable"),
    user: Optional[str] = Query(None, description="If set, scope change to dogfood list for this user_id"),
    x_admin_token: Optional[str] = Header(None, alias="X-Admin-Token"),
):
    """Toggle a feature flag globally or add/remove a user from dogfood.

    Examples:
        POST /admin/flags/COACH_FSM_ENABLED?value=true            → global on
        POST /admin/flags/COACH_FSM_ENABLED?value=true&user=u1    → dogfood u1
        POST /admin/flags/COACH_FSM_ENABLED?value=false&user=u1   → remove u1
    """
    _require_admin_token(x_admin_token)
    if flag not in REGISTERED_FLAGS:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Unknown flag '{flag}'. Registered: {sorted(REGISTERED_FLAGS)}",
        )
    ok = await flags.set(flag, value, user_scope=user)
    return {"flag": flag, "value": value, "user": user, "stored": ok}


@router.get("/flags/{flag}")
async def get_feature_flag(
    flag: str,
    user: Optional[str] = Query(None),
    x_admin_token: Optional[str] = Header(None, alias="X-Admin-Token"),
):
    _require_admin_token(x_admin_token)
    if flag not in REGISTERED_FLAGS:
        raise HTTPException(status_code=404, detail="Unknown flag")
    enabled = await flags.is_enabled(flag, user_id=user)
    return {"flag": flag, "user": user, "enabled": enabled}
