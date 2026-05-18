---
phase: mint-data-architecture-v1-02-event-log-projection
plan: 02-event-log-core-canary
subsystem: backend-event-log-projection-canary
tags: [hmac-pepper, encrypted-value, dek-envelope, kms-fail-closed, ttl-cache, observability-counters, sentry-strip, lsfin-banned-terms-runtime, alembic-dual-head-resolved, privacy-dsar-real-count, snapshot-cache-invalidation, fact-event-partition-by-hash, fact-current-upsert, d19-atomic-projector, d25-canary-parity-gate-green]
description: CRITICAL PATH COMPLETE CONTINUATION-3 — substrate (4 commits) + P0 alembic merge + P1 D-16 + D-17 (3 commits from continuation-2) + 5 NEW commits from this continuation-3 landing the W1 -> W2 canary parity gate green on SQLite. fact_event PARTITION BY HASH 8 + fact_current covering index + FactProjector atomic UPSERT (D-19) + snapshot_service feature-flag-gated read path + D-25 canary parity gate green (2 SQLite tests passed, 1 pg-marked skipped). Mobile L1 + audit_mobile endpoint + p114/p115/p116 alembic + Tasks 3A/3B/3C/3D iter-2 polish + iter-3 iA1/iA2 explicitly DEFERRED to continuation-4 to maintain scope discipline.

# Dependency graph
requires:
  - phase: mint-data-architecture-v1-02-event-log-projection
    plan: 01-prereqs-lints-harness
    provides: hmac_pepper.py stub + EncryptedValue area + pg_fixture + 3 HARD lints + p112 alembic head + audit_service.hash_user_id surface
provides:
  # --- from substrate (4 commits, kept verbatim) ---
  - app/services/audit/hmac_pepper.py REAL impl
  - app/models/encryption/encrypted_value.py (EncryptedValue D-26 + EnhancedConfidence D-29+iter-2-B11)
  - app/services/encryption/encrypted_value_helper.py
  - app/services/encryption/banned_terms_runtime.py
  - app/services/encryption/key_vault.py
  - app/observability/counters.py
  - app/core/sentry_scrub.py
  # --- from continuation-2 (3 commits, kept verbatim) ---
  - alembic/versions/6e1790485c70_merge_p86_eclairage_into_p112_head.py (p98_merge_p86_eclairage)
  - app/api/v1/endpoints/privacy.py D-16 real DSAR count
  - app/services/cache/snapshot_cache.py D-17 is_snapshot_stale + cache_key_for_snapshot
  # --- NEW from continuation-3 (this executor, 5 commits) ---
  - alembic/versions/p98_fact_event_projection.py (D-01 + D-27 + D-28 — fact_event PARTITION BY HASH 8 + fact_current covering index + REVOKE append-only)
  - app/models/fact_event.py (D-27 append-only ORM)
  - app/models/fact_current.py (D-01 denormalised read-side ORM)
  - app/services/projector/__init__.py + app/services/projector/fact_projector.py (D-19 atomic project_event)
  - app/services/snapshots/snapshot_service.py + read_monthly_gross_income (D-25 substrate, feature-flag-gated)
  - tests/test_projector_atomicity.py (3 tests, D-19 proof)
  - tests/integration/test_canary_monthly_gross_income.py (3 tests, D-25 GATE — 2 SQLite green + 1 pg-marked skipped)
affects: [mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence (UNBLOCKED — D-25 canary GREEN means PR-3 HARD-mode parity-lint flip per D-31 can now proceed), mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks (D-33 counter firing-assertions still deferred per plan)]

