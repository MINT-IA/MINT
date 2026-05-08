"""Coverage tests for B2 (archetype-agnostic income chip) and B6
(doctrine_checks fail-loud on empty archetype).

These tests exist to satisfy the diff-cover gate (--fail-under=80) on the
PR #529 onboarding hotfix bundle. Without them the new branches at
coach_chat.py:917-925 and doctrine_checks.py:498-503 would be untested.
"""

from __future__ import annotations

from unittest.mock import MagicMock

from app.api.v1.endpoints.coach_chat import _compute_suggested_actions
from app.services.coach.doctrine_checks import (
    QuestionMeta,
    check_archetype_aware,
)


# ---------------------------------------------------------------------------
# B2 — archetype-agnostic « D'où vient ton argent ? » chip
# ---------------------------------------------------------------------------


def test_b2_money_source_chip_appears_when_income_missing():
    """When neither incomeNetMonthly nor incomeGrossYearly is set in the
    profile, the suggested-actions chip is the new B2 archetype-agnostic
    « D'où vient ton argent ? ... » phrasing — NOT the legacy
    « Quel est ton salaire net mensuel ? ».

    Pre-B2 (2026-05-08), this chip was « Quel est ton salaire net mensuel ? »
    which assumed salaried_active (4/8 archetypes only) and excluded
    independents, retirees, students, expat_us in transition, returning_swiss
    et al. — a CLAUDE.md NEVER #4 + NEVER #7 violation.
    """
    fake_profile = MagicMock()
    fake_profile.data = {
        # birthYear + canton present so we don't hit those chip branches
        "birthYear": 1990,
        "canton": "VD",
        # incomeNetMonthly + incomeGrossYearly intentionally MISSING — the
        # branch under test (coach_chat.py:916-925) fires only when both
        # are falsy.
    }
    fake_db = MagicMock()
    fake_db.query.return_value.filter.return_value.order_by.return_value.first.return_value = (
        fake_profile
    )

    actions = _compute_suggested_actions(user_id="user-123", db=fake_db)

    labels = [a["label"] for a in actions]
    # Must contain the new archetype-agnostic chip
    money_chip_present = any(
        "D'où vient ton argent" in label for label in labels
    )
    assert money_chip_present, (
        f"B2 chip missing — actions returned {labels!r}. The chip at "
        f"coach_chat.py:922 should fire when both incomeNetMonthly and "
        f"incomeGrossYearly are absent from the profile."
    )

    # Must NOT contain the legacy salaire-first phrasing
    salary_first_present = any(
        "salaire net mensuel" in label.lower() for label in labels
    )
    assert not salary_first_present, (
        f"B2 regression — legacy « salaire net mensuel » chip leaked back "
        f"into actions: {labels!r}. CLAUDE.md NEVER #4 + #7 violation."
    )


# ---------------------------------------------------------------------------
# B6 — doctrine_checks fail-loud on empty archetype
# ---------------------------------------------------------------------------


def test_b6_archetype_aware_fails_on_empty_archetype():
    """check_archetype_aware MUST return passed=False when meta.archetype
    is empty — closes the silent FATCA bypass.

    Pre-B6 (2026-05-08), if the front-end didn't plumb archetype into the
    LLM context (which it didn't — see coach_chat_screen.dart:1692-1698
    pre-fix), meta.archetype defaulted to "" (post-B4 empty default) and
    the check fell through the « no cues defined → pass » branch at
    doctrine_checks.py:507. Net effect: an expat_us user could receive
    « Verse 7'258 CHF sur ton 3a » without the FATCA guard firing.

    The B6 fix at doctrine_checks.py:498-503 makes empty/unknown archetype
    a guard violation rather than a silent skip.
    """
    response = "Verse 7'258 CHF sur ton 3a avant fin décembre."
    meta = QuestionMeta(archetype="")

    result = check_archetype_aware(response, meta)

    assert not result.passed, (
        f"B6 regression — empty archetype produced passed=True at "
        f"doctrine_checks.py. Expected fail-loud per B6 fix to close "
        f"FATCA bypass. result={result!r}"
    )
    assert "empty" in result.reason.lower() or "unknown" in result.reason.lower(), (
        f"B6 fail message should mention empty/unknown archetype. "
        f"Got reason={result.reason!r}"
    )


def test_b6_archetype_aware_fails_on_whitespace_archetype():
    """Whitespace-only archetype is treated the same as empty (B6 strip)."""
    response = "Plafond 7'258 CHF."
    meta = QuestionMeta(archetype="   ")

    result = check_archetype_aware(response, meta)

    assert not result.passed, (
        f"B6 regression — whitespace-only archetype produced passed=True. "
        f"The .strip() guard at doctrine_checks.py:498 should treat "
        f"whitespace as empty. result={result!r}"
    )
