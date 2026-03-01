"""
Household schemas for API request/response.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class HouseholdMemberInfo(BaseModel):
    user_id: str
    email: Optional[str] = None
    display_name: Optional[str] = None
    role: str
    status: str
    invited_at: Optional[datetime] = None
    accepted_at: Optional[datetime] = None


class HouseholdInfo(BaseModel):
    id: str
    household_owner_user_id: str
    billing_owner_user_id: str
    created_at: Optional[datetime] = None


class HouseholdResponse(BaseModel):
    household: Optional[HouseholdInfo] = None
    members: list[HouseholdMemberInfo] = Field(default_factory=list)
    role: Optional[str] = None


class InviteRequest(BaseModel):
    email: str


class InviteResponse(BaseModel):
    invitation_code: str
    partner_email: str
    expires_at: str


class AcceptRequest(BaseModel):
    invitation_code: str


class AcceptResponse(BaseModel):
    status: str


class RevokeResponse(BaseModel):
    status: str


class TransferRequest(BaseModel):
    new_owner_id: str


class TransferResponse(BaseModel):
    status: str
    new_owner_id: str


class AdminOverrideCooldownRequest(BaseModel):
    user_id: str
    reason: str


class AdminOverrideCooldownResponse(BaseModel):
    status: str
    target_user_id: str
    overridden_count: int
