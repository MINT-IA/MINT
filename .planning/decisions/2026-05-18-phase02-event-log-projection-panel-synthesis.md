---
date: 2026-05-18
status: Decided
authors: Julien Battaglia (final calls) + 7-specialist panel synthesis
panel: 7-pers (architect-review + database-architect + threat-modeling-expert + devops-troubleshooter + postgres-pro + 2 hotfix auditors)
supersedes: —
superseded_by: —
description: Phase 02 event-log + projection schema migration — 7 open questions resolved + S12/Flutter/Mobile-L1-audit decisions locked + 4 Phase 01 carry-over gaps
related:
  - .planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md
  - .planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/mint-data-architecture-v1-01-calc-engine-CONTEXT.md
  - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VERIFICATION.md
---

# Phase 02 event-log + projection — panel synthesis + locked decisions

## TLDR

Phase 02 ships event-log (`fact_event` append-only) + projection (`fact_current` denormalised) + DEK envelope (per-user, Railway-native KMS) + projection_audit_record extension for mobile L1 sessions. Big-bang cut-over pre-launch. Strict Postgres test harness mandatory.

## Context

Phase 01 (mint-data-architecture-v1-01-calc-engine-canonical) shipped 2026-05-17 — calc-engine ownership resolved via split-with-arbiter (L1 mobile, L2-L4 backend), regulatory constants sync wired. Phase 02 is the load-bearing user-facts schema migration the panel ADR (`.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md`) proposed but deferred concrete decisions.

The ADR listed 7 open questions. This synthesis closes each, plus 3 design panels (S12 API consolidation, Flutter drift + dead-COUP-04, Mobile L1 audit-trail gap) discovered during Phase 02 readiness work, plus 4 security gaps surfaced by the post-Phase-01 audit.

Empirical validation arrived mid-session : QA panel obs #187 flagged « Migration test harness on sqlite:///:memory: won't catch Postgres-specific DDL » 5 min before exactly that class of bug crashed staging deploy (Hotfix B p111 `BOOLEAN DEFAULT 0` Postgres rejection, fixed at `fe52ba31`).

## Decision

### Q1 — fact_current latency target
p50 ≤ 5 ms, p99 ≤ 20 ms, p99.9 ≤ 50 ms — REALISTIC FastAPI-side from Railway-managed Postgres (NOT sub-1ms which is Postgres-internal-only). PK composite `(subject_type, subject_id, fact_type)` + covering index `(subject_id) INCLUDE (value_enc, latest_event_id, confidence, visibility)`. Partition-ready from day one (`PARTITION BY HASH (subject_id)` with 1 partition) ; split at 5M rows or p99 > 20ms.

### Q2 — KMS provider (Julien call)
**Railway-native + logical key-id `kms_key_ref='mint-master-v1'`** for portability. AWS KMS over-engineering for solo engineer pre-launch ; Vault self-hosted = malpractice. Re-litigate at >10k users or first EDÖB/FINMA inquiry.

### Q3 — DEK shred granularity (Julien call alignment)
**All-or-nothing per user** in Phase 02. Add `dek_scope` column (default `'user'`) for future-proofing Phase 04 per-category sub-DEKs. nLPD art. 32 + GDPR art. 17 don't require granular erasure ; account-closure = compliance-sufficient.

### Q4 — Constants propagation on law change
**Snapshot point-in-time only.** NEVER re-flag historical projections. LSFin satisfied by `projection_audit_record.constants_version_hash` (Hotfix B shipped). Re-flagging breaks Triplet #8 no-promise doctrine + trains user distrust. Optional « Recalculer ? » CTA is Phase 03+ marketing, NOT compliance.

### Q5 — Migration strategy from SnapshotModel
**Big-bang cut-over, 5-PR sequence** (postgres-pro). Pre-launch + zero prod data = the only window. PR-1 schema introduction (additive) → PR-2 dual-write feature-flagged off → PR-3 backfill script idempotent → PR-4 read cut-over → PR-5 legacy drop (post-launch gate).

### Q6 — CI staging-down failure mode
Tiered 7/14/28-day escalation KEEP + 3 mechanical fixes :
1. `STAGING-MALFORMED` status (200 with shape-invalid payload) on faster 2/7/14d schedule
2. Aging state writes on scheduled workflow (cron 6h on `dev`), per-PR runs READ-ONLY (race fix)
3. HARD-mode (Phase 02 D-12 promotion) fail-closed on staging-down with explicit `STAGING-DOWN-OVERRIDE` PR label (audit-trail not skip+warn)

### Q7 — Audit retention
10y hot Postgres, hashed user_id with HMAC-pepper (NOT bare SHA-256 — current `hash_user_id()` is rainbow-table-reversible on UUID space ; security-auditor non-negotiable). Pepper lives in Railway secrets. REVOKE UPDATE/DELETE on `fact_event` + `projection_audit_record`. Delete-after-10y job DEFERRED (trigger = Railway bill > CHF 100/mo on this table).