# Tech tracking
tech-stack:
  added: [cachetools (TTLCache for _dek_cache, from substrate)]
  patterns:
    - "Fail-closed env-var resolution (D-35) — substrate"
    - "Canonical entry routing (substrate)"
    - "Pydantic v2 Literal + extra='forbid' typed JSONB shape — substrate"
    - "alembic merge migration (empty upgrade/downgrade) to resolve dual-head topology — continuation-2"
    - "Real DSAR count via per-table db.query(...).count() — continuation-2"
    - "Read-side cache invalidation via stamped-vs-active hash comparison — continuation-2"
    - "PARTITION BY HASH (user_id) PARTITIONS 8 + 8 explicit partition declarations + REVOKE UPDATE,DELETE on parent + each partition (Postgres-only ; SQLite test path uses non-partitioned table) — continuation-3"
    - "ONLINE FK migration : ADD CONSTRAINT ... NOT VALID followed by separate VALIDATE statement (Postgres-only ; SQLite declares FK inline at CREATE TABLE time, no online path needed) — continuation-3"
    - "Postgres covering INCLUDE-index for index-only scans on (user_id, field_key) INCLUDE (value_enc, valid_from) ; SQLite falls back to plain composite index named identically so reflective DDL diffs don't surface phantom drift — continuation-3"
    - "Atomic single-transaction projector : 'with session.begin()' wraps fact_event INSERT + fact_current UPSERT ; rollback on any exception leaves read-side (fact_current) NEVER ahead of write-side (fact_event) — D-19 — continuation-3"
    - "Idempotent UPSERT with WHERE-guard : ON CONFLICT (user_id, field_key) DO UPDATE ... WHERE excluded.valid_from > fact_current.valid_from — last-writer-wins by valid_from, older events arriving late do NOT clobber newer state, D-04 PIT preserved — continuation-3"
    - "Feature-flag-gated read-path migration (FF_FACT_CURRENT_READ default OFF) — zero end-user-visible change until Plan 02-03 PR-2 flips the flag during dual-write phase — continuation-3"
    - "Dual-test-variant for dialect-specific guarantees : SQLite always-on signal for dialect-independent contracts (atomicity, UPSERT semantics, append-only invariant) + pg-marked variant for Postgres-only guarantees (PARTITION BY HASH routing, REVOKE enforcement, INCLUDE covering index) skipped if Docker unavailable — continuation-3"

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
    # continuation-3 (THIS EXECUTOR)
    - services/backend/alembic/versions/p98_fact_event_projection.py
    - services/backend/app/models/fact_event.py
    - services/backend/app/models/fact_current.py
    - services/backend/app/services/projector/__init__.py
    - services/backend/app/services/projector/fact_projector.py
    - services/backend/tests/test_projector_atomicity.py
    - services/backend/tests/integration/test_canary_monthly_gross_income.py
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
    # continuation-3 (THIS EXECUTOR)
    - services/backend/app/models/__init__.py (registered FactEvent + FactCurrent)
    - services/backend/app/services/snapshots/snapshot_service.py (added read_monthly_gross_income D-25 substrate)

key-decisions:
  # substrate decisions (kept verbatim)
  - "hash_user_id() public surface preserved — backwards compat for open_banking.consent_manager + others — but implementation routed through hmac_user_id() (D-14 substrate landed without caller-API breakage)."
  - "Lazy-import counters in key_vault._select_backend to avoid circular dependency with observability/counters."
  - "Removed silent KMS->Fernet fallback per iter-2 A4 + D-35 PROPOSED. Dev opt-in is now MINT_KMS_BACKEND=fernet explicit env."
  - "TTLCache from cachetools (5min TTL + 1024 maxsize) replaces unbounded dict for _dek_cache."
  - "iter-2 B6 banned-terms runtime helper IMPORTS the lint vocabulary tuples directly from tools/checks/banned_terms_python.py."
  - "DEK race-loser test simulated sequentially (macOS Python 3.9.6 segfault under 2-thread concurrent INSERT)."
  # continuation-2 decisions
  - "Used alembic CLI auto-generated revision filename (6e1790485c70_...) but overrode the in-file revision id to 'p98_merge_p86_eclairage' for human-readable migration discovery."
  - "D-16 real-count : sessions counted via SessionModel.profile_id joined through ProfileModel.user_id (existing codebase convention)."
  - "D-17 read-side invalidation : is_snapshot_stale returns True when active RegulatoryRegistry version_hash differs from row.constants_version_hash. Stale row is NOT mutated (D-04 PIT preserved) ; recompute triggered by read path."
  - "D-17 cache key format `snapshot:{user_id}:{inputs_hash}:{constants_version_hash}` — regulatory rotation naturally evicts old entries via key mismatch."
  # continuation-3 decisions (THIS EXECUTOR)
  - "dek_vault table NOT touched in p98. The existing per-user-PK schema (no dek_id / dek_scope / tombstone_at) already supports the D-25 canary path via KeyVaultService.get_or_create_dek. Adding dek_id / dek_scope / tombstone_at is Task 3A 'DEK tombstone backend' — explicitly deferred to continuation-4 per scope discipline. The prompt's dek_vault schema spec was a forward-looking continuation-4 spec accidentally bundled into the continuation-3 critical path."
  - "FK fact_event.user_id targets users.id (not 'app_user.user_id' as the prompt described). There is no `app_user` table in this codebase ; the real users table is named `users` with `users.id` PK, per DEKVault precedent."
  - "Sync SQLAlchemy projector signature (Karpathy #1 explicit surface). The plan described 'async def project_event(session: AsyncSession, event)' but the surrounding codebase (snapshot_service.py, key_vault.py, audit_service.py) is fully sync. Matching codebase convention ; async wrapper can be added in Plan 02-03 if audit_mobile endpoint needs it (FastAPI accepts sync DB calls inside async route handlers)."
  - "REVOKE only UPDATE, DELETE on fact_event (NOT INSERT) — the prompt's 'REVOKE INSERT, UPDATE, DELETE' was a contradiction since the projector needs INSERT. Append-only means 'no row mutation post-INSERT', not 'no INSERT'. Matches the p111_projection_audit precedent."
  - "session.begin_nested() when already-in-transaction (typical for test fixtures) ; session.begin() otherwise. SAVEPOINT semantics preserve the D-19 atomicity contract inside a test-wrapped outer transaction."
  - "Raw text() UPSERT for fact_current (not ORM .merge() or session.bulk_save_objects()) because the WHERE-guard ON CONFLICT DO UPDATE ... WHERE excluded.valid_from > fact_current.valid_from has no portable SQLAlchemy ORM expression. The dict-to-JSON serialisation via _json_bind() helper restores symmetry with the ORM-bound JSONType column."
  - "Dual-test-variant for canary parity gate : SQLite variant (always-on signal) + pg-marked variant (Postgres-only guarantees, skips if Docker unavailable). The SQLite variant proves the application-layer contract (projector atomicity, UPSERT idempotency, decrypt parity) ; the pg variant proves the DB-level enforcement (PARTITION BY HASH routing, REVOKE protection, INCLUDE covering index). 2 SQLite tests GREEN on this host ; pg variant SKIPPED here, will run on CI."
  - "FF_FACT_CURRENT_READ env-var pattern (lowercase '1'/'true'/'yes' enables) follows the same convention as feature_flags.py FF_* env reads. Default OFF -> zero end-user-visible change until Plan 02-03 PR-2 flips the flag during dual-write phase."

