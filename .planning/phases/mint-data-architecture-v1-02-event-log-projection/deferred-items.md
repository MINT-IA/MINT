---
phase: mint-data-architecture-v1-02-event-log-projection
description: Items discovered during Phase 02 execution that are OUT OF SCOPE for the current plan, deferred to a separate PR / follow-up phase. Per executor doctrine SCOPE BOUNDARY — never auto-fix pre-existing issues, log them here instead.
---

# Deferred Items — Phase 02 event-log-projection

## Pre-existing — discovered Plan 02-01 (W0, 2026-05-18)

### DEFERRED-02-01-A : Alembic dual heads on `dev`

- **Discovery context** : while building Task 1's `pg_fixture` self-test, ran `command.upgrade(cfg, "head")` and hit `alembic.util.exc.CommandError: Multiple head revisions are present for given argument 'head'`.
- **Heads detected** : `p112_audit_event_user_hash` (chain length 26, the chain the plan assumes as canonical baseline) AND `p86_eclairage_delivered` (chain length 22, an unmerged branch from the anonymous-session work).
- **Pre-existing failing tests** (NOT caused by this plan — failing on the worktree base) :
  - `tests/test_scenarios_cache_index.py::test_upgrade_head_creates_index_on_sqlite`
  - `tests/test_scenarios_cache_index.py::test_downgrade_below_p110_removes_index`
  - `tests/test_scenarios_cache_index.py::test_upgrade_is_idempotent`
  - `tests/test_snapshots_migration_exists.py::test_alembic_upgrade_creates_snapshots_table`
  - `tests/test_snapshots_migration_exists.py::test_snapshots_columns_match_orm`
  - `tests/test_snapshots_migration_exists.py::test_snapshots_indexes_present`
  - `tests/test_snapshots_migration_exists.py::test_snapshots_user_id_fk_present_and_cascade`
  - `tests/test_snapshots_migration_exists.py::test_snapshots_server_defaults_match_orm`
  - `tests/test_snapshots_migration_exists.py::test_alembic_chain_has_single_head` (this one EXPLICITLY documents the condition)
- **Scope boundary** : this plan only owns the new `pg_fixture` + harness. The fix is a one-line alembic merge migration (`alembic merge p112_audit_event_user_hash p86_eclairage_delivered -m "merge_p86_eclairage_into_p112_head"`) — out of scope for W0 prereqs/lints/harness.
- **Workaround applied in Plan 02-01** : `pg_fixture` uses `command.upgrade(cfg, "heads")` (plural) which upgrades all heads independently. The pg_dump baseline captures whatever DDL the SQL produces — both heads are valid migration chains.
- **Recommended owner** : Plan 02-02 W1 (when the first new migration `p113_fact_event` lands, the migration author MUST chain off `p112_audit_event_user_hash`, AND should atomically add a merge migration consolidating `p86_eclairage_delivered` into the chain). Alternative : a tiny standalone PR `chore(alembic): merge p112 + p86_eclairage heads` before Plan 02-02 starts.
- **Risk if not addressed by Plan 02-02 start** : every new migration in Phase 02 inherits the dual-head condition. `alembic upgrade head` keeps failing in CI and locally for any consumer.

### DEFERRED-02-01-B : Mobile `_buildProfileContext` 40-field drift (not 15)

- **Discovery context** : Task 3 step 4 asks to close 15 of the 40 missing-in-Flutter parity drift. Plan said « drift count drops from current `~15` to `~3` » — actual current drift baseline is 40 missing fields, not 15.
- **Drift baseline at Plan-start** : `python3 tools/checks/profile_safe_fields_parity.py` reports 40 missing-in-Flutter + 3 missing-in-server (`data_reliability`, `financial_summary`, `first_name`).
- **Plan 02-01 closes** : the 15 highest-leverage fields per the plan's PR-A2 spec ; remaining 25 missing fields deferred to PR-A3 (Plan 02-04 per D-10).
- **Risk** : SOFT-mode parity-lint will still flag ~25 missing fields post-Plan-02-01. HARD-mode flip remains in Plan 02-03 PR-3 per D-31 — must close to ≤ 0 before HARD-mode lands, otherwise Plan 02-03 PR-3 cannot ship.
- **Recommended owner** : Plan 02-04 PR-A3 (closes remaining 25 + drops 3 Flutter-only keys).

