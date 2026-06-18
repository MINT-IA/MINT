"""
Sync endpoints for local-first data claim into authenticated cloud profile.
"""

import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.models.profile_model import ProfileModel
from app.models.user import User
from app.schemas.profile import (
    MAX_AVS_CONTRIBUTION_YEARS,
    MAX_BIRTH_YEAR,
    MAX_PILLAR3A_ANNUAL,
    MAX_PROFILE_MONEY,
    MIN_BIRTH_YEAR,
)
from app.schemas.sync import ClaimLocalDataRequest, ClaimLocalDataResponse

logger = logging.getLogger(__name__)

router = APIRouter()

_BOOTSTRAP_PROFILE_KEYS = {
    "id",
    "createdAt",
    "householdType",
    "hasDebt",
    "goal",
    "factfindCompletionIndex",
    "isChurchMember",
}

_CONSUMER_DEBT_CAPITAL_KEYS = (
    "_coach_dettes_credit",
    "_coach_dettes_leasing",
    "_coach_dettes_autres",
)


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


def _first_present(*values):
    for value in values:
        if value is None:
            continue
        if isinstance(value, str) and not value.strip():
            continue
        return value
    return None


def _as_float(value) -> Optional[float]:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        normalized = value.replace("'", "").replace(" ", "").strip()
        if not normalized:
            return None
        try:
            return float(normalized)
        except ValueError:
            return None
    return None


def _bounded_float(value, *, minimum: float = 0, maximum: float) -> Optional[float]:
    number = _as_float(value)
    if number is None or number < minimum or number > maximum:
        return None
    return number


def _as_int(value) -> Optional[int]:
    number = _as_float(value)
    if number is None:
        return None
    if not number.is_integer():
        return None
    return int(number)


def _bounded_int(value, *, minimum: int = 0, maximum: int) -> Optional[int]:
    number = _as_int(value)
    if number is None or number < minimum or number > maximum:
        return None
    return number


def _as_bool(value) -> Optional[bool]:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"true", "yes", "oui", "1"}:
            return True
        if normalized in {"false", "no", "non", "0"}:
            return False
    return None


def _valid_iso_date(value) -> Optional[str]:
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    return parsed.date().isoformat()


def _birth_year_from_date(date_of_birth: Optional[str]) -> Optional[int]:
    if not date_of_birth:
        return None
    try:
        return datetime.fromisoformat(date_of_birth).year
    except ValueError:
        return None


def _net_monthly_income(payload: ClaimLocalDataRequest) -> Optional[float]:
    mini = payload.mini_onboarding
    wizard = payload.wizard_answers
    direct_monthly = _as_float(
        _first_present(
            mini.get("q_income_monthly"),
            wizard.get("incomeNetMonthly"),
        )
    )
    if direct_monthly is not None:
        return direct_monthly

    period_income = _as_float(wizard.get("q_net_income_period_chf"))
    if period_income is None:
        return None

    frequency = str(wizard.get("q_pay_frequency", "monthly")).strip().lower()
    if frequency in {"yearly", "annual", "annuel"}:
        return period_income / 12
    return period_income


def _consumer_debt_total(wizard_answers: dict) -> float:
    total = 0.0
    for key in _CONSUMER_DEBT_CAPITAL_KEYS:
        total += _as_float(wizard_answers.get(key)) or 0.0
    return total


def _goal(payload: ClaimLocalDataRequest) -> str:
    goal = _first_present(
        payload.mini_onboarding.get("q_goal"),
        payload.wizard_answers.get("q_goal"),
        payload.wizard_answers.get("goal"),
    )
    if goal in {"house", "retire", "emergency", "invest", "optimize_taxes", "other"}:
        return goal
    return "other"


