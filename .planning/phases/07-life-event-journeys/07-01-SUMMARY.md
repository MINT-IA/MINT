---
phase: 07-life-event-journeys
plan: 01
subsystem: onboarding-intent-journeys
tags: [intent-router, cap-sequence-engine, i18n, onboarding, life-events]
dependency_graph:
  requires: []
  provides: [first_job-journey-wiring, new_job-journey-wiring, intent-screen-9-chips]
  affects: [IntentScreen, CapSequenceEngine, IntentRouter]
tech_stack:
  added: []
  patterns: [TDD-red-green, pure-function-builder, ARB-6-language-sync]
key_files:
  created: []
  modified:
    - apps/mobile/lib/services/coach/intent_router.dart
    - apps/mobile/lib/services/cap_sequence_engine.dart
    - apps/mobile/lib/screens/onboarding/intent_screen.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
    - apps/mobile/test/services/coach/intent_router_test.dart
    - apps/mobile/test/services/cap_sequence_engine_test.dart
    - apps/mobile/lib/l10n/app_localizations.dart (generated)
    - apps/mobile/lib/l10n/app_localizations_*.dart (6 generated)
decisions:
  - "firstJob suggestedRoute set to /premier-emploi (existing screen); newJob to /rente-vs-capital (salary comparison entry)"
  - "New chips inserted after intentChipChangement and before intentChipAutre (catch-all stays last)"
  - "CapSequence step status: salary presence as primary gate; memory completedActions as secondary signal"
metrics:
  duration: "6 minutes"
  completed: "2026-04-06T06:23:00Z"
  tasks_completed: 2
  files_modified: 11
---

# Phase 07 Plan 01: Life Event Journey Infrastructure (firstJob + newJob) Summary

**One-liner:** IntentRouter wired with 9 chip mappings and CapSequenceEngine extended with firstJob (5-step) and newJob (5-step) sequences, backed by 22 new i18n keys across all 6 languages.

## What Was Built

### Task 1: IntentRouter + CapSequenceEngine (TDD)

**IntentRouter (`intent_router.dart`)** — expanded from 7 to 9 mappings:
- `intentChipPremierEmploi` → `first_job` / `stress_budget` / `/premier-emploi` / `professionnel`
- `intentChipNouvelEmploi` → `new_job` / `stress_budget` / `/rente-vs-capital` / `professionnel`

**CapSequenceEngine (`cap_sequence_engine.dart`)** — expanded from 3 to 5 goal families:
- `_kGoalFirstJob = 'first_job'` — 5 steps: fj_01_income → fj_02_salary_xray → fj_03_lpp → fj_04_3a → fj_05_specialist
- `_kGoalNewJob = 'new_job'` — 5 steps: nj_01_income → nj_02_compare → nj_03_lpp_transfer → nj_04_3a → nj_05_specialist
- Both sequences gate later steps on salary presence (blocked if no salary)
- Step completion via profile field presence + memory.completedActions

**Tests (73 total, all passing):**
- intent_router_test.dart: 2 new tests for new mappings, count updated to 9
- cap_sequence_engine_test.dart: 16 new tests for firstJob + newJob sequences

### Task 2: IntentScreen + i18n

**IntentScreen** — 9 chips (previously 7):
- Added `intentChipPremierEmploi` (Mon premier emploi) after intentChipChangement
- Added `intentChipNouvelEmploi` (Je change de travail) after intentChipPremierEmploi
- `intentChipAutre` remains last as catch-all

**ARB files (all 6 languages)** — 22 new keys each:
- 2 chip labels: intentChipPremierEmploi, intentChipNouvelEmploi
- 10 firstJob step titles + descriptions (capStepFirstJob01Title through capStepFirstJob05Desc)
- 10 newJob step titles + descriptions (capStepNewJob01Title through capStepNewJob05Desc)
- `flutter gen-l10n` regenerated all app_localizations_*.dart files

## Key Links Verified

- IntentScreen chip tap → IntentRouter.forChipKey('intentChipPremierEmploi') → `first_job` goal
- IntentRouter `first_job` → CapSequenceEngine._buildFirstJob() → 5-step sequence
- IntentScreen chip tap → IntentRouter.forChipKey('intentChipNouvelEmploi') → `new_job` goal
- IntentRouter `new_job` → CapSequenceEngine._buildNewJob() → 5-step sequence
- housingPurchase journey via intentChipProjet already works (verified, no changes needed)

## Commits

| Hash | Task | Description |
|------|------|-------------|
| 98edd815 | Task 1 | feat(07-01): IntentRouter + CapSequenceEngine firstJob/newJob |
| e895a4e8 | Task 2 | feat(07-01): IntentScreen chips + 22 i18n keys all 6 languages |

## Deviations from Plan

None — plan executed exactly as written.

## Deferred Issues (Out of Scope)

**Pre-existing `flutter analyze` failures (54 issues, none in modified files):**
- `retirement_budget_service_test.dart`: 5 undefined_getter errors on RetirementBudget fields
- `check_in_tool_test.dart`, `plan_reality_home_test.dart`: prefer_const_constructors info
- These exist on the base branch and are unrelated to this plan's scope.
- Logged here per deviation rules scope boundary.

## Known Stubs

None. All i18n keys are fully populated. CapSequence step routes point to existing screens.

## Self-Check: PASSED

- `apps/mobile/lib/services/coach/intent_router.dart` — FOUND, contains intentChipPremierEmploi
- `apps/mobile/lib/services/cap_sequence_engine.dart` — FOUND, contains _kGoalFirstJob + _kGoalNewJob
- `apps/mobile/lib/screens/onboarding/intent_screen.dart` — FOUND, contains both new chips
- `apps/mobile/lib/l10n/app_fr.arb` — FOUND, 22 new keys added
- Commit 98edd815 — FOUND (4 files, 423 insertions)
- Commit e895a4e8 — FOUND (14 files, 721 insertions)
- 73 tests passing: flutter test intent_router_test.dart cap_sequence_engine_test.dart — PASSED
