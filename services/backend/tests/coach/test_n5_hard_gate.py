"""Phase 11 / VOICE-09: N5 hard gate tests.

Asserts the rolling 7-day cap is enforced server-side, deterministically,
without re-LLM calls (template-level downgrade per CONTEXT D-05).
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.services.coach.claude_coach_service import (
    N5_DOWNGRADE_TARGET,
    N5_LEVEL,
    N5_MAX_PER_WINDOW,
    N5_WINDOW_DAYS,
    downgrade_n5_if_capped,
    n5_count_for_profile,
    purge_stale_n5_marks,
    register_n5_emission,
)


@pytest.fixture
def now():
    return datetime(2026, 4, 7, 12, 0, 0, tzinfo=timezone.utc)


# ---------------------------------------------------------------------------
# downgrade_n5_if_capped — pure decision function
# ---------------------------------------------------------------------------

class TestDowngradeDecision:
    def test_n5_with_zero_count_passes_through(self):
        assert downgrade_n5_if_capped(N5_LEVEL, 0) == N5_LEVEL

    def test_n5_with_count_at_cap_downgrades_to_n4(self):
        assert downgrade_n5_if_capped(N5_LEVEL, 1) == N5_DOWNGRADE_TARGET

    def test_n5_with_count_above_cap_still_downgrades(self):
        # Should remain idempotent at higher counts.
        assert downgrade_n5_if_capped(N5_LEVEL, 5) == N5_DOWNGRADE_TARGET

    def test_n4_never_downgraded(self):
        assert downgrade_n5_if_capped(4, 99) == 4

    def test_n3_never_downgraded(self):
        assert downgrade_n5_if_capped(3, 99) == 3

    def test_n1_never_downgraded(self):
        assert downgrade_n5_if_capped(1, 99) == 1


# ---------------------------------------------------------------------------
# purge_stale_n5_marks — rolling window enforcement
# ---------------------------------------------------------------------------

class TestPurgeStaleMarks:
    def test_empty_in_empty_out(self, now):
        assert purge_stale_n5_marks([], now=now) == []

    def test_recent_mark_kept(self, now):
        recent = (now - timedelta(days=2)).isoformat()
        assert purge_stale_n5_marks([recent], now=now) == [recent]

    def test_mark_at_exact_boundary_dropped(self, now):
        # Cutoff is now - 7d; anything strictly older is dropped.
        # Use 7d + 1s to be safely outside the window.
        old = (now - timedelta(days=N5_WINDOW_DAYS, seconds=1)).isoformat()
        assert purge_stale_n5_marks([old], now=now) == []

    def test_mixed_marks_only_recent_kept(self, now):
        recent = (now - timedelta(days=1)).isoformat()
        old = (now - timedelta(days=30)).isoformat()
        result = purge_stale_n5_marks([recent, old], now=now)
        assert recent in result
        assert old not in result

    def test_malformed_marks_silently_dropped(self, now):
        recent = (now - timedelta(days=1)).isoformat()
        result = purge_stale_n5_marks(["not-a-date", recent, ""], now=now)
        assert result == [recent]


# ---------------------------------------------------------------------------
# register_n5_emission — increment ONLY on send path
# ---------------------------------------------------------------------------

class TestRegisterEmission:
    def test_first_emission_yields_count_1(self, now):
        marks = register_n5_emission([], now=now)
        assert n5_count_for_profile(marks, now=now) == 1

    def test_second_emission_yields_count_2(self, now):
        m = register_n5_emission([], now=now)
        m = register_n5_emission(m, now=now)
        assert n5_count_for_profile(m, now=now) == 2

    def test_old_emissions_purged_on_new_register(self, now):
        old = (now - timedelta(days=10)).isoformat()
        m = register_n5_emission([old], now=now)
        # Old mark dropped; only the fresh one remains.
        assert n5_count_for_profile(m, now=now) == 1


# ---------------------------------------------------------------------------
# Replay test — synthetic crisis cluster
# ---------------------------------------------------------------------------

class TestCrisisClusterReplay:
    """Synthetic crisis cluster: 5 user turns each triggering N5.

    Asserts only the FIRST sends as N5; remaining 4 send as N4.
    Validates the round-trip: gate decision → conditional increment.
    """

    def test_five_n5_attempts_one_actual_n5(self, now):
        marks: list[str] = []
        sent_levels: list[int] = []

        for _ in range(5):
            count = n5_count_for_profile(marks, now=now)
            chosen = downgrade_n5_if_capped(N5_LEVEL, count)
            sent_levels.append(chosen)
            # Increment ONLY when the actual emission is N5.
            if chosen == N5_LEVEL:
                marks = register_n5_emission(marks, now=now)

        assert sent_levels.count(N5_LEVEL) == N5_MAX_PER_WINDOW
        assert sent_levels.count(N5_DOWNGRADE_TARGET) == 5 - N5_MAX_PER_WINDOW
        # Counter only ever incremented once.
        assert n5_count_for_profile(marks, now=now) == N5_MAX_PER_WINDOW

    def test_window_boundary_reset_allows_new_n5(self, now):
        # First N5 emitted at t0.
        marks = register_n5_emission([], now=now)
        assert n5_count_for_profile(marks, now=now) == 1
        # Second attempt 2 days later: still capped.
        t1 = now + timedelta(days=2)
        assert downgrade_n5_if_capped(
            N5_LEVEL, n5_count_for_profile(marks, now=t1)
        ) == N5_DOWNGRADE_TARGET
        # Eight days later: window has reset; new N5 allowed.
        t2 = now + timedelta(days=N5_WINDOW_DAYS + 1)
        assert n5_count_for_profile(marks, now=t2) == 0
        assert downgrade_n5_if_capped(
            N5_LEVEL, n5_count_for_profile(marks, now=t2)
        ) == N5_LEVEL

    def test_downgrade_path_does_not_increment(self, now):
        # Pre-load a fresh N5 mark to simulate "already capped".
        marks = register_n5_emission([], now=now)
        before = n5_count_for_profile(marks, now=now)
        chosen = downgrade_n5_if_capped(N5_LEVEL, before)
        # Caller would NOT register on downgrade path:
        if chosen == N5_LEVEL:
            marks = register_n5_emission(marks, now=now)
        after = n5_count_for_profile(marks, now=now)
        assert chosen == N5_DOWNGRADE_TARGET
        assert after == before  # no double-increment
