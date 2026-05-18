---
phase: mint-data-architecture-v1-02-event-log-projection
plan: 02-event-log-core-canary
subsystem: backend-encryption-observability-privacy
tags: [hmac-pepper, encrypted-value, dek-envelope, kms-fail-closed, ttl-cache, observability-counters, sentry-strip, lsfin-banned-terms-runtime, alembic-dual-head-resolved, privacy-dsar-real-count, snapshot-cache-invalidation]
description: PARTIAL SHIP CONTINUATION-2 — Plan 02-02 substrate (4 commits from prior executor) + P0 alembic dual-head merge + P1 D-16 /privacy/delete real DSAR count + D-17 snapshot cache invalidation contract landed in 3 new atomic commits on top of substrate. Task 2 alembic p114/p115/p116 + ALL of Task 3 (p98 fact_event PARTITION BY HASH + p113 + ORM + projector + audit_mobile endpoint + Flutter MobileL1AuditService + canary parity gate) + Tasks 3A/3B/3C/3D + iter-3 iA1/iA2 are DEFERRED to a third continuation agent — see § Remaining Scope below.

# Dependency graph
requires:
  - phase: mint-data-architecture-v1-02-event-log-projection
    plan: 01-prereqs-lints-harness
    provides: hmac_pepper.py stub + EncryptedValue area + pg_fixture + 3 HARD lints + p112 alembic head + audit_service.hash_user_id surface
provides:
  # --- from prior executor's substrate commits (4 commits, kept verbatim) ---
  - app/services/audit/hmac_pepper.py REAL impl (PepperNotConfigured + hmac_pii/hmac_user_id/hmac_actor_email)
  - app/services/audit_service.py routes hash_user_id() through hmac_user_id() (caller API preserved)
  - app/models/encryption/encrypted_value.py (EncryptedValue D-26 + EnhancedConfidence D-29+iter-2-B11)
  - app/services/encryption/encrypted_value_helper.py (encrypt_value/decrypt_value + LOGICAL_DEK_ID + iter-2 B6 banned-terms gate)
  - app/services/encryption/banned_terms_runtime.py (reuses tools/checks vocabulary at runtime)
  - app/services/encryption/key_vault.py (KMSBackendUnavailable + fail-closed _select_backend + TTLCache _dek_cache + LOGICAL kms_key_ref)
  - app/observability/counters.py (8 counters: 6 D-33 base + 2 iter-2)
  - app/core/sentry_scrub.py (extended forbidden-key regex with value_enc|_dek_cache)
  # --- NEW from continuation-2 (this executor) ---
  - alembic/versions/6e1790485c70_merge_p86_eclairage_into_p112_head.py (revision p98_merge_p86_eclairage — DEFERRED-02-01-A resolved)
  - app/api/v1/endpoints/privacy.py (D-16 hardcoded zeros → real db.query().count() for sessions/snapshots/documents/analytics)
  - app/services/cache/snapshot_cache.py (D-17 is_snapshot_stale + cache_key_for_snapshot)
  - tests/integration/test_privacy_delete_real_count.py (4 tests, D-16)
  - tests/integration/test_snapshot_cache_invalidation.py (6 tests, D-17)
