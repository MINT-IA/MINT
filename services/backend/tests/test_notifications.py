"""
Tests for Notifications & Milestones module — Sprint S36.

Covers:
    - Calendar notifications (Tier 1): correct dates, personal numbers, deeplinks
    - Event notifications (Tier 2): delta display, profile update, check-in completed
    - Milestone detection: each milestone type, no false positives, compliance
    - Wording compliance: no banned terms, no social comparison, no prescriptive language
    - API endpoints: POST calendar, events, milestones

Sources:
    - OPP3 art. 7 (plafond 3a : 7'258 CHF)
    - LPP art. 79b (rachat LPP)
    - LSFin art. 3 (obligation d'information)
"""

from datetime import date

from fastapi.testclient import TestClient

from app.main import app
from app.services.notifications.milestone_detection_service import (
    MilestoneDetectionService,
)
from app.services.notifications.notification_models import (
    MilestoneType,
    NotificationCategory,
    NotificationTier,
)
from app.services.notifications.notification_scheduler_service import (
    NotificationSchedulerService,
)

client = TestClient(app)

BANNED_TERMS = [
    "garanti",
    "certain",
    "assur\u00e9",
    "sans risque",
    "optimal",
    "meilleur",
    "parfait",
    "conseiller",
    "tu devrais",
    "tu dois",
    "il faut que tu",
]


# ===========================================================================
# Calendar Notifications (Tier 1)
# ===========================================================================


class TestCalendarNotifications:
    """Tests for calendar-driven notification generation."""

    def setup_method(self):
        self.svc = NotificationSchedulerService()

    def test_generates_17_notifications(self):
        """Should produce 5 3a/plafond + 12 monthly check-ins = 17 total."""
        result = self.svc.generate_calendar_notifications(
            tax_saving_3a=1820.0, today=date(2026, 1, 15)
        )
        assert len(result) == 17

    def test_3a_oct1_contains_days_and_chf(self):
        """Oct 1 notification must mention days remaining and CHF amount."""
        result = self.svc.generate_calendar_notifications(
            tax_saving_3a=1820.0, today=date(2026, 1, 1)
        )
        oct_notifs = [
            n
            for n in result
            if n.scheduled_date == date(2026, 10, 1)
            and n.category == NotificationCategory.three_a_deadline
        ]
        assert len(oct_notifs) == 1
        n = oct_notifs[0]
        assert "jours" in n.body
        assert "1\u2019820" in n.body
        assert n.deeplink == "/pilier-3a"
        assert n.tier == NotificationTier.calendar

    def test_3a_dec20_last_reminder(self):
        """Dec 20 notification should be the last 3a reminder."""
        result = self.svc.generate_calendar_notifications(
            tax_saving_3a=500.0, today=date(2026, 1, 1)
        )
        dec20_notifs = [
            n
            for n in result
            if n.scheduled_date == date(2026, 12, 20)
            and n.category == NotificationCategory.three_a_deadline
        ]
        assert len(dec20_notifs) == 1
        assert "11 jours" in dec20_notifs[0].body

    def test_jan5_new_year_plafonds(self):
        """Jan 5 notification should mention new year plafonds."""
        result = self.svc.generate_calendar_notifications(
            tax_saving_3a=0.0, today=date(2026, 1, 1)
        )
        jan5_notifs = [
            n
            for n in result
            if n.scheduled_date == date(2027, 1, 5)
            and n.category == NotificationCategory.new_year_plafonds
        ]
        assert len(jan5_notifs) == 1
        n = jan5_notifs[0]
        assert "2027" in n.body
        assert "7\u2019258" in n.body

    def test_monthly_check_ins_all_12_months(self):
        """Should have exactly 12 monthly check-in notifications."""
        result = self.svc.generate_calendar_notifications(
            tax_saving_3a=1000.0, today=date(2026, 6, 15)
        )
        check_ins = [
            n for n in result if n.category == NotificationCategory.monthly_check_in
        ]
        assert len(check_ins) == 12

    def test_all_notifications_have_deeplink(self):
        """Every notification must have a non-empty deeplink starting with /."""
        result = self.svc.generate_calendar_notifications(
            tax_saving_3a=2000.0, today=date(2026, 3, 1)
        )
        for n in result:
            assert n.deeplink.startswith("/"), f"Missing deeplink on {n.category}"

    def test_all_notifications_have_personal_number(self):
        """Every notification must have a non-empty personal_number."""
        result = self.svc.generate_calendar_notifications(
            tax_saving_3a=1500.0, today=date(2026, 1, 1)
        )
        for n in result:
            assert len(n.personal_number) > 0, f"Missing personal_number on {n.category}"

    def test_all_notifications_have_time_reference(self):
        """Every notification must have a non-empty time_reference."""
        result = self.svc.generate_calendar_notifications(
            tax_saving_3a=1500.0, today=date(2026, 1, 1)
        )
        for n in result:
            assert len(n.time_reference) > 0, f"Missing time_reference on {n.category}"

    def test_sorted_by_date(self):
        """Notifications must be sorted chronologically."""
        result = self.svc.generate_calendar_notifications(
            tax_saving_3a=1000.0, today=date(2026, 1, 1)
        )
        dates = [n.scheduled_date for n in result]
        assert dates == sorted(dates)

    def test_chf_formatting_large_amount(self):
        """Large CHF amounts should use Swiss apostrophe formatting."""
        result = self.svc.generate_calendar_notifications(
            tax_saving_3a=12345.0, today=date(2026, 1, 1)
        )
        # Find Oct 1 notification
        oct_notif = [
            n for n in result if n.scheduled_date == date(2026, 10, 1)
            and n.category == NotificationCategory.three_a_deadline
        ][0]
        assert "12\u2019345" in oct_notif.body


