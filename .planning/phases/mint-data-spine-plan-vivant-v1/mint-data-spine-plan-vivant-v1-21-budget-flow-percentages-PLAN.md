# Plan 21 — Budget flow percentages

## Goal
Make the Budget flow map easier to scan by showing proportions next to each monthly amount.

## Scope
- Reuse the existing `BudgetSnapshot.present` values.
- Add no calculation service, route, or ARB key.
- Keep the diff tiny and widget-tested.

## Acceptance
- BudgetScreen shows charge, future, and available percentages.
- The BudgetScreen smoke test locks 65%, 9%, and 26% for the snapshot fixture.
- Analyze, screen test, design lints, and diff check stay green.

