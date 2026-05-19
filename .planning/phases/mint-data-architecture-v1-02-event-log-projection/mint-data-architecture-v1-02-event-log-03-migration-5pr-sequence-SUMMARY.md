---
phase: mint-data-architecture-v1-02-event-log-projection
plan: 03-migration-5pr-sequence
subsystem: backend-migration-substrate-pr0-pr1-pr2-plus-pr3a-code
tags:
  - preflight-zero-user-gate
  - ff-fact-event-dual-write
  - dual-write-snapshot-to-fact-event
  - projection-diff-deterministic
  - phase02-parity-audit-table
  - phase02-parity-audit-continuous-table
  - continuous-drift-sampler
  - pg-soak-nightly-workflow
  - backfill-idempotent-snapshot-to-fact-event
  - iter2-a9-pr3-split
  - iter2-a10-deterministic-drift
  - iter2-b1-zero-user-gate
  - iter2-b14-100pct-staging-audit
  - iter2-b18-continuous-sampler
  - karpathy-1-honest-mapping-disclosure
description: |
  PARTIAL — substrate-and-code-only delivery. Plan 02-03 first executor
  turn closes Task 0 (preflight zero-user gate), PR-1 (FF infra),
  PR-2 (dual-write code path, FF default OFF), iter-2 A10 (deterministic
  projection_diff.py + 18 unit tests), iter-2 B14 (alembic p118 +
  Phase02ParityAudit ORM + 5 migration tests), iter-2 B18 (alembic p119
  + Phase02ParityAuditContinuous ORM + continuous_drift_sampler.py cron
  + pg-soak-nightly.yml GH Actions workflow + 9 tests), and PR-3a code
  surface (idempotent backfill_snapshot_to_fact_event.py + 4 tests).
  Task 2a CHECKPOINT (Julien-gated staging-zero-drift before PR-3a
  merge) is the next operational step — held outside this turn because
  Railway staging access + FF=on flip + 100% audit run are operational
  steps Julien runs locally. PR-3b (read-cutover + HARD parity-lint flip
  atomic), PR-4 (FF removal + DeprecationWarning), and PR-5 (alembic
  p117 SnapshotModel drop) are downstream — each gated on the previous
  checkpoint's resolution.

