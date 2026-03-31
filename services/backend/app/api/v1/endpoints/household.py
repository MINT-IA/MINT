"""
Household management endpoints (Couple+ billing).
"""

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.config import settings
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.models.user import User
from app.services.household_service import (
    get_household_details,
    invite_partner,
    accept_invitation,
    revoke_member,
    transfer_ownership,
    dissolve_household,
    admin_override_cooldown,
)
from app.schemas.household import (
    HouseholdResponse,
    InviteRequest,
    InviteResponse,
    AcceptRequest,
    AcceptResponse,
    RevokeResponse,
    TransferRequest,
    TransferResponse,
    DissolveResponse,
    AdminOverrideCooldownRequest,
    AdminOverrideCooldownResponse,
)

router = APIRouter()


@router.get("", response_model=HouseholdResponse)
@limiter.limit("30/minute")
def get_household(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> HouseholdResponse:
    details = get_household_details(db, current_user)
    return HouseholdResponse(**details)


@router.post("/invite", response_model=InviteResponse, status_code=201)
@limiter.limit("10/minute")
def invite(
    request: Request,
    body: InviteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> InviteResponse:
    result = invite_partner(db, current_user, body.email)
    return InviteResponse(**result)


@router.post("/accept", response_model=AcceptResponse)
@limiter.limit("10/minute")
def accept(
    request: Request,
    body: AcceptRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> AcceptResponse:
    result = accept_invitation(db, current_user, body.invitation_code)
    return AcceptResponse(**result)


@router.delete("/member/{user_id}", response_model=RevokeResponse)
@limiter.limit("10/minute")
def revoke(
    request: Request,
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> RevokeResponse:
    result = revoke_member(db, current_user, user_id)
    return RevokeResponse(**result)


@router.put("/transfer", response_model=TransferResponse)
@limiter.limit("5/minute")
def transfer(
    request: Request,
    body: TransferRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> TransferResponse:
    result = transfer_ownership(db, current_user, body.new_owner_id)
    return TransferResponse(**result)


@router.delete("/dissolve", response_model=DissolveResponse)
@limiter.limit("5/minute")
def dissolve(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> DissolveResponse:
    result = dissolve_household(db, current_user)
    return DissolveResponse(**result)


@router.post("/admin/override-cooldown", response_model=AdminOverrideCooldownResponse)
@limiter.limit("5/minute")
def override_cooldown(
    request: Request,
    body: AdminOverrideCooldownRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> AdminOverrideCooldownResponse:
    # RBAC check: require BOTH DB role AND email in allowlist (defense in depth).
    # P0-4: Previously used OR — a compromised email allowlist alone granted admin.
    has_role = getattr(current_user, 'role', None) == 'support_admin'
    admin_emails = [e.strip() for e in settings.AUTH_ADMIN_EMAIL_ALLOWLIST.split(",") if e.strip()]
    has_email = current_user.email in admin_emails
    if not has_role or not has_email:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Role support_admin requis",
        )

    # Use RIGHTMOST IP — closest to the server, hardest to spoof
    ip = request.headers.get("x-forwarded-for", "").split(",")[-1].strip() or (
        request.client.host if request.client else None
    )
    result = admin_override_cooldown(
        db, current_user, body.user_id, body.reason,
        ip_address=ip,
        user_agent=request.headers.get("user-agent"),
    )
    return AdminOverrideCooldownResponse(**result)
