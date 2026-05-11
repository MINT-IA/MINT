"""Phase 96 D-08..D-11 — turn-cap behavioural tests.

Per 96-02-PLAN.md Task 3 <behavior> Tests 1, 6, 7, 9, 10, 11.
Server-side enforcement of the 3-turn cap with ZERO LLM cost at turn 4.

The tests below exercise the module-level helpers directly. The end-
to-end wrapper (_run_narrator_with_gate_and_cap) is exercised through
the Sentry-breadcrumb test file (test_sentry_overflow_breadcrumb.py)
because it requires the FastAPI endpoint closure for `body` and
`session_id` to be bound.
"""
from __future__ import annotations

import pytest

from app.services.coach import turn_cap


@pytest.fixture(autouse=True)
def _reset_counter():
    """Reset the shared dict between tests in this module."""
    turn_cap.reset()
    yield
    turn_cap.reset()


# ---------------------------------------------------------------------------
# Test 1 — TURN_COUNTER starts empty
# ---------------------------------------------------------------------------


def test_turn_counter_initially_empty():
    """Module-level dict is empty when no requests have arrived."""
    assert turn_cap.TURN_COUNTER == {}


# ---------------------------------------------------------------------------
# Test 11 — reset() helper clears the counter
# ---------------------------------------------------------------------------


def test_reset_clears_counter():
    """reset() empties the dict for test isolation."""
    turn_cap.TURN_COUNTER[("session_a", "card_x")] = 2
    turn_cap.reset()
    assert turn_cap.TURN_COUNTER == {}


# ---------------------------------------------------------------------------
# Test 6 — increment helper increments counter and reports old value
# ---------------------------------------------------------------------------


def test_increment_returns_previous_count_and_increments():
    """increment_and_get_previous() reports the count BEFORE the increment.

    This is the value the cap is checked against — at turn 4 the cap-
    enforcement reads ≥3 from this return value before incrementing.
    """
    key = ("session_a", "card_x")
    assert turn_cap.increment_and_get_previous(key) == 0
    assert turn_cap.TURN_COUNTER[key] == 1
    assert turn_cap.increment_and_get_previous(key) == 1
    assert turn_cap.TURN_COUNTER[key] == 2


# ---------------------------------------------------------------------------
# Test 7 — cap-hit predicate
# ---------------------------------------------------------------------------


def test_is_cap_hit_true_when_count_ge_3():
    """is_cap_hit(key) returns True when TURN_COUNTER[key] >= 3."""
    key = ("session_a", "card_x")
    assert turn_cap.is_cap_hit(key) is False  # missing key = 0 = not hit
    turn_cap.TURN_COUNTER[key] = 2
    assert turn_cap.is_cap_hit(key) is False
    turn_cap.TURN_COUNTER[key] = 3
    assert turn_cap.is_cap_hit(key) is True
    turn_cap.TURN_COUNTER[key] = 5  # still hit beyond 3
    assert turn_cap.is_cap_hit(key) is True


# ---------------------------------------------------------------------------
# Test 10 — server-side enforcement ignores client-supplied turn_count
# ---------------------------------------------------------------------------


def test_per_session_per_card_isolation():
    """Different (session, card) keys do NOT bleed into each other."""
    turn_cap.increment_and_get_previous(("session_a", "card_x"))
    turn_cap.increment_and_get_previous(("session_a", "card_y"))
    turn_cap.increment_and_get_previous(("session_b", "card_x"))
    assert turn_cap.TURN_COUNTER[("session_a", "card_x")] == 1
    assert turn_cap.TURN_COUNTER[("session_a", "card_y")] == 1
    assert turn_cap.TURN_COUNTER[("session_b", "card_x")] == 1
    assert turn_cap.is_cap_hit(("session_a", "card_x")) is False
    assert turn_cap.is_cap_hit(("session_a", "card_y")) is False


def test_four_increments_trigger_cap_on_fourth_check():
    """Increment 3 times → 4th request hits the cap (T-96-W2-TurnCountTamper).

    The wrapper's contract : increment BEFORE checking on every PASS, so
    after 3 successful turns the 4th call sees count >= 3 and returns
    the terminal template without incrementing further.
    """
    key = ("session_a", "card_x")
    turn_cap.increment_and_get_previous(key)
    turn_cap.increment_and_get_previous(key)
    turn_cap.increment_and_get_previous(key)
    assert turn_cap.TURN_COUNTER[key] == 3
    # 4th incoming request : pre-call check sees 3 → cap hit.
    assert turn_cap.is_cap_hit(key) is True


# ---------------------------------------------------------------------------
# Test 9 — module-level singleton survives import boundary
# ---------------------------------------------------------------------------


def test_turn_counter_singleton_across_imports():
    """Re-importing the module returns the same dict instance."""
    from app.services.coach import turn_cap as turn_cap_reimport
    assert turn_cap_reimport.TURN_COUNTER is turn_cap.TURN_COUNTER