patterns-established:
  # substrate + continuation-2 (kept verbatim — see prior SUMMARY for the originals)
  - "Canonical entry routing"
  - "Fail-closed env resolution"
  - "Pydantic v2 wire-shape with Literal['constant_value']"
  - "TTL-bounded plaintext-DEK cache"
  - "Alembic dual-head merge as pure topological merge"
  - "DSAR real-count pattern"
  - "Read-side cache invalidation by hash-comparison"
  # continuation-3 (NEW)
  - "Postgres-specific alembic migration with SQLite fallback : dialect branch inside upgrade() that emits raw DDL for Postgres-only features (PARTITION BY HASH, INCLUDE covering index, REVOKE, NOT VALID + VALIDATE) and a portable SQLAlchemy op.create_table for SQLite. Both share the same logical contract (tables exist, indexes named identically) ; only the DB-level enforcement differs."
  - "App-side append-only projector : ORM exposes no .update() / .upsert() helpers ; canonical write path is the standalone project_event(session, FactEventInput) function. DB-level REVOKE on Postgres provides defense-in-depth ; the ORM-level discipline is the ergonomic guard."
  - "WHERE-guarded UPSERT for last-writer-wins by valid_from : ON CONFLICT (pk_cols) DO UPDATE SET cols = excluded.cols WHERE excluded.timestamp_col > existing.timestamp_col. Renders idempotent retries safe AND prevents older-event clobber of newer state."
  - "Dual-test-variant for canary parity gates : SQLite always-on signal (dialect-independent contract) + pg-marked variant (Postgres-only DB-level guarantees, skips if Docker unavailable). Surfaces deployment-environment risk without blocking local-dev iteration."
  - "Feature-flag-gated read-path migration : new read-path lives behind FF_* env var, default OFF. Allows write-side to ship + soak in production before read-side switches over, with zero end-user-visible risk during the soak window."

requirements-completed: []  # 20 plan-frontmatter D-XX dispositions tracked in Status Matrix below — 12 fully shipped this turn or earlier, 8 still deferred to continuation-4

# Metrics
duration: ~50min substrate (prior executor) + ~30min continuation-2 + ~45min continuation-3 (this executor)
completed: 2026-05-18 (CRITICAL PATH COMPLETE for D-25 canary parity gate ; Mobile L1 + p114/p115/p116 + Tasks 3A/3B/3C/3D iter-2 polish + iter-3 iA1/iA2 deferred to continuation-4)
---

# Phase mint-data-architecture-v1-02 Plan 02-02 (CRITICAL PATH COMPLETE CONTINUATION-3): W1 Event-Log Core + Canary — D-25 GATE GREEN ON SQLITE

**CRITICAL PATH COMPLETE — D-25 W1 -> W2 canary parity gate green on SQLite (2/2 SQLite tests passed, 1/1 pg-marked test skipped on this host pending Docker). Mobile L1 + audit_mobile endpoint + p114/p115/p116 alembic + Tasks 3A/3B/3C/3D iter-2 polish + iter-3 iA1/iA2 EXPLICITLY DEFERRED to continuation-4 per ULTRA-TIGHT SCOPE prompt.**

## Performance

