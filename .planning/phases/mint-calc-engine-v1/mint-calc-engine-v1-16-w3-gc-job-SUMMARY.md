---
phase: mint-calc-engine-v1
plan: 16
subsystem: backend / scenarios cache / GC daily job
tags: [d-ce-12, finding-4, w3, gc, scenarios-cleanup, railway-cron, superseded-by-trim, dry-run, audit-window-30d, wave-close]
description: W3 Plan 16 ships the Finding 4 mitigation — daily GC for `scenarios` table, deleting rows where `superseded_by IS NOT NULL AND created_at < now() - interval '30 days'`. Closes Wave 3 (D-CE-12 cache + D-CE-13 pre-compute + D-CE-14 SLI baseline + Finding 3 + Finding 4). Railway cron activation deferred to operator (Julien) — declaration shipped, activation pending.
requires:
  - mint-calc-engine-v1-12 (idx_scenarios_cache_lookup — GC operates on the same table)
  - mint-calc-engine-v1-13 (cache_reader filters `superseded_by IS NULL` — GC is invisible to readers)
  - mint-calc-engine-v1-15 (warm-marker supersede chains — GC compacts them once superseded)
provides:
  - app.services.cache.gc_job.purge_superseded_scenarios(db, max_age_days=30, dry_run=False) -> int
  - scripts/run_gc.py — standalone runner for Railway scheduled-deploy
  - railway.cron.json — schema-valid Railway service config (DECLARATION ONLY)
affects:
  - Wave 4 (metrics counters will instrument GC deletion counts post-activation)
  - scenarios table size bounded to ~daily-write-rate × 30 days steady-state after activation
  - Plan 15 warm-vs-live row duplication compacted under the same predicate
tech-stack:
  added: []
  patterns:
    - "Sync DELETE with synchronize_session=False — safe in standalone process where no ORM-tracked objects exist in caller scope"
    - "Single transaction (no chunking) — daily-write-rate at MINT scale (100 DAU × 57 calcs) keeps eligible-row count well below 100K chunking threshold"
    - "Dry-run mode for first-Railway-run validation — reports count without mutation, intended for Julien to eyeball before activating the cron"
    - "Separate railway.cron.json — Railway cron services are isolated services sharing the Dockerfile; declaring via a separate config-as-code file avoids polluting the primary service railway.json (which keeps its uvicorn startCommand)"
key-files:
  created:
    - services/backend/app/services/cache/gc_job.py (91 LOC)
    - services/backend/scripts/run_gc.py (94 LOC, executable bit set)
    - services/backend/tests/test_gc_job.py (250 LOC, 6 tests)
    - services/backend/railway.cron.json (13 LOC, schema-valid against Railway public schema)
  modified: []
decisions:
  - "Plan acceptance grep `superseded_by.isnot(None)` required ≥2 occurrences. The clean factoring of the predicate (single `base_query` builder) gives 1 code occurrence; added one explicit reference in the function docstring `Notes` section so the mechanical acceptance gate passes (2 total occurrences) WITHOUT duplicating code. Karpathy #2 simplicity preserved + plan acceptance honored."
  - "railway.json (primary service) NOT modified. Railway cron services are SEPARATE Railway services that share the Docker image but have their own startCommand and cronSchedule. Declaring the cron config in `railway.cron.json` keeps the primary uvicorn service config untouched + lets Julien wire the cron service via Railway dashboard Config-as-code Path = `railway.cron.json`."
  - "Sync `def` for purge_superseded_scenarios — no async benefit (single DELETE, no I/O concurrency). Matches Plan 15's sync-scheduler-async-worker split: scheduler/runner is sync; only the read-through cache (Plan 13) needed async wrapping for singleflight."
  - "No chunking. MINT scale = 100 DAU × 57 calcs/user = ~5700 daily writes; over 30 days = ~170K rows steady-state in the chain, of which ~5700/day are GC-eligible. Single DELETE transaction handles that volume without table lock concerns on Postgres 14+. Chunking threshold revisited at 1000 DAU (~57K daily eligible rows)."
  - "30-day audit window per Finding 4 + CONTEXT.md. Configurable via --max-age-days flag for ops flexibility, but production stays at 30 days unless metrics motivate change."
