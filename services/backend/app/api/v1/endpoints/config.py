"""
Config endpoints -- feature flags (INV-10).
"""

from fastapi import APIRouter, Request

from app.core.rate_limit import limiter
from pydantic import BaseModel
from app.services.feature_flags import FeatureFlags

router = APIRouter()


class FeatureFlagsResponse(BaseModel):
    enableCouplePlusTier: bool
    enableSlmNarratives: bool
    enableDecisionScaffold: bool
    valeurLocative2028Reform: bool
    safeModeDegraded: bool


@router.get("/feature-flags", response_model=FeatureFlagsResponse)
@limiter.limit("60/minute")
def get_feature_flags(
    request: Request) -> FeatureFlagsResponse:
    flags = FeatureFlags.get_flags()
    return FeatureFlagsResponse(
        enableCouplePlusTier=flags["enable_couple_plus_tier"],
        enableSlmNarratives=flags["enable_slm_narratives"],
        enableDecisionScaffold=flags["enable_decision_scaffold"],
        valeurLocative2028Reform=flags["valeur_locative_2028_reform"],
        safeModeDegraded=flags["safe_mode_degraded"],
    )
