"""
Notification Scheduler Service — Sprint S36.

Pure functions for generating calendar-driven (Tier 1) and event-driven (Tier 2)
notifications.

Rules:
    - Every notification contains a personal number (CHF or %)
    - Every notification contains a time reference
    - Every notification has a deeplink
    - No generic encouragement ("Reviens nous voir!")
    - No social comparison
    - No prescriptive language ("Tu dois verser...")
    - All French, informal "tu"
    - CHF formatted with Swiss apostrophe (1'820)

Sources:
    - OPP3 art. 7 — plafond 3a
    - LSFin art. 3 — obligation d'information
"""

from datetime import date
from typing import List, Optional

from app.services.notifications.notification_models import (
    NotificationCategory,
    NotificationTier,
    ScheduledNotification,
)


def _format_chf(amount: float) -> str:
    """Format a CHF amount with Swiss apostrophe grouping.

    Examples:
        1820.0  -> "1'820"
        12345.5 -> "12'346"
        100.0   -> "100"
    """
    rounded = round(amount)
    if rounded < 0:
        return f"-{_format_chf(-amount)}"
    s = str(rounded)
    # Insert apostrophe every 3 digits from the right
    parts: List[str] = []
    while len(s) > 3:
        parts.append(s[-3:])
        s = s[:-3]
    parts.append(s)
    return "\u2019".join(reversed(parts))


