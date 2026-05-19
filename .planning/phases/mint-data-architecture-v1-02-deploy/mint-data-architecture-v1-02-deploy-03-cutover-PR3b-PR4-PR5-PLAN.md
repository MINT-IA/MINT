---
phase: mint-data-architecture-v1-02-deploy
plan: 03
type: execute
wave: 2
depends_on: [01, 02]
files_modified:
  # PR-3b atomic trio
  - services/backend/app/api/v1/endpoints/projection.py
  - services/backend/app/api/v1/endpoints/snapshots.py
  - tools/checks/profile_safe_fields_parity.py
  - tools/checks/profile_safe_fields_parity_allowlist.txt
  - lefthook.yml
  - .github/workflows/design-lints.yml
  - tools/db/pre_pr3b_pg_dump.sql
  - .github/workflows/pg-soak-nightly.yml
  - .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-7day-evidence.txt
  - .planning/phases/mint-data-architecture-v1-02-deploy/pre-pr3b-pg-dump-capture.log
  # PR-4 FF removal
  - services/backend/app/services/feature_flags.py
  - services/backend/app/services/snapshots/snapshot_service.py
  - services/backend/app/models/snapshot.py
  - tools/checks/no_ff_fact_event_dual_write.py
  - tools/checks/tests/test_no_ff_fact_event_dual_write.py
  - .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt
  # PR-5 SnapshotModel drop
  - services/backend/alembic/versions/p117_drop_snapshot_legacy.py
  - docs/operations/snapshot-model-decommission.md
  - tools/db/baseline_snapshot_phase02_pre_drop.sql
  - .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt
  - PERIMETERS.md
autonomous: false
requirements:
  - D-05
  - D-12
  - D-31
  - D-32
requirements_addressed:
  - Plan-02-03-iter-2#Task-2b PR-3b atomic trio (read-cutover + Phase-01 D-12 parity-lint SOFT→HARD + pre_pr3b_pg_dump.sql 7th gate B5)
  - Plan-02-03-iter-2#Task-3 PR-4 (FF removal + DeprecationWarning on SnapshotModel writers + no_ff_fact_event_dual_write.py HARD lefthook + drift telemetry)
  - Plan-02-03-iter-2#Task-4 PR-5 (alembic p117_drop_snapshot_legacy + decommission runbook + B19 SnapshotModel-referencing tests inventory + baseline_snapshot_phase02_pre_drop.sql)
  - HANDOFF#Wave-2 cutover flow + 7-day soak window (override per locked decision #4)
  - VALIDATION#Wave-2 PR-3b atomic + 7-day soak + PR-4 FF removal + 1-week observability soak + PR-5 SnapshotModel drop + B19 test inventory
threat_model_ref: mint-data-architecture-v1-02-deploy-RESEARCH#Security-Domain + #Pitfall-5 (override soak) + #Pitfall-6 (drift counter) + engram #194

decisions_locked:
  - id: open-q-4
    locked: "7-day continuous_drift_sampler soak applies OVERRIDE PATH for Phase 02-deploy. Minimum floor : 24h consecutive clean OR 48h sampler ticks clean (48 × 30min = 48 bug-surface opportunities). 0-user-prod premise + 2-test-acct confirmation + Julien sign-off ledger ref = mandatory PR body content."
    rationale: "Phase-decision-lock orchestrator instruction #4 + RESEARCH §Pitfall 5 + iter-2 B20 7-min/14-target + CONTEXT line 41."
  - id: pr-3b-atomicity
    locked: "PR-3b atomic trio = single PR containing (a) read-cutover code + (b) Phase-01 D-12 parity-lint SOFT→HARD flip + (c) pre_pr3b_pg_dump.sql 7th gate file. NEVER split — splitting voids the rollback contract (per Plan 02-03 iter-2 A9 Task 2b contract)."
    rationale: "Plan-02-03 iter-2 4-way reviewer convergence + RESEARCH §Pattern 5 + HANDOFF Wave 2 step 1."
  - id: pr-3b-allowlist
    locked: "tools/checks/profile_safe_fields_parity_allowlist.txt CREATED by PR-3b with EXACTLY 3 Flutter-only field names whitelisted (per Plan 02-04 Task 1 closure path D-10). Wave 3 Plan 04 Task 1 deletes the allowlist after dropping the 3 fields. PR-3b only ENABLES HARD mode with allowlist as transitional state."
    rationale: "Plan 02-03 iter-2 Task 2b contract + Plan 02-04 Task 1 prerequisite + Phase-decision-lock #7 (40 vs 15 baseline scope discipline)."
  - id: pr-5-snapshot-drop
    locked: "PR-5 SnapshotModel drop migration = `p121_drop_snapshot_legacy` (NOT `p117` as Plan 02-03 spec — collision with prior phase ; we use next available)."
    rationale: "Plan 01 Task 1 ships `p120_fact_event_idempotency` ; next available is `p121`. RESEARCH §Project-Structure shows p117 as Plan 02-03 spec but post-Plan-01 ship, p121 is correct."
  - id: cron-lifecycle-active-through-wave-2
    locked: "Per H-3 fix : `continuous_drift_sampler` cron stays ACTIVE throughout PR-3b → PR-4 → PR-5 AND both soak windows (24h-floor pre-PR-3b + 1-week post-PR-4). Deactivation = OPTIONAL Phase 03 cleanup, NOT part of this plan. Threat T-03-06 (cron disabled accidentally during cutover window) mitigated by : (a) Task 1 commits cron activation, (b) Task 2 PR-3b body documents activation status, (c) Task 4 PR-4 body confirms still active, (d) Task 7 CHECKPOINT confirms still active at PR-5 ship time. NO task in this plan deactivates the cron."
    rationale: "Checker iteration 1 H-3 fix — Task 1 commit message + threat T-03-06 + Task 7 CHECKPOINT must be coherent. Cron is the canary observability signal across the entire cutover ; deactivating it mid-flight would surface zero drift signal during the highest-risk window."
  - id: soak-day-1-inline-days-2-7-async
    locked: "Per H-4 fix : Task 4 `<done>` clarifies that Day-1 daily probe runs INLINE during Task 4 execution ; Days 2-7 (or until PR-4 ready to ship) run ASYNC as the cron continues independently ; Julien monitors the soak evidence file appends via Sentry alert + manual probe between Tasks 4 and 5. Task 5 `<resume-signal>` accepts `defer N days — soak in progress` as a valid alternative response. Without this clarification, Task 4-5 boundary is ambiguous : Task 4 stage `<done>` reads completion but soak is still running."
    rationale: "Checker iteration 1 H-4 fix — without explicit async-soak protocol, executor may either (a) wait inline for 7 days (blocks orchestrator for a week), or (b) prematurely call Task 4 done while soak still uncertain. The explicit Day-1 inline + Days-2-N async pattern is consistent with locked decision #4 OVERRIDE PATH 24h floor."

must_haves:
  truths:
    - "Plan 02 Task 2a operational gate signed-off by Julien (PERIMETERS.md ledger entry referenced)."
    - "Continuous_drift_sampler cron activated post-PR-3a merge step (`.github/workflows/pg-soak-nightly.yml` cron uncomment + push) — runs every 30min × 100 staging users × ≥48h before PR-3b ships AND stays active through PR-3b → PR-4 → PR-5 per locked decision `cron-lifecycle-active-through-wave-2`."
    - "PR-3b atomic trio shipped : (a) `app/api/v1/endpoints/projection.py` + `snapshots.py` read from FactCurrent (not SnapshotModel) ; (b) `profile_safe_fields_parity.py --hard` flip in lefthook + design-lints.yml ; (c) `tools/db/pre_pr3b_pg_dump.sql` committed in PR branch as rollback anchor."
    - "7-day soak override exercised per locked decision #4 : PR-3b body contains explicit override rationale + Julien sign-off ledger ref + minimum 24h consecutive clean window verified in `_phase02_parity_audit_continuous`."
    - "PR-3b merged to dev → dev → staging promotion deploys read-cutover to staging postgres-qdyu ; staging /v1/projection now reads FactCurrent path ; `?legacy=true` query-param escape hatch retained for PR-4 transition."
    - "1-week observability soak post-PR-4 (or override per same locked decision) : `mint_snapshot_fact_current_drift_total{field_key}` counter monitored ; PR-4 ships only if soak clean ; Day-1 probe inline + Days 2-7 async per locked decision `soak-day-1-inline-days-2-7-async`."
    - "PR-4 shipped : `FF_FACT_EVENT_DUAL_WRITE` removed from feature_flags.py + snapshot_service.py dual-write branch removed + `DeprecationWarning` on SnapshotModel writers + `tools/checks/no_ff_fact_event_dual_write.py` HARD lefthook + telemetry counter wire confirmed."
    - "PR-5 shipped : alembic `p121_drop_snapshot_legacy` migration + `docs/operations/snapshot-model-decommission.md` runbook + B19 SnapshotModel-referencing tests inventory (`snapshotmodel-tests-inventory.txt` 3-column table) + `baseline_snapshot_phase02_pre_drop.sql` committed."
    - "After PR-5 merge : `grep -rln 'SnapshotModel' services/backend/tests/ | wc -l` returns 0 OR all matches `@pytest.mark.deprecated`."
    - "All 3 PRs Julien-gated between (PR-3b → 24h+ soak → PR-4 → 1-week+ soak → PR-5). NO parallelism."
    - "Cron `continuous_drift_sampler` remains ACTIVE at Task 7 CHECKPOINT time (verified by Julien per cron-lifecycle locked decision)."
  artifacts:
    - path: "tools/db/pre_pr3b_pg_dump.sql"
      provides: "Pre-cutover staging pg_dump (7th gate B5) — committed as part of PR-3b branch"
      contains: "CREATE TABLE fact_event"
      min_lines: 200
    - path: "tools/checks/no_ff_fact_event_dual_write.py"
      provides: "HARD lefthook lint banning any `FF_FACT_EVENT_DUAL_WRITE` re-introduction post-PR-4"
      min_lines: 30
    - path: "services/backend/alembic/versions/p121_drop_snapshot_legacy.py"
      provides: "PR-5 alembic migration dropping snapshots table"
      min_lines: 30
    - path: "docs/operations/snapshot-model-decommission.md"
      provides: "PR-5 decommission runbook (rollback procedure documented)"
      min_lines: 60
    - path: "tools/db/baseline_snapshot_phase02_pre_drop.sql"
      provides: "Pre-PR-5 staging pg_dump of snapshots table (audit anchor before drop)"
      min_lines: 30
    - path: ".planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt"
      provides: "B19 enumeration of Phase 01 tests referencing SnapshotModel + per-test decision (delete/migrate/deprecate)"
      min_lines: 20
    - path: "tools/checks/profile_safe_fields_parity_allowlist.txt"
      provides: "Transitional allowlist (3 Flutter-only fields whitelisted in PR-3b ; deleted Wave 3 Plan 04 Task 1)"
      min_lines: 3
  key_links:
    - from: "services/backend/app/api/v1/endpoints/projection.py"
      to: "services/backend/app/models/fact_current.py"
      via: "Read endpoint switches from SnapshotModel.find_by_user_inputs_hash → FactCurrent PK lookup + decrypt_value"
      pattern: "FactCurrent\\."
    - from: "lefthook.yml"
      to: "tools/checks/no_ff_fact_event_dual_write.py"
      via: "pre-push HARD gate banning FF_FACT_EVENT_DUAL_WRITE re-introduction"
      pattern: "no_ff_fact_event_dual_write"
    - from: "services/backend/alembic/versions/p121_drop_snapshot_legacy.py"
      to: "services/backend/app/models/snapshot.py"
      via: "Migration drops snapshots table ; ORM file deleted in same PR"
      pattern: "op\\.drop_table\\(\"snapshots\"\\)"
    - from: "docs/operations/snapshot-model-decommission.md"
      to: "tools/db/baseline_snapshot_phase02_pre_drop.sql"
      via: "Rollback procedure references baseline anchor for pg_restore on emergency revert"
      pattern: "baseline_snapshot_phase02_pre_drop"
---

<objective>
Wave 2 — operational cutover sequence (PR-3b → 7-day soak → PR-4 → 1-week soak → PR-5).

3 PRs séquentiels, chacun Julien-gated, séparés par 2 soak windows (7-day pre-PR-3b drift sampler + 1-week post-PR-4 observability). Override path documented per locked decision #4 si Julien choisit 24h+ floor.

Purpose : flipper le système de SnapshotModel → fact_current de manière irréversible-mais-rollback-able. Chaque PR a sa baseline pg_dump committed dans le branch. Chaque transition se passe sur staging d'abord (dev→staging auto-deploy), puis prod côté Wave 4 close-out.

Cron lifecycle (per locked decision `cron-lifecycle-active-through-wave-2`) : `continuous_drift_sampler` activé en Task 1 + STAYS ACTIVE throughout PR-3b → PR-4 → PR-5 + both soak windows ; deactivation OPTIONAL Phase 03 cleanup.

Soak protocol (per locked decision `soak-day-1-inline-days-2-7-async`) : Day-1 daily probe inline ; Days-2-7 async (cron continues independently, Julien monitors via Sentry + manual probes between checkpoints). Task 5 `<resume-signal>` accepts `defer N days — soak in progress`.

Output :
- PR-3b atomic trio (read-cutover + Phase-01 D-12 HARD + pre_pr3b_pg_dump.sql)
- PR-4 (FF removal + DeprecationWarning + no_ff_fact_event_dual_write HARD lefthook + drift telemetry)
- PR-5 (alembic p121_drop_snapshot_legacy + decommission runbook + B19 tests inventory + baseline_snapshot_phase02_pre_drop.sql)