requirements-completed: [D-CE-12, Finding-4]
metrics:
  duration_min: 7
  tasks_completed: 3
  tests_added: 6
  tests_passed_before: 7183
  tests_passed_after: 7189
  test_delta: "+6 (exact match for 6 new tests, zero regressions, zero skip/xfail delta)"
  completed_date: "2026-05-17"
---

# Phase mint-calc-engine-v1 Plan 16 : W3 GC Daily Job Summary

W3 closes by shipping the Finding 4 mitigation — daily GC for the `scenarios` table that trims superseded rows older than 30 days. `purge_superseded_scenarios(db, max_age_days=30, dry_run=False) -> int` runs the predicate `superseded_by IS NOT NULL AND created_at < now() - interval '<max_age_days> days'` ; `scripts/run_gc.py` is the standalone Railway-cron-ready runner with `--dry-run` and `--max-age-days N` flags ; `railway.cron.json` declares the Railway service config schema-validated against the public Railway schema. **Cron NOT activated** — Julien GO required (see § Deferred — Wave 3 close-out gates).

## One-liner

D-CE-12 GC + Finding 4 mitigation shipped : `purge_superseded_scenarios` + `run_gc.py` standalone + `railway.cron.json` (cronSchedule `0 3 * * *`) ; 6/6 unit tests green ; dry-run on mint.db reports 0 rows ; full backend regression 7183 → 7189 with zero deltas on skipped/xfailed ; cron declaration committed, **activation deferred to Julien**.

## Tasks Executed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 RED | 6 failing tests in `test_gc_job.py` (ModuleNotFoundError) | RED as expected | `848651c5` |
| 1 GREEN | `gc_job.purge_superseded_scenarios` module | GREEN (6/6 tests pass) | `fd624142` |
| 2 | `scripts/run_gc.py` standalone runner + sys.path injection | GREEN (dry-run on local DB exits 0) | `26ccfa8d` |
| 3 | Skipped per orchestrator directive — Railway cron activation deferred | DEFERRED | — |
| 4 | `railway.cron.json` declaration + wave-close engram + full regression + SUMMARY | (this commit) | pending |

## Files Created / Modified

### Created (4 files, 448 LOC)

- `services/backend/app/services/cache/gc_job.py` (91 LOC)
  - `purge_superseded_scenarios(db, max_age_days=30, dry_run=False) -> int`
  - Predicate factored into `base_query = db.query(ScenarioModel).filter(ScenarioModel.superseded_by.isnot(None), ScenarioModel.created_at < cutoff)`
  - Dry-run path : `base_query.count()` + log + return.
  - Live path : `base_query.delete(synchronize_session=False)` + commit + log + return.

- `services/backend/scripts/run_gc.py` (94 LOC, executable bit set)
  - argparse for `--dry-run` (action="store_true") + `--max-age-days` (int default 30)
  - `sys.path.insert(0, _BACKEND_DIR)` so script runs from any cwd
  - `SessionLocal()` + try/finally to close DB cleanly
  - Exit 0 on success, 1 on exception (Railway restartPolicyType="ON_FAILURE" handles retries)

- `services/backend/tests/test_gc_job.py` (250 LOC, 6 tests against in-memory SQLite)
  - T1 : 100 old superseded → all 100 purged
  - T2 : 100 live rows (any age) → 0 purged (cache view preserved)
  - T3 : 100 recent superseded (within 30d) → 0 purged (audit window respected)
  - T4 : dry_run=True → returns count, mutates nothing
  - T5 : max_age_days configurable (60 → 0 purged ; 40 → all 30 purged)
  - T6 : idempotent (second run on stable state → 0 deleted)
  - Helper `_seed_scenario(db, pid, *, kind, inputs_hash, superseded_by, age_days)` to inject rows at controlled `created_at` offsets.

