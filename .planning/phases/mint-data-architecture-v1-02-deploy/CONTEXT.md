---
phase: mint-data-architecture-v1-02-deploy
type: phase-context
status: open-bootstrap
opened: 2026-05-19
depends_on: mint-data-architecture-v1-02-event-log-projection
blocks: phase-03-coach-extractor
load_bearing_premise: engram obs #233 — Phase 02 substrate is code-only on dev, staging+prod alembic chains lag dev
description: |
  Phase 02-deploy is the sibling phase to mint-data-architecture-v1-02-event-log-projection.
  Where the substrate phase shipped the EVENT-LOG CODE on dev, this phase ships
  the OPERATIONAL CUTOVER : alembic chain audit (prod at 29_05_magic_link_tokens
  head, staging at p112_audit_event_user_hash head — both behind dev p119
  by 7+ to dozens of revs) + staging migration apply with smoke + Task 2a
  operational gate + PR-3b read-cutover atomic + PR-4 FF removal + PR-5
  SnapshotModel drop + Plan 02-04 autonomous tasks (Q6 CI + declared_counters
  + 3 runbooks) + Mobile L1 device-side wiring (DEFERRED-02-02-D/E/F +
  sqflite_sqlcipher + iOS entitlement isolated PR) + 5 QA panel sec/arch FLAGs.
---

# Phase mint-data-architecture-v1-02-deploy — CONTEXT (bootstrap)

> Created 2026-05-19. This is the bootstrap shell. RESEARCH.md + VALIDATION.md + PLANs to be authored during the next planning session.

## TL;DR

**Phase 02-deploy ships what « code-shipped on dev » did NOT : the actual deployment.**

The Phase 02 substrate (event-log + projector + canary + Mobile L1 + parity audit + projection_diff drift gate + dual-write FF + backfill script) shipped to dev branch on 2026-05-19 via 4 squash PRs. None of it is on staging or prod. This phase closes the deploy → cutover → decommission chain.

## Load-bearing premise

**Engram obs #233 (Phase 02 substrate is code-only on dev — NEVER deployed to staging/prod, 2026-05-19).**

`railway ssh` evidence captured 2026-05-19 ~16:00 UTC :

| Layer | State |
|-------|-------|
| dev branch (code) | alembic head `p119_phase02_parity_cont` |
| Staging DB (postgres-qdyu, what MINT-staging actually uses) | alembic head `p112_audit_event_user_hash`, 34 tables, 131 users, **0 snapshots, no fact_event, no fact_current** |
| Prod DB | alembic head `29_05_magic_link_tokens` (pre-Phase-01 entirely — VERY old date-prefixed naming), 33 tables, 2 users (test accts confirmed by Julien 2026-05-19), **0 snapshots, no fact_event, no fact_current** |

The implication is structural :
- **All Phase 02 substrate migrations (p98, p113, p116, p118, p119) are undeployed.**
- **Prod is so far behind dev that Phase 01 + sequence-coordinator + earlier substrate work may also be undeployed.** The exact gap is unknown at this writing.
- **Task 2a operational gate as written in Plan 02-03 cannot execute** — staging has 0 snapshots (backfill is no-op) and no fact_event table (projection_diff has nothing to compare).
- **PR-3b read-cutover would BREAK the system** if shipped without the schema deployed.

This phase exists to resolve those structural gaps before any cutover-class PR ships.

## Scope (W0 — bootstrap-only, plans deferred)

The detailed scope per-plan will be authored during the next GSD planning session (`/gsd-plan-phase mint-data-architecture-v1-02-deploy`). At a high level :

### Wave 0 — alembic chain audit
- Audit why prod is at `29_05_magic_link_tokens` head. Possible causes :
  - (a) prod was forked off an old branch and migrations diverged ;
  - (b) all migrations from `29_05_magic_link_tokens` → `p112` were never deployed ;
  - (c) prod is on a different deploy path than staging.
- Audit gap between staging `p112` and dev `p119` — likely 7 revs : p113 + p116 + p98 (chain order TBD) + p118 + p119.
- Verify each migration is forward-compatible AND idempotent AND has a downgrade path.
- Capture pre-deploy baseline `pg_dump` of staging + prod (separate files, committed to `tools/db/`).

### Wave 1 — staging migration apply + smoke
- Apply alembic chain to staging via `railway ssh -e staging --service MINT 'alembic upgrade head'`.
- Smoke-test all health endpoints + key flows (coach chat, projection read, audit ingestion).
- Run `preflight_zero_user_gate.py` against staging — confirm baseline.
- Enable `FF_FACT_EVENT_DUAL_WRITE=on` on staging via `railway variable set`.
- Wait for staging deploy.
- Run `backfill_snapshot_to_fact_event.py --apply` twice (idempotency).
- Run `projection_diff.py --audit-all-users --persist-to _phase02_parity_audit`.
- Verify `mint_projector_idempotency_skip_total` counter via /metrics.
- Julien-gates Task 2a operational signal : `« approved PR-3a — backfill idempotent, 100% staging-user parity audit zero diff, projection_diff.py deterministic »`.

