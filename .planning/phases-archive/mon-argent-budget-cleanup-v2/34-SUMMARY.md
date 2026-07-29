# Phase 34 — Mobile budget source convergence

## Goal

Make Mon argent display the canonical mobile budget source instead of letting a local `BudgetProvider` cache mask the Data Spine.

## Findings

- `MonArgentScreen` could choose `BudgetProvider` over `MintState.dataSpineSnapshot.budget` when `BudgetProvider.hasFreshInputs` was true.
- `BudgetProvider.refreshFromProfile` persisted profile-derived budget inputs into `budget_inputs_v1`, creating a second local representation beside `wizard_answers_v2`.

## Changes

- `MonArgentScreen` now prefers a budget freshly re-derived from the current `CoachProfile`, then Data Spine, then direct-input fallback data.
- `BudgetProvider.refreshFromProfile` computes the session read model from `CoachProfile` but no longer rewrites `budget_inputs_v1`.
- Profile-derived duplicate caches are cleared; direct-input caches such as bank-import budgets remain as fallback until migrated into `wizard_answers_v2`.
- `BudgetLocalStore` gained `clearInputs()` so slider overrides can survive while stale direct inputs are removed.
- Tests now assert direct-input cache cannot mask a current Data Spine, current profile-derived values can replace a stale Data Spine, and direct-input fallback caches survive full-profile hydration.

## Verification

- `flutter test test/screens/mon_argent_screen_test.dart`
- `flutter test test/providers/budget/budget_provider_test.dart`
- `flutter analyze lib/data/budget/budget_local_store.dart lib/providers/budget/budget_provider.dart lib/screens/mon_argent/mon_argent_screen.dart test/providers/budget/budget_provider_test.dart test/screens/mon_argent_screen_test.dart`
