---
phase: mint-calc-engine-v1
plan: 13
subsystem: backend / cache / read-through + singleflight
tags: [d-ce-12, concern-e, w3, cache-reader, cache-writer, singleflight, get-or-compute, superseded-by, asyncio-lock, stampede, idx-scenarios-cache-lookup]
description: W3 Plan 13 ships the D-CE-12 read-through cache layer + Concern E AsyncSingleflight stampede mitigation that consume the Plan 12 composite partial index.
requires:
  - mint-calc-engine-v1-12 (idx_scenarios_cache_lookup composite partial index)
  - p95_dag_invalidation (scenarios.inputs_hash + superseded_by columns)
provides:
  - app.services.cache.lookup() — sub-50ms partial-index read on PG
  - app.services.cache.write() — insert + supersede-chain integrity (idempotent on same inputs_hash)
  - app.services.cache.AsyncSingleflight — per-key asyncio.Lock dict, Concern E stampede guard
  - app.services.cache.get_or_compute() — read-through orchestrator (read → singleflight → re-check → compute_fn → write)
  - bench_cache_reader.py — env-gated p50/p95/p99 latency measurement
affects:
  - Plan 14 reverse-dep map (will call get_or_compute)
  - Plan 15 BackgroundTasks pre-compute (will call get_or_compute)
  - Plan 16 GC job (will compact superseded chains + optionally evict singleflight locks)
  - D-CE-12 SLO (≥80% cache hit rate downstream)
