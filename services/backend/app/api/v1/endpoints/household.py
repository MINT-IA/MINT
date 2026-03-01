"""
Household management endpoints (Couple+ billing).
"""

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.config import settings
from app.core.database import get_db
from app.models.user import User
from app.services.household_service import (
    get_household_details,
    invite_partner,
    accept_invitation,
    revoke_member,
    transfer_ownership,
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
    AdminOverrideCooldownRequest,
    AdminOverrideCooldownResponse,
)

router = APIRouter()


@router.get("", response_model=HouseholdResponse)
def get_household(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> HouseholdResponse:
    details = get_household_details(db, current_user)
    return HouseholdResponse(**details)


@router.post("/invite", response_model=InviteResponse, status_code=201)
def invite(
    body: InviteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> InviteResponse:
    result = invite_partner(db, current_user, body.email)
    return InviteResponse(**result)


@router.post("/accept", response_model=AcceptResponse)
def accept(
    body: AcceptRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> AcceptResponse:
    result = accept_invitation(db, current_user, body.invitation_code)
    return AcceptResponse(**result)


@router.delete("/member/{user_id}", response_model=RevokeResponse)
def revoke(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> RevokeResponse:
    result = revoke_member(db, current_user, user_id)
    return RevokeResponse(**result)


@router.put("/transfer", response_model=TransferResponse)
def transfer(
    body: TransferRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> TransferResponse:
    result = transfer_ownership(db, current_user, body.new_owner_id)
    return TransferResponse(**result)


@router.post("/admin/override-cooldown", response_model=AdminOverrideCooldownResponse)
def override_cooldown(
    request: Request,
    body: AdminOverrideCooldownRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> AdminOverrideCooldownResponse:
    # RBAC check: require support_admin role
    admin_emails = [e.strip() for e in settings.AUTH_ADMIN_EMAIL_ALLOWLIST.split(",") if e.strip()]
    if current_user.email not in admin_emails:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Role support_admin requis",
        )

    ip = request.headers.get("x-forwarded-for", "").split(",")[0].strip() or (
        request.client.host if request.client else None
    )
    result = admin_override_cooldown(
        db, current_user, body.user_id, body.reason,
        ip_address=ip,
        user_agent=request.headers.get("user-agent"),
    )
    return AdminOverrideCooldownResponse(**result)