Type : `autonomous: false` — 3 Julien CHECKPOINTS (un par PR shipping decision).

Out of scope this plan :
- Mobile L1 device wiring (Wave 3 Plan 04).
- Plan 02-04 Task 1-4 close-out (Wave 3 Plan 04).
- Prod migration apply (Wave 4 Plan 04 close-out).
- 5 sec/arch FLAGs (Wave 3 Plan 04).
- PR D polish (Wave 3 Plan 04 final tasks).
- Cron deactivation (Phase 03 cleanup if ever) — cron stays running through this plan.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/mint-data-architecture-v1-02-deploy/CONTEXT.md
@.planning/phases/mint-data-architecture-v1-02-deploy/HANDOFF-2026-05-19.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-VALIDATION.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-02-staging-migration-apply-PLAN.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md
@services/backend/app/api/v1/endpoints/projection.py
@services/backend/app/api/v1/endpoints/snapshots.py
@services/backend/app/services/feature_flags.py
@services/backend/app/services/snapshots/snapshot_service.py
@services/backend/app/models/snapshot.py
@services/backend/app/models/fact_current.py
@services/backend/app/cron/continuous_drift_sampler.py
@tools/checks/profile_safe_fields_parity.py
@.github/workflows/pg-soak-nightly.yml

<interfaces>
<!-- State after Plan 01 + Plan 02 lands (post-Task 2a Julien-signed). -->

State after Plan 02 Wave 1 close :
- Staging postgres-qdyu : alembic head=p120_fact_event_idempotency, fact_event+fact_current populated by forward-write dual-write (no historical backfill, but ongoing snapshot creations populate both)
- `FF_FACT_EVENT_DUAL_WRITE=on` on staging
- `FF_FACT_EVENT_DUAL_WRITE` UNSET on production (preserved per Wave 4 prereq)
- `_phase02_parity_audit` table on staging populated with 131 rows (Task 2a Step 8)
- `_phase02_parity_audit_continuous` table on staging empty (cron not yet activated)
- Julien sign-off ledger entry in PERIMETERS.md

`services/backend/app/api/v1/endpoints/projection.py` (current — pre-PR-3b) :
- Reads from `SnapshotModel.find_by_user_inputs_hash(user_id, inputs_hash)` (line ~95)
- Returns projection dict shape : `{field_key: value, ...}`
- NO `?legacy=true` query param yet (PR-3b adds the dual-read transitional path)

`services/backend/app/api/v1/endpoints/snapshots.py` (current — pre-PR-3b) :
- Reads from SnapshotModel for direct snapshot access endpoint
- PR-3b switches to FactCurrent + decrypt_value

`services/backend/app/services/feature_flags.py` (current — pre-PR-4) :
- Contains `FF_FACT_EVENT_DUAL_WRITE` class attribute + module-level `is_fact_event_dual_write_enabled()` helper
- PR-4 removes both

`services/backend/app/services/snapshots/snapshot_service.py` (current — pre-PR-4) :
- `create_snapshot()` has `if is_fact_event_dual_write_enabled():` branch that projects via FactProjector
- PR-4 removes the branch + always projects (no FF gate) ; OR removes the branch + drops projection (depends on Plan 02-03 spec interpretation)
- DECISION : PR-4 removes the FF gate + makes projection ALWAYS-ON (since dual-write contract is now permanent post-cutover) + emits DeprecationWarning on the SnapshotModel writer path

`services/backend/app/models/snapshot.py` (current — pre-PR-5) :
- ORM SnapshotModel class definition
- PR-5 deletes the file

`tools/checks/profile_safe_fields_parity.py` (current) :
- Has `--hard` flag implementation
- Supports `--allowlist <path>` flag
- Currently invoked in `lefthook.yml` + `.github/workflows/design-lints.yml` WITHOUT `--hard` (SOFT mode)
- PR-3b flips to `--hard` + adds `--allowlist tools/checks/profile_safe_fields_parity_allowlist.txt`

