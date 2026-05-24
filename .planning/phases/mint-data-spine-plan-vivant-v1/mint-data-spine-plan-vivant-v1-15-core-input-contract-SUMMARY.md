---
phase: mint-data-spine-plan-vivant-v1
plan: 15
status: complete
completed_at: 2026-05-24
type: flutter-tdd
---

# Plan 15 Summary — Core Input Contract

## Goal

Make `DataSpineSnapshot` available from the unified `MintUserState` so future
widgets, visualisations, arbitrages, and chat scenes can consume one central
read model for situation, budget, pillars, and trajectory.

## Accomplished

- Added `MintUserState.dataSpineSnapshot`.
- Added `MintUserState.hasDataSpineSnapshot`.
- Extended `MintUserState.copyWith()` with `dataSpineSnapshot`.
- Extended `DataSpineService.fromProfile()` with an optional precomputed
  `BudgetSnapshot`.
- Updated `MintStateEngine.compute()` so `dataSpineSnapshot` is computed in the
  same pass as `budgetSnapshot`.
- Added a regression test proving the Julien golden profile receives a
  `dataSpineSnapshot` and that it reuses the exact central `budgetSnapshot`
  instance.

## Verification

- `cd apps/mobile && flutter test test/services/mint_state_engine_test.dart --plain-name 'Julien dataSpineSnapshot reuses the central budget snapshot'` — PASS.
- `cd apps/mobile && flutter test test/services/mint_state_engine_test.dart test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart` — PASS, 46 tests.
- `cd apps/mobile && flutter analyze lib/models/mint_user_state.dart lib/services/mint_state_engine.dart lib/services/data_spine/data_spine_service.dart test/services/mint_state_engine_test.dart test/services/data_spine_service_test.dart` — PASS.
- `git diff --check` — PASS.

## Notes

- This does not refactor the UI yet.
- This deliberately avoids a second state model. `CoachProfile`,
  `BudgetSnapshot`, and `DataSpineSnapshot` remain the source chain.
- The brainstorm prototype lives at
  `.planning/prototypes/situation-budget-visual-brainstorm.html`.

## Next

Plan 16 should migrate one visible consumer to `MintUserState.dataSpineSnapshot`.
The recommended first target is `MonArgentScreen`, because it is the user-facing
place where situation financière and budget meet.
