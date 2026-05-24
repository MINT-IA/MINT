description: Plan 25 renders housing and LAMal fixed charges in the Mon Argent situation map.

# Plan 25 — Mon Argent Fixed Charges

## Goal

Expose the two fixed charges that anchor the budget situation:
`monthlyHousingCost` and `lamalPremiumMonthly`.

## Scope

- Add rows for housing and health insurance in the Mon Argent situation map.
- Reuse existing localization keys: `budgetHousing` and
  `budgetHealthInsurance`.
- Extend the existing Mon Argent screen test.

## Verification

- First run the screen test red with the new expectations.
- Run the screen test green after implementation.
- Run Dart analysis on the touched screen and test.
- Run design lints and `git diff --check`.
