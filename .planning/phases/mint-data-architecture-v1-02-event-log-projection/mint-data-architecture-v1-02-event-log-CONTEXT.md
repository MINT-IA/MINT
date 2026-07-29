---
description: Phase mint-data-architecture-v1-02-event-log-projection — migrate user-facts storage from `SnapshotModel` (cached projection keyed on inputs_hash) to event-log (`fact_event` append-only) + projection (`fact_current` denormalised) + DEK envelope per-user (Railway-native KMS), extend `projection_audit_record` for D-MOB-03 mobile L1 sessions (anonymous-session buffer-and-link), wire DEK before first INSERT, big-bang 5-PR cut-over pre-launch with strict Postgres test harness. Locks 33 decisions across 4 areas: (1) 7 panel-debated Qs on latency / KMS / DEK / audit policy / migration / CI / retention ; (2) S12 consolidation + D-MOB design completion + 4 Phase 01 carry-over gaps ; (3) 4-plan wave structure (W0/W1/W2-W3/W4), app-side projector with `session.begin()`, W0 prereq bundle ; (4) `fact_event` schema concretes (typed `value_enc` JSONB + idempotency UNIQUE constraint + partition declaration in p98 + full `EnhancedConfidence` 4-axis), anonymous-session buffer mechanics (mobile SQLite, 30d TTL, UUID v7), D-12 parity-lint SOFT→HARD atomic with PR-3 read cut-over, 5-gate exit checklist with 6 new observability counters.
---

> **Statut : CLOS 2026-07-29** — clos sur receipt SUMMARY « substrate-complete-on-dev » : le substrat event-log est sur dev ; la suite vit dans les campagnes dev (étalon fiscal #1060-#1100) et Journey OS. Réconciliation plans 2026-07-29.

# Phase mint-data-architecture-v1-02-event-log-projection — Context

**Gathered:** 2026-05-18
**Status:** Ready for planning
**Source of decisions:** discuss-phase 2026-05-18 (Julien × Claude, 4 gray areas confirmed bundle)
**Upstream artifacts:**
- [.planning/decisions/2026-05-18-phase02-event-log-projection-panel-synthesis.md](../../decisions/2026-05-18-phase02-event-log-projection-panel-synthesis.md) — THIS phase's « how + when + trade-offs » lockdown (7-specialist panel synthesis + 3 Julien-locked calls). Single canonical source for 23 carry-forward decisions.
- [.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md](../../decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md) — upstream « what shape » ADR (panel-converged event-log + projection + DEK envelope).
- [.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/mint-data-architecture-v1-01-calc-engine-CONTEXT.md](../mint-data-architecture-v1-01-calc-engine-canonical/mint-data-architecture-v1-01-calc-engine-CONTEXT.md) — Phase 01 16 D-XX LOCKED decisions (split-with-arbiter L1 mobile / L2-L4 backend, `lucidity._payload` discriminator). This phase MUST NOT undo any.

## TLDR

Phase 02 ships three new tables — `fact_event` (append-only event log) + `fact_current` (denormalised PK-indexed projection) + `user_dek` (per-user crypto-shred envelope) — replacing `SnapshotModel` as the canonical user-facts substrate. Mobile L1 chiffrer (per Phase 01 D-01) continues writing through codegen-baked constants to local L1 outputs ; backend L2-L4 surfaces consume `fact_current` via PK reads (p50 ≤ 5ms, p99 ≤ 20ms FastAPI-side). The `projection_audit_record` table (Hotfix B shipped 2026-05-17) extends with `source` discriminator + `app_version` + `observed_at` + `anonymous_session_id` to absorb mobile L1 session audit (D-MOB-03), closing the LSFin audit-trail gap surfaced by architect-review obs #176.

Migration is **big-bang 5-PR cut-over** (postgres-pro, panel-locked) — pre-launch + zero prod data is the only window. Within Phase 02 : W0 prereqs bundle (1 plan : real-Postgres test harness + alembic_boolean_default_lint HARD + codegen timestamp determinism + S12 PR-1 façade-delegate + HMAC-pepper site sweep + Flutter PR-A2 drift fix) → W1 event-log core + canary fact on `monthly_gross_income` + Mobile L1 audit POST + 2 carry-over fixes → W2-W3 5-PR migration sequence (dual-write FF-OFF → backfill → read cut-over with atomic D-12 SOFT→HARD parity-lint promotion → legacy drop) → W4 close-out (S12 PR-2 alias removal + Q6 CI mechanical fixes + declared_counters_must_fire gate + auth-coach G2 scenario E).

KMS is **Railway-native** with logical key-id `mint-master-v1` (Q2 Julien call). DEK shred is **all-or-nothing per user** with `dek_scope` column future-proofed for Phase 04 sub-DEKs (Q3). Constants propagation is **snapshot point-in-time only** — historical projections never re-flagged (Q4). Audit retention is **10y hot Postgres** with HMAC-pepper user_id_hash (Q7) — REVOKE UPDATE/DELETE enforced on `fact_event` + `projection_audit_record`. Q6 CI staging-down policy ships 3 mechanical fixes (STAGING-MALFORMED + scheduled-only aging writes + HARD-mode STAGING-DOWN-OVERRIDE label).

Anonymous-session L1 audit (D-MOB-03 Julien call) buffers in mobile SQLite (offline-capable, no backend ephemeral PII surface) with 30d TTL ; first login triggers single batch POST `/v1/audit/mobile-session-link` with stable UUID v7 `anonymous_session_id` carried into the projection_audit_record column. Mobile L1 audit explicitly does NOT dual-write `fact_event` (clean separation : user-facts encrypted+shreddable vs compliance metadata hash-only 10y retention — D-MOB-04).

Phase 02 exit = 5-gate mechanical check : G1 Maestro walker + offline-queue replay · G2 Julien device end-to-end (anonymous → cold-start → warm-resume → login → link → continuous chain visible) · G3 dev CI HARD lints + REVOKE-DDL assertion + Postgres-real migration test · G4 pytest + 2 new test classes (projector idempotency + DEK shred opacity) · G5 LSFin + accent + ARB + constants drift HARD + HMAC-pepper site lint. 6 new observability counters wired via `declared_counters_must_fire.py` close-out gate.

## Counter-arguments and data gaps

### Strongest opposing view

Steel-man for keeping Snodgrass SCD2 bitemporal as single canonical table (rejected by upstream ADR, re-litigated here for Phase 02 commit gate) :

> *« The migration is asymmetric : we're throwing away a working `SnapshotModel` for three new tables + a KMS dependency + a DEK envelope + an app-side projector — four new failure modes, four new monitoring surfaces, four new alembic-rollback paths. The 'big-bang pre-launch with zero prod data' framing is sleight of hand : the moment the first user signs up, the rollback path collapses. SCD2 with envelope-encrypted `value` columns gives identical erasure semantics with one table, one query path, one Postgres extension (`pgcrypto`) and zero projector lag. The 'audit trail' advantage of event-log over SCD2 is illusory : SCD2 already records every supersession with a row. The 'sub-1ms PK read' advantage of fact_current is irrelevant : FastAPI-side latency floor is 5-8ms regardless of Postgres-internal time. We're shipping complexity to satisfy an architecture-review aesthetic. »*

This argument carries weight. The mitigation is that **crypto-shred opacity requires a decrypt step at read time** — once `value` becomes opaque ciphertext to satisfy nLPD/GDPR erasure, SCD2's predicate-query advantage evaporates (Postgres can't index on encrypted blobs), and a separate decrypted projection becomes operationally necessary. The end state is event-log + projection + DEK envelope either way ; the question is whether to design for it now (pre-launch, zero prod data, 5 PRs) or after 18 months of iteration pain. We accept the « 4 failure modes » cost knowingly because (a) the projector is app-side with `session.begin()` so it's transactional, not async-eventual ; (b) the canary fact validates end-to-end parity before the 5-PR migration starts ; (c) Phase 02 ships 6 new observability counters (D-33) including `mint_projector_idempotency_skip_total` + `mint_dek_envelope_status_total` so the failure surface is visible before it bites.