def _profile_fields_from_claim(payload: ClaimLocalDataRequest) -> dict:
    mini = payload.mini_onboarding
    wizard = payload.wizard_answers
    date_of_birth = _valid_iso_date(
        _first_present(
            wizard.get("q_date_of_birth"),
            mini.get("q_date_of_birth"),
            wizard.get("dateOfBirth"),
        )
    )
    consumer_debt_total = _consumer_debt_total(wizard)
    explicit_has_debt = _as_bool(
        _first_present(
            wizard.get("q_has_debt"),
            wizard.get("q_has_consumer_debt"),
            wizard.get("hasDebt"),
        )
    )

    fields = {
        "householdType": _pick_household(payload),
        "dateOfBirth": date_of_birth,
        "birthYear": _bounded_int(
            _first_present(
                mini.get("q_birth_year"),
                wizard.get("q_birth_year"),
                wizard.get("birthYear"),
                _birth_year_from_date(date_of_birth),
            ),
            minimum=MIN_BIRTH_YEAR,
            maximum=MAX_BIRTH_YEAR,
        ),
        "canton": _first_present(
            mini.get("q_canton"),
            wizard.get("q_canton"),
            wizard.get("canton"),
        ),
        "commune": _first_present(wizard.get("q_commune"), wizard.get("commune")),
        "incomeNetMonthly": _bounded_float(
            _net_monthly_income(payload),
            maximum=MAX_PROFILE_MONEY,
        ),
        "incomeGrossYearly": _bounded_float(
            _first_present(
                wizard.get("q_gross_salary_annual"),
                wizard.get("incomeGrossYearly"),
            ),
            maximum=MAX_PROFILE_MONEY,
        ),
        "savingsMonthly": _bounded_float(
            _first_present(
                wizard.get("q_savings_monthly"), wizard.get("savingsMonthly")
            ),
            maximum=MAX_PROFILE_MONEY,
        ),
        "totalSavings": _bounded_float(
            _first_present(
                wizard.get("q_cash_total"),
                wizard.get("q_epargne_liquide"),
                wizard.get("totalSavings"),
            ),
            maximum=MAX_PROFILE_MONEY,
        ),
        "goal": _goal(payload),
        "employmentStatus": _first_present(
            wizard.get("q_employment_status"),
            wizard.get("employmentStatus"),
        ),
        "gender": _first_present(wizard.get("q_gender"), wizard.get("gender")),
        "targetRetirementAge": _bounded_int(
            _first_present(
                wizard.get("q_target_retirement_age"),
                wizard.get("targetRetirementAge"),
            ),
            minimum=58,
            maximum=70,
        ),
        "lppInsuredSalary": _bounded_float(
            _first_present(
                wizard.get("_coach_salaire_assure"),
                wizard.get("lppInsuredSalary"),
            ),
            maximum=MAX_PROFILE_MONEY,
        ),
        "avoirLpp": _bounded_float(
            _first_present(
                wizard.get("_coach_avoir_lpp"),
                wizard.get("q_avoir_lpp"),
                wizard.get("avoirLpp"),
            ),
            maximum=MAX_PROFILE_MONEY,
        ),
        "lppBuybackMax": _bounded_float(
            _first_present(
                wizard.get("_coach_rachat_maximum"),
                wizard.get("lppBuybackMax"),
            ),
            maximum=MAX_PROFILE_MONEY,
        ),
        "pillar3aBalance": _bounded_float(
            _first_present(
                wizard.get("q_3a_total"),
                wizard.get("q_total_3a"),
                wizard.get("_coach_total_3a"),
                wizard.get("pillar3aBalance"),
            ),
            maximum=MAX_PROFILE_MONEY,
        ),
        "pillar3aAnnual": _bounded_float(
            _first_present(
                wizard.get("q_3a_annual_contribution"),
                wizard.get("pillar3aAnnual"),
            ),
            maximum=MAX_PILLAR3A_ANNUAL,
        ),
        "hasDebt": explicit_has_debt
        if explicit_has_debt is not None
        else (True if consumer_debt_total > 0 else None),
        "avsContributionYears": _bounded_int(
            _first_present(
                wizard.get("q_avs_contribution_years"),
                wizard.get("avsContributionYears"),
            ),
            maximum=MAX_AVS_CONTRIBUTION_YEARS,
        ),
        "spouseBirthYear": _bounded_int(
            _first_present(
                wizard.get("q_partner_birth_year"),
                wizard.get("spouseBirthYear"),
            ),
            minimum=MIN_BIRTH_YEAR,
            maximum=MAX_BIRTH_YEAR,
        ),
        "spouseIncomeNetMonthly": _bounded_float(
            _first_present(
                wizard.get("q_partner_net_income_chf"),
                wizard.get("spouseIncomeNetMonthly"),
            ),
            maximum=MAX_PROFILE_MONEY,
        ),
        "spouseAvsContributionYears": _bounded_int(
            _first_present(
                wizard.get("q_spouse_avs_contribution_years"),
                wizard.get("spouseAvsContributionYears"),
            ),
            maximum=MAX_AVS_CONTRIBUTION_YEARS,
        ),
    }
    if fields["householdType"] == "single":
        fields.pop("spouseBirthYear", None)
        fields.pop("spouseIncomeNetMonthly", None)
        fields.pop("spouseAvsContributionYears", None)
    return {key: value for key, value in fields.items() if value is not None}


def _is_bootstrap_profile(data: dict) -> bool:
    return "localDataClaim" not in data and set(data).issubset(_BOOTSTRAP_PROFILE_KEYS)


def _merge_claim_fields(existing_data: dict, claim_fields: dict) -> dict:
    data = dict(existing_data)
    bootstrap_profile = _is_bootstrap_profile(data)
    for key, value in claim_fields.items():
        if key not in data or data[key] is None or bootstrap_profile:
            data[key] = value
    return data


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
                    merged_fields_count = len(body.mini_onboarding) + len(
                        body.wizard_answers
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
            merged_fields_count = len(body.mini_onboarding) + len(body.wizard_answers)
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
        "mint2AxisHandoff": body.mint2_axis_handoff,
        "budgetSnapshot": body.budget_snapshot,
        "checkins": body.checkins,
    }
    claim_fields = _profile_fields_from_claim(body)

    if existing_profile:
        data = _merge_claim_fields(existing_profile.data, claim_fields)
        data["localDataClaim"] = claim_blob
        data.setdefault("createdAt", now.isoformat())

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
        **claim_fields,
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
