Plan 18 turns the Budget screen into a visual monthly flow surface.

## Goal

Show income, charges, future allocation, and available cash from the central Mint state before detailed controls.

## Contract

`BudgetScreen` prefers `MintUserState.dataSpineSnapshot.budget`, then falls back to `budgetSnapshot`, then local computation for isolated tests. The visible flow must use the same `BudgetSnapshot` values consumed elsewhere.

## Verification

- Red/green widget test for the central `BudgetSnapshot` amounts
- Targeted budget, Mon Argent, MintStateEngine, and DataSpineService tests
- Targeted Flutter analyze plus five design lints