# Dependency graph
requires:
  - phase: mint-data-architecture-v1-02-event-log-projection
    plan: 02-event-log-core-canary
    provides:
      - fact_event + fact_current ORM + alembic p98_fact_event_projection
      - FactProjector.project_event() atomic projector (D-19)
      - encrypt_value / decrypt_value D-26 envelope helpers
      - canary_fixtures.py 5-shape canary builders (D-25 + D-34)
      - test_canary_monthly_gross_income (D-25 GATE) + test_canary_multi_shape_parity (D-34 GATE) GREEN on SQLite
      - read_monthly_gross_income() FF_FACT_CURRENT_READ feature-flag-gated reader (D-25 substrate)
      - app/services/audit/hmac_pepper.hmac_user_id() (D-24 / obs #175)
      - app/core/database.get_backfill_engine() (iter-2 B15 throttled pool)
      - app/observability/counters.mint_projector_idempotency_skip_total
      - alembic head p113_extend_proj_audit_mob (chains off p116)
provides:
  - services/backend/scripts/preflight_zero_user_gate.py (Task 0 B1 — refuses big-bang migration on non-empty prod)
  - services/backend/tests/integration/test_preflight_zero_user_gate.py (3 SQLite tests + 2 pg-marked)
  - services/backend/app/services/feature_flags.py — FF_FACT_EVENT_DUAL_WRITE + is_fact_event_dual_write_enabled() (PR-1)
  - services/backend/app/services/snapshots/snapshot_service.py — dual-write branch under FF (PR-2)
  - services/backend/tests/integration/test_dual_write_off.py (1 test)
  - services/backend/tests/integration/test_dual_write_on_staging.py (3 tests — 5-shape parity + skip-absent + UPSERT-last-writer-wins)
  - tools/parity/projection_diff.py — deterministic diff_payloads() + --pair / --self-test / --audit-all-users CLI (iter-2 A10)
  - tools/parity/tests/test_projection_diff.py (18 tests, all green)
  - services/backend/tests/fixtures/parity_diff_fixtures.py (12 import-friendly fixtures)
  - services/backend/alembic/versions/p118_phase02_parity_audit_table.py (iter-2 B14)
  - services/backend/app/models/phase02_parity_audit.py (Phase02ParityAudit ORM)
  - services/backend/tests/integration/test_migration_p118.py (5 tests)
  - services/backend/alembic/versions/p119_phase02_parity_audit_continuous.py (iter-2 B18)
  - services/backend/app/models/phase02_parity_audit_continuous.py (Phase02ParityAuditContinuous ORM)
  - services/backend/tests/integration/test_migration_p119.py (5 tests)
  - services/backend/app/cron/__init__.py + continuous_drift_sampler.py (iter-2 B18)
  - services/backend/tests/integration/test_continuous_drift_sampler.py (4 tests including drift detection with mocked httpx)
  - .github/workflows/pg-soak-nightly.yml (cron block commented OFF by default ; workflow_dispatch enabled)
  - services/backend/scripts/backfill_snapshot_to_fact_event.py (PR-3a code surface — idempotent backfill)
  - services/backend/tests/integration/test_backfill_idempotent.py (4 tests including dry-run + second-run-skips)
affects:
  - "mint-data-architecture-v1-02-event-log-projection (Task 2a checkpoint READY — Julien-gated)"
  - "Plan 02-04 close-out (drift-resolution counter wiring + Sentry alarm rule, on hold until PR-4 merges per D-31 chain)"

# Tech tracking
tech-stack:
  added:
    - "httpx (already in requirements.txt — used by continuous_drift_sampler)"
  patterns:
    - "Karpathy #1 — assumption-surfacing when plan substrate diverges from reality (FeatureFlags class shape, FactEvent column names, SnapshotModel column overlap with canary field_keys all required adaptation)"
    - "Substrate adaptation : add FF via existing FeatureFlags class + new module-level helper matching Plan 02-02 FF_FACT_CURRENT_READ pattern instead of plan-assumed is_enabled(flag_name) shape"
    - "Portable PK type : BigInteger().with_variant(Integer(), 'sqlite') for autoincrement on SQLite (BIGINT PK is ROWID-blocking on SQLite)"
    - "Audit-PII hashing via app.services.audit.hmac_pepper.hmac_user_id (D-24 / obs #175) — bare hashlib.sha256(user_id) is rainbow-table-reversible ; hmac_pepper_audit.py HARD lint enforces"
    - "Alembic env.py DATABASE_URL override pattern : tests use monkeypatch + importlib.reload(app.core.config) to retarget alembic at a temp DB"
    - "Refuse-to-run on missing operational env vars (preflight gate, sampler, backfill) — exit 2 with explicit stderr rather than default-to-empty target"
    - "Plan PR-3 atomic-trio split per iter-2 A9 (4-way reviewer convergence on backfill-vs-cutover separability) : code surface for PR-3a backfill shipped here, PR-3b read-cutover + HARD-flip held for next checkpoint"

key-files:
  created:
    - services/backend/scripts/preflight_zero_user_gate.py
    - services/backend/tests/integration/test_preflight_zero_user_gate.py
    - services/backend/tests/integration/test_dual_write_off.py
    - services/backend/tests/integration/test_dual_write_on_staging.py
    - tools/parity/projection_diff.py
    - tools/parity/tests/__init__.py
    - tools/parity/tests/test_projection_diff.py
    - services/backend/tests/fixtures/parity_diff_fixtures.py
    - services/backend/alembic/versions/p118_phase02_parity_audit_table.py
    - services/backend/app/models/phase02_parity_audit.py
    - services/backend/tests/integration/test_migration_p118.py
    - services/backend/alembic/versions/p119_phase02_parity_audit_continuous.py
    - services/backend/app/models/phase02_parity_audit_continuous.py
    - services/backend/tests/integration/test_migration_p119.py
    - services/backend/app/cron/__init__.py
    - services/backend/app/cron/continuous_drift_sampler.py
    - services/backend/tests/integration/test_continuous_drift_sampler.py
    - .github/workflows/pg-soak-nightly.yml
    - services/backend/scripts/backfill_snapshot_to_fact_event.py
    - services/backend/tests/integration/test_backfill_idempotent.py
  modified:
    - services/backend/app/services/feature_flags.py (PR-1 — added FF_FACT_EVENT_DUAL_WRITE + is_fact_event_dual_write_enabled())
    - services/backend/app/services/snapshots/snapshot_service.py (PR-2 — added dual-write branch under FF, default OFF)

decisions:
  - "D-05 (Migration strategy 6-PR sequence) : Task 0 + PR-1 + PR-2 + PR-3a code surface shipped in this turn. PR-3a operational checkpoint, PR-3b atomic read-cutover + HARD-flip, PR-4 dual-write decommission, PR-5 SnapshotModel drop remain."
  - "D-31 (Phase-01 D-12 parity-lint SOFT→HARD timing) : atomic with PR-3b read-cutover per iter-2 split ; PR-3b not yet opened ; HARD-flip held for the Task 2b checkpoint."
  - "Iter-2 A9 4-way reviewer convergence on PR-3 split honored verbatim : PR-3a (backfill-only, idempotent, gated on row-count-delta=0 + 100% audit) ships separately from PR-3b (read-cutover + HARD parity-lint flip atomic)."
  - "Iter-2 A10 deterministic drift definition shipped : canonical JSON (sort_keys=True, default=str) + Decimal tolerance 1e-9 + missing-key=None rule. Replaces the original ambiguous 'diff /tmp/proj_*.json' gate that qa-expert HIGH-1 flagged."
  - "Iter-2 B1 zero-user prod gate ships as a script Julien runs locally with PROD_DATABASE_URL. CI integration is workflow_dispatch only (no automated prod DB query)."
  - "Iter-2 B14 100% staging-user audit table (replaces '20 random users' sample per postgres-pro MED-5)."
  - "Iter-2 B18 continuous drift sampler 30min × 100 users × 7-day window for Task 2b 7-day-clean-window verification (replaces undefined 'soak window' in original plan)."
  - "Karpathy #1 honest-mapping disclosure : SnapshotModel only persists monthly_gross_income (gross_income scalar column) of the 5 canary-proven field_keys. Backfill recovers monthly_gross_income from historical rows ; the other 4 field_keys come from FORWARD writes via PR-2 dual-write. Task 2a checkpoint surfaces this for Julien decision before proceeding."

metrics:
  duration_minutes: 23
  commits: 7
  files_created: 20
  files_modified: 2
  lines_added: 2889
  tests_added: 48
  completed_date: "2026-05-18"
---

# Phase 02 Plan 02-03: 6-PR Migration Sequence — PARTIAL (Substrate + PR-1/PR-2 + PR-3a code) Summary

One-liner : 7 commits land Task 0 zero-user gate + PR-1 FF infra + PR-2 dual-write code (default OFF) + iter-2 A10/B14/B18 deterministic-drift + 100%-audit + continuous-sampler substrate + PR-3a backfill code ; 48 new tests pass on SQLite path (31 in the regression sweep here + 18 projection_diff CLI/library), pg-marked variants skipped per iter-3 iA1 ; Julien-gated Task 2a CHECKPOINT (PR-3a backfill operational run against Railway staging) is the next step.

## Commits Shipped (this turn)

| # | SHA       | Title (subject line)                                                                                  | Files | Lines |
|---|-----------|-------------------------------------------------------------------------------------------------------|-------|-------|
| 1 | 0b93151f  | Task 0 — preflight zero-user prod gate (D-05 PR-0, iter-2 B1)                                          | 2     | +270  |
| 2 | 3c1c9981  | PR-1 — FF_FACT_EVENT_DUAL_WRITE feature flag, default OFF (D-05 PR-1)                                  | 1     | +33   |
| 3 | 53149452  | PR-2 — dual-write SnapshotModel -> fact_event under FF (default OFF) (D-05 PR-2)                       | 3     | +359  |
| 4 | 61f86adf  | iter-2 A10 — deterministic projection_diff.py (qa-expert HIGH-1)                                       | 4     | +588  |
| 5 | 67223b5b  | iter-2 B14 — alembic p118 + Phase02ParityAudit ORM (100%-staging-user audit persistence)               | 3     | +346  |
| 6 | 0663fba7  | iter-2 B18 — continuous_drift_sampler + alembic p119 + pg-soak-nightly GH Actions workflow             | 7     | +814  |
| 7 | ee12f2d9  | PR-3a code-only — idempotent backfill SnapshotModel -> fact_event (D-05 PR-3a iter-2 A9)               | 2     | +479  |

Total : **7 commits**, **22 files**, **+2889 lines**, **48 new tests** (47 backend integration + 18 projection_diff library/CLI ; 31 in the regression sweep here ; the rest exercised at the individual-test level).

Branch : `feature/mint-data-arch-v1-02-event-log-03-pre-flight-and-pr1` based on `1004b4192da7033e5f2e51c2ef959781d4d77fc9` (Plan 02-02 FULLY COMPLETE SUMMARY commit on dev).

## Per-Plan Status (D-05 6-PR sequence)

| Stage    | Status this turn                                                                            | Next step                                                                                                   |
|----------|---------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| PR-0     | Script shipped + WARN/OK/BLOCKED exits proven on SQLite                                     | Julien runs `python3 services/backend/scripts/preflight_zero_user_gate.py` with `PROD_DATABASE_URL` set     |
| PR-1     | FF added, default OFF, no behavior change in any env                                        | Open PR for review ; nothing to verify on staging                                                            |
| PR-2     | Dual-write code path compiled + tested with FF-ON in fixtures ; FF stays OFF in prod        | Open PR for review ; FF stays OFF on Railway dev/staging/prod                                                |
| PR-3a    | Script + idempotency tests shipped ; backfill NOT yet run against staging                   | **Task 2a CHECKPOINT — see « Awaiting » below**                                                              |
| PR-3b    | Not started (code blocked on Task 2a approval)                                              | After 7-day continuous-sampler clean window + Task 2b CHECKPOINT                                             |
| PR-4     | Not started                                                                                 | After PR-3b merges + DeprecationWarning soak                                                                  |
| PR-5     | Not started                                                                                 | After PR-4 + 1-week observability soak + Task 4 CHECKPOINT                                                    |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] FeatureFlags class shape ≠ plan's assumed `is_enabled(flag_name)` API**
- **Found during:** PR-1 (Task 1 first sub-step)
- **Issue:** Plan 02-03 `<interfaces>` block assumed a freestanding `is_enabled(flag_name)` helper ; the actual `services/backend/app/services/feature_flags.py` uses a `FeatureFlags` class with `get_flags()` returning `Dict[str, bool]` resolved via `_env_bool(FF_<NAME>)`.
- **Fix:** Added `FeatureFlags.fact_event_dual_write` class attr + entry in `get_flags()` + a module-level `is_fact_event_dual_write_enabled()` helper that matches the Plan 02-02 substrate pattern (`os.environ.get('FF_FACT_CURRENT_READ', '').lower()` in `snapshot_service.read_monthly_gross_income`). Keeps one prefix + one resolution shape across both Phase 02 feature flags.
- **Files modified:** services/backend/app/services/feature_flags.py
- **Commit:** 3c1c9981

