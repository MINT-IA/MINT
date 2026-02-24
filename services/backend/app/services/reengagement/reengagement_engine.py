"""
Reengagement Engine — Sprint S40.

Generates personalized reengagement messages tied to the Swiss financial
calendar. Every message MUST contain a personal CHF number and a time
constraint — no generic "we miss you" push notifications.

Calendar mapping:
    - January: new_year — new 3a ceilings
    - February: tax_prep — prepare declaration
    - March: tax_deadline — canton-specific deadline
    - October: three_a_countdown — days remaining
    - November: three_a_urgency — urgency + savings estimate
    - December: three_a_final — last month warning
    - Quarterly (1, 4, 7, 10): quarterly_fri — FRI score update

Sources:
    - OPP3 art. 7 (plafond 3a)
    - LSFin art. 3 (information financiere)
"""

from datetime import date
from typing import List, Optional

from app.services.reengagement.reengagement_models import (
    ReengagementMessage,
    ReengagementTrigger,
)


def _format_chf(amount: float) -> str:
    """Format CHF amount with Swiss apostrophe as thousands separator.

    Examples:
        1234.0  -> "1'234"
        7258.0  -> "7'258"
        36288.0 -> "36'288"
        150.5   -> "151"
    """
    rounded = round(amount)
    if rounded < 0:
        return f"-{_format_chf(-amount)}"
    s = str(rounded)
    # Insert apostrophes from the right
    parts: List[str] = []
    while len(s) > 3:
        parts.append(s[-3:])
        s = s[:-3]
    parts.append(s)
    return "'".join(reversed(parts))


def _days_until_year_end(today: date) -> int:
    """Return the number of days remaining until 31 December."""
    year_end = date(today.year, 12, 31)
    return (year_end - today).days


class ReengagementEngine:
    """Generates personalized reengagement messages.

    NEVER generic. Always:
    - Contains a personal number (CHF or %)
    - Contains a time constraint
    - Links to relevant screen

    BANNED:
    - "Tu n'as pas utilise MINT depuis X jours"
    - "Reviens decouvrir nos nouvelles fonctionnalites!"
    - "Tu nous manques!"
    - Any generic encouragement without personal numbers
    """

    def generate_messages(
        self,
        today: Optional[date] = None,
        canton: str = "VD",
        tax_saving_3a: float = 0.0,
        fri_total: float = 0.0,
        fri_delta: float = 0.0,
        replacement_ratio: float = 0.0,
    ) -> List[ReengagementMessage]:
        """Generate applicable reengagement messages for today.

        Checks calendar triggers and generates personalized messages.
        Returns a list of ReengagementMessage — may contain 0, 1, or 2
        messages if multiple triggers match (e.g. January = new_year + quarterly).

        Args:
            today: Override date for testing (defaults to date.today()).
            canton: Canton code (2 letters) for tax deadline.
            tax_saving_3a: Estimated CHF tax saving from max 3a contribution.
            fri_total: Current FRI score (0-100).
            fri_delta: FRI change since last quarter.
            replacement_ratio: Projected replacement ratio (0-1).
        """
        if today is None:
            today = date.today()

        month = today.month
        messages: List[ReengagementMessage] = []

        saving_str = _format_chf(tax_saving_3a)
        days_left = _days_until_year_end(today)

        # January: new year, new ceilings
        if month == 1:
            messages.append(ReengagementMessage(
                trigger=ReengagementTrigger.new_year,
                title="Nouveaux plafonds 3a: CHF 7'258",
                body=(
                    f"Nouveaux plafonds 3a: CHF 7'258. "
                    f"Ton economie potentielle : CHF {saving_str}."
                ),
                deeplink="/3a",
                personal_number=f"CHF {saving_str}",
                time_constraint="Annee fiscale 2026",
                month=1,
            ))

        # February: tax prep
        if month == 2:
            messages.append(ReengagementMessage(
                trigger=ReengagementTrigger.tax_prep,
                title="Prepare ta declaration fiscale",
                body=(
                    f"Prepare ta declaration: tes chiffres cles sont disponibles. "
                    f"Economie 3a estimee : CHF {saving_str}."
                ),
                deeplink="/fiscal",
                personal_number=f"CHF {saving_str}",
                time_constraint="Declaration fiscale a preparer",
                month=2,
            ))

        # March: tax deadline (canton-specific)
        if month == 3:
            messages.append(ReengagementMessage(
                trigger=ReengagementTrigger.tax_deadline,
                title=f"Deadline canton de {canton}",
                body=(
                    f"Deadline canton de {canton}: bientot. "
                    f"Tes chiffres sont prets. "
                    f"Economie 3a estimee : CHF {saving_str}."
                ),
                deeplink="/fiscal",
                personal_number=f"CHF {saving_str}",
                time_constraint=f"Deadline canton de {canton}",
                month=3,
            ))

        # October: 3a countdown
        if month == 10:
            messages.append(ReengagementMessage(
                trigger=ReengagementTrigger.three_a_countdown,
                title=f"Il reste {days_left} jours pour ton 3a",
                body=(
                    f"Il reste {days_left} jours pour verser ton 3a. "
                    f"Economie estimee : CHF {saving_str}."
                ),
                deeplink="/3a",
                personal_number=f"CHF {saving_str}",
                time_constraint=f"{days_left} jours restants",
                month=10,
            ))

        # November: 3a urgency
        if month == 11:
            messages.append(ReengagementMessage(
                trigger=ReengagementTrigger.three_a_urgency,
                title=f"Plus que {days_left} jours pour ton 3a",
                body=(
                    f"Il reste {days_left} jours. "
                    f"Economie estimee : CHF {saving_str}."
                ),
                deeplink="/3a",
                personal_number=f"CHF {saving_str}",
                time_constraint=f"{days_left} jours restants",
                month=11,
            ))

        # December: 3a final
        if month == 12:
            messages.append(ReengagementMessage(
                trigger=ReengagementTrigger.three_a_final,
                title="Dernier mois pour ton versement 3a",
                body=(
                    f"Dernier mois. "
                    f"CHF {saving_str} d'economie en jeu."
                ),
                deeplink="/3a",
                personal_number=f"CHF {saving_str}",
                time_constraint="Dernier mois",
                month=12,
            ))

        # Quarterly FRI (January, April, July, October)
        if month in (1, 4, 7, 10):
            fri_str = f"{fri_total:.0f}"
            delta_sign = "+" if fri_delta >= 0 else ""
            delta_str = f"{delta_sign}{fri_delta:.0f}"
            messages.append(ReengagementMessage(
                trigger=ReengagementTrigger.quarterly_fri,
                title=f"Ton score de solidite : {fri_str}/100",
                body=(
                    f"Ton score de solidite: {fri_str} "
                    f"({delta_str} ce trimestre)."
                ),
                deeplink="/dashboard",
                personal_number=f"{fri_str}/100",
                time_constraint="Bilan trimestriel",
                month=month,
            ))

        return messages
