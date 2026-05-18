---
phase: mint-data-architecture-v1-02-event-log-projection
slug: mint-data-architecture-v1-02-event-log-projection
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-18
description: Nyquist validation strategy for Phase 02 (event-log + projection + DEK envelope + S12/D-MOB carry-overs). Backend-heavy (Postgres migrations + crypto + audit-trail). Wave 0 wires `pg_fixture` testcontainers harness + 6 new lint files + 15 new test files mapped to the 33 D-XX. Sampling cadence keeps feedback latency under 30s per commit.
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Source: `mint-data-architecture-v1-02-event-log-RESEARCH.md` § Validation Architecture (1451-line research doc, sha `055ca9e3`).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (backend)** | pytest 7.x + `testcontainers[postgres]>=4.7` (W0 installs) |
| **Framework (mobile)** | flutter_test (already installed) |
| **Config file (backend)** | `services/backend/pyproject.toml` + `services/backend/tests/conftest.py` (extend with `pg_fixture` in W0) |
| **Config file (mobile)** | `apps/mobile/pubspec.yaml` (no changes; existing flutter_test) |
| **Quick run command (backend, SQLite)** | `cd services/backend && python3 -m pytest tests/ -q -x --ignore=tests/integration_pg` |
| **Quick run command (mobile)** | `cd apps/mobile && flutter analyze && flutter test --no-pub` |
| **Full suite command (backend, real Postgres)** | `cd services/backend && python3 -m pytest tests/ -q` (runs `pg_fixture`-gated tests via testcontainers) |
| **Full suite command (lints)** | `python3 tools/checks/alembic_boolean_default_lint.py && python3 tools/checks/hmac_pepper_audit.py && python3 tools/checks/profile_safe_fields_parity.py --hard && python3 tools/checks/wiki_lint.py` |
| **Estimated runtime (quick)** | ~25s backend SQLite + ~30s mobile = ~55s |
| **Estimated runtime (full backend + testcontainers)** | ~90s (30s testcontainers spin-up amortised across pg_fixture-scoped session) |

---

## Sampling Rate

- **After every task commit:** Run quick backend + mobile commands above (≤ 60s feedback)
- **After every plan wave:** Run full suite (Postgres testcontainers + lints) — required green before next wave starts
- **Before `/gsd-verify-work`:** Full suite green + accent_lint_fr + ARB parity + banned-terms-python all exit-0
- **Max feedback latency:** 30s for changed-file scope (pytest `-x --ff` on changed modules); 90s for full Postgres pass
- **Wave gate (W2-W3 5-PR sequence):** Each PR's CI must run full Postgres suite + parity-lint SOFT/HARD according to PR position; HARD parity-lint flip lands inside PR-3 (D-31)

---

## Per-Task Verification Map

> Mapped from RESEARCH.md § Validation Architecture, anchored on the 33 locked D-XX from CONTEXT.md. Plan IDs follow the researcher's 4-plan split (Plan 02-01 W0 / 02-02 W1 / 02-03 W2-W3 / 02-04 W4). Task IDs will be refined by the planner; entries below are the validation surface the planner MUST cover.

### Wave 0 — Prereqs + lints + test harness (Plan 02-01)

