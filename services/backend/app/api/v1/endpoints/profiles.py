"""
Profiles endpoint - CRUD for user profiles.
MVP: In-memory storage (no persistence).
"""

import uuid
from datetime import datetime
from typing import Dict
from fastapi import APIRouter, HTTPException
from pydantic import UUID4
from app.schemas.profile import Profile, ProfileCreate, ProfileUpdate

router = APIRouter()

# In-memory store for MVP
_profiles: Dict[UUID4, Profile] = {}


@router.post("", response_model=Profile)
def create_profile(profile_create: ProfileCreate) -> Profile:
    """Create a new profile."""
    profile_id = uuid.uuid4()
    now = datetime.utcnow()

    profile = Profile(
        id=profile_id,
        birthYear=profile_create.birthYear,
        canton=profile_create.canton,
        householdType=profile_create.householdType,
        incomeNetMonthly=profile_create.incomeNetMonthly,
        savingsMonthly=profile_create.savingsMonthly,
        goal=profile_create.goal,
        createdAt=now,
    )
    _profiles[profile_id] = profile
    return profile


@router.get("/{profile_id}", response_model=Profile)
def get_profile(profile_id: UUID4) -> Profile:
    """Get a profile by ID."""
    if profile_id not in _profiles:
        raise HTTPException(status_code=404, detail="Profile not found")
    return _profiles[profile_id]


@router.patch("/{profile_id}", response_model=Profile)
def update_profile(profile_id: UUID4, profile_update: ProfileUpdate) -> Profile:
    """Update an existing profile."""
    if profile_id not in _profiles:
        raise HTTPException(status_code=404, detail="Profile not found")

    existing = _profiles[profile_id]
    update_data = profile_update.model_dump(exclude_unset=True)

    updated = existing.model_copy(update=update_data)
    _profiles[profile_id] = updated
    return updated
