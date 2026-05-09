"""
Annual Refresh Service — Sprint S37.

Detects stale profiles (last_major_update > 11 months ago) and generates
a set of 7 refresh questions pre-filled with current values.

Questions:
    1. Salary change        -> slider
    2. Job change           -> yes_no
    3. Current LPP balance  -> text
    4. 3a balance           -> text (pre-filled with projection)
    5. Housing project      -> yes_no
    6. Family change        -> select (marriage/birth/divorce/none)
    7. Risk appetite        -> select (conservateur/modere/dynamique)

Sources:
    - LSFin art. 3 (information financiere)
"""

from datetime import date
from typing import List, Optional

from app.services.scenario.scenario_models import (
    AnnualRefreshResult,
    RefreshQuestion,
)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

REFRESH_THRESHOLD_MONTHS = 11

STANDARD_DISCLAIMER = (
    "Outil educatif simplifie. Ne constitue pas un conseil financier (LSFin)."
)

STANDARD_SOURCES = ["LSFin art. 3"]

FAMILY_OPTIONS = ["mariage", "naissance", "divorce", "aucun"]

RISK_OPTIONS = ["conservateur", "modere", "dynamique"]


def _format_chf_value(amount: float) -> str:
    """Format a CHF amount as a string for pre-filling."""
    rounded = round(amount)
    if rounded < 0:
        return "-" + _format_chf_value(-rounded)
    s = str(rounded)
    parts = []
    while len(s) > 3:
        parts.append(s[-3:])
        s = s[:-3]
    parts.append(s)
    return "'".join(reversed(parts))


def _months_between(start: date, end: date) -> int:
    """Calculate the number of months between two dates."""
    return (end.year - start.year) * 12 + (end.month - start.month)


class AnnualRefreshService:
    """Detects stale profiles and generates refresh questions.

    Trigger: last_major_update > 11 months ago.
    """

    def check_refresh_needed(
        self,
        last_major_update: date,
        today: Optional[date] = None,
    ) -> bool:
        """Return True if profile is stale (> 11 months since last update).

        Args:
            last_major_update: Date of the last major profile update.
            today: Override for current date (for testing). Defaults to today.

        Returns:
            True if refresh is needed.
        """
        if today is None:
            today = date.today()
        months = _months_between(last_major_update, today)
        return months > REFRESH_THRESHOLD_MONTHS

    def generate_refresh_questions(
        self,
        current_salary: float = 0,
        current_lpp: float = 0,
        current_3a: float = 0,
        risk_profile: str = "modere",
        last_major_update: Optional[date] = None,
        today: Optional[date] = None,
        employment_status: Optional[str] = None,
    ) -> AnnualRefreshResult:
        """Generate the 7 refresh questions with pre-filled values.

        Args:
            current_salary: Current gross annual salary (CHF).
            current_lpp: Current LPP balance (CHF).
            current_3a: Current 3a balance (CHF).
            risk_profile: Current risk profile (conservateur/modere/dynamique).
            last_major_update: Date of last update (for months_since calculation).
            today: Override for current date (for testing).
            employment_status: Optional employment status code
                ('salarie', 'independant', 'retraite', 'student', ...).
                When set to 'retraite', the salary question is reframed
                ("source de revenus" instead of "salaire brut") to avoid
                hitting retirees with an inapplicable cron prompt
                (B-EXP-F-1 audit fix 2026-05-09 — perimeter STUB
                .planning/decisions/2026-05-09-perimeter-p1-cron-archetype-aware/).

        Returns:
            AnnualRefreshResult with refresh_needed flag and 7 questions.
        """
        if today is None:
            today = date.today()

        if last_major_update is None:
            last_major_update = today
        months_since = _months_between(last_major_update, today)
        refresh_needed = months_since > REFRESH_THRESHOLD_MONTHS

        questions = self._build_questions(
            current_salary=current_salary,
            current_lpp=current_lpp,
            current_3a=current_3a,
            risk_profile=risk_profile,
            employment_status=employment_status,
        )

        return AnnualRefreshResult(
            refresh_needed=refresh_needed,
            months_since_update=months_since,
            questions=questions,
            disclaimer=STANDARD_DISCLAIMER,
            sources=list(STANDARD_SOURCES),
        )

    @staticmethod
    def _build_questions(
        current_salary: float,
        current_lpp: float,
        current_3a: float,
        risk_profile: str,
        employment_status: Optional[str] = None,
    ) -> List[RefreshQuestion]:
        """Build the 7 standard refresh questions.

        B-EXP-F-1 audit fix 2026-05-09 : when employment_status == 'retraite',
        reframe the salary question to "source de revenus" so retirees
        don't get a yearly cron prompt about a salary they don't have.
        Same pattern as the B2 fix on suggest_actions chips.
        """
        is_retired = employment_status == "retraite"
        salary_label = (
            "Tes sources de revenus (rentes, retraits, autres) ont-elles change ?"
            if is_retired
            else "Ton salaire annuel brut a-t-il change ?"
        )
        job_label = (
            "Y a-t-il eu un changement dans ta situation (rente, activite reduite, deces conjoint) ?"
            if is_retired
            else "As-tu change d'emploi ou de statut professionnel ?"
        )
        return [
            RefreshQuestion(
                key="salary_changed",
                label=salary_label,
                question_type="slider",
                current_value=_format_chf_value(current_salary) if current_salary else None,
            ),
            RefreshQuestion(
                key="job_changed",
                label=job_label,
                question_type="yes_no",
            ),
            RefreshQuestion(
                key="lpp_balance",
                label="Quel est ton avoir LPP actuel (certificat de prevoyance) ?",
                question_type="text",
                current_value=_format_chf_value(current_lpp) if current_lpp else None,
            ),
            RefreshQuestion(
                key="three_a_balance",
                label="Quel est ton solde 3a actuel ?",
                question_type="text",
                current_value=_format_chf_value(current_3a) if current_3a else None,
            ),
            RefreshQuestion(
                key="housing_project",
                label="As-tu un projet immobilier en cours ou prevu ?",
                question_type="yes_no",
            ),
            RefreshQuestion(
                key="family_change",
                label="Y a-t-il eu un changement familial ?",
                question_type="select",
                options=list(FAMILY_OPTIONS),
            ),
            RefreshQuestion(
                key="risk_appetite",
                label="Comment decrirais-tu ton appetit pour le risque ?",
                question_type="select",
                current_value=risk_profile,
                options=list(RISK_OPTIONS),
            ),
        ]
