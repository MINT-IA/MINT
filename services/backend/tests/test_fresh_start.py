"""
Tests for fresh-start anchor detection and proactive messaging.

Covers:
    - Date computation for all 5 landmark types
    - Edge cases (None fields, past birthdays, account too young)
    - Message generation with conditional language
    - Banned term absence
    - Rate limiting (max 2 per month)
"""

from datetime import date, datetime, timezone

import pytest

from app.api.v1.endpoints.fresh_start import (
    apply_rate_limit,
    compute_fresh_start_dates,
    generate_fresh_start_message,
)

# ---------------------------------------------------------------------------
# Date computation tests
# ---------------------------------------------------------------------------


def test_compute_dates_birthday():
    """Birthday computed correctly — next occurrence within 60 days."""
    # Reference: April 12. Birthday: April 20 => 8 days away
    result = compute_fresh_start_dates(
        birth_date=date(1990, 4, 20),
        first_employment_year=None,
        account_created_at=None,
        reference_date=date(2026, 4, 12),
    )
    bdays = [r for r in result if r["type"] == "birthday"]
    assert len(bdays) == 1
    assert bdays[0]["date"] == "2026-04-20"
    assert bdays[0]["days_until"] == 8


def test_compute_dates_birthday_past_this_year():
    """Birthday already passed this year => next year."""
    # Reference: April 12. Birthday: March 1 => next is March 1 2027
    result = compute_fresh_start_dates(
        birth_date=date(1990, 3, 1),
        first_employment_year=None,
        account_created_at=None,
        reference_date=date(2026, 4, 12),
    )
    bdays = [r for r in result if r["type"] == "birthday"]
    # March 1 2027 is > 60 days from April 12 2026, so not included
    assert len(bdays) == 0


def test_compute_dates_birthday_within_60_days_next_year():
    """Birthday early Jan, reference late Nov => within 60 days next year."""
    result = compute_fresh_start_dates(
        birth_date=date(1990, 1, 5),
        first_employment_year=None,
        account_created_at=None,
        reference_date=date(2026, 11, 20),
    )
    bdays = [r for r in result if r["type"] == "birthday"]
    assert len(bdays) == 1
    assert bdays[0]["date"] == "2027-01-05"
    assert bdays[0]["days_until"] == 46


def test_compute_dates_month_start():
    """Always returns 1st of next month."""
    result = compute_fresh_start_dates(
        birth_date=None,
        first_employment_year=None,
        account_created_at=None,
        reference_date=date(2026, 4, 12),
    )
    months = [r for r in result if r["type"] == "month_start"]
    assert len(months) == 1
    assert months[0]["date"] == "2026-05-01"
    assert months[0]["days_until"] == 19


def test_compute_dates_month_start_december():
    """December wraps to January next year."""
    result = compute_fresh_start_dates(
        birth_date=None,
        first_employment_year=None,
        account_created_at=None,
        reference_date=date(2026, 12, 15),
    )
    months = [r for r in result if r["type"] == "month_start"]
    assert len(months) == 1
    assert months[0]["date"] == "2027-01-01"


def test_compute_dates_year_start():
    """Year start only included if within 60 days."""
    # Nov 15 => Jan 1 is 47 days away, within 60
    result = compute_fresh_start_dates(
        birth_date=None,
        first_employment_year=None,
        account_created_at=None,
        reference_date=date(2026, 11, 15),
    )
    years = [r for r in result if r["type"] == "year_start"]
    assert len(years) == 1
    assert years[0]["date"] == "2027-01-01"


def test_compute_dates_year_start_too_far():
    """Year start not included if > 60 days away."""
    result = compute_fresh_start_dates(
        birth_date=None,
        first_employment_year=None,
        account_created_at=None,
        reference_date=date(2026, 4, 12),
    )
    years = [r for r in result if r["type"] == "year_start"]
    assert len(years) == 0