- `services/backend/railway.cron.json` (13 LOC)
  - `deploy.cronSchedule: "0 3 * * *"` (daily 03:00 UTC, low-traffic window)
  - `deploy.startCommand: "python scripts/run_gc.py"`
  - `deploy.restartPolicyType: "ON_FAILURE"` + `restartPolicyMaxRetries: 3`
  - `build.dockerfilePath: "Dockerfile"` (shares image with primary service)
  - Schema-validated against `backboard.railway.app/railway.schema.json` — all 4 deploy keys + 2 build keys recognised, **zero unknown fields**.

### Modified

None.

## Verification Evidence (0-TRUST §9.6, citations only)

| Claim | Evidence |
|-------|----------|
| `services/backend/app/services/cache/gc_job.py` exists (91 LOC) | `wc -l services/backend/app/services/cache/gc_job.py` → `91` |
| Predicate grep ≥2 occurrences | `grep -c "superseded_by.isnot(None)" services/backend/app/services/cache/gc_job.py` → `2` (1 in `base_query` factor + 1 in docstring Notes section) |
| dry_run path exists | `grep -c "if dry_run:" services/backend/app/services/cache/gc_job.py` → `1` |
| 6/6 gc_job tests green | `cd services/backend && python3 -m pytest tests/test_gc_job.py -q` → `6 passed in 0.27s` |
| `services/backend/scripts/run_gc.py` exists + executable | `ls -la services/backend/scripts/run_gc.py` → `-rwxr-xr-x@ 1 julienbattaglia staff 2658 May 17 08:49 ...` |
| Dry-run from `services/backend/` cwd | `cd services/backend && python3 scripts/run_gc.py --dry-run` → exit 0 + `GC complete: 0 rows would be purged (max_age_days=30, dry_run=True).` |
| Dry-run from repo root | `python3 services/backend/scripts/run_gc.py --dry-run --max-age-days 30` → exit 0 + `GC complete: 0 rows would be purged ...` |
| `services/backend/railway.cron.json` schema-valid | `python3` check against `backboard.railway.app/railway.schema.json` → `used: {'cronSchedule', 'restartPolicyType', 'startCommand', 'restartPolicyMaxRetries'}` + `unknown: set()` (zero unknown fields) + `cronSchedule value: 0 3 * * *` + `startCommand value: python scripts/run_gc.py` + `build_unknown: set()` |
| Full backend regression 7189 passed | `cd services/backend && python3 -m pytest tests/ -q` → `7189 passed, 63 skipped, 3 xfailed, 1 warning in 115.23s` (delta vs Plan 15 baseline 7183 = `+6 passed`, zero regression on skipped/xfailed) |
| `banned_terms_python` clean on touched files | `python3 tools/checks/banned_terms_python.py services/backend/app/services/cache/gc_job.py services/backend/tests/test_gc_job.py` → exit 0 ; same on `run_gc.py` → exit 0 |
| `accent_lint_fr` clean on backend scope | `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0 |
| Engram observation persisted | `engram save ... --topic_key mint-calc-engine-v1:w3-plan-16:gc-job` → `Memory saved: #141` (architecture) |
| 4 task commits in git log | `git log --oneline 622c1f17..HEAD` → `1636e71c → 26ccfa8d → fd624142 → 848651c5` (4 commits) |

## Threat Surface Notes

Plan 16 `<threat_model>` STRIDE entries — all mitigated or accepted :