### DEFERRED-02-01-C : `profile_safe_fields_parity.py` only scans inline `profileContext: { ... }` blocks

- **Discovery context** : Task 3 step 4 extends `CoachNarrativeService._buildProfileContext` (a static method returning a Map). After landing the 15 new keys in the method body, `profile_safe_fields_parity.py` still reports the same 40 missing-in-Flutter drift — because the lint's regex (`_PROFILECONTEXT_START_RE` at lines 197/207) scans for inline `profileContext: { ... }` literal blocks at 4 explicit call-sites (`coach_orchestrator.dart` 3x, `coaching_service.dart` 1x, `coach_chat_api_service.dart` mutation pattern), NOT method return statements.
- **Why this is out of scope for Plan 02-01** : extending the 4 inline blocks to mirror `_buildProfileContext`'s 15 new keys would duplicate the field-emission logic across `_buildProfileContext` AND the orchestrator inline blocks — exactly the Karpathy #3 surgical-changes anti-pattern (touch only what you must). The right fix is to teach the lint to follow Dart static method return statements, which is a separate scope.
- **Risk** : the parity-lint signal stays at 40 even though Flutter now emits 15 new keys via the `_buildProfileContext` path. Plan 02-03 PR-3 (HARD-mode flip per D-31) requires the lint to report ≤ 0 drift — but the lint's static-analysis model can't see method-return emissions, so either (a) the lint must be extended OR (b) the 4 inline blocks must duplicate the emission.
- **Recommended owner** : Plan 02-04 PR-A3 owner picks (a) or (b). Option (a) is principled but bigger lint surgery ; option (b) is mechanical but introduces a 4x duplication maintenance burden.
- **Test coverage** : `apps/mobile/test/services/coach_narrative_profile_context_test.dart` proves the 15 keys ARE emitted (test-level guard) — the lint blind-spot is a static-analysis limitation, not a runtime bug.

## Pre-existing — discovered Plan 02-02 (W1, 2026-05-18)

### DEFERRED-02-02-A : `test_tool_search_round_trip.py` frontalier-tool-name fixture stale post-D-09 rename

