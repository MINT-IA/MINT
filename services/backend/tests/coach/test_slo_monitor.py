"""Phase 27-01 / Task 6: SLO monitor tests.

Covers:
  - record_response writes bucket counters
  - check_once aggregates the 5-minute window
  - Two consecutive breaches trigger auto-rollback of COACH_FSM_ENABLED
  - Low-traffic window (< 10 requests) never flags breach
  - Fail-open on Redis outage
"""
from __future__ import annotations

from datetime import datetime, timezone

import pytest

from app.core import redis_client
from app.services import slo_monitor as slo_mod
from app.services.slo_monitor import (
    CONSECUTIVE_BREACHES_TO_ROLLBACK,
    FALLBACK_RATE_THRESHOLD,
    LATENCY_MS_THRESHOLD,
    SLOMonitor,
    record_response,
)


@pytest.fixture
def fake_redis():
    import fakeredis.aioredis as fakeaio
    client = fakeaio.FakeRedis(decode_responses=True)
    redis_client.set_redis_client_for_tests(client)
    yield client
    redis_client.reset_for_tests()


@pytest.mark.asyncio
async def test_record_response_writes_bucket(fake_redis):
    now = datetime(2026, 4, 14, 10, 30, tzinfo=timezone.utc)
    await record_response(degraded=False, fallback=False, latency_ms=100, now=now)
    key = f"coach:metrics:{now.strftime('%Y-%m-%d-%H-%M')}"
    h = await fake_redis.hgetall(key)
    assert int(h["total"]) == 1
    assert int(h["latency_ms_cnt"]) == 1
    assert int(h["latency_ms_sum"]) == 100


@pytest.mark.asyncio
async def test_record_degraded_and_fallback_counters(fake_redis):
    now = datetime(2026, 4, 14, 10, 30, tzinfo=timezone.utc)
    await record_response(degraded=True, fallback=False, latency_ms=200, now=now)
    await record_response(degraded=False, fallback=True, latency_ms=300, now=now)
    key = f"coach:metrics:{now.strftime('%Y-%m-%d-%H-%M')}"
    h = await fake_redis.hgetall(key)
    assert int(h["total"]) == 2
    assert int(h["degraded"]) == 1
    assert int(h["fallback"]) == 1


@pytest.mark.asyncio
async def test_check_once_below_traffic_floor_no_breach(fake_redis):
    now = datetime(2026, 4, 14, 10, 30, tzinfo=timezone.utc)
    # 5 degraded out of 5 — would be 100% but under floor of 10 total.
    for _ in range(5):
        await record_response(degraded=True, fallback=False, latency_ms=100, now=now)

    mon = SLOMonitor()
    metrics = await mon.check_once(now=now)
    assert metrics["total"] == 5
    assert mon._breach_streak == 0


@pytest.mark.asyncio
async def test_single_breach_does_not_rollback(fake_redis):
    now = datetime(2026, 4, 14, 10, 30, tzinfo=timezone.utc)
    # 15 total, 3 degraded → 20% → above 5% threshold.
    for _ in range(12):
        await record_response(degraded=False, fallback=False, latency_ms=100, now=now)
    for _ in range(3):
        await record_response(degraded=True, fallback=False, latency_ms=100, now=now)

    mon = SLOMonitor()
    await mon.check_once(now=now)
    # Flag should NOT be rolled back after a single breach.
    from app.services.flags_service import flags
    assert mon._breach_streak == 1
    assert await flags.is_enabled("COACH_FSM_ENABLED") is False  # default off is fine


@pytest.mark.asyncio
async def test_two_consecutive_breaches_trigger_rollback(fake_redis):
    now = datetime(2026, 4, 14, 10, 30, tzinfo=timezone.utc)
    from app.services.flags_service import flags
    await flags.set_global("COACH_FSM_ENABLED", True)
    assert await flags.is_enabled("COACH_FSM_ENABLED") is True

    # Make sure traffic + breach condition holds.
    for _ in range(12):
        await record_response(degraded=False, fallback=False, latency_ms=100, now=now)
    for _ in range(3):
        await record_response(degraded=True, fallback=False, latency_ms=100, now=now)

    mon = SLOMonitor()
    for _ in range(CONSECUTIVE_BREACHES_TO_ROLLBACK):
        await mon.check_once(now=now)

    assert await flags.is_enabled("COACH_FSM_ENABLED") is False


@pytest.mark.asyncio
async def test_latency_breach_also_rolls_back(fake_redis):
    now = datetime(2026, 4, 14, 10, 30, tzinfo=timezone.utc)
    from app.services.flags_service import flags
    await flags.set_global("COACH_FSM_ENABLED", True)

    # 15 requests all very slow → avg latency well above threshold.
    for _ in range(15):
        await record_response(
            degraded=False, fallback=False,
            latency_ms=int(LATENCY_MS_THRESHOLD + 2000), now=now,
        )

    mon = SLOMonitor()
    for _ in range(CONSECUTIVE_BREACHES_TO_ROLLBACK):
        await mon.check_once(now=now)
    assert await flags.is_enabled("COACH_FSM_ENABLED") is False


@pytest.mark.asyncio
async def test_fail_open_when_redis_unavailable():
    redis_client.reset_for_tests()
    redis_client._initialized = True
    redis_client._client = None
    # Should not raise
    await record_response(degraded=True, fallback=False, latency_ms=1000)
    mon = SLOMonitor()
    metrics = await mon.check_once()
    assert metrics["total"] == 0
    redis_client.reset_for_tests()


@pytest.mark.asyncio
async def test_breach_streak_resets_on_healthy_window(fake_redis):
    now = datetime(2026, 4, 14, 10, 30, tzinfo=timezone.utc)
    for _ in range(12):
        await record_response(degraded=False, fallback=False, latency_ms=100, now=now)
    for _ in range(3):
        await record_response(degraded=True, fallback=False, latency_ms=100, now=now)
    mon = SLOMonitor()
    await mon.check_once(now=now)
    assert mon._breach_streak == 1

    # Now a healthy minute
    later = datetime(2026, 4, 14, 10, 31, tzinfo=timezone.utc)
    for _ in range(20):
        await record_response(degraded=False, fallback=False, latency_ms=100, now=later)
    await mon.check_once(now=later)
    assert mon._breach_streak == 0
