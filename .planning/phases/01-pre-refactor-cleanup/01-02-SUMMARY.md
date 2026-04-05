---
phase: 01-pre-refactor-cleanup
plan: 02
subsystem: navigation/routing
tags: [cleanup, dead-code, routing, screens]
dependency_graph:
  requires: []
  provides: [clean-route-table, dead-screens-removed]
  affects: [apps/mobile/lib/app.dart, apps/mobile/lib/screens, apps/mobile/test]
tech_stack:
  added: [apps/mobile/lib/services/navigation_shell_state.dart]
  patterns: [NavigationShellState extracted to services/]
key_files:
  created:
    - apps/mobile/lib/services/navigation_shell_state.dart
  modified:
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/screens/main_navigation_shell.dart
    - apps/mobile/lib/widgets/pulse/cap_card.dart
    - apps/mobile/test/screens/core_app_screens_smoke_test.dart
  deleted:
    - apps/mobile/lib/screens/ask_mint_screen.dart
    - apps/mobile/lib/screens/coach/annual_refresh_screen.dart
    - apps/mobile/lib/screens/coach/coach_checkin_screen.dart
    - apps/mobile/lib/screens/coach/cockpit_detail_screen.dart
    - apps/mobile/lib/screens/tools_library_screen.dart
    - apps/mobile/lib/screens/pulse/pulse_screen.dart
    - apps/mobile/lib/screens/onboarding/smart_onboarding_screen.dart
    - apps/mobile/lib/screens/onboarding/smart_onboarding_viewmodel.dart
    - apps/mobile/lib/screens/onboarding/steps/step_chiffre_choc.dart
    - apps/mobile/lib/screens/onboarding/steps/step_jit_explanation.dart
    - apps/mobile/lib/screens/onboarding/steps/step_next_step.dart
    - apps/mobile/lib/screens/onboarding/steps/step_ocr_upload.dart
    - apps/mobile/lib/screens/onboarding/steps/step_questions.dart
    - apps/mobile/lib/screens/onboarding/steps/step_stress_selector.dart
    - apps/mobile/lib/screens/onboarding/steps/step_top_actions.dart
    - apps/mobile/test/screens/coach/coach_checkin_test.dart
    - apps/mobile/test/screens/pulse/pulse_screen_test.dart
    - apps/mobile/test/screens/tools_library_test.dart
decisions:
  - "budget_screen.dart preserved: plan research was incorrect — it IS imported by budget_container_screen.dart as live child screen"
  - "NavigationShellState extracted from pulse_screen.dart to services/navigation_shell_state.dart before deletion"
  - "Wire Spec V2 P4 redirects all preserved: /ask-mint, /tools, /coach/cockpit, /coach/checkin, /coach/refresh, /onboarding/smart, /advisor"
metrics:
  duration: "~7 minutes"
  completed_date: "2026-04-05"
  tasks: 2
  files_changed: 22
  lines_deleted: ~11696
  screens_deleted: 15
  test_files_deleted: 3
---

# Phase 01 Plan 02: Route Audit and Dead Screen Deletion Summary

Dead route and screen cleanup that eliminates 15 unreachable screen files and fixes the stale 4-tabs shell comment, leaving every screen in screens/ reachable and every GoRoute in app.dart intentional.

## What Was Done

### Task 1: Route Table Audit and Stale Comment Fix

Audited all GoRoute entries in `app.dart` (L161-974). Every route classified as:
- **live**: builder pointing to existing file (majority of routes)
- **redirected**: Wire Spec V2 P4 archived routes forwarding to shell tabs

Fixed stale comment at L245:
- Before: `// -- Main Shell (4 tabs: Aujourd'hui, Coach, Explorer, Dossier) --`
- After: `// -- Main Shell (3 tabs: Aujourd'hui, Coach, Explorer + ProfileDrawer) --`

