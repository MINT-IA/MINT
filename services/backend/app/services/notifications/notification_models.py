"""
Data models for the Notifications & Milestones module (Sprint S36).

Covers:
    - NotificationTier: calendar (T1), event (T2), byok (T3)
    - NotificationCategory: 3a deadline, tax, check-in, FRI, profile, plafonds
    - ScheduledNotification: a single notification with personal number + time ref
    - MilestoneType: 14 milestone types (emergency fund, 3a, LPP, FRI, patrimoine, streaks)
    - DetectedMilestone: a milestone that was just crossed
    - MilestoneCheckResult: the output of milestone detection

Sources:
    - OPP3 art. 7 (plafond 3a)
    - LPP art. 79b (rachat LPP)
    - LSFin art. 3 (obligation d'information)
"""

from dataclasses import dataclass, field
from datetime import date, datetime
from enum import Enum
from typing import List


class NotificationTier(str, Enum):
    """Tier determines how the notification is delivered."""

    calendar = "calendar"  # Tier 1: scheduled at app launch
    event = "event"  # Tier 2: triggered on app resume
    byok = "byok"  # Tier 3: LLM-enriched


class NotificationCategory(str, Enum):
    """Category of notification content."""

    three_a_deadline = "three_a_deadline"
    tax_declaration = "tax_declaration"
    monthly_check_in = "monthly_check_in"
    fri_improvement = "fri_improvement"
    profile_update = "profile_update"
    new_year_plafonds = "new_year_plafonds"


@dataclass
class ScheduledNotification:
    """A single notification ready to be displayed or pushed.

    Invariants:
        - title max 60 chars, in French
        - body max 200 chars, must contain personal_number + time_reference
        - deeplink starts with "/"
    """

    category: NotificationCategory
    tier: NotificationTier
    title: str
    body: str
    deeplink: str
    scheduled_date: date
    personal_number: str  # The concrete number included (for audit)
    time_reference: str  # The time reference included (for audit)


class MilestoneType(str, Enum):
    """All recognised milestone types."""

    emergency_fund_3_months = "emergency_fund_3_months"
    emergency_fund_6_months = "emergency_fund_6_months"
    three_a_max_reached = "three_a_max_reached"
    lpp_buyback_completed = "lpp_buyback_completed"
    fri_improved_10_points = "fri_improved_10_points"
    fri_above_50 = "fri_above_50"
    fri_above_70 = "fri_above_70"
    fri_above_85 = "fri_above_85"
    patrimoine_50k = "patrimoine_50k"
    patrimoine_100k = "patrimoine_100k"
    patrimoine_250k = "patrimoine_250k"
    first_arbitrage_completed = "first_arbitrage_completed"
    check_in_streak_6_months = "check_in_streak_6_months"
    check_in_streak_12_months = "check_in_streak_12_months"


@dataclass
class DetectedMilestone:
    """A milestone that the user has just crossed."""

    milestone_type: MilestoneType
    celebration_text: str  # Factual, no banned terms
    concrete_value: str  # The achievement number
    detected_at: datetime = field(default_factory=datetime.now)


@dataclass
class MilestoneCheckResult:
    """Result of comparing two snapshots for milestone detection."""

    new_milestones: List[DetectedMilestone]
    sources: List[str] = field(
        default_factory=lambda: ["LSFin art. 3"]
    )
    disclaimer: str = (
        "Outil educatif simplifie. Ne constitue pas un conseil financier (LSFin)."
    )