def test_compute_dates_no_birth_date():
    """Graceful skip when birth_date is None."""
    result = compute_fresh_start_dates(
        birth_date=None,
        first_employment_year=2010,
        account_created_at=None,
        reference_date=date(2026, 5, 15),
    )
    bdays = [r for r in result if r["type"] == "birthday"]
    assert len(bdays) == 0


def test_compute_dates_no_first_employment():
    """Graceful skip when first_employment_year is None."""
    result = compute_fresh_start_dates(
        birth_date=None,
        first_employment_year=None,
        account_created_at=None,
        reference_date=date(2026, 6, 1),
    )
    jobs = [r for r in result if r["type"] == "job_anniversary"]
    assert len(jobs) == 0


def test_compute_dates_job_anniversary():
    """Job anniversary computed when within 60 days."""
    # First employment 2016, reference June 1 2026 => July 1 is 30 days away
    result = compute_fresh_start_dates(
        birth_date=None,
        first_employment_year=2016,
        account_created_at=None,
        reference_date=date(2026, 6, 1),
    )
    jobs = [r for r in result if r["type"] == "job_anniversary"]
    assert len(jobs) == 1
    assert jobs[0]["date"] == "2026-07-01"
    assert jobs[0]["years"] == 10


def test_compute_dates_mint_anniversary_too_young():
    """Skip if account < 1 year old (< 330 days)."""
    recent = datetime(2026, 1, 1, tzinfo=timezone.utc)
    result = compute_fresh_start_dates(
        birth_date=None,
        first_employment_year=None,
        account_created_at=recent,
        reference_date=date(2026, 4, 12),
    )
    mints = [r for r in result if r["type"] == "mint_anniversary"]
    assert len(mints) == 0


def test_compute_dates_mint_anniversary_eligible():
    """Mint anniversary shown when account is ~1 year old and date within 60 days."""
    created = datetime(2025, 5, 1, tzinfo=timezone.utc)
    result = compute_fresh_start_dates(
        birth_date=None,
        first_employment_year=None,
        account_created_at=created,
        reference_date=date(2026, 4, 12),
    )
    mints = [r for r in result if r["type"] == "mint_anniversary"]
    assert len(mints) == 1
    assert mints[0]["date"] == "2026-05-01"


# ---------------------------------------------------------------------------
# Message generation tests
# ---------------------------------------------------------------------------


def test_generate_message_birthday():
    """Birthday message contains age and conditional language."""
    msg = generate_fresh_start_message(
        "birthday",
        {"birth_date": date(1990, 4, 20)},
        commitment_count=3,
    )
    assert "anniversaire" in msg["message"]
    assert "3 engagement(s)" in msg["message"]
    assert "Un bon moment" in msg["message"]
    assert msg["intent"] == "birthday_review"


def test_generate_message_birthday_no_commitments():
    """Birthday message with zero commitments uses 'aucun'."""
    msg = generate_fresh_start_message(
        "birthday",
        {"birth_date": date(1990, 4, 20)},
        commitment_count=0,
    )
    assert "aucun engagement" in msg["message"]


def test_generate_message_month_start():
    """Month start message mentions 3a."""
    msg = generate_fresh_start_message(
        "month_start",
        {"pillar_3a_capital": 5000.0},
        commitment_count=0,
    )
    assert "3a" in msg["message"]
    assert "5\u2019000" in msg["message"]
    assert msg["intent"] == "monthly_3a_check"


def test_generate_message_month_start_no_3a():
    """Month start message when 3a amount unknown."""
    msg = generate_fresh_start_message(
        "month_start",
        {},
        commitment_count=0,
    )
    assert "un montant que je ne connais pas encore" in msg["message"]


def test_generate_message_year_start():
    """Year start message mentions revoir situation."""
    msg = generate_fresh_start_message("year_start", {}, 0)
    assert "revoir" in msg["message"].lower() or "situation" in msg["message"].lower()
    assert msg["intent"] == "yearly_review"


