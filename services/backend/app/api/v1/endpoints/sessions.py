"""
Sessions endpoint - Advisor guided sessions.
Migrated to use database.
"""

import uuid
from datetime import datetime
from fastapi import APIRouter, HTTPException, Depends
from pydantic import UUID4
from sqlalchemy.orm import Session
from app.schemas.session import Session as SessionSchema, SessionCreate, SessionReport
from app.core.database import get_db
from app.models.profile_model import ProfileModel
from app.models.session_model import SessionModel
from app.services.rules_engine import generate_session_report, recommend_goal_template

router = APIRouter()


@router.post("", response_model=SessionSchema)
def create_session(
    session_create: SessionCreate,
    db: Session = Depends(get_db),
) -> SessionSchema:
    """Create a new guide session."""
    # Check if profile exists
    db_profile = db.query(ProfileModel).filter(
        ProfileModel.id == str(session_create.profileId)
    ).first()

    if not db_profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Get profile data from JSON
    profile_data = db_profile.data

    # Reconstruct profile for rules engine (using the original Profile schema)
    from app.schemas.profile import Profile, HouseholdType, Goal

    profile = Profile(
        id=profile_data["id"],
        birthYear=profile_data.get("birthYear"),
        canton=profile_data.get("canton"),
        householdType=HouseholdType(profile_data["householdType"]),
        incomeNetMonthly=profile_data.get("incomeNetMonthly"),
        incomeGrossYearly=profile_data.get("incomeGrossYearly"),
        savingsMonthly=profile_data.get("savingsMonthly"),
        totalSavings=profile_data.get("totalSavings"),
        lppInsuredSalary=profile_data.get("lppInsuredSalary"),
        hasDebt=profile_data.get("hasDebt", False),
        goal=Goal(profile_data.get("goal", "other")),
        factfindCompletionIndex=profile_data.get("factfindCompletionIndex", 0.0),
        employmentStatus=profile_data.get("employmentStatus"),
        has2ndPillar=profile_data.get("has2ndPillar"),
        legalForm=profile_data.get("legalForm"),
        selfEmployedNetIncome=profile_data.get("selfEmployedNetIncome"),
        hasVoluntaryLpp=profile_data.get("hasVoluntaryLpp"),
        primaryActivity=profile_data.get("primaryActivity"),
        hasAvsGaps=profile_data.get("hasAvsGaps"),
        avsContributionYears=profile_data.get("avsContributionYears"),
        spouseAvsContributionYears=profile_data.get("spouseAvsContributionYears"),
        commune=profile_data.get("commune"),
        isChurchMember=profile_data.get("isChurchMember", False),
        pillar3aAnnual=profile_data.get("pillar3aAnnual"),
        createdAt=datetime.fromisoformat(profile_data["createdAt"]),
    )

    # Get recommended goal
    recommended_goal_id, _ = recommend_goal_template(profile, session_create.answers)

    session_id = uuid.uuid4()

    # Build session data
    session_data = {
        "id": str(session_id),
        "profileId": str(session_create.profileId),
        "createdAt": datetime.utcnow().isoformat(),
        "answers": session_create.answers,
        "selectedFocusKinds": session_create.selectedFocusKinds,
        "recommendedGoalTemplateId": recommended_goal_id,
        "selectedGoalTemplateId": session_create.selectedGoalTemplateId,
    }

    # Create database record
    db_session = SessionModel(
        id=str(session_id),
        profile_id=str(session_create.profileId),
        data=session_data,
        created_at=datetime.utcnow(),
    )

    db.add(db_session)
    db.commit()
    db.refresh(db_session)

    # Return session schema
    session = SessionSchema(
        id=session_id,
        profileId=session_create.profileId,
        createdAt=datetime.utcnow(),
        answers=session_create.answers,
        selectedFocusKinds=session_create.selectedFocusKinds,
        recommendedGoalTemplateId=recommended_goal_id,
        selectedGoalTemplateId=session_create.selectedGoalTemplateId,
    )

    return session


@router.get("/{session_id}/report", response_model=SessionReport)
def get_session_report(
    session_id: UUID4,
    db: Session = Depends(get_db),
) -> SessionReport:
    """Generate and get the report for a session."""
    # Get session from database
    db_session = db.query(SessionModel).filter(SessionModel.id == str(session_id)).first()

    if not db_session:
        raise HTTPException(status_code=404, detail="Session not found")

    # Get session data
    session_data = db_session.data

    # Get profile
    db_profile = db.query(ProfileModel).filter(
        ProfileModel.id == session_data["profileId"]
    ).first()

    if not db_profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Reconstruct profile for rules engine
    from app.schemas.profile import Profile, HouseholdType, Goal

    profile_data = db_profile.data
    profile = Profile(
        id=profile_data["id"],
        birthYear=profile_data.get("birthYear"),
        canton=profile_data.get("canton"),
        householdType=HouseholdType(profile_data["householdType"]),
        incomeNetMonthly=profile_data.get("incomeNetMonthly"),
        incomeGrossYearly=profile_data.get("incomeGrossYearly"),
        savingsMonthly=profile_data.get("savingsMonthly"),
        totalSavings=profile_data.get("totalSavings"),
        lppInsuredSalary=profile_data.get("lppInsuredSalary"),
        hasDebt=profile_data.get("hasDebt", False),
        goal=Goal(profile_data.get("goal", "other")),
        factfindCompletionIndex=profile_data.get("factfindCompletionIndex", 0.0),
        employmentStatus=profile_data.get("employmentStatus"),
        has2ndPillar=profile_data.get("has2ndPillar"),
        legalForm=profile_data.get("legalForm"),
        selfEmployedNetIncome=profile_data.get("selfEmployedNetIncome"),
        hasVoluntaryLpp=profile_data.get("hasVoluntaryLpp"),
        primaryActivity=profile_data.get("primaryActivity"),
        hasAvsGaps=profile_data.get("hasAvsGaps"),
        avsContributionYears=profile_data.get("avsContributionYears"),
        spouseAvsContributionYears=profile_data.get("spouseAvsContributionYears"),
        commune=profile_data.get("commune"),
        isChurchMember=profile_data.get("isChurchMember", False),
        pillar3aAnnual=profile_data.get("pillar3aAnnual"),
        createdAt=datetime.fromisoformat(profile_data["createdAt"]),
    )

    # Generate report
    report = generate_session_report(
        profile,
        session_data["answers"],
        session_data["selectedFocusKinds"],
        session_id,
    )

    return report
