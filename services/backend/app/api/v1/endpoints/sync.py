"""
Sync endpoints for local-first data claim into authenticated cloud profile.
"""

import logging
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.models.profile_model import ProfileModel
from app.models.user import User
from app.schemas.sync import ClaimLocalDataRequest, ClaimLocalDataResponse

logger = logging.getLogger(__name__)

router = APIRouter()


def _pick_household(payload: ClaimLocalDataRequest) -> str:
    mini = payload.mini_onboarding
    wizard = payload.wizard_answers
    household = (
        mini.get("q_household_type")
        or mini.get("household_type")
        or wizard.get("q_household_type")
        or wizard.get("householdType")
        or "single"
    )
    if household not in {"single", "couple", "concubine", "family"}:
        return "single"
    return household


@router.post("/claim-local-data", response_model=ClaimLocalDataResponse)
@limiter.limit("10/minute")
def claim_local_data(
    request: Request,
    body: ClaimLocalDataRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_current_user),
) -> ClaimLocalDataResponse:
    """
    One-shot migration of local mobile data to the authenticated user's cloud profile.

    Merge policy: Last write wins, version-gated. Same or older version is a no-op.
    If the existing profile already contains a localDataClaim whose localDataVersion
    is >= the incoming version, we skip the overwrite and return the existing data.
    This prevents stale replays from older devices or retry storms.
    """
    now = datetime.now(timezone.utc)
    existing_profile = (
        db.query(ProfileModel)
        .filter(ProfileModel.user_id == current_user.id)
        .order_by(ProfileModel.updated_at.desc())
        .first()
    )

    # --- Timestamp-based idempotence gate ---
    # FIX-W11-1: Use ISO 8601 timestamp comparison instead of static version
    # integers to prevent last-write-wins data loss across multiple devices.
    if existing_profile and existing_profile.data:
        existing_claim = existing_profile.data.get("localDataClaim", {})
        existing_meta = existing_claim.get("meta", {})
        existing_updated_at = existing_meta.get("updatedAt")
        incoming_updated_at = body.updated_at

        # Primary gate: timestamp comparison (preferred, no data loss)
        if existing_updated_at and incoming_updated_at:
            try:
                existing_ts = datetime.fromisoformat(
                    existing_updated_at.replace("Z", "+00:00")
                )
                incoming_ts = datetime.fromisoformat(
                    incoming_updated_at.replace("Z", "+00:00")
                )
                if existing_ts >= incoming_ts:
                    logger.info(
                        "Sync conflict: existing=%s >= incoming=%s for user=%s, "
                        "device=%s — rejecting stale payload",
                        existing_updated_at,
                        incoming_updated_at,
                        current_user.id,
                        body.device_id,
                    )
                    merged_fields_count = (
                        len(body.mini_onboarding) + len(body.wizard_answers)
                    )
                    return ClaimLocalDataResponse(
                        status="ok",
                        profile_id=existing_profile.id,
                        created_profile=False,
                        merged_fields_count=merged_fields_count,
                    )
            except (ValueError, TypeError):
                # Malformed timestamps — fall through to version check
                logger.warning(
                    "Sync: malformed timestamp existing=%s incoming=%s, "
                    "falling back to version check",
                    existing_updated_at,
                    incoming_updated_at,
                )

        # Fallback gate: version integer (backward compat for old clients)
        existing_version = existing_meta.get("localDataVersion", 0)
        if not incoming_updated_at and existing_version >= body.local_data_version:
            merged_fields_count = (
                len(body.mini_onboarding) + len(body.wizard_answers)
            )
            return ClaimLocalDataResponse(
                status="ok",
                profile_id=existing_profile.id,
                created_profile=False,
                merged_fields_count=merged_fields_count,
            )

    claim_blob = {
        "meta": {
            "claimedAt": now.isoformat(),
            "updatedAt": body.updated_at or now.isoformat(),
            "deviceId": body.device_id,
            "localDataVersion": body.local_data_version,
        },
        "miniOnboarding": body.mini_onboarding,
        "wizardAnswers": body.wizard_answers,
        "budgetSnapshot": body.budget_snapshot,
        "checkins": body.checkins,
    }

    if existing_profile:
        data = dict(existing_profile.data)
        data["localDataClaim"] = claim_blob

        # Fill key top-level profile fields when missing to improve immediate UX.
        data.setdefault("householdType", _pick_household(body))
        data.setdefault("createdAt", now.isoformat())
        if "birthYear" not in data:
            data["birthYear"] = (
                body.mini_onboarding.get("q_birth_year")
                or body.wizard_answers.get("q_birth_year")
                or body.wizard_answers.get("birthYear")
            )
        if "canton" not in data:
            data["canton"] = (
                body.mini_onboarding.get("q_canton")
                or body.wizard_answers.get("q_canton")
                or body.wizard_answers.get("canton")
            )
        if "incomeNetMonthly" not in data:
            data["incomeNetMonthly"] = (
                body.mini_onboarding.get("q_income_monthly")
                or body.wizard_answers.get("q_net_income_period_chf")
                or body.wizard_answers.get("incomeNetMonthly")
            )

        existing_profile.data = data
        existing_profile.updated_at = now
        db.commit()
        db.refresh(existing_profile)

        merged_fields_count = len(claim_blob["miniOnboarding"]) + len(
            claim_blob["wizardAnswers"]
        )
        return ClaimLocalDataResponse(
            status="ok",
            profile_id=existing_profile.id,
            created_profile=False,
            merged_fields_count=merged_fields_count,
        )

    profile_data = {
        "id": f"{current_user.id}-claimed",
        "createdAt": now.isoformat(),
        "householdType": _pick_household(body),
        "birthYear": body.mini_onboarding.get("q_birth_year")
        or body.wizard_answers.get("q_birth_year")
        or body.wizard_answers.get("birthYear"),
        "canton": body.mini_onboarding.get("q_canton")
        or body.wizard_answers.get("q_canton")
        or body.wizard_answers.get("canton"),
        "incomeNetMonthly": body.mini_onboarding.get("q_income_monthly")
        or body.wizard_answers.get("q_net_income_period_chf")
        or body.wizard_answers.get("incomeNetMonthly"),
        "goal": body.mini_onboarding.get("q_goal")
        or body.wizard_answers.get("q_goal")
        or "other",
        "localDataClaim": claim_blob,
    }
    new_profile = ProfileModel(
        id=profile_data["id"],
        user_id=current_user.id,
        data=profile_data,
        created_at=now,
        updated_at=now,
    )
    db.add(new_profile)
    db.commit()
    db.refresh(new_profile)

    merged_fields_count = len(claim_blob["miniOnboarding"]) + len(
        claim_blob["wizardAnswers"]
    )
    return ClaimLocalDataResponse(
        status="ok",
        profile_id=new_profile.id,
        created_profile=True,
        merged_fields_count=merged_fields_count,
    )