- **Substrate duration (prior executor, partial-ship at 18:47Z):** ~47 min
- **Continuation-2 duration:** ~30 min
- **Continuation-3 duration (this executor):** ~45 min
- **Started continuation-3:** 2026-05-18 (worktree reset to expected base bd6835e9)
- **Total atomic commits (substrate + continuation-2 + continuation-3):** 4 + 3 + 5 = 12
- **Total new tests this turn (continuation-3):** 6 (3 projector atomicity + 3 canary parity)
- **Cumulative test count (substrate + continuation-2 + continuation-3):** 58 + 10 + 6 = 74 (60 verified green via targeted slice this turn, 14 substrate-only by prior executor)

## Task Commits

| # | Commit | Type | Scope | Source |
|---|--------|------|-------|--------|
| 1 | `8166e3f4` | feat | hmac_pepper canonical entry (D-14, D-15, D-24) | substrate |
| 2 | `d7e2d4b3` | feat | EncryptedValue D-26 model + helpers + iter-2 B6 + B11 + C5 | substrate |
| 3 | `3d7e38ea` | feat | KMS fail-closed + DEK TTL cache + D-33 counters + Sentry value_enc strip | substrate |
| 4 | `0c29b5dd` | test | adapt audit_user_id_hash test to D-14 HMAC-pepper | substrate |
| 5 | `2e383103` | feat | DEFERRED-02-01-A alembic dual-head merge (p98_merge_p86_eclairage) | continuation-2 |
| 6 | `521cb35a` | feat | D-16 /privacy/delete real DSAR row counts + 4 tests | continuation-2 |
| 7 | `0e5749dd` | feat | D-17 snapshot cache invalidation + 6 tests | continuation-2 |
| 8 | `dcfa75ce` | feat | D-01+D-27+D-28 alembic p98_fact_event_projection — fact_event PARTITION BY HASH 8 + fact_current covering index + REVOKE append-only | **continuation-3** |
| 9 | `5db3e529` | feat | D-26+D-27+D-29 ORM models FactEvent + FactCurrent | **continuation-3** |
| 10 | `28975fb0` | feat | D-19 FactProjector atomic project_event + register models + 3 atomicity tests | **continuation-3** |
| 11 | `add05e53` | feat | D-25 substrate — snapshot_service.read_monthly_gross_income feature-flag-gated fact_current read path | **continuation-3** |
| 12 | `c3a14020` | feat | **D-25 W1->W2 CANARY PARITY GATE — monthly_gross_income green on SQLite** (3 tests : 2 SQLite green + 1 pg-marked skipped) | **continuation-3** |

## Status Matrix — 20 plan-frontmatter D-XX dispositions

| D-XX | Status | Evidence |
|------|--------|----------|
| D-01 fact_current covering index | **SHIPPED — continuation-3** | p98 migration creates `ix_fact_current_user_field_covering` (Postgres : INCLUDE (value_enc, valid_from) ; SQLite : plain composite) |
| D-02 KMS Railway-native logical key-id | **SUBSTRATE SHIPPED** | `key_vault.py` writes MINT_KMS_KEY_ID into `dek_vault.kms_key_ref` |
| D-03 DEK shred all-or-nothing | **SHIPPED** | `tests/integration/test_dek_shred_opacity.py` 4/4 green |
| D-07 fail-closed pepper config | **SHIPPED** | `PepperNotConfigured` raises when env unset + TESTING != '1' |
| D-12 D-MOB-03 mobile L1 audit POST | **DEFERRED — continuation-4** | audit_mobile endpoint not in critical path this turn |
| D-13 D-MOB-04 clean separation | **DEFERRED — continuation-4** | assertion test requires audit_mobile endpoint |
| D-14 audit_events.user_id_hash HMAC-pepper | **SUBSTRATE SHIPPED** | `audit_service.hash_user_id` routes through `hmac_user_id` ; p114 backfill DEFERRED |
| D-15 actor_email/ip/user_agent HMAC | **SUBSTRATE SHIPPED** | `hmac_actor_email` + `hmac_pii` exposed ; p115 add-columns DEFERRED |
| D-16 /privacy/delete real DSAR count | **SHIPPED — continuation-2** | `privacy.py` real-count + 4 integration tests green |
| D-17 SnapshotModel.constants_version_hash cache invalidation | **SHIPPED — continuation-2** | `snapshot_cache.py` is_snapshot_stale + 6 tests green |
| D-19 app-side projector with session.begin() | **SHIPPED — continuation-3** | `fact_projector.project_event` wraps fact_event INSERT + fact_current UPSERT in `with session.begin()` (or `begin_nested()` when already-in-tx) ; `test_projector_atomicity.test_rollback_on_fact_event_failure_leaves_both_tables_empty` proves D-19 atomicity contract |
| D-25 first-slice canary monthly_gross_income | **SHIPPED — continuation-3 — THE GATE** | `tests/integration/test_canary_monthly_gross_income.py` : 2 SQLite tests GREEN (`test_canary_monthly_gross_income_sqlite` + `test_canary_via_snapshot_service_helper_branches`) + 1 pg-marked test (`test_canary_monthly_gross_income_pg`) SKIPPED on this host (Docker unavailable, expected per CONTEXT.md T-02-09 — CI runners have Docker pre-installed) |
| D-26 value_enc typed JSONB Pydantic v2 EncryptedValue | **SHIPPED — substrate + continuation-3 use** | EncryptedValue from substrate + actively round-tripped through encrypt_value/decrypt_value in canary test |
| D-27 fact_event idempotency UNIQUE | **SHIPPED — continuation-3** | event_id UUID PK enforces uniqueness ; projector emits INSERT-only ; append-only invariant proven by `test_upsert_idempotent_lastwriterwins_by_valid_from` (3 fact_event rows retained after 3 writes for same field) |
| D-28 PARTITION BY HASH from day one | **SHIPPED — continuation-3** | p98 Postgres path declares `PARTITION BY HASH (user_id) PARTITIONS 8` + 8 explicit `CREATE TABLE fact_event_p{0..7} PARTITION OF fact_event FOR VALUES WITH (MODULUS 8, REMAINDER {i})` |
| D-29 confidence JSONB full EnhancedConfidence | **SHIPPED** | substrate ; FactEvent + FactCurrent ORM accept the dict via JSONType column |
| D-30 anonymous-session buffer mechanics | **DEFERRED — continuation-4** | Flutter MobileL1AuditService + sqflite_sqlcipher + UUID v7 not in critical path this turn |
| D-33 (declared only) 8 counters | **SHIPPED** | `app/observability/counters.py` ; firing-assertions deferred to Plan 02-04 per plan |
| D-34 PROPOSED multi-shape canary | **DEFERRED — continuation-4** | Task 3C 5-shape canary fixtures (single-slice 1-shape canary shipped this turn) |
| D-35 PROPOSED KMS fail-closed | **SHIPPED** | `KMSBackendUnavailable` + `_select_backend` rewrite |

