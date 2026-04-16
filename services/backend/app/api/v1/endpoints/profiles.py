"""
Profiles endpoint - CRUD for user profiles.
Migrated to use database with backward compatibility for anonymous profiles.
"""

import uuid
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import UUID4
from sqlalchemy.orm import Session
from app.schemas.profile import Profile, ProfileCreate, ProfileUpdate
from app.core.database import get_db
from app.core.auth import get_current_user, require_current_user
from app.core.rate_limit import limiter
from app.models.user import User
from app.models.profile_model import ProfileModel
from app.services.profile_bootstrap import ensure_empty_profile

router = APIRouter()


@router.get("/me", response_model=Profile)
@limiter.limit("30/minute")
def get_my_profile(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> Profile:
    """
    Get the authenticated user's profile.

    Get-or-create semantics (FIX-B, 2026-04-13): if the authenticated user
    somehow has no profile row (legacy account, partial migration, aborted
    bootstrap during auth), auto-create an empty one on the fly rather than
    returning 404 forever. Every auth path SHOULD already call
    `ensure_empty_profile`, but this endpoint is the last line of defence
    for the downstream screens that depend on a profile existing.
    """
    db_profile = (
        db.query(ProfileModel)
        .filter(ProfileModel.user_id == current_user.id)
        .order_by(ProfileModel.updated_at.desc())
        .first()
    )

    if not db_profile:
        # Auto-bootstrap so /profiles/me is never a dead-end for authenticated users.
        ensure_empty_profile(db, str(current_user.id), commit=True)
        db_profile = (
            db.query(ProfileModel)
            .filter(ProfileModel.user_id == current_user.id)
            .order_by(ProfileModel.updated_at.desc())
            .first()
        )

    if not db_profile:
        # Should be unreachable — ensure_empty_profile is idempotent and commits.
        # Keep the guard so a genuine infra issue surfaces instead of 500-ing
        # on the dict access below.
        raise HTTPException(status_code=404, detail="Profile not found")

    data = db_profile.data
    return Profile(
        id=data["id"],
        birthYear=data.get("birthYear"),
        canton=data.get("canton"),
        householdType=data["householdType"],
        incomeNetMonthly=data.get("incomeNetMonthly"),
        incomeGrossYearly=data.get("incomeGrossYearly"),
        savingsMonthly=data.get("savingsMonthly"),
        totalSavings=data.get("totalSavings"),
        lppInsuredSalary=data.get("lppInsuredSalary"),
        avoirLpp=data.get("avoirLpp"),
        lppBuybackMax=data.get("lppBuybackMax"),
        pillar3aBalance=data.get("pillar3aBalance"),
        hasDebt=data.get("hasDebt", False),
        goal=data.get("goal", "other"),
        factfindCompletionIndex=data.get("factfindCompletionIndex", 0.0),
        employmentStatus=data.get("employmentStatus"),
        has2ndPillar=data.get("has2ndPillar"),
        legalForm=data.get("legalForm"),
        selfEmployedNetIncome=data.get("selfEmployedNetIncome"),
        hasVoluntaryLpp=data.get("hasVoluntaryLpp"),
        primaryActivity=data.get("primaryActivity"),
        hasAvsGaps=data.get("hasAvsGaps"),
        avsContributionYears=data.get("avsContributionYears"),
        spouseAvsContributionYears=data.get("spouseAvsContributionYears"),
        commune=data.get("commune"),
        isChurchMember=data.get("isChurchMember", False),
        pillar3aAnnual=data.get("pillar3aAnnual"),
        wealthEstimate=data.get("wealthEstimate"),
        gender=data.get("gender"),
        targetRetirementAge=data.get("targetRetirementAge"),
        createdAt=datetime.fromisoformat(data["createdAt"]),
    )


@router.post("", response_model=Profile)
@limiter.limit("10/minute")
def create_profile(
    request: Request,
    profile_create: ProfileCreate,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user),
) -> Profile:
    """
    Create a new profile.
    If authenticated, link profile to user. Otherwise, create anonymous profile.
    """
    profile_id = uuid.uuid4()
    now = datetime.now(timezone.utc)

    # Build profile data
    profile_data = profile_create.model_dump()
    profile_data["id"] = str(profile_id)
    profile_data["createdAt"] = now.isoformat()

    # Create database record
    db_profile = ProfileModel(
        id=str(profile_id),
        user_id=current_user.id if current_user else None,
        data=profile_data,
        created_at=now,
        updated_at=now,
    )

    db.add(db_profile)
    db.commit()
    db.refresh(db_profile)

    # Convert to response model
    profile = Profile(
        id=profile_id,
        birthYear=profile_create.birthYear,
        canton=profile_create.canton,
        householdType=profile_create.householdType,
        incomeNetMonthly=profile_create.incomeNetMonthly,
        incomeGrossYearly=profile_create.incomeGrossYearly,
        savingsMonthly=profile_create.savingsMonthly,
        totalSavings=profile_create.totalSavings,
        lppInsuredSalary=profile_create.lppInsuredSalary,
        hasDebt=profile_create.hasDebt,
        goal=profile_create.goal,
        factfindCompletionIndex=profile_create.factfindCompletionIndex,
        employmentStatus=profile_create.employmentStatus,
        has2ndPillar=profile_create.has2ndPillar,
        legalForm=profile_create.legalForm,
        selfEmployedNetIncome=profile_create.selfEmployedNetIncome,
        hasVoluntaryLpp=profile_create.hasVoluntaryLpp,
        primaryActivity=profile_create.primaryActivity,
        hasAvsGaps=profile_create.hasAvsGaps,
        avsContributionYears=profile_create.avsContributionYears,
        spouseAvsContributionYears=profile_create.spouseAvsContributionYears,
        commune=profile_create.commune,
        isChurchMember=profile_create.isChurchMember,
        pillar3aAnnual=profile_create.pillar3aAnnual,
        wealthEstimate=profile_create.wealthEstimate,
        gender=profile_create.gender,
        targetRetirementAge=profile_create.targetRetirementAge,
        createdAt=now,
    )

    return profile


