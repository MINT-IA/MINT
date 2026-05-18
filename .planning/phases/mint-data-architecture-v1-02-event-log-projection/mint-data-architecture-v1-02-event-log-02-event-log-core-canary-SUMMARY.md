---
phase: mint-data-architecture-v1-02-event-log-projection
plan: 02-event-log-core-canary
subsystem: backend-encryption-observability
tags: [hmac-pepper, encrypted-value, dek-envelope, kms-fail-closed, ttl-cache, observability-counters, sentry-strip, lsfin-banned-terms-runtime]
description: PARTIAL SHIP — Plan 02-02 W1 Task 2 security + observability substrate landed in 4 atomic commits (hmac_pepper canonical entry, EncryptedValue D-26 wire shape + helpers wrapping envelope.py primitives, KMS fail-closed + TTL DEK cache + 8 D-33 counters, Sentry value_enc/_dek_cache strip). Task 2 alembic migrations (p114/p115/p116) + /privacy/delete real-count rewrite + snapshot cache (D-17) + ALL of Task 3 (p98 fact_event PARTITION BY HASH + p113 + ORM + projector + audit_mobile endpoint + Flutter MobileL1AuditService + canary parity gate) + Tasks 3A/3B/3C/3D + iter-3 iA1/iA2 are DEFERRED to a continuation agent — see § Remaining Scope below. This SUMMARY documents the partial-ship per plan's checkpoint protocol.

# Dependency graph
requires:
  - phase: mint-data-architecture-v1-02-event-log-projection
    plan: 01-prereqs-lints-harness
    provides: hmac_pepper.py stub + EncryptedValue area + pg_fixture + 3 HARD lints + p112 alembic head + audit_service.hash_user_id surface
provides:
  - app/services/audit/hmac_pepper.py REAL impl (PepperNotConfigured + hmac_pii/hmac_user_id/hmac_actor_email)
  - app/services/audit_service.py routes hash_user_id() through hmac_user_id() (caller API preserved)
  - app/models/encryption/encrypted_value.py (EncryptedValue D-26 + EnhancedConfidence D-29+iter-2-B11)
  - app/services/encryption/encrypted_value_helper.py (encrypt_value/decrypt_value + LOGICAL_DEK_ID + iter-2 B6 banned-terms gate)
  - app/services/encryption/banned_terms_runtime.py (NEW — reuses tools/checks vocabulary at runtime)
  - app/services/encryption/key_vault.py (KMSBackendUnavailable + fail-closed _select_backend + TTLCache _dek_cache + LOGICAL kms_key_ref)
  - app/observability/counters.py (NEW — 8 counters: 6 D-33 base + 2 iter-2)
  - app/core/sentry_scrub.py (extended forbidden-key regex with value_enc|_dek_cache)
  - Updated baseline tools/checks/_baseline_hmac_sites_at_p112.txt (4 -> 3 sites; audit_service no longer baselined)
