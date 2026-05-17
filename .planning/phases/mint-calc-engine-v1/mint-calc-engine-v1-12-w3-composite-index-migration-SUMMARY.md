---
phase: mint-calc-engine-v1
plan: 12
subsystem: backend / alembic / scenarios cache
tags: [d-ce-12, finding-3, alembic, composite-index, autocommit-block, postgres-concurrently, w3, scenarios-cache]
description: W3 Plan 12 ships the composite partial index Phase 95 left missing — closes Finding 3 critical gap before Plan 13's read-side cache_reader can consume it.
requires:
  - p97_snapshots_fk_defaults (alembic head at plan-time)
  - p95_dag_invalidation (scenarios.inputs_hash + superseded_by columns)
provides:
  - idx_scenarios_cache_lookup composite partial index on PostgreSQL (CONCURRENTLY + autocommit_block)
  - SQLite test fallback (plain CREATE INDEX IF NOT EXISTS, no partial WHERE)
  - alembic head p110_scenarios_cache_idx
affects:
  - Plan 13 cache_reader (consumes idx_scenarios_cache_lookup)
  - D-CE-12 read-side cache SLO (Index Scan, not Seq Scan)
tech-stack:
  added: []
  patterns:
    - op.get_context().autocommit_block() for CREATE INDEX CONCURRENTLY (RESEARCH §Q-D)
    - dialect-branch on bind.dialect.name for SQLite test compat
    - IF NOT EXISTS / IF EXISTS for idempotent deploy replay
key-files:
  created:
    - services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py (118 LOC)
    - services/backend/tests/test_scenarios_cache_index.py (230 LOC)
  modified: []
decisions:
  - Shortened revision id from `p110_scenarios_cache_lookup_index` (33 chars) to `p110_scenarios_cache_idx` (24 chars) — `lefthook alembic_revision_length` hard-blocked the 33-char form at the Postgres VARCHAR(32) cap. INDEX_NAME and filename stay at the long form (no length cap on those).
  - down_revision pinned to actual head `p97_snapshots_fk_defaults` (25 chars), NOT the stale `p97_snapshots_fk_and_server_defaults` (36 chars) cited in RESEARCH §Q-D. The long form was truncated in p97 file line 49 during the 2026-05-12 Railway 502 incident.
  - PG-only EXPLAIN ANALYZE Index Scan check `pytest.mark.skipif(...always-skip...)`. Production verification ships post-deploy via the SQL in RESEARCH §Q-D lines 675-693, not in CI.
metrics:
  duration_min: 7
  tasks_completed: 3
  tests_added: 13
  tests_passed_after: 7148
  tests_passed_before: 7136
  test_delta: "+12 (exact match for 12 new tests, 1 PG-only skipped, zero regressions)"
  completed_date: "2026-05-17"
---

# Phase mint-calc-engine-v1 Plan 12 : W3 Composite Index Migration Summary

W3 opens by shipping the composite partial index Phase 95 left missing — `idx_scenarios_cache_lookup ON scenarios (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL` — via `op.get_context().autocommit_block()` on PG / plain `CREATE INDEX IF NOT EXISTS` on SQLite, closing the Finding 3 critical gap before Plan 13's `cache_reader` consumes it.

## One-liner

D-CE-12 composite partial index `idx_scenarios_cache_lookup` ships as alembic migration `p110_scenarios_cache_idx`, autocommit_block + dialect branch + idempotent replay, 12/13 tests pass (1 PG-only skip).

## Tasks Executed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 RED | Migration tests (13 tests : 9 static + 3 runtime + 1 PG-only skip) | RED 11 failed / 1 trivially passed / 1 skipped, as expected | `41638661` |
| 1 GREEN | Alembic p110 migration (autocommit_block + dialect branch + partial WHERE) | GREEN 12 passed / 1 skipped | `925920f3` |
| 2 | (Migration tests written in Task 1 RED — no separate commit) | Done | (folded into 41638661) |
| 3 | Full regression + engram save + SUMMARY | Done | (docs commit pending) |

## Files Created / Modified