`.github/workflows/pg-soak-nightly.yml` (current) :
- Cron `*/30 * * * *` COMMENTED OFF by default
- Task 1 of THIS plan uncomments cron block (within Task 1's branch, NOT a separate PR — per Plan 02-03 iter-2 contract)
- Cron stays ACTIVE through PR-3b → PR-4 → PR-5 per locked decision `cron-lifecycle-active-through-wave-2`

`services/backend/app/cron/continuous_drift_sampler.py` (current) :
- 30min × 100 users sampler logic shipped Plan 02-03 substrate
- Persists to `_phase02_parity_audit_continuous` table
- PR B Plan 01 wires `mint_snapshot_fact_current_drift_total{field_key}` increment AFTER each diff

`services/backend/scripts/preflight_zero_user_gate.py` (shipped Plan 02-03 substrate) :
- Required PR-3b body content : preflight stdout exit 0 (or override rationale)

`tools/db/pre_pr3b_pg_dump.sql` :
- Captured RIGHT BEFORE PR-3b read-cutover commit
- Committed in PR-3b branch alongside the code change
- Realistic floor : ≥ 200 lines (staging-qdyu has 34+ tables + indices ; H-8 fix raises threshold from 50 → 200).
</interfaces>
</context>

<decision_locked>
- **Open-Q #4 (7-day soak override)** — LOCKED OVERRIDE PATH : 24h consecutive clean minimum OR 48h continuous_drift_sampler clean. PR-3b commit body MUST contain rationale + Julien sign-off ledger ref.
- **PR-3b atomicity** — LOCKED : 3 changes (read-cutover + HARD lint + pg_dump 7th gate) ship as ONE PR. Splitting voids Plan 02-03 iter-2 Task 2b contract.
- **PR-3b allowlist transitional** — LOCKED : `profile_safe_fields_parity_allowlist.txt` created by PR-3b with EXACTLY 3 Flutter-only fields ; Wave 3 Plan 04 Task 1 deletes the allowlist. Full 40-field drift closure deferred (DEFERRED-02-01-B backlog) per Phase-decision-lock #7.
- **PR-5 migration filename** — LOCKED : `p121_drop_snapshot_legacy.py` (NOT p117 as Plan 02-03 spec — collision avoided post-Plan-01 ship of p120).
- **Open-Q #5 (Sentry alert timing)** — LOCKED : Sentry alert rule scheduled BEFORE Wave 2 PR-3b ; runbook ships in Wave 3 Plan 04 Task 4 but Julien must configure UI before this Plan's PR-3b CHECKPOINT (Task 3). Listed as pre-requisite assertion in Task 1.
- **Cron lifecycle (H-3 fix)** — LOCKED : `continuous_drift_sampler` cron stays ACTIVE Task 1 → Task 7 (PR-3b → PR-4 → PR-5 + both soak windows). Deactivation = OPTIONAL Phase 03 cleanup. Threat T-03-06 mitigated by Task 1 commit + Task 2 PR body + Task 4 PR body + Task 7 CHECKPOINT all-confirming cron active.
- **Soak Day-1-inline + Days-2-7-async (H-4 fix)** — LOCKED : Task 4 ships Day-1 probe inline ; Days 2-7 run async ; Task 5 `<resume-signal>` accepts `defer N days — soak in progress` as valid response. Task 4 `<done>` reads « soak monitoring continues async ; Julien resumes Task 5 after N days ».
</decision_locked>

<tasks>

<task type="auto">
  <name>Task 1 (PR-3a merge step + continuous_drift_sampler cron activation + 24h+ soak window) : Activate cron + monitor + validate Sentry alert wiring pre-Julien-gate</name>
  <files>
    .github/workflows/pg-soak-nightly.yml,
    .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-7day-evidence.txt
  </files>
  <read_first>
    .github/workflows/pg-soak-nightly.yml (cron block to uncomment — lines 21-23),
    services/backend/app/cron/continuous_drift_sampler.py (sampler logic + counter wire from Plan 01 PR B),
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-02-staging-migration-apply-PLAN.md (Plan 02 outcome — Task 2a signed-off),
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md (§Pattern 5 + §Pitfall 5 7-day soak override),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md (lines 776-826 Task 2-helper continuous drift sampler spec)
  </read_first>
  <action>
1. **Verify Plan 02 Task 2a signed-off** (executor STOPS if not) :

```bash
grep -E "approved PR-3a" PERIMETERS.md || { echo "BLOCKED: Plan 02 Task 2a not signed-off in PERIMETERS.md" ; exit 1 ; }
```

2. **Uncomment cron schedule in `.github/workflows/pg-soak-nightly.yml`** :

```yaml
# BEFORE (current state) :
on:
  # schedule:
  #   - cron: '*/30 * * * *'   # ★ COMMENTÉ par défaut, à activer PR-3a merge
  workflow_dispatch:
    ...

# AFTER (Task 1 mutation — uncomment cron block ; cron stays active through Task 7 per locked decision cron-lifecycle-active-through-wave-2) :
on:
  schedule:
    - cron: '*/30 * * * *'   # Activated Wave 2 PR-3a merge — STAYS ACTIVE through PR-3b → PR-4 → PR-5 (Phase 03 cleanup may deactivate)
  workflow_dispatch:
    ...
```

3. **Commit cron activation** (commit message MUST be coherent with locked decision `cron-lifecycle-active-through-wave-2`) :

```bash
git checkout -b feat/p02-deploy-wave2-cron-activation
# (apply the YAML edit above)
git add .github/workflows/pg-soak-nightly.yml
git commit -m "feat(p02-deploy): activate continuous_drift_sampler cron for PR-3b soak window

Per Plan 02-03 iter-2 Task 2-helper contract : cron */30 * * * * runs
sampler against staging postgres-qdyu, persists to _phase02_parity_audit_continuous.

Activation tied to Plan 02 Task 2a Julien sign-off (PERIMETERS.md ledger ref).

LIFECYCLE (per locked decision cron-lifecycle-active-through-wave-2) :
- ACTIVE from this commit onward
- STAYS ACTIVE through PR-3b → PR-4 → PR-5 + both soak windows
- Deactivation = OPTIONAL Phase 03 cleanup (NOT this plan)
- Task 2 PR-3b body documents cron still active
- Task 4 PR-4 body documents cron still active
- Task 7 CHECKPOINT confirms cron still active at PR-5 ship

7-day soak window opens NOW (\$(date -u +%Y-%m-%dT%H:%M:%SZ)).
Override path documented per locked decision #4 — see Task 2 + Task 3 of this plan.

Engram : prior_finding_refs = #233, #249, #194, Plan 02 sign-off"
gh pr create --base dev --head feat/p02-deploy-wave2-cron-activation --title "feat(p02-deploy): activate continuous_drift_sampler cron (Wave 2 prereq)" --body "..."
```

4. **Initialize soak evidence file** :

```bash
cat > .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-7day-evidence.txt << EOF
# Phase 02-deploy Wave 2 — continuous_drift_sampler 7-day soak evidence
# Activated $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Cron : */30 * * * * via .github/workflows/pg-soak-nightly.yml
# Lifecycle : ACTIVE through PR-3b → PR-4 → PR-5 (locked decision cron-lifecycle-active-through-wave-2)

## Soak parameters
- Sample size : 100 random staging users per tick
- Tick frequency : every 30 min
- Target window : 7 days minimum (locked decision #4 OVERRIDE PATH = 24h floor)
- Persist table : _phase02_parity_audit_continuous
- Drift counter : mint_snapshot_fact_current_drift_total{field_key}

## Soak start
- Cron PR sha : {to fill}
- Cron activation timestamp : $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Staging postgres-qdyu fact_event row count at start : {to fill via railway ssh probe}
- Staging postgres-qdyu fact_current row count at start : {to fill}
EOF
```

5. **Monitor sampler activity (5 ticks = 2h30 wall-clock OR run sampler manually via workflow_dispatch to bootstrap data)** :

Either path A or B (Julien decides) :

Path A — Wait for natural cron ticks (5+ ticks = 2.5h+) :
```bash
# Poll the table every 30min for 5 ticks
for tick in 1 2 3 4 5; do
  sleep 1800   # 30 min
  TICK_ROWS=$(railway ssh -e staging --service MINT 'python3 -c "import os, psycopg2; c=psycopg2.connect(os.getenv(\"DATABASE_URL\")); cur=c.cursor(); cur.execute(\"SELECT count(*) FROM _phase02_parity_audit_continuous\"); print(cur.fetchone()[0])"')
  DIRTY_ROWS=$(railway ssh -e staging --service MINT 'python3 -c "import os, psycopg2; c=psycopg2.connect(os.getenv(\"DATABASE_URL\")); cur=c.cursor(); cur.execute(\"SELECT count(*) FROM _phase02_parity_audit_continuous WHERE diff_count > 0\"); print(cur.fetchone()[0])"')
  echo "Tick $tick : $TICK_ROWS total rows, $DIRTY_ROWS dirty" >> staging-soak-7day-evidence.txt
done
```

Path B — Force-trigger workflow_dispatch (faster bootstrap, recommended) :
```bash
gh workflow run pg-soak-nightly.yml -f sample_size=100 -f dry_run=false
gh run watch
# Repeat 3-5 times spaced by 30min OR run with smaller sample_size for faster bootstrap
```

6. **Sentry alert rule pre-requisite check** (per locked decision #5 — Julien-only UI task, surfaces here as soft-blocker) :

```bash
echo "" >> staging-soak-7day-evidence.txt
echo "## Sentry alert rule precondition (Julien-only, locked decision #5)" >> staging-soak-7day-evidence.txt
echo "Per CONTEXT Open-Q #6 + locked decision #5 : Sentry alert rule" >> staging-soak-7day-evidence.txt
echo "  mint_snapshot_fact_current_drift_total > 0 in 24h window" >> staging-soak-7day-evidence.txt
echo "must be configured BEFORE PR-3b Julien CHECKPOINT (Task 3)." >> staging-soak-7day-evidence.txt
echo "Runbook = docs/operations/sentry-alert-config.md (ships Wave 3 Plan 04 Task 4)." >> staging-soak-7day-evidence.txt
echo "" >> staging-soak-7day-evidence.txt
echo "If Sentry rule NOT configured at Task 3 CHECKPOINT time : Julien either" >> staging-soak-7day-evidence.txt
echo "(a) configures inline (5min UI task), OR" >> staging-soak-7day-evidence.txt
echo "(b) defers PR-3b until configured." >> staging-soak-7day-evidence.txt
```

7. **24h+ soak floor check** (per locked decision #4) :

```bash
# After 24h (or override floor), assert _phase02_parity_audit_continuous has clean window
DIRTY_24H=$(railway ssh -e staging --service MINT 'python3 -c "
import os, psycopg2
c = psycopg2.connect(os.getenv(\"DATABASE_URL\")); cur = c.cursor()
cur.execute(\"SELECT count(*) FROM _phase02_parity_audit_continuous WHERE sampled_at > now() - interval '\''24 hours'\'' AND diff_count > 0\")
print(cur.fetchone()[0])
"')

if [ "$DIRTY_24H" = "0" ]; then
  echo "✓ 24h clean window achieved : 0 dirty rows in last 24h" >> staging-soak-7day-evidence.txt
else
  echo "⚠ NOT clean : $DIRTY_24H dirty rows in last 24h — surface to Julien for review" >> staging-soak-7day-evidence.txt
fi
```
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && grep -q "approved PR-3a" PERIMETERS.md && [ -f .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-7day-evidence.txt ] && grep -cE "schedule:\s*$" .github/workflows/pg-soak-nightly.yml && ! grep -E "# schedule:\s*$" .github/workflows/pg-soak-nightly.yml && grep -q "Soak start" .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-7day-evidence.txt && grep -q "STAYS ACTIVE through PR-3b" .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-7day-evidence.txt</automated>
  </verify>
  <acceptance_criteria>
    - `grep "approved PR-3a" PERIMETERS.md` returns ≥ 1 hit (Plan 02 Task 2a signed-off).
    - `.github/workflows/pg-soak-nightly.yml` has `schedule:` block UN-commented (`grep -E "^  schedule:" .github/workflows/pg-soak-nightly.yml` returns ≥ 1 hit + `grep -E "^  # schedule:" .github/workflows/pg-soak-nightly.yml` returns 0 hits).
    - Cron-activation PR opened with commit message containing "STAYS ACTIVE through PR-3b → PR-4 → PR-5" (per locked decision `cron-lifecycle-active-through-wave-2`).
    - PR opened with cron activation commit (`gh pr list --base dev --head feat/p02-deploy-wave2-cron-activation` returns ≥ 1).
    - `.planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-7day-evidence.txt` exists ≥ 20 lines + contains « Soak start » + « Cron activation timestamp » + « Lifecycle : ACTIVE through PR-3b → PR-4 → PR-5 ».
    - At least 5 sampler ticks captured (either via wait OR via workflow_dispatch) — evidence file has « Tick N : ... » entries ≥ 5.
    - 24h+ clean window assertion present in evidence file (either ✓ green OR ⚠ flag for Julien review).
    - Sentry alert rule precondition documented in evidence file with the (a)/(b) decision tree.
    - `_phase02_parity_audit_continuous` table row count > 0 (sampler has produced data).
  </acceptance_criteria>
  <done>
    Cron activated + soak window opened. Cron is locked-active through PR-3b → PR-4 → PR-5 per locked decision. Minimum 24h floor either achieved (✓) or surfaced (⚠) for Julien review. Sentry alert rule precondition flagged. Evidence file ready for Task 2 (PR-3b prep + atomic trio).
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2 (PR-3b prep) : Build atomic trio code + commit pre_pr3b_pg_dump.sql 7th gate</name>
  <files>
    services/backend/app/api/v1/endpoints/projection.py,
    services/backend/app/api/v1/endpoints/snapshots.py,
    tools/checks/profile_safe_fields_parity.py,
    tools/checks/profile_safe_fields_parity_allowlist.txt,
    lefthook.yml,
    .github/workflows/design-lints.yml,
    tools/db/pre_pr3b_pg_dump.sql,
    .planning/phases/mint-data-architecture-v1-02-deploy/pre-pr3b-pg-dump-capture.log,
    services/backend/tests/integration/test_projection_read_cutover.py
  </files>
  <read_first>
    services/backend/app/api/v1/endpoints/projection.py (current — line ~95 SnapshotModel.find_by_user_inputs_hash),
    services/backend/app/api/v1/endpoints/snapshots.py (current — SnapshotModel reads),
    services/backend/app/models/fact_current.py (post-Plan-01 — has latest_event_id col),
    services/backend/app/services/encryption/key_vault.py (decrypt_value helper),
    tools/checks/profile_safe_fields_parity.py (existing --hard + --allowlist flag support),
    lefthook.yml (current SOFT-mode invocation),
    .github/workflows/design-lints.yml (current SOFT-mode invocation),
    tools/db/railway_pg_dump.sh (Plan 01 PR B),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md (lines 714-770 Task 2b how-to-verify VERBATIM)
  </read_first>
  <behavior>
    - test_projection_read_cutover : POST `/v1/projection/$USER_ID` against fresh fact_current row → response shape matches legacy SnapshotModel response (canonical JSON via projection_diff equality assertion).
    - `?legacy=true` query param : POST `/v1/projection/$USER_ID?legacy=true` falls back to SnapshotModel read (transitional path during PR-4 soak window) → assert legacy + new paths return semantically equal (per projection_diff canonical JSON).
    - Phase-01 D-12 parity-lint HARD mode : `python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt` exits 0 (the 3 transitional allowlisted fields permitted).
    - Without --allowlist : `python3 tools/checks/profile_safe_fields_parity.py --hard` exits ≠ 0 (proves the 3 fields are the only remaining drift).
  </behavior>
  <action>
1. **Open PR-3b branch** :

```bash
git checkout -b feat/p02-deploy-pr3b-read-cutover
```

2. **Capture pre-cutover staging pg_dump (7th gate B5)** — RESEARCH §Pattern C step 4 + Plan 02-03 iter-2 Task 2b step 4 + H-8 threshold fix (≥ 200 lines uncompressed for staging-qdyu which has 34+ tables + indices) :

```bash
echo "Capturing pre-PR-3b staging pg_dump baseline ($(date -u +%Y-%m-%dT%H:%M:%SZ))" > .planning/phases/mint-data-architecture-v1-02-deploy/pre-pr3b-pg-dump-capture.log
railway ssh -e staging --service MINT 'pg_dump --no-comments --no-owner --no-privileges --schema-only --data-only $DATABASE_URL' > tools/db/pre_pr3b_pg_dump.sql 2>> .planning/phases/mint-data-architecture-v1-02-deploy/pre-pr3b-pg-dump-capture.log

# Secret guard re-run on captured file (Plan 01 PR B logic)
if grep -E -i "password\\s*[:=]|api_key|secret_key|bearer\\s+|MINT_AUDIT_HASH_PEPPER\\s*=" tools/db/pre_pr3b_pg_dump.sql > /dev/null; then
  echo "BLOCKED: pg_dump contains secrets — review before commit." ; exit 1
fi

DUMP_LINES=$(wc -l < tools/db/pre_pr3b_pg_dump.sql)
echo "pre_pr3b_pg_dump.sql line count : $DUMP_LINES (expected ≥ 200 per H-8 fix — staging-qdyu has 34+ tables + indices)" >> .planning/phases/mint-data-architecture-v1-02-deploy/pre-pr3b-pg-dump-capture.log
if [ "$DUMP_LINES" -lt 200 ]; then
  echo "BLOCKED: pg_dump truncated — only $DUMP_LINES lines (expected ≥ 200 for staging-qdyu schema)" ; exit 1
fi

ls -la tools/db/pre_pr3b_pg_dump.sql >> .planning/phases/mint-data-architecture-v1-02-deploy/pre-pr3b-pg-dump-capture.log
git add tools/db/pre_pr3b_pg_dump.sql .planning/phases/mint-data-architecture-v1-02-deploy/pre-pr3b-pg-dump-capture.log
```

3. **Apply read-cutover to `app/api/v1/endpoints/projection.py`** (verbatim per Plan 02-03 iter-2 Task 2b step 5) :

```python
# BEFORE (line ~95) :
# row = SnapshotModel.find_by_user_inputs_hash(db, user_id, inputs_hash)
# return JSONResponse(content=row.outputs if row else {})

# AFTER (PR-3b read-cutover) :
from app.models.fact_current import FactCurrent
from app.services.encryption.key_vault import decrypt_value

@router.get("/v1/projection/{user_id}")
async def get_projection(user_id: str, legacy: bool = False, db = Depends(get_db)):
    if legacy:
        # Transitional escape hatch — retained during PR-4 soak window, removed Plan 02-04 PR-5
        row = SnapshotModel.find_by_user_inputs_hash(db, user_id, _resolve_inputs_hash(user_id))
        return JSONResponse(content=row.outputs if row else {})

    # NEW (default) : read from FactCurrent + decrypt_value
    fact_rows = db.query(FactCurrent).filter(FactCurrent.user_id == user_id).all()
    projection = {}
    for row in fact_rows:
        try:
            projection[row.field_key] = decrypt_value(row.value_enc, row.dek_id)
        except Exception as e:
            logger.error(f"decrypt_failed user_id={user_id} field={row.field_key}: {e}")
            mint_fact_current_decrypt_failure_total.labels(field_key=row.field_key).inc()
    return JSONResponse(content=projection)
```

4. **Apply same pattern to `app/api/v1/endpoints/snapshots.py`** if it has independent SnapshotModel reads (mirror the dual-path pattern with `?legacy=true` escape hatch).

5. **Flip parity-lint SOFT→HARD with allowlist** :

   a. Create `tools/checks/profile_safe_fields_parity_allowlist.txt` with EXACTLY 3 Flutter-only field names (per locked decision #pr-3b-allowlist) :

```
# tools/checks/profile_safe_fields_parity_allowlist.txt
# Transitional allowlist for Phase 02-deploy PR-3b HARD-mode flip.
# These 3 Flutter-only fields are allowed to fail the parity-lint until Wave 3 Plan 04 Task 1 drops them.
# Reference : Phase-decision-lock #7 + Plan 02-04 D-10 closure.
# Created : 2026-05-19 (PR-3b atomic trio)
# Expected removal : Wave 3 Plan 04 Task 1 (D-10 dead-fields drop).

<flutter-only-field-1>
<flutter-only-field-2>
<flutter-only-field-3>
```

   (Executor : enumerate the 3 actual field names by running `python3 tools/checks/profile_safe_fields_parity.py` in SOFT mode + extracting the « missing-in-server » list ; pick the 3 highest-leverage Flutter-only fields per Plan 02-04 PR-A3 spec.)

   b. Update `lefthook.yml` :

```yaml
pre-commit:
  commands:
    # ... existing rules ...
    profile-safe-fields-parity:
      run: python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt
      glob: "{apps/mobile/lib/services/coach_narrative_service.dart,services/backend/app/api/v1/endpoints/coach_chat.py}"
      fail_text: "Phase-01 D-12 parity-lint HARD : Flutter↔server profile field drift detected. See tools/checks/profile_safe_fields_parity_allowlist.txt for transitional whitelist (drops Wave 3 Plan 04 Task 1)."
```

   c. Update `.github/workflows/design-lints.yml` analogous (add `--hard --allowlist` flag).

6. **Local HARD-mode regression check (per behavior contract)** :

```bash
python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt
# Expected : exit 0
echo $?
```

7. **Add read-cutover integration test** :

```python
# services/backend/tests/integration/test_projection_read_cutover.py
@pytest.mark.requires_pg
def test_projection_endpoint_reads_from_fact_current_default():
    # Seed : fact_current rows for user U
    seed_fact_current(db, user_id="U", field_key="monthly_gross_income", value_enc={"value": "100000"})
    # POST /v1/projection/U (no ?legacy)
    response = client.get("/v1/projection/U")
    assert response.status_code == 200
    assert "monthly_gross_income" in response.json()
    assert response.json()["monthly_gross_income"] == "100000"

@pytest.mark.requires_pg
def test_projection_endpoint_legacy_param_reads_from_snapshot_model():
    # Seed : SnapshotModel row for user U
    seed_snapshot(db, user_id="U", outputs={"monthly_gross_income": "100000"})
    response = client.get("/v1/projection/U?legacy=true")
    assert response.status_code == 200
    assert response.json()["monthly_gross_income"] == "100000"

@pytest.mark.requires_pg
def test_projection_endpoint_canonical_json_equality_dual_path():
    """Verify ?legacy=true and default path return semantically equal (projection_diff canonical JSON)."""
    seed_fact_current(db, user_id="U", field_key="k", value_enc={"v": "x"})
    seed_snapshot(db, user_id="U", outputs={"k": "x"})
    new = client.get("/v1/projection/U").json()
    legacy = client.get("/v1/projection/U?legacy=true").json()
    from tools.parity.projection_diff import canonical_json
    assert canonical_json(new) == canonical_json(legacy)
```

8. **Commit PR-3b atomic trio** (commit body MUST mention cron still active per locked decision `cron-lifecycle-active-through-wave-2`) :

```bash
git add services/backend/app/api/v1/endpoints/projection.py services/backend/app/api/v1/endpoints/snapshots.py tools/checks/profile_safe_fields_parity_allowlist.txt lefthook.yml .github/workflows/design-lints.yml tools/db/pre_pr3b_pg_dump.sql services/backend/tests/integration/test_projection_read_cutover.py .planning/phases/mint-data-architecture-v1-02-deploy/pre-pr3b-pg-dump-capture.log

git commit -m "$(cat <<'EOF'
feat(p02-deploy): PR-3b atomic trio — read-cutover + D-12 HARD + 7th gate pg_dump

Atomic trio per Plan 02-03 iter-2 Task 2b contract (4-way reviewer convergence) :

1. **Read-cutover** : app/api/v1/endpoints/projection.py + snapshots.py switch
   from SnapshotModel.find_by_user_inputs_hash → FactCurrent + decrypt_value.
   ?legacy=true escape hatch retained for PR-4 soak window (removed PR-5).

2. **Phase-01 D-12 parity-lint SOFT→HARD flip** : lefthook.yml + design-lints.yml
   invocations add --hard --allowlist flags. tools/checks/profile_safe_fields_parity_allowlist.txt
   ships with 3 Flutter-only fields whitelisted (transitional ; dropped Wave 3 Plan 04 Task 1
   per D-10 closure path).

3. **Pre-cutover pg_dump 7th gate (B5)** : tools/db/pre_pr3b_pg_dump.sql captured
   right before this commit (staging postgres-qdyu schema+data baseline). Rollback
   procedure : `psql $STAGING_DATABASE_URL < tools/db/pre_pr3b_pg_dump.sql` + revert
   this commit. Documented in docs/operations/snapshot-model-decommission.md (ships PR-5).
   Dump file ≥ 200 lines uncompressed per H-8 fix (staging-qdyu schema floor).

Cron status (per locked decision cron-lifecycle-active-through-wave-2) :
- continuous_drift_sampler ACTIVE since Task 1 cron-activation commit
- STAYS ACTIVE through this PR-3b merge + PR-4 + PR-5
- Soak window evidence in .planning/phases/.../staging-soak-7day-evidence.txt

7-day soak override path applied per locked decision #4 :
- 0-user-prod premise (2 test accounts per CONTEXT line 41 + memory project_byok_scope)
- 2-test-acct empirical confirmation (Julien 2026-05-19)
- Julien sign-off ledger reference : PERIMETERS.md Wave 1 Task 2a entry sha {to fill}
- Minimum 24h floor verified : _phase02_parity_audit_continuous shows 0 dirty rows
  in last 24h adjacent to this commit (see staging-soak-7day-evidence.txt).

Engram prior_finding_refs : #233 (substrate gap), #249 (staging-landed), #194 (deep
security audit), Plan 02 Task 2a sign-off obs, iter-2 A9 4-way convergence.
EOF
)"
gh pr create --base dev --head feat/p02-deploy-pr3b-read-cutover --title "feat(p02-deploy): PR-3b atomic trio — read-cutover + D-12 HARD + 7th gate pg_dump" --body "$(cat <<EOF
## Summary
- Read-cutover atomic with Phase-01 D-12 parity-lint SOFT→HARD flip per Plan 02-03 iter-2 Task 2b.
- 7th gate \`pre_pr3b_pg_dump.sql\` committed (B5, ≥ 200 lines).
- 7-day soak override applied per locked decision #4 (0-user-prod + 2-test-acct + Julien sign-off).
- Cron status : continuous_drift_sampler ACTIVE since Task 1, stays active through PR-5.

## Pre-merge gates
- [x] Plan 02 Task 2a signed-off (PERIMETERS.md ledger ref)
- [x] 24h+ continuous_drift_sampler clean window verified
- [x] HARD-mode parity-lint exits 0 with transitional allowlist
- [x] 3 integration tests for read-cutover + ?legacy=true escape hatch + canonical JSON equality
- [x] pg_dump 7th gate captured (≥ 200 lines) + secret-guard-validated
- [ ] Julien CHECKPOINT (Task 3 of this plan)

## Rollback procedure
\`docs/operations/snapshot-model-decommission.md\` (ships PR-5).
Emergency : \`psql \$STAGING_DATABASE_URL < tools/db/pre_pr3b_pg_dump.sql\` + revert this PR.
EOF
)"
```

9. **Pre-push checklist (per memory `feedback_pre_push_checklist`)** :
   - `grep -rn "SnapshotModel" services/backend/app/api/v1/endpoints/projection.py` returns ≥ 1 hit (legacy path retained for `?legacy=true`).
   - `python3 services/backend/scripts/generate_canonical.py` exits 0 (OpenAPI regen).
   - `cd services/backend && python3 -m pytest tests/ -q --timeout=180` exits 0 BEFORE push.
   - Branch protection : verify `pg-integration` is a required check (Julien-only UI per Plan 01 PR B).
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && [ -f tools/db/pre_pr3b_pg_dump.sql ] && [ $(wc -l < tools/db/pre_pr3b_pg_dump.sql) -ge 200 ] && grep -c "CREATE TABLE fact_event" tools/db/pre_pr3b_pg_dump.sql && grep -c "CREATE TABLE fact_current" tools/db/pre_pr3b_pg_dump.sql && [ -f tools/checks/profile_safe_fields_parity_allowlist.txt ] && [ $(grep -c "^[a-zA-Z_]" tools/checks/profile_safe_fields_parity_allowlist.txt) -eq 3 ] && python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt && grep -c "FactCurrent" services/backend/app/api/v1/endpoints/projection.py && grep -c "?legacy" services/backend/app/api/v1/endpoints/projection.py && cd services/backend && python3 -m pytest tests/integration/test_projection_read_cutover.py -q -k pg --timeout=120</automated>
  </verify>
  <acceptance_criteria>
    - `[ -f tools/db/pre_pr3b_pg_dump.sql ]` returns 0 (file captured).
    - `wc -l tools/db/pre_pr3b_pg_dump.sql` ≥ 200 (per H-8 fix — staging-qdyu has 34+ tables + indices ; previous 50-line threshold was too low).
    - `grep -c "CREATE TABLE fact_event" tools/db/pre_pr3b_pg_dump.sql` ≥ 1 (post-p98 state in dump).
    - `grep -c "CREATE TABLE fact_current" tools/db/pre_pr3b_pg_dump.sql` ≥ 1.
    - `grep -c "CREATE TABLE snapshots" tools/db/pre_pr3b_pg_dump.sql` ≥ 1 (legacy snapshot table still present pre-PR-5).
    - `[ -f tools/checks/profile_safe_fields_parity_allowlist.txt ]` returns 0.
    - `grep -cE "^[a-zA-Z_]" tools/checks/profile_safe_fields_parity_allowlist.txt` = 3 (EXACTLY 3 field names, per locked decision).
    - `python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt` exits 0.
    - Without --allowlist : `python3 tools/checks/profile_safe_fields_parity.py --hard` exits ≠ 0 (proves the 3 fields are the only drift).
    - `grep -c "FactCurrent" services/backend/app/api/v1/endpoints/projection.py` ≥ 2 (import + query).
    - `grep -c "legacy" services/backend/app/api/v1/endpoints/projection.py` ≥ 1 (escape hatch present).
    - `grep -c "decrypt_value" services/backend/app/api/v1/endpoints/projection.py` ≥ 1 (decryption wired).
    - `cd services/backend && python3 -m pytest tests/integration/test_projection_read_cutover.py -q -k pg` exits 0.
    - `cd services/backend && python3 -m pytest tests/ -q --timeout=180` exits 0 (full regression including new tests).
    - `gh pr list --base dev --head feat/p02-deploy-pr3b-read-cutover` returns ≥ 1 PR.
    - PR body contains 7-day soak override rationale + Julien sign-off ledger ref + 24h floor verification.
    - PR body documents cron-lifecycle ACTIVE through PR-3b → PR-5 (per locked decision `cron-lifecycle-active-through-wave-2`).
  </acceptance_criteria>
  <done>
    PR-3b atomic trio code shipped + tests green + pg_dump 7th gate committed (≥ 200 lines) + HARD-mode parity-lint verified with transitional allowlist + cron-lifecycle status documented active. PR open + awaiting Julien CHECKPOINT (Task 3).
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3 (PR-3b Julien CHECKPOINT) : Verify atomic trio + 7-day soak window + override rationale + cron still active + merge PR-3b</name>
  <files>N/A — checkpoint task ; no file mutation by Claude. Julien runs verification steps + types resume-signal.</files>
  <what-built>
    Task 1 + Task 2 deliver :
    - Cron activated (lifecycle ACTIVE through PR-5 per locked decision `cron-lifecycle-active-through-wave-2`) → ≥24h soak floor verified (clean OR ⚠ surfaced).
    - PR-3b branch with atomic trio (read-cutover + D-12 HARD + pg_dump 7th gate ≥ 200 lines) + 3 integration tests green.
    - PR-3b PR opened + body contains override rationale + Julien sign-off ledger ref + cron-lifecycle documentation.
    - Sentry alert rule precondition flagged.
  </what-built>
  <action>
    Checkpoint task — Claude executes no file mutation here. The atomic
    operations (PR builds, evidence file generation, code commits) all live
    in the preceding `type="auto"` tasks of this plan. This checkpoint task
    pauses execution until Julien types the `resume-signal` after running
    the verification steps listed in `<how-to-verify>` below.
  </action>
  <how-to-verify>
    **Julien verifies (in this order, ~15 min)** :

    1. **Open PR-3b on GitHub** : review the atomic trio diff.

    2. **Continuous drift sampler 7-day window** :
       ```bash
       railway ssh -e staging --service MINT 'psql $DATABASE_URL -tAc "
         SELECT date_trunc(\"hour\", sampled_at) AS h, count(*) FILTER (WHERE diff_count > 0) AS dirty
         FROM _phase02_parity_audit_continuous
         WHERE sampled_at > now() - interval \"7 days\"
         GROUP BY 1 ORDER BY 1 DESC;
       "'
       ```
       Assert : zero rows with `dirty > 0` across the window OR at least 24 consecutive hours adjacent to NOW are clean (per locked decision #4 OVERRIDE PATH).

    3. **Re-run 100% staging-user projection_diff audit** :
       ```bash
       railway ssh -e staging --service MINT 'cd /app && python3 -m tools.parity.projection_diff --audit-all-users'
       ```
       Assert : `USERS_WITH_DIFF == 0`.

    4. **Spot-check staging projection endpoint pre/post-cutover on staging PR preview** (Railway PR-deploy URL) :
       ```bash
       USER_ID=<julien-staging-test-uid>
       curl -sf "https://mint-staging-pr-NN.up.railway.app/v1/projection/$USER_ID?legacy=true" > /tmp/legacy.json
       curl -sf "https://mint-staging-pr-NN.up.railway.app/v1/projection/$USER_ID" > /tmp/new.json
       python3 tools/parity/projection_diff.py --pair /tmp/legacy.json /tmp/new.json
       ```
       Assert : exit 0 + stdout `EQUAL`.

    5. **HARD lint local run** :
       ```bash
       python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt; echo $?
       ```
       Assert : exit 0.

    6. **Verify pg_dump 7th gate committed in PR-3b** :
       ```bash
       gh pr view <PR-3b-NUM> --json files | jq '.files[] | select(.path == "tools/db/pre_pr3b_pg_dump.sql")'
       wc -l tools/db/pre_pr3b_pg_dump.sql
       ```
       Assert : file present + non-empty + ≥ 200 lines (H-8 floor).

    7. **Verify cron still active** (per locked decision `cron-lifecycle-active-through-wave-2`) :
       ```bash
       gh workflow view pg-soak-nightly.yml --yaml | grep -E "^\s*-?\s*cron:"
       railway ssh -e staging --service MINT 'psql $DATABASE_URL -tAc "SELECT count(*) FROM _phase02_parity_audit_continuous WHERE sampled_at > now() - interval \"1 hour\""'
       ```
       Assert : cron schedule uncommented + at least 1 sample in last hour (proves cron is firing).

    8. **Verify Sentry alert rule active (locked decision #5)** :
       Julien checks Sentry dashboard : `mint_snapshot_fact_current_drift_total > 0 in 24h window` rule exists.
       If MISSING : configure inline (5 min UI task) OR defer PR-3b.

    9. **Type gate decision**.

    **Gate decision** :
    - All checks pass → `approved PR-3b — 7-day drift sampler clean (or 24h+ floor + override doc'd), parity audit re-run zero diff, pg_dump 7th gate committed (≥200 lines), HARD lint green, cron still active, Sentry alert configured` → Claude merges PR-3b to dev.
    - `<24h soak` or `Sentry rule missing` → describe + Claude addresses (wait OR configure Sentry inline OR defer).
    - `cron not firing` → BLOCKING ; Claude diagnoses (workflow_dispatch test) + re-runs assertion.
    - Any check fails → describe failure mode + Claude ships fix-up commit on PR-3b branch (NOT pre_pr3b_pg_dump.sql — that's append-only).

    **After merge** : record Julien sign-off in PERIMETERS.md ledger, prepare for 1-week observability soak (Task 4).
  </how-to-verify>
  <verify>
    <automated>echo "Checkpoint task — verification is manual by Julien per <how-to-verify> ; this <verify> stub is a structural placeholder. Resume blocked until <resume-signal> received."</automated>
  </verify>
  <acceptance_criteria>
    - [ ] Julien types `<resume-signal>` verbatim (« approved PR-3b — 7-day drift sampler clean, parity audit re-run zero diff, pg_dump 7th gate committed, HARD lint green, Sentry alert configured ») in chat (or alternative `defer N days — {reason}` / failure-mode signal).
    - [ ] PERIMETERS.md ledger entry « Phase 02-deploy Wave 2 PR-3b — APPROVED » committed (commit sha recorded in evidence file + SUMMARY).
    - [ ] No blocker raised in resume signal text — if Julien describes a blocker, Claude opens fix-up commits BEFORE merging PR-3b.
    - [ ] Soak evidence verified : `_phase02_parity_audit_continuous` query shows ≥ 24h consecutive clean window (or 7-day continuous clean).
    - [ ] `pre_pr3b_pg_dump.sql` ≥ 200 lines verified (H-8 floor).
    - [ ] Cron `pg-soak-nightly` confirmed firing (sample in last hour) — per locked decision `cron-lifecycle-active-through-wave-2`.
    - [ ] HARD lint exits 0 with allowlist (3 fields whitelisted).
    - [ ] Sentry alert rule active in Sentry dashboard (or inline-configured by Julien before merge).
    - [ ] PR-3b merged to dev + Railway dev→staging auto-deploy completes (staging serves FactCurrent path).
  </acceptance_criteria>
  <done>
    Julien types the resume-signal after running the <how-to-verify> steps successfully. Claude proceeds to the next task (or records sign-off in PERIMETERS.md per task spec).
  </done>
  <resume-signal>
    Type "approved PR-3b — 7-day drift sampler clean, parity audit re-run zero diff, pg_dump 7th gate committed, HARD lint green, Sentry alert configured" OR "defer N days — {reason}" OR describe failure mode.
  </resume-signal>
</task>

<task type="auto">
  <name>Task 4 (PR-4 prep + 1-week observability soak — Day-1 inline, Days-2-7 async) : Remove FF + ship DeprecationWarning + no_ff_fact_event_dual_write HARD lefthook + monitor drift telemetry</name>
  <files>
    services/backend/app/services/feature_flags.py,
    services/backend/app/services/snapshots/snapshot_service.py,
    services/backend/app/models/snapshot.py,
    tools/checks/no_ff_fact_event_dual_write.py,
    tools/checks/tests/test_no_ff_fact_event_dual_write.py,
    lefthook.yml,
    .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt
  </files>
  <read_first>
    services/backend/app/services/feature_flags.py (current — `FF_FACT_EVENT_DUAL_WRITE` class attr + helper),
    services/backend/app/services/snapshots/snapshot_service.py (current — dual-write FF gate branch),
    services/backend/app/models/snapshot.py (current — ORM class for legacy SnapshotModel ; PR-5 deletes it),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md (Task 3 PR-4 spec),
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md (§Pitfall 6 drift counter)
  </read_first>
  <action>
1. **Verify PR-3b merged on dev** (executor STOPS otherwise) :

```bash
gh pr view <PR-3b-NUM> --json mergedAt --jq '.mergedAt' | grep -qE "^[0-9]" || { echo "BLOCKED: PR-3b not merged" ; exit 1 ; }
grep -E "approved PR-3b" PERIMETERS.md || { echo "BLOCKED: PR-3b sign-off not in PERIMETERS.md" ; exit 1 ; }
```

2. **Open PR-4 branch + apply FF removal** :

```bash
git checkout -b feat/p02-deploy-pr4-ff-removal
```

   a. `services/backend/app/services/feature_flags.py` — remove `FF_FACT_EVENT_DUAL_WRITE` class attribute + module-level helper :

```python
# REMOVE :
# class FeatureFlags:
#     ...
#     FF_FACT_EVENT_DUAL_WRITE: bool = bool_env("FF_FACT_EVENT_DUAL_WRITE", default=False)
#
# def is_fact_event_dual_write_enabled() -> bool:
#     return FeatureFlags.FF_FACT_EVENT_DUAL_WRITE
```

   b. `services/backend/app/services/snapshots/snapshot_service.py` — remove FF gate, make projection always-on, emit DeprecationWarning :

```python
import warnings

def create_snapshot(db, user_id, inputs, ...):
    # REMOVED : if is_fact_event_dual_write_enabled():
    #     project_via_fact_projector(...)

    # NEW : always project (dual-write is now permanent post-cutover)
    project_via_fact_projector(db, user_id, inputs, ...)

    # Emit DeprecationWarning on the SnapshotModel writer path
    # (this path remains active during PR-4 → PR-5 soak window for ?legacy=true reads)
    warnings.warn(
        "SnapshotModel.create() is DEPRECATED — fact_current is the canonical "
        "projection store post-Phase-02-deploy PR-3b cutover. SnapshotModel writes "
        "remain enabled during PR-4 → PR-5 transition for ?legacy=true read path. "
        "Removal : PR-5 alembic p121_drop_snapshot_legacy migration.",
        DeprecationWarning,
        stacklevel=2,
    )
    snapshot = SnapshotModel(user_id=user_id, ...)
    db.add(snapshot)
    db.commit()
    return snapshot
```

3. **Ship `tools/checks/no_ff_fact_event_dual_write.py` HARD lefthook lint** :

```python
#!/usr/bin/env python3
"""no_ff_fact_event_dual_write.py — banned token lint post-PR-4.

Prevents re-introduction of FF_FACT_EVENT_DUAL_WRITE after Phase 02-deploy PR-4
removed the feature flag. The flag was a transitional construct ; post-cutover
the dual-write contract is permanent and must not be re-gated.

Exit 0 if no hits ; exit 1 with file:line citations if any found.
"""
import subprocess
import sys
from pathlib import Path

BANNED_TOKEN = "FF_FACT_EVENT_DUAL_WRITE"
SCAN_ROOTS = ["services/backend/app/", "services/backend/scripts/", "tools/"]

violations = []
for root in SCAN_ROOTS:
    if not Path(root).exists():
        continue
    cmd = ["grep", "-rn", BANNED_TOKEN, root, "--include=*.py", "--include=*.yml", "--include=*.yaml"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    for line in result.stdout.strip().split("\n"):
        if not line:
            continue
        # Exempt this lint file itself
        if "no_ff_fact_event_dual_write" in line:
            continue
        # Exempt the PR-4 commit message stub in CHANGELOG if any
        if "CHANGELOG" in line and "removed" in line.lower():
            continue
        violations.append(line)

if violations:
    print(f"BLOCKED : {len(violations)} files contain '{BANNED_TOKEN}' (post-PR-4 banned token):", file=sys.stderr)
    for v in violations:
        print(f"  {v}", file=sys.stderr)
    sys.exit(1)
print(f"OK : 0 hits for '{BANNED_TOKEN}' in {SCAN_ROOTS}")
sys.exit(0)
```

4. **`tools/checks/tests/test_no_ff_fact_event_dual_write.py` (NEW)** : self-test with seed bad fixture + good fixture.

5. **Update `lefthook.yml`** :

```yaml
pre-commit:
  commands:
    # ... existing rules ...
    no-ff-fact-event-dual-write:
      run: python3 tools/checks/no_ff_fact_event_dual_write.py
      glob: "{services/backend/**/*.py,tools/**/*.py,.github/workflows/**/*.yml}"
      fail_text: "FF_FACT_EVENT_DUAL_WRITE was removed by Phase 02-deploy PR-4 — do not re-introduce."
```

6. **Verify drift telemetry counter increment site present** (PR B Plan 01 work, regression check) :

```bash
grep -rn "mint_snapshot_fact_current_drift_total" services/backend/app/
# Expected : at least one increment site in app/cron/continuous_drift_sampler.py
```

7. **Open PR + commit** (body MUST mention cron still active per locked decision `cron-lifecycle-active-through-wave-2`) :

```bash
git add services/backend/app/services/feature_flags.py services/backend/app/services/snapshots/snapshot_service.py tools/checks/no_ff_fact_event_dual_write.py tools/checks/tests/test_no_ff_fact_event_dual_write.py lefthook.yml
git commit -m "feat(p02-deploy): PR-4 FF_FACT_EVENT_DUAL_WRITE removal + DeprecationWarning + HARD lefthook

Per Plan 02-03 iter-2 Task 3 + locked decision (PR-3b merged + 7-day soak clean).

Removes :
- FeatureFlags.FF_FACT_EVENT_DUAL_WRITE class attribute (feature_flags.py)
- is_fact_event_dual_write_enabled() module-level helper
- FF gate branch in snapshot_service.create_snapshot() — dual-write is now permanent

Adds :
- DeprecationWarning on SnapshotModel writer path (lifetime : PR-4 → PR-5)
- tools/checks/no_ff_fact_event_dual_write.py HARD lefthook lint
- 4 self-tests for the new lint

Drift telemetry counter mint_snapshot_fact_current_drift_total{field_key} declared
by Plan 01 PR B + wired in continuous_drift_sampler.py — verified increment site
in services/backend/app/cron/.

Cron status (per locked decision cron-lifecycle-active-through-wave-2) :
- continuous_drift_sampler STILL ACTIVE since Task 1
- Stays active through this PR-4 merge + post-PR-4 1-week soak + PR-5 merge
- Day-1 probe inline ; Days-2-7 run async per locked decision soak-day-1-inline-days-2-7-async

Soak window opens NOW : continuous_drift_sampler keeps running 30min × 100 users
for ≥1 week (or override per same locked decision #4 minimum 24h floor).

Engram prior_finding_refs : Plan 02 Task 2a sign-off, PR-3b sign-off, #194, #178."
gh pr create --base dev --head feat/p02-deploy-pr4-ff-removal --title "feat(p02-deploy): PR-4 FF removal + DeprecationWarning + HARD lefthook" --body "..."
```

8. **Initialize 1-week observability soak evidence file** (per locked decision `soak-day-1-inline-days-2-7-async`) :

```bash
cat > .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt << EOF
# Phase 02-deploy Wave 2 PR-4 — 1-week observability soak evidence
# Started $(date -u +%Y-%m-%dT%H:%M:%SZ) ; target ≥7 days OR ≥24h floor override
# Protocol : Day-1 probe inline (this Task 4), Days 2-7 async (Julien monitors)

## Drift telemetry monitoring
- Counter : mint_snapshot_fact_current_drift_total{field_key}
- Sentry alert : drift > 0 in 24h window (Julien-configured per locked decision #5)
- Drift sampler : continuous_drift_sampler.py @ 30min × 100 users (still running per cron-lifecycle locked decision)

## Daily probes
EOF
```

9. **Day-1 probe inline** (per locked decision `soak-day-1-inline-days-2-7-async`) — Days 2-7 run async, Julien monitors :

```bash
# Day-1 inline probe (run NOW during Task 4 execution)
echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt
echo "## Day 1 inline probe ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt
curl -sf https://mint-staging.up.railway.app/metrics | grep mint_snapshot_fact_current_drift_total >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt
railway ssh -e staging --service MINT 'psql $DATABASE_URL -tAc "
  SELECT count(*), count(*) FILTER (WHERE diff_count > 0) FROM _phase02_parity_audit_continuous
  WHERE sampled_at > now() - interval '\''24 hours'\''"' >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt
echo "Sentry alert state : (Julien checks dashboard ; ⚠ if fired)" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt

# Days 2-7 protocol (async — Julien appends entries between this task and Task 5 CHECKPOINT)
echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt
echo "## Days 2-7 async monitoring protocol" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt
echo "Cron continues firing (30min × 100 users) ; Sentry alert fires on first dirty row." >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt
echo "Julien probes daily via the same query as Day-1 + appends results below." >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt
echo "Task 5 CHECKPOINT accepts 'defer N days — soak in progress' as a valid resume signal." >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt
```
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && grep -E "approved PR-3b" PERIMETERS.md && [ ! -z "$(git log origin/dev --grep='PR-3b')" ] && grep -c "FF_FACT_EVENT_DUAL_WRITE" services/backend/app/services/feature_flags.py && grep -c "FF_FACT_EVENT_DUAL_WRITE" services/backend/app/services/snapshots/snapshot_service.py && grep -c "DeprecationWarning" services/backend/app/services/snapshots/snapshot_service.py && python3 tools/checks/no_ff_fact_event_dual_write.py && python3 -m pytest tools/checks/tests/test_no_ff_fact_event_dual_write.py -q && grep -c "no-ff-fact-event-dual-write" lefthook.yml && grep -q "Day 1 inline probe" .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt && grep -q "Days 2-7 async monitoring protocol" .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt && cd services/backend && python3 -m pytest tests/ -q --timeout=180</automated>
  </verify>
  <acceptance_criteria>
    - `grep "approved PR-3b" PERIMETERS.md` returns ≥ 1 hit (PR-3b signed-off).
    - `grep -E "^[^#].*FF_FACT_EVENT_DUAL_WRITE" services/backend/app/services/feature_flags.py` returns 0 lines (flag class attr removed ; only comments/docstrings remain if any).
    - `grep -E "^[^#].*FF_FACT_EVENT_DUAL_WRITE" services/backend/app/services/snapshots/snapshot_service.py` returns 0 lines (FF gate branch removed).
    - `grep -c "DeprecationWarning" services/backend/app/services/snapshots/snapshot_service.py` ≥ 1 (warning on SnapshotModel writer path present).
    - `python3 tools/checks/no_ff_fact_event_dual_write.py` exits 0 (no `FF_FACT_EVENT_DUAL_WRITE` token in scanned roots).
    - `python3 -m pytest tools/checks/tests/test_no_ff_fact_event_dual_write.py -q` exits 0 (self-test green : seed bad fixture → exit 1 ; seed good → exit 0).
    - `grep -c "no-ff-fact-event-dual-write" lefthook.yml` ≥ 1 (lefthook rule registered).
    - `grep -rn "mint_snapshot_fact_current_drift_total" services/backend/app/cron/` returns ≥ 1 hit (counter wired in sampler from Plan 01 PR B — regression check).
    - `cd services/backend && python3 -m pytest tests/ -q --timeout=180` exits 0 (full backend regression — no test references removed FF helper).
    - PR-4 PR opened (`gh pr list --base dev --head feat/p02-deploy-pr4-ff-removal` returns ≥ 1) + body mentions cron-lifecycle ACTIVE.
    - 1-week observability soak evidence file initialized (`[ -f .planning/phases/mint-data-architecture-v1-02-deploy/staging-soak-post-pr4-week-evidence.txt ]` returns 0).
    - Day-1 inline probe entry present in soak evidence file (`grep -q "Day 1 inline probe"`) per locked decision `soak-day-1-inline-days-2-7-async`.
    - Days-2-7 async monitoring protocol documented in evidence file.
  </acceptance_criteria>
  <done>
    PR-4 code shipped + tests green + no_ff_fact_event_dual_write HARD lefthook + DeprecationWarning on SnapshotModel writer. 1-week observability soak evidence file initialized + Day-1 probe captured INLINE ; Days-2-7 soak monitoring continues async (cron keeps running per cron-lifecycle locked decision ; Julien resumes Task 5 after N days). PR open + awaiting Julien CHECKPOINT (Task 5).
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 5 (PR-4 Julien CHECKPOINT) : Verify FF removal + 1-week observability soak (or 24h+ override) + drift telemetry clean + cron still active + merge PR-4</name>
  <files>N/A — checkpoint task ; no file mutation by Claude. Julien runs verification steps + types resume-signal.</files>
  <what-built>
    Task 4 delivers :
    - `FF_FACT_EVENT_DUAL_WRITE` removed from feature_flags.py + snapshot_service.py.
    - `DeprecationWarning` on SnapshotModel writer path (active during PR-4 → PR-5 transition).
    - `no_ff_fact_event_dual_write.py` HARD lefthook lint + self-tests.
    - 1-week observability soak evidence file initialized + Day-1 probe captured INLINE.
    - Days 2-7 cron continues ASYNC (per locked decision `soak-day-1-inline-days-2-7-async`).
    - PR-4 PR open awaiting merge.
  </what-built>
  <action>
    Checkpoint task — Claude executes no file mutation here. The atomic
    operations (PR builds, evidence file generation, code commits) all live
    in the preceding `type="auto"` tasks of this plan. This checkpoint task
    pauses execution until Julien types the `resume-signal` after running
    the verification steps listed in `<how-to-verify>` below.
  </action>
  <how-to-verify>
    **Julien verifies (after ≥1-week or override floor, ~15 min)** :

    1. **Open PR-4 on GitHub** : review the FF removal diff + DeprecationWarning + new lint.

    2. **Drift telemetry clean window** :
       ```bash
       railway ssh -e staging --service MINT 'psql $DATABASE_URL -tAc "
         SELECT date_trunc(\"day\", sampled_at) AS d,
                count(*) AS samples,
                count(*) FILTER (WHERE diff_count > 0) AS dirty
         FROM _phase02_parity_audit_continuous
         WHERE sampled_at > now() - interval \"7 days\"
         GROUP BY 1 ORDER BY 1 DESC;
       "'
       ```
       Assert : 7 days × ≥48 samples/day × 0 dirty rows (or override per locked decision #4 — 24h floor).

    3. **Verify `/metrics` mint_snapshot_fact_current_drift_total counter still 0** :
       ```bash
       curl -sf https://mint-staging.up.railway.app/metrics | grep mint_snapshot_fact_current_drift_total
       ```
       Assert : counter total = 0 across all field_keys.

    4. **Verify Sentry alert dashboard** : no `drift_total > 0` alerts fired in 7-day window.

    5. **Verify cron still active** (per locked decision `cron-lifecycle-active-through-wave-2`) :
       ```bash
       railway ssh -e staging --service MINT 'psql $DATABASE_URL -tAc "SELECT count(*) FROM _phase02_parity_audit_continuous WHERE sampled_at > now() - interval \"1 hour\""'
       ```
       Assert : ≥ 1 sample in last hour (cron firing).

    6. **Spot-check staging endpoints post-PR-4 deploy** :
       ```bash
       curl -sf https://mint-staging-pr-NN.up.railway.app/v1/projection/$JULIEN_TEST_UID
       # Expected : reads from FactCurrent (no FF gate involved)
       ```

    7. **Confirm no SnapshotModel writes happen except via legacy path** :
       ```bash
       railway ssh -e staging --service MINT 'psql $DATABASE_URL -tAc "
         SELECT count(*) FROM snapshots WHERE created_at > '\''2026-05-19'\'' - interval '\''1 day'\''
       "'
       ```
       Document growth rate (should be near-zero post-PR-3b read-cutover since most callers use the new path).

    8. **Type gate decision**.

    **Gate decision** :
    - All checks pass → `approved PR-4 — FF removed, 1-week (or 24h+ override) drift telemetry clean, DeprecationWarning on writer, lefthook HARD active, cron still firing` → Claude merges PR-4 to dev.
    - <1-week soak (still in progress) → `defer N days — soak in progress` → Claude waits + re-presents checkpoint after N days (per locked decision `soak-day-1-inline-days-2-7-async`).
    - `cron not firing` → BLOCKING ; Claude diagnoses + re-runs.
    - Any check fails → describe failure mode + Claude ships fix-up commit.

    **After merge** : record sign-off in PERIMETERS.md ; ready for PR-5 prep (Task 6).
  </how-to-verify>
  <verify>
    <automated>echo "Checkpoint task — verification is manual by Julien per <how-to-verify> ; this <verify> stub is a structural placeholder. Resume blocked until <resume-signal> received."</automated>
  </verify>
  <acceptance_criteria>
    - [ ] Julien types `<resume-signal>` verbatim (« approved PR-4 — FF removed, drift telemetry clean, DeprecationWarning on writer, lefthook HARD active ») in chat OR `defer N days — soak in progress` (valid alternative per locked decision `soak-day-1-inline-days-2-7-async`) OR failure-mode description.
    - [ ] PERIMETERS.md ledger entry « Phase 02-deploy Wave 2 PR-4 — APPROVED » committed (commit sha recorded in evidence file + SUMMARY).
    - [ ] No blocker raised in resume signal text (if blocker, Claude addresses BEFORE merging PR-4).
    - [ ] Soak evidence shows ≥ 1-week clean window (or 24h override per locked decision #4).
    - [ ] `mint_snapshot_fact_current_drift_total` counter = 0 confirmed on `/metrics`.
    - [ ] Cron `pg-soak-nightly` confirmed firing (sample in last hour).
    - [ ] No Sentry alert fired during soak window.
    - [ ] PR-4 merged to dev + Railway auto-deploy completes (FF removed code path live on staging).
  </acceptance_criteria>
  <done>
    Julien types the resume-signal after running the <how-to-verify> steps successfully. Claude proceeds to the next task (or records sign-off in PERIMETERS.md per task spec).
  </done>
  <resume-signal>
    Type "approved PR-4 — FF removed, drift telemetry clean, DeprecationWarning on writer, lefthook HARD active" OR "defer N days — soak in progress" OR describe failure mode.
  </resume-signal>
</task>

<task type="auto">
  <name>Task 6 (PR-5 prep) : alembic p121_drop_snapshot_legacy + decommission runbook + B19 SnapshotModel-referencing tests inventory + baseline_snapshot_phase02_pre_drop.sql</name>
  <files>
    services/backend/alembic/versions/p121_drop_snapshot_legacy.py,
    services/backend/app/models/snapshot.py,
    docs/operations/snapshot-model-decommission.md,
    tools/db/baseline_snapshot_phase02_pre_drop.sql,
    .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt,
    services/backend/app/api/v1/endpoints/projection.py,
    services/backend/app/api/v1/endpoints/snapshots.py
  </files>
  <read_first>
    services/backend/app/models/snapshot.py (current ORM — file to delete),
    services/backend/alembic/versions/p120_fact_event_idempotency.py (head — p121 chains off this),
    services/backend/app/api/v1/endpoints/projection.py (has `?legacy=true` escape hatch from PR-3b — PR-5 removes it),
    services/backend/app/api/v1/endpoints/snapshots.py (same),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md (Task 5 PR-5 spec + B19 inventory pattern lines 829-857),
    tools/db/railway_pg_dump.sh (Plan 01 PR B)
  </read_first>
  <action>
1. **Verify PR-4 merged + 1-week soak signed-off** :

```bash
gh pr view <PR-4-NUM> --json mergedAt --jq '.mergedAt' | grep -qE "^[0-9]" || exit 1
grep -E "approved PR-4" PERIMETERS.md || exit 1
```

2. **Open PR-5 branch** :

```bash
git checkout -b feat/p02-deploy-pr5-snapshot-drop
```

3. **B19 tests inventory** (per Plan 02-03 iter-2 Task 5 spec) :

```bash
grep -rln "SnapshotModel" services/backend/tests/ > /tmp/snap_test_inventory.txt
wc -l /tmp/snap_test_inventory.txt
# Expected : 5-20 test files per Plan 02-03 spec ; actual count depends on Phase 02 substrate state
```

   Build the 3-column decision table :

```bash
cat > .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt << EOF
# Phase 02-deploy Wave 2 PR-5 — B19 SnapshotModel-referencing tests inventory
# Generated $(date -u +%Y-%m-%dT%H:%M:%SZ) for PR-5 alembic p121_drop_snapshot_legacy

| test_file | decision | rationale |
|-----------|----------|-----------|
EOF

# For each file, executor decides per Plan 02-03 iter-2 B19 spec :
# - Delete if asserting SnapshotModel-specific behavior invalidated by drop
# - Migrate if asserting behavior post-cutover MUST preserve (rewrite to FactCurrent)
# - Mark deprecated if Phase 01 end-of-life suite
for test_file in $(cat /tmp/snap_test_inventory.txt); do
  CONTEXT=$(grep -A2 "SnapshotModel" "$test_file" | head -10)
  echo "Test : $test_file" >> .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt
  echo "Context : $CONTEXT" >> .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt
  echo "Decision : {delete|migrate|deprecate} — {rationale}" >> .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt
  echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt
done

# Executor MUST fill in each Decision + rationale row before commit.
```

4. **Capture `baseline_snapshot_phase02_pre_drop.sql`** :

```bash
# Use Plan 01 PR B's railway_pg_dump.sh helper, scoped to snapshots table only
railway ssh -e staging --service MINT 'pg_dump --no-comments --no-owner --no-privileges --table snapshots $DATABASE_URL' > tools/db/baseline_snapshot_phase02_pre_drop.sql 2>&1

# Secret guard
if grep -E -i "password\\s*[:=]|api_key|secret_key|bearer\\s+|MINT_AUDIT_HASH_PEPPER\\s*=" tools/db/baseline_snapshot_phase02_pre_drop.sql > /dev/null; then
  echo "BLOCKED: secrets detected" ; exit 1
fi

wc -l tools/db/baseline_snapshot_phase02_pre_drop.sql
grep -c "CREATE TABLE snapshots" tools/db/baseline_snapshot_phase02_pre_drop.sql   # ≥1
git add tools/db/baseline_snapshot_phase02_pre_drop.sql
```

5. **Ship alembic `p121_drop_snapshot_legacy.py`** :

```python
"""p121 drop SnapshotModel legacy

Revision ID: p121_drop_snapshot_legacy
Revises: p120_fact_event_idempotency
Create Date: 2026-XX-XX

PR-5 — SnapshotModel decommission after PR-3b read-cutover + PR-4 FF removal
+ 1-week observability soak clean.

Pre-drop baseline : tools/db/baseline_snapshot_phase02_pre_drop.sql (full snapshots
table dump committed in this PR for audit retention + emergency rollback).

Rollback : docs/operations/snapshot-model-decommission.md
"""
from alembic import op
import sqlalchemy as sa

revision = "p121_drop_snapshot_legacy"
down_revision = "p120_fact_event_idempotency"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Drop FKs first (no CASCADE on user_id since FactCurrent has its own user FK)
    op.drop_table("snapshots")


def downgrade() -> None:
    # Emergency rollback : recreate snapshots table from baseline_snapshot_phase02_pre_drop.sql
    # via psql $STAGING_DATABASE_URL < tools/db/baseline_snapshot_phase02_pre_drop.sql
    # This downgrade() is a no-op stub ; actual restore happens via the SQL file.
    raise RuntimeError(
        "p121 downgrade is manual : psql $DATABASE_URL < tools/db/baseline_snapshot_phase02_pre_drop.sql. "
        "See docs/operations/snapshot-model-decommission.md for emergency rollback procedure."
    )
```

6. **Delete `services/backend/app/models/snapshot.py`** :

```bash
git rm services/backend/app/models/snapshot.py
```

7. **Remove `?legacy=true` escape hatch from endpoints** (PR-5 finalizes the cutover) :

```python
# services/backend/app/api/v1/endpoints/projection.py — remove the legacy branch :
# BEFORE :
# async def get_projection(user_id: str, legacy: bool = False, db = Depends(get_db)):
#     if legacy:
#         row = SnapshotModel.find_by_user_inputs_hash(...)  # remove this branch

# AFTER :
async def get_projection(user_id: str, db = Depends(get_db)):
    # Only FactCurrent path remains
    fact_rows = db.query(FactCurrent).filter(...).all()
    ...
```

   Same for `app/api/v1/endpoints/snapshots.py`.

8. **Ship `docs/operations/snapshot-model-decommission.md`** (≥60 lines per must_haves) :

```markdown
# SnapshotModel Decommission Runbook (Phase 02-deploy PR-5)

## TL;DR
Plan 02-03 PR-5 + Plan 02-deploy Wave 2 close-out : SnapshotModel ORM + `snapshots`
table dropped from staging via alembic p121_drop_snapshot_legacy. FactCurrent is
canonical projection store post-cutover.

## Pre-drop state (verified before PR-5 ships)
- PR-3b read-cutover merged + ≥24h+ soak clean (per locked decision #4 override path)
- PR-4 FF removal merged + 1-week observability soak clean (`mint_snapshot_fact_current_drift_total` = 0)
- B19 tests inventory complete (`.planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt`)
- `tools/db/baseline_snapshot_phase02_pre_drop.sql` committed (full snapshots table dump)
- continuous_drift_sampler cron still active (per cron-lifecycle locked decision)

## Emergency rollback procedure (within 30 days post-PR-5 merge)
If post-PR-5 reads start failing on a previously-projected user-field combination :

1. Identify the user_id from logs.
2. Confirm fact_current row exists : `psql $STAGING_DATABASE_URL -tAc "SELECT * FROM fact_current WHERE user_id = ..."`
3. If row missing : re-project from fact_event :
   `psql $STAGING_DATABASE_URL -tAc "SELECT * FROM fact_event WHERE user_id = ... ORDER BY recorded_at DESC LIMIT 5"`
   Run `services/backend/scripts/reproject_fact_event_to_fact_current.py --user-id ...`
4. If fact_event ALSO missing : emergency restore snapshots table from baseline :
   `psql $STAGING_DATABASE_URL < tools/db/baseline_snapshot_phase02_pre_drop.sql`
5. Revert PR-5 on dev + re-deploy.

## Post-30-day cleanup (Phase 03)
After 30 days of stable post-PR-5 operation (zero rollback invocations) :
- Delete `tools/db/baseline_snapshot_phase02_pre_drop.sql` (retention period elapsed).
- Delete this runbook (operation completed).
- Update SUMMARY.md with the decommission close-out.

## Counter-arguments
1. « We should keep the SnapshotModel table forever for audit. »
   Rejeté : audit lives in `fact_event` table (append-only, crypto-shred-able via DEK envelope).
   SnapshotModel duplicate is redundant + maintenance burden.

2. « 30-day rollback window is too short for Swiss financial compliance. »
   Accept : compliance audit retention is on `fact_event` (10-year per D-07).
   `baseline_snapshot_phase02_pre_drop.sql` is a SAFETY anchor for unforeseen post-cutover
   bugs, not a compliance artifact.

## Data gaps
- None known at PR-5 ship time. The 1-week observability soak + projection_diff full
  audit + drift counter zero state collectively rule out the dominant risk vectors.
```

9. **Update Project Pre-push checklist** :
   - `git grep "SnapshotModel" services/backend/app/` returns 0 lines (except deleted file & runbook).
   - `cd services/backend && alembic upgrade head` + `alembic downgrade -1` cycle exits 0.
   - `cd services/backend && python3 -m pytest tests/ -q --timeout=180` exits 0 (verify B19 tests are properly deleted/migrated/deprecated).
   - `grep -rln "SnapshotModel" services/backend/tests/ | wc -l` returns 0 (per Plan 02-03 iter-2 acceptance) OR all matches `@pytest.mark.deprecated`.

10. **Commit PR-5 + open PR** :

```bash
git add services/backend/alembic/versions/p121_drop_snapshot_legacy.py docs/operations/snapshot-model-decommission.md tools/db/baseline_snapshot_phase02_pre_drop.sql .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt services/backend/app/api/v1/endpoints/projection.py services/backend/app/api/v1/endpoints/snapshots.py
# git rm services/backend/app/models/snapshot.py already staged
# Plus B19 tests : delete / migrate / deprecate per inventory decisions

git commit -m "feat(p02-deploy): PR-5 SnapshotModel drop + decommission runbook + B19 inventory

Per Plan 02-03 iter-2 Task 5 contract (PR-4 merged + 1-week observability soak clean).

Drops :
- snapshots table via alembic p121_drop_snapshot_legacy
- app/models/snapshot.py ORM file
- ?legacy=true escape hatch from app/api/v1/endpoints/projection.py + snapshots.py

Adds :
- docs/operations/snapshot-model-decommission.md emergency rollback runbook
- tools/db/baseline_snapshot_phase02_pre_drop.sql pre-drop staging baseline
- .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt B19 inventory

B19 tests : <N> files inventoried, <X> deleted, <Y> migrated to FactCurrent, <Z> deprecated.

Cron status (per locked decision cron-lifecycle-active-through-wave-2) :
- continuous_drift_sampler STILL ACTIVE since Task 1 — observability canary preserved
- Deactivation = OPTIONAL Phase 03 cleanup (NOT this PR)

Engram prior_finding_refs : PR-3b sign-off, PR-4 sign-off, #194, #233."
gh pr create --base dev --head feat/p02-deploy-pr5-snapshot-drop --title "feat(p02-deploy): PR-5 SnapshotModel drop + decommission runbook + B19 inventory" --body "..."
```
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && grep -q "approved PR-4" PERIMETERS.md && [ -f services/backend/alembic/versions/p121_drop_snapshot_legacy.py ] && grep -c "drop_table\\(.snapshots.\\)" services/backend/alembic/versions/p121_drop_snapshot_legacy.py && [ ! -f services/backend/app/models/snapshot.py ] && [ -f docs/operations/snapshot-model-decommission.md ] && [ $(wc -l < docs/operations/snapshot-model-decommission.md) -ge 60 ] && [ -f tools/db/baseline_snapshot_phase02_pre_drop.sql ] && grep -c "CREATE TABLE snapshots" tools/db/baseline_snapshot_phase02_pre_drop.sql && [ -f .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt ] && [ $(wc -l < .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt) -ge 20 ] && [ -z "$(grep -rn 'legacy' services/backend/app/api/v1/endpoints/projection.py)" ] && cd services/backend && alembic upgrade head && alembic downgrade -1 2>&1 | grep -q "manual" && alembic upgrade head && python3 -m pytest tests/ -q --timeout=180 && cd /Users/julienbattaglia/Desktop/MINT.nosync && [ $(grep -rln "SnapshotModel" services/backend/tests/ | wc -l) -eq 0 ]</automated>
  </verify>
  <acceptance_criteria>
    - `grep "approved PR-4" PERIMETERS.md` returns ≥ 1 hit (PR-4 signed-off).
    - `[ -f services/backend/alembic/versions/p121_drop_snapshot_legacy.py ]` returns 0.
    - `grep -c "op.drop_table.*snapshots" services/backend/alembic/versions/p121_drop_snapshot_legacy.py` ≥ 1 (drop_table call present).
    - `[ ! -f services/backend/app/models/snapshot.py ]` returns 0 (file deleted).
    - `[ -f docs/operations/snapshot-model-decommission.md ]` returns 0 + `wc -l` ≥ 60.
    - `[ -f tools/db/baseline_snapshot_phase02_pre_drop.sql ]` returns 0.
    - `grep -c "CREATE TABLE snapshots" tools/db/baseline_snapshot_phase02_pre_drop.sql` ≥ 1.
    - `[ -f .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt ]` returns 0 + `wc -l` ≥ 20 (inventory non-trivial).
    - `grep -rn "legacy" services/backend/app/api/v1/endpoints/projection.py` returns 0 lines (escape hatch removed).
    - `cd services/backend && alembic upgrade head` exits 0 ; `alembic current` shows `p121_drop_snapshot_legacy`.
    - `alembic downgrade -1` raises `RuntimeError` with manual rollback instruction (per migration code).
    - `cd services/backend && python3 -m pytest tests/ -q --timeout=180` exits 0 (full regression — B19 tests properly handled).
    - `grep -rln "SnapshotModel" services/backend/tests/ | wc -l` returns 0 OR all matches `@pytest.mark.deprecated`.
    - `git grep "from app.models.snapshot import" services/backend/app/` returns 0 hits (no stale imports).
    - PR-5 PR opened + body mentions cron-lifecycle ACTIVE preserved.
    - PR description includes 3-column B19 inventory table.
  </acceptance_criteria>
  <done>
    PR-5 code shipped : alembic p121 drops snapshots table, ORM file deleted, `?legacy=true` escape hatch removed, decommission runbook + pre-drop baseline + B19 inventory committed. Cron-lifecycle preserved (still active per locked decision). PR open + awaiting Julien CHECKPOINT (Task 7).
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 7 (PR-5 Julien CHECKPOINT) : Final cutover verification + cron-lifecycle confirmation + Wave 2 close-out</name>
  <files>N/A — checkpoint task ; no file mutation by Claude. Julien runs verification steps + types resume-signal.</files>
  <what-built>
    Task 6 delivers :
    - alembic p121_drop_snapshot_legacy.py migration.
    - app/models/snapshot.py deleted + `?legacy=true` escape hatch removed.
    - docs/operations/snapshot-model-decommission.md runbook (≥60 lines).
    - tools/db/baseline_snapshot_phase02_pre_drop.sql committed.
    - snapshotmodel-tests-inventory.txt 3-column B19 table.
    - Cron-lifecycle preserved : continuous_drift_sampler still active (per locked decision `cron-lifecycle-active-through-wave-2`).
    - PR-5 PR open.
  </what-built>
  <action>
    Checkpoint task — Claude executes no file mutation here. The atomic
    operations (PR builds, evidence file generation, code commits) all live
    in the preceding `type="auto"` tasks of this plan. This checkpoint task
    pauses execution until Julien types the `resume-signal` after running
    the verification steps listed in `<how-to-verify>` below.
  </action>
  <how-to-verify>
    **Julien verifies (~15 min)** :

    1. **Open PR-5 on GitHub** : review diff (migration + ORM delete + endpoint cleanup + runbook + B19 inventory).

    2. **Confirm fact_current covers all known projections** :
       ```bash
       railway ssh -e staging --service MINT 'psql $DATABASE_URL -tAc "
         SELECT field_key, count(*) FROM fact_current GROUP BY 1 ORDER BY 2 DESC LIMIT 20
       "'
       ```
       Spot-check : top field_keys match historical SnapshotModel usage patterns.

    3. **Final 100% staging-user projection_diff sanity** :
       ```bash
       railway ssh -e staging --service MINT 'cd /app && python3 -m tools.parity.projection_diff --audit-all-users'
       ```
       Assert : `USERS_WITH_DIFF == 0`.

    4. **Verify baseline anchor + runbook before merge** :
       ```bash
       ls -la tools/db/baseline_snapshot_phase02_pre_drop.sql
       cat docs/operations/snapshot-model-decommission.md | head -30
       ```

    5. **Verify B19 inventory completeness** :
       ```bash
       cat .planning/phases/mint-data-architecture-v1-02-deploy/snapshotmodel-tests-inventory.txt
       # Every test file has a decision (delete/migrate/deprecate) + rationale
       ```

    6. **Confirm cron still active** (per locked decision `cron-lifecycle-active-through-wave-2` — this is the final-stage verification before Wave 2 close) :
       ```bash
       gh workflow view pg-soak-nightly.yml --yaml | grep -E "^\s*-?\s*cron:"
       railway ssh -e staging --service MINT 'psql $DATABASE_URL -tAc "SELECT count(*) FROM _phase02_parity_audit_continuous WHERE sampled_at > now() - interval \"1 hour\""'
       ```
       Assert : cron schedule uncommented + at least 1 sample in last hour. If cron has been disabled accidentally → BLOCKING ; re-enable before merging PR-5.

    7. **Type gate decision**.

    **Gate decision** :
    - All checks pass → `approved PR-5 — SnapshotModel dropped, fact_current canonical, runbook + baseline + B19 inventory complete, cron still active` → Claude merges PR-5 to dev.
    - Spot-check fails → describe + Claude diagnoses (likely a missed migration of a SnapshotModel test, or a forgotten endpoint).
    - `cron not firing` → BLOCKING (T-03-06 mitigation) ; Claude re-enables cron + re-runs.

    **After merge — Wave 2 close-out** :
    - Record sign-off in PERIMETERS.md (3rd entry for this plan : Task 3 PR-3b + Task 5 PR-4 + Task 7 PR-5).
    - Update STATE.md Wave 2 status from 🚧 to ◆.
    - Forward signal : Wave 3 Plan 04 ready to start (Plan 02-04 tasks + Mobile L1 + 5 FLAGs + prod migration apply).
    - Cron stays active going into Wave 3 ; Plan 04 may optionally deactivate as Phase 03 cleanup.
  </how-to-verify>
  <verify>
    <automated>echo "Checkpoint task — verification is manual by Julien per <how-to-verify> ; this <verify> stub is a structural placeholder. Resume blocked until <resume-signal> received."</automated>
  </verify>
  <acceptance_criteria>
    - [ ] Julien types `<resume-signal>` verbatim (« approved PR-5 — SnapshotModel dropped, fact_current canonical, runbook + baseline + B19 inventory complete ») in chat (or failure-mode description).
    - [ ] PERIMETERS.md ledger entry « Phase 02-deploy Wave 2 PR-5 — APPROVED » committed (commit sha recorded in evidence file + SUMMARY). This is the 3rd PERIMETERS.md entry for this plan (PR-3b + PR-4 + PR-5).
    - [ ] No blocker raised in resume signal text — if Julien describes blocker, Claude addresses BEFORE merging PR-5.
    - [ ] Cron `pg-soak-nightly` confirmed firing at Task 7 verification time (per locked decision `cron-lifecycle-active-through-wave-2`).
    - [ ] `projection_diff --audit-all-users` returns USERS_WITH_DIFF=0 final sanity check.
    - [ ] `baseline_snapshot_phase02_pre_drop.sql` committed in PR-5 branch + non-empty.
    - [ ] B19 inventory complete (every test file has a decision + rationale).
    - [ ] PR-5 merged to dev + Railway auto-deploy completes (snapshots table dropped on staging).
    - [ ] STATE.md Wave 2 status flipped from 🚧 to ◆.
    - [ ] Wave 3 Plan 04 ready to start (forward signal).
  </acceptance_criteria>
  <done>
    Julien types the resume-signal after running the <how-to-verify> steps successfully. Claude proceeds to the next task (or records sign-off in PERIMETERS.md per task spec).
  </done>
  <resume-signal>
    Type "approved PR-5 — SnapshotModel dropped, fact_current canonical, runbook + baseline + B19 inventory complete" OR describe failure mode.
  </resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| `services/backend/app/api/v1/endpoints/projection.py` read path switch | Atomic flip from SnapshotModel → FactCurrent ; rollback requires PR revert + pg_restore from `tools/db/pre_pr3b_pg_dump.sql`. |
| `?legacy=true` escape hatch lifecycle | Active during PR-3b → PR-5 (transitional). Removal in PR-5 finalizes cutover. |
| `FF_FACT_EVENT_DUAL_WRITE` removal (PR-4) | One-way operation — `no_ff_fact_event_dual_write.py` HARD lefthook prevents re-introduction. |
| `tools/db/pre_pr3b_pg_dump.sql` + `baseline_snapshot_phase02_pre_drop.sql` committed | Append-only rollback anchors ; never deleted within 30-day window per runbook. |
| Continuous_drift_sampler 30min × 100 users | Cron schedule activation tied to PR-3a merge step (Task 1) ; STAYS ACTIVE through PR-3b → PR-4 → PR-5 + both soak windows (per locked decision `cron-lifecycle-active-through-wave-2`) ; deactivation = OPTIONAL Phase 03 cleanup. Tasks 1+2+4+6+7 all reference cron-lifecycle for coherent enforcement. |

## STRIDE Threat Register (ASVS L1 + engram #194 deep audit)

| Threat ID | Category | Component | Severity | Disposition | Mitigation |
|-----------|----------|-----------|----------|-------------|------------|
| T-03-01 | Tampering | PR-3b atomic trio split into multiple PRs voids rollback contract | high | mitigate | Locked decision #pr-3b-atomicity + Plan 02-03 iter-2 Task 2b contract enforce single-PR ship ; PR template/CHECKLIST in PR-3b body. |
| T-03-02 | Tampering | Read-cutover happens but `?legacy=true` escape hatch broken → users on old path 500 | high | mitigate | Task 2 ships 3 integration tests including `?legacy=true` path verification ; Task 3 Julien CHECKPOINT spot-checks both paths. |
| T-03-03 | Tampering | HMAC-pepper drift between sampler + decrypt path leaks to drift counter | medium | mitigate | Plan 01 PR A3 `test_hmac_pepper_rotation.py` exercises lru_cache(maxsize=1) interaction ; sampler reads same pepper as projection endpoint. |
| T-03-04 | Tampering | `projection_diff.py` non-determinism in canonical JSON causes false positives in drift counter | high | mitigate | Plan 02 Task 2 Step 9.5 runs `projection_diff.py --self-test` (12 fixtures) ; iter-2 A10 canonical contract verified. |
| T-03-05 | Tampering | 7-day soak override accepted without documented rationale | medium | mitigate | Locked decision #4 + PR-3b commit message template REQUIRES rationale + Julien sign-off ledger ref ; Task 3 CHECKPOINT verifies. |
| T-03-06 | Tampering | continuous_drift_sampler cron disabled accidentally during PR-3b → PR-5 window | high | mitigate | Per locked decision `cron-lifecycle-active-through-wave-2` : Task 1 commit message documents lifecycle ; Task 2 PR-3b body documents activation status ; Task 4 PR-4 body confirms still active ; Task 6 PR-5 body confirms still active ; Task 7 CHECKPOINT step 6 mechanically asserts cron firing (sample in last hour) and BLOCKS PR-5 merge if cron disabled. Defense-in-depth across 5 task touchpoints. Deactivation = OPTIONAL Phase 03 cleanup, NEVER in this plan. |
| T-03-07 | Tampering | `tools/db/pre_pr3b_pg_dump.sql` deleted accidentally | medium | mitigate | Committed in PR-3b branch as part of atomic trio ; gitignore'd from any cleanup script ; runbook references it explicitly. Per H-8 fix : ≥ 200 lines threshold (was 50). |
| T-03-08 | Repudiation | Drift counter declared but never fires (Pitfall 6) | high | mitigate | Plan 01 PR B step 1 declares counter ; Task 4 verifies grep-in-app/ presence ; Wave 3 Plan 04 Task 3 `declared_counters_must_fire.py` HARD gate. |
| T-03-09 | Spoofing | DeprecationWarning suppressed by global filter | low | mitigate | Task 4 uses `warnings.warn(..., DeprecationWarning, stacklevel=2)` — stacklevel ensures caller-attributable ; pytest captures warnings by default. |
| T-03-10 | Tampering | Baseline `pg_dump` contains DEK plaintexts | high | mitigate | DEKs are wrapped in `dek_envelope` via KMS — `pg_dump` exports wrapped form ; plaintext DEKs never live in DB. Secret guard in Plan 01 PR B `railway_pg_dump.sh` confirms no plaintext leaks. |
| T-03-11 | Information disclosure | B19 inventory file lists test file paths that reveal internal structure | low | accept | Test paths are already public via repo browsing ; inventory file is internal `.planning/` content not externally exposed. |
| T-03-12 | Tampering | alembic p121 downgrade auto-restore via downgrade() would mis-restore data | high | mitigate | p121 `downgrade()` deliberately raises RuntimeError with manual rollback pointer to `baseline_snapshot_phase02_pre_drop.sql` ; prevents `alembic downgrade -1` from running auto-failed-state restore. |
| T-03-13 | Tampering | SnapshotModel-referencing test rewriting introduces regressions | medium | mitigate | Task 6 step 9 pre-push checklist runs full pytest + grep regression check ; Task 7 CHECKPOINT confirms via spot-check. |
| T-03-14 | Spoofing | Julien sign-off forged | medium | accept | Git history attribution + PERIMETERS.md ledger commit sha auditable ; mitigation procedural per CLAUDE.md §9. |
| T-03-15 | Tampering | DSAR / right-to-erasure interaction with fact_event log | high | accept | Sec FLAG-4 DSAR manifest event_log inclusion deferred to Wave 3 Plan 04 ; Phase 02 substrate D-07 documents retention + crypto-shred-via-DEK-revoke ; emergency DSAR procedure : revoke DEK + the event_log row becomes opaque (audit trail preserved structurally). |
</threat_model>

<verification>
**Phase-level checks for this plan :**

1. **`autonomous: false`** — 3 Julien CHECKPOINTS (Task 3 PR-3b + Task 5 PR-4 + Task 7 PR-5).
2. **Sequential strict** : PR-3b → soak ≥24h → PR-4 → soak ≥24h-floor (1-week target) → PR-5. NEVER parallel.
3. **Each PR has rollback anchor** : PR-3b ships `pre_pr3b_pg_dump.sql` (≥ 200 lines per H-8) ; PR-4 has revert path (re-introduce FF) ; PR-5 ships `baseline_snapshot_phase02_pre_drop.sql` + runbook.
4. **0-trust §9 strict** : 3 sign-off entries in PERIMETERS.md ; each PR body cites deterministic evidence ; no « shipped » claim about Wave 2 until Task 7 close.
5. **Continuous drift sampler lifecycle** (per locked decision `cron-lifecycle-active-through-wave-2`) : ACTIVE Task 1 → Task 7 ; coherent across Task 1 commit + Task 2 PR body + Task 4 PR body + Task 6 PR body + Task 7 CHECKPOINT step 6 ; deactivation = OPTIONAL Phase 03 cleanup, NOT this plan.
6. **Soak protocol** (per locked decision `soak-day-1-inline-days-2-7-async`) : Day-1 inline at Task 4 ; Days-2-7 async ; Task 5 `<resume-signal>` accepts `defer N days — soak in progress` as valid alternative.
7. **Pre-push checklist applied per PR** : grep callers + regen OpenAPI + full pytest + lint suite + lefthook regression (memory `feedback_pre_push_checklist`).
8. **Engram contract** : `mem_save` at end of each PR's task with topic_key per-PR + prior_finding_refs accumulating.
</verification>

<success_criteria>
- [ ] Plan 02 Task 2a signed-off (PERIMETERS.md entry verified Task 1).
- [ ] continuous_drift_sampler cron activated + 24h+ floor clean window (Task 1).
- [ ] Cron-lifecycle ACTIVE through PR-3b → PR-4 → PR-5 documented in Task 1 commit + Task 2 PR body + Task 4 PR body + Task 6 PR body (per H-3 fix locked decision).
- [ ] PR-3b atomic trio shipped : read-cutover + D-12 HARD + 7th gate pg_dump ≥ 200 lines (Task 2-3, H-8 floor).
- [ ] PR-3b Julien-signed in PERIMETERS.md (Task 3 resume signal received).
- [ ] PR-4 shipped : FF removed + DeprecationWarning + no_ff_fact_event_dual_write HARD lefthook + drift telemetry wired (Task 4-5).
- [ ] PR-4 Julien-signed (Task 5 resume signal — may include `defer N days — soak in progress` per H-4 fix).
- [ ] 1-week observability soak Day-1 inline + Days-2-7 async clean OR override floor (Task 4 Day-1 probe + Julien async monitoring).
- [ ] PR-5 shipped : alembic p121 + ORM delete + escape hatch removed + runbook + baseline + B19 inventory (Task 6-7).
- [ ] PR-5 Julien-signed (Task 7 resume signal).
- [ ] Task 7 CHECKPOINT step 6 confirms cron still firing at PR-5 ship time (T-03-06 mitigation).
- [ ] `grep -rln "SnapshotModel" services/backend/tests/ | wc -l` returns 0 OR all `@pytest.mark.deprecated`.
- [ ] `grep -rn "SnapshotModel" services/backend/app/` returns 0 hits (post-PR-5 — except runbook references).
- [ ] Full backend pytest suite green post-each-PR.
- [ ] 3 PERIMETERS.md ledger entries (one per PR).
- [ ] All threats in STRIDE register have a disposition.
- [ ] Engram observations saved per-PR with cross-references.
</success_criteria>

<output>
After completion, ensure :
- `.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-03-cutover-PR3b-PR4-PR5-SUMMARY.md` (per-task receipt) exists.
- 7 evidence/artifact files committed across the 3 PRs :
  - `staging-soak-7day-evidence.txt` (Task 1)
  - `pre-pr3b-pg-dump-capture.log` + `tools/db/pre_pr3b_pg_dump.sql` (≥ 200 lines, H-8 floor) + `tools/checks/profile_safe_fields_parity_allowlist.txt` (Task 2)
  - `staging-soak-post-pr4-week-evidence.txt` (Day-1 inline + Days-2-7 async protocol, H-4 fix) + `tools/checks/no_ff_fact_event_dual_write.py` (Task 4)
  - `tools/db/baseline_snapshot_phase02_pre_drop.sql` + `docs/operations/snapshot-model-decommission.md` + `snapshotmodel-tests-inventory.txt` (Task 6)
- 3 PERIMETERS.md ledger entries (PR-3b sign-off + PR-4 sign-off + PR-5 sign-off).
- 0-trust §9.6 Evidence + Caveat block in SUMMARY listing : Evidence = 3 PR shas + 3 sign-off ledger entries + 2 pg_dump baselines + drift telemetry clean window verification + cron-lifecycle ACTIVE verified at Task 7 step 6. Caveat = (a) prod NOT yet migrated (Wave 4), (b) Mobile L1 device wiring NOT shipped (Wave 3 Plan 04), (c) Sentry alert rule lifecycle dependency, (d) `baseline_snapshot_phase02_pre_drop.sql` retention 30 days only (Phase 03 cleanup), (e) cron deactivation deferred to OPTIONAL Phase 03 cleanup (per H-3 fix locked decision).
- `mem_save` calls per-PR with `topic_key: mint-data-architecture-v1-02-deploy:wave-2:pr-{3b,4,5}-shipped-{date}` + `prior_finding_refs` accumulating across PRs.
- Forward-deferred items list : Wave 3 Plan 04 work + prod cutover (Wave 4) + cron deactivation (OPTIONAL Phase 03).
</output>
</content>
</invoke>