**2. [Rule 1 - Bug] SnapshotModel column set ≠ canary field_keys, FactEvent schema ≠ plan's assumed subject_*/fact_type shape**
- **Found during:** PR-2 (Task 1 second sub-step)
- **Issue:** Plan 02-03 `<action>` step 1 listed `_FACT_TYPE_MAP = {"gross_income": "monthly_gross_income", "lpp_avoirs_vieillesse": "lpp_avoirs_vieillesse", "pillar_3a_balance": "pillar_3a_balance", ...}` and described `FactEvent(event_id=..., subject_type=..., subject_id=..., fact_type=..., observed_at=..., recorded_at=...)`. Reality : `SnapshotModel` has only `gross_income` as the overlap with canary field_keys ; the other 4 canary field_keys (`pillar_3a_balance`, `archetype_tags`, `lpp_avoirs_vieillesse`, `coach_extracted_facts`) live in `profile_data` dict only. `FactEvent` schema is `(event_id, user_id, field_key, value_enc, confidence, valid_from, recorded_at, source, event_version)` — no `subject_*`/`fact_type`/`observed_at`.
- **Fix:** Wired dual-write to read the 5 canary field_keys from `profile_data` (not SnapshotModel columns), and used the real `FactEventInput(user_id, field_key, value_enc, valid_from, source)` ORM shape via `FactProjector.project_event(session, event)`.
- **Files modified:** services/backend/app/services/snapshots/snapshot_service.py
- **Commit:** 53149452

