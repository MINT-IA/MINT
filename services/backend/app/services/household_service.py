"""
Household management service for Couple+ billing.
Implements INV-1 through INV-6 from P6_BILLING_INVARIANTS.md.
"""

from __future__ import annotations

import secrets
from datetime import datetime, timedelta
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.household import HouseholdModel, HouseholdMemberModel, AdminAuditEventModel
from app.models.billing import SubscriptionModel
from app.models.user import User
from app.services.billing_service import recompute_entitlements


INVITATION_EXPIRY_HOURS = 72
COOLDOWN_DAYS = 30
MAX_ACTIVE_MEMBERS = 2


def _now() -> datetime:
    return datetime.utcnow()


def get_household_for_user(db: Session, user_id: str) -> Optional[HouseholdModel]:
    """Get the household a user belongs to (as active or pending member)."""
    membership = (
        db.query(HouseholdMemberModel)
        .filter(
            HouseholdMemberModel.user_id == user_id,
            HouseholdMemberModel.status.in_(["pending", "active"]),
        )
        .first()
    )
    if not membership:
        return None
    return db.query(HouseholdModel).filter(HouseholdModel.id == membership.household_id).first()


def get_household_details(db: Session, user: User) -> dict:
    """Get full household details for current user."""
    membership = (
        db.query(HouseholdMemberModel)
        .filter(
            HouseholdMemberModel.user_id == user.id,
            HouseholdMemberModel.status.in_(["pending", "active"]),
        )
        .first()
    )
    if not membership:
        return {"household": None, "members": [], "role": None}

    household = db.query(HouseholdModel).filter(HouseholdModel.id == membership.household_id).first()
    if not household:
        return {"household": None, "members": [], "role": None}

    # FIX-032: single query with join instead of N+1 per member.
    from sqlalchemy.orm import joinedload
    members = (
        db.query(HouseholdMemberModel)
        .filter(HouseholdMemberModel.household_id == household.id)
        .options(joinedload(HouseholdMemberModel.user))
        .all()
    )
    member_list = []
    for m in members:
        u = m.user  # pre-loaded via joinedload
        member_list.append({
            "user_id": m.user_id,
            "email": u.email if u else None,
            "display_name": u.display_name if u else None,
            "role": m.role,
            "status": m.status,
            "invited_at": m.invited_at,
            "accepted_at": m.accepted_at,
        })

    return {
        "household": {
            "id": household.id,
            "household_owner_user_id": household.household_owner_user_id,
            "billing_owner_user_id": household.billing_owner_user_id,
            "created_at": household.created_at,
        },
        "members": member_list,
        "role": membership.role,
    }


def create_household_for_billing_owner(db: Session, user: User) -> HouseholdModel:
    """Auto-create household when user subscribes to couple_plus."""
    # Check user is not already in a household
    existing = get_household_for_user(db, user.id)
    if existing:
        return existing

    household = HouseholdModel(
        household_owner_user_id=user.id,
        billing_owner_user_id=user.id,
    )
    db.add(household)
    db.flush()

    # Owner is the first active member
    owner_member = HouseholdMemberModel(
        household_id=household.id,
        user_id=user.id,
        role="owner",
        status="active",
        accepted_at=_now(),
    )
    db.add(owner_member)
    db.commit()
    return household