### Wave 2 — Plan 02-03 cutover (PR-3b → PR-4 → PR-5)
- Ship PR-3b (atomic trio per Plan 02-03 iter-2 Task 2b) : read-cutover + Phase-01 D-12 parity-lint SOFT→HARD flip + pre_pr3b_pg_dump.sql 7th gate.
- 7-day continuous_drift_sampler clean window (per iter-2 B20 — 7 minimum, 14 target) OR Julien override with documented justification (0-user-prod premise + Julien empirical confirmation).
- Ship PR-4 : FF removal + DeprecationWarning on SnapshotModel writers + `no_ff_fact_event_dual_write.py` HARD lefthook + drift telemetry counter.
- 1-week observability soak post-PR-4 (or Julien override).
- Ship PR-5 : alembic `p117_drop_snapshot_legacy` + decommission runbook + B19 SnapshotModel-referencing tests inventory + baseline_snapshot_phase02_pre_drop.sql.

### Wave 3 — Plan 02-04 tasks + Mobile L1 device wiring
- Task 1 D-09 S12 alias removal + D-10 PR-A3 dead-fields + allowlist cleanup.
- Task 2 Q6 CI mechanical fixes (STAGING-MALFORMED status + scheduled-only aging + STAGING-DOWN-OVERRIDE label CODEOWNER-gated per D-06).
- Task 3 `declared_counters_must_fire.py` HARD close-out gate (asserts 8 declared counters fire).
- Task 4 3 forward-deferred runbooks (`docs/operations/fact-event-partition-split.md` + `docs/operations/dek-rotation-phase04.md` + `docs/operations/audit-pepper-rotation.md`).
- Mobile L1 device-side wiring (DEFERRED-02-02-D sqflite_sqlcipher prod impl + iOS entitlement isolated PR + DEFERRED-02-02-E main.dart observer wiring + DEFERRED-02-02-F connectivity_plus integration).
- 5 sec/arch FLAGs from QA panel (sec FLAG-2 scenario_inputs_hash quasi-identifier + sec FLAG-4 DSAR manifest event_log entry + sec FLAG-5 pre-existing baseline trim + arch FLAG-2 UUID4→UUID7 + arch FLAG-3 subject_type forward-lint).
- DEFERRED-02-01-A alembic dual-head merge migration (p86_eclairage_delivered into p112).
- DEFERRED-02-01-B Mobile `_buildProfileContext` 40-field drift cleanup.
- DEFERRED-02-01-C `profile_safe_fields_parity.py` lint static-analysis enhancement.

### Wave 4 — Prod migration apply + close-out
- Repeat Wave 1 against prod (with the audit gap from Wave 0 informing the migration plan).
- Final 5-gate panel (G1 Maestro walker on Mobile L1 wired surface + G2 Julien device sign-off + G3 dev CI green + G4 regression + G5 lints).
- VERIFICATION-REPORT.html + SUMMARY.md + ROADMAP + STATE flip.

## Open questions (defer to /gsd-plan-phase next session)

1. **Why is prod alembic at `29_05_magic_link_tokens`?** Could indicate a fork, an undeployed Phase 01, or a pre-Phase-01 fossil. Audit-and-decide before applying dozens of migrations.
2. **Is the staging→prod deploy automated?** If Railway auto-applies migrations on each deploy, the gap should self-close on next deploy. If migrations require manual `alembic upgrade head`, the operational runbook must document that.
3. **What's the baseline pg_dump strategy?** Pre-Wave-1 snapshot capture for staging vs pre-Wave-4 snapshot for prod ; storage location for restore anchors ; retention policy.
4. **Should the 7-day continuous_drift_sampler soak be enforced or override-allowed?** Per iter-2 B20 the soak is 7-day minimum / 14-day target. With 2 prod test accounts (no real user data), the override path may be appropriate. Document the decision.
5. **iOS entitlement isolation PR ordering** — Mobile L1 device wiring (DEFERRED-02-02-D) requires a `com.apple.developer.*` key in Runner.entitlements. Per memory `feedback_ios_entitlements_block_testflight`, this must isolate to its own PR before bundling. Schedule before or after the cutover?
6. **Sentry alarm wiring** — `mint_snapshot_fact_current_drift_total > 0 in 24h window` alert needs configuration in Sentry dashboard (not Claude-actionable). Schedule a Julien-only task.
7. **Mobile parity-lint drift baseline 40 vs 15** (DEFERRED-02-01-B) — should PR-A3 drop only the 3 allowlisted fields or close the full 40-field gap?

