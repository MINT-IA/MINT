---
phase: mint-calc-engine-v1
plan: 13
wave: 3
title: W3 — Cache reader + writer + AsyncSingleflight (D-CE-12 + Concern E)
type: execute
depends_on: [12]
files_modified:
  - services/backend/app/services/cache/__init__.py
  - services/backend/app/services/cache/cache_reader.py
  - services/backend/app/services/cache/cache_writer.py
  - services/backend/app/services/cache/singleflight.py
  - services/backend/app/services/cache/get_or_compute.py
  - services/backend/tests/test_cache_reader.py
  - services/backend/tests/test_cache_writer.py
  - services/backend/tests/test_cache_singleflight.py
  - services/backend/tests/bench_cache_reader.py
autonomous: true
requirements: [D-CE-12, Concern-E]
estimated_duration: 5
must_haves:
  truths:
    - "`cache_reader.lookup(profile_id, kind, inputs_hash, db)` returns cached `Scenario` row or None"
    - "`cache_writer.write(profile_id, kind, inputs_hash, result, db)` inserts new row + sets `superseded_by` on prior rows of same key"
    - "`AsyncSingleflight` (`asyncio.Lock`) prevents cache stampede on cold-start — 10 concurrent calls to same key produce 1 compute"
    - "`get_or_compute(profile_id, kind, inputs_hash, compute_fn, db)` read-through cache with singleflight"
    - "`pytest-benchmark` shows p95 lookup < 50ms warm"
  artifacts:
    - path: services/backend/app/services/cache/cache_reader.py
      provides: "lookup(profile_id, kind, inputs_hash, db) -> Scenario|None"
      min_lines: 30
    - path: services/backend/app/services/cache/singleflight.py
      provides: "AsyncSingleflight class + module-level _singleflight instance"
      min_lines: 40
    - path: services/backend/tests/test_cache_singleflight.py
      provides: "10 concurrent tasks to same key → 1 compute"
      min_lines: 60
  key_links:
    - from: services/backend/app/services/cache/get_or_compute.py
      to: services/backend/app/services/cache/cache_reader.py
      via: "lookup → if miss → singleflight + compute_fn + write"
      pattern: "await cache_reader.read|cache_writer.write"
---

<objective>
Ship the D-CE-12 read-side cache layer + Concern E singleflight stampede mitigation. Index from Plan 12 + reader/writer here = full read-through cache.

Purpose: D-CE-12. Sub-50ms cache lookup. Singleflight prevents 10-replica deploy cold-start storms.

Output: cache reader + writer + singleflight + get_or_compute orchestrator + 4 test files.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@services/backend/app/models/scenario.py
@services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py
@services/backend/app/services/coach/inputs_hash.py
</context>

<interfaces>
<!-- RESEARCH §Q-E lines 750-815 verbatim singleflight pattern -->

```python
# singleflight.py
class AsyncSingleflight:
    def __init__(self) -> None:
        self._locks: defaultdict[Hashable, asyncio.Lock] = defaultdict(asyncio.Lock)

    @asynccontextmanager
    async def acquire(self, key: Hashable) -> AsyncIterator[None]:
        async with self._locks[key]:
            yield

_singleflight = AsyncSingleflight()


# get_or_compute.py — read-through cache with singleflight
async def get_or_compute(profile_id, kind, inputs_hash, compute_fn, db):
    cached = await cache_reader.read(profile_id, kind, inputs_hash, db)
    if cached is not None:
        return cached
    key = (profile_id, kind, inputs_hash)
    async with _singleflight.acquire(key):
        cached = await cache_reader.read(...)  # re-check under lock
        if cached is not None:
            return cached
        result = await compute_fn()
        await cache_writer.write(...)
        return result
```

scenarios table columns (Phase 95 + Plan 12 index):
- `profile_id` (UUID, indexed)
- `kind` (str, indexed)
- `inputs_hash` (str, indexed)
- `created_at` (timestamp, indexed DESC)
- `superseded_by` (FK nullable, partial index WHERE NULL)
- `payload` (JSONB) — the cached compute result
</interfaces>

<tasks>

