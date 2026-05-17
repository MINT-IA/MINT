"""
Phase mint-calc-engine-v1 W3 Plan 13 — D-CE-12 cache_reader p50/p95 bench.

INFORMATIONAL ONLY — not in default pytest collection.

Gated by `MINT_RUN_CACHE_BENCH=1` env var to keep the regression suite fast
(default pytest run skips this file). To execute manually :

    MINT_RUN_CACHE_BENCH=1 python3 -m pytest services/backend/tests/bench_cache_reader.py -q -s

The bench populates 1000 ScenarioModel rows on the test SQLite engine, then
times N=200 warm lookups of an existing key. Reports p50 + p95 + p99.

Caveats (cited per CLAUDE.md §9 0-TRUST) :
- SQLite + in-memory engine + StaticPool is NOT representative of Railway
  PostgreSQL p95. The Plan 12 composite partial index
  `idx_scenarios_cache_lookup` does NOT enforce the partial-WHERE on SQLite,
  so the SQLite plan is a full table scan with a B-tree filter, while PG uses
  Index Scan via the partial index.
- D-CE-12 SLO target = warm lookup p95 < 50ms on PG. The SQLite numbers
  here are order-of-magnitude only ; the real verification is the EXPLAIN
  ANALYZE query in RESEARCH §Q-D lines 675-693 run on Railway PG14+ post-deploy.
- pytest-benchmark is NOT installed in this repo ; bench uses time.perf_counter
  + statistics.quantiles for a dependency-free measurement.
"""

from __future__ import annotations

import asyncio
import os
import statistics
import time
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.models.profile_model import ProfileModel  # noqa: F401 — FK target
from app.models.scenario import ScenarioModel
from app.services.cache.cache_reader import lookup


_BENCH_ENABLED = os.getenv("MINT_RUN_CACHE_BENCH") == "1"


pytestmark = pytest.mark.skipif(
    not _BENCH_ENABLED,
    reason="Bench disabled by default. Set MINT_RUN_CACHE_BENCH=1 to run.",
)


def _seed_rows(db, n: int = 1000) -> str:
    """Insert n scenarios spread across 10 profiles × 10 kinds. Returns the canonical hot key profile_id."""
    profile_ids: list[str] = []
    for _ in range(10):
        pid = str(uuid4())
        db.add(
            ProfileModel(
                id=pid,
                user_id=None,
                data={"placeholder": True},
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc),
            )
        )
        profile_ids.append(pid)
    db.flush()
    db.commit()

    base = datetime.now(timezone.utc)
    kinds = ["avs", "lpp", "pillar3a", "tax", "lamal", "rsa", "loyer", "frais", "epargne", "succession"]
    for i in range(n):
        pid = profile_ids[i % 10]
        kind = kinds[i % 10]
        row = ScenarioModel(
            id=str(uuid4()),
            profile_id=pid,
            kind=kind,
            inputs={"i": i},
            outputs={"v": i},
            inputs_hash=f"hash-{i}",
            superseded_by=None,
            created_at=base - timedelta(seconds=i),
        )
        db.add(row)
        if i % 200 == 0:
            db.flush()
    db.commit()

    # Hot key for the bench : profile 0, kind 0, hash 0.
    return profile_ids[0]


def test_lookup_latency_warm():
    """Measure warm lookup p50 / p95 / p99 over N samples. Logs results, does NOT enforce SLO on SQLite."""
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    try:
        hot_profile = _seed_rows(db, n=1000)

        # Warm-up — one call to amortize SQLAlchemy first-query cost.
        asyncio.run(lookup(hot_profile, "avs", "hash-0", db))

        n_samples = 200
        latencies_ms: list[float] = []

        async def one() -> None:
            t0 = time.perf_counter()
            await lookup(hot_profile, "avs", "hash-0", db)
            latencies_ms.append((time.perf_counter() - t0) * 1000.0)

        async def runner() -> None:
            for _ in range(n_samples):
                await one()

        asyncio.run(runner())

        latencies_ms.sort()
        p50 = statistics.median(latencies_ms)
        p95 = latencies_ms[int(0.95 * (n_samples - 1))]
        p99 = latencies_ms[int(0.99 * (n_samples - 1))]
        mean = statistics.mean(latencies_ms)

        # Print so `-s` flag shows the numbers ; pytest captures by default.
        print(
            f"\n[bench_cache_reader] n={n_samples} SQLite warm "
            f"p50={p50:.3f}ms p95={p95:.3f}ms p99={p99:.3f}ms mean={mean:.3f}ms"
        )

        # Informational assertion — order of magnitude only. PG SLO is < 50ms.
        # If SQLite p95 exceeds 50ms here, the algorithm has a perf regression
        # (something other than DB plan) we should investigate.
        assert p95 < 50.0, (
            f"SQLite p95={p95:.3f}ms > 50ms — algorithm-side regression "
            f"(SQLite has no partial index ; PG path should be even faster)"
        )
    finally:
        db.close()