tech-stack:
  added:
    - asyncio.Lock + collections.defaultdict + contextlib.asynccontextmanager (stdlib)
  patterns:
    - read-through cache with double-check under singleflight lock
    - supersede-chain DAG (new write flips prior live row's superseded_by)
    - idempotent writer (same inputs_hash → no-op return of existing row)
    - async signature over sync SQLAlchemy Session (FastAPI-compat without AsyncSession refactor)
    - env-gated bench (MINT_RUN_CACHE_BENCH=1) — informational, not regression-gating
key-files:
  created:
    - services/backend/app/services/cache/__init__.py (24 LOC — public API exports)
    - services/backend/app/services/cache/cache_reader.py (59 LOC)
    - services/backend/app/services/cache/cache_writer.py (87 LOC)
    - services/backend/app/services/cache/singleflight.py (54 LOC)
    - services/backend/app/services/cache/get_or_compute.py (70 LOC)
    - services/backend/tests/test_cache_reader.py (175 LOC, 4 tests)
    - services/backend/tests/test_cache_writer.py (171 LOC, 4 tests)
    - services/backend/tests/test_cache_singleflight.py (165 LOC, 5 tests)
    - services/backend/tests/test_get_or_compute.py (202 LOC, 4 tests)
    - services/backend/tests/bench_cache_reader.py (139 LOC, 1 env-gated test)
  modified: []
decisions:
  - Plan spec uses the word "payload" for the cached compute result ; ScenarioModel column is actually `outputs` (verified by reading services/backend/app/models/scenario.py:30). Writer maps `payload` arg → `outputs` column. No model change. Documented in cache_writer.py docstring "Notes" section.
  - async def signatures wrap sync SQLAlchemy Session calls — kept the plan's async API surface so get_or_compute can await inside AsyncSingleflight.acquire(...). No AsyncSession refactor needed ; FastAPI handlers stay async ; Session is sync (consistent with the rest of services/backend/).
  - Singleflight lock is NEVER pop'd after release (intentional per RESEARCH §Q-E lines 784-787). Eviction is the GC job's concern (Plan 16). Memory bound = ~5.7K locks max (~1 KB each), acceptable.
  - bench_cache_reader.py is env-gated (MINT_RUN_CACHE_BENCH=1) ; default pytest collects it but skips. Keeps regression suite < 2 min. pytest-benchmark is NOT installed in this repo — used time.perf_counter + statistics for a dependency-free measurement.
  - Python 3.9 forbids `asyncio.Lock()` constructed outside a running loop (the test file initially had this bug — caught + fixed). Used a plain dict counter `state = {"calls": 0}` instead ; asyncio is single-threaded by default, so no GIL race on dict slot mutation.
metrics:
  duration_min: 12
  tasks_completed: 6
  tests_added: 17
  tests_passed_after: 7165
  tests_passed_before: 7148
  test_delta: "+17 (4 reader + 4 writer + 5 singleflight + 4 get_or_compute ; bench 1 skipped, env-gated). Zero regressions."
  completed_date: "2026-05-17"
---

# Phase mint-calc-engine-v1 Plan 13 : W3 Cache Reader + Writer + AsyncSingleflight Summary

W3 Plan 13 ships the D-CE-12 read-through cache layer + Concern E AsyncSingleflight stampede mitigation. Plan 12's composite partial index `idx_scenarios_cache_lookup` is now consumed by `cache_reader.lookup()` ; `cache_writer.write()` maintains the supersede-chain DAG ; `AsyncSingleflight` collapses N concurrent same-key calls to 1 compute ; `get_or_compute()` orchestrates the read → singleflight → re-check → compute_fn → write flow.

## One-liner

D-CE-12 read-through cache + Concern E AsyncSingleflight shipped as `app.services.cache.{lookup,write,AsyncSingleflight,get_or_compute}` ; 17 new tests green (including 10→1 stampede collapse end-to-end) ; SQLite bench p50=0.167ms p95=0.188ms ; full regression 7148 → 7165 with zero deltas on skipped/xfailed.

## Tasks Executed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 RED | cache_reader.lookup — 4 failing tests | RED (ModuleNotFoundError as expected) | `f15dd846` |
| 1 GREEN | cache_reader + writer + singleflight + get_or_compute scaffold | GREEN (4/4 reader pass) | `1180eee6` |
| 2 | cache_writer.write — 4 supersede-chain tests | GREEN (4/4 pass) | `5e5a4415` |
| 3 | AsyncSingleflight — 5 tests inc. stampede headline | GREEN (5/5 pass) | `1cd20b29` |
| 4 | get_or_compute — 4 tests inc. concurrent stampede | GREEN (4/4 pass, after Python 3.9 asyncio.Lock-out-of-loop fix) | `555dff14` |
| 5 | bench_cache_reader — env-gated p50/p95/p99 | GREEN (skip by default, runs with MINT_RUN_CACHE_BENCH=1) | `0ed5ae09` |
| 6 | Full suite + lints + engram + SUMMARY | (this commit) | pending |

## Files Created / Modified

**Created** (10 files, ~1146 LOC) :

### Production code (`services/backend/app/services/cache/`)
- `__init__.py` — 24 LOC. Public API exports : `lookup`, `write`, `AsyncSingleflight`, `_singleflight`, `get_or_compute`.
- `cache_reader.py` — 59 LOC. Single `async def lookup(profile_id, kind, inputs_hash, db)`. Query shape matches Plan 12 index column order verbatim.
- `cache_writer.py` — 87 LOC. Single `async def write(...)`. 5-step transaction : find prior live → idempotent guard → insert new → flip prior.superseded_by → commit.
- `singleflight.py` — 54 LOC. `AsyncSingleflight` class + module-level `_singleflight` singleton. `defaultdict(asyncio.Lock)` GIL-safe slot insertion.
- `get_or_compute.py` — 70 LOC. Read-through orchestrator verbatim from RESEARCH §Q-E lines 792-813.

### Tests (`services/backend/tests/`)
- `test_cache_reader.py` — 175 LOC, 4 tests. Live-row return / superseded skip / most-recent-DESC / missing-returns-None.
- `test_cache_writer.py` — 171 LOC, 4 tests. First-insert / supersede-chain / idempotent-same-hash / 3-write chain depth 2.
- `test_cache_singleflight.py` — 165 LOC, 5 tests. Same-key serialization (peak=1) / different-keys parallel (peak≥2) / release / lock-identity-persists / stampede headline (10 × hold ≤ elapsed).
- `test_get_or_compute.py` — 202 LOC, 4 tests. Cold-cache-1-call / warm-cache-0-call / **concurrent-cold-cache-10-1-call HEADLINE** / compute-raises-no-row.
- `bench_cache_reader.py` — 139 LOC, 1 env-gated test. 200 warm lookups across 1000 seeded rows ; p50/p95/p99/mean reported via `print()`. Default skip.

**Modified** : none.

## Verification Evidence (0-TRUST, citations only)

| Claim | Evidence |
|-------|----------|
| `services/backend/app/services/cache/__init__.py` exists | `[ -f services/backend/app/services/cache/__init__.py ] && echo FOUND` → FOUND |
| 5 cache modules created | `ls services/backend/app/services/cache/ | wc -l` → 5 |
| Reader query matches Plan 12 index column order | `grep -A6 "db.query(ScenarioModel)" services/backend/app/services/cache/cache_reader.py` shows filters in order `profile_id`, `kind`, `inputs_hash`, `superseded_by.is_(None)` + `order_by(created_at.desc())` — EXACT match for `idx_scenarios_cache_lookup (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL` |
| Writer flips superseded_by on prior row | `grep -c "superseded_by" services/backend/app/services/cache/cache_writer.py` → 8 (≥2 acceptance OK) |
| Writer idempotent on same inputs_hash | test_cache_writer::test_write_idempotent_same_inputs_hash green ; same id returned, outputs NOT overwritten |
| AsyncSingleflight 10→1 stampede | test_cache_singleflight::test_same_key_serializes_10_concurrent_tasks green ; `peak == 1` assertion |
| AsyncSingleflight different-keys parallel | test_cache_singleflight::test_different_keys_run_in_parallel green ; `peak >= 2` |
| get_or_compute concurrent stampede end-to-end | test_get_or_compute::test_concurrent_cold_cache_compute_fn_called_once_singleflight green ; `state["calls"] == 1` assertion across 10 concurrent tasks ; all 10 callers got `rows[i].id == rows[0].id` ; DB row count == 1 |
| get_or_compute compute_fn raises ⇒ no row | test_get_or_compute::test_compute_fn_raises_no_row_written green ; `pytest.raises(ComputeFailed)` + post-DB count == 0 + recovery write succeeds (lock was released cleanly) |
| Reader 4/4 green | `cd services/backend && python3 -m pytest tests/test_cache_reader.py -q` → `4 passed in 0.28s` |
| Writer 4/4 green | `cd services/backend && python3 -m pytest tests/test_cache_writer.py -q` → `4 passed in 0.21s` |
| Singleflight 5/5 green | `cd services/backend && python3 -m pytest tests/test_cache_singleflight.py -q` → `5 passed in 0.40s` |
| get_or_compute 4/4 green | `cd services/backend && python3 -m pytest tests/test_get_or_compute.py -q` → `4 passed in 0.23s` |
| Bench skipped by default | `cd services/backend && python3 -m pytest tests/bench_cache_reader.py -q` → `1 skipped in 0.02s` |
| Bench runs with env flag | `cd services/backend && MINT_RUN_CACHE_BENCH=1 python3 -m pytest tests/bench_cache_reader.py -q -s` → `[bench_cache_reader] n=200 SQLite warm p50=0.167ms p95=0.188ms p99=0.237ms mean=0.171ms` + `1 passed in 0.26s` |
| Full regression 7165 passed | `cd services/backend && python3 -m pytest tests/ -q` → `7165 passed, 63 skipped, 3 xfailed, 1 warning in 114.39s` (delta vs Plan 12 baseline 7148/63/3 = `+17 passed`, zero skip/xfail regression) |
| banned_terms_python clean on all 10 files | `python3 tools/checks/banned_terms_python.py <10 files>` → exit 0 |
| accent_lint_fr clean | `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0 |
| Engram observation persisted | `engram save ... --project mint --type architecture --topic_key mint-calc-engine-v1:w3-plan-13:cache-reader-writer-singleflight` → `Memory saved: #138` |
| Commits chain | RED reader `f15dd846` → GREEN scaffold `1180eee6` → writer tests `5e5a4415` → singleflight tests `1cd20b29` → get_or_compute tests `555dff14` → bench `0ed5ae09` → docs (pending) |

## Bench Numbers (SQLite Local — Informational Only)

```
[bench_cache_reader] n=200 SQLite warm
  p50  = 0.167 ms
  p95  = 0.188 ms
  p99  = 0.237 ms
  mean = 0.171 ms
```

Caveats per CLAUDE.md §9 0-TRUST :
- SQLite + in-memory + StaticPool path is NOT representative of Railway PG p95.
- D-CE-12 SLO `< 50ms p95` is targeted on PG ; SQLite numbers here are order-of-magnitude only.
- Real verification = EXPLAIN ANALYZE on Railway PG14+ post-deploy (RESEARCH §Q-D lines 675-693).
- The Plan 12 composite partial index `idx_scenarios_cache_lookup` only fully materializes its plan win on PG (PostgreSQL evaluates the partial WHERE at index creation ; SQLite reduces to a plain B-tree + post-scan filter).
- pytest-benchmark NOT installed in this repo — bench uses stdlib `time.perf_counter` + `statistics`.

## Deviations from Plan

### Rule 1 — Auto-fixed bugs

**1. [Rule 1 - Bug] Plan spec used `payload` for the cached column ; actual column is `outputs`**

- **Found during** : Task 1 GREEN — reading services/backend/app/models/scenario.py to determine the correct column name for the writer.
- **Issue** : The plan `<action>` template for cache_writer.write() uses `payload: dict[str, Any]` as the arg name AND the column name (`ScenarioModel(..., payload=payload, ...)`). The actual ScenarioModel column is `outputs` (per scenario.py:30 `outputs = Column(JSON, nullable=True)`). A naive paste of the plan code would have raised `TypeError: 'payload' is an invalid keyword argument for ScenarioModel` at first write.
- **Fix** : kept `payload` as the writer's PUBLIC arg name (consistent with the plan's API contract for downstream callers including get_or_compute), but mapped `outputs=payload` in the ScenarioModel(...) constructor call. Documented in cache_writer.py docstring "Notes" section.
- **Files modified** : `services/backend/app/services/cache/cache_writer.py` line 76 (`outputs=payload`).
- **Commit** : `1180eee6` (GREEN scaffold).