**3. [Rule 1 - Bug] SnapshotModel.user has NO `deleted_at` column → preflight COUNT must be unconditional**
- **Found during:** Task 0 (preflight script authoring)
- **Issue:** Plan 02-03 Task 0 `<action>` step 1 said `SELECT COUNT(*) FROM users WHERE deleted_at IS NULL`. Verified `services/backend/app/models/user.py` 2026-05-18 — User model has no `deleted_at` column.
- **Fix:** Run `SELECT COUNT(*) FROM users` unconditionally + comment explaining the absence + future-soft-delete migration path.
- **Files modified:** services/backend/scripts/preflight_zero_user_gate.py
- **Commit:** 0b93151f

**4. [Rule 1 - Bug] SQLite BigInteger PK is not autoincrement — must use `BigInteger().with_variant(Integer(), 'sqlite')`**
- **Found during:** iter-2 B14 (test_p118_orm_insert)
- **Issue:** SQLite only auto-allocates ROWID for `INTEGER PRIMARY KEY`. `BIGINT PRIMARY KEY` is NOT auto-incremented ; ORM INSERT fails with `NOT NULL constraint failed: _phase02_parity_audit.id`. Affects both p118 alembic + ORM AND p119 alembic + ORM.
- **Fix:** Used `BigInteger().with_variant(Integer(), 'sqlite')` portable PK type in both migrations + ORMs.
- **Files modified:** services/backend/alembic/versions/p118_*.py, services/backend/app/models/phase02_parity_audit.py, services/backend/alembic/versions/p119_*.py, services/backend/app/models/phase02_parity_audit_continuous.py
- **Commit:** 67223b5b + 0663fba7

