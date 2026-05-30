# Phase 18 — ClarityState String Hardening

## Goal
Prevent the clarity/safe-mode model from crashing on persisted numeric strings.

## Problem
`ClarityState._calculateDebtRatio` directly cast answer values to `num?`.
Persisted values can be strings, including Swiss-formatted values such as
`5'000`. This could crash clarity-state calculation even after the budget read
model had been hardened.

## Scope
- Add a regression test for string income and string debt.
- Parse numeric strings consistently with the budget and wizard services.
- Align weekly/biweekly factors with `BudgetInputs` and `WizardService`.

## Acceptance Criteria
- `ClarityState.calculate` accepts string income and debt.
- No change to the safe-mode threshold.
- Wizard, budget, and clarity targeted suites remain green.
