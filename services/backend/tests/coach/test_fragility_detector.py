"""Phase 11 / VOICE-10: Fragility detector tests."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.services.coach.fragility_detector_service import (
    FRAGILE_MODE_DURATION_DAYS,
    FRAGILE_TRIGGER_COUNT,
    FRAGILE_TRIGGER_WINDOW_DAYS,
    MAX_LEVEL_WHILE_FRAGILE,
    check_and_update,
    clamp_level_if_fragile,
    is_currently_fragile,
)


@pytest.fixture
def now():
    return datetime(2026, 4, 7, 12, 0, 0, tzinfo=timezone.utc)


def _ev(ts: datetime, gravity: str) -> dict:
    return {"ts": ts.isoformat(), "gravity": gravity}


# ---------------------------------------------------------------------------
# Trigger window: ≥3 G2/G3 in 14 days
# ---------------------------------------------------------------------------

class TestTrigger:
    def test_two_events_no_trigger(self, now):
        events = [
            _ev(now - timedelta(days=10), "G2"),
        ]
        r = check_and_update(events, None, _ev(now, "G3"), now=now)
        assert r.is_fragile is False
        assert r.entered_now is False
        assert r.fragile_entered_at is None

    def test_three_g2g3_in_14d_triggers(self, now):
        events = [
            _ev(now - timedelta(days=12), "G2"),
            _ev(now - timedelta(days=5), "G3"),
        ]
        r = check_and_update(events, None, _ev(now, "G2"), now=now)
        assert r.is_fragile is True
        assert r.entered_now is True
        assert r.fragile_entered_at == now

    def test_g1_events_do_not_count(self, now):
        events = [
            _ev(now - timedelta(days=1), "G1"),
            _ev(now - timedelta(days=2), "G1"),
        ]
        r = check_and_update(events, None, _ev(now, "G1"), now=now)
        assert r.is_fragile is False
        assert r.entered_now is False

    def test_old_event_outside_14d_window_does_not_count(self, now):
        # Day 0 G2, day 5 G2, day 20 G2 — only the day 20 + day 5 inside window;
        # day 0 falls outside the 14-day window seen from day 20.
        events = [
            _ev(now - timedelta(days=20), "G2"),
            _ev(now - timedelta(days=15), "G2"),
        ]
        r = check_and_update(events, None, _ev(now, "G2"), now=now)
        assert r.is_fragile is False  # only 1 event inside the 14d window

    def test_already_fragile_no_duplicate_entry(self, now):
        prior_entry = now - timedelta(days=2)
        events = [
            _ev(now - timedelta(days=10), "G2"),
            _ev(now - timedelta(days=5), "G3"),
            _ev(now - timedelta(days=2), "G2"),
        ]
        r = check_and_update(events, prior_entry, _ev(now, "G3"), now=now)
        assert r.is_fragile is True
        assert r.entered_now is False  # already fragile
        assert r.fragile_entered_at == prior_entry  # timer not reset


# ---------------------------------------------------------------------------
# Expiry: 30-day mode duration
# ---------------------------------------------------------------------------

class TestExpiry:
    def test_within_30d_still_fragile(self, now):
        entered = now - timedelta(days=15)
        assert is_currently_fragile(entered, now=now) is True

    def test_at_30d_expired(self, now):
        entered = now - timedelta(days=FRAGILE_MODE_DURATION_DAYS, seconds=1)
        assert is_currently_fragile(entered, now=now) is False

    def test_after_31d_expired(self, now):
        entered = now - timedelta(days=31)
        assert is_currently_fragile(entered, now=now) is False

    def test_none_never_fragile(self, now):
        assert is_currently_fragile(None, now=now) is False


# ---------------------------------------------------------------------------
# Level clamp
# ---------------------------------------------------------------------------

class TestClampLevel:
    def test_clamp_n5_to_n3_when_fragile(self, now):
        entered = now - timedelta(days=5)
        assert clamp_level_if_fragile(5, entered, now=now) == MAX_LEVEL_WHILE_FRAGILE

    def test_clamp_n4_to_n3_when_fragile(self, now):
        entered = now - timedelta(days=5)
        assert clamp_level_if_fragile(4, entered, now=now) == MAX_LEVEL_WHILE_FRAGILE

    def test_n3_unchanged_when_fragile(self, now):
        entered = now - timedelta(days=5)
        assert clamp_level_if_fragile(3, entered, now=now) == 3

    def test_n2_unchanged_when_fragile(self, now):
        entered = now - timedelta(days=5)
        assert clamp_level_if_fragile(2, entered, now=now) == 2

    def test_no_clamp_when_not_fragile(self, now):
        assert clamp_level_if_fragile(5, None, now=now) == 5

    def test_no_clamp_after_expiry(self, now):
        entered = now - timedelta(days=40)
        assert clamp_level_if_fragile(5, entered, now=now) == 5


# ---------------------------------------------------------------------------
# Replay test — synthetic stress cluster
# ---------------------------------------------------------------------------

class TestStressClusterReplay:
    def test_job_loss_divorce_debt_triggers_at_day_12(self, now):
        # Day 0: job_loss G2
        # Day 5: divorce_turn G3
        # Day 12: debt_crisis G2
        day0 = now
        day5 = now + timedelta(days=5)
        day12 = now + timedelta(days=12)

        # Step 1: G2 at day 0
        r1 = check_and_update([], None, _ev(day0, "G2"), now=day0)
        assert r1.is_fragile is False

        # Step 2: G3 at day 5
        r2 = check_and_update(r1.events, r1.fragile_entered_at, _ev(day5, "G3"), now=day5)
        assert r2.is_fragile is False

        # Step 3: G2 at day 12 → trigger
        r3 = check_and_update(r2.events, r2.fragile_entered_at, _ev(day12, "G2"), now=day12)
        assert r3.is_fragile is True
        assert r3.entered_now is True
        assert r3.fragile_entered_at == day12

    def test_day_43_fragile_expired(self, now):
        # User entered fragile mode at day 12; check at day 43 (entered + 31).
        entered = now + timedelta(days=12)
        day43 = entered + timedelta(days=31)
        assert is_currently_fragile(entered, now=day43) is False
        # Level cap lifts.
        assert clamp_level_if_fragile(5, entered, now=day43) == 5

    def test_event_log_purges_to_30d(self, now):
        # Old event > 30d should be dropped on next check.
        events = [_ev(now - timedelta(days=45), "G3")]
        r = check_and_update(events, None, _ev(now, "G2"), now=now)
        # Only the new event survives.
        assert len(r.events) == 1
        assert r.events[0]["gravity"] == "G2"

    def test_trigger_constants_match_spec(self):
        assert FRAGILE_TRIGGER_COUNT == 3
        assert FRAGILE_TRIGGER_WINDOW_DAYS == 14
        assert FRAGILE_MODE_DURATION_DAYS == 30
        assert MAX_LEVEL_WHILE_FRAGILE == 3