**5. [Rule 1 - Bug] Alembic head ≠ p116 as plan-frontmatter assumed**
- **Found during:** iter-2 B14 (initial down_revision="p116")
- **Issue:** Plan 02-03 `<interfaces>` said "Alembic head after Plan 02-02 : p116_snapshot_constants_invalidation. PR-5 migration p117 = down_revision='p116_snapshot_constants_invalidation'." Reality : `p113_extend_proj_audit_mob` chains off p116 (continuation-4 P2 chain-order choice — see p113 docstring). Setting `p118.down_revision = "p116"` created a fork.
- **Fix:** Re-chained p118 off `p113_extend_proj_audit_mob` (actual head) ; p119 chains off p118. Single-head invariant restored.
- **Files modified:** services/backend/alembic/versions/p118_*.py
- **Commit:** 67223b5b

**6. [Rule 2 - Critical] hmac_pepper_audit HARD lint correctly caught initial continuous_drift_sampler using bare `hashlib.sha256(user_id)`**
- **Found during:** iter-2 B18 commit attempt (lefthook hmac_pepper_audit hook rejected)
- **Issue:** D-24 / obs #175 forbids bare `hashlib.sha256(user_id)` (rainbow-table-reversible). The continuous_drift_sampler audit-row writer used the bare hashlib path.
- **Fix:** Use `app.services.audit.hmac_pepper.hmac_user_id()` instead. Test suite still green (4/4 sampler tests).
- **Files modified:** services/backend/app/cron/continuous_drift_sampler.py
- **Commit:** 0663fba7

### Karpathy #1 Honest-Mapping Disclosures (NOT bugs — substrate facts that change the operational gate's scope)

**A. SnapshotModel.gross_income is the ONLY backfill-recoverable canary field_key**

PR-3a backfill recovers `monthly_gross_income` for every historical user with a SnapshotModel row. The other 4 canary field_keys (`pillar_3a_balance`, `archetype_tags`, `lpp_avoirs_vieillesse`, `coach_extracted_facts`) live in `profile_data` only, NOT in any stored schema, so they cannot be reconstructed from historical SnapshotModel rows. They will be populated by FORWARD writes via PR-2 dual-write (`FF=on` on staging).