### S12 API consolidation (deferred from mint-calc-engine-v1)
**Composition pattern** : S12 `IndependantService.analyze()` stays as segment-level façade, internally delegates calculator primitives to S18 (`calculer_*` functions). Same for `frontalier` + rename `FrontalierService` → `FrontalierSegmentService` (S23 has 5x more downstream surfaces — least blast radius). 2-PR migration (PR-1 façade-delegate + rename + IJM/LAA promote to S18 ; PR-2 alias removal). PR-1 must land BEFORE Phase 02 W1 event-log writer PRs.

### Flutter 45-field drift + dead-COUP-04 + Mobile L1 audit (D-MOB)
- **D-MOB-01** Drift fix : baseline 45→43 fields post-Stage-0. PR-A2 = extend `_buildProfileContext()` to emit 15 missing fields without `> 0` guard ; PR-A3 = drop 3 dead Flutter-only fields. Final → promote `profile_safe_fields_parity` SOFT→HARD.
- **D-MOB-02** dead-COUP-04 : verified closed end-to-end. 1 integration test to lock contract.
- **D-MOB-03** Mobile L1 audit POST : EXTEND existing `projection_audit_record` (NOT new table — fragments 10y retention) with `source` discriminator + `app_version` + `observed_at`. Alembic p113 additive. Endpoint `POST /v1/audit/mobile-session-start`. 2 lifecycle hooks (cold start + warm-resume >30min). Offline SQLite queue (LSFin durability). **Anonymous sessions = buffer-and-link** after first login (Julien call).
- **D-MOB-04** : mobile L1 audit does NOT dual-write `fact_event` (clean separation : user-facts encrypted+shreddable vs compliance metadata hash-only 10y).

### Side-finding fixed
`apps/mobile/lib/services/api_service.dart:187` hardcoded `_appVersion='1.0.0'` replaced with `package_info_plus` boot init (commit `ce24c963`). Required before D-MOB-03 ships so mobile L1 audit doesn't log app_version=1.0.0 for 10y.