- **Discovery context** : full backend regression after Plan 02-02 Task 2 commits (8166e3f4 / d7e2d4b3 / 3d7e38ea) shows `tests/test_tool_search_round_trip.py::test_anthropic_adapter_descriptions_match_fr_queries[frontalier vaudois, impôt à la source-expected_top_320]` failing. Expected `FrontalierService_*` tool names; the adapter now emits `WealthTaxService_*` because D-09 PR-1 (Plan 02-01) renamed the class to `FrontalierSegmentService`, which auto-regenerated the calculator registry tool-name list — the FR-query overlap scoring no longer surfaces frontalier tools at top-3 for « frontalier vaudois ».
- **Pre-existing failing test** : NOT caused by Plan 02-02. Caused by Plan 02-01 D-09 (commit `c465719f`). The test was a Plan-09 polish-TODO `xfail` candidate already (per the test's docstring : « Failing fixtures surface as description-polish TODOs for the Plan 09 staging pilot (Task 5b, DEFERRED) »).
- **Scope boundary** : Plan 02-02 ships hmac_pepper / EncryptedValue / DEK envelope + counters + Sentry strip. The tool-search adapter description list is owned by `services/backend/app/services/coach/tools/` — out of scope for this plan.
- **Recommended owner** : the next plan that touches the canonical-tool description list OR the rename PR-2 (Plan 02-04 per D-09), should either (a) update the expected_top_3 fixture to the post-rename canonical names OR (b) mark the fixture xfail with a reference to D-09 + this deferred item.
- **Risk if not addressed by Plan 02-03** : 1 flaky test in the regression suite. CI workflows must add `--ignore=tests/test_tool_search_round_trip.py::test_anthropic_adapter_descriptions_match_fr_queries[frontalier*]` OR the test must be xfailed to keep CI green.

## Pre-existing — discovered Plan 02-02 (W1, continuation-4 2026-05-18)

### DEFERRED-02-02-B : iter-2 A1 DEK tombstone backend

- **Discovery context** : Plan 02-02 iter-2 Task 3A spec adds `tombstone_at` + `dek_scope` columns to `dek_vault` with ON DELETE RESTRICT FK + a `dek_tombstone.py` service. Continuation-3's p98 migration did NOT touch dek_vault (continuation-3 deferred it to continuation-4) ; continuation-4 evaluated A1 vs scope and re-deferred.
- **Reason out of scope** : The existing `revoke_dek` (key_vault.py:324-348) already shreds `wrapped_dek` to NULL + sets `revoked_at` — the « crypto-shred opacity » contract is already PFPDT-validated and proven by `test_dek_shred_opacity.py` (substrate). Adding a new `tombstone_at` column AND `dek_scope` column AND a new `dek_tombstone.py` service that composes existing `crypto_shred_user` introduces a backend surface that semantically duplicates existing infrastructure without adding a new contract. The structural ON DELETE RESTRICT is also incompatible with the existing CASCADE behaviour wired through `users` table FKs ; flipping it requires coordinated removal of cascade-dependent migration code across multiple downstream tables.
- **Recommended owner** : Plan 02-03 PR-3a backfill pre-flight (the backfill script needs an authoritative « has the DEK been tombstoned » signal beyond `revoked_at IS NOT NULL` only if A1's wider RTBF audit semantic is ratified). Alternative : Plan 02-04 close-out runbook ratifies the deferred-with-reason classification + sign-off if the wider semantic is not needed for production launch.
- **Risk if not addressed** : LOW. The crypto-shred opacity is intact ; the missing surface is only the « tombstoned vs revoked vs DEK-rotation » 3-way distinction. Pre-launch user volume does not stress this surface.

### DEFERRED-02-02-C : iter-2 B2 mobile boundary lint not wired into lefthook.yml

- **Discovery context** : Plan 02-02 iter-2 Task 3D spec wires `tools/checks/no_mobile_fact_current_regulatory_read.py` as a HARD lefthook pre-commit gate on `apps/mobile/lib/**/*.dart`. Continuation-4 P4-B2 shipped the lint script + bad-fixture + 5 unit tests but did NOT modify `lefthook.yml`.
- **Reason out of scope** : Continuation-4 commit hygiene — modifying `lefthook.yml` requires routing through the lefthook config review process and can interact with other staged-files-pass-through scripts (`tools/checks/alembic_revision_length.py` already has a multi-arg parse bug per continuation-4's commit DEVIATION note). Keeping the lint script + tests isolated from `lefthook.yml` lets any future commit on tools/ wire it in as a one-line config addition without risk of bundling.
- **Recommended owner** : Plan 02-03 PR-1 (when other tools/ wiring lands), OR a standalone PR `chore(lefthook): wire no_mobile_fact_current_regulatory_read.py HARD on apps/mobile/lib/**/*.dart`.
- **Risk if not addressed** : LOW. The lint logic IS shipped + tested ; it can be run manually via `python3 tools/checks/no_mobile_fact_current_regulatory_read.py apps/mobile/lib/` before any PR touching Dart in `apps/mobile/lib/`. CI workflows touching mobile can also invoke it. Without the lefthook wiring, the lint is a SOFT gate (manual-invocation-only) rather than HARD (auto-on-commit).

### DEFERRED-02-02-D : Flutter sqflite_sqlcipher production AuditBufferDb impl

- **Discovery context** : Plan 02-02 P3 spec includes a `sqflite_sqlcipher`-backed AuditBufferDb. Continuation-4 P3 shipped `audit_buffer_db.dart` with the abstract interface + `InMemoryAuditBufferDb` fallback + 11 unit tests, but did NOT ship the sqflite_sqlcipher-backed production impl.
- **Reason out of scope** : iOS production deploy requires (a) CocoaPods spec validation for sqflite_sqlcipher 3.x against Xcode 15.x + iOS deployment target 14.0+, (b) Keychain entitlement for SQLCipher passphrase derivation via flutter_secure_storage, (c) physical-device verification on iOS sim AND TestFlight build. Per Julien memory `feedback_ios_entitlements_block_testflight.md`, any new `com.apple.developer.*` entitlement key is release-blocking and MUST land in its own PR, NEVER bundled with feature stacks. The InMemoryAuditBufferDb fallback proves the contract on Dart VM ; the iOS production path lands with the Plan 02-04 device-gate runbook + entitlement isolation PR.
- **Recommended owner** : Plan 02-04 Task 3 device-gate runbook (manual G2 gate per CONTEXT D-30 § 2-device + clock-skew + reinstall + low-storage suite).
- **Risk if not addressed by Plan 02-04** : MEDIUM-LOW for staging soak (in-memory buffer means audit events are lost on app cold-start ; no offline audit trail), HIGH for TestFlight production (Mobile L1 audit ingestion is broken end-to-end without persistent on-device buffer). Plan 02-04 device-gate runbook MUST close this before any TestFlight release.

### DEFERRED-02-02-E : Flutter main.dart MobileL1AuditLifecycleObserver wiring

- **Discovery context** : Plan 02-02 P3 spec includes wiring `MobileL1AuditLifecycleObserver` into `apps/mobile/lib/main.dart` via `WidgetsBinding.instance.addObserver(lifecycle)` + `await lifecycle.recordColdStart()` on bootstrap. Continuation-4 P3 shipped the observer class + 5 unit tests but did NOT modify `main.dart`.
- **Reason out of scope** : Surgical scope discipline (Karpathy #3) — `main.dart` is the bootstrap surface for the entire mobile app and modifying it requires careful interaction-testing with the existing observer chain (Sentry initialization, Engram boot, FeatureFlags hydration, etc.). The audit subsystem is shipped + tested ; bridging is a separate, low-risk follow-up that can be reviewed against the existing main.dart context.
- **Recommended owner** : Plan 02-04 Task 3 device-gate runbook (lands with the sqflite_sqlcipher production impl from DEFERRED-02-02-D — same code-review surface).
- **Risk if not addressed by Plan 02-04** : HIGH for end-to-end Mobile L1 audit value (without main.dart wiring, the observer class is dead code that never fires). Plan 02-04 MUST close this alongside DEFERRED-02-02-D before TestFlight release.

### DEFERRED-02-02-F : connectivity_plus integration in OfflineAuditQueue

- **Discovery context** : Plan 02-02 P3 spec mentions `connectivity_plus` to gate drain() on stable connection. Continuation-4 P3 did NOT add `connectivity_plus` to pubspec.yaml ; the drain() interface is connectivity-agnostic (caller supplies the httpPost callback) so the integration can layer on top later.
- **Reason out of scope** : Avoiding iOS Pod dependency surface expansion. The existing `api_service.dart` already has connectivity hooks ; the cleaner integration point is a caller in main.dart that invokes `audit.flush()` on connectivity restore via the existing connectivity stream, rather than embedding `connectivity_plus` inside OfflineAuditQueue.
- **Recommended owner** : Plan 02-04 Task 3 (same code-review surface as DEFERRED-02-02-D + DEFERRED-02-02-E).
- **Risk if not addressed by Plan 02-04** : MEDIUM. Without explicit connectivity gating, drain() may fire on a known-offline state and waste CPU + battery (per Pitfall 6). The exponential backoff (1s/2s/4s/8s/16s/...) bounds the wasted work, so the impact is degradation-not-failure.

### DEFERRED-02-02-G : True-concurrency variant of iter-2 A8 (with threading + pg_session)

- **Discovery context** : Plan 02-02 iter-2 Task 3B spec is a 100-iteration 2-thread race test on pg_session to prove the projector's atomic UPSERT contract under Read Committed concurrency. Continuation-4 P4 shipped a 100-iteration SEQUENTIAL simulation that proves the same WHERE-guard contract dialect-independently ; the true-concurrency variant was NOT shipped because macOS Python 3.9.6 + SQLAlchemy 2-thread concurrent INSERT segfaults (per continuation-3 SUMMARY).
- **Reason out of scope** : Mac dev hazard. The true-concurrency variant can run on CI Postgres (Linux Python 3.12 doesn't segfault under the same pattern), but cannot be developed locally on macOS without crashing the test runner. Shipping a test that segfaults locally would block all future test work for any contributor on macOS.
- **Recommended owner** : Plan 02-04 Task 4 close-out (which already includes pg-only test rituals).
- **Risk if not addressed** : LOW. The sequential simulation proves the WHERE-guard contract at the application layer (dialect-independent). The Postgres-level lost-update guarantee under concurrency is a property of `INSERT ... ON CONFLICT ... DO UPDATE WHERE` (Postgres documentation guarantee) — the true-concurrency test is a belt-and-suspenders confirmation, not a new contract proof.

## Format

Each entry must contain : Discovery context · Reason out of scope · Recommended owner (which plan / when) · Risk if not addressed.