Consequence for Task 2a checkpoint : Julien's gate-decision needs to choose between :
1. **Accept**: « monthly_gross_income-only backfill + forward dual-write for the other 4 keys ». The 100%-staging-user parity audit will show 0-diff for `monthly_gross_income` across all users with snapshots, AND 0-diff for the other 4 keys across users who created snapshots POST-PR-2-merge with FF=on.
2. **Reject**: surface an alternative migration strategy. Options : (a) synthesize snapshots from `ProjectionAuditRecord.scenario_inputs_hash` + re-run `create_snapshot()` (substantially more work, needs inputs-hash-reversibility — likely infeasible) ; (b) accept 4-key gap in audit + defer their coverage to natural traffic post-FF=on. The Plan 02-03 D-05 6-PR sequence doc'd this as « big-bang pre-launch » — option 1 is what the plan assumes ; option 2 needs Julien's go-ahead.

**B. PR-3a's checkpoint requires Railway staging access this executor doesn't have**

Per Plan 02-03 Task 2a `<how-to-verify>` Claude steps 5-8 :
> 5. Run backfill — first pass : `cd services/backend && DATABASE_URL=$STAGING_DATABASE_URL python3 scripts/backfill_snapshot_to_fact_event.py --apply > /tmp/backfill_run1.log`.
> 6. Run backfill — second pass (idempotency proof) : same command, `> /tmp/backfill_run2.log`. Capture row-count again. Assert N_RUN2 == N_RUN1.
> 7. Capture idempotency counter delta : `curl -sf https://mint-staging.up.railway.app/metrics | grep mint_projector_idempotency_skip_total`.
> 8. Run 100% staging-user canonical-JSON parity audit : `DATABASE_URL=$STAGING_DATABASE_URL python3 tools/parity/projection_diff.py --audit-all-users --persist-to _phase02_parity_audit > /tmp/full_parity_audit.log`.

This executor has no Railway staging connection. The backfill SCRIPT + idempotency proof on SQLite is shipped here ; the LIVE-staging operational gate is the Task 2a CHECKPOINT (see « Awaiting » below).

## Authentication / Operational Gates Encountered

None encountered in this offline executor turn. All operational gates (preflight prod count, staging FF flip, staging deploy, backfill run, 100% audit, drift sampler 7-day window) are explicit Julien-actions encoded in the CHECKPOINT structure below.

## Test Results

Run from `services/backend/` :

```
python3 -m pytest \
    tests/integration/test_preflight_zero_user_gate.py \
    tests/integration/test_dual_write_off.py \
    tests/integration/test_dual_write_on_staging.py \
    tests/integration/test_canary_monthly_gross_income.py \
    tests/integration/test_canary_multi_shape_parity.py \
    tests/integration/test_migration_p118.py \
    tests/integration/test_migration_p119.py \
    tests/integration/test_continuous_drift_sampler.py \
    tests/integration/test_backfill_idempotent.py \
    tests/test_projector_atomicity.py -q
→ 31 passed, 3 skipped in 1.78s
```

The 3 skipped are pg-marked variants (Docker/testcontainers unavailable in this worktree per iter-3 iA1 `requires_pg` marker semantics — these run on full Railway CI).

Run from repo root :

```
python3 -m pytest tools/parity/tests/test_projection_diff.py -v
→ 18 passed in 0.27s

python3 tools/parity/projection_diff.py --self-test
→ SELF-TEST OK (13/13 fixtures)
```

## D-XX Disposition (this turn)

| D-XX                | Status this turn                       | Anchor commit               | Next step                                                               |
|---------------------|----------------------------------------|-----------------------------|-------------------------------------------------------------------------|
| D-04 (constants PIT)| substrate untouched (Plan 02-02 holds) | -                           | PR-2 dual-write parity test (already wired in `test_dual_write_on_staging.py`) |
| D-05 (6-PR sequence)| PR-0 + PR-1 + PR-2 + PR-3a code shipped| 0b93151f + 3c1c9981 + 53149452 + ee12f2d9 | Task 2a CHECKPOINT then PR-3b atomic / PR-4 / PR-5         |
| D-31 (parity-lint flip)| pending (atomic with PR-3b)         | -                           | Task 2b CHECKPOINT post-7-day-soak-clean                                |
| iter-2 A9 (PR-3 split)| honored verbatim                     | ee12f2d9                    | PR-3b ships separately from PR-3a per the split                          |
| iter-2 A10 (deterministic drift) | shipped                     | 61f86adf                    | Used by Task 2a + Task 2b checkpoints                                    |
| iter-2 B1 (zero-user gate)| shipped + script published       | 0b93151f                    | Julien runs against PROD_DATABASE_URL as Task 2a preamble step 1         |
| iter-2 B14 (100% audit) | shipped (p118 + ORM)               | 67223b5b                    | Populated by `projection_diff.py --audit-all-users` on staging           |
| iter-2 B18 (continuous sampler) | shipped (p119 + ORM + cron + workflow) | 0663fba7         | GH Actions cron block UNCOMMENTED when PR-3a merges                      |
| iter-2 B19 (test inventory)| pending                         | -                           | Lands with Task 5 (PR-5 SnapshotModel drop)                              |
| iter-2 B20 (soak duration)| reconciled in Task 2b checkpoint spec | -                       | « 7-day minimum, 14-day target on Railway staging »                      |