Steel-man for AWS KMS over Railway-native (rejected by Julien call, re-litigated for commit gate) :

> *« AWS KMS eu-central-2 with HSM (FIPS 140-2 L3) is the FINMA-defensible Swiss financial choice. Railway-native = vendor lock + no per-key audit trail + Railway may not be FINMA-acceptable for production deposit-holding. Threat-modeling-expert (obs #175) recommended AWS over Railway for exactly these reasons. »*

We accept the trade-off knowingly. Pre-launch + zero deposits + solo engineer makes the cheap-and-portable choice correct TODAY but **will** become the wrong call within 12 months of first paying CH user. The `dek_scope` column + logical key-id `mint-master-v1` (not a Railway-encoded key path) preserve the migration path. Re-litigation triggers : (1) first paying CH user with deposit > 100K CHF, (2) first EDÖB/FINMA inquiry, (3) Railway adds FIPS 140-2 attestation.

### What this discussion did NOT address

- **Empirical p99 latency under Phase 02 schema** — estimate 8-15ms FastAPI-side based on Railway-managed Postgres convention but NO real workload measurement on `fact_current` shape. First W1 PR (Plan 02-02) MUST instrument `mint_fact_current_read_latency_ms` histogram with p99 alert threshold to validate empirically before the 5-PR migration starts. If p99 > 50ms sustained in canary, escape hatch is Postgres UNLOGGED + `pg_prewarm` BEFORE adding Redis.
- **DEK shred performance under bulk request** — Phase 04 per-category sub-DEK migration cost unmeasured. Estimate ~$1/CMK/month × N categories on Railway. Re-encryption of existing blobs at scale never benchmarked. Phase 02 does NOT need this measurement but planner should leave Phase 04 escape hatch annotated in Plan 02-02 DEK envelope wiring.
- **Mobile L1 audit POST battery cost** — estimated trivial (~1.5KB JSON × 3 sessions/day, batched offline queue replays) but not measured on cellular vs WiFi. Plan 02-02 Mobile L1 audit deliverable should include a battery-cost measurement as G2 device-gate sub-check (Julien sim run, observe before/after battery slope).
- **LSFin audit retention semantics if user is deleted then re-creates** — do we re-link via HMAC-pepper-stable user_id_hash (current design : same hash across deletions) or treat as new identity ? Phase 02 designs the former by default ; re-litigate if regulator pushes back.
- **Constants propagation gap for offline mobile sessions** — if user is offline at moment of constants change, next sync may show « old constants used » in audit but user's offline screenshot shows post-change values. Off-by-one risk under D-08 Phase 01 runtime delta-check ; current design accepts a 7d/30d staleness window per Phase 01 D-07.
- **The `anonymous_session_id` re-installation risk** — if user wipes app + reinstalls before linking, the previous audit chain becomes orphan (no `user_id_hash` to link to). Phase 02 accepts this as cost of privacy-preserving design (no device fingerprint) ; LSFin auditor can match by `observed_at` + `app_version` + `constants_version_hash` if needed.
- **Projector failure-recovery posture** — if projection write fails after `fact_event` commit within same `session.begin()`, transactional rollback covers it. But what about projector lag if `fact_current` rebuild from `fact_event` is ever needed (corruption, drift) ? Phase 02 ships the rebuild script in Plan 02-02 but does NOT ship the « drift detector » that triggers rebuild. Deferred to backlog : `tools/checks/fact_current_drift_detector.py` if mismatch counter triggers post-launch.

### What would change this conclusion

- **First paying CH user with deposit > 100K CHF** → revisit D-02 KMS (Railway may not be FINMA-defensible at that scale).
- **p99 `fact_current` PK reads > 50ms sustained** in canary or post-launch → revisit D-01 latency target (escape hatch : Postgres UNLOGGED OR `pg_prewarm` BEFORE adding Redis).
- **First nLPD partial-deletion request OR EDÖB inquiry** → bring Phase 04 per-category sub-DEKs forward, use `dek_scope` column.
- **First FINMA written guidance requiring single-table bitemporal source-of-truth** → revisit D-04 snapshot-PIT and re-examine upstream ADR's event-log shape.
- **First migration that introduces non-empty backfill (>1k rows)** → revisit D-05 big-bang vs dual-write.
- **Railway adds Prometheus scraping native** → enables Q6 metrics infrastructure path stayed Railway-native (no Grafana Cloud / Datadog detour).
- **Railway bill > CHF 100/mo from `projection_audit_record` table** → activate D-07 delete-after-10y job (currently DEFERRED).
- **Cleo / RightCapital / consumer fintech publishes post-mortem of event-log + projection architecture in production with concrete failure data** → revisit the whole Phase 02 shape with their evidence on the table.

<domain>
## Phase Boundary

**This phase delivers** :
1. Three new tables (`fact_event` append-only event log + `fact_current` PK-indexed denormalised projection + `user_dek` per-user crypto-shred envelope) via Alembic p98 migration, with REVOKE UPDATE/DELETE enforced on append-only tables.
2. Extension of `projection_audit_record` (Hotfix B shipped 2026-05-17) with `source` + `app_version` + `observed_at` + `anonymous_session_id` columns via Alembic p113 (additive, backfill-safe).
3. DEK envelope wiring before first `fact_event` INSERT — `ensure_user_dek()` integration with `services/backend/app/services/encryption/key_vault.py` (existing 2-backend KMS facade, logical key-id `mint-master-v1`).
4. App-side projector with `session.begin()` (transactional, NOT db trigger).
5. Mobile L1 audit POST endpoint `/v1/audit/mobile-session-start` + `/v1/audit/mobile-session-link` with offline SQLite queue (D-MOB-03) and anonymous-session buffer-and-link mechanics (UUID v7, 30d TTL).
6. First-slice canary on `monthly_gross_income` end-to-end (write fact_event → projector → fact_current decrypted match + existing SnapshotModel still consistent during dual-write phase) with parity test.
7. Big-bang 5-PR migration sequence (Plan 02-03) replacing `SnapshotModel` as canonical user-facts substrate : dual-write FF-OFF → backfill idempotent → read cut-over + D-12 SOFT→HARD parity-lint promotion (atomic) → legacy drop.
8. 4 Phase 01 carry-over security gap closures (`audit_events.user_id_hash` plaintext drop ; hash actor_email/ip_address/user_agent ; `/privacy/delete` real count ; `SnapshotModel.constants_version_hash` cache invalidation wiring).
9. W0 prereq bundle : `alembic_boolean_default_lint.py` HARD lefthook (catches the Hotfix B class at commit-time) + codegen timestamp determinism fix + real-Postgres pg fixture migration test harness + pg_dump baseline snapshot + HMAC-pepper site sweep + S12 PR-1 façade-delegate (composition pattern, IJM/LAA promote to S18, `FrontalierService→FrontalierSegmentService` rename) + Flutter PR-A2 drift fix (extend `_buildProfileContext` for 15 missing fields).
10. W4 close-out : S12 PR-2 alias removal + Q6 CI mechanical fixes (STAGING-MALFORMED status + scheduled-only aging writes + HARD-mode STAGING-DOWN-OVERRIDE label) + `declared_counters_must_fire.py` close-out gate + auth-coach G2 scenario E variant authoring + Maestro flow D refactor.
11. 6 new observability counters declared and wired (`mint_fact_current_read_latency_ms` histogram + `mint_fact_event_insert_total{source_type}` + `mint_dek_envelope_status_total{status}` + `mint_anonymous_session_link_total{outcome}` + `mint_projector_idempotency_skip_total` + `mint_constants_version_mismatch_total`).

**The phase does NOT** :
- Implement coach-extractor LLM with evidence-quote + banlist + TTL + user-visible review surface (Phase 03, gated on Phase 02 completion).
- Implement per-category sub-DEKs / granular erasure (Phase 04, trigger : 1st granular deletion request OR EDÖB inquiry — `dek_scope` column future-proofs).
- Ship S3 Glacier 9y archive of `projection_audit_record` (DEFERRED, trigger : Railway bill > CHF 100/mo on this table).
- Ship Sigstore Rekor Merkle anchoring of audit chain (DEFERRED, trigger : 1st LSFin complaint).
- Migrate Monte Carlo / tornado sensitivity / arbitrage / withdrawal-sequencing calc services to backend (Phase 01 D-11 strangler-fig sequence ; tracked separately as `mint-data-architecture-v1-03+` phases).
- Touch the Phase 01 16 D-XX LOCKED decisions. In particular : D-01 split-with-arbiter L1 mobile / L2-L4 backend, D-02 `lucidity._payload` discriminator boundary, D-04 doctrine rewrite (already shipped), D-08 build-time codegen + runtime delta-check, D-11 Monte Carlo migrates FIRST, D-12 parity lint pattern — all remain in force and constrain Phase 02.
- Add new financial domains, new calculators, new user-facing UI surfaces.
- Reopen the panel ADR : `decisions/2026-05-18-phase02-event-log-projection-panel-synthesis.md` is the canonical PRD ; Phase 02 implements, does not re-litigate.

</domain>

<decisions>
## Implementation Decisions (LOCKED)

The 33 decisions are grouped by the 4 areas crossed in discuss-phase.

### Area 1 — 7 panel-debated open questions (Q1-Q7 from upstream ADR)

- **D-01:** **Q1 — fact_current latency target.** p50 ≤ 5 ms, p99 ≤ 20 ms, p99.9 ≤ 50 ms — REALISTIC FastAPI-side from Railway-managed Postgres (NOT sub-1ms which is Postgres-internal-only per architect-review obs #176). PK composite `(subject_type, subject_id, fact_type)` + covering index `(subject_id) INCLUDE (value_enc, latest_event_id, confidence, visibility)`. Partition-ready from day one (`PARTITION BY HASH (subject_id) PARTITIONS 1`). Split at 5M rows OR p99 > 20ms sustained. Per database-architect obs #174 + postgres-pro verdict.

- **D-02:** **Q2 — KMS provider.** Railway-native + logical key-id `kms_key_ref='mint-master-v1'` for portability. AWS KMS over-engineering for solo engineer pre-launch ; Vault self-hosted = malpractice. Re-litigate at > 10k users OR first EDÖB/FINMA inquiry. Per Julien call obs #182. Logical key-id pattern in `services/backend/app/services/encryption/key_vault.py` already fits.

- **D-03:** **Q3 — DEK shred granularity.** All-or-nothing per user in Phase 02. Add `dek_scope` column (default `'user'`) for future-proofing Phase 04 per-category sub-DEKs. nLPD art. 32 + GDPR art. 17 don't require granular erasure ; account-closure = compliance-sufficient. Per Julien call alignment, security-auditor obs #175.

- **D-04:** **Q4 — Constants propagation on law change.** Snapshot point-in-time only. NEVER re-flag historical projections. LSFin satisfied by `projection_audit_record.constants_version_hash` (Hotfix B shipped). Re-flagging breaks CLAUDE.md Triplet #8 no-promise doctrine + trains user distrust. Optional « Recalculer ? » CTA is Phase 03+ marketing, NOT compliance. Per database-architect obs #174 + architect-review obs #176.

- **D-05:** **Q5 — Migration strategy from SnapshotModel.** Big-bang cut-over, **6-PR sequence** (iter-2 amendment 2026-05-18, locked iter-3 commit `2097c9f5` — split from prior 5-PR per 4-way reviewer convergence : architect-review MED + database-architect MED-6 + postgres-pro MED-5 + qa-expert HIGH×2). Pre-launch + zero prod data = the only window. **PR-0** preflight `SELECT COUNT(*) FROM users` zero-user gate → **PR-1** FF infrastructure (additive p98 schema + `fact_event_dual_write_enabled` flag) → **PR-2** dual-write FF-OFF (writer code added, flag-gated, can be enabled/disabled without redeploy) → **PR-3a** backfill-only idempotent (row-count-delta=0 second-run gate ; 100% staging-user canonical-JSON parity audit persisted to `_phase02_parity_audit`) → **PR-3b** read cut-over atomic with D-12 SOFT→HARD (Phase-01 D-12 parity-lint promotion) per D-31 → **PR-4** dual-write decommission → **PR-5** legacy SnapshotModel drop (post-1-week-observability-soak gate, controlled by `legacy_snapshot_model_active=false` feature flag default-on then default-off). PR-3 split rationale : backfill is operationally separable from cut-over ; original « atomic trio » could leave `fact_current` half-populated AND reads cut over if backfill interrupted mid-run.

- **D-06:** **Q6 — CI staging-down failure mode.** Tiered 7/14/28-day escalation KEEP (Phase 01 shipped) + 3 mechanical fixes :
  1. `STAGING-MALFORMED` status (200 OK with shape-invalid payload) on faster 2/7/14d schedule (separate counter from STAGING-DOWN).
  2. Aging state writes happen ONLY on scheduled workflow (cron 6h on `dev`), per-PR runs READ-ONLY (race-fix : PR run cannot age out the staging-cached version mid-flight).
  3. HARD-mode (Phase 02 D-31 promotion) fails-closed on STAGING-DOWN with explicit `STAGING-DOWN-OVERRIDE` PR label override (audit-trail, not skip+warn). Label scoped to CODEOWNERS (Julien-only via `.github/CODEOWNERS` gate on `.github/workflows/regulatory-codegen.yml`).
  Per devops-troubleshooter obs #178.

- **D-07:** **Q7 — Audit retention.** 10y hot Postgres. `user_id_hash` via HMAC-pepper (NOT bare SHA-256 — current `hash_user_id()` is rainbow-table-reversible on UUID space ; security-auditor non-negotiable obs #175). Pepper lives in Railway secrets (env var `MINT_AUDIT_HASH_PEPPER`). REVOKE UPDATE/DELETE on `fact_event` + `projection_audit_record` enforced at Alembic migration time + asserted in G3 mechanical exit gate. Delete-after-10y job DEFERRED (trigger : Railway bill > CHF 100/mo on this table).

### Area 2 — S12 consolidation + D-MOB design + Phase 01 carry-over gaps

- **D-08:** **S12 API consolidation pattern.** Composition pattern : S12 `IndependantService.analyze()` stays as segment-level façade, internally delegates calculator primitives to S18 (`calculer_*` functions). Same for frontalier + rename `FrontalierService` → `FrontalierSegmentService` (S23 has 5x more downstream surfaces — least blast radius). Promote S12-local `IJM_ESTIMATE_RATE=0.02` + `LAA_ESTIMATE_RATE=0.015` from `independant_service.py:60-64` to S18 (single source of truth for indemnity rate constants). Per architect obs #183 + Julien call.

- **D-09:** **S12 2-PR sequence.** PR-1 (façade-delegate + rename + IJM/LAA promote to S18) lands in Plan 02-01 (W0 prereq, BEFORE W1 writer code touches `fact_event`). PR-2 (alias removal `FrontalierService = FrontalierSegmentService`) lands in Plan 02-04 (W4 close-out, atomic with migration cut-over). Reason : façade-delegate is a non-breaking refactor (safe to land early) ; alias removal is breaking (lands once all downstream surfaces updated).

- **D-10:** **D-MOB-01 — Flutter drift fix.** Baseline 45→43 fields post-Stage-0 (40 server-canonical fields Flutter never sends + 3 Flutter-only fields server drops). PR-A2 (in Plan 02-01 W0) extends `apps/mobile/lib/services/coach/_buildProfileContext.dart` to emit the 15 missing fields without `> 0` guard. PR-A3 drops 3 dead Flutter-only fields. After both ship, promote `tools/checks/profile_safe_fields_parity.py` SOFT→HARD. Per Flutter D-MOB design obs #186.

- **D-11:** **D-MOB-02 — dead-COUP-04 verified closed.** Cleared end-to-end. 1 integration test locks contract in Plan 02-01 (`tests/integration/test_coup_04_dead_path.py`).

- **D-12:** **D-MOB-03 — Mobile L1 audit POST.** EXTEND existing `projection_audit_record` (NOT new table — fragments 10y retention). Alembic p113 adds columns : `source VARCHAR(32) NOT NULL DEFAULT 'projection'` discriminator (values : `'projection'` | `'mobile_session_start'` | `'mobile_session_warm_resume'`) + `app_version VARCHAR(32) NULL` + `observed_at TIMESTAMP NULL` + `anonymous_session_id VARCHAR(36) NULL`. Endpoints : `POST /v1/audit/mobile-session-start` (single-row write, authenticated OR anonymous-tagged) and `POST /v1/audit/mobile-session-link` (batch POST of buffered anonymous rows on first login). 2 lifecycle hooks in Flutter : cold-start (every app launch) + warm-resume (>30min since last foreground). Offline SQLite queue persists writes when offline, replays on next connectivity (LSFin durability). Per D-MOB design obs #186 + architect-review obs #176 audit-trail gap.

- **D-13:** **D-MOB-04 — clean separation.** Mobile L1 audit does NOT dual-write `fact_event`. Compliance metadata (hash-only 10y retention) stays in `projection_audit_record` ; user-facts (encrypted + DEK-shreddable) live in `fact_event` / `fact_current`. Reason : different retention semantics + different PII profiles ; mixing would force one path to satisfy the stricter.

- **D-14:** **Carry-over gap #1 — `audit_events.user_id_hash` backfill + plaintext drop.** Backfill `user_id_hash = hmac_sha256(user_id, MINT_AUDIT_HASH_PEPPER)` for all existing rows. Drop plaintext `user_id` column on environments without `pgcrypto` extension (or NULL it where the extension exists and a one-way function can be reverted-from-hash if needed — defer to security-auditor recommendation). Sits in Plan 02-02 W1.

- **D-15:** **Carry-over gap #2 — Hash actor_email + ip_address + user_agent.** Currently still plaintext PII in `audit_events`. Migrate to HMAC-pepper hashes (`actor_email_hash`, `ip_address_hash`, `user_agent_hash`) following same pattern as user_id_hash. Plaintext columns DROPPED post-deprecation window (1 release). Sits in Plan 02-02 W1.

- **D-16:** **Carry-over gap #3 — `/privacy/delete` real count.** Currently hardcoded `nb_sessions=0` in DSAR receipt (misleading). Fix : query actual `chat_messages` / `coach_insights` / `snapshots` row counts pre-deletion, return real DSAR receipt with counts. Sits in Plan 02-02 W1.

- **D-17:** **Carry-over gap #4 — SnapshotModel.constants_version_hash cache invalidation.** Currently stored as evidence trail only (not part of cache key). Wire into existing snapshot cache lookup so cached projections invalidate when active regulatory version changes. Sits in Plan 02-02 W1 (atomic with Phase 02 read-side, before PR-3 read cut-over consumes the invalidation contract).

### Area 3 — Wave structure, projector pattern, W0 prereqs

- **D-18:** **Phase 02 = 4 sequential plans.** Matches Phase 01 5-plan / 4-wave shape, sequential serializes risk. Per memory `feedback_no_micro_pauses` + Phase 01 lesson (no parallelization).
  - **Plan 02-01 (W0 prereqs, ~1 week)** — single bundle PR landing : alembic_boolean_default_lint HARD lefthook + codegen timestamp determinism fix (`Generated for effective_on: <date>`) + real-Postgres pg fixture migration harness + pg_dump baseline snapshot + HMAC-pepper site sweep + S12 PR-1 façade-delegate + Flutter PR-A2 drift fix + D-MOB-02 dead-COUP-04 integration test.
  - **Plan 02-02 (W1 event-log core + canary, ~1.5 weeks)** — Alembic p98 (`fact_event` + `fact_current`) + Alembic p113 (extend `projection_audit_record`) + DEK envelope wiring + `ensure_user_dek()` integration test + app-side projector + Mobile L1 audit POST endpoints + Flutter Mobile L1 audit service + offline SQLite queue + first-slice canary on `monthly_gross_income` end-to-end with parity test + 4 Phase 01 carry-overs (D-14 / D-15 / D-16 / D-17).
  - **Plan 02-03 (W2-W3 6-PR migration sequence, ~1.5 weeks ; iter-2 amendment)** — 1 plan with 6 sequential PRs : PR-0 preflight zero-user gate → PR-1 FF infrastructure → PR-2 dual-write FF-OFF → PR-3a backfill-only idempotent (row-count-delta=0) → PR-3b read cut-over atomic with D-12 SOFT→HARD per D-31 → PR-4 dual-write decommission → PR-5 legacy SnapshotModel drop (post-1-week-observability-soak gate).
  - **Plan 02-04 (W4 close-out, ~3 days)** — S12 PR-2 alias removal + Q6 CI mechanical fixes + `declared_counters_must_fire.py` close-out gate + auth-coach G2 scenario E variant + Maestro flow D refactor.

- **D-19:** **App-side projector with `session.begin()`.** NOT db trigger. Reason : observability > simplicity per postgres-pro panel verdict. The projector is a function `project_fact_event(event: FactEvent) → None` called within the same SQLAlchemy `session.begin()` block as the `fact_event` INSERT, so projection write is transactional with the event write. Failure rolls both back. No async eventual consistency, no projector lag, no separate worker process.

- **D-20:** **`alembic_boolean_default_lint.py` HARD lefthook.** Catches the Hotfix B class (`server_default=sa.text("0")` on `sa.Boolean()` → Postgres `DatatypeMismatch`) at commit time. Scope : ANY alembic PR adding or modifying a Boolean column with a non-Boolean `server_default` value. Tight enough to avoid false positives, broad enough to catch re-introductions.

- **D-21:** **Codegen timestamp determinism.** `tools/codegen/regulatory_constants_to_dart.py:277,282` `Generated at: <utcnow>` → `Generated for effective_on: <date>` so D-12 Phase 01 HARD mode constants-drift lint doesn't get noise diffs from build-time timestamp churn.

- **D-22:** **Real-Postgres pg fixture migration test harness.** Replaces `DATABASE_URL=sqlite:///:memory:` for migration tests. Implementation : pytest fixture `pg_fixture` spinning an ephemeral Postgres container via testcontainers-python OR running against Railway-staging-replica. Catches the Hotfix B class + future Postgres-specific DDL bugs predicted by QA panel obs #187 5min before they crash.

- **D-23:** **pg_dump baseline snapshot committed.** `tools/db/baseline_snapshot_2026-05-18.sql` checked into git as the « what the schema looks like RIGHT NOW » reference. Used by D-22 pg fixture as starting state. Updated atomic with every breaking schema change.

- **D-24:** **HMAC-pepper site sweep.** Apply `MINT_AUDIT_HASH_PEPPER` uniformly to ALL user_id_hash sites (currently inconsistent : Hotfix C used bare SHA-256). Grep-based audit at lint time (`tools/checks/hmac_pepper_audit.py`) — any call to `hashlib.sha256(user_id)` without pepper fails the lint. Sits in Plan 02-01 W0.

- **D-25:** **First-slice canary fact = `monthly_gross_income`.** Most-trafficked single user-fact (read on every snapshot / projection / coach turn). End-to-end parity test (`tests/integration/test_canary_monthly_gross_income.py`) shape : (a) write fact_event with `source_type='user_input'`, (b) projector runs within session.begin(), (c) `fact_current.value_enc` decrypts to same value as the existing `SnapshotModel.gross_income` for the same user, (d) backend `/v1/projection` endpoint returns identical output whether it reads from fact_current OR SnapshotModel (dual-read window). Parity must hold for 100% of test fixtures before D-31 D-12 SOFT→HARD promotion fires.

### Area 4 — fact_event schema concretes + buffer mechanics + exit gates

- **D-26:** **`value_enc` typed JSONB shape.** Single JSONB column with Pydantic v2 model `EncryptedValue` in `services/backend/app/models/encryption/encrypted_value.py` :
  ```python
  class EncryptedValue(BaseModel):
      ct: str   # base64-encoded ciphertext
      iv: str   # base64-encoded IV/nonce (96-bit for GCM)
      tag: Literal[""] = ""  # iter-2 amendment: GCM auth tag is embedded in `ct` (AESGCM appends it). Field kept empty for envelope-shape stability ; future engineers extending decrypt path MUST read tag from end of `ct`, NOT from this field.
      alg: Literal["AES-256-GCM"] = "AES-256-GCM"
      dek_id: str  # logical key ref, e.g. "mint-master-v1"
      enc_v: int = 1  # envelope-format version (for future DEK rotation)
  ```
  Reason : future DEK rotation needs `dek_id` per row ; separate columns would explode width for 6 fields × every event row. JSONB allows index on `dek_id` for rotation queries.

- **D-27:** **`fact_event` idempotency.** UNIQUE constraint `(subject_type, subject_id, fact_type, source_id, recorded_at)` on `fact_event`. Projector reads `latest_event_id` from `fact_current` and skips re-projection if `event.event_id <= fact_current.latest_event_id` (sequence-number monotonicity, not timestamp). Retry-on-conflict at API layer maps to HTTP 409 with stable response shape. Wired counter : `mint_projector_idempotency_skip_total` (D-33).

- **D-28:** **Partition declaration in p98.** `PARTITION BY HASH (subject_id) PARTITIONS 8` ships in p98 alembic from day one (iter-2 amendment 2026-05-18 — bumped from PARTITIONS 1 per database-architect MED-4). Reason : MODULUS 1 → 2 → 4 → 8 split requires DETACH/ATTACH per step (effectively data migration each time) ; MODULUS 8 from day one in the pre-launch zero-data window costs nothing now and avoids 3 future migrations. Postgres-pro convention aligns with ADR Q1 partition-ready stance. Forward-deferred split-to-16/32 documented in `docs/operations/fact-event-partition-split.md` (trigger : `fact_event` row count > 50M OR p99 read latency > 15ms sustained 7-day).

- **D-29:** **`confidence` JSONB = full EnhancedConfidence 4-axis.** Shape : `{c: 0.8, a: 0.9, f: 1.0, u: 0.7, score: 0.85, enrichmentPrompts: ["..."]}` (completeness × accuracy × freshness × understanding + aggregate score + enrichment prompts per `swiss-brain.md` mandate). No normalized subset — already a tiny JSONB, denormalising loses the 4-axis breakdown which downstream surfaces consume. **`enrichmentPrompts` cap : 5 strings × 200 chars max** (iter-2 amendment per database-architect MED-3) — prevents row-size pushing >2KB JSONB TOAST threshold, which would force out-of-line storage and degrade future GIN `dek_id` rotation queries. Pydantic v2 `EnhancedConfidence` model enforces the cap with `model_validator(mode='after')`.

- **D-30:** **Anonymous-session buffer mechanics.**
  - **Storage** — mobile SQLite (offline-capable, no backend ephemeral table). Aligns with D-MOB existing offline SQLite queue + LSFin durability + zero backend PII before account creation (DSAR-clean).
  - **TTL** — 30 days (matches Phase 01 D-07 L1 hard-refuse staleness ceiling).
  - **Anonymous session ID** — UUID v7 generated once per app install, persisted in SQLite. NOT a device fingerprint (privacy-preserving — user can wipe storage to reset).
  - **Server-side correlation column** — `projection_audit_record.anonymous_session_id VARCHAR(36) NULL` per D-12 (Alembic p113).
  - **Link on first login** — single batch POST `/v1/audit/mobile-session-link` with array of buffered audit rows. Server inserts each row with both `user_id_hash` AND `anonymous_session_id` populated, then mobile SQLite buffer purged. Retry-safe via UNIQUE `(anonymous_session_id, observed_at)`.
  - **Proof-of-session-start handshake** (iter-2 amendment 2026-05-18, locked iter-3 — per security-auditor HIGH T-S01 obs #195). `/v1/audit/mobile-session-link` rejects batch with HTTP 403 if any submitted `anonymous_session_id` lacks a prior `mobile_session_start` row server-side. Closes spoofing attack vector (any HTTP client could otherwise POST audit rows for arbitrary `anonymous_session_id` values and permanently attribute spoofed sessions to real users at link time). Counter `mint_anonymous_session_link_total{outcome='rejected_no_handshake'}` increments on every rejection for audit-integrity alerting.

- **D-31:** **D-12 parity-lint SOFT→HARD promotion timing.** Atomic with **PR-3b read cut-over** in Plan 02-03 6-PR sequence (iter-2 amendment 2026-05-18 — PR-3 split into PR-3a backfill-only + PR-3b cutover+HARD-flip per D-05 amendment). Reason : PR-1 FF infra + PR-2 dual-write FF-OFF + PR-3a backfill all done + 100% staging-user canonical-JSON parity audit clean = parity is provably tight ; flipping HARD at read cut-over locks the invariant precisely when readers depend on it. Earlier = blocks Phase 02 itself ; later = drift sneaks past undetected. The same PR-3b atomically updates the SOFT→HARD config + adds the test coverage that proves zero drift. **Soak duration: 7-day minimum, 14-day target** (iter-2 reconciliation of REVIEWS « 14-day » vs prior CONTEXT « 1-week » vs Plan « ≥7 days » — continuous drift sampler `_phase02_parity_audit_continuous` clean window is the gate-precondition for PR-3b merge). **Drift gate definition** (iter-2 per Claude-Opus A10 + qa-expert HIGH-1) : `tools/parity/projection_diff.py` canonical-JSON via `json.dumps(..., sort_keys=True, default=str)` + Decimal tolerance `1e-9` + missing-key==NULL rule + 100% staging-user sample (NOT random-20-of-N).

- **D-32:** **Phase 02 5-gate mechanical exit checklist.**
  - **G1 Maestro walker** — extends `tools/simulator/walker_audit_tap_render.sh` with Mobile L1 audit POST + offline-queue replay verification (airplane-mode toggle test).
  - **G2 Julien device sign-off** — end-to-end on iPhone 17 Pro sim : anonymous session → cold-start audit → warm-resume audit (>30min sleep) → first login → buffered rows linked → continuous chain visible in admin panel.
  - **G3 dev CI green** — `alembic_boolean_default_lint.py` HARD + `declared_counters_must_fire.py` HARD + REVOKE UPDATE/DELETE assertion on `fact_event` + `projection_audit_record` (post-migration check) + Postgres-real migration test on every alembic touch.
  - **G4 regression tests** — pytest full suite + 2 new test classes : `test_projector_idempotency.py` (replay same event_id, expect no-op + counter increment) + `test_dek_shred_opacity.py` (NULL `dek_ciphertext`, assert downstream `value_enc` rows return decrypt-error not plaintext).
  - **G5 lint suite** — LSFin banned-terms + accent_lint_fr + ARB parity (existing Phase 01 G5) + constants drift HARD-promoted (D-31) + `hmac_pepper_audit.py` (D-24) site lint.

- **D-33:** **6 new observability counters wired.** All declared in `services/backend/app/observability/counters.py` and validated by `declared_counters_must_fire.py` close-out gate (Plan 02-04) :
  1. `mint_fact_current_read_latency_ms` (histogram, p50/p99/p99.9 labels per `fact_type`)
  2. `mint_fact_event_insert_total{source_type}` (counter, validates Q1 latency target empirically + source-type distribution)
  3. `mint_dek_envelope_status_total{status}` (counter, status ∈ `created` | `active` | `shredded` | `rewrap_pending`)
  4. `mint_anonymous_session_link_total{outcome}` (counter, outcome ∈ `linked` | `expired` | `conflict` | `error`)
  5. `mint_projector_idempotency_skip_total` (counter, fires on D-27 dedup skip — drift signal)
  6. `mint_constants_version_mismatch_total` (counter, fires on D-31 parity-lint detection if any slips through HARD — should be 0 post-promotion)
  7. `mint_kms_backend_failure_total` (counter, iter-2 addition per D-35 — increments on every `KMSBackendUnavailable` raise from `_select_backend()` for alerting on Railway KMS health)
  8. `mint_dek_cache_size_total` (gauge, iter-2 addition per Claude-Opus A5 — tracks `KeyVaultService._dek_cache` size after 5-min TTL eviction ; bounded-cache invariant signal)

- **D-34:** **Multi-shape canary parity gate** (iter-2 addition 2026-05-18, locked iter-3 commit `2097c9f5`). Before PR-3b read cut-over, parity-test FIVE fact-types covering distinct value shapes : (a) scalar float `monthly_gross_income` (D-25 baseline canary), (b) decimal-precision `pillar_3a_balance` (rounding bugs surface), (c) nested JSONB `confidence` 4-axis (JSONB key-order canonicalisation surface), (d) nullable optional `archetype_tags` (NULL-vs-missing-key semantics surface), (e) multi-KB TOAST-eligible blob `coach_extracted_facts` (out-of-line storage surface). All 5 shapes must show zero drift via `projection_diff.py` before HARD-flip fires. Per Claude-Opus A11 / qa-expert HIGH-2 / postgres-pro LOW-iii (2-way convergence — qa + pg). Reason : single-shape canary on `monthly_gross_income` (scalar float, D-25) does NOT exercise the JSONB/decimal/nullable/TOAST cells that the projector also serializes ; cut-over without multi-shape parity = blind spots over ~95% of fact-type surface area.

- **D-35:** **KMS fail-closed posture** (iter-2 addition 2026-05-18, locked iter-3 commit `2097c9f5`). `services/backend/app/services/key_vault.py:_select_backend()` raises `KMSBackendUnavailable` on Railway KMS failure ; **NO silent fallback to `_FernetBackend`**. Production never silently degrades crypto-wrapping. Counter `mint_kms_backend_failure_total` increments on every failure for alerting. The explicit dev opt-in path is the env var `MINT_KMS_BACKEND=fernet` (production deployment MUST NOT set this). Per Claude-Opus A4 / security-auditor HIGH T-S09 obs #195 — single-highest-severity Phase 02 finding in the iter-1b review. Reason : prior code path silently fell through to Fernet on `KeyVaultServiceError` ; split-brain key wrapping (some DEKs Fernet-wrapped, others KMS-wrapped) is unrecoverable if either backend's key rotates ; alerting on KMS-down beats discovering it post-rotation.

### Claude's Discretion

The following are NOT user-specified but flow from the 33 LOCKED decisions and are at the planner's discretion to refine :

- Exact pytest fixture scaffold for D-22 (testcontainers-python vs Railway-staging-replica auth) — default to testcontainers-python for hermetic test runs ; fall back to staging-replica for nightly soak.
- Exact `EncryptedValue` Pydantic v2 model location + JSONB shape validator (D-26) — default `services/backend/app/models/encryption/encrypted_value.py` ; planner picks if it sits in `models/` or `schemas/`.
- Exact retry / backoff policy for offline SQLite queue replay (D-12 / D-30) — default exponential backoff 1s/2s/4s/8s/16s with `mint_anonymous_session_link_total{outcome='error'}` increment per failure ; planner refines per network-error class.
- Exact STAGING-DOWN-OVERRIDE label workflow gate (D-06) — default `.github/CODEOWNERS` scoped to `julienbattaglia` on `.github/workflows/regulatory-codegen.yml` ; planner picks if CODEOWNERS gate uses GitHub repo ruleset OR branch protection rule.
- Exact `fact_current` covering index field order (D-01) — default `(subject_id) INCLUDE (value_enc, latest_event_id, confidence, visibility)` per database-architect obs #174 ; planner re-validates if `EXPLAIN` shows different optimal order for the actual query pattern.
- Feature-flag naming for PR-2 dual-write toggle (D-05 / Plan 02-03 PR-1) — default `fact_event_dual_write_enabled` (off → on → off, then PR-5 removes the flag) ; planner picks namespace.
- Bundle-size impact of mobile SQLite buffer for anonymous-session audit (D-30) — must measure in Plan 02-02 and confirm < 100KB compressed addition to bundle ; planner picks SQLite migration strategy (raw sqlite3 vs sqflite vs drift).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing Phase 02.**

### Upstream decisions (the gate)

- [.planning/decisions/2026-05-18-phase02-event-log-projection-panel-synthesis.md](../../decisions/2026-05-18-phase02-event-log-projection-panel-synthesis.md) — THIS phase's « how + when + trade-offs » lockdown. 7-specialist panel synthesis + 3 Julien-locked calls. **Single canonical source** for D-01…D-22 carry-forward decisions. Status : `Decided` 2026-05-18.
- [.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md](../../decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md) — upstream « what shape » ADR. 5-specialist adversarial panel-converged event-log + projection + per-user DEK envelope. Status : `Decided` (calc-engine portion) + `Proposed → flipped to Decided` (event-log portion by Phase 02 ship).
- [.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/mint-data-architecture-v1-01-calc-engine-CONTEXT.md](../mint-data-architecture-v1-01-calc-engine-canonical/mint-data-architecture-v1-01-calc-engine-CONTEXT.md) — Phase 01 16 D-XX LOCKED decisions (split-with-arbiter L1 mobile / L2-L4 backend). Phase 02 MUST NOT undo any.

### Existing tables to migrate from / extend

- [services/backend/app/models/snapshot.py](../../../services/backend/app/models/snapshot.py) — `SnapshotModel` shape (migration source for D-05). Has `constants_version_hash` (Hotfix B 2026-05-17) but cache invalidation NOT wired (D-17 carry-over).
- [services/backend/app/models/projection_audit_record.py](../../../services/backend/app/models/projection_audit_record.py) — Hotfix B 2026-05-17 shipped append-only audit table. EXTEND with `source` + `app_version` + `observed_at` + `anonymous_session_id` columns via Alembic p113 (additive) per D-12.
- [services/backend/app/models/audit_event.py](../../../services/backend/app/models/audit_event.py) — Hotfix C 2026-05-17 `user_id_hash` column shipped. Plaintext `user_id` + `actor_email` + `ip_address` + `user_agent` still PII gaps (D-14 / D-15 carry-overs).
- [services/backend/app/services/encryption/key_vault.py](../../../services/backend/app/services/encryption/key_vault.py) — existing 2-backend KMS facade (283 LOC). Logical-id pattern fits Q2 Railway-native (D-02). Add `ensure_user_dek()` per D-32 / Plan 02-02.

### Phase 02 new code surfaces

- `services/backend/app/models/fact_event.py` (NEW, Plan 02-02) — `fact_event` append-only event log per upstream ADR shape + D-26 (`EncryptedValue` JSONB) + D-27 (UNIQUE idempotency) + D-28 (HASH partition).
- `services/backend/app/models/fact_current.py` (NEW, Plan 02-02) — denormalised PK-indexed projection per D-01 (covering index) + D-23 transactional projector.
- `services/backend/app/models/user_dek.py` (NEW, Plan 02-02) — per-user crypto-shred envelope per D-03 (`dek_scope` future-proof).
- `services/backend/app/models/encryption/encrypted_value.py` (NEW, Plan 02-02) — Pydantic v2 `EncryptedValue` model per D-26.
- `services/backend/app/services/projector/fact_projector.py` (NEW, Plan 02-02) — app-side projector per D-19 (`session.begin()` transactional).
- `services/backend/app/api/v1/endpoints/audit_mobile.py` (NEW, Plan 02-02) — `/v1/audit/mobile-session-start` + `/v1/audit/mobile-session-link` per D-12.
- `services/backend/alembic/versions/p98_fact_event_projection_dek.py` (NEW, Plan 02-02) — `fact_event` + `fact_current` + `user_dek` creation per upstream ADR.
- `services/backend/alembic/versions/p113_extend_projection_audit_for_mobile.py` (NEW, Plan 02-02) — extends `projection_audit_record` per D-12.

### Existing services Phase 02 consumes

- [services/backend/app/services/regulatory/registry.py](../../../services/backend/app/services/regulatory/registry.py) — `RegulatoryParameter` source for `subject_type='regulatory'` event-log dual-write (Phase 01 D-08 codegen integration).
- [services/backend/app/services/independants/](../../../services/backend/app/services/independants/) (S18) + [services/backend/app/services/expat/frontalier_service.py](../../../services/backend/app/services/expat/frontalier_service.py) (S23) — S12 façade-delegate-to-granular pattern per D-08. Promote `IJM_ESTIMATE_RATE` + `LAA_ESTIMATE_RATE` to S18.
- [services/backend/app/api/v1/endpoints/coach_chat.py](../../../services/backend/app/api/v1/endpoints/coach_chat.py) `:957-1015` `_PROFILE_SAFE_FIELDS` — Stage 0 baseline for D-10 D-MOB-01 drift fix.
- [apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart](../../../apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart) — Phase 01 D-16 codegen output ; mobile L1 audit reads `regulatoryConstantsVersionHash` for D-12 audit row.
- [apps/mobile/lib/services/api_service.dart](../../../apps/mobile/lib/services/api_service.dart) `:187` — `_appVersion` fix shipped 2026-05-18 (commit `ce24c963`) via `package_info_plus`. Required pre-D-12 ship so mobile L1 audit doesn't log `app_version=1.0.0` for 10 years.

### Lints + tooling (the gates)

- [tools/checks/profile_safe_fields_parity.py](../../../tools/checks/profile_safe_fields_parity.py) — Concern C Flutter↔server parity lint. Promote SOFT→HARD per D-31 (atomic with PR-3 read cut-over).
- `tools/checks/alembic_boolean_default_lint.py` (NEW, Plan 02-01) — HARD lefthook per D-20.
- `tools/checks/hmac_pepper_audit.py` (NEW, Plan 02-01) — D-24 site lint.
- `tools/checks/declared_counters_must_fire.py` (NEW, Plan 02-04) — D-32 / D-33 close-out gate.
- [tools/checks/banned_terms_python.py](../../../tools/checks/banned_terms_python.py) — D-CE-16(b) lint with 11 paraphrase verbs + NFKC + zero-width strip (Phase 01 G5 unchanged).
- [tools/checks/accent_lint_fr.py](../../../tools/checks/accent_lint_fr.py) — 14-pattern FR accent lint (Phase 01 G5 unchanged).

### Test harness + fixtures

- `services/backend/tests/fixtures/pg_fixture.py` (NEW, Plan 02-01) — real-Postgres pg fixture migration test harness per D-22.
- `tools/db/baseline_snapshot_2026-05-18.sql` (NEW, Plan 02-01) — pg_dump baseline per D-23.
- `services/backend/tests/integration/test_canary_monthly_gross_income.py` (NEW, Plan 02-02) — D-25 canary parity test.
- `services/backend/tests/integration/test_projector_idempotency.py` (NEW, Plan 02-02) — D-32 G4 gate.
- `services/backend/tests/integration/test_dek_shred_opacity.py` (NEW, Plan 02-02) — D-32 G4 gate.
- `services/backend/tests/integration/test_coup_04_dead_path.py` (NEW, Plan 02-01) — D-11 contract lock.

### CI workflows (Q6 fixes)

- [.github/workflows/regulatory-codegen.yml](../../../.github/workflows/regulatory-codegen.yml) — Q6 CI staging-down policy per D-06. Extend with STAGING-MALFORMED status + scheduled-only aging writes (cron 6h on `dev`) + HARD-mode `STAGING-DOWN-OVERRIDE` label override (CODEOWNERS Julien-only gate).
- `.github/CODEOWNERS` (touch in Plan 02-04) — scope STAGING-DOWN-OVERRIDE label to `@julienbattaglia` for `.github/workflows/regulatory-codegen.yml`.

### Engram observation index

- engram obs #163 — Phase 01 CONTEXT (16 D-XX decisions, the gate).
- engram obs #169 — cleanup bug (destructive untracked-files delete — informational).
- engram obs #172 — Phase 01 VERIFICATION 16/16 PASS.
- engram obs #174 — Phase 02 database-architect verdict (Q1 + Q4 + Q5 → D-01 + D-04 + D-05).
- engram obs #175 — Phase 02 threat-modeling verdict (Q2 + Q3 + Q7 + STRIDE + HMAC-pepper non-negotiable → D-02 + D-03 + D-07 + D-24).
- engram obs #176 — Phase 02 architect-review integrated verdict + mobile L1 audit gap discovery → D-12.
- engram obs #178 — Phase 02 devops verdict (Q6 + PR-readiness 8-item + 6 new counters → D-06 + D-33).
- engram obs #180 — Track-B Claude-actionable default (Julien correction — informational).
- engram obs #182 — Q6 Railway-native metrics scraping decided → D-06 alignment.
- engram obs #183 — S12 API consolidation design → D-08 + D-09.
- engram obs #185 — G2 sweep pre-fix BLOCKED on Railway (closed by Hotfix B/C + `fe52ba31`).
- engram obs #186 — Flutter D-MOB design + audit gap fix → D-10 to D-13.
- engram obs #187 — QA methodical sweep (predicted Postgres bug 5min before surface — informational, validates D-22).
- engram obs #188 — Postgres BOOLEAN DEFAULT bug root cause + fix `fe52ba31` (validates D-20).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`services/backend/app/services/encryption/key_vault.py`** (283 LOC) — already a 2-backend KMS facade with logical-id pattern. Q2 Railway-native (D-02) maps directly : add `mint-master-v1` logical key to existing logical-id registry, wire `ensure_user_dek(user_id)` per D-32. No new KMS infrastructure to build.
- **`services/backend/app/models/projection_audit_record.py`** (53 LOC) — Hotfix B shipped 2026-05-17. Extension per D-12 is additive (4 new columns) ; existing rows backfill `source='projection'` (default). Postgres REVOKE UPDATE/DELETE pattern already in p111 migration (carries to p98 for `fact_event`).
- **`services/backend/app/models/snapshot.py`** (52 LOC) — `SnapshotModel` shape understood ; `constants_version_hash` column shipped (Hotfix B). The big-bang 5-PR migration (D-05) extracts each field-by-field via `fact_event` dual-write → projector → `fact_current` parity → read cut-over → drop.
- **`tools/checks/profile_safe_fields_parity.py`** (Phase 01 D-12 pattern) — codegen → CI lint chain proven. Same pattern reused for D-20 (alembic_boolean_default_lint) + D-24 (hmac_pepper_audit) + D-33 close-out gate.
- **`services/backend/alembic/versions/p111_projection_audit.py`** — Hotfix B + Postgres BOOLEAN DEFAULT fix `fe52ba31`. Migration pattern reference for p98 (REVOKE UPDATE/DELETE + Postgres-vs-SQLite portability) + p113 (additive column extension).
- **`services/backend/alembic/versions/p95_dag_invalidation.py`** — recent additive migration with `inputs_hash` + UUID7 + JCS shape. Migration pattern reference for `fact_event.event_id` (UUID7) + UNIQUE constraint pattern (D-27).
- **`apps/mobile/lib/services/api_service.dart`** — `package_info_plus` boot init for `_appVersion` shipped 2026-05-18 (commit `ce24c963`). Pre-requisite for D-12 mobile L1 audit POST (so `app_version` never logs `1.0.0`).

### Established Patterns

- **Hotfix B/C migration pattern** (REVOKE UPDATE/DELETE on Postgres + INSERT-only convention on SQLite test path) — directly reused for `fact_event` + extended `projection_audit_record` in p98 / p113.
- **HMAC user_id_hash with Railway-secret pepper** (security-auditor obs #175 non-negotiable) — D-24 site sweep applies uniformly ; D-14 / D-15 backfill plaintext PII columns to hash columns following same pattern.
- **App-side projector with `session.begin()`** (D-19) — matches existing SQLAlchemy session pattern in `coach_chat.py` `_dispatch_tool` ; no new transaction-management framework.
- **JSONB-typed Pydantic v2 column** (D-26 `EncryptedValue`) — matches existing pattern in `services/backend/app/models/lucidity/_payload.py` (Phase 01 D-02 boundary discriminator).
- **Codegen-baked constants → runtime delta-check** (Phase 01 D-08 + D-16) — D-21 timestamp determinism fix preserves D-12 parity-lint signal (no noise diffs from utcnow churn).
- **Mobile offline SQLite queue replay** (D-12 / D-30) — Flutter pattern reusable from existing offline-coach queue ; planner picks raw sqlite3 vs sqflite vs drift.
- **Lefthook + CI parity lints** — D-20 + D-24 + D-31 SOFT→HARD promotion + D-33 close-out gate all reuse the proven `tools/checks/*.py` invocation pattern.
- **Feature-flag rollout for risky migrations** — Phase 01 `profile_grounding_strict_mode` pattern (D-CE-08) reused for D-05 PR-2 `fact_event_dual_write_enabled` flag.

### Integration Points

- **Where DEK envelope hooks** — `ensure_user_dek(user_id)` called inline before first `fact_event` INSERT for that user (lazy, not at signup). Sits in projector + Mobile L1 audit POST handler. Integration test mandatory per D-32 G4.
- **Where `fact_event` writes originate** — Plan 02-02 W1 wires writers in `services/backend/app/services/snapshot_service.py` (dual-write under FF) + Mobile L1 audit endpoints (D-12) + regulatory codegen sync (subject_type='regulatory').
- **Where `fact_current` reads land** — backend `/v1/projection` endpoint switches to fact_current via PR-3 read cut-over in Plan 02-03. Existing `SnapshotModel` reads keep going during dual-read window (PR-2 → PR-3 transition).
- **Where mobile L1 audit POSTs originate** — Flutter `AppLifecycleObserver` cold-start hook + warm-resume detector (>30min since last `didChangeAppLifecycleState` resumed). Offline queue persists to mobile SQLite ; replays on connectivity restoration.
- **Where Q6 CI fixes land** — `.github/workflows/regulatory-codegen.yml` + `.github/CODEOWNERS` in Plan 02-04. STAGING-DOWN-OVERRIDE label requires CODEOWNERS gate (Julien-only).
- **Where observability counters wire** — `services/backend/app/observability/counters.py` (existing module) + `apps/mobile/lib/services/observability/` for mobile L1 audit replay counter. Close-out gate (`declared_counters_must_fire.py`) asserts all 6 are wired before Phase 02 close.

</code_context>

<specifics>
## Specific Ideas

- **« Big-bang pre-launch is the only window »** — D-05 framing per postgres-pro panel verdict. The moment first paying user signs up, the rollback path collapses ; Phase 02 ships now or accepts 18 months of migration pain post-launch. Acknowledged trade-off, not pretended invisible.
- **« Crypto-shred opacity forces decrypted projection »** — counter-argument mitigation for keeping SCD2. Once `value` becomes opaque ciphertext to satisfy nLPD/GDPR erasure, Postgres can't index on encrypted blobs ; a separate decrypted projection becomes operationally necessary. Event-log + projection is the end state ; the question is when.
- **« Railway-native KMS is correct TODAY but wrong within 12 months »** — D-02 trade-off explicit. `dek_scope` column + logical `mint-master-v1` key-id preserve the migration path. Re-litigation triggers locked.
- **« HMAC-pepper is non-negotiable »** — D-07 / D-24 security-auditor obs #175. Bare SHA-256 on UUID space is rainbow-table-reversible. Pepper lives in Railway secrets ; site sweep ensures uniform application.
- **« Anonymous-session buffer in mobile SQLite, not backend »** — D-30 privacy-preserving design. No PII on backend before account creation ; DSAR-clean. User can wipe storage to reset audit chain (vs device fingerprint which they can't escape).
- **« App-side projector with `session.begin()`, not db trigger »** — D-19 postgres-pro panel verdict : observability > simplicity. Transactional, no projector lag, no separate worker process to monitor.
- **« 4 plans sequential, no parallelization »** — D-18 Phase 01 lesson. Phase 01 5-plan/4-wave sequential shipped clean ; parallelization caused W-05 framing-agent worktree loss 2026-05-07 per memory `feedback_no_nuke_worktree_with_running_agent`.
- **« First-slice canary = `monthly_gross_income` »** — D-25 most-trafficked single user-fact. Parity gate before 5-PR migration starts. If canary fails, Phase 02 plan-phase re-litigates D-05 scope.
- **« D-12 SOFT→HARD atomic with PR-3b read cut-over »** (iter-2 amendment) — D-31 latest safe window. PR-3 split per D-05 iter-2 amendment ; HARD-flip lives in PR-3b (cutover) not PR-3a (backfill-only). Earlier = blocks Phase 02 itself ; later = drift sneaks past undetected.
- **« 6 new observability counters validate Q1 latency empirically »** — D-33 closes the panel ADR data gap (no empirical workload measurement on `fact_current` shape). First W1 PR instruments before 5-PR migration starts.

</specifics>

<deferred>
## Deferred Ideas

The following surfaced during discussion (or were enumerated in the panel ADR) and are explicitly out of scope for Phase 02. They will be revisited in later phases or backlog as noted.

### To downstream phases (Phase 03+)

- **Coach-extractor LLM** with evidence-quote requirement + interpretive-vocabulary banlist + TTL decay policy + user-visible review surface — Phase 03. The pattern is locked in upstream ADR ; the implementation phase is gated on Phase 02 completion (requires `fact_event(source_type='coach_inference')` schema from Phase 02).
- **Per-category sub-DEKs / granular erasure** — Phase 04. `dek_scope` column shipped in Phase 02 (D-03) future-proofs the migration. Trigger : 1st granular deletion request OR EDÖB inquiry.
- **Monte Carlo / tornado sensitivity / arbitrage / withdrawal-sequencing migration to backend** — separate `mint-data-architecture-v1-03+` phases per Phase 01 D-11 strangler-fig sequence.

### To backlog (re-litigate on trigger)

- **AWS KMS migration** — re-open if first paying CH user with deposit > 100K CHF OR first EDÖB/FINMA inquiry OR Railway adds FIPS 140-2 attestation.
- **Postgres UNLOGGED + `pg_prewarm` escape hatch** for `fact_current` — re-open if p99 PK reads > 50ms sustained in canary or post-launch (BEFORE adding Redis).
- **S3 Glacier 9y archive of `projection_audit_record`** — trigger : Railway bill > CHF 100/mo on this table.
- **Sigstore Rekor Merkle anchoring** of audit chain — trigger : 1st LSFin complaint.
- **Delete-after-10y job** for `projection_audit_record` — trigger : Railway bill > CHF 100/mo OR storage-cost optimization.
- **`tools/checks/fact_current_drift_detector.py`** + automated rebuild — trigger : `mint_projector_idempotency_skip_total` non-zero post-launch (drift signal).
- **Single-table bitemporal source-of-truth migration** — re-open only if FINMA publishes guidance requiring it.
- **Re-link audit chain semantics for deleted-then-recreated users** — re-open if regulator pushes back on HMAC-stable hash across deletions.

### To Phase 02 planner deliverables (D-18 / Claude's Discretion)

- Latency measurement of `fact_current` PK reads under W1 canary load (D-25 + D-33 histogram).
- Bundle-size measurement of mobile SQLite anonymous-session buffer (D-30) — must be < 100KB compressed addition.
- Battery-cost measurement of mobile L1 audit POST on cellular vs WiFi (D-12 G2 sub-check).
- Exact `EncryptedValue` Pydantic v2 model location (D-26) — default `services/backend/app/models/encryption/encrypted_value.py`.
- Exact pytest fixture scaffold for D-22 (testcontainers-python vs Railway-staging-replica auth).
- Exact retry / backoff policy for offline SQLite queue replay (D-12 / D-30).
- Exact CODEOWNERS / branch-protection mechanism for STAGING-DOWN-OVERRIDE label (D-06).
- Mobile SQLite migration strategy (raw sqlite3 vs sqflite vs drift) for D-30 buffer.

### Scope-creep redirects

- *None surfaced during discussion* — discussion stayed within phase scope, bundle confirmed in single round.

</deferred>

---

*Phase: mint-data-architecture-v1-02-event-log-projection*
*Context gathered: 2026-05-18*
*Next: `/gsd-plan-phase mint-data-architecture-v1-02-event-log-projection`*
