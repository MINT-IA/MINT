"""
Notifications & Milestones endpoints — Sprint S36.

POST /api/v1/notifications/calendar    — Generate calendar-driven notifications
POST /api/v1/notifications/events      — Generate event-driven notifications
POST /api/v1/notifications/milestones  — Detect newly crossed milestones

Sources:
    - OPP3 art. 7 (plafond 3a)
    - LPP art. 79b (rachat LPP)
    - LSFin art. 3 (obligation d'information)
"""

from fastapi import APIRouter, Request

from app.core.rate_limit import limiter

from app.schemas.notifications import (
    CalendarNotificationRequest,
    CalendarNotificationsResponse,
    EventNotificationRequest,
    EventNotificationsResponse,
    MilestoneCheckRequest,
    MilestoneCheckResponse,
    MilestoneResponse,
    ScheduledNotificationResponse,
)
from app.services.notifications import (
    MilestoneDetectionService,
    NotificationSchedulerService,
)

router = APIRouter()

_scheduler = NotificationSchedulerService()
_milestone_detector = MilestoneDetectionService()


def _notif_to_response(notif) -> ScheduledNotificationResponse:
    """Convert a ScheduledNotification dataclass to Pydantic response."""
    return ScheduledNotificationResponse(
        category=notif.category.value,
        tier=notif.tier.value,
        title=notif.title,
        body=notif.body,
        deeplink=notif.deeplink,
        scheduled_date=notif.scheduled_date,
        personal_number=notif.personal_number,
        time_reference=notif.time_reference,
    )


def _milestone_to_response(ms) -> MilestoneResponse:
    """Convert a DetectedMilestone dataclass to Pydantic response."""
    return MilestoneResponse(
        milestone_type=ms.milestone_type.value,
        celebration_text=ms.celebration_text,
        concrete_value=ms.concrete_value,
        detected_at=ms.detected_at,
    )


@router.post("/calendar", response_model=CalendarNotificationsResponse)
@limiter.limit("30/minute")
def generate_calendar_notifications(
    request: Request,
    body: CalendarNotificationRequest,
) -> CalendarNotificationsResponse:
    """Generer les notifications calendaires (Tier 1).

    Planifie les rappels 3a, check-ins mensuels, et plafonds de nouvelle annee
    en fonction de l'economie fiscale estimee.

    Returns:
        CalendarNotificationsResponse avec la liste des notifications.
    """
    notifications = _scheduler.generate_calendar_notifications(
        tax_saving_3a=body.tax_saving_3a,
        today=body.today,
    )
    return CalendarNotificationsResponse(
        notifications=[_notif_to_response(n) for n in notifications],
        count=len(notifications),
    )


@router.post("/events", response_model=EventNotificationsResponse)
@limiter.limit("30/minute")
def generate_event_notifications(
    request: Request,
    body: EventNotificationRequest,
) -> EventNotificationsResponse:
    """Generer les notifications evenementielles (Tier 2).

    Declenchees par un check-in complete, une mise a jour du profil,
    ou une amelioration du score FRI.

    Returns:
        EventNotificationsResponse avec la liste des notifications.
    """
    notifications = _scheduler.generate_event_notifications(
        fri_delta=body.fri_delta,
        profile_updated=body.profile_updated,
        check_in_completed=body.check_in_completed,
    )
    return EventNotificationsResponse(
        notifications=[_notif_to_response(n) for n in notifications],
        count=len(notifications),
    )


@router.post("/milestones", response_model=MilestoneCheckResponse)
@limiter.limit("30/minute")
def check_milestones(
    request: Request,
    body: MilestoneCheckRequest,
) -> MilestoneCheckResponse:
    """Detecter les milestones nouvellement franchis.

    Compare le snapshot actuel au snapshot precedent et retourne
    les milestones qui viennent d'etre atteints.

    Returns:
        MilestoneCheckResponse avec la liste des milestones detectes.
    """
    result = _milestone_detector.detect_milestones(
        current=body.current_snapshot,
        previous=body.previous_snapshot,
        check_in_streak=body.check_in_streak,
        arbitrage_count=body.arbitrage_count,
    )
    return MilestoneCheckResponse(
        new_milestones=[_milestone_to_response(m) for m in result.new_milestones],
        count=len(result.new_milestones),
        disclaimer=result.disclaimer,
        sources=result.sources,
    )