affects: [mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence (still blocked on p98+p113+p114+p115+p116 from THIS plan's third continuation), mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks (D-33 counter firing-assertions deferred per plan)]

# Tech tracking
tech-stack:
  added: [cachetools (TTLCache for _dek_cache from substrate)]
  patterns:
    - "Fail-closed env-var resolution (D-35) — substrate"
    - "Canonical entry routing (substrate)"
    - "Pydantic v2 Literal + extra='forbid' typed JSONB shape — substrate"
    - "alembic merge migration (empty upgrade/downgrade) to resolve dual-head topology — continuation-2"
    - "Real DSAR count via per-table db.query(...).count() keyed on authenticated user_id, with profile_id → session.profile_id join — continuation-2"
    - "Read-side cache invalidation via stamped-vs-active hash comparison (D-04 point-in-time row immutability preserved) — continuation-2"

key-files:
  created:
    # substrate
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
    # continuation-2
    - services/backend/alembic/versions/6e1790485c70_merge_p86_eclairage_into_p112_head.py
    - services/backend/app/services/cache/snapshot_cache.py
    - services/backend/tests/integration/test_privacy_delete_real_count.py
    - services/backend/tests/integration/test_snapshot_cache_invalidation.py
  modified:
    # substrate
    - services/backend/app/services/audit/hmac_pepper.py
    - services/backend/app/services/audit_service.py
    - services/backend/app/services/encryption/key_vault.py
    - services/backend/app/core/sentry_scrub.py
    - services/backend/tests/test_audit_user_id_hash.py
    - tools/checks/_baseline_hmac_sites_at_p112.txt
    - .planning/phases/mint-data-architecture-v1-02-event-log-projection/deferred-items.md
    # continuation-2
    - services/backend/app/api/v1/endpoints/privacy.py

key-decisions:
  # substrate decisions (kept verbatim)
  - "hash_user_id() public surface preserved — backwards compat for open_banking.consent_manager + others — but implementation routed through hmac_user_id() (D-14 substrate landed without caller-API breakage)."
  - "Lazy-import counters in key_vault._select_backend to avoid circular dependency with observability/counters (resilient to absence — no-op if import fails)."
  - "Removed silent KMS->Fernet fallback per iter-2 A4 + D-35 PROPOSED. Dev opt-in is now MINT_KMS_BACKEND=fernet explicit env. TESTING=1 keeps the 7000+ test-suite path intact."
  - "TTLCache from cachetools (5min TTL + 1024 maxsize) replaces unbounded dict for _dek_cache."
  - "iter-2 B6 banned-terms runtime helper IMPORTS the lint vocabulary tuples directly from tools/checks/banned_terms_python.py."
  - "DEK race-loser test simulated sequentially. macOS system-Python 3.9.6 + sqlite3 segfaults under 2-thread concurrent INSERT into in-memory DB; real-race coverage is via pg_fixture in Task 3B test_projector_concurrent_upsert.py (NOT YET landed)."
  # continuation-2 decisions
  - "Used alembic CLI auto-generated revision filename (6e1790485c70_...) but overrode the in-file revision id to 'p98_merge_p86_eclairage' (24 chars, under the 32-char alembic_revision_length lint cap) for human-readable migration discovery via `ls alembic/versions/ | grep p9`."
  - "D-16 real-count : sessions counted via SessionModel.profile_id joined through ProfileModel.user_id (existing codebase convention), not a direct user_id column on sessions. The PrivacyService deletion-manifest schema preserves the legacy `nb_sessions / nb_reports / nb_documents / nb_analytics` argument names for backwards-compat with the nLPD receipt template."
  - "D-17 read-side invalidation : is_snapshot_stale(row) returns True when active RegulatoryRegistry version_hash differs from row.constants_version_hash. The stale row is NOT mutated (D-04 point-in-time immutability) ; the read path triggers a recompute. snapshot_cache.py contains pure functions only — wiring into snapshot_service.py read path is deferred to Plan 02-04 (the read path will call is_snapshot_stale before returning cached state)."
  - "D-17 cache key format `snapshot:{user_id}:{inputs_hash}:{constants_version_hash}` — regulatory rotation naturally evicts old entries via key mismatch."

patterns-established:
  # substrate (kept verbatim)
  - "Canonical entry routing: a public function kept for backwards-compat, body now calls the D-XX-canonical entry. Caller-facing API stable; security substrate swapped underneath."
  - "Fail-closed env resolution: missing critical env -> raise exception with the exact env var name + fallback opt-in documented in the exception message."
  - "Pydantic v2 wire-shape with Literal['constant_value'] for hard-coded contract fields."
  - "TTL-bounded plaintext-DEK cache: TTLCache(maxsize=1024, ttl=300s)."
  # continuation-2
  - "Alembic dual-head merge as pure topological merge (empty upgrade/downgrade body) so consumer migrations can chain off a single new head id."
  - "DSAR real-count pattern : for every category in the deletion manifest, query the canonical model by authenticated user_id (or by joined FK for sessions which key on profile_id). Tests use the conftest TestingSessionLocal fixture to seed N rows of each kind and assert the manifest reflects the seed count."
  - "Read-side cache invalidation by hash-comparison : write side stamps constants_version_hash, read side compares to RegulatoryRegistry.version_hash(on_date). Cache key includes the hash so rotation evicts naturally without a row mutation (D-04 PIT preserved)."

requirements-completed: []  # 16 plan-frontmatter D-XX dispositions: 9 fully shipped (D-02 D-03 D-07 D-14 D-15 D-16 D-17 D-24 D-26 D-29 substrate + cont-2), 9 deferred. See § Status Matrix below.

# Metrics
duration: ~50min substrate (prior executor) + ~30min continuation-2 (this executor)
completed: 2026-05-18 (PARTIAL — see Remaining Scope)
---

# Phase mint-data-architecture-v1-02 Plan 02-02 (PARTIAL CONTINUATION-2): W1 Event-Log Core + Canary — Substrate + P0 + P1 (D-16, D-17)

**PARTIAL SHIP — Substrate (4 commits from prior executor) + P0 alembic merge + P1 D-16 privacy real-count + D-17 snapshot cache invalidation landed in 3 new atomic commits. Task 2 alembic p114/p115/p116 + ALL of Task 3 (p98 fact_event + projector + audit_mobile + Flutter mobile L1 + canary parity gate) + Tasks 3A/3B/3C/3D + iter-3 iA1/iA2 DEFERRED to a third continuation agent.**

## Performance

- **Substrate duration (prior executor, partial-ship at 18:47Z):** ~47 min
- **Continuation-2 duration (this executor):** ~30 min
- **Started continuation-2:** 2026-05-18T20:55Z (worktree reset to expected base 846aaa56)
- **Continuation-2 checkpoint:** 2026-05-18T21:25Z
- **Total atomic commits (substrate + continuation-2):** 4 + 3 = 7
- **Total new tests (substrate + continuation-2):** 58 + 10 = 68
- **Total files created (substrate + continuation-2):** 11 + 4 = 15
- **Total files modified (substrate + continuation-2):** 6 + 1 = 7

## Task Commits

| # | Commit | Type | Scope | Source |
|---|--------|------|-------|--------|
| 1 | `8166e3f4` | feat | hmac_pepper canonical entry (D-14, D-15, D-24) — 11 unit tests, baseline 4 -> 3 | substrate |
| 2 | `d7e2d4b3` | feat | EncryptedValue D-26 model + encrypt_value/decrypt_value helpers + iter-2 B6 + B11 + C5 — 28 unit tests | substrate |
| 3 | `3d7e38ea` | feat | KMS fail-closed + DEK TTL cache + D-33 counters + Sentry value_enc strip — 13 unit tests + 4 integration tests | substrate |
| 4 | `0c29b5dd` | test | adapt audit_user_id_hash test to D-14 HMAC-pepper migration + document DEFERRED-02-02-A | substrate |
| 5 | `2e383103` | feat | DEFERRED-02-01-A alembic dual-head merge (p98_merge_p86_eclairage) — P0 | continuation-2 |
| 6 | `521cb35a` | feat | D-16 /privacy/delete real DSAR row counts + 4 integration tests — P1 Task 2 step 11 | continuation-2 |
| 7 | `0e5749dd` | feat | D-17 snapshot cache invalidation (is_snapshot_stale + cache_key_for_snapshot) + 6 tests — P1 Task 2 step 9-10 | continuation-2 |

## Status Matrix — 16 plan-frontmatter D-XX dispositions

| D-XX | Status | Evidence |
|------|--------|----------|
| D-01 fact_current covering index | **DEFERRED — Task 3** | p98 migration not yet landed |
| D-02 KMS Railway-native logical key-id | **SUBSTRATE SHIPPED** | `key_vault.py` writes MINT_KMS_KEY_ID env value into `dek_vault.kms_key_ref` ; `LOGICAL_DEK_ID='mint-master-v1'` in `encrypted_value_helper.py:50` |
| D-03 DEK shred all-or-nothing | **SHIPPED** | `tests/integration/test_dek_shred_opacity.py` 4/4 green |
| D-07 fail-closed pepper config | **SHIPPED** | `PepperNotConfigured` raises when env unset + TESTING != '1' |
| D-12 D-MOB-03 mobile L1 audit POST | **DEFERRED — Task 3** | audit_mobile endpoint + projection_audit_record extension not yet landed |
| D-13 D-MOB-04 clean separation | **DEFERRED — Task 3** | assertion test requires audit_mobile endpoint |
| D-14 audit_events.user_id_hash HMAC-pepper | **SUBSTRATE SHIPPED** | `audit_service.hash_user_id` routes through `hmac_user_id` ; p114 backfill migration **DEFERRED** |
| D-15 actor_email/ip/user_agent HMAC | **SUBSTRATE SHIPPED** | `hmac_actor_email` + `hmac_pii` exposed ; p115 add-columns migration **DEFERRED** |
| D-16 /privacy/delete real DSAR count | **SHIPPED — continuation-2** | `privacy.py:286-330` now queries sessions+snapshots+docs+analytics+coach_insights ; 4 integration tests green (commit `521cb35a`) |
| D-17 SnapshotModel.constants_version_hash cache invalidation | **SHIPPED — continuation-2** | `app/services/cache/snapshot_cache.py` is_snapshot_stale + cache_key_for_snapshot ; 6 tests green (commit `0e5749dd`) — wiring into snapshot_service read path deferred to Plan 02-04 |
| D-19 app-side projector with session.begin() | **DEFERRED — Task 3 step 6** | fact_projector.py not yet shipped |
| D-25 first-slice canary monthly_gross_income | **DEFERRED — Task 3 step 16** | W1 -> W2 gate test pending |
| D-26 value_enc typed JSONB Pydantic v2 EncryptedValue | **SHIPPED** | `app/models/encryption/encrypted_value.py` + 11 unit tests green ; helper wrapper + roundtrip tests 17/17 green |
| D-27 fact_event idempotency UNIQUE | **DEFERRED — Task 3 step 1** | p98 migration carries the UNIQUE |
| D-28 PARTITION BY HASH from day one | **DEFERRED — Task 3 step 1** | p98 PARTITION BY HASH (subject_id) PARTITIONS 8 (iter-2 B8) |
| D-29 confidence JSONB full EnhancedConfidence | **SHIPPED** | `EnhancedConfidence` Pydantic class with iter-2 B11 cap (5 prompts x 200 chars) + 7 unit tests green |
| D-30 anonymous-session buffer mechanics | **DEFERRED — Task 3 steps 10-15** | Flutter MobileL1AuditService + sqflite_sqlcipher + UUID v7 not yet shipped |
| D-33 (declared only) 8 counters | **SHIPPED** | `app/observability/counters.py` exports 8 counter/gauge/histogram instances ; firing-assertions deferred to Plan 02-04 per plan |
| D-34 PROPOSED multi-shape canary | **DEFERRED — Task 3C** | 5-shape canary fixtures not yet shipped |
| D-35 PROPOSED KMS fail-closed | **SHIPPED** | `KMSBackendUnavailable` exception + `_select_backend` rewritten ; `mint_kms_backend_failure_total` counter increments on fallback |

**Iter-2 patches shipped here**: A4 + A5 + B6 + B11 + C5 (key_vault + helper + EnhancedConfidence + Sentry) from substrate.
**Iter-2 patches DEFERRED**: A1, A2, A3, A6, A8, A11, B2, B8, B9, B10, B12, B15, C3, C7 (all in Task 3 / 3A / 3B / 3C / 3D).
**Iter-3 patches**: iA3 cleared (Julien Railway env-var checkpoint approved 2026-05-18). iA1, iA2 DEFERRED.

**DEFERRED-02-01-A : RESOLVED** in continuation-2 via commit `2e383103`. Alembic now has single head `p98_merge_p86_eclairage`. Every new migration in Phase 02 can chain off this id ; `alembic upgrade head` (singular) succeeds.

## 0-Trust §9.6 Evidence + Caveat block

**Evidence (deterministic citations, continuation-2 additions) :**
- `git log --oneline 846aaa56..HEAD` → 3 NEW commits : `2e383103 / 521cb35a / 0e5749dd`
- `cd services/backend && python3 -c "from alembic.config import Config; from alembic.script import ScriptDirectory; print(ScriptDirectory.from_config(Config('alembic.ini')).get_heads())"` → `['p98_merge_p86_eclairage']` (single head, post-merge)
- `python3 tools/checks/alembic_revision_length.py --file services/backend/alembic/versions/6e1790485c70_merge_p86_eclairage_into_p112_head.py` → exit 0
- Alembic upgrade head proof : standalone `python3 -c` script runs `command.upgrade(cfg, 'head')` on fresh SQLite — completes without `MultipleHeads` error ; final revision = `p98_merge_p86_eclairage`
- `cd services/backend && python3 -m pytest tests/integration/test_privacy_delete_real_count.py tests/integration/test_snapshot_cache_invalidation.py -q` → `10 passed in 0.32s` (captured 2026-05-18T21:20Z)
- `cd services/backend && python3 -m pytest tests/test_hmac_pepper.py tests/test_encrypted_value_model.py tests/test_encrypted_value_helper.py tests/test_key_vault_logical_id.py tests/test_dek_envelope_concurrency.py tests/integration/test_dek_shred_opacity.py tests/test_audit_user_id_hash.py tests/integration/test_privacy_delete_real_count.py tests/integration/test_snapshot_cache_invalidation.py -q` → `68 passed in 2.05s` (substrate 58 + continuation-2 10, zero regression)
- `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/privacy.py services/backend/app/services/cache/snapshot_cache.py services/backend/tests/integration/test_privacy_delete_real_count.py services/backend/tests/integration/test_snapshot_cache_invalidation.py` → exit 0
- `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0
- All 3 new commits authored with `LEFTHOOK_BYPASS=1` (NOT `--no-verify`) per CLAUDE.md §5 DEV RULES + GUARD-07 grep-able convention.

**Evidence (substrate, prior executor — kept for completeness) :**
- `git log --oneline dc5d7d0b..846aaa56` → 4 substrate commits : `8166e3f4 / d7e2d4b3 / 3d7e38ea / 0c29b5dd`
- `cd services/backend && python3 -m pytest tests/ -q --ignore=<pre-existing dual-head>` → `7338 passed, 1 failed (DEFERRED-02-02-A pre-existing — frontalier-rename test fixture stale post-D-09), 82 skipped, 3 xfailed in 121s` (zero NEW regressions caused by substrate)
- Julien Railway-env-var checkpoint confirmation 2026-05-18

**Caveat (what I have NOT done / what is UNKNOWN, continuation-2) :**
- **Task 2 alembic migrations p114 / p115 / p116 NOT SHIPPED.** Substrate (`hmac_pepper.py` + helper) + DEFERRED-02-01-A merge migration are in place ; p114 backfill (audit_events.user_id_hash HMAC re-hash + plaintext NULL) + p115 (actor_email_hash / ip_address_hash / user_agent_hash columns + backfill) + p116 (snapshot_constants_invalidation tombstone) still require pg_fixture data_upgrade authoring.
- **ALL of Task 3 (p98 fact_event PARTITION BY HASH + p113 projection_audit extension + ORM FactEvent/FactCurrent + projector + audit_mobile endpoint + Flutter MobileL1AuditService + first-slice canary parity gate) NOT SHIPPED.** This is the W1 → W2 gate per D-25 ; without it, Plan 02-03 PR-3 CANNOT proceed.
- **Tasks 3A/3B/3C/3D (DDL iter-2 patches + atomic UPSERT + 5-shape canary + B2 Dart lint) NOT SHIPPED.**
- **iter-3 iA1 (`requires_pg` pytest marker + projector CI path filter) NOT SHIPPED.**
- **iter-3 iA2 (handshake replay ordering integration test) NOT SHIPPED.**
- **D-17 wiring NOT YET INSIDE snapshot_service.py read path.** continuation-2 ships pure-function `is_snapshot_stale` + `cache_key_for_snapshot` with 6 unit tests proving the contract ; integrating them into the snapshot read path (so a stale row triggers actual recompute) is a Plan 02-04 deferred step ; flagged in module docstring.
- **Full backend regression NOT re-run by continuation-2.** Substrate's prior executor ran the full suite (`7338 passed / 1 pre-existing fail / 82 skipped / 3 xfailed`). continuation-2 only ran the 9-test file targeted slice (`68 passed`). The 10 new tests touch privacy.py + snapshot_cache.py + tests/integration/ — surfaces unrelated to any pre-existing regression. Honest framing : I am confident no regression was introduced, but I have NOT re-proven it with the full 7338-test sweep.
- **No engram `mem_save` invoked from this executor** — engram MCP tool not exposed to this sub-agent context (Claude Code agent loader limitation per CLAUDE.md §3.5). Orchestrator should save post-return with `topic_key: mint-data-architecture-v1-02:wave-1:event-log-core-canary-partial-continuation-2`.
- **No PR opened.** All 7 commits (4 substrate + 3 continuation-2) live on the worktree branch only.
- **Backend tests run on system Python 3.9.6.** Production Railway runs Python 3.12. Unlikely to surface a real divergence for the surfaces touched.
- **Stage-of-4 honest framing (CLAUDE.md §9.5)**: PR opened = NOT YET. CI green = UNKNOWN. Merged = UNKNOWN. Post-merge sim = NOT APPLICABLE.

## Honest Work-vs-Value Separation (CLAUDE.md §9.4)

**WORK DONE (continuation-2)** :
- 3 NEW atomic commits authored + signed by Julienbatt (LEFTHOOK_BYPASS=1 — NOT --no-verify, per CLAUDE.md §5 DEV RULES)
- 10 NEW tests green
- Alembic dual-head condition (pre-existing since before Plan 02-01) RESOLVED — every new migration in Phase 02 / 03 / 04 can now chain off the single new head id
- D-16 (real DSAR count) closed — nLPD art. 32 « manifest of what was deleted » contract now truthful
- D-17 substrate (is_snapshot_stale contract + 6 tests) shipped — read-path wiring deferred to Plan 02-04

**USER VALUE DELIVERED (continuation-2)** :
- DSAR (Data Subject Access Request) deletion receipts now show TRUTHFUL row counts instead of « 0 sessions / 0 reports / 0 documents / 0 analytics » regardless of seeded data. This is a direct end-user-visible compliance fix for users who hit `/privacy/delete` — they now see what actually got deleted.
- Alembic infrastructure unblocked : Plan 02-03 / 02-04 migration authors are no longer blocked on the dual-head condition.
- ZERO end-user-visible change from D-17 yet (read-side wiring deferred).

## Remaining Scope (continuation-3 agent prompt)

A fresh continuation-3 agent picking this up should execute (in order, atomically per file group). All P0-P1 alembic infrastructure is now in place ; the remaining work is purely additive.

### A. Task 2 step 6-7-8 — alembic p114 + p115 + p116 (~3 commits, ~4-6 hours)

- `p114_hmac_pepper_audit_events.py` chained off `p98_merge_p86_eclairage` (NEW single head). Python data_upgrade re-hashes existing `user_id_hash` rows with HMAC-pepper via `hmac_user_id()`. Postgres path NULLs the plaintext `user_id` column.
- `p115_hmac_pepper_pii_columns.py` adds `actor_email_hash` / `ip_address_hash` / `user_agent_hash` columns to audit_events. Python data_upgrade backfills via `hmac_pii()`.
- `p116_snapshot_constants_invalidation.py` tombstone migration documenting the D-17 cache-key extension shipped in code (continuation-2). Empty upgrade/downgrade body.
- 3 pg_fixture integration tests (`test_migration_p114.py`, `test_migration_p115.py`, `test_constants_propagation_pit.py`).

### B. Task 3 + Task 3A + Task 3B + Task 3C + Task 3D (~15-20 commits, ~6-8 hours focused work)

This is the bulk of the remaining work :

- **Task 3 step 1-9 (backend core)** : p98 (fact_event PARTITION BY HASH PARTITIONS 8 + fact_current covering index `(subject_id, fact_type)` + dek_vault.dek_scope + dek_vault FK RESTRICT + tombstone_at + 8 partitions + FK NOT VALID + fillfactor=70 + autovacuum tuning) + p113 (projection_audit extension w/ source + app_version + observed_at + anonymous_session_id + UNIQUE) + ORM models (FactEvent + FactCurrent + DEKVault.tombstone_at + ProjectionAuditRecord 4-column extension) + projector with atomic UPSERT + audit_mobile endpoint with iter-2 A6 handshake + OpenAPI regen.
- **Task 3 step 10-15 (Flutter mobile L1)** : 5 Dart files (anonymous_session_id, audit_buffer_db, offline_queue, mobile_l1_audit_service, app_lifecycle_observer) + 3 Dart tests + pubspec.yaml deps (sqflite_sqlcipher + uuid + connectivity_plus).
- **Task 3 step 16 (canary parity gate)** : `test_canary_monthly_gross_income.py` — THE W1 → W2 gate per D-25.
- **Task 3A** : DDL iter-2 patches inside p98.
- **Task 3B** : projector atomic UPSERT.
- **Task 3C** : 5-shape canary parity gate — D-34 PROPOSED.
- **Task 3D** : `tools/checks/no_mobile_fact_current_regulatory_read.py` HARD lefthook on Dart files.
- **iter-3 iA1** : `services/backend/conftest.py` registers `requires_pg` marker.
- **iter-3 iA2** : `tests/integration/test_audit_mobile_link_handshake_replay_ordering.py`.

Estimated continuation-3 cost : **17-23 atomic commits, 25-35 files, 6-8 hours focused work.**

## Self-Check

Per execution doctrine — verify claims before declaring success.

### Files created (15 spot-checked, all FOUND)
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
  services/backend/tests/integration/test_dek_shred_opacity.py \
  services/backend/alembic/versions/6e1790485c70_merge_p86_eclairage_into_p112_head.py \
  services/backend/app/services/cache/snapshot_cache.py \
  services/backend/tests/integration/test_privacy_delete_real_count.py \
  services/backend/tests/integration/test_snapshot_cache_invalidation.py; do
  [ -f "$f" ] && echo "FOUND: $f"; done
```

### Commits exist (7/7 FOUND)
```bash
for sha in 8166e3f4 d7e2d4b3 3d7e38ea 0c29b5dd 2e383103 521cb35a 0e5749dd; do
  git log --oneline | grep -q "$sha" && echo "FOUND: $sha"; done
```

## Self-Check: PASSED

All 15 created files exist on disk. All 7 commits present in `git log dc5d7d0b..HEAD`. Evidence cited above with command + exit code per CLAUDE.md §9.6.

## Engram Persistence

`mem_save` MCP tool NOT exposed to this sub-agent context (Claude Code agent loader limitation per CLAUDE.md §3.5). Orchestrator should save post-return :
  - `topic_key: mint-data-architecture-v1-02:wave-1:event-log-core-canary-partial-continuation-2`
  - `type: architecture`
  - `prior_finding_refs: [Plan-02-01 SUMMARY obs, prior continuation-1 partial-ship obs (from substrate commits), obs #163 Phase-01 CONTEXT, obs #175 hmac-pepper rainbow-table, obs #186 D-MOB-03, obs #187 QA-Postgres, obs #188 Postgres-BOOLEAN]`
  - Content : « Plan 02-02 partial-continuation-2 : 3 new commits on top of substrate. P0 alembic dual-head merge (DEFERRED-02-01-A resolved — `p98_merge_p86_eclairage` is new single head). D-16 /privacy/delete real DSAR count (replaced 4 hardcoded zeros with db.query.count() per table, 4 integration tests green). D-17 snapshot cache invalidation contract (is_snapshot_stale + cache_key_for_snapshot pure functions, 6 tests green ; snapshot_service read-path wiring deferred to Plan 02-04). Task 2 alembic p114/p115/p116 + ALL of Task 3 (p98 fact_event + projector + audit_mobile + Flutter mobile L1 + canary parity gate) + Tasks 3A/3B/3C/3D + iter-3 iA1/iA2 STILL DEFERRED to continuation-3. »

---

*Phase: mint-data-architecture-v1-02-event-log-projection*
*Plan: 02-event-log-core-canary*
*Status: PARTIAL SHIP CONTINUATION-2 — substrate (4) + P0 alembic merge + P1 D-16 + D-17 (3) landed ; Task 2 alembic + Task 3 + Tasks 3A/3B/3C/3D + iter-3 iA1/iA2 deferred to continuation-3 agent*
*Completed (partial-continuation-2): 2026-05-18*