@router.get("/{profile_id}", response_model=Profile)
@limiter.limit("30/minute")
def get_profile(
    request: Request,
    profile_id: UUID4,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> Profile:
    """
    Get a profile by ID.
    Requires authentication. Verifies ownership.
    """
    # P0-3: Always require auth and verify ownership
    db_profile = db.query(ProfileModel).filter(
        ProfileModel.id == str(profile_id),
        ProfileModel.user_id == current_user.id,
    ).first()

    if not db_profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Convert from JSON data to Profile model
    data = db_profile.data
    profile = Profile(
        id=data["id"],
        birthYear=data.get("birthYear"),
        canton=data.get("canton"),
        householdType=data["householdType"],
        incomeNetMonthly=data.get("incomeNetMonthly"),
        incomeGrossYearly=data.get("incomeGrossYearly"),
        savingsMonthly=data.get("savingsMonthly"),
        totalSavings=data.get("totalSavings"),
        lppInsuredSalary=data.get("lppInsuredSalary"),
        avoirLpp=data.get("avoirLpp"),
        lppBuybackMax=data.get("lppBuybackMax"),
        pillar3aBalance=data.get("pillar3aBalance"),
        hasDebt=data.get("hasDebt", False),
        goal=data.get("goal", "other"),
        factfindCompletionIndex=data.get("factfindCompletionIndex", 0.0),
        employmentStatus=data.get("employmentStatus"),
        has2ndPillar=data.get("has2ndPillar"),
        legalForm=data.get("legalForm"),
        selfEmployedNetIncome=data.get("selfEmployedNetIncome"),
        hasVoluntaryLpp=data.get("hasVoluntaryLpp"),
        primaryActivity=data.get("primaryActivity"),
        hasAvsGaps=data.get("hasAvsGaps"),
        avsContributionYears=data.get("avsContributionYears"),
        spouseAvsContributionYears=data.get("spouseAvsContributionYears"),
        commune=data.get("commune"),
        isChurchMember=data.get("isChurchMember", False),
        pillar3aAnnual=data.get("pillar3aAnnual"),
        wealthEstimate=data.get("wealthEstimate"),
        gender=data.get("gender"),
        targetRetirementAge=data.get("targetRetirementAge"),
        createdAt=datetime.fromisoformat(data["createdAt"]),
    )

    return profile


@router.patch("/{profile_id}", response_model=Profile)
@limiter.limit("30/minute")
def update_profile(
    request: Request,
    profile_id: UUID4,
    profile_update: ProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> Profile:
    """
    Update an existing profile.
    Requires authentication. Verifies ownership.
    """
    # P0-3: Always require auth and verify ownership
    db_profile = db.query(ProfileModel).filter(
        ProfileModel.id == str(profile_id),
        ProfileModel.user_id == current_user.id,
    ).first()

    if not db_profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Update data
    data = db_profile.data
    update_data = profile_update.model_dump(exclude_unset=True)

    # Cascade clear: when household becomes single, remove spouse-specific data
    if "householdType" in update_data and update_data["householdType"] == "single":
        for spouse_key in [
            "spouseSalaryGrossAnnual",
            "spouseEmploymentStatus",
            "spouseAvsContributionYears",
            "householdGrossIncome",
        ]:
            data.pop(spouse_key, None)

    for key, value in update_data.items():
        data[key] = value

    db_profile.data = data
    db_profile.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(db_profile)

    # Convert to response
    profile = Profile(
        id=data["id"],
        birthYear=data.get("birthYear"),
        canton=data.get("canton"),
        householdType=data["householdType"],
        incomeNetMonthly=data.get("incomeNetMonthly"),
        incomeGrossYearly=data.get("incomeGrossYearly"),
        savingsMonthly=data.get("savingsMonthly"),
        totalSavings=data.get("totalSavings"),
        lppInsuredSalary=data.get("lppInsuredSalary"),
        avoirLpp=data.get("avoirLpp"),
        lppBuybackMax=data.get("lppBuybackMax"),
        pillar3aBalance=data.get("pillar3aBalance"),
        hasDebt=data.get("hasDebt", False),
        goal=data.get("goal", "other"),
        factfindCompletionIndex=data.get("factfindCompletionIndex", 0.0),
        employmentStatus=data.get("employmentStatus"),
        has2ndPillar=data.get("has2ndPillar"),
        legalForm=data.get("legalForm"),
        selfEmployedNetIncome=data.get("selfEmployedNetIncome"),
        hasVoluntaryLpp=data.get("hasVoluntaryLpp"),
        primaryActivity=data.get("primaryActivity"),
        hasAvsGaps=data.get("hasAvsGaps"),
        avsContributionYears=data.get("avsContributionYears"),
        spouseAvsContributionYears=data.get("spouseAvsContributionYears"),
        commune=data.get("commune"),
        isChurchMember=data.get("isChurchMember", False),
        pillar3aAnnual=data.get("pillar3aAnnual"),
        wealthEstimate=data.get("wealthEstimate"),
        gender=data.get("gender"),
        targetRetirementAge=data.get("targetRetirementAge"),
        createdAt=datetime.fromisoformat(data["createdAt"]),
    )

    return profile
