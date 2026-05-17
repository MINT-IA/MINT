"""
Phase mint-calc-engine-v1 W3 Plan 13 — Concern E AsyncSingleflight.

Per-key `asyncio.Lock` dict that collapses N concurrent same-key calls to 1
compute on cache cold-start. Mitigates the 10-replica deploy cold-start storm
(Concern E) verified by RESEARCH §Q-E lines 750-815.

Race rebuttal on `defaultdict(asyncio.Lock)` :
- `defaultdict.__getitem__` invoking `__missing__` (which calls the default_factory)
  runs while the CPython GIL is held → atomic slot insertion.
- Two concurrent `__getitem__` for the same missing key get the **same Lock instance**.
- For asyncio (single-threaded by default), this is even simpler : no preemption
  during synchronous dict access.

Verified : docs.python.org/3/library/asyncio-sync.html ; dataleadsfuture.com 2026
"Mastering Synchronization Primitives in Python Asyncio" ; oneuptime.com 2026-01-25
request coalescing.

Memory bound : ~57 calcs × ~100 active profiles = 5.7K locks max ; ~1 KB each ;
acceptable. Eviction is intentionally NOT performed here — that lives in cache GC
(Plan 16) when needed.
"""

from __future__ import annotations

import asyncio
from collections import defaultdict
from contextlib import asynccontextmanager
from typing import AsyncIterator, Hashable


class AsyncSingleflight:
    """Per-key `asyncio.Lock` registry safe under CPython GIL slot insertion."""

    def __init__(self) -> None:
        self._locks: defaultdict[Hashable, asyncio.Lock] = defaultdict(asyncio.Lock)

    @asynccontextmanager
    async def acquire(self, key: Hashable) -> AsyncIterator[None]:
        """Acquire the lock for `key` ; release on context exit.

        Args:
            key: any hashable. Convention : `(profile_id, kind, inputs_hash)` tuple.

        Notes:
            - We intentionally do NOT pop the lock after release — eviction lives
              in cache GC (Plan 16), not here.
            - The lock is NOT pop'd on release, so a same-key call after release
              re-acquires the SAME `asyncio.Lock` instance ; this is correct for
              N-pass stampede protection.
        """
        lock = self._locks[key]
        async with lock:
            yield


# Module-level singleton — reused across all callers in the FastAPI process.
# Lifetime = process lifetime ; lost on container restart (acceptable for
# stampede mitigation — the next cold-start cycle just re-establishes locks).
_singleflight = AsyncSingleflight()