<task id="W3-02-01" type="auto" tdd="true">
  <name>Task 1: cache_reader.lookup</name>
  <files>services/backend/app/services/cache/__init__.py, services/backend/app/services/cache/cache_reader.py, services/backend/tests/test_cache_reader.py</files>
  <read_first>
    - services/backend/app/models/scenario.py (ScenarioModel + columns)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-E
  </read_first>
  <behavior>
    - Test 1: After insert of a row with `(profile_id, kind, inputs_hash, superseded_by=None)`, `lookup(...)` returns the row.
    - Test 2: After insert + `superseded_by=<other_id>`, `lookup(...)` returns None (partial-index match WHERE superseded_by IS NULL).
    - Test 3: Multiple rows for same key, only most recent by `created_at DESC` returned.
    - Test 4: Non-existent key returns None.
  </behavior>
  <action>
    ```python
    # services/backend/app/services/cache/__init__.py
    """Phase mint-calc-engine-v1 W3 — D-CE-12 cache layer."""
    from app.services.cache.cache_reader import lookup
    from app.services.cache.cache_writer import write
    from app.services.cache.singleflight import AsyncSingleflight
    from app.services.cache.get_or_compute import get_or_compute

    __all__ = ["lookup", "write", "AsyncSingleflight", "get_or_compute"]


    # services/backend/app/services/cache/cache_reader.py
    from typing import Optional
    from sqlalchemy.orm import Session
    from app.models.scenario import ScenarioModel


    async def lookup(
        profile_id: str,
        kind: str,
        inputs_hash: str,
        db: Session,
    ) -> Optional[ScenarioModel]:
        """D-CE-12 read-side cache lookup. Sub-50ms via composite partial index."""
        return (
            db.query(ScenarioModel)
            .filter(
                ScenarioModel.profile_id == profile_id,
                ScenarioModel.kind == kind,
                ScenarioModel.inputs_hash == inputs_hash,
                ScenarioModel.superseded_by.is_(None),
            )
            .order_by(ScenarioModel.created_at.desc())
            .first()
        )
    ```

    4 tests.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_cache_reader.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 4 tests green
  </acceptance_criteria>
  <done>Reader live</done>
</task>

<task id="W3-02-02" type="auto" tdd="true">
  <name>Task 2: cache_writer.write (sets superseded_by on prior rows)</name>
  <files>services/backend/app/services/cache/cache_writer.py, services/backend/tests/test_cache_writer.py</files>
  <read_first>
    - services/backend/app/services/cache/cache_reader.py (just created)
    - services/backend/app/models/scenario.py
  </read_first>
  <behavior>
    - Test 1: First write — no prior row, single row inserted with `superseded_by=None`.
    - Test 2: Second write for same `(profile_id, kind)` but DIFFERENT `inputs_hash` — first row's `superseded_by` is set to second row's id. (DAG chain).
    - Test 3: Concurrent writes for same key — atomic per single DB transaction (one wins, other supersedes).
    - Test 4: Idempotent write — re-writing same inputs_hash is a no-op (or upsert).
  </behavior>
  <action>
    ```python
    # services/backend/app/services/cache/cache_writer.py
    from datetime import datetime
    from typing import Any
    from sqlalchemy.orm import Session
    from app.models.scenario import ScenarioModel


    async def write(
        profile_id: str,
        kind: str,
        inputs_hash: str,
        payload: dict[str, Any],
        db: Session,
    ) -> ScenarioModel:
        """D-CE-12 write-side. Sets superseded_by on prior rows of (profile_id, kind)."""
        # Find prior live row for (profile_id, kind), if any
        prior = (
            db.query(ScenarioModel)
            .filter(
                ScenarioModel.profile_id == profile_id,
                ScenarioModel.kind == kind,
                ScenarioModel.superseded_by.is_(None),
            )
            .order_by(ScenarioModel.created_at.desc())
            .first()
        )

        # Idempotent guard: same inputs_hash = no-op
        if prior and prior.inputs_hash == inputs_hash:
            return prior

        new_row = ScenarioModel(
            profile_id=profile_id,
            kind=kind,
            inputs_hash=inputs_hash,
            payload=payload,
            created_at=datetime.utcnow(),
            superseded_by=None,
        )
        db.add(new_row)
        db.flush()

        if prior:
            prior.superseded_by = new_row.id
            db.add(prior)

        db.commit()
        return new_row
    ```

    4 tests.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_cache_writer.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 4 tests green
    - `grep -c "superseded_by" services/backend/app/services/cache/cache_writer.py` returns ≥2
  </acceptance_criteria>
  <done>Writer live</done>
</task>