def invite_partner(db: Session, owner: User, partner_email: str) -> dict:
    """
    Invite a partner to the household.
    Only the household_owner can invite.
    """
    # Check caller owns a household
    household = (
        db.query(HouseholdModel)
        .filter(HouseholdModel.household_owner_user_id == owner.id)
        .first()
    )
    if not household:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu n'es pas proprietaire d'un menage",
        )

    # Check billing owner has couple_plus subscription
    billing_sub = (
        db.query(SubscriptionModel)
        .filter(SubscriptionModel.user_id == household.billing_owner_user_id)
        .order_by(SubscriptionModel.updated_at.desc())
        .first()
    )
    if not billing_sub or billing_sub.tier != "couple_plus":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Un abonnement Couple+ est requis pour inviter un\u00b7e partenaire",
        )

    # Check max active members (INV-5)
    active_count = (
        db.query(HouseholdMemberModel)
        .filter(
            HouseholdMemberModel.household_id == household.id,
            HouseholdMemberModel.status.in_(["active", "pending"]),
        )
        .count()
    )
    if active_count >= MAX_ACTIVE_MEMBERS:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Le menage a deja le nombre maximum de membres",
        )

    # Find the partner user
    partner = db.query(User).filter(User.email == partner_email).first()
    if not partner:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Aucun compte MINT avec cet e-mail",
        )

    if partner.id == owner.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tu ne peux pas t'inviter toi-meme",
        )

    # Check partner not already in a household as active/pending (INV-4)
    existing_membership = (
        db.query(HouseholdMemberModel)
        .filter(
            HouseholdMemberModel.user_id == partner.id,
            HouseholdMemberModel.status.in_(["active", "pending"]),
        )
        .first()
    )
    if existing_membership:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cette personne est deja dans un menage",
        )

    # Check cooldown (INV-6)
    last_revoked = (
        db.query(HouseholdMemberModel)
        .filter(
            HouseholdMemberModel.user_id == partner.id,
            HouseholdMemberModel.status == "revoked",
        )
        .order_by(HouseholdMemberModel.invited_at.desc())
        .first()
    )
    if last_revoked and not last_revoked.cooldown_override:
        # Use accepted_at as revocation timestamp approximation
        revoked_at = last_revoked.accepted_at or last_revoked.invited_at
        if revoked_at and (_now() - revoked_at) < timedelta(days=COOLDOWN_DAYS):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cette personne doit attendre 30 jours avant de rejoindre un nouveau menage",
            )

    # Generate invitation code
    code = secrets.token_urlsafe(32)

    # Delete any previous revoked membership for this user (unique constraint)
    old_revoked = (
        db.query(HouseholdMemberModel)
        .filter(
            HouseholdMemberModel.user_id == partner.id,
            HouseholdMemberModel.status == "revoked",
        )
        .all()
    )
    for old in old_revoked:
        db.delete(old)
    db.flush()

    member = HouseholdMemberModel(
        household_id=household.id,
        user_id=partner.id,
        role="partner",
        status="pending",
        invitation_code=code,
    )
    db.add(member)
    db.commit()

    return {
        "invitation_code": code,
        "partner_email": partner_email,
        "expires_at": (_now() + timedelta(hours=INVITATION_EXPIRY_HOURS)).isoformat(),
    }


def accept_invitation(db: Session, user: User, invitation_code: str) -> dict:
    """Accept a household invitation."""
    member = (
        db.query(HouseholdMemberModel)
        .filter(HouseholdMemberModel.invitation_code == invitation_code)
        .first()
    )
    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Code d'invitation invalide",
        )

    # Check it belongs to this user
    if member.user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cette invitation n'est pas pour toi",
        )

    # Check already accepted (idempotent)
    if member.status == "active":
        return {"status": "already_accepted"}

    if member.status == "revoked":
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail="Cette invitation a ete revoquee",
        )

    # Check expiry (72h -- INV A1)
    if member.invited_at and (_now() - member.invited_at) > timedelta(hours=INVITATION_EXPIRY_HOURS):
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail="Cette invitation a expire",
        )

    # Check household is not full (INV-5)
    active_count = (
        db.query(HouseholdMemberModel)
        .filter(
            HouseholdMemberModel.household_id == member.household_id,
            HouseholdMemberModel.status == "active",
        )
        .count()
    )
    if active_count >= MAX_ACTIVE_MEMBERS:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Le menage a deja le nombre maximum de membres actifs",
        )

    member.status = "active"
    member.accepted_at = _now()
    db.commit()

    # Recompute entitlements for the new member (household inheritance)
    recompute_entitlements(db, user.id)

    return {"status": "accepted"}