All 7 Wire Spec V2 redirects confirmed present:
- `/ask-mint` -> `/home?tab=1`
- `/tools` -> `/home?tab=2`
- `/coach/cockpit` -> `/home?tab=0`
- `/coach/checkin` -> `/home?tab=1`
- `/coach/refresh` -> `/home?tab=0`
- `/onboarding/smart` -> `/onboarding/intent`
- `/advisor` -> `/onboarding/intent`

### Task 2: Dead Screen Deletion and Test Updates

Deleted 15 dead screen files across 4 categories:

**Category C (archived routes with redirects):**
- `ask_mint_screen.dart` — route /ask-mint redirects to /home?tab=1 since S52
- `coach/annual_refresh_screen.dart` — 0 importers
- `coach/coach_checkin_screen.dart` — route /coach/checkin redirects to /home?tab=1
- `coach/cockpit_detail_screen.dart` — 0 importers
- `tools_library_screen.dart` — route /tools redirects to /home?tab=2

**Category D (replaced screen):**
- `pulse/pulse_screen.dart` — 1665 lines, replaced by MintHomeScreen. Required NavigationShellState extraction before deletion.

**Category B (smart onboarding cascade, 9 files):**
- `onboarding/smart_onboarding_screen.dart` + `smart_onboarding_viewmodel.dart`
- 7 step files in `onboarding/steps/`: step_chiffre_choc, step_jit_explanation, step_next_step, step_ocr_upload, step_questions, step_stress_selector, step_top_actions

**Directories removed:** `onboarding/steps/` and `pulse/` (both now empty)

**Test file updates:**
- `core_app_screens_smoke_test.dart`: removed AskMintScreen import + 4 test cases (renders, title, configure CTA, privacy note)
- Deleted `test/screens/coach/coach_checkin_test.dart`
- Deleted `test/screens/pulse/pulse_screen_test.dart`
- Deleted `test/screens/tools_library_test.dart`

## Verification Results

- `flutter analyze --no-pub`: No issues found!
- `flutter test --no-pub`: 8115 tests passed (note: reduced from 8137 due to deleted test files)
- Zero imports referencing deleted screen files remain in lib/
- All 7 Wire Spec V2 redirects present in app.dart
- Stale 4-tabs comment replaced with 3-tabs

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] NavigationShellState class embedded in pulse_screen.dart**
- **Found during:** Task 2, pre-deletion check
- **Issue:** `pulse_screen.dart` contained `NavigationShellState` class (L1650-1665) used by `main_navigation_shell.dart` and `cap_card.dart`. Deleting the file would break navigation tab switching.
- **Fix:** Extracted `NavigationShellState` to `apps/mobile/lib/services/navigation_shell_state.dart`. Updated imports in both consumers.
- **Files modified:** `main_navigation_shell.dart`, `cap_card.dart`; created `services/navigation_shell_state.dart`
- **Commit:** ff37c4c8

**2. [Rule 1 - Bug] Plan research incorrect: budget_screen.dart is LIVE**
- **Found during:** Task 2, post-deletion flutter analyze
- **Issue:** Plan (D-09) classified `budget_screen.dart` as dead with "0 importers, replaced by budget_container_screen.dart". In fact, `budget_container_screen.dart` IMPORTS and WRAPS `budget_screen.dart` — it IS the live implementation.
- **Fix:** Restored `budget_screen.dart` from git. NOT deleted.
- **Impact:** Plan said "~15 dead screen files" — actual count is 15 (budget_screen.dart not counted as one of the dead files after correction)
- **Files modified:** `apps/mobile/lib/screens/budget/budget_screen.dart` (restored)

## Known Stubs

None — this plan only deletes files and fixes a comment. No new UI or data-binding code introduced.

## Threat Flags

None — only deletions and a comment fix. No new network endpoints, auth paths, file access patterns, or schema changes.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | eb6d0be9 | chore(01-02): fix stale 4-tabs comment in app.dart |
| Task 2 | ff37c4c8 | chore(01-02): delete dead screen files and update test references |

## Self-Check: PASSED

All files listed as deleted confirmed absent. NavigationShellState file confirmed created. flutter analyze: 0 errors. flutter test: 8115 passed.
