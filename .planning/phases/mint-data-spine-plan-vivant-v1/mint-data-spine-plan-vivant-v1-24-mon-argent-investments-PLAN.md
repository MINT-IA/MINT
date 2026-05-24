description: Plan 24 renders investments in the Mon Argent situation map so the visible UI matches the structured situation facts.

# Plan 24 — Mon Argent Investments

## Goal

Expose `FinancialSituation.investments` in the Mon Argent situation map.

## Scope

- Add a row for investments between liquid savings and debt.
- Reuse the existing `financialSummaryInvestissements` localization key.
- Extend the existing Mon Argent screen test.

## Verification

- First run the screen test red with the new expectation.
- Run the same screen test green after implementation.
- Run Dart analysis on the touched screen and test.
- Run design lints and `git diff --check`.
