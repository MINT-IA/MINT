---
phase: mint-data-architecture-v1-02-event-log-projection
status: substrate-complete-on-dev
deploy_phase_split_to: mint-data-architecture-v1-02-deploy
generated: 2026-05-19
dev_head_at_close: e19461f1
description: |
  Phase 02 substrate is CODE-SHIPPED on dev branch (4 squash PRs : #653 prereqs,
  #657 event-log + projector + canary + Mobile L1, #656 PR-0/PR-1/PR-2 + PR-3a
  code + iter-2 A10/B14/B18, #655 QA panel fixes). Operational deploy
  (PR-3b read-cutover + PR-4 FF removal + PR-5 SnapshotModel drop + Task 2a
  staging operational gate + Plan 02-04 Task 1-4) split to follow-on phase
  mint-data-architecture-v1-02-deploy because staging+prod alembic chains are
  behind dev by 7+ and dozens of migrations respectively, and Phase 02 substrate
  migrations (p98 fact_event, p113, p116, p118, p119) have never been applied to
  any deployed environment. Plan 02-03 carried autonomous: false explicitly to
  acknowledge this risk ; the operational reality discovered 2026-05-19 (engram
  obs #233) proved it.
---

# Phase mint-data-architecture-v1-02-event-log-projection — Substrate SUMMARY

## TL;DR

**Status : ◆ substrate code-shipped on dev — operational deploy split to Phase 02-deploy.**

The event-log substrate (fact_event + fact_current + FactProjector + DEK envelope encryption + canary parity proofs + Mobile L1 audit ingestion + projection_diff deterministic drift gate + continuous drift sampler cron + parity audit tables p118/p119 + idempotent backfill script) is **code-merged on dev** as of 2026-05-19 (e19461f1 HEAD). The cutover that flips read endpoints from SnapshotModel → fact_current + drops SnapshotModel + activates HARD parity-lint is **NOT in scope for substrate close-out** — it requires staging + prod migrations applied first (currently 7+ and dozens of revs behind dev respectively) and is genuine operational deploy work belonging in a sibling phase.

## Substrate landed (4 squash PRs + 2 direct docs)

| PR | Squash SHA | Plan + scope | Date |
|----|-----------|--------------|------|
| #653 | `dc28f974` | 02-01 prereqs + lints + harness (D-08/09/10/11/20-24 + CI fixes) | 2026-05-19 |
| #657 | `d8c97dd1` | 02-02 event-log + projector + canary + Mobile L1 (D-14..D-30) | 2026-05-19 |
| #656 | `979e45f4` | 02-03 partial — FF + dual-write + projection_diff + parity audit + PR-3a code | 2026-05-19 |
| #655 | `40afcaba` | QA panel fixes — 2 BLOCKs + 3 high-FLAGs + 4 polish + cachetools pyproject add | 2026-05-19 |
| — | `16fe62ed` | docs(state) STATE.md post-merge update (direct push) | 2026-05-19 |
| — | `e19461f1` | docs(phase-02) CONTINUATION-AFTER-SUBSTRATE-LANDING.md (direct push) | 2026-05-19 |

Plus this-session follow-ups :

| PR | Type | Scope |
|----|------|-------|
| #658 | hotfix | `fix(consent-tests)` — caplog → logger mock for CI `-x --cov` stability (unblocks dev CI gate) |
| (this PR) | close-out | Phase 02 substrate VERIFICATION-REPORT.html + SUMMARY.md + STATE/ROADMAP/PROJECT updates + Phase 02-deploy CONTEXT.md bootstrap |

## Per-plan rollup

### Plan 02-01 — prereqs-lints-harness
**STATUS : COMPLETE.** All tasks shipped via PR #653. See `mint-data-architecture-v1-02-event-log-01-prereqs-lints-harness-SUMMARY.md`.

### Plan 02-02 — event-log-core-canary
**STATUS : COMPLETE for backend ; Mobile L1 device-side wiring DEFERRED to Phase 02-deploy.**
- Backend substrate fully shipped via PR #657 : alembic p98 (fact_event), p113 (audit_mob extension), p116 (constants_invalidation), FactProjector with atomic UPSERT, EncryptedValue + DEK envelope helpers via key_vault, 5-shape canary fixtures + D-25 GATE test + D-34 multi-shape parity test, /v1/audit_mobile POST endpoint, hmac_pepper + KMS_KEY_ID rotation rehearsal, A4/A5 counters (`mint_kms_backend_failure_total` + `mint_dek_cache_size_total`).
- Mobile L1 partial : AuditBufferDb abstract + InMemoryAuditBufferDb + MobileL1AuditLifecycleObserver + OfflineAuditQueue shipped in code, but 4 device-gate items (DEFERRED-02-02-D sqflite_sqlcipher prod impl + iOS entitlement, DEFERRED-02-02-E main.dart observer wiring, DEFERRED-02-02-F connectivity_plus integration, DEFERRED-02-02-G pg-only true-concurrency test) live in Phase 02-deploy.
- See `mint-data-architecture-v1-02-event-log-02-event-log-core-canary-SUMMARY.md`.

### Plan 02-03 — migration-6pr-sequence (was 5pr ; split via iter-2 A9)
**STATUS : PARTIAL — code-only, operational cutover split to Phase 02-deploy.**
- PR-0 zero-user prod gate `preflight_zero_user_gate.py` + tests : shipped via PR #656. Empirical run 2026-05-19 returned **BLOCKED — prod has 2 users**. Julien confirmed both are test accounts (engram obs #233 updates engram #223).
- PR-1 `FF_FACT_EVENT_DUAL_WRITE` feature flag : shipped via PR #656. Default OFF in all envs.
- PR-2 dual-write code path under FF (default OFF) : shipped via PR #656. 5 canary field_keys projected via FactProjector inside `session.begin_nested()`.
- iter-2 A10 deterministic `projection_diff.py` (canonical JSON + Decimal 1e-9 tolerance + missing-key=None rule) + 18 unit tests + 13-fixture self-test : shipped via PR #656.
- iter-2 B14 alembic p118 + `Phase02ParityAudit` ORM + 5 migration tests : shipped via PR #656.
- iter-2 B18 alembic p119 + `Phase02ParityAuditContinuous` ORM + `continuous_drift_sampler.py` cron + `.github/workflows/pg-soak-nightly.yml` (cron commented OFF by default) + 9 tests : shipped via PR #656.
- PR-3a code surface `backfill_snapshot_to_fact_event.py` idempotent + 4 tests : shipped via PR #656.
- **NOT shipped this phase** (all SPLIT to Phase 02-deploy) :
  - Task 2a operational gate (FF=on staging + backfill x2 + 100% staging-user projection_diff audit + Julien sign-off)
  - PR-3b atomic trio (read-cutover + Phase-01 D-12 parity-lint SOFT→HARD + pg_dump 7th gate)
  - PR-4 FF removal + DeprecationWarning + `no_ff_fact_event_dual_write.py` HARD lefthook
  - PR-5 alembic `p117_drop_snapshot_legacy` + decommission runbook + B19 tests inventory
- See `mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-SUMMARY.md`.

### Plan 02-04 — close-out-counters-runbooks
**STATUS : PARTIAL — close-out artifacts shipped (this PR), autonomous tasks split to Phase 02-deploy.**
- Close-out artifacts (VERIFICATION-REPORT.html + SUMMARY.md + STATE.md + ROADMAP.md + PROJECT.md + Phase 02-deploy CONTEXT.md bootstrap) : ship in this PR.
- Task 1 D-09 S12 alias removal + D-10 PR-A3 dead-fields + allowlist cleanup : SPLIT (gated on PR-3b shipping the allowlist + HARD-mode parity-lint first).
- Task 2 Q6 CI mechanical fixes (STAGING-MALFORMED + scheduled-only aging + STAGING-DOWN-OVERRIDE label CODEOWNER-gated) : SPLIT (autonomous, will ship as own PR in Phase 02-deploy).
- Task 3 `declared_counters_must_fire.py` HARD close-out gate (asserts all 8 declared counters fire) : SPLIT (autonomous, own PR).
- Task 4 forward-deferred runbooks (`docs/operations/fact-event-partition-split.md` + `docs/operations/dek-rotation-phase04.md` + `docs/operations/audit-pepper-rotation.md`) : SPLIT (autonomous, own PR).
- Plus 5 sec/arch FLAGs from QA panel (sec FLAG-2 scenario_inputs_hash quasi-identifier + sec FLAG-4 DSAR manifest event_log entry + sec FLAG-5 pre-existing baseline trim + arch FLAG-2 UUID4→UUID7 + arch FLAG-3 subject_type forward-lint) : SPLIT.

## 33 D-XX dispositions

> Cross-references the CONTEXT.md decision register (D-01 through D-33). Status legend : ✅ shipped on dev · 🔄 code shipped, operational deploy split · ⏸ split to Phase 02-deploy.

| D-XX | Title | Status | Notes |
|------|-------|--------|-------|
| D-01 | Bitemporal vs event-log substrate (event-log chosen) | ✅ | ADR `2026-05-17-data-architecture-event-log-vs-bitemporal.md` |
| D-02 | DEK envelope encryption (per-user DEK + KMS-wrapped) | ✅ | key_vault.py + dek_vault + EncryptedValue helper |
| D-03 | hmac_pepper for audit user_id hashing | ✅ | hmac_pepper.py + HARD lint `hmac_pepper_audit.py` |
| D-04 | Constants propagation point-in-time (no retroactive re-flag) | ✅ | PR-2 dual-write parity test proves contract |
| D-05 | Big-bang 6-PR migration sequence (was 5-PR) | 🔄 | PR-0/1/2/3a code shipped ; PR-3b/4/5 split |
| D-06 | Q6 CI staging-down policy (STAGING-MALFORMED + scheduled-only + override label) | ⏸ | Plan 02-04 Task 2 split to Phase 02-deploy |
| D-07 | Audit retention 10y + REVOKE assertion + pepper-rotation runbook | ⏸ | runbook split to Phase 02-deploy Task 4 |
| D-08 | S12 façade preservation + S23 rename (FrontalierSegmentService) | ✅ | Plan 02-01 PR-A1 |
| D-09 | S12 PR-2 alias removal | ⏸ | Plan 02-04 Task 1 — gated on PR-3b |
| D-10 | D-MOB-01 PR-A3 drop 3 dead Flutter-only fields | ⏸ | Plan 02-04 Task 1 — gated on PR-3b allowlist file existing |
| D-11 | Karpathy Wiki user-profile (not RAG) | ✅ | Plan 02-01 — wiki memory model adopted |
| D-12 | Parity-lint SOFT→HARD timing (atomic with PR-3b read-cutover per D-31) | ⏸ | Phase 02-deploy |
| D-14 | fact_event substrate creation (p98) | ✅ | Plan 02-02 PR #657 |
| D-15 | fact_current substrate creation (p98 same migration) | ✅ | Plan 02-02 PR #657 |
| D-16 | Q6 staging tiered 7/14/28-day escalation (baseline) | ✅ | Already in dev (Phase 01 W4) |
| D-17 | Multi-shape canary fixtures (5 shapes per profile) | ✅ | Plan 02-02 PR #657 |
| D-18 | FactProjector with atomic UPSERT under Read Committed | ✅ | Plan 02-02 PR #657 |
| D-19 | Atomicity contract : session.begin_nested() for projector | ✅ | Plan 02-02 PR #657 (PR-2 dual-write inherits) |
| D-20 | Mobile L1 audit POST `/v1/audit_mobile` | ✅ | Plan 02-02 PR #657 |
| D-21 | Mobile L1 audit observer + OfflineAuditQueue + InMemoryAuditBufferDb | 🔄 | Code shipped ; device-side prod impl + iOS entitlement split |
| D-22 | testcontainers Postgres harness (pg_fixture + requires_pg marker) | ✅ | Plan 02-01 PR #653 |
| D-23 | hmac_pepper audit lint HARD on services/backend/app/ | ✅ | Plan 02-01 PR #653 |
| D-24 | hmac_user_id() helper + bare hashlib.sha256 ban | ✅ | Plan 02-01 PR #653 |
| D-25 | W1 canary GATE test_canary_monthly_gross_income | ✅ | Plan 02-02 PR #657 |
| D-26 | DEK envelope encryption helpers (encrypt_value/decrypt_value) | ✅ | Plan 02-02 PR #657 |
| D-27 | fact_event UNIQUE constraint (event_id + subject_id + fact_type + observed_at + recorded_at) | ✅ | Plan 02-02 PR #657 ; backfill idempotency relies on this |
| D-28 | DEK shred opacity (crypto-shred via wrapped_dek=NULL) | ✅ | Plan 02-02 PR #657 |
| D-29 | KMS backend failure counter + DEK cache size gauge | ✅ | iter-2 A4/A5 — Plan 02-02 PR #657 |
| D-30 | Multi-shape parity GATE test_canary_multi_shape_parity | ✅ | Plan 02-02 PR #657 |
| D-31 | Phase-01 D-12 parity-lint promotion atomic with PR-3b cutover (7-day soak, 14-day target) | ⏸ | Phase 02-deploy |
| D-32 | 5-gate mechanical exit checklist | 🔄 | G3/G4/G5 met ; G1/G2 deferred (no UI surface, no operational deploy yet) |
| D-33 | 6+2 observability counters declared + ASSERTED firing | 🔄 | Declared ; firing assertion (Task 3) split |

## Karpathy alignment

- **#1 Think Before Coding (don't assume, surface tradeoffs).** Surfaced 2 major tradeoffs this session : (a) prod has 2 users not 0 (preflight script returned BLOCKED → asked Julien for the call) ; (b) substrate code-only vs deploy split (presented Option A vs B vs C vs D ; Julien delegated, I made the call for Option A SPLIT with full rationale).
- **#2 Simplicity First (minimum code).** Refocused mid-session : reverted partial regulatory-codegen.yml edits + CODEOWNERS edits when I realized Plan 02-04 Task 2/3/4 don't gate substrate close-out. Shipped 1 surgical PR (#658 consent caplog fix) + close-out artifacts only.
- **#3 Surgical Changes (touch only what you must).** PR #658 changes 1 file (2 test methods) for the dev-CI-failure fix. No drive-by refactors. Phase 02 close-out artifacts are documentation only ; no code-mutation in this PR beyond what's strictly required for the substrate close-out narrative.
- **#4 Goal-Driven Execution (verify before completing).** Used <code>railway ssh</code> to deterministically verify staging + prod DB state instead of trusting the « substrate landed on dev » narrative. Citation-backed every claim in the VERIFICATION-REPORT.html per 0-trust §9.6.

## Counter-arguments + data gaps

(Per CLAUDE.md §8 wiki-lint convention — bias-check against echo-chamber.)

### Counter-arguments considered

1. **« Phase 02 should be COMPLETE since 4 plans have code on dev. »** Substrate is complete as substrate. But Plan 02-03 explicitly carries `autonomous: false` with operational checkpoints (Task 2a + Task 4) that depend on staging+prod DB state. Per 0-trust §9.2 « tests passing != feature working » — PRs merged != schema deployed. Marking COMPLETE without operational deploy conflates the two.
2. **« Run Task 2a operational gate against staging today and ship PR-3b. »** Cannot — staging has 0 snapshots and no fact_event table. The backfill is a no-op and the projection_diff audit has nothing to diff. Forcing PR-3b would create read-paths to non-existent tables.
3. **« Apply migrations to staging+prod in this session. »** Prod alembic head is `29_05_magic_link_tokens` — dozens of migrations behind dev. This implies Phase 01 + sequence-coordinator + earlier substrate migrations are also undeployed. Advancing prod blindly is high-risk. Phase 02-deploy needs a dedicated session with rollback prep.
4. **« The 2 prod users are test accounts so we're safe. »** Confirmed by Julien 2026-05-19. Per `preflight_zero_user_gate.py` contract this is documented justification, not premise validation. The big-bang migration is safe in principle, but staging-first + smoke is still the responsible deploy order.

### Data gaps

- **Cron sampler 7-day soak window** — not started ; gated on PR-3a being deployed (not yet). Phase 02-deploy will start the soak after staging migration applies.
- **Sentry alarm wiring for `mint_snapshot_fact_current_drift_total`** — declared in code but not configured in Sentry dashboard. Phase 02-deploy close-out task.
- **Why prod alembic is at `29_05_magic_link_tokens`** — unknown. Could be a fork, an old branch deploy, or a never-cleaned state from before Phase 01. Phase 02-deploy must audit-and-decide.
- **BYOK vs ServerKey for the 2 prod users** — per memory `project_byok_scope`, current builds use ServerKey. The 2 test accounts are presumed ServerKey-backed. Verify before any DEK rotation work.
- **Plan 02-04 Task 3 `declared_counters_must_fire` self-test fixture** — not yet validated end-to-end ; deferred to its own PR in Phase 02-deploy.

## 0-Trust §9.6 Evidence + Caveat

**Evidence (this session, 2026-05-19, claim-by-claim) :**

| Claim | Evidence |
|-------|----------|
| dev HEAD `e19461f1`, alembic at `p119_phase02_parity_cont` | `git rev-parse HEAD` + `python3 -c "from alembic..."` at session start |
| Staging MINT DB at `p112_audit_event_user_hash`, 131 users, 0 snapshots, no fact_event | `railway ssh -e staging --service MINT` python3 query captured 2026-05-19 |
| Prod MINT DB at `29_05_magic_link_tokens`, 2 users (test accts), 0 snapshots, no fact_event | `railway ssh -e production --service MINT` python3 query captured 2026-05-19 |
| 4 substrate PRs squash-merged | `git log --oneline e19461f1~6..e19461f1` |
| PR #658 opened | https://github.com/MINT-IA/MINT/pull/658 |
| Engram obs #233 saved | `mem_search "phase02 substrate"` returns the operational gap finding |

**Caveat (what I have NOT done) :**

- I have NOT run the full backend pytest suite on dev HEAD this session — only the targeted consent-extensions file (9/9 pass).
- I have NOT applied any migrations to staging or prod in this session. Zero mutation of any deployed environment.
- I have NOT enabled the 7-day continuous_drift_sampler cron. It ships in code but is workflow_dispatch-only until Phase 02-deploy starts the soak.
- I have NOT verified PR #658 CI completion at the time of writing this SUMMARY (CI is in flight ; check at end of session).
- I have NOT executed Plan 02-04 Task 2/3/4 PRs. They are explicitly split to Phase 02-deploy.

## Mem_save reference

```
title: Phase 02 substrate is code-only on dev — NEVER deployed to staging/prod (2026-05-19)
id: 233
topic_key: mint-data-architecture-v1-02:operational-substrate-gap
project: mint
```

Use `mem_get_observation 233` to retrieve full text in future sessions.

## Next-phase pointer

See `.planning/phases/mint-data-architecture-v1-02-deploy/CONTEXT.md` (created in this PR) for Phase 02-deploy scope.
