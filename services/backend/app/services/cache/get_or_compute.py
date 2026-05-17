"""
Phase mint-calc-engine-v1 W3 Plan 13 — D-CE-12 read-through cache orchestrator.

Verbatim pattern from RESEARCH §Q-E lines 792-813 :
    1. Read cache. If hit → return cached row.
    2. Miss → acquire singleflight lock keyed by (profile_id, kind, inputs_hash).
    3. RE-CHECK cache under the lock (double-check : another task may have
       populated it while we were waiting).
    4. Still miss → invoke `compute_fn()` (the calculator).
    5. Write the compute result to the cache (supersede-chain integrity).
    6. Release lock + return the freshly-written row.

Stampede property : N concurrent same-key cold-cache calls produce 1 compute
fan-out. All N callers observe the same cached row (the one written by the
single survivor). Verified by `tests/test_cache_singleflight.py` Test 3 (10 → 1).
"""

from __future__ import annotations

from typing import Any, Awaitable, Callable

from sqlalchemy.orm import Session

from app.models.scenario import ScenarioModel
from app.services.cache.cache_reader import lookup as cache_read
from app.services.cache.cache_writer import write as cache_write
from app.services.cache.singleflight import _singleflight


async def get_or_compute(
    profile_id: str,
    kind: str,
    inputs_hash: str,
    compute_fn: Callable[[], Awaitable[dict[str, Any]]],
    db: Session,
) -> ScenarioModel:
    """D-CE-12 read-through cache with Concern E singleflight stampede mitigation.

    Args:
        profile_id: profile UUID.
        kind: calculator kind.
        inputs_hash: SHA256 hex of canonical JSON inputs.
        compute_fn: async zero-arg callable returning the compute result dict.
        db: SQLAlchemy sync session.

    Returns:
        The cached or freshly-written `ScenarioModel` row.

    Raises:
        Whatever `compute_fn()` raises — exception propagates without writing
        a row (Test 4 of `test_get_or_compute.py`). The singleflight lock is
        still released cleanly via the `async with` context manager.
    """
    # Plan 17 W4 (D-CE-12 SLI) — fire `mint_cache_lookup_total{kind, hit}`
    # at every lookup site. Late-import to avoid circular dep at module load.
    from app.core.metrics import cache_lookup_total

    # Fast path : cache hit, no lock taken.
    cached = await cache_read(profile_id, kind, inputs_hash, db)
    if cached is not None:
        cache_lookup_total.labels(kind=kind, hit="true").inc()
        return cached
    cache_lookup_total.labels(kind=kind, hit="false").inc()

    # Slow path : acquire singleflight lock for this key, then re-check.
    key = (profile_id, kind, inputs_hash)
    async with _singleflight.acquire(key):
        # Double-check : another task may have populated the cache while we
        # were waiting on the lock. This is THE singleflight stampede property.
        cached = await cache_read(profile_id, kind, inputs_hash, db)
        if cached is not None:
            # Re-check hit (post-singleflight) — count separately from the
            # fast-path hit so observability can distinguish stampede
            # collapse from true cache warmth.
            cache_lookup_total.labels(kind=kind, hit="true").inc()
            return cached

        # Single survivor : run compute, persist, return.
        payload = await compute_fn()
        return await cache_write(profile_id, kind, inputs_hash, payload, db)
