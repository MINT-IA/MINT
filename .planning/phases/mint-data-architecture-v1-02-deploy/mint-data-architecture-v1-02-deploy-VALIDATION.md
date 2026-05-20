---
phase: mint-data-architecture-v1-02-deploy
slug: deploy
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-19
---

# Phase mint-data-architecture-v1-02-deploy — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Drawn from RESEARCH.md `## Validation Architecture` section. Planner fills task-level rows during PLAN.md generation.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 7.x (backend) + flutter test (mobile) + alembic CLI + Maestro (G1 sim) |
| **Config file** | `services/backend/pytest.ini` + `apps/mobile/pubspec.yaml` + `alembic.ini` |
| **Quick run command** | `cd services/backend && python3 -m pytest tests/unit -q --timeout=10` |
| **Full suite command** | `cd services/backend && python3 -m pytest tests/ -q` + `cd apps/mobile && flutter test` + `tools/simulator/walker.sh` |
| **Estimated runtime** | ~120s backend unit, ~480s backend full+integration, ~180s flutter, ~300s Maestro sweep |

---

## Sampling Rate

- **After every task commit:** Run quick unit pytest (`pytest tests/unit -q --timeout=10`) — feedback < 30s.
- **After every plan wave:** Run full pytest + flutter test + accent_lint + banned_terms + arb_parity lints — feedback < 600s.
- **Before `/gsd-verify-work`:** Full suite green + Maestro G1 sweep clean + `idb ui describe-all` post-deploy snapshot captured.
- **Max feedback latency:** 600s (10 min) for full Wave verification ; 30s for per-task feedback.

---

## Per-Wave Verification Map (placeholder — planner fills task-level rows per PLAN.md)