### 4 Phase 01 carry-over gaps (Phase 02 W1 must-haves)
1. `audit_events.user_id_hash` backfill + drop plaintext column on envs without pgcrypto
2. Hash `actor_email` + `ip_address` + `user_agent` (currently still plaintext PII)
3. `/privacy/delete` real count (currently hardcoded `nb_sessions=0` zeros — DSAR receipt misleading)
4. `SnapshotModel.constants_version_hash` cache invalidation wiring (currently evidence trail only, not cache key)

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  AWS KMS eu-central-2 with HSM (FIPS 140-2 L3) is the « correct » Swiss financial choice per FINMA-defensible interpretation. Railway-native = vendor lock + no audit trail of per-key operations + Railway may not be FINMA-acceptable for production deposit-holding. Threat-modeling-expert (obs #175) recommended AWS over Railway for exactly these reasons. The counter-argument is « pre-launch + zero deposits + solo engineer makes the cheap-and-portable trade-off correct TODAY but will be the wrong call within 12 months of first paying CH user. » We accept that trade-off knowingly and gate re-litigation on >10k users or first regulator inquiry.

  Similarly, AWS KMS would force the HMAC-pepper to live in AWS Secrets Manager not Railway secrets — slightly stronger separation but more cross-cloud complexity. We accept the Railway-secret-stored pepper as sufficient pre-launch.

- **What does this source not address ?**
  - Empirical p99 latency under Phase 02 schema : we estimate 8-15ms FastAPI-side based on Railway-managed Postgres bench convention, but have NO real workload measurement on `fact_current` shape. First W1 PR must instrument `mint_fact_current_read_latency_ms` histogram to validate empirically.
  - DEK shred performance under bulk request : Phase 04 per-category sub-DEK migration cost is unmeasured. We estimate ~$1/CMK/month × N categories but never benchmarked re-encryption of existing blobs at scale.
  - Mobile L1 audit POST battery cost : estimated trivial (~1.5KB JSON × 3 sessions/day) but not measured on cellular vs WiFi.
  - LSFin audit retention semantics if user is deleted then re-creates : do we re-link the audit chain via shared `user_id_hash` (HMAC-pepper stable across deletions) or treat as new identity ? Phase 02 designs the former by default — re-litigate if regulator pushes back.
  - Constants propagation gap for offline mobile sessions : if user is offline at moment of constants change, the next sync may show « old constants used » in audit but user's offline screenshot shows post-change values. Off-by-one risk under D-08 runtime delta-check ; current design accepts a 7d/30d staleness window per D-07.

- **What would change this conclusion ?**
  - First paying CH user with deposit > 100K CHF → revisit Q2 KMS (Railway may not be FINMA-defensible at that scale)
  - p99 fact_current PK reads > 50ms sustained → revisit Q1 latency target (escape hatch : Postgres UNLOGGED table OR `pg_prewarm` BEFORE adding Redis)
  - First nLPD partial-deletion request OR EDÖB inquiry → bring Q3 per-category sub-DEK forward
  - First FINMA written guidance requiring single-table bitemporal source-of-truth → revisit Q4 snapshot-PIT and re-examine the panel ADR's event-log shape
  - First migration that introduces non-empty backfill (>1k rows) → revisit Q5 big-bang vs dual-write
  - Railway adds Prometheus scraping native → enables Q6 metrics infrastructure path stayed Railway-native (memory feedback_grafana_cloud_dropped)
  - Railway bill > CHF 100/mo from `projection_audit_record` table → activate Q7 delete-after-10y job

## Phase 02 scope (locked)

### W0 (prereqs, ~1 week solo)
- `alembic_boolean_default_lint.py` HARD lefthook (catches the Hotfix B class at commit-time)
- Codegen timestamp determinism : `regulatory_constants_to_dart.py:277,282` `Generated at: <utcnow>` → `Generated for effective_on: <date>` (so D-12 HARD mode doesn't get noise diffs)
- Real-Postgres migration test harness (replaces `DATABASE_URL=sqlite:///:memory:` for migration tests via pg fixture)
- S12 PR-1 (façade-delegate + rename + IJM/LAA promote to S18) — load-bearing : Phase 02 W1 event-log writers consume S12/S18 boundary
- Flutter PR-A2 (extend `_buildProfileContext` for 15 missing fields)
- pg_dump baseline snapshot committed
- HMAC-pepper site uniformly applied to all user_id_hash sites (gap #1 + #2 carry-overs)

### W1 (event-log core, ~1.5 weeks solo)
- Alembic p98 (`fact_event` + `fact_current` + extend `projection_audit_record` for D-MOB-03)
- App-side projection (with session.begin()), NOT db trigger (observability > simplicity per postgres-pro)
- DEK envelope wired BEFORE first INSERT (`ensure_user_dek()` integration test mandatory)
- Mobile L1 audit POST + Alembic p113 + Flutter service + offline SQLite queue
- `/privacy/delete` real count fix (gap #3 carry-over)
- `SnapshotModel.constants_version_hash` cache invalidation wiring (gap #4 carry-over)
- First-slice canary : single fact (`monthly_gross_income`) end-to-end with parity test

### W2-W4 (migration + cleanup)
- 5-PR migration sequence : dual-write → backfill → read cut-over → legacy drop
- Promote D-12 parity lint SOFT → HARD (atomic with first migration)
- Q6 CI fixes (STAGING-MALFORMED + race-fix + HARD label override)
- `declared_counters_must_fire.py` close-out gate
- S12 PR-2 alias removal (atomic with migration cut-over)
- Auth-coach G2 scenario E variant authoring + Maestro flow D refactor

### Out / Deferred
- Per-category DEKs → Phase 04 (trigger : 1st granular deletion or EDÖB inquiry)
- Constants « Recalculer » CTA → Phase 03+ marketing
- S3 Glacier 9y archive → trigger Railway bill > CHF 100/mo on this table
- Sigstore Rekor Merkle anchoring → trigger 1st LSFin complaint

## How to apply

Phase 02 plan-phase (gsd-planner agent) reads THIS ADR as the single canonical source. The 7 Q decisions + 4 carry-over gaps + D-MOB design feed directly into wave/plan splits per CLAUDE.md §6 GSD workflow.

W0 prerequisites land as a single bundle before W1 writer code touches `fact_event`. Every Phase 02 PR ends-to-end requires:
1. Real-Postgres migration test (no sqlite-only)
2. HMAC-pepper applied to any new user_id_hash site
3. `constants_version_hash` column on every new table
4. Reversibility gate (downgrade not NotImplementedError)
5. atomic doctrine gate (if doctrine files touched)

The `decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md` ADR remains the upstream « what shape » document ; THIS ADR is the « how + when + with which trade-offs » follow-up that closes the deferred decisions.

## Engram observation index

| ID | What |
|---|---|
| #163 | Phase 01 CONTEXT (16 D-XX decisions) |
| #169 | Cleanup bug (destructive untracked-files delete) |
| #172 | Phase 01 VERIFICATION 16/16 PASS |
| #174 | Phase 02 database-architect verdict (Q1+Q4+Q5) |
| #175 | Phase 02 threat-modeling verdict (Q2+Q3+Q7 + STRIDE) |
| #176 | Phase 02 architect-review integrated verdict + mobile L1 audit gap discovery |
| #178 | Phase 02 devops verdict (Q6 + PR-readiness 8-item + counters) |
| #180 | Track-B Claude-actionable default (Julien correction) |
| #182 | Q6 Railway-native metrics scraping decided |
| #183 | S12 API consolidation design |
| #185 | G2 sweep pre-fix BLOCKED on Railway |
| #186 | Flutter D-MOB design + audit gap fix |
| #187 | QA methodical sweep (predicted Postgres bug 5min before surface) |
| #188 | Postgres BOOLEAN DEFAULT bug root cause + fix |
| _next_ | G2 sweep retry (2 PASS / 1 BLOCKED / 2 DEFERRED) |

---

*Drafted by Claude Opus 4.7 (orchestrator) 2026-05-18 from 7-specialist panel + 3 Julien-locked calls. Status `Decided` per ADR template — pre-implementation panel synthesis with concrete trade-off acknowledgement.*
