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
