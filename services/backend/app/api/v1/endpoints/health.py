import logging
from datetime import datetime, timezone

from fastapi import APIRouter
from sqlalchemy import text

from app.core.config import settings
from app.core.database import SessionLocal
from app.schemas.common import DetailedHealthResponse, HealthResponse

logger = logging.getLogger(__name__)

router = APIRouter()

_VERSION = "0.1.0"


@router.get("/health", response_model=HealthResponse)
def get_health():
    """Health check endpoint (backward compatible)."""
    return HealthResponse(status="ok")


@router.get("/health/live", response_model=HealthResponse)
def liveness_probe():
    """Kubernetes liveness probe — always returns ok if the process is running."""
    return HealthResponse(status="ok")


@router.get("/health/ready", response_model=DetailedHealthResponse)
def readiness_probe():
    """
    Kubernetes readiness probe — checks database connectivity.
    Returns detailed status including version, environment, and DB status.
    """
    db_status = "ok"
    try:
        db = SessionLocal()
        try:
            db.execute(text("SELECT 1"))
        finally:
            db.close()
    except Exception as e:
        logger.warning("Database health check failed: %s", e)
        db_status = "unavailable"

    overall_status = "ok" if db_status == "ok" else "degraded"

    return DetailedHealthResponse(
        status=overall_status,
        version=_VERSION,
        environment=settings.ENVIRONMENT,
        database=db_status,
        timestamp=datetime.now(timezone.utc),
    )