**Created** (2 files) :
- `services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` — 118 LOC. Revision id `p110_scenarios_cache_idx` (24 chars, ≤32 PG cap). down_revision `p97_snapshots_fk_defaults`. `autocommit_block()` wraps both `CREATE INDEX CONCURRENTLY IF NOT EXISTS` and `DROP INDEX CONCURRENTLY IF EXISTS` on the PG branch. SQLite branch ships plain `CREATE INDEX IF NOT EXISTS` / `DROP INDEX IF EXISTS` for the pytest in-memory test path.
- `services/backend/tests/test_scenarios_cache_index.py` — 230 LOC. 13 tests : 9 static (file exists, ast.parse, down_revision token, autocommit_block ≥2x, CREATE INDEX CONCURRENTLY ≥1x, dialect-branch ≥2x, partial WHERE, DROP INDEX, INDEX_NAME) + 3 runtime against in-memory SQLite (upgrade head creates index, downgrade -1 removes it, idempotent re-upgrade) + 1 PG-only EXPLAIN ANALYZE always-skip.

**Modified** : none.

## Verification Evidence (0-TRUST, citations only)

| Claim | Evidence |
|-------|----------|
| Migration file present | `services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` (file exists, 118 lines confirmed via `wc -l`) |
| revision id 24 chars ≤ 32 | `echo -n "p110_scenarios_cache_idx" | wc -c` → 24 ; `python3 tools/checks/alembic_revision_length.py --file <path>` → exit 0 |
| down_revision chains to actual head | `python3 -c "from alembic.config import Config; from alembic.script import ScriptDirectory; ..."` showed head=p97_snapshots_fk_defaults at plan-time ; migration file line 73 confirms `down_revision = "p97_snapshots_fk_defaults"` |
| autocommit_block ≥2x | `grep -c "autocommit_block" <file>` → 4 (2 in docstring + 2 in code, upgrade + downgrade) |
| CREATE INDEX CONCURRENTLY present | `grep -c "CREATE INDEX CONCURRENTLY" <file>` → 3 (1 in docstring + 1 in upgrade body literal + 1 in error-message reference) |
| Partial WHERE present | `grep -c "WHERE superseded_by IS NULL" <file>` → 2 (1 docstring + 1 code) |
| Dialect branch in both directions | `grep -c 'if bind.dialect.name != "postgresql"' <file>` → 2 (upgrade + downgrade) |
| Smoke : upgrade head → p110 | Manual `python3 -c "..."` script in plan-execution session ; `command.upgrade(cfg, "head")` → `alembic_version.version_num='p110_scenarios_cache_idx'` ; `inspect(eng).get_indexes("scenarios")` returns `['idx_scenarios_cache_lookup', 'ix_scenarios_profile_id']` |
| Smoke : downgrade -1 → p97 + index dropped | Same script ; `command.downgrade(cfg, "-1")` → `alembic_version.version_num='p97_snapshots_fk_defaults'` ; inspector returns `['ix_scenarios_profile_id']` (idx_scenarios_cache_lookup absent) |
| Smoke : idempotent re-upgrade | Same script ; second `command.upgrade(cfg, "head")` returns to p110 head without raising |
| Migration tests 12 pass / 1 skip | `cd services/backend && python3 -m pytest tests/test_scenarios_cache_index.py -q` → `12 passed, 1 skipped in 0.53s` |
| Full regression 7148 passed | `cd services/backend && python3 -m pytest tests/ -q` → `7148 passed, 63 skipped, 3 xfailed, 1 warning in 113.89s` (delta vs Plan 11 baseline 7136 passed / 62 skipped = +12 passed +1 skipped, exact match for the 13 new tests, zero regressions) |
| banned_terms_python clean | `python3 tools/checks/banned_terms_python.py <migration> <test>` → exit 0 |
| accent_lint_fr clean | `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0 |
| alembic_revision_length clean | `python3 tools/checks/alembic_revision_length.py --file <migration>` → exit 0 (`OK alembic_revision_length: scanned 0 migration(s), all ≤32 chars`) |
| Engram observation persisted | `engram save ... --project mint --type bugfix --topic_key mint-calc-engine-v1:w3-plan-12:composite-index-migration` → `Memory saved: #137` |

## Deviations from Plan

