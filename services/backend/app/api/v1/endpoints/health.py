from fastapi import APIRouter
from app.schemas.common import HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
def get_health():
    """Health check endpoint."""
    return HealthResponse(status="ok")