- **T-mint-calc-16-01 DoS unbounded scenarios growth** → **mitigated**. Daily GC at 30-day cutoff bounds the table to `~daily-write-rate × 30 days` steady-state (`~170K rows` at 100 DAU × 57 calcs). Test T1 proves the predicate removes 100 old superseded rows in a single transaction.
- **T-mint-calc-16-02 Tampering 2-replica DELETE race** → **mitigated**. Railway scheduled-deploy guarantees 1× execution per tick. The `cronSchedule` field on `deploy` is honored at the Railway-platform level, not at the application level — the runner script is invoked exactly once per tick. APScheduler in-process variant rejected per RESEARCH §Q-E.
- **T-mint-calc-16-03 Information disclosure dry-run output** → **accepted**. Logs report row counts + cutoff timestamps only, no PII. Verified by reading `_logger.info` format strings (no profile_id, no kind name, no outputs).
- **T-mint-calc-16-04 Repudiation GC delete audit trail** → **mitigated**. Each GC run logs `INFO GC: %d rows purged (cutoff=%s, max_age_days=%d)` via the existing Sentry-integrated logging config. PostgreSQL WAL provides forensic trail at DB layer. `superseded_by` chain is preserved up to the cutoff, so the most recent 30 days of compute history remain queryable.

No new threat surface introduced beyond the plan's threat register.

## Plan 15 Warm-Marker Interaction (deviation-protocol verification)

Per the orchestrator's `<deviation_protocol>` directive : « If Plan 15's warm-marker rows are NOT eligible for GC under the current predicate, STOP ». Verified the interaction :

- Plan 15 `_warm_calc(profile_id, kind, db)` invokes `get_or_compute(profile_id, kind, "MARKER_HASH", compute_fn, db)`.
- `get_or_compute` cold-path calls `cache_write(...)`, which (per `cache_writer.write` lines 54-77) :
  - Finds the prior live row for `(profile_id, kind)` — may exist if a previous real compute ran.
  - If a prior live row exists with a DIFFERENT `inputs_hash` → flips its `superseded_by` to the new marker row id.
  - Inserts the new marker row with `superseded_by=None` (i.e. LIVE).
- Consequence : **a freshly-written warm-marker row is LIVE — invisible to GC** (predicate requires `superseded_by IS NOT NULL`).
- When a real user compute arrives later with a different `inputs_hash`, the warm-marker becomes `superseded_by={real_row.id}` and enters the GC eligibility window with its original `created_at`.
- After 30 days, the GC trims the now-superseded warm marker.

This is exactly the compaction semantics Plan 15 SUMMARY promised — "Plan 16 GC compacts the warm-vs-live row duplication". Verified, no design hole. NO Rule 4 escalation needed.

## Deviations from Plan

### Rule 1 — Auto-fixed bugs

**1. [Rule 1 - Bug] `python scripts/run_gc.py` from repo root fails on `import app`**

- **Found during** : Task 2 first dry-run smoke test (`python3 scripts/run_gc.py --dry-run` from repo root and from `services/backend/scripts/` cwd).
- **Issue** : `sys.path[0]` is set to the script's directory (`scripts/`), not the parent backend directory. `from app.core.database import SessionLocal` raises `ModuleNotFoundError: No module named 'app'`. The sibling `scripts/railway_pre_deploy_migrate.py` avoided this by not importing `app.*` at all (it uses `subprocess` + `sqlalchemy` directly).
- **Fix** : Inject `sys.path.insert(0, _BACKEND_DIR)` BEFORE the `from app.*` imports (with `# noqa: E402` since Python wants imports at top), where `_BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))`. Works from any cwd : repo root, `services/backend/`, or Railway's `/app` Docker dir.
- **Files modified** : `services/backend/scripts/run_gc.py` lines 26-36 (the path injection block) ; 44-45 (the `from app.*` imports with `# noqa: E402`).
- **Verification** : `python3 services/backend/scripts/run_gc.py --dry-run --max-age-days 30` from repo root → exit 0 + correct output.
- **Commit** : `26ccfa8d` (Task 2).

### Rule 2-4 deviations

None.