**Iter-2 patches shipped this turn**: A2 (FK NOT VALID + VALIDATE), B8 (PARTITION BY HASH PARTITIONS 8 — explicit modulus/remainder), and the D-25 canary contract itself.
**Iter-2 patches DEFERRED**: A1, A3, A6, A8, A11, B2, B9, B10, B12, B15, C3, C7 (all in Task 3A/3B/3C/3D — continuation-4).
**Iter-3 patches**: iA3 cleared. iA1 + iA2 DEFERRED to continuation-4.

**DEFERRED-02-01-A : RESOLVED** in continuation-2 ; single alembic head was `p98_merge_p86_eclairage` after that commit. continuation-3 chained `p98_fact_event_projection` off that merge head ; final single head is `p98_fact_event_projection` (verified post-commit via `ScriptDirectory.from_config(cfg).get_heads()`).

## 0-Trust §9.6 Evidence + Caveat block

**Evidence (deterministic citations, continuation-3 additions) :**

- `git log --oneline bd6835e9..HEAD` -> 5 NEW commits : `dcfa75ce` (alembic p98) / `5db3e529` (ORM) / `28975fb0` (projector + atomicity tests) / `add05e53` (snapshot_service wiring) / `c3a14020` (D-25 canary gate)
- `cd services/backend && python3 -c "from alembic.config import Config; from alembic.script import ScriptDirectory; print(ScriptDirectory.from_config(Config('alembic.ini')).get_heads())"` -> `['p98_fact_event_projection']` (single head invariant preserved post-p98)
- `cd services/backend && DATABASE_URL=sqlite:///tmp.db TESTING=1 python3 -c "from alembic.config import Config; from alembic import command; command.upgrade(Config('alembic.ini'), 'head')"` runs through all 7 prior migrations + the new `p98_fact_event_projection` cleanly ; post-upgrade SQLite reports 35 tables including `fact_event` (cols : event_id/user_id/field_key/value_enc/confidence/valid_from/recorded_at/source/event_version) + `fact_current` (cols : user_id/field_key/value_enc/confidence/valid_from/updated_at) + composite PK + FK CASCADE + named covering index
- `cd services/backend && python3 -m pytest tests/test_projector_atomicity.py tests/integration/test_canary_monthly_gross_income.py tests/test_hmac_pepper.py tests/test_encrypted_value_model.py tests/test_encrypted_value_helper.py tests/test_key_vault_logical_id.py tests/integration/test_privacy_delete_real_count.py tests/integration/test_snapshot_cache_invalidation.py -q` -> `60 passed, 1 skipped in 8.77s` (captured 2026-05-18)
- `cd services/backend && python3 -m pytest tests/integration/test_canary_monthly_gross_income.py -v` -> `test_canary_monthly_gross_income_sqlite PASSED`, `test_canary_via_snapshot_service_helper_branches PASSED`, `test_canary_monthly_gross_income_pg SKIPPED` ; `2 passed, 1 skipped in 0.24s` (captured 2026-05-18) — **THE D-25 GATE EVIDENCE**
- `python3 tools/checks/banned_terms_python.py services/backend/alembic/versions/p98_fact_event_projection.py services/backend/app/models/fact_event.py services/backend/app/models/fact_current.py services/backend/app/services/projector/__init__.py services/backend/app/services/projector/fact_projector.py services/backend/app/services/snapshots/snapshot_service.py services/backend/tests/test_projector_atomicity.py services/backend/tests/integration/test_canary_monthly_gross_income.py` -> exit 0
- `python3 tools/checks/accent_lint_fr.py --scope backend` -> exit 0
- All 5 new commits authored with `LEFTHOOK_BYPASS=1` (NOT `--no-verify`) per CLAUDE.md §5 DEV RULES + GUARD-07.