def revoke_member(db: Session, caller: User, target_user_id: str) -> dict:
    """
    Remove a member from the household.
    - household_owner can revoke the partner
    - partner can leave (self-revoke)
    """
    # Find caller's household
    household = (
        db.query(HouseholdModel)
        .filter(HouseholdModel.household_owner_user_id == caller.id)
        .first()
    )
    is_self_revoke = caller.id == target_user_id

    if not household and is_self_revoke:
        # Partner leaving: find their household
        membership = (
            db.query(HouseholdMemberModel)
            .filter(
                HouseholdMemberModel.user_id == caller.id,
                HouseholdMemberModel.status == "active",
            )
            .first()
        )
        if membership:
            household = db.query(HouseholdModel).filter(HouseholdModel.id == membership.household_id).first()

    if not household:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Aucun menage trouve",
        )

    # Only owner can revoke others
    if not is_self_revoke and household.household_owner_user_id != caller.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seul le proprietaire du menage peut revoquer un membre",
        )

    # Cannot revoke the billing owner (would break billing)
    if target_user_id == household.billing_owner_user_id and not is_self_revoke:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossible de revoquer le proprietaire de la facturation",
        )

    member = (
        db.query(HouseholdMemberModel)
        .filter(
            HouseholdMemberModel.household_id == household.id,
            HouseholdMemberModel.user_id == target_user_id,
            HouseholdMemberModel.status.in_(["active", "pending"]),
        )
        .first()
    )
    if not member:
        # Idempotent: already revoked (INV C4)
        return {"status": "already_revoked"}

    member.status = "revoked"
    db.commit()

    # Recompute entitlements for revoked user (loses household access)
    recompute_entitlements(db, target_user_id)

    return {"status": "revoked"}


def transfer_ownership(db: Session, caller: User, new_owner_id: str) -> dict:
    """Transfer household ownership to another active member."""
    household = (
        db.query(HouseholdModel)
        .filter(HouseholdModel.household_owner_user_id == caller.id)
        .first()
    )
    if not household:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu n'es pas proprietaire d'un menage",
        )

    if new_owner_id == caller.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tu es deja le proprietaire",
        )

    # Check new owner is active member
    new_owner_member = (
        db.query(HouseholdMemberModel)
        .filter(
            HouseholdMemberModel.household_id == household.id,
            HouseholdMemberModel.user_id == new_owner_id,
            HouseholdMemberModel.status == "active",
        )
        .first()
    )
    if not new_owner_member:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le nouveau proprietaire doit etre un membre actif du menage",
        )

    # Transfer
    household.household_owner_user_id = new_owner_id
    household.updated_at = _now()

    # Update roles
    old_owner_member = (
        db.query(HouseholdMemberModel)
        .filter(
            HouseholdMemberModel.household_id == household.id,
            HouseholdMemberModel.user_id == caller.id,
        )
        .first()
    )
    if old_owner_member:
        old_owner_member.role = "partner"
    new_owner_member.role = "owner"

    db.commit()
    return {"status": "transferred", "new_owner_id": new_owner_id}


def admin_override_cooldown(
    db: Session,
    admin: User,
    target_user_id: str,
    reason: str,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> dict:
    """
    Admin override for the 30-day cooldown (INV-6, INV-12).
    Requires support_admin role.
    """
    # Validate reason (INV-13: min 10 chars)
    if not reason or len(reason.strip()) < 10:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La raison doit contenir au moins 10 caracteres",
        )

    # Find revoked memberships for target user
    revoked_memberships = (
        db.query(HouseholdMemberModel)
        .filter(
            HouseholdMemberModel.user_id == target_user_id,
            HouseholdMemberModel.status == "revoked",
        )
        .all()
    )
    for membership in revoked_memberships:
        membership.cooldown_override = True

    # Log audit event (INV-13: immutable)
    audit = AdminAuditEventModel(
        admin_user_id=admin.id,
        action="cooldown_override",
        target_user_id=target_user_id,
        reason=reason.strip(),
        ip_address=ip_address,
        user_agent=user_agent,
    )
    db.add(audit)
    db.commit()

    return {
        "status": "override_applied",
        "target_user_id": target_user_id,
        "overridden_count": len(revoked_memberships),
    }