| Wave | Plan | Acceptance evidence | Test type | Automated command | Status |
|------|------|---------------------|-----------|-------------------|--------|
| 0 | 01-alembic-chain-audit | Chain doc with 14 revs enumerated + per-rev forward-compat note + downgrade verified | doc + alembic CLI | `alembic history --verbose \| tee chain-audit.txt` + `alembic upgrade <rev>` + `alembic downgrade -1` per rev | ⬜ pending |
| 0 | 01-alembic-chain-audit | pg_dump baseline captured for staging + prod | shell script | `tools/db/railway_pg_dump.sh staging` + `tools/db/railway_pg_dump.sh production` | ⬜ pending |
| 1 | 02-staging-migration-apply | `railway ssh -e staging` confirms alembic head = `p119_phase02_parity_cont` | shell probe | `railway ssh -e staging --service MINT 'python3 -c "...alembic_version..."'` | ✅ green (2026-05-19) |
| 1 | 02-staging-migration-apply | `fact_event` + `fact_current` + `dek_envelope` tables exist on staging postgres-qdyu | shell probe | `railway ssh -e staging --service MINT 'python3 -c "...pg_tables..."'` | ✅ green (fact_event verified 2026-05-19) |
| 1 | 02-staging-migration-apply | `FF_FACT_EVENT_DUAL_WRITE=on` set on staging | Railway CLI | `railway variables -e staging --service MINT` shows `FF_FACT_EVENT_DUAL_WRITE=on` | ⬜ pending |
| 1 | 02-staging-migration-apply | `backfill_snapshot_to_fact_event.py --apply` idempotent (2nd run = 0 new rows) | python script | `python3 services/backend/scripts/backfill_snapshot_to_fact_event.py --apply` ×2 + diff row counts | ⬜ pending |
| 1 | 02-staging-migration-apply | `projection_diff.py --audit-all-users` returns 0 diffs on all 131 staging users | python script | `python3 tools/parity/projection_diff.py --audit-all-users --persist-to _phase02_parity_audit` | ⬜ pending |
| 1 | 02-staging-migration-apply | `mint_projector_idempotency_skip_total` counter declared + increments on replay | python integration | `pytest services/backend/tests/integration/test_projector_idempotency_replay_skip.py -q` | ⬜ pending |
| 1 | 02-staging-migration-apply | Task 2a gate : Julien sign-off message ledger entry in PERIMETERS.md | manual | Julien types « approved PR-3a » + ledger commit | ⬜ pending |
| 2 | 03-cutover-PR3b-PR4-PR5 | PR-3b atomic trio (read-cutover + D-12 parity-lint HARD + pre_pr3b_pg_dump.sql) ships clean | pytest + lint | full pytest + `tools/checks/no_legacy_snapshot_read_in_production.py` HARD | ⬜ pending |
| 2 | 03-cutover-PR3b-PR4-PR5 | 7-day continuous_drift_sampler clean window (or Julien override with documented justification) | cron probe | `_phase02_drift_sampler` table query : 0 drift events in 7-day window | ⬜ pending |
| 2 | 03-cutover-PR3b-PR4-PR5 | PR-4 FF removal + DeprecationWarning + `no_ff_fact_event_dual_write.py` HARD lefthook | pytest + lefthook | grep `FF_FACT_EVENT_DUAL_WRITE` returns 0 hits ; lefthook gate fires on test injection | ⬜ pending |
| 2 | 03-cutover-PR3b-PR4-PR5 | PR-5 alembic `p117_drop_snapshot_legacy` applied + B19 tests inventory complete | alembic + pytest | `alembic upgrade head` + `pytest tests/integration -q` zero `SnapshotModel` refs in red | ⬜ pending |
| 3 | 04-plan-02-04-tasks | Plan 02-04 Task 1 (D-09 alias removal + D-10 dead-fields) shipped + tests green | pytest | full pytest + grep `_PROFILE_SAFE_FIELDS` for D-09 removal | ⬜ pending |
| 3 | 04-plan-02-04-tasks | Plan 02-04 Task 2 (Q6 CI STAGING-MALFORMED + scheduled-only aging + override label CODEOWNER) shipped | GH Actions probe | `gh workflow view regulatory-codegen` + manual injection of STAGING-MALFORMED state | ⬜ pending |
| 3 | 04-plan-02-04-tasks | Plan 02-04 Task 3 `declared_counters_must_fire.py` HARD gate green | python lint | `python3 tools/checks/declared_counters_must_fire.py` exit 0 + 8 counters fire in test fixture | ⬜ pending |
| 3 | 04-plan-02-04-tasks | Plan 02-04 Task 4 3 runbooks shipped : fact-event-partition-split, dek-rotation-phase04, audit-pepper-rotation | doc | `ls docs/operations/{fact-event-partition-split,dek-rotation-phase04,audit-pepper-rotation}.md` exit 0 | ⬜ pending |
| 3 | 04-plan-02-04-tasks | Mobile L1 device wiring (DEFERRED-02-02-C lefthook + DEFERRED-02-02-E main.dart observer + DEFERRED-02-02-F connectivity_plus) | flutter test | `flutter test test/services/audit/mobile_l1_audit_lifecycle_observer_test.dart -q` + lefthook probe | ⬜ pending |
| 3 | 04-plan-02-04-tasks | DEFERRED-02-02-D `sqflite_sqlcipher` production AuditBufferDb + iOS entitlement isolated PR | flutter integration | `flutter test integration_test/audit_buffer_db_test.dart` + Apple Developer portal capability check | ⬜ pending |
| 3 | 04-plan-02-04-tasks | 5 sec/arch FLAGs : sec FLAG-2 scenario_inputs_hash + sec FLAG-4 DSAR manifest + sec FLAG-5 baseline trim + arch FLAG-2 UUID4→UUID7 decoupled + arch FLAG-3 subject_type forward-lint | pytest + lint | per-FLAG acceptance criteria in PLAN.md ; planner enumerates | ⬜ pending |
| 4 | (close-out, no new plan) | Prod alembic head = `p119_phase02_parity_cont` (or current dev head) | shell probe | `railway ssh -e production --service MINT 'python3 -c "...alembic_version..."'` | ⬜ pending |
| 4 | (close-out) | Maestro G1 sweep clean on staging + prod Mobile L1 wired surface | maestro | `tools/simulator/walker.sh --env staging` + `--env production` | ⬜ pending |
| 4 | (close-out) | Julien G2 device sign-off | manual | Julien confirms via PERIMETERS.md ledger | ⬜ pending |
| 4 | (close-out) | dev CI green sha + regression tests + lints (accent_lint + banned_terms + arb_parity + accent_patterns) | gh + lint | `gh pr checks <prod-cutover-PR>` + lint suite exit 0 | ⬜ pending |
| 4 | (close-out) | VERIFICATION-REPORT.html + SUMMARY.md + ROADMAP + STATE flip | doc | `ls .planning/phases/mint-data-architecture-v1-02-deploy/*-VERIFICATION-REPORT.html` exit 0 | ⬜ pending |

*Status legend : ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · ◆ in progress*

---

## Wave 0 Requirements (test infrastructure prerequisites)