| Task ID | Plan | Wave | Decision | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 02-01 | 0 | D-20 (Postgres BOOLEAN lint) | — | Migration files cannot ship `sa.Boolean(...).server_default=sa.text("0\|1\|true\|false")` (Hotfix B/`fe52ba31` regression class) | unit (lint self-test) | `python3 tools/checks/alembic_boolean_default_lint.py --self-test` | ❌ W0 | ⬜ pending |
| 02-01-02 | 02-01 | 0 | D-22 (pg_fixture harness) | — | `pg_fixture` spins real Postgres 15 via testcontainers; alembic upgrade head + downgrade base completes idempotently | integration (harness self-test) | `python3 -m pytest services/backend/tests/conftest_pg_test.py -q` | ❌ W0 | ⬜ pending |
| 02-01-03 | 02-01 | 0 | D-S12-01..04 (S12 consolidation PR-1) | — | `FrontalierService` → `FrontalierSegmentService` rename complete, all callers updated, IJM/LAA constants promoted to S18, façade-delegate-to-granular pattern preserved | unit + grep | `cd services/backend && python3 -m pytest tests/services/independants tests/services/expat -q && ! grep -rn "FrontalierService" services/backend/app apps/mobile/lib \| grep -v "FrontalierSegmentService"` | ❌ W0 | ⬜ pending |
| 02-01-04 | 02-01 | 0 | D-MOB-01 (Flutter drift PR-A2) | — | `_PROFILE_SAFE_FIELDS` extended with the 40 server-canonical fields Flutter never emitted; 3 Flutter-only drops cleaned; emit-pattern (not handle-pattern) | unit + parity-lint SOFT | `python3 tools/checks/profile_safe_fields_parity.py` (exit 0 SOFT mode) | ❌ W0 | ⬜ pending |
| 02-01-05 | 02-01 | 0 | D-21 (lefthook wiring) | — | New lints (`alembic_boolean_default_lint.py` + `hmac_pepper_audit.py`) wired in `lefthook.yml` on the correct file glob | unit (lefthook config) | `grep -A3 "alembic_boolean_default_lint" lefthook.yml && grep -A3 "hmac_pepper_audit" lefthook.yml` | ❌ W0 | ⬜ pending |

### Wave 1 — Schema + KMS + HMAC-pepper (Plan 02-02)

| Task ID | Plan | Wave | Decision | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-02-01 | 02-02 | 1 | D-Q1 (`fact_event` schema) | — | Append-only table with `subject_type`/`subject_id`/`source_type`/`payload` JSONB + `event_id` UUID7 + `recorded_at` server_default `now()`; PARTITION BY HASH on `subject_id` (raw SQL) | integration (pg_fixture) | `cd services/backend && python3 -m pytest tests/integration_pg/test_fact_event_schema.py -q` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02-02 | 1 | D-Q1 (`fact_current` projection schema + sub-1ms PK read) | — | Denormalised table with per-user PK; index supports sub-1ms `SELECT WHERE user_id=?` (measured via pgbench script) | integration + perf | `cd services/backend && python3 -m pytest tests/integration_pg/test_fact_current_perf.py -q && python3 tools/perf/fact_current_pk_read.py --p99-under 1ms` | ❌ W0 | ⬜ pending |
| 02-02-03 | 02-02 | 1 | D-02 (Railway-native KMS, logical key-id `mint-master-v1`) | T-02-01 (key compromise) | `KeyVaultService.get_or_create_dek(user_id)` returns wrapped DEK using `mint-master-v1` logical id; KMS provider abstracted via existing 2-backend facade | integration + STRIDE T:tampering | `cd services/backend && python3 -m pytest tests/services/encryption/test_key_vault_railway.py -q` | ❌ W0 | ⬜ pending |
| 02-02-04 | 02-02 | 1 | D-03 (DEK shred all-or-nothing per user) | T-02-02 (RTBF compliance) | `KeyVaultService.revoke_dek(user_id)` flips `DEKVault.revoked_at`; subsequent reads return `KeyRevokedError`; crypto-shred path tested | integration + STRIDE I:info-disclosure | `cd services/backend && python3 -m pytest tests/services/encryption/test_dek_shred.py -q` | ❌ W0 | ⬜ pending |
| 02-02-05 | 02-02 | 1 | D-26 (JSONB envelope packaging) | T-02-03 (payload tamper) | `encrypt_value(db, user_id, value) -> EncryptedValue` Pydantic v2 model; AAD bound to `user_id`; decrypt fails with wrong user | unit + integration | `cd services/backend && python3 -m pytest tests/services/encryption/test_envelope_jsonb.py -q` | ❌ W0 | ⬜ pending |
| 02-02-06 | 02-02 | 1 | D-Q7 + HMAC-pepper migration (`audit_event.user_id_hash`) | T-02-04 (audit integrity) | New canonical entry `app/services/audit/hmac_pepper.py::hmac_user_id()`; alembic backfill p112-style; old SHA256-only hashes migrated; `tools/checks/hmac_pepper_audit.py` flags non-canonical usage | integration + lint | `cd services/backend && python3 -m pytest tests/services/audit/test_hmac_pepper_migration.py -q && python3 tools/checks/hmac_pepper_audit.py --strict` | ❌ W0 | ⬜ pending |
| 02-02-07 | 02-02 | 1 | D-MOB-03 (`projection_audit_record` extension) | — | Adds `source` discriminator (`mobile_l1` \| `backend_l2_l4`) + `app_version` + `observed_at` columns; backfill defaults match existing rows; idempotent upgrade | integration (pg_fixture) | `cd services/backend && python3 -m pytest tests/integration_pg/test_projection_audit_extension.py -q` | ❌ W0 | ⬜ pending |
| 02-02-08 | 02-02 | 1 | D-MOB-04 (mobile L1 audit ingestion endpoint) | T-02-05 (audit replay) | `POST /v1/audit/projection` accepts batch from mobile; payload encrypted at rest via D-26; ~1.5KB JSON expected (A8 verified) | integration + contract | `cd services/backend && python3 -m pytest tests/api/v1/test_audit_projection_endpoint.py -q && python3 services/backend/scripts/generate_canonical.py --check` | ❌ W0 | ⬜ pending |
| 02-02-09 | 02-02 | 1 | D-Q4 (constants propagation on law change) | — | RegulatoryParameter change writes `fact_event(subject_type='regulatory', source_type='codegen')` dual-write; mobile `regulatoryConstantsVersionHash` reads from the event-log lineage | integration | `cd services/backend && python3 -m pytest tests/services/regulatory/test_constants_event_log.py -q` | ❌ W0 | ⬜ pending |