# ===========================================================================
# Event Notifications (Tier 2)
# ===========================================================================


class TestEventNotifications:
    """Tests for event-driven notification generation."""

    def setup_method(self):
        self.svc = NotificationSchedulerService()

    def test_check_in_with_positive_delta(self):
        """Check-in completed with positive FRI delta shows +X.X points."""
        result = self.svc.generate_event_notifications(
            fri_delta=5.2, check_in_completed=True
        )
        assert len(result) >= 1
        n = result[0]
        assert "+5.2" in n.body
        assert n.category == NotificationCategory.fri_improvement
        assert n.tier == NotificationTier.event

    def test_check_in_with_negative_delta(self):
        """Check-in completed with negative FRI delta shows -X.X points."""
        result = self.svc.generate_event_notifications(
            fri_delta=-3.0, check_in_completed=True
        )
        assert len(result) >= 1
        assert "-3.0" in result[0].body

    def test_check_in_with_zero_delta(self):
        """Check-in with no change should say score is stable."""
        result = self.svc.generate_event_notifications(
            fri_delta=0.0, check_in_completed=True
        )
        assert len(result) >= 1
        assert "stable" in result[0].body.lower()

    def test_profile_updated(self):
        """Profile update should generate notification about new projections."""
        result = self.svc.generate_event_notifications(profile_updated=True)
        assert len(result) >= 1
        assert "profil" in result[0].body.lower()
        assert "projections" in result[0].body.lower()
        assert result[0].deeplink == "/home?tab=0"

    def test_fri_improvement_without_check_in(self):
        """FRI improvement without check-in should generate a separate notification."""
        result = self.svc.generate_event_notifications(
            fri_delta=8.5, check_in_completed=False
        )
        assert len(result) >= 1
        assert "8.5" in result[0].body

    def test_no_events_returns_empty(self):
        """No events triggered should return empty list."""
        result = self.svc.generate_event_notifications(
            fri_delta=0.0, profile_updated=False, check_in_completed=False
        )
        assert len(result) == 0

    def test_negative_fri_without_check_in_no_notification(self):
        """Negative FRI without check-in should not generate notification."""
        result = self.svc.generate_event_notifications(
            fri_delta=-2.0, check_in_completed=False
        )
        assert len(result) == 0

    def test_multiple_events_combined(self):
        """Multiple events should generate multiple notifications."""
        result = self.svc.generate_event_notifications(
            fri_delta=5.0, profile_updated=True, check_in_completed=True
        )
        assert len(result) >= 2