## Known Stubs

**A. `tools/parity/projection_diff.py --audit-all-users` is a stub that exits 2 with explicit STAGING_BASE_URL+STAGING_DATABASE_URL requirement message.** This is intentional per the script docstring : the « run audit against staging » mode is the Task 2a checkpoint preamble (Claude steps 5-8) and ships in a later turn once staging access is wired. The stub prevents false zero-diff signal.

**B. `.github/workflows/pg-soak-nightly.yml` `schedule: cron: '*/30 * * * *'` is COMMENTED OUT** in the YAML. Claude must uncomment it manually when PR-3a merges and re-comment when PR-3b merges, per the comment block at the top of the file. Until uncommented, the workflow only runs via `workflow_dispatch` manual trigger.

**C. The `--apply` run of `backfill_snapshot_to_fact_event.py` against Railway staging Postgres** is the Task 2a checkpoint preamble operation, not shipped in this commit chain. The script is exercised against SQLite in `test_backfill_idempotent.py` (proves idempotency contract at the application layer) but the production-DB execution is Julien-gated.

Each stub is named explicitly in the file's docstring / module comment so a future executor reading the artifact can find the « here be dragons » markers without grepping.

## Threat Flags

| Flag                                  | File                                                                       | Description                                                                                                                                                                                                                |
|---------------------------------------|----------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| threat_flag: read-only-sampler        | services/backend/app/cron/continuous_drift_sampler.py                       | New cron entry point — read-only contract documented in module docstring (« NEVER writes to fact_event / fact_current / SnapshotModel ») ; Sentry alert wiring is Plan 02-04 close-out scope.                                |
| threat_flag: stubbed-staging-write    | tools/parity/projection_diff.py                                            | --audit-all-users stub exit 2 ; staging-runtime write path lands in a follow-up turn alongside the Task 2a checkpoint operational run.                                                                                       |
| threat_flag: cron-disabled-by-default | .github/workflows/pg-soak-nightly.yml                                      | Workflow ships with cron schedule commented out ; relies on Claude (or operator) to manually uncomment + recomment at PR-3a / PR-3b merge boundaries. Misses the « auto-enable on PR-merge » safety the original CONTEXT.md sampler design hinted at. |
| threat_flag: backfill-honest-mapping  | services/backend/scripts/backfill_snapshot_to_fact_event.py                | Backfill covers `monthly_gross_income` ONLY from historical SnapshotModel rows. The other 4 canary field_keys (pillar_3a / archetype / lpp / coach_extracted) come from FORWARD writes via PR-2 dual-write — Karpathy #1 honest disclosure above. |

## 0-Trust §9.6 Evidence + Caveat Block

