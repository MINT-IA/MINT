---
phase: quick-260406-gja
plan: "01"
subsystem: navigation
tags: [routing, onboarding, gorouter, fix]
dependency_graph:
  requires: []
  provides: ["/onboarding/intent route", "/onboarding/promise route"]
  affects: [navigation_route_integrity_test]
tech_stack:
  added: []
  patterns: ["GoRoute with parentNavigatorKey pattern"]
key_files:
  created: []
  modified:
    - apps/mobile/lib/app.dart
decisions:
  - "Both screens use const constructors — no parameter adaptation needed"
  - "Routes placed in ONBOARDING section after /onboarding/chiffre-choc, consistent with existing pattern"
metrics:
  duration: "~5 minutes"
  completed: "2026-04-06"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 1
---

# Phase quick-260406-gja Plan 01: Register Onboarding Routes Summary

**One-liner:** Added GoRouter entries for `/onboarding/intent` → `IntentScreen` and `/onboarding/promise` → `PromiseScreen` to fix 10 broken route references detected by `navigation_route_integrity_test`.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add /onboarding/intent and /onboarding/promise GoRoute entries | cd0dbee7 | apps/mobile/lib/app.dart |

## Verification Results

- `flutter test test/navigation_route_integrity_test.dart`: **PASSED** — 0 broken routes (was 10 before fix)
- `flutter analyze lib/app.dart`: **PASSED** — 0 errors

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — no new trust boundaries. Routes point to read-only onboarding screens with no auth-gated data.

## Self-Check: PASSED

- [x] `apps/mobile/lib/app.dart` modified with 2 new imports and 2 new GoRoute entries
- [x] Commit `cd0dbee7` exists: `feat(quick-260406-gja): register /onboarding/intent and /onboarding/promise GoRouter routes`
- [x] `navigation_route_integrity_test` passes (1 test, all passed)
- [x] `flutter analyze` reports no issues
