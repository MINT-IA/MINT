"""
Recommendations endpoint - preview personalized recommendations.
"""

from typing import List
from fastapi import APIRouter
from app.schemas.recommendation import Recommendation, RecommendationPreviewRequest
from app.schemas.profile import Profile, HouseholdType, Goal
from app.services.rules_engine import generate_recommendations
from app.api.v1.endpoints.profiles import _profiles

router = APIRouter()


@router.post("/preview", response_model=List[Recommendation])
def preview_recommendations(
    request: RecommendationPreviewRequest,
) -> List[Recommendation]:
    """
    Generate personalized recommendations based on profile.
    Returns up to 3 recommendations.
    """
    profile = _profiles.get(request.profileId)

    if not profile:
        # For demo purposes, create a default profile if not found
        from datetime import datetime

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
    return recommendations