- [ ] `tools/db/railway_pg_dump.sh` — Railway pg_dump helper (PR B step 8 — currently MISSING per HANDOFF devops finding)
- [ ] `tools/checks/alembic_partition_safety_lint.py` — ~50 LOC AST walk banning PARTITION BY without PK partition-col-in-key + FK NOT VALID on partitioned table (PR B step 6, postgres-pro E2)
- [ ] `tools/checks/declared_counters_must_fire.py` — HARD gate asserting 8 declared counters fire (Plan 02-04 Task 3)
- [ ] `tools/checks/no_mobile_fact_current_regulatory_read.py` — lefthook wiring on `apps/mobile/lib/**/*.dart` (DEFERRED-02-02-C, 1-line lefthook addition)
- [ ] `tools/checks/no_ff_fact_event_dual_write.py` — HARD lefthook post-PR-4 FF removal
- [ ] `services/backend/tests/integration/test_projector_idempotency_replay_skip.py` — D-27 EXACT-EQUALITY skip semantics (PR A2)
- [ ] `services/backend/tests/integration/test_projector_natural_key_pk_collision.py` — D-27 PK collision exercise (PR A2)
- [ ] `services/backend/tests/integration/test_dual_write_replay_safe.py` — full integration through snapshot_service (PR A2)
- [ ] `services/backend/tests/integration/test_dual_write_failure_rollback.py` — pg_fixture DEK-revoked mid-loop → atomic rollback (PR A3)
- [ ] `services/backend/tests/integration/test_hmac_pepper_rotation.py` — pg_fixture monkeypatch.setenv with `lru_cache(maxsize=1)` rotation (PR A3)
- [ ] `services/backend/tests/conftest.py` — health-check fixture asserting critical app loggers `.disabled is False` at session start (PR B step 9, debugger prevention)
- [ ] Lefthook rule banning `fileConfig(` without `disable_existing_loggers=False` in alembic env.py (PR B step 7)
- [ ] `apps/mobile/test/services/audit/mobile_l1_audit_lifecycle_observer_test.dart` — DEFERRED-02-02-E main.dart observer wiring test
- [ ] `apps/mobile/integration_test/audit_buffer_db_test.dart` — DEFERRED-02-02-D sqflite_sqlcipher production impl integration

---

## Manual-Only Verifications

| Behavior | Wave | Why Manual | Test Instructions |
|----------|------|------------|-------------------|
| Task 2a Julien sign-off | 1 | Operational gate by design — requires human « approved PR-3a » signal in PERIMETERS.md ledger | After backfill+projection_diff green, Julien types « approved PR-3a — backfill idempotent, 100% staging-user parity audit zero diff, projection_diff.py deterministic » in PERIMETERS.md ledger commit |
| 7-day continuous_drift_sampler clean window | 2 | Time-gated (7-day minimum / 14-day target per iter-2 B20) ; override path documented for 2-prod-user premise | Either wait 7 days with `_phase02_drift_sampler` table showing zero drift events, OR Julien documents override with « 0-user-prod premise + 2-test-acct empirical confirmation » in PR-3b commit message |
| Sentry alert rule on `mint_snapshot_fact_current_drift_total > 0 in 24h window` | 3 | Sentry dashboard task (not Claude-actionable) | Julien configures alert rule + on-call notification target in Sentry UI ; ledgers config in `docs/operations/sentry-alert-config.md` |
| iOS entitlement isolated PR (DEFERRED-02-02-D) | 3 | Apple Developer portal capability + fastlane match profile update | Julien adds `com.apple.developer.*` key in Apple Developer portal capability sheet ; update fastlane match profile via `bundle exec fastlane match development` ; commit Runner.entitlements update in **isolated sub-PR A4b** per memory `feedback_ios_entitlements_block_testflight` |
| Maestro G1 sweep on prod Mobile L1 wired surface | 4 | Requires staging + prod environments wired + Mobile L1 device wiring landed | `tools/simulator/walker.sh --env staging` + `--env production` — output committed to `.planning/reports/wave-4-maestro-sweep.html` |
| Julien G2 device sign-off | 4 | End-to-end user value separation (per CLAUDE.md §9.4) — Maestro proves the wiring works, but Julien on real device + real Apple ID proves the user experience | Julien runs the wired Mobile L1 surface on real device after prod deploy, types confirmation in PERIMETERS.md ledger entry |
| dev branch protection promotion of `pg-integration (testcontainers)` to required check | (PR B prerequisite) | GitHub Actions branch protection config (5 min config GH UI) | Julien navigates to repo Settings → Branches → dev rule → required checks → add `pg-integration (testcontainers)` ; ledgers config in `docs/operations/branch-protection-config.md` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies enumerated (planner fills during PLAN.md generation)
- [ ] Sampling continuity : no 3 consecutive tasks without automated verify (planner enforces)
- [ ] Wave 0 covers all MISSING references (14 prerequisites listed above)
- [ ] No watch-mode flags (CI=true + --timeout=10 across all commands)
- [ ] Feedback latency < 600s (per-task ≤ 30s ; per-Wave ≤ 600s)
- [ ] `nyquist_compliant: true` set in frontmatter (after planner fills task-level rows + Wave 0 lands)

**Approval:** pending — to be flipped to `approved YYYY-MM-DD` after PLAN.md generation + plan-checker green.