class NotificationSchedulerService:
    """Generates calendar-driven and event-driven notifications.

    All methods are pure functions (no side effects, no I/O).
    """

    # ------------------------------------------------------------------
    # Tier 1 — Calendar-driven
    # ------------------------------------------------------------------

    def generate_calendar_notifications(
        self,
        tax_saving_3a: float,
        today: Optional[date] = None,
    ) -> List[ScheduledNotification]:
        """Generate Tier 1 calendar-driven notifications for the current year.

        Schedule:
            - Oct 1: "Il reste 92 jours pour verser sur ton 3a."
            - Nov 1: "Il reste 61 jours. Economie estimee : CHF {tax_saving_3a}."
            - Dec 1: "Dernier mois pour ton 3a. CHF {tax_saving_3a} d'economie en jeu."
            - Dec 20: "11 jours. Dernier rappel 3a."
            - Jan 5 (next year): "Nouveaux plafonds {year+1}. Ton economie potentielle a change."
            - Monthly on 1st: "Ton check-in mensuel est disponible."

        Args:
            tax_saving_3a: Estimated tax saving from maxing 3a (CHF).
            today: Override for current date (default: date.today()).

        Returns:
            List of ScheduledNotification sorted by scheduled_date.
        """
        if today is None:
            today = date.today()

        year = today.year
        chf_saving = _format_chf(tax_saving_3a)
        notifications: List[ScheduledNotification] = []

        # --- 3a deadline reminders ---
        oct1 = date(year, 10, 1)
        dec31 = date(year, 12, 31)
        days_oct1 = (dec31 - oct1).days  # 91-92 depending on leap year

        notifications.append(
            ScheduledNotification(
                category=NotificationCategory.three_a_deadline,
                tier=NotificationTier.calendar,
                title="Rappel 3a \u2014 fin d\u2019annee",
                body=(
                    f"Il reste {days_oct1} jours pour ton 3a. "
                    f"Economie estimee : CHF {chf_saving}."
                ),
                deeplink="/3a",
                scheduled_date=oct1,
                personal_number=f"CHF {chf_saving}",
                time_reference=f"{days_oct1} jours",
            )
        )

        nov1 = date(year, 11, 1)
        days_nov1 = (dec31 - nov1).days

        notifications.append(
            ScheduledNotification(
                category=NotificationCategory.three_a_deadline,
                tier=NotificationTier.calendar,
                title="3a — 2 mois restants",
                body=(
                    f"Il reste {days_nov1} jours. "
                    f"Economie estimee : CHF {chf_saving}."
                ),
                deeplink="/3a",
                scheduled_date=nov1,
                personal_number=f"CHF {chf_saving}",
                time_reference=f"{days_nov1} jours",
            )
        )

        dec1 = date(year, 12, 1)
        days_dec1 = (dec31 - dec1).days

        notifications.append(
            ScheduledNotification(
                category=NotificationCategory.three_a_deadline,
                tier=NotificationTier.calendar,
                title="3a — dernier mois",
                body=(
                    f"Dernier mois pour ton 3a. "
                    f"CHF {chf_saving} d\u2019economie en jeu. "
                    f"{days_dec1} jours restants."
                ),
                deeplink="/3a",
                scheduled_date=dec1,
                personal_number=f"CHF {chf_saving}",
                time_reference=f"{days_dec1} jours",
            )
        )

        dec20 = date(year, 12, 20)
        days_dec20 = (dec31 - dec20).days

        notifications.append(
            ScheduledNotification(
                category=NotificationCategory.three_a_deadline,
                tier=NotificationTier.calendar,
                title="Dernier rappel 3a",
                body=(
                    f"{days_dec20} jours. Dernier rappel 3a. "
                    f"CHF {chf_saving} d\u2019economie potentielle."
                ),
                deeplink="/3a",
                scheduled_date=dec20,
                personal_number=f"CHF {chf_saving}",
                time_reference=f"{days_dec20} jours",
            )
        )

        # --- New year plafonds ---
        jan5 = date(year + 1, 1, 5)
        notifications.append(
            ScheduledNotification(
                category=NotificationCategory.new_year_plafonds,
                tier=NotificationTier.calendar,
                title=f"Plafonds {year + 1}",
                body=(
                    f"Nouveaux plafonds {year + 1}. "
                    f"Ton economie potentielle a change. "
                    f"Plafond 3a : CHF 7\u2019258."
                ),
                deeplink="/3a",
                scheduled_date=jan5,
                personal_number="CHF 7\u2019258",
                time_reference=str(year + 1),
            )
        )

        # --- Monthly check-in (12 months) ---
        for month in range(1, 13):
            first_of_month = date(year, month, 1)
            month_names = [
                "",
                "janvier",
                "fevrier",
                "mars",
                "avril",
                "mai",
                "juin",
                "juillet",
                "aout",
                "septembre",
                "octobre",
                "novembre",
                "decembre",
            ]
            notifications.append(
                ScheduledNotification(
                    category=NotificationCategory.monthly_check_in,
                    tier=NotificationTier.calendar,
                    title=f"Check-in {month_names[month]}",
                    body=(
                        f"Ton check-in mensuel est disponible. "
                        f"Mois de {month_names[month]} {year}."
                    ),
                    deeplink="/check-in",
                    scheduled_date=first_of_month,
                    personal_number=f"{month}/12",
                    time_reference=f"{month_names[month]} {year}",
                )
            )

        # Sort by date
        notifications.sort(key=lambda n: n.scheduled_date)
        return notifications

    # ------------------------------------------------------------------
    # Tier 2 — Event-driven
    # ------------------------------------------------------------------

    def generate_event_notifications(
        self,
        fri_delta: float = 0.0,
        profile_updated: bool = False,
        check_in_completed: bool = False,
    ) -> List[ScheduledNotification]:
        """Generate Tier 2 event-driven notifications.

        Triggers:
            - check_in completed -> delta display
            - profile updated -> new projections available
            - FRI improved -> delta points

        Args:
            fri_delta: Change in FRI score since last check-in.
            profile_updated: Whether the profile was just updated.
            check_in_completed: Whether a check-in was just completed.

        Returns:
            List of ScheduledNotification (may be empty).
        """
        today = date.today()
        notifications: List[ScheduledNotification] = []

        if check_in_completed and fri_delta != 0.0:
            sign = "+" if fri_delta > 0 else ""
            notifications.append(
                ScheduledNotification(
                    category=NotificationCategory.fri_improvement,
                    tier=NotificationTier.event,
                    title="Resultat du check-in",
                    body=(
                        f"Depuis ton dernier check-in : "
                        f"{sign}{fri_delta:.1f} points sur ton score de solidite."
                    ),
                    deeplink="/dashboard",
                    scheduled_date=today,
                    personal_number=f"{sign}{fri_delta:.1f} points",
                    time_reference="dernier check-in",
                )
            )
        elif check_in_completed and fri_delta == 0.0:
            notifications.append(
                ScheduledNotification(
                    category=NotificationCategory.fri_improvement,
                    tier=NotificationTier.event,
                    title="Check-in termine",
                    body=(
                        "Check-in termine. Ton score de solidite "
                        "est stable depuis le dernier check-in."
                    ),
                    deeplink="/dashboard",
                    scheduled_date=today,
                    personal_number="0 point",
                    time_reference="dernier check-in",
                )
            )

        if profile_updated:
            notifications.append(
                ScheduledNotification(
                    category=NotificationCategory.profile_update,
                    tier=NotificationTier.event,
                    title="Profil mis a jour",
                    body=(
                        "Ton profil a ete mis a jour. "
                        "Nouvelles projections disponibles des maintenant."
                    ),
                    deeplink="/dashboard",
                    scheduled_date=today,
                    personal_number="1 mise a jour",
                    time_reference="maintenant",
                )
            )

        if fri_delta > 0 and not check_in_completed:
            notifications.append(
                ScheduledNotification(
                    category=NotificationCategory.fri_improvement,
                    tier=NotificationTier.event,
                    title="Progression FRI",
                    body=(
                        f"Ta solidite a progresse de {fri_delta:.1f} points "
                        f"depuis la derniere evaluation."
                    ),
                    deeplink="/dashboard",
                    scheduled_date=today,
                    personal_number=f"+{fri_delta:.1f} points",
                    time_reference="derniere evaluation",
                )
            )

        return notifications
