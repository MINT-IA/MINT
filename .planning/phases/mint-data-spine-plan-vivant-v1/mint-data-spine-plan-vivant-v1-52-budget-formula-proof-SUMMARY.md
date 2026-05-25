# Summary 52 — Budget formula proof

## Outcome

The budget flow map now shows a compact calculation proof for the monthly
available amount:

`net income - charges - future = available`

This makes the hero number easier to audit and gives Maestro a stable anchor to
assert the screen's calculation surface.

## Changes

- Added `_BudgetFormulaProof` to `BudgetScreen`.
- Added the `budget_formula_proof` semantics anchor.
- Extended the budget smoke test to assert the new anchor.
- Extended the Mon Argent budget Maestro flow to assert the new anchor after a
  direct `/budget` relaunch.

## Verification

- Red test first: `BudgetScreen exposes Maestro semantics anchors` failed while
  the new anchor was absent.
- `flutter test test/screens/budget_screen_smoke_test.dart`
- `flutter test test/domain/budget/budget_service_test.dart test/screens/budget_screen_smoke_test.dart`
- `flutter analyze lib/screens/budget/budget_screen.dart test/screens/budget_screen_smoke_test.dart`
- `flow_mon_argent_budget_setup_spine.yaml` passed on iPhone 17 Pro with
  `MINT_E2E_ARCHETYPE=julien_swiss`; the flow saw `budget_formula_proof`,
  CHF 2'200, CHF 420, and confirmed `19'272'200` / `420'420` are absent.
