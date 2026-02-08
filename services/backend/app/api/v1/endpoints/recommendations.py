"""
Recommendations endpoint - preview personalized recommendations.
"""

from datetime import datetime
from typing import List
from fastapi import APIRouter, Depends
from pydantic import UUID4
from sqlalchemy.orm import Session
from app.schemas.recommendation import Recommendation, RecommendationPreviewRequest
from app.schemas.profile import Profile, HouseholdType, Goal
from app.services.rules_engine import generate_recommendations
from app.core.database import get_db
from app.models.profile_model import ProfileModel

router = APIRouter()


@router.post("/preview", response_model=List[Recommendation])
def preview_recommendations(
    request: RecommendationPreviewRequest,
    db: Session = Depends(get_db),
) -> List[Recommendation]:
    """
    Generate personalized recommendations based on profile.
    Returns up to 3 recommendations.
    """
    # Try to fetch profile from database
    db_profile = db.query(ProfileModel).filter(
        ProfileModel.id == str(request.profileId)
    ).first()

    if db_profile:
        # Reconstruct profile from JSON data
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
    else:
        # For demo purposes, create a default profile if not found
        profile = Profile(
            id=request.profileId,
            birthYear=1990,
            canton="ZH",
            householdType=HouseholdType.single,
            incomeNetMonthly=6000.0,
            savingsMonthly=500.0,
            goal=Goal.invest,
            createdAt=datetime.utcnow(),
        )

    recommendations = generate_recommendations(profile)
    if request.focusKind:
        # Filter if focusKind is requested
        recommendations = [r for r in recommendations if r.kind == request.focusKind]
    
    # Identify Top 3 (Simplified priority for preview)
    priority_map = {
        "debt_repayment": 0,
        "debt_risk": 1,
        "budget_control": 2,
        "pension_3a": 3,
        "pillar3a": 4,
        "tax_optimization": 5,
        "legal_protection": 6,
        "compound_interest": 7
    }
    recommendations = sorted(recommendations, key=lambda r: priority_map.get(r.kind, 99))
    return recommendations[:3]
