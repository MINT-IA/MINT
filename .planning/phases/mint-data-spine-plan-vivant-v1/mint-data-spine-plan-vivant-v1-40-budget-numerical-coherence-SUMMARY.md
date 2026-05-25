# Summary 40 — Budget numerical coherence

## Outcome

`BudgetScreen` now uses the explicit `BudgetInputs` passed into the screen for
its hero number, breakdown, and flow map. A stale global `BudgetSnapshot` can no
longer make the flow map tell a different monthly story from the detailed rows.

## Changes

- Removed the `BudgetScreen` dependency on `MintStateProvider` and
  `BudgetLivingEngine` for the local detail screen.
- Added `_presentBudgetFromInputs()` to derive the flow map from
  `BudgetInputs` and `BudgetPlan`.
- Aligned displayed CHF arithmetic by rounding the visible rows before deriving
  visible totals.
- Updated `budget_screen_smoke_test.dart` with a stale `MintState` regression.
- Extended the Maestro Mon Argent/Budget flow with visible CHF assertions and
  negative assertions against the old absurd values.
- Documented the local source-of-truth rule in `docs/data-flow.md`.

## Verification

- `flutter test test/screens/budget_screen_smoke_test.dart`
- `flutter analyze lib/screens/budget/budget_screen.dart test/screens/budget_screen_smoke_test.dart`
- `bash tools/simulator/maestro_env.sh check-syntax tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml`
- `bash tools/simulator/maestro_env.sh test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml --format junit --output .planning/_walker/maestro-evidence-20260525T111635-plan40/maestro.xml`

## Evidence

- `.planning/_walker/maestro-evidence-20260525T111635-plan40/MAESTRO-RUNS.md` —
  documents `1/1 Flow Passed in 36s`.
- `.planning/_walker/maestro-evidence-20260525T111635-plan40/mon-argent-03-budget-direct-relaunch.png` —
  shows CHF 5'379 net income, CHF 3'140 charges, CHF 0 future, CHF 2'239
  available.
