"""
Fresh-start anchor detection and proactive messaging.

Computes landmark dates (birthday, month-start, year-start, job anniversary,
MINT anniversary) from user profile and generates personalized messages for
each upcoming landmark within 60 days.

Sources:
    - CMIT-03: 5 landmark types per locked decision
    - CMIT-04: 1 message per landmark, max 2/month
    - T-14-10: Rate limit — max 2 landmarks returned per month
    - T-14-12: Server-side rate limiting is primary control
"""

from __future__ import annotations

import logging
from collections import defaultdict
from datetime import date, datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.database import get_db
from app.models.commitment import CommitmentDevice
from app.models.profile_model import ProfileModel
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Pure functions
# ---------------------------------------------------------------------------


def compute_fresh_start_dates(
    birth_date: Optional[date],
    first_employment_year: Optional[int],
    account_created_at: Optional[datetime],
    reference_date: Optional[date] = None,
) -> list[dict]:
    """Compute up to 5 landmark types for the next 60 days.

    Returns list of dicts with type, date (ISO), days_until.
    ``reference_date`` defaults to today and is exposed for testing.
    """
    today = reference_date or date.today()
    landmarks: list[dict] = []

    # 1. Birthday — next occurrence of birth_date
    if birth_date is not None:
        next_bday = birth_date.replace(year=today.year)
        if next_bday < today:
            next_bday = next_bday.replace(year=today.year + 1)
        days = (next_bday - today).days
        if 0 <= days <= 60:
            landmarks.append(
                {"type": "birthday", "date": next_bday.isoformat(), "days_until": days}
            )

    # 2. Month start — 1st of next month
    if today.month == 12:
        next_month_start = date(today.year + 1, 1, 1)
    else:
        next_month_start = date(today.year, today.month + 1, 1)
    days = (next_month_start - today).days
    if 0 <= days <= 60:
        landmarks.append(
            {
                "type": "month_start",
                "date": next_month_start.isoformat(),
                "days_until": days,
            }
        )

    # 3. Year start — January 1st of next year (only if within 60 days)
    next_year_start = date(today.year + 1, 1, 1)
    days = (next_year_start - today).days
    if 0 <= days <= 60:
        landmarks.append(
            {
                "type": "year_start",
                "date": next_year_start.isoformat(),
                "days_until": days,
            }
        )

    # 4. Job anniversary — years of service anniversary
    if first_employment_year is not None:
        years_worked = today.year - first_employment_year
        if years_worked > 0:
            # Anniversary is July 1 (midpoint) of this year or next
            anniv = date(today.year, 7, 1)
            if anniv < today:
                anniv = date(today.year + 1, 7, 1)
                years_worked += 1
            days = (anniv - today).days
            if 0 <= days <= 60:
                landmarks.append(
                    {
                        "type": "job_anniversary",
                        "date": anniv.isoformat(),
                        "days_until": days,
                        "years": years_worked,
                    }
                )

    # 5. MINT anniversary — 1 year from account creation
    if account_created_at is not None:
        created_date = (
            account_created_at.date()
            if isinstance(account_created_at, datetime)
            else account_created_at
        )
        next_anniv = created_date.replace(year=today.year)
        if next_anniv < today:
            next_anniv = next_anniv.replace(year=today.year + 1)
        # Only show if account is at least ~1 year old
        account_age_days = (today - created_date).days
        if account_age_days >= 330:
            days = (next_anniv - today).days
            if 0 <= days <= 60:
                landmarks.append(
                    {
                        "type": "mint_anniversary",
                        "date": next_anniv.isoformat(),
                        "days_until": days,
                    }
                )

    return landmarks