### Wave 2-3 — Backfill + dual-write + cutover (Plan 02-03, 5-PR sequence)

| Task ID | Plan | Wave | Decision | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-03-01 | 02-03 | 2 | D-Q5 (PR-1 dual-write FF-OFF) | — | `FF_FACT_EVENT_WRITE=off` path: writes still hit `SnapshotModel`; new `fact_event` writes shadow-mirror w/o read-back; idempotent on re-run | integration (pg_fixture) | `cd services/backend && python3 -m pytest tests/integration_pg/test_dual_write_off.py -q` | ❌ W0 | ⬜ pending |
| 02-03-02 | 02-03 | 2 | D-Q5 (PR-2 dual-write FF-ON staging) | — | `FF_FACT_EVENT_WRITE=on` (staging-only): writes hit both `SnapshotModel` + `fact_event`; consistency verifier compares per-user projections | integration + perf | `cd services/backend && python3 -m pytest tests/integration_pg/test_dual_write_on_staging.py -q && python3 tools/perf/dual_write_overhead.py --p99-under 5ms` | ❌ W0 | ⬜ pending |
| 02-03-03 | 02-03 | 3 | D-31 (PR-3 read cutover + parity-lint HARD) | T-02-06 (read drift) | Same PR: (a) `/v1/projection` reads from `fact_current` (not SnapshotModel), (b) `profile_safe_fields_parity.py --hard` added to lefthook + CI, (c) zero-drift proof in coverage | integration + lint HARD | `cd services/backend && python3 -m pytest tests/integration_pg/test_read_cutover.py -q && python3 tools/checks/profile_safe_fields_parity.py --hard` | ❌ W0 | ⬜ pending |
| 02-03-04 | 02-03 | 3 | D-Q5 (PR-4 dual-write decommission) | — | `FF_FACT_EVENT_WRITE` removed; `SnapshotModel` writes deprecated (deprecation marker + tests); migration prepared for read deletion | unit + lint | `cd services/backend && python3 -m pytest tests/services/snapshot_deprecation -q && grep -rn "FF_FACT_EVENT_WRITE" services/backend/app && exit 1` | ❌ W0 | ⬜ pending |
| 02-03-05 | 02-03 | 3 | D-Q5 (PR-5 SnapshotModel drop) | T-02-07 (orphan data) | `SnapshotModel` table dropped via alembic; rollback procedure documented in operations runbook; pg_fixture downgrade test passes | integration (pg_fixture) | `cd services/backend && python3 -m pytest tests/integration_pg/test_snapshot_drop.py -q && ls docs/operations/snapshot-model-decommission.md` | ❌ W0 | ⬜ pending |
| 02-03-06 | 02-03 | 3 | D-MOB-02 (drift-resolution telemetry) | — | Drift-resolution counter + audit-record-coverage gauge wired in Sentry (A6 quota verified); HARD parity-lint catches future regressions | integration + telemetry | `cd services/backend && python3 -m pytest tests/observability/test_drift_telemetry.py -q` | ❌ W0 | ⬜ pending |