## Canonical refs

- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-projection-SUMMARY.md` — substrate-phase close-out narrative
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-projection-VERIFICATION-REPORT.html` — substrate-phase verification (5-gate panel)
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/deferred-items.md` — full deferred list absorbed by this phase
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md` — Plan 02-03 iter-2 6-PR sequence + Task 2a/2b checkpoint contracts (re-used by this phase)
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks-PLAN.md` — Plan 02-04 4-task close-out plan (re-used by this phase Wave 3)
- engram obs #233 — operational-substrate-gap finding (load-bearing premise)
- engram obs #194 — Phase 02 deep security audit (STRIDE + LSFin + Swiss) — re-applies to deploy phase
- `services/backend/scripts/preflight_zero_user_gate.py` — prod gate (returns BLOCKED with 2 users today, justification documented)
- `services/backend/scripts/backfill_snapshot_to_fact_event.py` — idempotent backfill (no-op against current empty staging snapshots)
- `tools/parity/projection_diff.py` — deterministic drift gate (canonical JSON + Decimal 1e-9 tolerance)

## Counter-arguments + data gaps

(Per CLAUDE.md §8 wiki-lint convention — bias-check against echo-chamber.)

### Counter-arguments considered

1. **« Just collapse Phase 02 + Phase 02-deploy into one milestone. »** Tempting but operationally unsafe : the substrate phase's PRs are already merged on dev, and forcing a re-open would invalidate the verified GSD substrate-phase close-out. Sibling phase is cleaner.
2. **« Apply migrations + cutover in one shot today. »** Rejected — prod alembic is dozens of revs behind ; advancing blindly is high-risk. The audit Wave 0 is non-negotiable.
3. **« Mobile L1 device wiring is separate concern, defer to v3.0 milestone. »** Tempting but wrong — Phase 02's Mobile L1 backend endpoint (`/v1/audit_mobile`) is already shipped ; without device wiring it's dead code. Bundling closes the contract.
4. **« Plan 02-04 Task 2/3/4 are independent, don't need to be in this phase. »** True technically — they could be standalone PRs. But scope-wise they ARE Phase 02 close-out work (counters declared in Phase 02 substrate must fire ; Q6 CI hardening was scoped by Phase 02 RESEARCH). Keeping them in the deploy phase keeps the audit trail clean.

### Data gaps (require investigation before plans)

- Exact list of migrations between `29_05_magic_link_tokens` and dev's `p119_phase02_parity_cont` (could be tens or hundreds — TBD).
- Whether Railway auto-applies migrations on deploy or requires manual invocation.
- Whether prod's 2 users (Julien + Lauren test accts) have any data in tables that intersect with the migration chain (snapshots, audit, scenarios, profiles).
- Production deploy automation state — is there a CI step that runs `alembic upgrade head`?

## Karpathy alignment

- **#1 Think Before Coding.** Surface the deploy gap explicitly + audit before mutating prod.
- **#2 Simplicity First.** Sequence is staging-first → smoke → prod. No clever parallelism. No skip-the-soak unless documented.
- **#3 Surgical Changes.** Each PR in this phase touches one operational concern at a time. PR-3b is the only « atomic trio » exception (per Plan 02-03 iter-2 Task 2b contract).
- **#4 Goal-Driven Execution.** Per-wave success criteria : Wave 0 = chain audit doc + baseline pg_dump captured ; Wave 1 = staging at dev head + Task 2a green ; Wave 2 = PR-5 merged on dev + soak clean ; Wave 3 = Plan 02-04 PRs merged + Mobile L1 device wiring shipped ; Wave 4 = prod at dev head + final 5-gate panel green.

## Open-questions disposition

To be locked during `/gsd-plan-phase` next session via Claude-decided-and-Julien-confirmed protocol (per memory `feedback_critical_pm_mode` + `feedback_product_delegation`).

## Next session entry

```
/gsd-plan-phase mint-data-architecture-v1-02-deploy
```

Required reading in the next session before planning :
1. `.planning/phases/mint-data-architecture-v1-02-deploy/CONTEXT.md` (this file)
2. `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-projection-SUMMARY.md`
3. engram obs #233 (full text via `mem_get_observation 233`)
4. Plan 02-03 iter-2 Task 2a/2b checkpoint contracts (Plan 02-03 PLAN.md lines ~659-770)
5. Plan 02-04 4-task close-out plan (Plan 02-04 PLAN.md)
6. `railway ssh -e staging --service MINT` quick query to re-verify staging state at session start
7. `railway ssh -e production --service MINT` quick query to re-verify prod state at session start
