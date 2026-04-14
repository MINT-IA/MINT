"""
Commitment device endpoints — CRUD for implementation intentions.

POST   /api/v1/coach/commitment    — Create a new commitment
GET    /api/v1/coach/commitment    — List user's commitments
PATCH  /api/v1/coach/commitment/{id} — Update status (completed/dismissed)

Sources:
    - CMIT-01: Implementation intentions after Layer 4 insights
    - CMIT-02: Notification scheduling per locked decision
    - T-14-06: IDOR protection (query filters by user_id from JWT)
    - T-14-07: Length validation (500 char max per field)
    - T-14-08: Rate limit (max 50 pending commitments per user)
    - LPD art. 6 (protection des données)
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic.alias_generators import to_camel
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.database import get_db
from app.models.commitment import CommitmentDevice
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter()


# ── Schemas ──────────────────────────────────────────────────


class CommitmentCreate(BaseModel):
    """Request schema for creating a commitment device."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    when_text: str = Field(..., max_length=500)
    where_text: str = Field(..., max_length=500)
    if_then_text: str = Field(..., max_length=500)
    reminder_at: Optional[datetime] = None

    @field_validator("when_text", "where_text", "if_then_text")
    @classmethod
    def not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Field must not be empty")
        return v.strip()


class CommitmentResponse(BaseModel):
    """Response schema for a commitment device."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
        from_attributes=True,
    )

    id: str
    status: str
    when_text: str
    where_text: str
    if_then_text: str
    reminder_at: Optional[datetime] = None
    created_at: datetime


class CommitmentStatusUpdate(BaseModel):
    """Request schema for updating commitment status."""

    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    status: str

    @field_validator("status")
    @classmethod
    def valid_status(cls, v: str) -> str:
        allowed = {"completed", "dismissed"}
        if v not in allowed:
            raise ValueError(f"Status must be one of: {', '.join(allowed)}")
        return v


# ── Endpoints ────────────────────────────────────────────────


@router.post(
    "/",
    response_model=CommitmentResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_commitment(
    payload: CommitmentCreate,
    user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> CommitmentResponse:
    """Create a new implementation intention commitment.

    T-14-08: Rate limit — max 50 pending commitments per user.
    T-14-07: Length validation enforced by Pydantic schema (500 char max).
    """
    # T-14-08: Check pending commitment count
    pending_count = (
        db.query(CommitmentDevice)
        .filter(
            CommitmentDevice.user_id == user.id,
            CommitmentDevice.status == "pending",
        )
        .count()
    )
    if pending_count >= 50:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Maximum 50 pending commitments reached. Complete or dismiss existing ones.",
        )

    device = CommitmentDevice(
        user_id=user.id,
        type="implementation_intention",
        when_text=payload.when_text,
        where_text=payload.where_text,
        if_then_text=payload.if_then_text,
        reminder_at=payload.reminder_at,
    )
    db.add(device)
    db.commit()
    db.refresh(device)

    if device.reminder_at is not None:
        logger.info(
            "Commitment created: user=%s id=%s reminder_at=%s",
            user.id,
            device.id,
            device.reminder_at.isoformat(),
        )
    else:
        logger.info(
            "Commitment created: user=%s id=%s (no reminder scheduled)",
            user.id,
            device.id,
        )

    return CommitmentResponse.model_validate(device)


@router.get("/", response_model=list[CommitmentResponse])
def list_commitments(
    status_filter: Optional[str] = Query(
        None, alias="status", description="Filter by status (pending, completed, dismissed)"
    ),
    limit: int = Query(20, ge=1, le=100),
    user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> list[CommitmentResponse]:
    """List user's commitments, optionally filtered by status."""
    query = db.query(CommitmentDevice).filter(
        CommitmentDevice.user_id == user.id
    )
    if status_filter:
        query = query.filter(CommitmentDevice.status == status_filter)

    devices = (
        query.order_by(CommitmentDevice.created_at.desc()).limit(limit).all()
    )
    return [CommitmentResponse.model_validate(d) for d in devices]


@router.patch("/{commitment_id}", response_model=CommitmentResponse)
def update_commitment_status(
    commitment_id: str,
    payload: CommitmentStatusUpdate,
    user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> CommitmentResponse:
    """Update commitment status (completed or dismissed).

    T-14-06: IDOR protection — query filters by BOTH commitment_id AND user_id.
    """
    device = (
        db.query(CommitmentDevice)
        .filter(
            CommitmentDevice.id == commitment_id,
            CommitmentDevice.user_id == user.id,
        )
        .first()
    )
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Commitment not found.",
        )

    device.status = payload.status
    db.commit()
    db.refresh(device)

    logger.info(
        "Commitment updated: user=%s id=%s status=%s",
        user.id,
        device.id,
        payload.status,
    )

    return CommitmentResponse.model_validate(device)