**2. [Rule 1 - Bug] Plan's `from app.models.profile import ProfileModel` import path is wrong**

- **Found during** : Task 1 RED first run.
- **Issue** : test file initially imported `from app.models.profile import ProfileModel` (modeled on the plan's reading list). Actual module is `from app.models.profile_model import ProfileModel` (per `find services/backend/app/models -name "profile*"`). RED test errored with `ModuleNotFoundError: No module named 'app.models.profile'` at collection time — BEFORE the cache_reader module-not-found that the RED phase was supposed to verify.
- **Fix** : changed the test import to the correct path. Applied across all 4 test files (test_cache_reader.py, test_cache_writer.py, test_get_or_compute.py) and bench_cache_reader.py. test_cache_singleflight.py doesn't import ProfileModel.
- **Files modified** : 4 test files.
- **Commits** : folded into `f15dd846` (RED) + `5e5a4415` + `555dff14` + `0ed5ae09`.

**3. [Rule 1 - Bug] Python 3.9 forbids `asyncio.Lock()` constructed outside a running event loop**

- **Found during** : Task 4 first test run — `RuntimeError: There is no current event loop in thread 'MainThread'` raised on `call_lock = asyncio.Lock()` at the top of `test_concurrent_cold_cache_compute_fn_called_once_singleflight`.
- **Issue** : The test created an `asyncio.Lock()` synchronously (to guard the `calls` counter against concurrent mutation). Python 3.9's `asyncio.Lock.__init__` calls `events.get_event_loop()` ; if there's no running loop, it raises. (Python 3.10+ would just create a no-loop Lock and bind on first `acquire`.)
- **Fix** : replaced `asyncio.Lock()` + `nonlocal calls` with a plain `state = {"calls": 0}` dict. asyncio is single-threaded by default, so the `state["calls"] += 1` in `compute_fn` is GIL-safe + no race possible. Removed the unused `nonlocal` declaration.
- **Files modified** : `services/backend/tests/test_get_or_compute.py` lines 108-119.
- **Commit** : folded into `555dff14`.

### Rule 2-4 deviations

None. No missing critical functionality (Rule 2), no architectural escalation (Rule 4).

The bench script being env-gated rather than `@pytest.mark.benchmark` is per the explicit `<mint_infra_contract>` §4 instruction (« Bench script is informational — should NOT block the suite if slow. Mark with @pytest.mark.bench or guard with env flag »). `pytest-benchmark` is NOT installed in this repo, so the env-flag path was the only one available without adding a dependency.

## Threat Surface Notes

Plan 13 `<threat_model>` STRIDE entries :
- **T-mint-calc-13-01 DoS cache stampede on cold start** → **mitigated**. test_get_or_compute Test 3 proves `state["calls"] == 1` across 10 concurrent tasks. Singleflight collapses N → 1.
- **T-mint-calc-13-02 Information disclosure cross-user** → **mitigated**. cache_reader.lookup filters `ScenarioModel.profile_id == profile_id` exactly (cache_reader.py line 53). No multi-tenant leak path.
- **T-mint-calc-13-03 Tampering cache poisoning** → **accepted**. Only `get_or_compute` writes ; no client write path. inputs_hash + superseded_by chain ensures invalidation on profile change.
- **T-mint-calc-13-04 Repudiation cached compute provenance** → **accepted**. `created_at` + `outputs` JSON field log who/when. Audit chain via `superseded_by` traversal.
- **T-mint-calc-13-05 Spoofing profile_id manipulation** → **mitigated**. Cache layer is server-internal ; endpoints feed authenticated `_user.id` → resolved-profile-id, no client-controlled profile_id reaches lookup/write.

No new threat surface introduced beyond the plan's threat register.

## Deployment Notes (carried forward to Plan 14)

- **Staging deploy** : the cache layer is in-process Python — no migration step, no Railway config change. Becomes active on next container restart of `services/backend`. No downstream caller imports yet (Plan 14 reverse-dep map + Plan 15 BackgroundTasks pre-compute will be the first consumers).
- **PG verification post-deploy** : run the RESEARCH §Q-D lines 675-693 EXPLAIN ANALYZE query against a populated `scenarios` table on Railway PG14+ to verify the reader query uses `Index Scan using idx_scenarios_cache_lookup`. NOT done in this session (no live PG access).
- **Singleflight memory** : `~/.engram/engram.db` observation #138 documents the ~5.7K-locks memory bound. If `profile_id` leak triggers unbounded growth, Plan 16 GC adds LRU eviction.
- **Cache invalidation semantics** : on profile mutation, the snapshot/projection layer (Phase 95 DAG-INVALIDATION) bumps `inputs_hash` → next lookup misses → next write supersedes the prior row. No explicit invalidation API needed in Plan 13 ; the partial-index + supersede-chain handles it implicitly.

## What I Have NOT Done (caveats / 0-TRUST §9.6)

- Did NOT run EXPLAIN ANALYZE on Railway PG — no live PG access from this session. SQLite bench numbers verify algorithm-side correctness ; PG-specific plan choice is verifiable only post-deploy.
- Did NOT wire `get_or_compute` into any FastAPI endpoint or coach_tools.py caller — that's Plan 14 (reverse-dep map) + Plan 15 (BackgroundTasks pre-compute) scope per PLAN.md `<output>` carry-forward.
- Did NOT add `pytest-benchmark` dependency — bench uses stdlib `time.perf_counter` per `<mint_infra_contract>` §4 (informational + no dependency creep).
- Did NOT add Sentry breadcrumbs / observability to the cache layer — that's Plan 17 (metrics counters) scope.
- Did NOT add a singleflight TTL / max-wait timeout — `<deviation_protocol>` mentioned this as a "conservative path" possibility, but Plan 13 spec doesn't require it AND the singleflight critical section is just one `await compute_fn()` call (bounded by the calculator's own timeout, not the singleflight's). Adding TTL = Plan 16 scope if profile_id leak proves a real concern.
- Did NOT open a PR. Plan 13 ships direct on `dev` per current GSD sequential model ; stage 1 of 4 per CLAUDE.md §9.5.
- Did NOT merge `dev` → `staging`. Staging deploy + post-deploy EXPLAIN ANALYZE is a Plan-12+13-adjacent follow-up (chained with Plan 14 onward).
- Did NOT run Maestro G1 — Plan 13 is backend-internal, no UI surface, no endpoint added.
- Did NOT call MCP `mem_save` tool — not exposed in this session's tool list (10th consecutive plan with this mismatch). Engram CLI fallback `engram save` succeeded ; observation **#138** persisted.
- Did NOT modify `services/backend/app/models/scenario.py` — no schema change ; `outputs` JSON column accepts arbitrary dict payloads.
- Did NOT touch any caller code — cache layer is read-side infrastructure that Plan 14+ will consume.

## Engram

Observation **#138** persisted via CLI fallback :
```
engram save "D-CE-12 W3 Plan 13 cache reader+writer+singleflight+get_or_compute shipped" \
  --project mint --type architecture \
  --topic_key mint-calc-engine-v1:w3-plan-13:cache-reader-writer-singleflight
```

Content covers : What (5 modules + 4 test files + bench) / Why (Plan 12 index is dead infrastructure without reader/writer/orchestrator ; Concern E 10-replica cold-start storm) / Where (10 files, 6 commit SHAs) / Learned (5 lessons : payload→outputs column mismatch, asyncio.Lock outside loop, profile_model import path, supersede chain integrity, stampede property end-to-end) / Caveats (SQLite bench informational only, async-over-sync-Session, future plans consume get_or_compute).

`prior_finding_refs` : Plan 12 obs #137 (composite index — direct dependency), Phase 95 inputs_hash/superseded_by columns (transitive dependency, not currently in engram), Concern E panel synthesis (lives in CONTEXT.md + RESEARCH.md §Q-E, not engram).

## Self-Check: PASSED

Verified before SUMMARY commit :

1. `services/backend/app/services/cache/__init__.py` exists → `[ -f ... ] && echo FOUND` returned FOUND.
2. `services/backend/app/services/cache/cache_reader.py` exists (59 LOC) → FOUND.
3. `services/backend/app/services/cache/cache_writer.py` exists (87 LOC) → FOUND.
4. `services/backend/app/services/cache/singleflight.py` exists (54 LOC) → FOUND.
5. `services/backend/app/services/cache/get_or_compute.py` exists (70 LOC) → FOUND.
6. 4 test files present : `tests/test_cache_reader.py`, `tests/test_cache_writer.py`, `tests/test_cache_singleflight.py`, `tests/test_get_or_compute.py` → all FOUND.
7. `tests/bench_cache_reader.py` exists (139 LOC, env-gated) → FOUND.
8. Commit `f15dd846` (RED reader) reachable → present in `git log --oneline -10`.
9. Commit `1180eee6` (GREEN scaffold) reachable → present.
10. Commit `5e5a4415` (writer tests) reachable → present.
11. Commit `1cd20b29` (singleflight tests) reachable → present.
12. Commit `555dff14` (get_or_compute tests) reachable → present.
13. Commit `0ed5ae09` (bench) reachable → present.
14. Engram observation #138 confirmed via `engram save` CLI stdout : `Memory saved: #138`.
15. Full regression count cited (7165 passed) ≥ acceptance target (7160+).
16. SQLite bench numbers cited verbatim (p50=0.167ms p95=0.188ms p99=0.237ms mean=0.171ms).

## Next Plan

**Plan 14 — W3 reverse-dependency map** wires the calculator-to-calculator dependency graph that BackgroundTasks (Plan 15) uses to pre-compute downstream `kind` results on input mutation. Plan 14 consumes `get_or_compute()` shipped here ; the map is static + module-level (RESEARCH §Q-F lines TBD). Plan 15 then ties it all together via FastAPI BackgroundTasks ; Plan 16 closes the wave with the GC job for both superseded-chain pruning and (optional) singleflight lock eviction.