def test_generate_message_job_anniversary():
    """Job anniversary message references 2e pilier."""
    msg = generate_fresh_start_message(
        "job_anniversary",
        {"job_years": 10},
        commitment_count=0,
    )
    assert "10" in msg["message"]
    assert "LPP" in msg["message"]
    assert msg["intent"] == "lpp_certificate_check"


def test_generate_message_mint_anniversary():
    """MINT anniversary message is warm and inviting."""
    msg = generate_fresh_start_message("mint_anniversary", {}, 0)
    assert "MINT" in msg["message"]
    assert "chang" in msg["message"]  # "changé"
    assert msg["intent"] == "mint_anniversary_review"


def test_generate_message_no_banned_terms():
    """None of the 5 templates contain banned terms."""
    banned = ["garanti", "certain", "assuré", "sans risque", "optimal", "meilleur", "parfait"]
    types = ["birthday", "month_start", "year_start", "job_anniversary", "mint_anniversary"]
    profile = {
        "birth_date": date(1990, 1, 1),
        "first_employment_year": 2010,
        "pillar_3a_capital": 5000.0,
        "job_years": 16,
    }
    for lt in types:
        msg = generate_fresh_start_message(lt, profile, commitment_count=2)
        text_lower = msg["message"].lower()
        for term in banned:
            assert term not in text_lower, f"Banned term '{term}' found in {lt} message"


# ---------------------------------------------------------------------------
# Rate limiting tests
# ---------------------------------------------------------------------------


def test_rate_limit_max_2_per_month():
    """When 3+ landmarks in same month, only first 2 returned."""
    landmarks = [
        {"type": "birthday", "date": "2026-04-15", "days_until": 3},
        {"type": "month_start", "date": "2026-04-20", "days_until": 8},
        {"type": "year_start", "date": "2026-04-25", "days_until": 13},
    ]
    result = apply_rate_limit(landmarks, max_per_month=2)
    assert len(result) == 2
    # Closest dates kept
    assert result[0]["days_until"] == 3
    assert result[1]["days_until"] == 8


def test_compute_dates_sensible_for_1992_profile():
    """Audit case: birth_date 1992-04-15 yields sensible landmarks.

    Verifies compute_fresh_start_dates returns plausible birthday, month-start
    and (when applicable) year-start anchors for a profile with a known birth
    date. Guards against regressions where landmark computation silently
    returns an empty list.
    """
    # Reference date slightly before the birthday, so it must be picked up.
    result = compute_fresh_start_dates(
        birth_date=date(1992, 4, 15),
        first_employment_year=None,
        account_created_at=None,
        reference_date=date(2026, 4, 1),
    )
    types = {r["type"] for r in result}

    # Must contain birthday (14 days away) and month_start (1 May, 30 days)
    assert "birthday" in types
    assert "month_start" in types

    bday = next(r for r in result if r["type"] == "birthday")
    assert bday["date"] == "2026-04-15"
    assert 0 < bday["days_until"] <= 60

    month = next(r for r in result if r["type"] == "month_start")
    assert month["date"] == "2026-05-01"
    assert month["days_until"] > 0

    # Dates must be ISO-parseable and unique per (type, date)
    seen = set()
    for r in result:
        key = (r["type"], r["date"])
        assert key not in seen, f"Duplicate landmark: {key}"
        seen.add(key)
        # Parseable ISO date
        date.fromisoformat(r["date"])


def test_rate_limit_different_months():
    """Landmarks in different months are not affected."""
    landmarks = [
        {"type": "birthday", "date": "2026-04-15", "days_until": 3},
        {"type": "month_start", "date": "2026-05-01", "days_until": 19},
        {"type": "year_start", "date": "2026-05-10", "days_until": 28},
    ]
    result = apply_rate_limit(landmarks, max_per_month=2)
    assert len(result) == 3  # 1 in April, 2 in May — all within limit