### Wave 4 — Close-out + lint promotion + ops docs (Plan 02-04)

| Task ID | Plan | Wave | Decision | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-04-01 | 02-04 | 4 | Q6 ext (6 new counters) | — | 6 new observability counters from obs #178 wired (fact_event_writes_total, dek_revocations_total, audit_replay_lag_seconds, parity_lint_violations_total, dual_write_drift_total, projection_rebuild_duration_seconds) | unit | `cd services/backend && python3 -m pytest tests/observability/test_phase02_counters.py -q` | ❌ W0 | ⬜ pending |
| 02-04-02 | 02-04 | 4 | Q6 ext (STAGING-MALFORMED status + label override) | — | `curl -sf -m 10` upgraded to distinguish DOWN vs MALFORMED; `STAGING-DOWN-OVERRIDE` label gate functional in `.github/workflows/regulatory-codegen.yml` | integration (CI workflow self-test) | `python3 .github/workflows/_self_test/staging_status_test.py` | ❌ W0 | ⬜ pending |
| 02-04-03 | 02-04 | 4 | Q6 ext (scheduled-only aging writes) | — | Aging writes (parity-lint SOFT→HARD promotion candidate) run only via cron-scheduled workflow, not PR-triggered | integration | `python3 .github/workflows/_self_test/cron_scheduled_only.py` | ❌ W0 | ⬜ pending |
| 02-04-04 | 02-04 | 4 | Q3 partition-split runbook | — | `docs/operations/fact-event-partition-split.md` shipped: thresholds, procedure, rollback; partition-split decision tree documented | doc lint | `ls docs/operations/fact-event-partition-split.md && python3 tools/checks/wiki_lint.py --file docs/operations/fact-event-partition-split.md` | ❌ W0 | ⬜ pending |
| 02-04-05 | 02-04 | 4 | DEK rotation forward-deferral | — | `docs/operations/dek-rotation-phase04.md` documents the forward-deferred rotation procedure; no live rotation in Phase 02 | doc lint | `ls docs/operations/dek-rotation-phase04.md && python3 tools/checks/wiki_lint.py --file docs/operations/dek-rotation-phase04.md` | ❌ W0 | ⬜ pending |
| 02-04-06 | 02-04 | 4 | LSFin/banned-terms parity | — | Event-log payloads + audit records + coach responses honor `check_banned_terms(text)`; lint extended to scan `fact_event.payload` JSONB shape | integration + lint | `cd services/backend && python3 -m pytest tests/compliance/test_event_log_banned_terms.py -q && python3 tools/checks/banned_terms_python.py` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

> The planner MUST land these BEFORE Wave 1 starts. Each maps to a Plan 02-01 task.

### Backend test infrastructure
- [ ] `services/backend/tests/conftest.py` — extend with `pg_fixture` (testcontainers Postgres 15, alembic upgrade head + downgrade base lifecycle)
- [ ] `services/backend/tests/integration_pg/` — new directory for real-Postgres integration tests (8 new test files mapped to D-XX above)
- [ ] `services/backend/tests/integration_pg/conftest_pg_test.py` — pg_fixture self-test (gates the harness itself before downstream tests rely on it)
- [ ] `services/backend/pyproject.toml` — add `testcontainers[postgres]>=4.7` (A1 pending PyPI verification by planner)
- [ ] `services/backend/pyproject.toml` — add `uuid_utils>=0.10` (A2 pending PyPI verification by planner) for UUID7 generation

