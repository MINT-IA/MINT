"""
Schemas for local -> cloud one-shot claim sync.
"""

from typing import Any, Optional
from pydantic import BaseModel, Field


class ClaimLocalDataRequest(BaseModel):
    """Payload sent by mobile when user upgrades from local mode to account."""

    local_data_version: int = Field(1, ge=1)
    device_id: str = Field(..., min_length=8, max_length=128)
    updated_at: Optional[str] = Field(
        None,
        description="ISO 8601 UTC timestamp of when the local data was last modified. "
        "Used for timestamp-based conflict resolution instead of version integers.",
    )
    wizard_answers: dict[str, Any] = Field(default_factory=dict)
    mini_onboarding: dict[str, Any] = Field(default_factory=dict)
    budget_snapshot: dict[str, Any] = Field(default_factory=dict)
    checkins: list[dict[str, Any]] = Field(default_factory=list)


class ClaimLocalDataResponse(BaseModel):
    """Result of local data claim."""

    status: str
    profile_id: str
    created_profile: bool
    merged_fields_count: int