def generate_fresh_start_message(
    landmark_type: str,
    profile_context: dict,
    commitment_count: int = 0,
) -> dict:
    """Generate a personalized template message for a landmark type.

    Uses conditional language (peut-etre, un bon moment), never prescriptive.
    Returns dict with message and intent for coach deeplink.
    """
    birth_date = profile_context.get("birth_date")
    first_employment_year = profile_context.get("first_employment_year")
    pillar_3a_amount = profile_context.get("pillar_3a_capital")

    if landmark_type == "birthday":
        age_next = None
        if birth_date:
            today = date.today()
            age_next = today.year - birth_date.year
            next_bday = birth_date.replace(year=today.year)
            if next_bday < today:
                age_next += 1
        age_str = str(age_next) if age_next else "un nouvel"
        commit_str = (
            f"{commitment_count} engagement(s) financier(s) en cours"
            if commitment_count
            else "aucun engagement financier en cours"
        )
        message = (
            f"C'est bient\u00f4t ton anniversaire. {age_str}\u00a0ans, "
            f"et {commit_str}. "
            f"Un bon moment pour faire le point\u00a0?"
        )
        intent = "birthday_review"

    elif landmark_type == "month_start":
        amount_str = (
            f"{pillar_3a_amount:,.0f}\u00a0CHF".replace(",", "\u2019")
            if pillar_3a_amount
            else "un montant que je ne connais pas encore"
        )
        message = (
            f"Nouveau mois. Ton 3a attend peut-\u00eatre un versement "
            f"\u2014 tu en es \u00e0 {amount_str}."
        )
        intent = "monthly_3a_check"

    elif landmark_type == "year_start":
        message = (
            "Nouvelle ann\u00e9e. C'est le moment id\u00e9al pour revoir "
            "ta situation \u2014 tes engagements, tes projections, ce qui a "
            "chang\u00e9."
        )
        intent = "yearly_review"

    elif landmark_type == "job_anniversary":
        years = profile_context.get("job_years", 0)
        message = (
            f"{years}\u00a0ans dans la vie active. Ton 2e\u00a0pilier a "
            f"peut-\u00eatre \u00e9volu\u00e9 \u2014 un bon moment pour "
            f"v\u00e9rifier ton certificat LPP."
        )
        intent = "lpp_certificate_check"

    elif landmark_type == "mint_anniversary":
        message = (
            "Un an avec MINT. On a parcouru du chemin ensemble. "
            "Envie de voir ce qui a chang\u00e9 dans ta situation\u00a0?"
        )
        intent = "mint_anniversary_review"

    else:
        message = "Un moment cl\u00e9 approche \u2014 envie d'en parler\u00a0?"
        intent = "general_review"

    return {"message": message, "intent": intent}


def apply_rate_limit(landmarks: list[dict], max_per_month: int = 2) -> list[dict]:
    """Keep at most ``max_per_month`` landmarks per calendar month.

    Landmarks are assumed sorted by ``days_until`` (ascending).
    """
    sorted_landmarks = sorted(landmarks, key=lambda lm: lm.get("days_until", 999))
    month_counts: dict[str, int] = defaultdict(int)
    result: list[dict] = []
    for lm in sorted_landmarks:
        month_key = lm["date"][:7]  # YYYY-MM
        if month_counts[month_key] < max_per_month:
            result.append(lm)
            month_counts[month_key] += 1
    return result


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------


class LandmarkResponse(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    type: str
    date: str
    days_until: int
    message: str
    intent: str


class FreshStartResponse(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )

    landmarks: list[LandmarkResponse]


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------


@router.get("/", response_model=FreshStartResponse)
async def get_fresh_start(
    user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
):
    """Return upcoming fresh-start landmarks with personalized messages.

    Rate-limited to max 2 landmarks per calendar month (T-14-10).
    """
    # Load profile
    profile = (
        db.query(ProfileModel)
        .filter(ProfileModel.user_id == user.id)
        .first()
    )

    profile_data = profile.data if profile and profile.data else {}

    # Extract profile fields
    birth_date = None
    bd_raw = profile_data.get("birthDate") or profile_data.get("birth_date")
    if bd_raw:
        try:
            if isinstance(bd_raw, str):
                birth_date = date.fromisoformat(bd_raw[:10])
            elif isinstance(bd_raw, (date, datetime)):
                birth_date = bd_raw if isinstance(bd_raw, date) else bd_raw.date()
        except (ValueError, TypeError):
            logger.warning("Invalid birth_date in profile: %s", bd_raw)

    first_employment_year = None
    fey_raw = profile_data.get("firstEmploymentYear") or profile_data.get(
        "first_employment_year"
    )
    if fey_raw:
        try:
            first_employment_year = int(fey_raw)
        except (ValueError, TypeError):
            logger.warning("Invalid first_employment_year: %s", fey_raw)

    pillar_3a_capital = None
    p3a_raw = profile_data.get("pillar3aCapital") or profile_data.get(
        "pillar_3a_capital"
    )
    if p3a_raw:
        try:
            pillar_3a_capital = float(p3a_raw)
        except (ValueError, TypeError):
            pass

    # Count active commitments
    commitment_count = (
        db.query(CommitmentDevice)
        .filter(
            CommitmentDevice.user_id == user.id,
            CommitmentDevice.status == "pending",
        )
        .count()
    )

    # Compute landmarks
    landmarks = compute_fresh_start_dates(
        birth_date=birth_date,
        first_employment_year=first_employment_year,
        account_created_at=user.created_at,
    )

    # Apply rate limit (max 2 per month)
    landmarks = apply_rate_limit(landmarks)

    # Generate messages
    profile_context = {
        "birth_date": birth_date,
        "first_employment_year": first_employment_year,
        "pillar_3a_capital": pillar_3a_capital,
    }

    result: list[dict] = []
    for lm in landmarks:
        if lm["type"] == "job_anniversary":
            profile_context["job_years"] = lm.get("years", 0)
        msg = generate_fresh_start_message(
            lm["type"], profile_context, commitment_count
        )
        result.append(
            {
                "type": lm["type"],
                "date": lm["date"],
                "days_until": lm["days_until"],
                "message": msg["message"],
                "intent": msg["intent"],
            }
        )

    return FreshStartResponse(landmarks=result)
