"""SLO-based auto-rollback monitor.

v2.7 Phase 27 / STAB-06.

Writes minute-bucket counters to Redis hash `coach:metrics:{YYYY-MM-DD-HH-MM}`:
    - total          : all coach_chat responses
    - degraded       : responses where Haiku fallback or hard_cap kicked in
    - fallback       : safe-template fallback (compliance guard or timeout)
    - latency_ms_sum : sum for p95 approximation
    - latency_ms_cnt : count for p95 approximation

Background task aggregates the last 5 buckets every 30s. If any of:
    fallback_rate_5m > 0.05
    OR avg_latency_ms_5m > 5000
holds for 2 consecutive checks → disables flag COACH_FSM_ENABLED via
FlagsService.set_global(False) + logger.error() (Sentry captures via handler).

Fail-open everywhere: Redis outage → monitor sleeps silently.
"""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

logger = logging.getLogger(__name__)

FALLBACK_RATE_THRESHOLD = 0.05
LATENCY_MS_THRESHOLD = 5000
CONSECUTIVE_BREACHES_TO_ROLLBACK = 2
WINDOW_MINUTES = 5
CHECK_INTERVAL_SECONDS = 30


def _bucket_key(dt: Optional[datetime] = None) -> str:
    d = dt or datetime.now(timezone.utc)
    return f"coach:metrics:{d.strftime('%Y-%m-%d-%H-%M')}"


async def record_response(
    *,
    degraded: bool,
    fallback: bool,
    latency_ms: int,
    now: Optional[datetime] = None,
) -> None:
    """Record one coach_chat response into the current minute bucket.

    Fail-open: silently returns on any Redis error.
    """
    try:
        from app.core.redis_client import get_redis
        redis = await get_redis()
        if redis is None:
            return
        key = _bucket_key(now)
        pipe = redis.pipeline()
        pipe.hincrby(key, "total", 1)
        if degraded:
            pipe.hincrby(key, "degraded", 1)
        if fallback:
            pipe.hincrby(key, "fallback", 1)
        pipe.hincrby(key, "latency_ms_sum", int(latency_ms))
        pipe.hincrby(key, "latency_ms_cnt", 1)
        # 10 min TTL — well past our 5-min window
        pipe.expire(key, 600)
        await pipe.execute()
    except Exception as exc:  # pragma: no cover — defensive
        logger.warning("slo_monitor: record failed err=%s", exc)


async def _read_window(now: Optional[datetime] = None) -> dict:
    """Aggregate last WINDOW_MINUTES buckets. Returns {} on Redis outage."""
    try:
        from app.core.redis_client import get_redis
        redis = await get_redis()
        if redis is None:
            return {}
        base = now or datetime.now(timezone.utc)
        totals = {
            "total": 0, "degraded": 0, "fallback": 0,
            "latency_ms_sum": 0, "latency_ms_cnt": 0,
        }
        for i in range(WINDOW_MINUTES):
            key = _bucket_key(base - timedelta(minutes=i))
            raw = await redis.hgetall(key)
            if not raw:
                continue
            for field in totals:
                totals[field] += int(raw.get(field, 0) or 0)
        return totals
    except Exception as exc:  # pragma: no cover
        logger.warning("slo_monitor: read window failed err=%s", exc)
        return {}


def _compute_rates(agg: dict) -> dict:
    total = agg.get("total", 0) or 0
    if total <= 0:
        return {"fallback_rate": 0.0, "avg_latency_ms": 0.0, "total": 0}
    degraded = agg.get("degraded", 0) or 0
    fallback = agg.get("fallback", 0) or 0
    combined = degraded + fallback
    cnt = agg.get("latency_ms_cnt", 0) or 0
    lat_sum = agg.get("latency_ms_sum", 0) or 0
    avg_latency = (lat_sum / cnt) if cnt > 0 else 0.0
    return {
        "fallback_rate": combined / total,
        "avg_latency_ms": avg_latency,
        "total": total,
    }


class SLOMonitor:
    def __init__(self) -> None:
        self._breach_streak = 0
        self._stopped = False

    def _is_breach(self, metrics: dict) -> bool:
        return (
            metrics["fallback_rate"] > FALLBACK_RATE_THRESHOLD
            or metrics["avg_latency_ms"] > LATENCY_MS_THRESHOLD
        )

    async def check_once(self, now: Optional[datetime] = None) -> dict:
        """Run a single check. Returns metrics dict (for tests)."""
        agg = await _read_window(now=now)
        metrics = _compute_rates(agg)
        if metrics["total"] < 10:
            # Not enough traffic to decide — reset streak to avoid flapping.
            self._breach_streak = 0
            return metrics

        if self._is_breach(metrics):
            self._breach_streak += 1
            logger.warning(
                "slo_monitor breach streak=%d fallback_rate=%.3f avg_latency_ms=%.0f",
                self._breach_streak,
                metrics["fallback_rate"],
                metrics["avg_latency_ms"],
            )
            if self._breach_streak >= CONSECUTIVE_BREACHES_TO_ROLLBACK:
                await self._rollback(metrics)
                self._breach_streak = 0
        else:
            self._breach_streak = 0
        return metrics

    async def _rollback(self, metrics: dict) -> None:
        from app.services.flags_service import flags
        logger.error(
            "slo_monitor AUTO-ROLLBACK COACH_FSM_ENABLED=false "
            "fallback_rate=%.3f avg_latency_ms=%.0f total=%d",
            metrics["fallback_rate"],
            metrics["avg_latency_ms"],
            metrics["total"],
        )
        await flags.set_global("COACH_FSM_ENABLED", False)

    async def run_forever(self) -> None:  # pragma: no cover — integration
        self._stopped = False
        logger.info("slo_monitor: started (interval=%ds)", CHECK_INTERVAL_SECONDS)
        while not self._stopped:
            try:
                await self.check_once()
            except Exception as exc:
                logger.warning("slo_monitor iteration failed: %s", exc)
            await asyncio.sleep(CHECK_INTERVAL_SECONDS)

    def stop(self) -> None:
        self._stopped = True


# Module-level singleton for the FastAPI startup task
slo_monitor = SLOMonitor()
