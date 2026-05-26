---
phase: mon-argent-budget-cleanup-v2
plan: 01
status: executed
created_at: 2026-05-26
branch: codex/mon-argent-budget-cleanup-v2
---

# Plan 01 — Mon Argent Canonical Budget Copy

## Goal

Keep Mon Argent budget visuals and deterministic coach copy on the same
canonical read model.

## Context

PR #681 made the Mon Argent budget card prefer `BudgetSnapshot`, but the
adjacent `CoachWhisperService` still read `BudgetProvider.inputs` and
`BudgetProvider.plan`. That can create a mismatch where the card shows a
canonical deficit while the whisper sees a stale positive local plan.

## Tasks

- [x] Add a failing service regression proving canonical snapshot wins over
      stale provider state.
- [x] Make `CoachWhisperService` accept `BudgetSnapshot?`.
- [x] Pass `budgetSnapshot` from `MonArgentScreen`.
- [x] Verify focused Mon Argent/Data Spine/Budget tests.

## Verification

- `flutter test test/services/mon_argent_coach_whisper_service_test.dart`
- `flutter test test/screens/mon_argent_screen_test.dart test/services/mon_argent_coach_whisper_service_test.dart test/widgets/mon_argent_budget_summary_card_test.dart test/services/data_spine_service_test.dart test/services/budget_living_engine_test.dart`
- `flutter analyze lib/services/mon_argent/coach_whisper_service.dart lib/screens/mon_argent/mon_argent_screen.dart`