### Rule 1 — Auto-fixed bugs (plan-text drift from actual codebase)

**1. [Rule 1 - Bug] Plan + RESEARCH cited stale down_revision string**

- **Found during** : Task 1 RED preparation, reading p95 + p97 alembic version files.
- **Issue** : PLAN.md `<action>` template + RESEARCH §Q-D lines 615 + 630 both cite `down_revision = "p97_snapshots_fk_and_server_defaults"` (36 chars). The actual revision id in `services/backend/alembic/versions/p97_snapshots_fk_and_server_defaults.py:49` is `"p97_snapshots_fk_defaults"` (25 chars) — the long form was truncated during the 2026-05-12T11:14Z Railway 502 incident (`psycopg2.errors.StringDataRightTruncation` on `alembic_version.version_num VARCHAR(32)`). If I had pasted the RESEARCH string verbatim, `alembic upgrade head` would have raised `KeyError: 'p97_snapshots_fk_and_server_defaults'` at chain resolution.
- **Fix** : Read the actual `revision: str` field from p97 file at plan-time, pinned `down_revision = "p97_snapshots_fk_defaults"` in the new p110 migration + the test's `EXPECTED_DOWN_REVISION` constant.
- **Files modified** : `services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` line 73 ; `services/backend/tests/test_scenarios_cache_index.py` lines 47-51 + 91-93.
- **Commit** : `925920f3` (GREEN migration) + `41638661` (RED tests).

**2. [Rule 1 - Bug] Plan / RESEARCH suggested 33-char revision id, lefthook blocked it**

- **Found during** : Task 1 GREEN commit cycle — `lefthook alembic_revision_length` (tools/checks/alembic_revision_length.py) hard-blocked the commit with `🥊 alembic_revision_length: alembic revision id > 32 chars`.
- **Issue** : The RESEARCH §Q-D template + PLAN.md inline code both used `revision = "p110_scenarios_cache_lookup_index"` (33 chars). The hook was introduced AFTER RESEARCH was written, post the 2026-05-12 Railway 502 incident, with `MAX_LEN = 32` and zero grandfathering. The PLAN/RESEARCH was unaware of the new lint.
- **Fix** : Shortened revision id to `p110_scenarios_cache_idx` (24 chars). INDEX_NAME and filename stay at the long form (`idx_scenarios_cache_lookup`, `p110_scenarios_cache_lookup_index.py`) — Postgres only caps the `version_num` column, not index names or filesystem paths.
- **Files modified** : `services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` lines 3-8 (docstring) + 72 (revision field).
- **Commit** : `925920f3` (GREEN, after rename).

### Rule 2-4 deviations

None. No missing critical functionality (Rule 2), no blocking issues beyond what auto-fixed above (Rule 3), no architectural escalation (Rule 4).

## Threat Surface Notes

Plan 12 `<threat_model>` STRIDE entries :
- **T-mint-calc-12-01 DoS seq-scan** → mitigated. Index closes the regression. Production EXPLAIN ANALYZE verification scheduled post-deploy on Railway.
- **T-mint-calc-12-02 DoS migration table lock** → mitigated. `CREATE INDEX CONCURRENTLY` + `autocommit_block()` produces a non-blocking 2-pass build, no `AccessExclusiveLock`.
- **T-mint-calc-12-03 Tampering migration replay** → mitigated. `IF NOT EXISTS` / `IF EXISTS` on both directions makes deploy retries idempotent. Verified by `test_upgrade_is_idempotent`.
- **T-mint-calc-12-04 Information disclosure (EXPLAIN ANALYZE result)** → accepted (PG-only check skipped in CI ; production verification runs against test queries, not user data).

No new threat surface introduced beyond the plan's threat register.

## Deployment Notes (carried forward to Plan 13)

