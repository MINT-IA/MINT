from fastapi import APIRouter
from app.api.v1.endpoints import (
    health,
    auth,
    profiles,
    scenarios,
    recommendations,
    partners,
    sessions,
    analytics,
    rag,
    documents,
    job_comparison,
    life_events,
    coaching,
    segments,
    assurances,
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
api_router.include_router(analytics.router, prefix="/analytics", tags=["analytics"])
api_router.include_router(rag.router, prefix="/rag", tags=["rag"])
api_router.include_router(documents.router, prefix="/documents", tags=["documents"])
api_router.include_router(
    job_comparison.router, prefix="/job-comparison", tags=["job-comparison"]
)
api_router.include_router(
    life_events.router, prefix="/life-events", tags=["life-events"]
)
api_router.include_router(
    coaching.router, prefix="/coaching", tags=["coaching"]
)
api_router.include_router(
    segments.router, prefix="/segments", tags=["segments"]
)
api_router.include_router(
    assurances.router, prefix="/assurances", tags=["assurances"]
)
