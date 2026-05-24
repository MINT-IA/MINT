Plan 16 connects Mon argent to the unified data spine read model.

## Goal

Use `MintUserState.dataSpineSnapshot` for the visible Mon argent budget and patrimoine cards when available, with legacy provider fallback before state computation.

## Contract

Prefer `dataSpineSnapshot.budget` and data spine patrimoine values. Empty `BudgetProvider` storage must not hide a ready state snapshot. Prove it with a widget test that fails before wiring.

## Verification

- `flutter test test/screens/mon_argent_screen_test.dart test/services/mint_state_engine_test.dart test/services/data_spine_service_test.dart`
- `flutter analyze lib/screens/mon_argent/mon_argent_screen.dart lib/widgets/mon_argent/budget_summary_card.dart lib/services/mon_argent/patrimoine_aggregator.dart test/screens/mon_argent_screen_test.dart`