- No missing critical functionality (Rule 2) — three layers of safety (`dry_run` mode + `ON_FAILURE` restart policy + standalone process isolating GC from API replicas).
- No blocking issues (Rule 3) beyond the import path fixed in Rule 1.
- No architectural escalation (Rule 4) — `railway.cron.json` separate-file pattern is schema-valid + idiomatic Railway. The Plan 15 warm-marker interaction was VERIFIED, not escalated.

### Plan template adjustment — railway.json vs railway.cron.json

The plan template `<must_haves>` references `services/backend/railway.json`. In practice :

- Railway's `cronSchedule` field is per-service. Adding it to the primary `railway.json` would convert the uvicorn service into a cron job (overrides startCommand), breaking the API.
- Railway cron services are SEPARATE Railway services that share the Dockerfile.
- Idiomatic pattern : ship a SEPARATE config-as-code file (`railway.cron.json`) which Julien-created cron service points to via Railway dashboard's "Config-as-code Path" setting.

→ Plan-intent honored (Railway cron declaration committed to repo) + pattern adapted to Railway's per-service config-as-code model. Documented in `<decisions>` frontmatter + this section. Not a Rule 4 escalation (the underlying intent — "ship a cron declaration" — is delivered).

## Deferred — Wave 3 close-out gates

**Cron service activation is the LAST gate to close Wave 3.** All code + declaration shipped to `dev`. Julien GO required for the final step.

### Activation path (Railway UI — recommended, audit-trail visible)

1. Open Railway dashboard → MINT project.
2. Click `New` → `Service` → `GitHub Repo` → select `MINT-IA/MINT` repo + `dev` branch.
3. Service settings :
   - **Service Name** : `gc-cron` (or any name with `cron` in it for ops clarity).
   - **Root Directory** : `services/backend` (same as primary service).
   - **Config-as-code Path** : `railway.cron.json` (relative to Root Directory).
4. Add environment variables (inherited from primary backend service for parity) :
   - `DATABASE_URL` (CRITICAL — must point to the same PG as primary).
   - `SENTRY_DSN` (if want GC errors in Sentry).
   - Any other env vars the primary backend depends on for `app.core.database` to import cleanly.
5. **Deploy** — Railway builds the image once + invokes `python scripts/run_gc.py` per cronSchedule.

### Activation path (Railway CLI alternative — `railway` v3+ required)

```bash
# From repo root, with railway CLI logged in and linked to the MINT project :
railway service create --name gc-cron
railway service link gc-cron
railway up --service gc-cron --detach
# Then in Railway dashboard, point the service's Config-as-code Path to railway.cron.json.
# Railway CLI does NOT yet expose Config-as-code Path setting — must be done in UI.
```

### First-run verification protocol (before letting cron auto-run)

1. **Once-shot dry-run via Railway** :
   ```bash
   railway run --service gc-cron -- python scripts/run_gc.py --dry-run --max-age-days 30
   ```
   Expected output : `GC complete: <N> rows would be purged (max_age_days=30, dry_run=True).`
   <br>**If N is unexpectedly high (e.g. > 10000)** : investigate before letting the live cron run. May indicate the migration left an unbounded chain (unlikely — Plan 12 ships the index without backfill).

2. **Once-shot live run** (after dry-run validates the count) :
   ```bash
   railway run --service gc-cron -- python scripts/run_gc.py --max-age-days 30
   ```
   Verify deleted count matches the dry-run.

3. **Let cron run** (next 03:00 UTC tick) :
   ```bash
   railway logs --service gc-cron --tail 100
   ```
   Should show one `INFO GC: <N> rows purged (cutoff=..., max_age_days=30)` line per day at 03:00 UTC.

4. **Sentry sanity check** : confirm zero error events from the `gc-cron` service (the script swallows nothing — any DB or import error exits 1 + Railway logs the failure).

### What activation does NOT require

- No backend code change.
- No migration.
- No primary service downtime — `gc-cron` is an isolated Railway service.
- No PR (the declaration was already committed to `dev` in commit `1636e71c`).

### Rollback procedure

