"""
Config endpoints -- feature flags (INV-10).
"""

from fastapi import APIRouter
from pydantic import BaseModel
from app.services.feature_flags import FeatureFlags

router = APIRouter()


class FeatureFlagsResponse(BaseModel):
    enableCouplePlusTier: bool


@router.get("/feature-flags", response_model=FeatureFlagsResponse)
def get_feature_flags() -> FeatureFlagsResponse:
    return FeatureFlagsResponse(
        enableCouplePlusTier=FeatureFlags.enable_couple_plus_tier,
    )
