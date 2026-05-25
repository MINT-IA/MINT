# Summary 53 — Budget formula visual polish

## Outcome

The budget formula proof now renders as a compact equation stack inside the
budget flow map instead of as a bordered card-like chip.

## Changes

- Replaced the proof `Wrap` / bordered `DecoratedBox` with `_BudgetFormulaLine`
  rows.
- Kept `budget_formula_proof` stable for widget tests and Maestro.
- Relaxed the smoke test's `Charges` assertion because the proof row and the
  flow legend now both show that label by design.

## Verification

- `flutter test test/screens/budget_screen_smoke_test.dart`
- `flutter analyze lib/screens/budget/budget_screen.dart test/screens/budget_screen_smoke_test.dart`
- Simulator screenshot review passed: the proof now reads as an inline audit
  stack rather than a nested card.
- `flow_mon_argent_budget_setup_spine.yaml` passed on iPhone 17 Pro; it still
  sees `budget_formula_proof`, CHF 2'200, CHF 420, and confirms
  `19'272'200` / `420'420` are absent.
