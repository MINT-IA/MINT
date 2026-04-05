---
phase: 01-pre-refactor-cleanup
plan: 03
subsystem: mobile/services
tags: [cleanup, duplicate-deletion, test-fix, cln-01]
dependency_graph:
  requires: [01-01, 01-02]
  provides: [CLN-01-complete]
  affects: [apps/mobile/lib/services/gamification, apps/mobile/lib/services/memory, apps/mobile/test/services]
tech_stack:
  added: []
  patterns: [single-canonical-import-path]
key_files:
  created: []
  modified:
    - apps/mobile/test/services/memory/goal_tracker_service_test.dart
  deleted:
    - apps/mobile/lib/services/gamification/community_challenge_service.dart
    - apps/mobile/lib/services/memory/goal_tracker_service.dart
    - apps/mobile/test/services/gamification/community_challenge_service_test.dart
decisions:
  - Delete duplicate gamification test rather than fix it because canonical test at test/services/community_challenge_service_test.dart already covers the service
  - Update memory test import to coach/ path (not delete) because the test exercises valid behavior against the canonical service
metrics:
  duration: 403s
  completed: 2026-04-05T14:11:23Z
  tasks_completed: 1
  files_changed: 4
requirements_satisfied:
  - CLN-01
---

# Phase 01 Plan 03: Gap Closure — Remaining Duplicate Service Deletions Summary

**One-liner:** Deleted 301-line gamification duplicate and 21-line memory re-export shim; fixed memory test import to coach/ path; CLN-01 now fully satisfied with zero non-canonical import paths.

## What Was Done

Closed the 2 remaining gaps from the CLN-01 duplicate service resolution (the previous executor plan 01-01 had missed these). Both non-canonical service files had 0 lib/ importers but still had test files importing them via non-canonical paths, which would cause build failures.

### File Operations

| Operation | File | Reason |
|-----------|------|--------|
| DELETE | `lib/services/gamification/community_challenge_service.dart` | 301-line duplicate of canonical `lib/services/coach/community_challenge_service.dart` (536 lines). Zero lib/ importers. |
| DELETE | `lib/services/memory/goal_tracker_service.dart` | 21-line re-export shim redirecting to `coach/goal_tracker_service.dart`. Zero lib/ importers. |
| DELETE | `test/services/gamification/community_challenge_service_test.dart` | Test for deleted file. Canonical test at `test/services/community_challenge_service_test.dart` already covers the service with imports from `coach/`. |
| UPDATE | `test/services/memory/goal_tracker_service_test.dart` | Changed line 3 import from `services/memory/goal_tracker_service.dart` to `services/coach/goal_tracker_service.dart`. Test logic unchanged — exercises the same classes. |

## Verification Results

All 6 verification checks from the plan passed:

1. `test ! -f lib/services/gamification/community_challenge_service.dart` — PASS
2. `test ! -f lib/services/memory/goal_tracker_service.dart` — PASS
3. `test ! -f test/services/gamification/community_challenge_service_test.dart` — PASS
4. Import updated to `services/coach/goal_tracker_service.dart` — PASS
5. `flutter analyze --no-pub`: No issues found — PASS
6. `flutter test test/services/memory/goal_tracker_service_test.dart`: 12/12 tests passed — PASS

## Decisions Made

1. **Delete gamification test, not update it**: The canonical community challenge service test at `test/services/community_challenge_service_test.dart` already imports from `coach/` and provides complete coverage. Keeping a second test file with an import pointing to the deleted `gamification/` service would not be useful — deletion is the correct action.

2. **Update memory test, not delete it**: The `test/services/memory/goal_tracker_service_test.dart` contains 10 unique tests (set/get, completion, history, remove, JSON roundtrip, summary) that exercise behavior in the canonical service. The import path was the only problem. Updating it preserves test coverage.

## Deviations from Plan

None — plan executed exactly as written.

## CLN-01 Final Status

All 3 duplicate service pairs are now fully resolved:

| Service Pair | Plan | Status |
|-------------|------|--------|
| `coach/community_challenge_service.dart` vs `gamification/community_challenge_service.dart` | 01-01 (partial) + 01-03 | DONE |
| `coach/goal_tracker_service.dart` vs `memory/goal_tracker_service.dart` | 01-03 | DONE |
| (third pair from 01-01) | 01-01 | DONE |

Zero non-canonical import paths remain anywhere in `apps/mobile/lib/` or `apps/mobile/test/`.

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | `c373543b` | chore(01-03): delete non-canonical service copies and fix test imports |

## Known Stubs

None — this plan only deletes files and updates an import path.

## Threat Flags

None — pure file deletion and import path update. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `apps/mobile/lib/services/gamification/community_challenge_service.dart` — ABSENT (confirmed)
- `apps/mobile/lib/services/memory/goal_tracker_service.dart` — ABSENT (confirmed)
- `apps/mobile/test/services/gamification/community_challenge_service_test.dart` — ABSENT (confirmed)
- `apps/mobile/test/services/memory/goal_tracker_service_test.dart` line 3 — imports `coach/goal_tracker_service.dart` (confirmed)
- Commit `c373543b` — EXISTS on branch `worktree-agent-ab9028e7`