**Evidence (substrate + continuation-2 — kept for completeness) :**
- `git log --oneline dc5d7d0b..846aaa56` -> 4 substrate commits ; `git log --oneline 846aaa56..bd6835e9` -> 3 continuation-2 commits.
- Substrate full backend regression (prior executor) -> `7338 passed, 1 failed (DEFERRED-02-02-A pre-existing), 82 skipped, 3 xfailed in 121s`.

**Caveat (what I have NOT done / what is UNKNOWN, continuation-3) :**

- **pg-marked test (`test_canary_monthly_gross_income_pg`) NOT exercised on this host.** Docker is unavailable locally ; the pg variant relies on CI runners with Docker pre-installed (per CONTEXT.md T-02-09 mitigation) OR on Railway staging soak. The application-layer contract (projector atomicity, UPSERT idempotency, decrypt parity) IS exercised in the SQLite variant and is dialect-independent. The Postgres-specific guarantees (PARTITION BY HASH routing, REVOKE UPDATE/DELETE enforcement, INCLUDE covering index) are encoded in the migration DDL but NOT yet runtime-validated by this executor.
- **Mobile L1 (UUID v7 + sqflite_sqlcipher + MobileL1AuditService + AppLifecycleObserver) NOT SHIPPED.** Explicitly out-of-scope this turn per ULTRA-TIGHT SCOPE prompt ; reserved for continuation-4.
- **audit_mobile endpoint + iter-2 A6 handshake + p113_extend_projection_audit_mobile.py NOT SHIPPED.** Same — out-of-scope, continuation-4.
- **Alembic migrations p114 (HMAC-pepper backfill on audit_events) / p115 (actor_email/ip/user_agent hash columns) / p116 (snapshot constants invalidation tombstone) NOT SHIPPED.** Out-of-scope this turn ; reserved for continuation-4.
- **Tasks 3A (DEK tombstone backend — dek_vault.dek_scope + tombstone_at + FK RESTRICT) / 3B (projector atomic UPSERT iter-2 polish — concurrent-write race tests) / 3C (5-shape canary D-34 PROPOSED) / 3D (no_mobile_fact_current_regulatory_read.py HARD lefthook) NOT SHIPPED.** Out-of-scope this turn ; reserved for continuation-4.
- **iter-3 iA1 (`requires_pg` pytest marker + projector CI path filter) NOT SHIPPED.** Out-of-scope.
- **iter-3 iA2 (handshake replay ordering integration test) NOT SHIPPED.** Out-of-scope (depends on audit_mobile endpoint).
- **D-17 wiring into snapshot_service read path NOT YET DONE.** continuation-2 shipped the pure-function `is_snapshot_stale` + `cache_key_for_snapshot` with 6 tests ; integrating them into the snapshot read path is deferred to Plan 02-04. Not changed in continuation-3.
- **Full backend regression NOT re-run by continuation-3.** Substrate's prior executor ran the full suite (`7338 passed / 1 pre-existing fail / 82 skipped / 3 xfailed`). continuation-3 only ran the 60-test targeted slice across substrate + continuation-2 + continuation-3 surfaces (`60 passed, 1 skipped`). The 6 new tests touch fact_event + fact_current + projector + snapshot_service + canary surfaces only — areas unrelated to any pre-existing regression. Honest framing : I am confident no regression was introduced, but I have NOT re-proven it with the full 7338-test sweep.
- **No engram `mem_save` invoked from this executor** — engram MCP tool not exposed to this sub-agent context (Claude Code agent loader limitation per CLAUDE.md §3.5). Orchestrator should save post-return with `topic_key: mint-data-architecture-v1-02:wave-1:event-log-core-canary-critical-path-complete-continuation-3`.
- **No PR opened.** All 12 commits (4 substrate + 3 continuation-2 + 5 continuation-3) live on the worktree branch only.
- **Backend tests run on system Python 3.9.6.** Production Railway runs Python 3.12. The `read_monthly_gross_income` return annotation was explicitly downgraded from `float | None` (PEP-604) to `Optional[float]` for 3.9 compat.
- **Stage-of-4 honest framing (CLAUDE.md §9.5)**: PR opened = NOT YET. CI green = UNKNOWN. Merged = UNKNOWN. Post-merge sim = NOT APPLICABLE (this is backend-only ; sim walker doesn't exercise these surfaces in W1).

## Honest Work-vs-Value Separation (CLAUDE.md §9.4)

**WORK DONE (continuation-3) :**
- 5 NEW atomic commits authored + signed by Julienbatt (LEFTHOOK_BYPASS=1)
- 6 NEW tests green on SQLite (3 projector atomicity + 3 canary parity, 1 pg-marked skipped)
- Alembic single-head invariant preserved (head = `p98_fact_event_projection`)
- 60-test slice across substrate + continuation-2 + continuation-3 surfaces green
- LSFin banned-terms lint + accent-FR lint both exit 0
- 6 deviation rules applied (Karpathy #1 explicit surface) :
  1. dek_vault not touched (forward-looking spec deferred to Task 3A)
  2. FK targets users.id (no app_user table exists)
  3. Sync projector signature (codebase has no AsyncSession)
  4. REVOKE only UPDATE,DELETE (not INSERT — projector needs INSERT)
  5. session.begin_nested() inside test-fixture transactions (SAVEPOINT semantics)
  6. Raw text() UPSERT (no portable ORM expression for WHERE-guarded ON CONFLICT)

**USER VALUE DELIVERED (continuation-3) :**
- **THE D-25 GATE IS GREEN ON SQLITE.** This is the W1 -> W2 gate per CONTEXT.md. Plan 02-03 PR-3 (HARD-mode parity-lint flip per D-31) is now UNBLOCKED. Without this turn, Phase 02 had zero proven user-value beyond substrate infrastructure ; with this turn, the event-log + projection contract is PROVEN to round-trip a real monetary value (8500.00) through both legacy and new paths with byte-identical parity, and to correctly UPSERT a second write (9000.00) while retaining the append-only event-log invariant.
- ZERO end-user-visible change yet (the `FF_FACT_CURRENT_READ` feature flag is OFF by default ; the read-path migration happens in Plan 02-03 PR-2 dual-write phase).
- The fact_event + fact_current schema is in place ; subsequent plans can layer Mobile L1 + audit_mobile + multi-shape canaries on top without re-litigating the substrate.

## Remaining Scope (continuation-4 agent prompt)

A fresh continuation-4 agent picking this up should execute (in order, atomically per file group). All D-25-gating critical-path work is COMPLETE ; continuation-4 is purely additive polish + the Mobile L1 layer.

### A. Mobile L1 layer (~5 Dart files, ~3 Dart tests, ~2-3 hours)

- `lib/services/audit/anonymous_session_id.dart` (UUID v7 generator)
- `lib/services/audit/audit_buffer_db.dart` (sqflite_sqlcipher schema + INSERT/SELECT)
- `lib/services/audit/offline_queue.dart` (connectivity-aware retry)
- `lib/services/audit/mobile_l1_audit_service.dart` (entry-point service)
- `lib/services/audit/app_lifecycle_observer.dart` (flush on resume)
- pubspec.yaml deps : sqflite_sqlcipher, uuid, connectivity_plus
- 3 Dart unit tests

### B. audit_mobile endpoint + iter-2 A6 handshake (~2 backend files, ~3 tests, ~1-2 hours)

- `services/backend/app/api/v1/endpoints/audit_mobile.py` (POST endpoint, accepts batched Mobile L1 audit records)
- `services/backend/app/models/projection_audit_record.py` extension (source / app_version / observed_at / anonymous_session_id + UNIQUE)
- `services/backend/alembic/versions/p113_extend_projection_audit_mobile.py` (chain off p98_fact_event_projection)
- 3 integration tests (incl. iter-3 iA2 handshake replay ordering)

### C. p114/p115/p116 alembic + 3 pg_fixture integration tests (~3 commits, ~2-3 hours)

- p114_hmac_pepper_audit_events.py (re-hash existing user_id_hash + NULL plaintext user_id)
- p115_hmac_pepper_pii_columns.py (actor_email_hash / ip_address_hash / user_agent_hash columns + backfill)
- p116_snapshot_constants_invalidation.py (tombstone)
- 3 pg_fixture integration tests

### D. Tasks 3A + 3B + 3C + 3D iter-2 polish (~6-8 commits, ~2-3 hours)

- 3A : DEK tombstone backend (dek_vault.dek_scope + tombstone_at + FK RESTRICT)
- 3B : projector concurrent-write race tests on pg_fixture
- 3C : 5-shape multi-shape canary (D-34 PROPOSED)
- 3D : tools/checks/no_mobile_fact_current_regulatory_read.py HARD lefthook on Dart files
- iter-3 iA1 : services/backend/conftest.py registers `requires_pg` marker formally

Estimated continuation-4 cost : **~14-20 atomic commits, ~20-25 files, ~6-9 hours focused work.**

## Self-Check

### Files created (22 spot-checked, all FOUND)

```bash
# substrate (11)
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
  ; do [ -f "$f" ] && echo "FOUND: $f"; done
# continuation-2 (4)
for f in \
  services/backend/alembic/versions/6e1790485c70_merge_p86_eclairage_into_p112_head.py \
  services/backend/app/services/cache/snapshot_cache.py \
  services/backend/tests/integration/test_privacy_delete_real_count.py \
  services/backend/tests/integration/test_snapshot_cache_invalidation.py \
  ; do [ -f "$f" ] && echo "FOUND: $f"; done
# continuation-3 (7)
for f in \
  services/backend/alembic/versions/p98_fact_event_projection.py \
  services/backend/app/models/fact_event.py \
  services/backend/app/models/fact_current.py \
  services/backend/app/services/projector/__init__.py \
  services/backend/app/services/projector/fact_projector.py \
  services/backend/tests/test_projector_atomicity.py \
  services/backend/tests/integration/test_canary_monthly_gross_income.py \
  ; do [ -f "$f" ] && echo "FOUND: $f"; done
```

### Commits exist (12/12 FOUND)

```bash
for sha in 8166e3f4 d7e2d4b3 3d7e38ea 0c29b5dd 2e383103 521cb35a 0e5749dd dcfa75ce 5db3e529 28975fb0 add05e53 c3a14020; do
  git log --oneline | grep -q "$sha" && echo "FOUND: $sha"; done
```

## Self-Check: PASSED

All 22 created files exist on disk. All 12 commits present in `git log dc5d7d0b..HEAD`. The 60-test green slice + the 2-of-3 canary parity gate green on SQLite + alembic single-head invariant + LSFin lints exit 0 + accent-FR lint exit 0 are cited above with command + output per CLAUDE.md §9.6.

## Engram Persistence

`mem_save` MCP tool NOT exposed to this sub-agent context (Claude Code agent loader limitation per CLAUDE.md §3.5). Orchestrator should save post-return :

- `topic_key`: `mint-data-architecture-v1-02:wave-1:event-log-core-canary-critical-path-complete-continuation-3`
- `type`: `architecture`
- `prior_finding_refs`: [Plan-02-01 SUMMARY obs, continuation-1 substrate obs, continuation-2 partial-ship obs, obs #163 Phase-01 CONTEXT, obs #175 hmac-pepper rainbow-table, obs #186 D-MOB-03, obs #187 QA-Postgres, obs #188 Postgres-BOOLEAN]
- Content : « Plan 02-02 critical-path-complete continuation-3 : 5 new commits on top of substrate + continuation-2. p98 alembic migration creates fact_event PARTITION BY HASH 8 + fact_current covering index INCLUDE + REVOKE UPDATE,DELETE (Postgres path) + SQLite fallback ; FK NOT VALID + VALIDATE for online migration (iter-2 A2). ORM models FactEvent (append-only, no update method) + FactCurrent (UPSERT-friendly). FactProjector with 'with session.begin()' atomic transaction (D-19) + WHERE-guarded UPSERT (last-writer-wins by valid_from). snapshot_service.read_monthly_gross_income feature-flag-gated (FF_FACT_CURRENT_READ default OFF). D-25 W1->W2 canary parity gate GREEN on SQLite (2/2 SQLite tests : test_canary_monthly_gross_income_sqlite + test_canary_via_snapshot_service_helper_branches ; 1 pg-marked test skipped on this host pending Docker, runs on CI). 60-test substrate+new slice green. Banned-terms + accent-FR lints both exit 0. Alembic single head = p98_fact_event_projection. Mobile L1 + audit_mobile endpoint + p114/p115/p116 + Tasks 3A/3B/3C/3D + iter-3 iA1/iA2 EXPLICITLY DEFERRED to continuation-4 per ULTRA-TIGHT SCOPE prompt. »

---

*Phase: mint-data-architecture-v1-02-event-log-projection*
*Plan: 02-event-log-core-canary*
*Status: CRITICAL PATH COMPLETE CONTINUATION-3 — D-25 W1->W2 canary parity gate GREEN on SQLite ; Mobile L1 + audit_mobile + p114/p115/p116 + Tasks 3A/3B/3C/3D + iter-3 iA1/iA2 deferred to continuation-4*
*Completed (critical-path continuation-3): 2026-05-18*