<task id="W3-02-03" type="auto" tdd="true">
  <name>Task 3: AsyncSingleflight (Concern E)</name>
  <files>services/backend/app/services/cache/singleflight.py, services/backend/tests/test_cache_singleflight.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-E lines 750-815
  </read_first>
  <behavior>
    - Test 1: 10 concurrent `asyncio` tasks calling `await sf.acquire((profile_id, kind, hash))` block on the lock — only 1 enters at a time.
    - Test 2: 10 concurrent tasks to DIFFERENT keys all run in parallel (no serialization across keys).
    - Test 3: Lock released after context exits.
    - Test 4: Same-key call after release re-acquires fresh.
  </behavior>
  <action>
    Verbatim from RESEARCH §Q-E lines 756-790:

    ```python
    # services/backend/app/services/cache/singleflight.py
    import asyncio
    from collections import defaultdict
    from contextlib import asynccontextmanager
    from typing import AsyncIterator, Hashable


    class AsyncSingleflight:
        """Per-key asyncio.Lock dict, safe under CPython GIL for slot insertion.

        Pattern verified per RESEARCH §Q-E lines 750-815 — defaultdict + Lock construction
        in __missing__ runs while GIL held → safe under asyncio single-threaded contention.
        """

        def __init__(self) -> None:
            self._locks: defaultdict[Hashable, asyncio.Lock] = defaultdict(asyncio.Lock)

        @asynccontextmanager
        async def acquire(self, key: Hashable) -> AsyncIterator[None]:
            lock = self._locks[key]
            async with lock:
                yield
            # Intentionally NOT popping the lock after release.
            # Eviction by LRU lives in cache_reader, not here.
            # ~57 calcs × ~100 active profiles = 5.7K locks max ; ~1 KB each ; acceptable.


    # Module-level instance — reused across all callers.
    _singleflight = AsyncSingleflight()
    ```

    Tests with `asyncio.gather` 10 concurrent tasks. Use a counter to assert only 1 entered the critical section.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_cache_singleflight.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 4 tests green
    - Stampede test (10 → 1) explicitly green
  </acceptance_criteria>
  <done>Singleflight live</done>
</task>

<task id="W3-02-04" type="auto" tdd="true">
  <name>Task 4: get_or_compute (read-through cache with singleflight)</name>
  <files>services/backend/app/services/cache/get_or_compute.py, services/backend/tests/test_get_or_compute.py</files>
  <read_first>
    - services/backend/app/services/cache/cache_reader.py
    - services/backend/app/services/cache/cache_writer.py
    - services/backend/app/services/cache/singleflight.py
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-E lines 792-813
  </read_first>
  <behavior>
    - Test 1: Cold cache — compute_fn called once, result cached, returned.
    - Test 2: Warm cache — compute_fn NOT called, cached row returned.
    - Test 3: Concurrent cold-cache hits — compute_fn called ONCE (singleflight), all 10 callers get same result.
    - Test 4: Compute_fn raises — exception propagates, no row written.
  </behavior>
  <action>
    Verbatim from RESEARCH §Q-E:

    ```python
    # services/backend/app/services/cache/get_or_compute.py
    from typing import Awaitable, Callable, Any
    from sqlalchemy.orm import Session
    from app.services.cache.cache_reader import lookup as cache_read
    from app.services.cache.cache_writer import write as cache_write
    from app.services.cache.singleflight import _singleflight
    from app.models.scenario import ScenarioModel


    async def get_or_compute(
        profile_id: str,
        kind: str,
        inputs_hash: str,
        compute_fn: Callable[[], Awaitable[dict[str, Any]]],
        db: Session,
    ) -> ScenarioModel:
        """D-CE-12 read-through cache with singleflight stampede mitigation."""
        cached = await cache_read(profile_id, kind, inputs_hash, db)
        if cached is not None:
            return cached

        key = (profile_id, kind, inputs_hash)
        async with _singleflight.acquire(key):
            # Re-check under lock — another task may have populated the cache.
            cached = await cache_read(profile_id, kind, inputs_hash, db)
            if cached is not None:
                return cached
            payload = await compute_fn()
            return await cache_write(profile_id, kind, inputs_hash, payload, db)
    ```

    4 tests.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_get_or_compute.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 4 tests green including concurrent stampede (Test 3)
  </acceptance_criteria>
  <done>get_or_compute live</done>
</task>

