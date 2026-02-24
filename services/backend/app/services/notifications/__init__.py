"""
Notifications & Milestones module — Sprint S36.

Exports:
    - NotificationSchedulerService: calendar & event notification generator
    - MilestoneDetectionService: milestone detection by snapshot comparison
    - Data models: NotificationTier, NotificationCategory, ScheduledNotification,
      MilestoneType, DetectedMilestone, MilestoneCheckResult
"""

from app.services.notifications.notification_models import (
    DetectedMilestone,
    MilestoneCheckResult,
    MilestoneType,
    NotificationCategory,
    NotificationTier,
    ScheduledNotification,
)
from app.services.notifications.notification_scheduler_service import (
    NotificationSchedulerService,
)
from app.services.notifications.milestone_detection_service import (
    MilestoneDetectionService,
)

__all__ = [
    "NotificationSchedulerService",
    "MilestoneDetectionService",
    "NotificationTier",
    "NotificationCategory",
    "ScheduledNotification",
    "MilestoneType",
    "DetectedMilestone",
    "MilestoneCheckResult",
]
