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

## Format

Each entry must contain : Discovery context · Reason out of scope · Recommended owner (which plan / when) · Risk if not addressed.