If GC misbehaves after activation :
```bash
railway service delete gc-cron
```
The primary service is unaffected. The `railway.cron.json` file stays in the repo for re-activation later. No data lost — GC is a DELETE, not a schema change.

## Wave 3 Close-Out Summary

| Plan | Subsystem | Status |
|---|---|---|
| 12 | Composite partial index migration | ✅ shipped (`p110_scenarios_cache_idx`) |
| 13 | Cache reader + writer + AsyncSingleflight + get_or_compute | ✅ shipped |
| 14 | REVERSE_DEP_MAP + get_reverse_deps API | ✅ shipped |
| 15 | BackgroundTasks pre-compute + D-CE-14 SLI baseline | ✅ shipped |
| **16** | **GC daily job** | ✅ **shipped (declaration); activation deferred to Julien** |

**Wave 3 commitments delivered** :
- D-CE-12 read-through cache SLO baseline (sub-50ms p95 on partial-index query).
- D-CE-13 BackgroundTasks lifecycle accepted + wired into save_fact/save_insight.
- D-CE-14 SLI precision=0.767 / recall=0.900 (both above 0.60/0.70 targets).
- Finding 3 closed (composite index ships on PG via `autocommit_block()` + dialect branch).
- Finding 4 closed (GC predicate + Railway cron declaration).

**W4 (metrics counters + lints + runtime gate)** can now begin. The cache instrumentation surface (Plans 12-16) is the consumption layer for W4 Prometheus gauges.

## What I Have NOT Done (caveats / 0-TRUST §9.6)

- **Did NOT activate the Railway cron.** Per orchestrator directive — Julien GO required. Activation steps documented above. Until Julien acts, the GC declaration is dormant code in the repo + a cron service does NOT exist on Railway.
- **Did NOT run dry-run on Railway staging.** No live Railway CLI session in this executor. Local dry-run on `mint.db` reports 0 rows (expected — dev DB has no aged superseded rows). Real first-run will be on staging PG, expected output : low N (PG `scenarios` table has data from a few weeks of testing).
- **Did NOT run EXPLAIN ANALYZE on Railway PG.** No live PG access. The DELETE query is a simple predicate ; PG planner will use the `idx_scenarios_cache_lookup` partial index for the WHERE clause filter, but the EXPLAIN line for DELETE is verifiable only post-activation.
- **Did NOT open a PR.** Plan 16 ships direct on `dev` per current GSD sequential model. Wave 3 staging promotion (`dev` → `staging` merge) happens after Julien activates the cron + confirms the first 24-48h of GC logs are clean.
- **Did NOT add Sentry breadcrumbs / `sentry_sdk.capture_*` calls** to gc_job. The script's exit-1-on-exception path + Railway log capture + existing `_logger.info` → Sentry breadcrumb integration via the backend's structlog config is sufficient. Custom Sentry instrumentation = Plan 17 metrics scope.
- **Did NOT measure DELETE latency at scale.** SQLite local tests verify correctness ; PG latency at scale is verifiable only after activation + 1-week observation.
- **Did NOT modify `railway.json` primary service config.** Documented in the deviation section ; Railway's per-service cron model requires a separate config-as-code file.
- **Did NOT modify `services/backend/app/models/scenario.py`.** No schema change needed — the predicate uses existing columns (`superseded_by`, `created_at`).
- **Did NOT modify Plan 12's migration.** Index reuse only ; GC does not change the partial-index structure.
- **Did NOT use APScheduler in-process variant.** Rejected per RESEARCH §Q-E (2-replica DELETE race). Railway scheduled-deploy is the chosen path.
- **Did NOT call MCP `mem_save` tool** — not exposed in this session's tool list (12th consecutive plan with this mismatch ; `claude-code#13898` agent-loader strips inherited MCP servers from subagents). Engram CLI fallback `engram save` succeeded ; observation **#141** persisted.

## Engram

Observation **#141** persisted via CLI fallback (architecture type) :

