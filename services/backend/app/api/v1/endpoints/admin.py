"""
Admin endpoints for operational observability.

All endpoints require admin role (RBAC: role=support_admin AND email in allowlist).
Gated by feature flag: enable_admin_screens.
"""

import os
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.config import settings
from app.core.database import get_db
from app.models.audit_event import AuditEventModel
from app.models.profile_model import ProfileModel
from app.models.user import User
from app.schemas.audit import AuditEventResponse, PaginatedAuditResponse
from app.schemas.sync import (
    AdminLocalDataClaimSummaryResponse,
    LocalDataClaimMetaSummary,
)
from app.services.feature_flags import FeatureFlags

router = APIRouter()

_ALLOWED_MINT2_AXIS_IDS = {"lpp_rente_capital"}

_WIZARD_AXIS_KEYS = {
    "mint2AxisHandoff",
    "mint2_axis_handoff",
    "onb_axis_v2",
    "onb_axis_schema_version",
    "legacy_onb_intent",
    "onb_signal_axes_v2",
}


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


def _safe_mint2_axis_id(value: Any) -> Optional[str]:
    if not isinstance(value, dict):
        return None
    axis_id = value.get("onb_axis_v2")
    return axis_id if axis_id in _ALLOWED_MINT2_AXIS_IDS else None


def _wizard_answers_contains_axis(value: Any) -> bool:
    if not isinstance(value, dict):
        return False
    return any(key in value for key in _WIZARD_AXIS_KEYS)


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


@router.get(
    "/local-data-claim-summary/{profile_id}",
    response_model=AdminLocalDataClaimSummaryResponse,
)
def get_local_data_claim_summary(
    profile_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> AdminLocalDataClaimSummaryResponse:
    """Return a PII-free summary of local-data claim state for admin proof."""
    FeatureFlags.require_flag("enable_admin_screens")
    _require_admin(current_user)

    profile = db.query(ProfileModel).filter(ProfileModel.id == profile_id).first()
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )

    data = profile.data if isinstance(profile.data, dict) else {}
    claim = data.get("localDataClaim")
    if not isinstance(claim, dict):
        return AdminLocalDataClaimSummaryResponse(
            profile_id=profile_id,
            has_local_data_claim=False,
            wizard_answers_count=0,
            wizard_answers_contains_axis=False,
            mint2_axis_handoff_present=False,
            mint2_axis_id=None,
            schema_version=None,
            legacy_intent_present=False,
            source_engine_present=False,
            receipt_hash_present=False,
            receipt_ref_present=False,
            generated_at_present=False,
            calculation_version_present=False,
            regulatory_constants_version_hash_present=False,
            meta=LocalDataClaimMetaSummary(
                claimed_at_present=False,
                updated_at_present=False,
                device_id_present=False,
                local_data_version=None,
            ),
        )

    wizard_answers = claim.get("wizardAnswers")
    handoff = claim.get("mint2AxisHandoff")
    handoff_dict = handoff if isinstance(handoff, dict) else {}
    meta = claim.get("meta") if isinstance(claim.get("meta"), dict) else {}
    version = meta.get("localDataVersion")
    schema_version = handoff_dict.get("onb_axis_schema_version")

    return AdminLocalDataClaimSummaryResponse(
        profile_id=profile_id,
        has_local_data_claim=True,
        wizard_answers_count=len(wizard_answers) if isinstance(wizard_answers, dict) else 0,
        wizard_answers_contains_axis=_wizard_answers_contains_axis(wizard_answers),
        mint2_axis_handoff_present=bool(handoff_dict),
        mint2_axis_id=_safe_mint2_axis_id(handoff_dict),
        schema_version=schema_version if isinstance(schema_version, int) else None,
        legacy_intent_present=bool(handoff_dict.get("legacy_onb_intent")),
        source_engine_present=bool(handoff_dict.get("source_engine")),
        receipt_hash_present=bool(handoff_dict.get("receipt_hash")),
        receipt_ref_present=bool(handoff_dict.get("receipt_ref")),
        generated_at_present=bool(handoff_dict.get("generated_at")),
        calculation_version_present=bool(handoff_dict.get("calculation_version")),
        regulatory_constants_version_hash_present=bool(
            handoff_dict.get("regulatory_constants_version_hash")
        ),
        meta=LocalDataClaimMetaSummary(
            claimed_at_present=bool(meta.get("claimedAt")),
            updated_at_present=bool(meta.get("updatedAt")),
            device_id_present=bool(meta.get("deviceId")),
            local_data_version=version if isinstance(version, int) else None,
        ),
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