affects: [mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence (blocked on p98+p113+p114+p115+p116 from THIS plan's continuation), mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks (D-33 counter firing-assertions deferred per plan)]

# Tech tracking
tech-stack:
  added: [cachetools (TTLCache for _dek_cache, A5), prometheus_client (already present, now used)]
  patterns: ["Fail-closed env-var resolution (D-35)", "lru_cached pepper read (one-shot per process)", "TESTING=1 fallback test-pepper (not a real secret)", "Pydantic v2 Literal + extra='forbid' typed JSONB shape", "Module-level no-op stub for optional prometheus_client", "Sentry forbidden-key extension (one-line surgical patch)"]

key-files:
  created:
    - services/backend/app/models/encryption/__init__.py
    - services/backend/app/models/encryption/encrypted_value.py
    - services/backend/app/services/encryption/encrypted_value_helper.py
    - services/backend/app/services/encryption/banned_terms_runtime.py
    - services/backend/app/observability/counters.py
    - services/backend/tests/test_hmac_pepper.py
    - services/backend/tests/test_encrypted_value_model.py
    - services/backend/tests/test_encrypted_value_helper.py
    - services/backend/tests/test_key_vault_logical_id.py
    - services/backend/tests/test_dek_envelope_concurrency.py
    - services/backend/tests/integration/test_dek_shred_opacity.py
  modified:
    - services/backend/app/services/audit/hmac_pepper.py (stub -> real impl)
    - services/backend/app/services/audit_service.py (hash_user_id routes through hmac_user_id)
    - services/backend/app/services/encryption/key_vault.py (KMSBackendUnavailable + fail-closed _select_backend + TTLCache + LOGICAL kms_key_ref)
    - services/backend/app/core/sentry_scrub.py (forbidden-key regex extended with value_enc|_dek_cache)
    - services/backend/tests/test_audit_user_id_hash.py (pre-Plan-02-02 bare-sha256 assertion inverted to D-14 HMAC-pepper contract)
    - tools/checks/_baseline_hmac_sites_at_p112.txt (4 -> 3 sites)
    - .planning/phases/mint-data-architecture-v1-02-event-log-projection/deferred-items.md (DEFERRED-02-02-A added)

key-decisions:
  - "hash_user_id() public surface preserved — backwards compat for open_banking.consent_manager + others — but implementation routed through hmac_user_id() (D-14 substrate landed without caller-API breakage)."
  - "Lazy-import counters in key_vault._select_backend to avoid circular dependency with observability/counters (resilient to absence — no-op if import fails)."
  - "Removed silent KMS->Fernet fallback per iter-2 A4 + D-35 PROPOSED. Dev opt-in is now MINT_KMS_BACKEND=fernet explicit env. TESTING=1 keeps the 7000+ test-suite path intact."
  - "TTLCache from cachetools (5min TTL + 1024 maxsize) replaces unbounded dict for _dek_cache. Bounded so long-lived workers cannot leak DEKs; expiring so a rotation propagates within 5min."
  - "Sentry forbidden-key extended with value_enc|_dek_cache via the existing regex — surgical 3-line patch, no new before_send pass logic."
  - "iter-2 B6 banned-terms runtime helper IMPORTS the lint vocabulary tuples directly from tools/checks/banned_terms_python.py (NOT subprocess). Single source of truth for the LSFin vocabulary; no duplication risk."
  - "DEK race-loser test simulated sequentially. macOS system-Python 3.9.6 + sqlite3 segfaults under 2-thread concurrent INSERT into in-memory DB; real-race coverage is via pg_fixture in Task 3B test_projector_concurrent_upsert.py (NOT YET landed — deferred to continuation agent)."

patterns-established:
  - "Canonical entry routing: a public function (hash_user_id) kept for backwards-compat, body now calls the D-XX-canonical entry (hmac_user_id). Caller-facing API stable; security substrate swapped underneath."
  - "Fail-closed env resolution: missing critical env -> raise exception (KMSBackendUnavailable, PepperNotConfigured) with the exact env var name + fallback opt-in documented in the exception message. Refusing to boot beats silently-degraded-PII."
  - "Pydantic v2 wire-shape with Literal['constant_value'] for hard-coded contract fields. Reader sees the locked value at the type level (alg=Literal['AES-256-GCM'], tag=Literal[''])."
  - "TTL-bounded plaintext-DEK cache: TTLCache(maxsize=1024, ttl=300s). Sentry strip layer recursively redacts the cache attribute from captured exceptions."

requirements-completed: []  # 16 plan-frontmatter D-XX dispositions: 7 fully shipped (D-02 D-03 D-07 D-14 D-15 D-24 D-26 D-29 substrate), 9 deferred (D-01 D-12 D-13 D-16 D-17 D-19 D-25 D-27 D-28 D-30). See § Status Matrix below.

# Metrics
duration: ~47min (after Task 1 Julien-checkpoint resumed at ~18:00Z; partial-ship checkpoint at 18:47Z)
completed: 2026-05-18 (PARTIAL — see Remaining Scope)
---

# Phase mint-data-architecture-v1-02 Plan 02-02 (PARTIAL): W1 Event-Log Core + Canary — Security Substrate Summary

**PARTIAL SHIP — Task 2 security + observability substrate landed in 4 atomic commits. Task 2 alembic + Task 3 (p98 fact_event + projector + audit_mobile + Flutter mobile L1 + canary parity) DEFERRED to continuation agent.**

## Performance

- **Duration (executor-side, post-checkpoint resume):** ~47 min
- **Started:** 2026-05-18T18:00Z (worktree-branch reset to expected base dc5d7d0b)
- **Partial-ship checkpoint:** 2026-05-18T18:47Z
- **Commits:** 4 atomic
- **New tests:** 58 (across 6 new + 1 updated test files)
- **Files created:** 11
- **Files modified:** 6

## Task Commits

| # | Commit | Type | Scope |
|---|--------|------|-------|
| 1 | `8166e3f4` | feat | hmac_pepper canonical entry (D-14, D-15, D-24) — 11 unit tests, baseline 4 -> 3 |
| 2 | `d7e2d4b3` | feat | EncryptedValue D-26 model + encrypt_value/decrypt_value helpers + iter-2 B6 + B11 + C5 — 28 unit tests |
| 3 | `3d7e38ea` | feat | KMS fail-closed + DEK TTL cache + D-33 counters + Sentry value_enc strip — 13 unit tests + 4 integration tests |
| 4 | `0c29b5dd` | test | adapt audit_user_id_hash test to D-14 HMAC-pepper migration + document DEFERRED-02-02-A |

## Status Matrix — 16 plan-frontmatter D-XX dispositions

| D-XX | Status | Evidence |
|------|--------|----------|
| D-01 fact_current covering index | **DEFERRED — Task 3** | p98 migration not yet landed |
| D-02 KMS Railway-native logical key-id | **SUBSTRATE SHIPPED** | `key_vault.py` writes MINT_KMS_KEY_ID env value into `dek_vault.kms_key_ref`; `LOGICAL_DEK_ID='mint-master-v1'` in `encrypted_value_helper.py:50` (commit 3d7e38ea + d7e2d4b3) |
| D-03 DEK shred all-or-nothing | **SHIPPED** | `tests/integration/test_dek_shred_opacity.py` 4/4 green (commit 3d7e38ea) — decrypt-after-shred raises DEKRevokedError |
| D-07 fail-closed pepper config | **SHIPPED** | `PepperNotConfigured` raises when env unset + TESTING != '1' (commit 8166e3f4); test `test_pepper_not_configured_raises_outside_testing` green |
| D-12 D-MOB-03 mobile L1 audit POST | **DEFERRED — Task 3** | audit_mobile endpoint + projection_audit_record extension not yet landed |
| D-13 D-MOB-04 clean separation | **DEFERRED — Task 3** | assertion test requires audit_mobile endpoint |
| D-14 audit_events.user_id_hash HMAC-pepper | **SUBSTRATE SHIPPED** | `audit_service.hash_user_id` routes through `hmac_user_id` (commit 8166e3f4); p114 backfill migration **DEFERRED** |
| D-15 actor_email/ip/user_agent HMAC | **SUBSTRATE SHIPPED** | `hmac_actor_email` + `hmac_pii` exposed (commit 8166e3f4); p115 add-columns migration **DEFERRED** |
| D-16 /privacy/delete real DSAR count | **DEFERRED — Task 2 step 11** | privacy.py still has hardcoded zeros for sessions/reports/documents/analytics |
| D-17 SnapshotModel.constants_version_hash cache invalidation | **DEFERRED — Task 2 step 9-10** | snapshot_service / snapshot_cache key-extension not yet shipped |
| D-19 app-side projector with session.begin() | **DEFERRED — Task 3 step 6** | fact_projector.py not yet shipped |
| D-25 first-slice canary monthly_gross_income | **DEFERRED — Task 3 step 16** | W1 -> W2 gate test pending |
| D-26 value_enc typed JSONB Pydantic v2 EncryptedValue | **SHIPPED** | `app/models/encryption/encrypted_value.py` + 11 unit tests green (commit d7e2d4b3); helper wrapper + roundtrip tests 17/17 green |
| D-27 fact_event idempotency UNIQUE | **DEFERRED — Task 3 step 1** | p98 migration carries the UNIQUE |
| D-28 PARTITION BY HASH from day one | **DEFERRED — Task 3 step 1** | p98 PARTITION BY HASH (subject_id) PARTITIONS 8 (iter-2 B8) |
| D-29 confidence JSONB full EnhancedConfidence | **SHIPPED** | `EnhancedConfidence` Pydantic class with iter-2 B11 cap (5 prompts x 200 chars) + 7 unit tests green (commit d7e2d4b3) |
| D-30 anonymous-session buffer mechanics | **DEFERRED — Task 3 steps 10-15** | Flutter MobileL1AuditService + sqflite_sqlcipher + UUID v7 not yet shipped |
| D-33 (declared only) 8 counters | **SHIPPED** | `app/observability/counters.py` exports 8 counter/gauge/histogram instances (6 D-33 + 2 iter-2); firing-assertions deferred to Plan 02-04 per plan |
| D-34 PROPOSED multi-shape canary | **DEFERRED — Task 3C** | 5-shape canary fixtures not yet shipped |
| D-35 PROPOSED KMS fail-closed | **SHIPPED** | `KMSBackendUnavailable` exception + `_select_backend` rewritten; `mint_kms_backend_failure_total` counter increments on fallback (commit 3d7e38ea) |

**Iter-2 patches shipped here**: A4 + A5 + B6 + B11 + C5 (key_vault + helper + EnhancedConfidence + Sentry).
**Iter-2 patches DEFERRED**: A1, A2, A3, A6, A8, A11, B2, B8, B9, B10, B12, B15, C3, C7 (all in Task 3 / 3A / 3B / 3C / 3D).
**Iter-3 patches**: iA3 cleared (Julien Railway env-var checkpoint approved 2026-05-18). iA1, iA2 DEFERRED to continuation (Task 3 / 3B).

## 0-Trust §9.6 Evidence + Caveat block

**Evidence (deterministic citations) :**
- `git log --oneline dc5d7d0b..HEAD` → 4 commits : `8166e3f4 / d7e2d4b3 / 3d7e38ea / 0c29b5dd`
- `cd services/backend && python3 -m pytest tests/test_hmac_pepper.py tests/test_encrypted_value_model.py tests/test_encrypted_value_helper.py tests/test_key_vault_logical_id.py tests/test_dek_envelope_concurrency.py tests/integration/test_dek_shred_opacity.py tests/test_audit_user_id_hash.py -q` → `58 passed in 1.86s` (captured 2026-05-18T18:47Z)
- `python3 tools/checks/hmac_pepper_audit.py services/backend/app/ --baseline tools/checks/_baseline_hmac_sites_at_p112.txt` → `exit 0` (baseline 4 -> 3 sites; audit_service.py no longer baselined since it now routes through hmac_user_id)
- `python3 tools/checks/banned_terms_python.py services/backend/app/services/audit/ services/backend/app/services/encryption/encrypted_value_helper.py services/backend/app/services/encryption/banned_terms_runtime.py services/backend/app/models/encryption/` → `exit 0`
- `python3 tools/checks/accent_lint_fr.py --scope backend` → `exit 0`
- Full backend regression `cd services/backend && python3 -m pytest tests/ -q --ignore=<pre-existing dual-head>` → `7338 passed, 1 failed (DEFERRED-02-02-A pre-existing — frontalier-rename test fixture stale post-D-09), 82 skipped, 3 xfailed in 121s` (zero NEW regressions caused by Plan 02-02 commits)
- Julien Railway-env-var checkpoint confirmation 2026-05-18 : « approved — pepper set on prod + staging via railway variable set --stdin, MINT_KMS_KEY_ID=mint-master-v1 confirmed on both envs, D-02 rotation rehearsal pre/post length 64 invariant preserved » (Task 1 unblocked, executor authorized to resume Task 2)

**Caveat (what I have NOT done / what is UNKNOWN) :**
- **Task 2 alembic migrations p114 (audit_events.user_id_hash HMAC backfill + plaintext drop), p115 (actor_email/ip/user_agent hash columns + backfill), p116 (snapshot cache invalidation tombstone) NOT SHIPPED.** Substrate (`hmac_pepper.py` + helper) is in place; migrations themselves require pg_fixture + Python data_upgrade authoring.
- **Task 2 step 9-10 (snapshot cache invalidation D-17) NOT SHIPPED.** `app/services/snapshots/snapshot_service.py` cache-key extension + `app/services/cache/snapshot_cache.py` creation pending.
- **Task 2 step 11 (privacy.py /privacy/delete real DSAR count D-16) NOT SHIPPED.** Hardcoded `nb_sessions=0, nb_reports=0, nb_documents=0, nb_analytics=0` still present at `services/backend/app/api/v1/endpoints/privacy.py:301-305`.
- **ALL of Task 3 (p98 fact_event PARTITION BY HASH + p113 projection_audit extension + ORM FactEvent/FactCurrent + projector + audit_mobile endpoint + Flutter MobileL1AuditService + first-slice canary parity gate) NOT SHIPPED.** This is the W1 -> W2 gate per D-25; without it, Plan 02-03 PR-3 CANNOT proceed.
- **Tasks 3A/3B/3C/3D (DDL iter-2 patches + atomic UPSERT + 5-shape canary + B2 Dart lint) NOT SHIPPED.**
- **iter-3 iA1 (`requires_pg` pytest marker + projector CI path filter) NOT SHIPPED.**
- **iter-3 iA2 (handshake replay ordering integration test) NOT SHIPPED.**
- **DEFERRED-02-01-A alembic dual-head merge migration NOT YET ADDRESSED** — orchestrator strongly recommends this as the FIRST step of Task 3 in the continuation. Without it, `alembic upgrade head` keeps failing for any consumer.
- **No engram `mem_save` invoked from this executor** — engram MCP tool not exposed to this sub-agent context (Claude Code agent loader limitation per CLAUDE.md §3.5). Orchestrator should save a post-return observation with `topic_key: mint-data-architecture-v1-02:wave-1:event-log-core-canary-partial`.
- **No PR opened.** All 4 commits live on the worktree branch `worktree-agent-a4d06b8ec6b66e046` only.
- **Backend tests run on system Python 3.9.6.** Production Railway runs Python 3.12 per pyproject.toml. The hmac.new + AES-GCM + Pydantic v2 code paths are interpreter-agnostic so this is unlikely to surface a real divergence, but I have NOT run the suite under 3.12.
- **Stage-of-4 honest framing (CLAUDE.md §9.5)**: PR opened = NOT YET (orchestrator-side step). CI green = UNKNOWN. Merged = UNKNOWN. Post-merge sim = NOT APPLICABLE (this plan ships pure backend security substrate; the canary parity gate that proves user-facing impact is DEFERRED to Task 3).

## Honest Work-vs-Value Separation (CLAUDE.md §9.4)

**WORK DONE (this executor)** :
- 4 atomic commits authored + signed by Julienbatt
- 58 new tests green
- 7338 backend-regression tests green (zero NEW failures introduced; 1 pre-existing DEFERRED-02-02-A documented)
- LSFin banned-terms + accent-FR + hmac_pepper_audit lints exit 0 on new surface
- D-XX substrate for D-02 / D-03 / D-07 / D-14 / D-15 / D-24 / D-26 / D-29 / D-33 / D-35-PROPOSED landed

**USER VALUE DELIVERED** :
- ZERO direct end-user-visible change. This plan ships the security + observability substrate that downstream Plans 02-03/02-04 will consume; users see no change yet.
- The real-pepper migration (p114) + plaintext-PII drop is the D-14 user-value moment — DEFERRED.
- The fact_event + projector + canary parity is the « events become source of truth » moment — DEFERRED.
- The MobileL1AuditService is the cold-start audit + offline-buffer user-protection moment — DEFERRED.

## Remaining Scope (continuation-agent prompt)

A fresh continuation agent picking this up should execute (in order, atomically per file group):

### A. DEFERRED-02-01-A alembic merge migration (BLOCKING for any new alembic work)

```bash
cd services/backend && python3 -m alembic merge p112_audit_event_user_hash p86_eclairage_delivered -m "merge_p86_eclairage_into_p112_head"
```
Commit the auto-generated merge migration as the first commit of the continuation.

### B. Task 2 step 9-11 — D-16 + D-17 (~2-3 commits)

- `services/backend/app/api/v1/endpoints/privacy.py` — replace hardcoded zeros at lines 301-305 with real `db.query(...).count()` calls for chat_messages, coach_insights, snapshots, projection_audit_records, audit_events.
- `services/backend/app/services/snapshots/snapshot_service.py` + new `app/services/cache/snapshot_cache.py` — extend snapshot-read cache key to include `constants_version_hash`; on regulatory-version bump, return fresh.
- 2 integration tests (`tests/integration/test_privacy_delete_real_count.py` + `tests/integration/test_snapshot_cache_invalidation.py`).

### C. Task 2 step 6-7-8 — alembic p114 + p115 + p116 (~3 commits)

- `p114_hmac_pepper_audit_events.py` chained off the new merge migration (NOT off p112 directly anymore). Python data_upgrade re-hashes existing `user_id_hash` rows with HMAC-pepper. Postgres path NULLs the plaintext `user_id` column.
- `p115_hmac_pepper_pii_columns.py` adds `actor_email_hash` / `ip_address_hash` / `user_agent_hash` to audit_events; Python data_upgrade backfills via `hmac_pii`.
- `p116_snapshot_constants_invalidation.py` tombstone migration documenting the D-17 cache-key extension shipped in code.
- 3 integration tests (`test_migration_p114.py`, `test_migration_p115.py`, `test_constants_propagation_pit.py`).

### D. Task 3 + Task 3A + Task 3B + Task 3C + Task 3D (~15-20 commits)

This is the bulk of the remaining work and represents what was originally scoped as a single « Task 3 » in the plan but iter-2 expanded into 5 tasks:

- **Task 3 step 1-9 (backend core)** : p98 (fact_event PARTITION BY HASH PARTITIONS 8 + fact_current covering index `(subject_id, fact_type)` + dek_vault.dek_scope + dek_vault FK RESTRICT + tombstone_at + 8 partitions + FK NOT VALID + fillfactor=70 + autovacuum tuning) + p113 (projection_audit extension w/ source + app_version + observed_at + anonymous_session_id + UNIQUE) + ORM models (FactEvent + FactCurrent + DEKVault.tombstone_at + ProjectionAuditRecord 4-column extension) + projector with atomic UPSERT (`INSERT ... ON CONFLICT ... DO UPDATE WHERE`) + audit_mobile endpoint with iter-2 A6 handshake + OpenAPI regen.
- **Task 3 step 10-15 (Flutter mobile L1)** : `apps/mobile/lib/services/audit/anonymous_session_id.dart` (UUID v7) + `audit_buffer_db.dart` (sqflite_sqlcipher schema + 30d TTL) + `offline_queue.dart` (exp backoff 1s/2s/4s/8s/16s cap 5min + connectivity_plus gate) + `mobile_l1_audit_service.dart` (cold-start + warm-resume >30min hooks) + `app_lifecycle_observer.dart` + 3 Dart test files.
- **Task 3 step 16 (canary parity gate)** : `test_canary_monthly_gross_income.py` — write fact_event -> projector -> assert `decrypt_value(fact_current.value_enc) == SnapshotModel.gross_income`. **This is the W1 -> W2 explicit gate per D-25.**
- **Task 3A** : DDL iter-2 patches inside p98 (A1 RESTRICT+tombstone, A2 PK reorder, A3 covering index leading col, B8 MODULUS 8, B9 FK NOT VALID, B10 fillfactor+autovacuum, B11 EnhancedConfidence cap — B11 already shipped here).
- **Task 3B** : projector atomic UPSERT replacing SELECT-then-UPDATE (T-PG-02 HIGH).
- **Task 3C** : 5-shape canary parity gate (scalar + decimal + nested JSONB + nullable + TOAST blob) — D-34 PROPOSED.
- **Task 3D** : `tools/checks/no_mobile_fact_current_regulatory_read.py` HARD lefthook on Dart files (architect-review MED — L1 boundary).
- **iter-3 iA1** : `services/backend/conftest.py` registers `requires_pg` marker; all projector tests decorated; CI `pg-integration` path filter extended to `services/backend/app/services/projector/**`.
- **iter-3 iA2** : `tests/integration/test_audit_mobile_link_handshake_replay_ordering.py` — interleaved 5-start + 5-warm-resume + 1-login batch end-to-end.

Estimated continuation cost: **20-30 atomic commits, 30-40 files, 4-8 hours focused work.**

## Self-Check

Per execution doctrine — verify claims before declaring success.

### Files created (11 spot-checked, all FOUND)
```bash
for f in \
  services/backend/app/models/encryption/__init__.py \
  services/backend/app/models/encryption/encrypted_value.py \
  services/backend/app/services/encryption/encrypted_value_helper.py \
  services/backend/app/services/encryption/banned_terms_runtime.py \
  services/backend/app/observability/counters.py \
  services/backend/tests/test_hmac_pepper.py \
  services/backend/tests/test_encrypted_value_model.py \
  services/backend/tests/test_encrypted_value_helper.py \
  services/backend/tests/test_key_vault_logical_id.py \
  services/backend/tests/test_dek_envelope_concurrency.py \
  services/backend/tests/integration/test_dek_shred_opacity.py; do
  [ -f "$f" ] && echo "FOUND: $f"; done
```

### Commits exist (4/4 FOUND)
```bash
for sha in 8166e3f4 d7e2d4b3 3d7e38ea 0c29b5dd; do
  git log --oneline | grep -q "$sha" && echo "FOUND: $sha"; done
```

## Self-Check: PASSED

All 11 created files exist on disk. All 4 commits present in `git log dc5d7d0b..HEAD`. Evidence cited above with command + exit code per CLAUDE.md §9.6.

## Engram Persistence

`mem_save` MCP tool NOT exposed to this sub-agent context (Claude Code agent loader limitation per CLAUDE.md §3.5). Orchestrator should save post-return:
  - `topic_key: mint-data-architecture-v1-02:wave-1:event-log-core-canary-partial-substrate-only`
  - `type: architecture`
  - `prior_finding_refs: [Plan-02-01 SUMMARY obs, obs #163 Phase-01 CONTEXT, obs #175 hmac-pepper rainbow-table, obs #186 D-MOB-03, obs #187 QA-Postgres, obs #188 Postgres-BOOLEAN]`
  - Content: « Plan 02-02 partial-ship 4 commits security+observability substrate (hmac_pepper canonical, EncryptedValue D-26 wire, KMS fail-closed + TTL DEK cache, Sentry value_enc strip, 8 D-33 counters). Task 2 alembic + Task 3 (p98 fact_event + projector + audit_mobile + Flutter mobile L1 + canary parity gate) DEFERRED to continuation agent. DEFERRED-02-02-A pre-existing frontalier-rename test fixture stale post-Plan-02-01-D-09. »

---

*Phase: mint-data-architecture-v1-02-event-log-projection*
*Plan: 02-event-log-core-canary*
*Status: PARTIAL SHIP — security/observability substrate landed; alembic + projector + mobile L1 + canary deferred to continuation agent*
*Completed (partial): 2026-05-18*