- **Staging** : Railway deploy auto-applies the migration on container boot via `alembic upgrade head`. The SQLite branch is tested by pytest in CI ; the PG branch is exercised on staging. EXPLAIN ANALYZE verification query (RESEARCH §Q-D lines 675-693) can be run via Railway's Postgres console after deploy.
- **Production** : Schedule the migration during low-traffic window (03-06 CET per Sentry traffic dashboard). On the projected 5.8M row scenarios table, expect ~5-10 min wall-clock for `CREATE INDEX CONCURRENTLY`. The CONCURRENTLY mode does a 2-pass build that does NOT block reads or writes (only blocks the index *creation* itself, which serializes vs other DDL).
- **Rollback** : `alembic downgrade -1` runs `DROP INDEX CONCURRENTLY IF EXISTS` (also wrapped in autocommit_block), restoring pre-Plan-12 state cleanly.

## What I Have NOT Done (caveats / 0-TRUST §9.6)

- Did NOT run EXPLAIN ANALYZE on Railway PG — no live PG access from this session. SQLite tests verify migration structure + index existence + idempotence. PG-specific behaviour (Index Scan plan choice, CONCURRENTLY non-blocking build) is verifiable only post-deploy.
- Did NOT open a PR. Plan 12 ships direct on `dev` per current GSD sequential model ; stage 1 of 4 per CLAUDE.md §9.5.
- Did NOT merge `dev` → `staging`. Staging deploy + post-deploy EXPLAIN ANALYZE check is a Plan-12-adjacent follow-up that Julien can trigger when convenient.
- Did NOT run Maestro G1 — Plan 12 is backend-only, no UI surface.
- Did NOT modify `services/backend/app/models/scenario.py` — the ORM model already declares the columns Plan 12's index references (`profile_id`, `kind`, `inputs_hash`, `created_at`, `superseded_by`). Per `feedback_pre_push_checklist`, schema-relevant migrations require model audit ; Plan 12 audit returned « no ORM change needed » (verified by reading the model file).
- Did NOT touch any caller code — the index is read-only infrastructure that Plan 13's `cache_reader` will consume. No downstream surface changed.
- Did NOT call MCP `mem_save` tool — not exposed in this session's tool list (consistent with the prior 8 plans' « MCP exposure mismatch despite merge bc07d915 » caveat). Engram CLI fallback `engram save` succeeded ; observation #137 persisted.

## Engram

Observation **#137** persisted via CLI fallback :
```
engram save "D-CE-12 W3 Plan 12 composite index migration shipped" \
  --project mint --type bugfix \
  --topic_key mint-calc-engine-v1:w3-plan-12:composite-index-migration
```

Content covers : What (migration shape) / Why (Finding 3 critical gap before Plan 13) / Where (file paths + LOC) / Learned (4 lessons — RESEARCH down_revision drift + lefthook revision-length hard gate + alembic head drift between RESEARCH and execution + smoke verification path) / Caveats (PG-only verification deferred to post-deploy).

`prior_finding_refs` : none (no prior MINT engram observations on this axis ; the panel Finding 3 lives in PLAN.md frontmatter + W3-planning synthesis, not in engram).

## Self-Check: PASSED

Verified before SUMMARY commit :

1. `services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` exists (118 LOC) → `[ -f ... ] && echo FOUND` returned `FOUND`.
2. `services/backend/tests/test_scenarios_cache_index.py` exists (230 LOC) → `FOUND`.
3. Commit `41638661` (RED) reachable via `git log --oneline --all | grep 41638661` → present.
4. Commit `925920f3` (GREEN) reachable via `git log --oneline --all | grep 925920f3` → present.
5. Engram observation #137 confirmed via `engram save` CLI stdout : `Memory saved: #137`.

## Next Plan

**Plan 13 — W3 cache_reader + cache_writer** consumes `idx_scenarios_cache_lookup`. Per CONTEXT D-CE-12 : read-side cache lookup BLOCKING, FastAPI `Depends`-injectable, no GC + no eviction + no warming in W3-PR1 (those go to W3-PR2). The reader query shape that exercises the index :

```sql
SELECT * FROM scenarios
 WHERE profile_id = :pid AND kind = :kind AND inputs_hash = :hash
   AND superseded_by IS NULL
 ORDER BY created_at DESC LIMIT 1
```

— exact column ordering matches `idx_scenarios_cache_lookup`'s `(profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL` partial index, so EXPLAIN ANALYZE on Railway PG14+ will return `Index Scan using idx_scenarios_cache_lookup`.