# ===========================================================================
# Milestone Detection
# ===========================================================================


class TestMilestoneDetection:
    """Tests for milestone detection by snapshot comparison."""

    def setup_method(self):
        self.svc = MilestoneDetectionService()

    def test_emergency_fund_3_months(self):
        """Should detect 3-month emergency fund milestone."""
        result = self.svc.detect_milestones(
            current={"months_liquidity": 3.2},
            previous={"months_liquidity": 2.5},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.emergency_fund_3_months in types

    def test_emergency_fund_6_months(self):
        """Should detect 6-month emergency fund milestone."""
        result = self.svc.detect_milestones(
            current={"months_liquidity": 6.5},
            previous={"months_liquidity": 5.8},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.emergency_fund_6_months in types

    def test_emergency_fund_both_3_and_6_in_single_jump(self):
        """Jumping from 1 to 7 months should trigger both 3 and 6 month milestones."""
        result = self.svc.detect_milestones(
            current={"months_liquidity": 7.0},
            previous={"months_liquidity": 1.0},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.emergency_fund_3_months in types
        assert MilestoneType.emergency_fund_6_months in types

    def test_three_a_max_reached(self):
        """Should detect 3a plafond reached at 7258 CHF."""
        result = self.svc.detect_milestones(
            current={"three_a_contribution": 7258, "tax_saving_3a": 1820},
            previous={"three_a_contribution": 5000},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.three_a_max_reached in types
        # Check celebration text mentions 7'258
        ms = [m for m in result.new_milestones if m.milestone_type == MilestoneType.three_a_max_reached][0]
        assert "7\u2019258" in ms.celebration_text

    def test_lpp_buyback_completed(self):
        """Should detect LPP buyback completion."""
        result = self.svc.detect_milestones(
            current={"lpp_buyback_completed": True},
            previous={"lpp_buyback_completed": False},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.lpp_buyback_completed in types

    def test_fri_improved_10_points(self):
        """Should detect 10-point FRI improvement."""
        result = self.svc.detect_milestones(
            current={"fri_total": 65},
            previous={"fri_total": 50},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.fri_improved_10_points in types

    def test_fri_above_50(self):
        """Should detect FRI crossing 50 threshold."""
        result = self.svc.detect_milestones(
            current={"fri_total": 52},
            previous={"fri_total": 48},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.fri_above_50 in types

    def test_fri_above_70(self):
        """Should detect FRI crossing 70 threshold."""
        result = self.svc.detect_milestones(
            current={"fri_total": 72},
            previous={"fri_total": 68},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.fri_above_70 in types

    def test_fri_above_85(self):
        """Should detect FRI crossing 85 threshold."""
        result = self.svc.detect_milestones(
            current={"fri_total": 87},
            previous={"fri_total": 83},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.fri_above_85 in types

    def test_patrimoine_50k(self):
        """Should detect patrimoine crossing 50k."""
        result = self.svc.detect_milestones(
            current={"patrimoine": 52000},
            previous={"patrimoine": 48000},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.patrimoine_50k in types

    def test_patrimoine_100k(self):
        """Should detect patrimoine crossing 100k."""
        result = self.svc.detect_milestones(
            current={"patrimoine": 105000},
            previous={"patrimoine": 95000},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.patrimoine_100k in types

    def test_patrimoine_250k(self):
        """Should detect patrimoine crossing 250k."""
        result = self.svc.detect_milestones(
            current={"patrimoine": 260000},
            previous={"patrimoine": 240000},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.patrimoine_250k in types

    def test_first_arbitrage_completed(self):
        """Should detect first arbitrage completion."""
        result = self.svc.detect_milestones(
            current={},
            previous={"arbitrage_count": 0},
            arbitrage_count=1,
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.first_arbitrage_completed in types

    def test_check_in_streak_6_months(self):
        """Should detect 6-month check-in streak."""
        result = self.svc.detect_milestones(
            current={},
            previous={"check_in_streak": 5},
            check_in_streak=6,
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.check_in_streak_6_months in types

    def test_check_in_streak_12_months(self):
        """Should detect 12-month check-in streak."""
        result = self.svc.detect_milestones(
            current={},
            previous={"check_in_streak": 11},
            check_in_streak=12,
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.check_in_streak_12_months in types

    def test_no_false_positive_when_already_above_threshold(self):
        """Should NOT detect milestone if already above threshold in previous."""
        result = self.svc.detect_milestones(
            current={"months_liquidity": 4.0},
            previous={"months_liquidity": 3.5},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.emergency_fund_3_months not in types

    def test_no_milestones_on_identical_snapshots(self):
        """Identical snapshots should produce zero milestones."""
        snapshot = {
            "months_liquidity": 2.0,
            "three_a_contribution": 3000,
            "fri_total": 40,
            "patrimoine": 30000,
        }
        result = self.svc.detect_milestones(current=snapshot, previous=snapshot)
        assert len(result.new_milestones) == 0

    def test_empty_snapshots(self):
        """Empty snapshots should produce zero milestones."""
        result = self.svc.detect_milestones(current={}, previous={})
        assert len(result.new_milestones) == 0

    def test_first_snapshot_with_high_values(self):
        """First snapshot (previous empty) with values above thresholds triggers milestones."""
        result = self.svc.detect_milestones(
            current={
                "months_liquidity": 7.0,
                "three_a_contribution": 7258,
                "fri_total": 90,
                "patrimoine": 300000,
            },
            previous={},
        )
        types = [m.milestone_type for m in result.new_milestones]
        assert MilestoneType.emergency_fund_3_months in types
        assert MilestoneType.emergency_fund_6_months in types
        assert MilestoneType.three_a_max_reached in types
        assert MilestoneType.patrimoine_50k in types
        assert MilestoneType.patrimoine_100k in types
        assert MilestoneType.patrimoine_250k in types

    def test_result_has_disclaimer_and_sources(self):
        """MilestoneCheckResult must include disclaimer and sources."""
        result = self.svc.detect_milestones(current={}, previous={})
        assert "LSFin" in result.disclaimer
        assert len(result.sources) > 0


# ===========================================================================
# Wording Compliance
# ===========================================================================


class TestWordingCompliance:
    """Ensure all generated text complies with MINT content rules."""

    def setup_method(self):
        self.scheduler = NotificationSchedulerService()
        self.milestone_svc = MilestoneDetectionService()

    def _check_text_for_banned_terms(self, text: str):
        """Helper to check text does not contain any banned terms."""
        lower = text.lower()
        for term in BANNED_TERMS:
            assert term not in lower, (
                f"Banned term '{term}' found in: {text}"
            )

    def test_calendar_notifications_no_banned_terms(self):
        """Calendar notifications must not contain any banned terms."""
        notifications = self.scheduler.generate_calendar_notifications(
            tax_saving_3a=1500.0, today=date(2026, 6, 1)
        )
        for n in notifications:
            self._check_text_for_banned_terms(n.title)
            self._check_text_for_banned_terms(n.body)

    def test_event_notifications_no_banned_terms(self):
        """Event notifications must not contain any banned terms."""
        notifications = self.scheduler.generate_event_notifications(
            fri_delta=10.0, profile_updated=True, check_in_completed=True
        )
        for n in notifications:
            self._check_text_for_banned_terms(n.title)
            self._check_text_for_banned_terms(n.body)

    def test_milestone_texts_no_banned_terms(self):
        """All milestone celebration texts must not contain banned terms."""
        # Trigger as many milestones as possible
        result = self.milestone_svc.detect_milestones(
            current={
                "months_liquidity": 7.0,
                "three_a_contribution": 7258,
                "tax_saving_3a": 1820,
                "lpp_buyback_completed": True,
                "fri_total": 90,
                "patrimoine": 300000,
            },
            previous={
                "months_liquidity": 0,
                "three_a_contribution": 0,
                "lpp_buyback_completed": False,
                "fri_total": 0,
                "patrimoine": 0,
            },
            check_in_streak=12,
            arbitrage_count=1,
        )
        assert len(result.new_milestones) > 0
        for ms in result.new_milestones:
            self._check_text_for_banned_terms(ms.celebration_text)

    def test_no_social_comparison_in_milestones(self):
        """Milestone texts must not contain social comparison phrases."""
        social_banned = [
            "top 20%",
            "top 10%",
            "mieux que",
            "comparaison",
            "par rapport aux autres",
            "moyenne suisse",
        ]
        result = self.milestone_svc.detect_milestones(
            current={
                "months_liquidity": 7.0,
                "fri_total": 90,
                "patrimoine": 300000,
            },
            previous={},
            check_in_streak=12,
            arbitrage_count=1,
        )
        for ms in result.new_milestones:
            lower = ms.celebration_text.lower()
            for term in social_banned:
                assert term not in lower, (
                    f"Social comparison '{term}' found in: {ms.celebration_text}"
                )

    def test_no_prescriptive_language_in_notifications(self):
        """Notifications must not use prescriptive language."""
        prescriptive = ["tu devrais", "tu dois", "il faut que tu", "verse", "investis"]
        notifications = self.scheduler.generate_calendar_notifications(
            tax_saving_3a=2000.0, today=date(2026, 1, 1)
        )
        for n in notifications:
            lower = n.body.lower()
            for term in prescriptive:
                assert term not in lower, (
                    f"Prescriptive term '{term}' found in: {n.body}"
                )

    def test_title_max_60_chars(self):
        """All notification titles must be max 60 characters."""
        notifications = self.scheduler.generate_calendar_notifications(
            tax_saving_3a=99999.0, today=date(2026, 1, 1)
        )
        for n in notifications:
            assert len(n.title) <= 60, (
                f"Title too long ({len(n.title)} chars): {n.title}"
            )


# ===========================================================================
# API Endpoints
# ===========================================================================


class TestNotificationEndpoints:
    """Test the REST API endpoints for notifications (auth required)."""

    def test_post_calendar(self, client):
        """POST /api/v1/notifications/calendar should return notifications."""
        resp = client.post(
            "/api/v1/notifications/calendar",
            json={"taxSaving3a": 1820.0, "today": "2026-06-01"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["count"] == 17
        assert len(data["notifications"]) == 17
        assert "disclaimer" in data
        assert "sources" in data

    def test_post_events(self, client):
        """POST /api/v1/notifications/events should return event notifications."""
        resp = client.post(
            "/api/v1/notifications/events",
            json={"friDelta": 5.0, "profileUpdated": True, "checkInCompleted": True},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["count"] >= 2

    def test_post_events_empty(self, client):
        """POST /api/v1/notifications/events with no triggers returns empty list."""
        resp = client.post(
            "/api/v1/notifications/events",
            json={},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["count"] == 0
        assert data["notifications"] == []

    def test_post_milestones(self, client):
        """POST /api/v1/notifications/milestones should detect milestones."""
        resp = client.post(
            "/api/v1/notifications/milestones",
            json={
                "currentSnapshot": {"months_liquidity": 3.5, "fri_total": 55},
                "previousSnapshot": {"months_liquidity": 2.0, "fri_total": 45},
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["count"] >= 1
        assert "disclaimer" in data

    def test_post_milestones_empty(self, client):
        """POST /api/v1/notifications/milestones with no change returns empty."""
        resp = client.post(
            "/api/v1/notifications/milestones",
            json={
                "currentSnapshot": {},
                "previousSnapshot": {},
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["count"] == 0

    def test_calendar_camel_case_response(self, client):
        """API response should use camelCase field names."""
        resp = client.post(
            "/api/v1/notifications/calendar",
            json={"taxSaving3a": 500.0, "today": "2026-03-01"},
        )
        data = resp.json()
        n = data["notifications"][0]
        assert "scheduledDate" in n
        assert "personalNumber" in n
        assert "timeReference" in n