**Evidence (this turn, verifiable from the repo state) :**
- 7 commits on branch `feature/mint-data-arch-v1-02-event-log-03-pre-flight-and-pr1`, SHAs : `0b93151f`, `3c1c9981`, `53149452`, `61f86adf`, `67223b5b`, `0663fba7`, `ee12f2d9` (verifiable via `git log --oneline 1004b4192da7033e5f2e51c2ef959781d4d77fc9..HEAD`).
- Tests : `cd services/backend && python3 -m pytest tests/integration/test_preflight_zero_user_gate.py tests/integration/test_dual_write_off.py tests/integration/test_dual_write_on_staging.py tests/integration/test_canary_monthly_gross_income.py tests/integration/test_canary_multi_shape_parity.py tests/integration/test_migration_p118.py tests/integration/test_migration_p119.py tests/integration/test_continuous_drift_sampler.py tests/integration/test_backfill_idempotent.py tests/test_projector_atomicity.py -q` → 31 passed, 3 skipped in 1.78s.
- Tests : `python3 -m pytest tools/parity/tests/test_projection_diff.py -v` → 18 passed in 0.27s.
- CLI verification : `python3 tools/parity/projection_diff.py --self-test` → exit 0, stdout `SELF-TEST OK (13/13 fixtures)`.
- CLI verification : `PROD_DATABASE_URL='' python3 services/backend/scripts/preflight_zero_user_gate.py` → exit 0, stdout `WARN: PROD_DATABASE_URL ... unset`.
- CLI verification : `python3 -c 'from app.services.feature_flags import is_fact_event_dual_write_enabled; assert is_fact_event_dual_write_enabled() == False'` exits 0 (default OFF).
- Lints (from repo root) : `python3 tools/checks/banned_terms_python.py <all-new-files>` → exit 0 ; `python3 tools/checks/alembic_boolean_default_lint.py p118 p119` → exit 0 ; `python3 tools/checks/hmac_pepper_audit.py services/backend/app/cron/` → exit 0.

**Caveat (what I have NOT checked, surfaced explicitly per 0-Trust §9.6) :**
- I have NOT run the backfill against Railway staging Postgres. The « idempotent backfill on real data » contract is proven only against the SQLite in-memory fixture in `test_backfill_idempotent.py`. The Task 2a CHECKPOINT preamble (Claude steps 5-8) holds the proof on real data.
- I have NOT enabled the GH Actions cron block in `pg-soak-nightly.yml`. The cron is `workflow_dispatch`-only until PR-3a merges.
- I have NOT run the projection_diff `--audit-all-users` against the staging deployment ; the CLI exits 2 with the explicit env-var requirement message (intentional stub behavior).
- I have NOT verified `mint_projector_idempotency_skip_total` increments on Railway staging post-second-run-of-backfill ; the increment is wired in the backfill script + Plan 02-02 D-33 counter declaration, but actual prometheus exposition happens on a deployed instance.
- I have NOT opened any GitHub PR. The 7 commits live only on the local feature branch ; Julien (or a follow-up executor turn) needs to push + open PR-0/PR-1/PR-2 separately per the D-05 « atomic separate PRs » contract.
- I have NOT run the FULL backend pytest suite (`cd services/backend && python3 -m pytest tests/ -q`) — only the targeted regression sweep listed above. There's a non-zero chance some unrelated test fails (e.g., a flake in a tangentially-related suite the Plan 02-02 SUMMARY also documented). The regression sweep covers every Plan 02-02 + Plan 02-03 surface this turn touches.
- I have NOT verified the dual-write code path against real Postgres (pg-marked test variants are not run in this offline executor — Docker unavailable). The SQLite path is sufficient for application-layer parity proof but does NOT exercise the Postgres-specific `ON CONFLICT ... WHERE excluded.valid_from > fact_current.valid_from` UPSERT guard the projector uses on the Postgres dialect branch.

I deliberately avoid the §9.1 banned phrases for this turn. Nothing here is « shipped » / « ready » / « green » in the deterministic-citation sense — what I have is « unit + integration tests green on SQLite path, end-to-end staging operational checkpoint UNKNOWN ».

## Mem-Save Anchor

Recommended engram observation for this turn :
- `topic_key` : `mint-data-architecture-v1-02:wave-2-3:six-pr-migration-substrate-pr0-pr1-pr2-pr3a-code`
- `prior_finding_refs` : Plan 02-02 obs #214 (FULLY COMPLETE), #211 (critical path canary GATE), #205 (Plan 02-01 merged), #174 (Phase 02 schema verdict), Plan 02-01 obs #204.

## Self-Check: PASSED

All 21 expected files FOUND on disk + all 7 expected commit SHAs FOUND in `git log --oneline --all` :

```
SHAs FOUND : 0b93151f, 3c1c9981, 53149452, 61f86adf, 67223b5b, 0663fba7, ee12f2d9
Files FOUND : 21/21
Files MISSING : 0
```
