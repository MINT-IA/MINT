"""
Phase mint-calc-engine-v1 W3 Plan 13 — Concern E AsyncSingleflight tests.

Property under test : 10 concurrent same-key calls serialize on the per-key
asyncio.Lock — at any moment, AT MOST 1 task is inside the critical section.
Different keys do NOT serialize.

Pattern verified per RESEARCH §Q-E lines 750-815 verbatim.
"""

from __future__ import annotations

import asyncio

import pytest

from app.services.cache.singleflight import AsyncSingleflight


# --------------------------------------------------------------------- Test 1
def test_same_key_serializes_10_concurrent_tasks():
    """10 asyncio tasks acquiring the SAME key — peak concurrency in critical section == 1."""

    sf = AsyncSingleflight()
    inside = 0
    peak = 0
    order: list[int] = []

    async def worker(i: int) -> None:
        nonlocal inside, peak
        async with sf.acquire(("profile-A", "avs", "hash-1")):
            inside += 1
            peak = max(peak, inside)
            order.append(i)
            # Yield to scheduler ; if singleflight is broken, another task
            # would enter here and bump `inside` past 1.
            await asyncio.sleep(0.005)
            inside -= 1

    async def run_all() -> None:
        await asyncio.gather(*[worker(i) for i in range(10)])

    asyncio.run(run_all())

    assert peak == 1, f"peak concurrency must be 1, got {peak}"
    assert len(order) == 10
    # All 10 tasks ran (none was dropped on the floor)
    assert sorted(order) == list(range(10))


# --------------------------------------------------------------------- Test 2
def test_different_keys_run_in_parallel():
    """10 asyncio tasks each acquiring a DIFFERENT key — peak concurrency reaches N."""

    sf = AsyncSingleflight()
    inside = 0
    peak = 0

    async def worker(i: int) -> None:
        nonlocal inside, peak
        # Each task gets its own unique key
        async with sf.acquire(("profile-A", "avs", f"hash-{i}")):
            inside += 1
            peak = max(peak, inside)
            # Hold the lock long enough that all 10 tasks have entered
            await asyncio.sleep(0.02)
            inside -= 1

    async def run_all() -> None:
        await asyncio.gather(*[worker(i) for i in range(10)])

    asyncio.run(run_all())

    # Different keys → no serialization across keys.
    assert peak >= 2, f"different keys should run in parallel, got peak={peak}"
    # In practice with asyncio.sleep(0.02) and 10 tasks, peak hits 10.
    assert peak <= 10


# --------------------------------------------------------------------- Test 3
def test_lock_released_after_context_exit():
    """After context exits, a fresh acquire on the same key proceeds without blocking."""

    sf = AsyncSingleflight()

    async def run() -> tuple[bool, bool]:
        key = ("profile-B", "lpp", "hash-x")
        first_acquired = False
        second_acquired = False

        async with sf.acquire(key):
            first_acquired = True

        # Lock is released here.
        # Second acquire should proceed immediately (no other holder).
        async with asyncio.timeout(0.5) if hasattr(asyncio, "timeout") else _NullCtx():
            async with sf.acquire(key):
                second_acquired = True

        return first_acquired, second_acquired

    first, second = asyncio.run(run())
    assert first is True
    assert second is True


# --------------------------------------------------------------------- Test 4
def test_same_key_after_release_re_acquires_same_lock_instance():
    """Lock instance is NOT pop'd after release — same-key re-acquire gets the same Lock object.

    Pattern note : we intentionally do NOT pop the lock after release, per
    RESEARCH §Q-E lines 784-787 (eviction lives in cache GC, not here).
    """

    sf = AsyncSingleflight()
    key = ("profile-C", "pillar3a", "hash-y")

    async def run() -> tuple[int, int]:
        async with sf.acquire(key):
            id_first = id(sf._locks[key])
        async with sf.acquire(key):
            id_second = id(sf._locks[key])
        return id_first, id_second

    id_first, id_second = asyncio.run(run())
    assert id_first == id_second, "lock identity must persist after release"


# --------------------------------------------------------------------- Stampede property test (the headline one)
def test_stampede_collapse_10_concurrent_calls_serialized():
    """The headline Concern E property : 10 concurrent same-key calls produce strictly serialized critical section.

    Stronger than Test 1 : measures that the WHOLE batch took at least N × hold_time,
    proving the calls were serialized (not just that peak==1 momentarily).
    """

    sf = AsyncSingleflight()
    hold = 0.01
    n = 10

    async def worker() -> None:
        async with sf.acquire(("profile-Z", "avs", "hash-stamp")):
            await asyncio.sleep(hold)

    async def run_all() -> float:
        loop = asyncio.get_running_loop()
        t0 = loop.time()
        await asyncio.gather(*[worker() for _ in range(n)])
        return loop.time() - t0

    elapsed = asyncio.run(run_all())
    # If singleflight is working, total time ≈ n × hold (with some scheduling overhead).
    # If it's broken (no lock), total time would be ≈ hold (parallel).
    assert elapsed >= n * hold * 0.8, (
        f"stampede collapse not serialized — elapsed={elapsed:.3f}s expected ≥ {n*hold*0.8:.3f}s"
    )


# --------------------------------------------------------------------- Helper for py3.10 fallback
class _NullCtx:
    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False
