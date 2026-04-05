---
phase: 03-onboarding-pipeline
plan: 01
subsystem: onboarding-routing
tags: [intent-router, persistence, onboarding, premier-eclairage, tdd]
dependency_graph:
  requires: []
  provides:
    - IntentRouter.forChipKey(chipKey) → IntentMapping (goalIntentTag, stressType, suggestedRoute, lifeEventFamily)
    - ReportPersistenceService.savePremierEclairageSnapshot()
    - ReportPersistenceService.loadPremierEclairageSnapshot()
    - ReportPersistenceService.hasSeenPremierEclairage()
    - ReportPersistenceService.markPremierEclairageSeen()
  affects:
    - apps/mobile/lib/screens/onboarding/intent_screen.dart (plan 02 consumer)
    - apps/mobile/lib/widgets/home/premier_eclairage_card.dart (plan 03 consumer)
tech_stack:
  added: []
  patterns:
    - Static const map lookup (IntentRouter) — pure, no runtime mutation
    - SharedPreferences JSON persistence with null-safe decode fallback
key_files:
  created:
    - apps/mobile/lib/services/coach/intent_router.dart
    - apps/mobile/test/services/coach/intent_router_test.dart
    - apps/mobile/test/services/coach/report_persistence_premier_eclairage_test.dart
  modified:
    - apps/mobile/lib/services/report_persistence_service.dart
decisions:
  - "Separate test file for ReportPersistenceService PremierEclairage tests rather than appending to intent_router_test.dart — cleaner separation of concerns"
  - "Added malformed JSON fallback (returns null) in loadPremierEclairageSnapshot — defense-in-depth per T-03-03"
  - "PII exclusion test added to enforce T-03-02 threat mitigation at test level"
metrics:
  duration: "~12 minutes"
  completed: "2026-04-05"
  tasks_completed: 2
  files_modified: 4
  tests_added: 27
---

# Phase 03 Plan 01: IntentRouter + PremierEclairage Persistence Summary

**One-liner:** Static intent routing map (7 ARB chip keys → goalIntentTag/stressType/route/family) plus SharedPreferences persistence for premier eclairage snapshot and seen-flag lifecycle.

## Tasks Completed

| Task | Description | Commit | Tests |
|------|-------------|--------|-------|
| 1 | Create IntentRouter mapping service (TDD) | 14776fe5 | 15 |
| 2 | Extend ReportPersistenceService with PremierEclairage persistence (TDD) | 49ec40b1 | 12 |

**Total: 27 new tests, all green. flutter analyze: 0 issues.**

## What Was Built

### Task 1: IntentRouter (`apps/mobile/lib/services/coach/intent_router.dart`)

- `IntentMapping` — immutable const class with 4 fields: `goalIntentTag`, `stressType`, `suggestedRoute`, `lifeEventFamily`
- `IntentRouter` — private constructor (never instantiated), static const `_map` of 7 entries per D-02:
  - `intentChip3a` → budget_overview / stress_budget / /pilier-3a / professionnel
  - `intentChipBilan` → retirement_choice / stress_retraite / /bilan-retraite / professionnel
  - `intentChipPrevoyance` → retirement_choice / stress_retraite / /prevoyance-overview / professionnel
  - `intentChipFiscalite` → budget_overview / stress_impots / /fiscalite-overview / patrimoine
  - `intentChipProjet` → housing_purchase / stress_patrimoine / /achat-immobilier / patrimoine
  - `intentChipChangement` → budget_overview / stress_budget / /life-events / professionnel
  - `intentChipAutre` → retirement_choice / stress_retraite / /bilan-retraite / professionnel (fallback)
- `forChipKey(String chipKey) → IntentMapping?` — returns null for unknown keys
- `allChipKeys → List<String>` — exactly 7 entries

### Task 2: ReportPersistenceService extensions

Four new methods added to the PREMIER ECLAIRAGE PERSISTENCE section:
- `savePremierEclairageSnapshot(Map<String, dynamic> data)` — stores display-only fields as JSON
- `loadPremierEclairageSnapshot() → Map<String, dynamic>?` — null-safe decode, returns null on error
- `hasSeenPremierEclairage() → bool` — returns false by default
- `markPremierEclairageSeen()` — one-shot boolean flag per D-09

`clearDiagnostic()` extended with removal of both new keys (`_hasSeenPremierEclairageKey`, `_premierEclairageSnapshotKey`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Security] Added PII exclusion test for T-03-02 mitigation**
- **Found during:** Task 2 implementation
- **Issue:** Threat T-03-02 (Information Disclosure — PII in SharedPreferences snapshot) required enforcement not covered by behavioral tests alone
- **Fix:** Added explicit test verifying snapshot map does not contain `salary`, `iban`, or `grossAnnualSalary` keys
- **Files modified:** `test/services/coach/report_persistence_premier_eclairage_test.dart`
- **Commit:** 49ec40b1

**2. [Rule 2 - Correctness] Added malformed JSON fallback test**
- **Found during:** Task 2 implementation
- **Issue:** `loadPremierEclairageSnapshot()` silently returns null on bad JSON — needed test coverage for this path
- **Fix:** Test sets malformed JSON directly via `SharedPreferences.setMockInitialValues` and verifies null return
- **Files modified:** `test/services/coach/report_persistence_premier_eclairage_test.dart`
- **Commit:** 49ec40b1

### Note: setSelectedOnboardingIntent missing from current codebase

The plan's `<interfaces>` section referenced `setSelectedOnboardingIntent` and `getSelectedOnboardingIntent` as existing methods — they are not present in the current `report_persistence_service.dart`. The `intent_screen.dart` was also removed from the worktree. Plan 02 must address this gap when wiring the intent screen. This plan's scope (IntentRouter + premier eclairage persistence) was unaffected.

## Known Stubs

None — both new artifacts are fully wired and functional. IntentRouter is a pure static map with no external dependencies. ReportPersistenceService methods use only SharedPreferences (project-standard).

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns were added. Persistence uses SharedPreferences (existing trust boundary). T-03-02 mitigation (no PII in snapshot) is enforced at test level.

## Self-Check

Files created:
- `apps/mobile/lib/services/coach/intent_router.dart` ✓
- `apps/mobile/test/services/coach/intent_router_test.dart` ✓
- `apps/mobile/test/services/coach/report_persistence_premier_eclairage_test.dart` ✓

Files modified:
- `apps/mobile/lib/services/report_persistence_service.dart` ✓

Commits:
- `14776fe5` feat(03-01): create IntentRouter mapping service ✓
- `49ec40b1` feat(03-01): extend ReportPersistenceService with PremierEclairage persistence ✓
