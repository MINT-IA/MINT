from fastapi import APIRouter
from app.api.v1.endpoints import (
    health,
    auth,
    profiles,
    scenarios,
    recommendations,
    partners,
    sessions,
)

api_router = APIRouter()

api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(profiles.router, prefix="/profiles", tags=["profiles"])
api_router.include_router(scenarios.router, prefix="/scenarios", tags=["scenarios"])
api_router.include_router(
    recommendations.router, prefix="/recommendations", tags=["recommendations"]
)
api_router.include_router(partners.router, prefix="/partners", tags=["partners"])
api_router.include_router(sessions.router, prefix="/sessions", tags=["sessions"])
