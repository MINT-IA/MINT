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
    mint2_axis_handoff: dict[str, Any] = Field(default_factory=dict)
    mini_onboarding: dict[str, Any] = Field(default_factory=dict)
    budget_snapshot: dict[str, Any] = Field(default_factory=dict)
    checkins: list[dict[str, Any]] = Field(default_factory=list)


class ClaimLocalDataResponse(BaseModel):
    """Result of local data claim."""

    status: str
    profile_id: str
    created_profile: bool
    merged_fields_count: int


class LocalDataClaimMetaSummary(BaseModel):
    """PII-free metadata summary for admin runtime proof."""

    claimed_at_present: bool
    updated_at_present: bool
    device_id_present: bool
    local_data_version: Optional[int] = None


class AdminLocalDataClaimSummaryResponse(BaseModel):
    """PII-free local-data claim summary for restricted admin observability."""

    profile_id: str
    has_local_data_claim: bool
    wizard_answers_count: int
    wizard_answers_contains_axis: bool
    mint2_axis_handoff_present: bool
    mint2_axis_id: Optional[str] = None
    schema_version: Optional[int] = None
    legacy_intent_present: bool
    source_engine_present: bool
    receipt_hash_present: bool
    receipt_ref_present: bool
    generated_at_present: bool
    calculation_version_present: bool
    regulatory_constants_version_hash_present: bool
    meta: LocalDataClaimMetaSummary
