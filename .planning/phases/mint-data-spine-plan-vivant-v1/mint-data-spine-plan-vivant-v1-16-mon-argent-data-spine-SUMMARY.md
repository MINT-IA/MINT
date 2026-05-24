Plan 16 migrated Mon argent to consume the unified data spine when present.

## Outcome

- Added a widget regression test for data-spine budget and patrimoine rendering.
- Extended `BudgetSummaryCard` with optional `BudgetSnapshot` input.
- Added `PatrimoineAggregator.computeFromDataSpine`.
- Wired `MonArgentScreen` to prefer `dataSpineSnapshot`, then `budgetSnapshot`, then legacy providers.

## Verification

Target Mon argent test first failed on missing wiring, then passed. Data spine service + mint state engine tests passed with the new screen test. Targeted Flutter analyze passed.