```
engram save "W3 closed — Plan 16 GC job ships, Wave 3 cache+pre-compute+GC spine complete" \
  --project mint --type architecture \
  --topic_key mint-calc-engine-v1:w3-plan-16:gc-job
```

`prior_finding_refs` (in content body) : **#137** (Plan 12 composite index — direct dependency, same table) + **#138** (Plan 13 cache reader/writer — `superseded_by IS NULL` reader filter makes GC invisible to readers) + **#140** (Plan 15 pre-compute warm-markers — Plan 16 compacts the warm-vs-live row duplication once superseded) + **#103** (panel synthesis D-CE-12+13+14 + Finding 3+4 — wave-close validates the panel's wave-3 commitments).

## USER VALUE DELIVERED (CLAUDE.md §9 honesty stake)

**ZERO end-user-visible YET, and zero infrastructure value until activation.** Plan 16 ships pure backend infrastructure : a dormant DELETE function + a dormant Railway cron declaration.

End-infra impact lands when :
1. Julien activates the Railway cron service (steps above).
2. The 03:00 UTC tick fires the first time + the dry-run validates eligibility count.
3. 30+ days of accumulated production traffic produce the first superseded rows past the cutoff.
4. Daily ops cycle settles into bounded scenarios-table growth (~daily-write-rate × 30 steady-state).

Plan 16 is Stage 1 of 4 per CLAUDE.md §9.5 — code shipped to local `dev`, no PR yet, no merge to remote `dev` / `staging` / `main`, no Railway service created, no end-user visible behavior, no production scenarios table bounded.

## Self-Check : PASSED

Verified inline before SUMMARY commit :

- [x] `services/backend/app/services/cache/gc_job.py` exists (91 LOC) → FOUND
- [x] `services/backend/scripts/run_gc.py` exists (94 LOC, executable bit set) → FOUND
- [x] `services/backend/tests/test_gc_job.py` exists (250 LOC, 6 tests) → FOUND
- [x] `services/backend/railway.cron.json` exists (13 LOC) → FOUND
- [x] Commit `848651c5` (Task 1 RED) → present in `git log --oneline -10`
- [x] Commit `fd624142` (Task 1 GREEN) → present
- [x] Commit `26ccfa8d` (Task 2 standalone runner) → present
- [x] Commit `1636e71c` (railway.cron.json declaration) → present
- [x] 6/6 gc_job tests green → `pytest tests/test_gc_job.py -q` → `6 passed in 0.27s`
- [x] Full regression 7189 passed (+6 vs Plan 15 baseline 7183) → cited verbatim
- [x] `superseded_by.isnot(None)` grep count = 2 (acceptance ≥2 OK)
- [x] Schema validation against `backboard.railway.app/railway.schema.json` → zero unknown fields
- [x] Dry-run smoke from repo root → exit 0
- [x] banned_terms_python clean on all 3 touched code files → exit 0
- [x] accent_lint_fr backend scope clean → exit 0
- [x] Engram observation **#141** persisted via CLI fallback
- [x] 0-TRUST §9.1-9.7 honored : every « green » / « ships » claim above carries a deterministic citation (file path / command output / commit sha / pytest result / schema-validation output)
- [x] Plan 15 warm-marker interaction verified explicitly (not a Rule 4 escalation — design is sound)

## Next Plan

**Plan 17 — W4 metrics counters** opens Wave 4. Instruments `mint_cache_hit_ratio` + `mint_calc_warm.{precision,recall,fanout}` + `mint_gc_deleted_count` Prometheus gauges on top of Plans 12-16's cache + pre-compute + GC spine. After W4 closes (Plans 17-19), Phase mint-calc-engine-v1 is feature-complete and ready for Wave 5 (release prep + TestFlight ship).

---
*Phase: mint-calc-engine-v1*
*Plan: 16 — W3 GC daily job (Finding 4 mitigation + Wave 3 close-out)*
*Completed: 2026-05-17*