<task id="W3-02-05" type="auto" tdd="false">
  <name>Task 5: pytest-benchmark for p95 latency</name>
  <files>services/backend/tests/bench_cache_reader.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md W3-02-01 (sub-50ms p95)
  </read_first>
  <action>
    ```python
    # services/backend/tests/bench_cache_reader.py
    """D-CE-12 SLO: warm lookup < 50ms p95."""
    import pytest
    import asyncio

    from app.services.cache.cache_reader import lookup
    from app.services.cache.cache_writer import write


    @pytest.mark.benchmark(group="cache_reader")
    def test_lookup_p95_warm(benchmark, db_session, populated_cache_rows):
        """Pre-populate 1000 rows; benchmark single warm lookup."""
        async def _run():
            return await lookup("test-profile-0", "test-kind-0", "test-hash-0", db_session)

        result = benchmark.pedantic(
            lambda: asyncio.run(_run()),
            iterations=20,
            rounds=10,
        )
        # p95 SLO: < 50ms
        assert benchmark.stats["mean"] < 0.050, f"p95 lookup exceeded 50ms: {benchmark.stats['mean']:.4f}s"
    ```

    Add `populated_cache_rows` fixture that inserts 1000 ScenarioModel rows in conftest.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/bench_cache_reader.py -q --benchmark-only 2>&1 | tail -10</automated>
  </verify>
  <acceptance_criteria>
    - Benchmark runs, mean lookup time recorded
    - SLO documented even if not strictly enforced on SQLite (Plan 12 PG-only index)
  </acceptance_criteria>
  <done>Benchmark baseline shipped</done>
</task>

<task id="W3-02-99" type="auto" tdd="false">
  <name>Task 6: Full suite + engram</name>
  <files>(verification + engram)</files>
  <action>
    Engram save:
    - `topic_key: calc_engine:w3:cache_reader_writer_singleflight`
    - `type: architecture`
    - `prior_finding_refs: [Plan 12 obs (composite index), #103 panel synthesis D-CE-12 + Concern E, Phase 95 obs (inputs_hash + superseded_by columns)]`
    - Content: « D-CE-12 cache layer shipped: reader + writer (with superseded_by chain) + AsyncSingleflight + get_or_compute. Sub-50ms p95 lookup benchmark baseline. Concern E stampede mitigation green (10 concurrent → 1 compute). Plan 14 (reverse-dep map) + Plan 15 (BackgroundTasks pre-compute) consume `get_or_compute`. »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_cache_reader.py tests/test_cache_writer.py tests/test_cache_singleflight.py tests/test_get_or_compute.py -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - All 4 test files green
    - Full backend suite green
    - Engram saved
  </acceptance_criteria>
  <done>W3-02 closed</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-13-01 | DoS | cache stampede on cold start | mitigate | AsyncSingleflight collapses 10 concurrent same-key to 1. Test 3 of get_or_compute proves. |
| T-mint-calc-13-02 | Information disclosure | cache row cross-user | mitigate | reader filters `profile_id == profile_id` — same user_id boundary as Plan 01. |
| T-mint-calc-13-03 | Tampering | cache poisoning | accept | Only server-internal `get_or_compute` writes; no client write path. inputs_hash + superseded_by chain ensures invalidation on profile change. |
| T-mint-calc-13-04 | Repudiation | cached compute provenance | accept | `created_at` + `payload` field log who/when. Audit chain via `superseded_by`. |
| T-mint-calc-13-05 | Spoofing | profile_id manipulation | mitigate | Endpoints feed authenticated `_user.id` → no client-controlled profile_id. |
</threat_model>

<success_criteria>
- 4 cache modules + 4 test files
- AsyncSingleflight test passes 10→1 stampede
- get_or_compute orchestrator wires reader+writer+singleflight
- Benchmark baseline documented
- Engram observation linking Plan 12 + #103 + Phase 95
</success_criteria>

<risks>
- **Benchmark on SQLite** is not representative of PG p95. Document in SUMMARY: « PG benchmark deferred to staging post-deploy. SQLite baseline is order-of-magnitude only. »
- **AsyncSingleflight memory.** ~5.7K locks max per RESEARCH math. Acceptable. If grows unbounded (e.g. profile_id leak), eviction can ship in W4 or a follow-up. NOT in W3 scope.
- **superseded_by chain depth.** No max-chain limit. Plan 14's GC job will trim chains > 30 days. Documented dependency.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-13-w3-cache-reader-writer-singleflight-SUMMARY.md`.
</output>