### New lint files
- [ ] `tools/checks/alembic_boolean_default_lint.py` — HARD lefthook lint flagging `sa.Boolean(...).server_default=sa.text("0|1|true|false")` (D-20)
- [ ] `tools/checks/hmac_pepper_audit.py` — site-sweep lint flagging `hashlib.sha256(user_id|actor_email|...)` not routed through `app/services/audit/hmac_pepper.py` (D-21 part 1)

### Lefthook wiring
- [ ] `lefthook.yml` — wire the two new lints on the correct file globs (D-21 part 2)
- [ ] `.github/workflows/backend-ci.yml` — add the two new lints + Postgres testcontainers job (D-22 finalisation)

### Mobile drift prep (D-MOB-01 PR-A2)
- [ ] `apps/mobile/lib/services/financial_core/profile_safe_fields.dart` — extend with the 40 server-canonical fields Flutter never emitted; 3 Flutter-only drops cleaned (emit-pattern)
- [ ] `tools/checks/profile_safe_fields_parity.py` — already exists from Phase 01 W4 Plan 19; verify SOFT-mode green after PR-A2 lands (HARD mode flip lands in Plan 02-03 PR-3)

### S12 API consolidation (D-S12-01..04 PR-1)
- [ ] `services/backend/app/services/independants/` — receive promoted `IJM_ESTIMATE_RATE=0.02` + `LAA_ESTIMATE_RATE=0.015` constants from S12-local
- [ ] `services/backend/app/services/expat/frontalier_service.py` — rename to `FrontalierSegmentService`, all callers updated via grep-rn sweep
- [ ] `services/backend/app/services/s12/independant_service.py:60-64` — remove the now-moved constants
- [ ] Tests: `tests/services/independants/test_ijm_laa_promoted.py` + `tests/services/expat/test_frontalier_rename.py`

---

## Manual-Only Verifications

| Behavior | Decision | Why Manual | Test Instructions |
|----------|----------|------------|-------------------|
| Sub-1ms `fact_current` PK read on production-shaped data | D-Q1 | Requires Railway staging Postgres with realistic row count (synthetic 100k users via seed script); pgbench overhead measure | Run `python3 tools/perf/fact_current_pk_read.py --target staging --users 100000 --p99-under 1ms`; capture Sentry P99 trace |
| Railway-native KMS key-rotation E2E | D-02 | Requires Railway env-var rotation simulation; cannot mock in unit test | Run `docs/operations/dek-rotation-phase04.md` PRACTICE section in staging (forward-deferred to Phase 04 but documented in P02) |
| Mobile battery drain from L1 audit emission | D-MOB-04 | Sentry-instrumented but requires real device 30-min audit-emit cycle | iPhone 17 Pro Sim or real device: run `tools/simulator/walker.sh` with `--audit-emit-stress`; verify Sentry `battery_drain_percent` < 2%/hour |
| Sentry quota survival under 5k events/mo/user | A6 | Requires production traffic shape; only verifiable via staging quota dashboard | Monitor Sentry quota dashboard for 1 week post-PR-3; alert threshold 80% quota |

---

## Validation Sign-Off

- [ ] All 33 D-XX tasks have `<automated>` verify command or Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (verified by planner during PLAN.md generation)
- [ ] Wave 0 covers all MISSING references (8 backend test infra + 2 lint files + 4 mobile/S12 files + 1 lefthook + 1 CI workflow)
- [ ] No watch-mode flags in Quick or Full suite commands
- [ ] Feedback latency < 30s for quick scope, < 90s for full Postgres
- [ ] `nyquist_compliant: true` set in frontmatter once Wave 0 lands

**Approval:** pending — flips to `approved YYYY-MM-DD` after Plan 02-01 (Wave 0) ships green
