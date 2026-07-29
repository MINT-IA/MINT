# Phase 19 — Budget Phantom Profile Guard

## Goal
Prevent profile defaults and internal estimates from being persisted as a real
user budget.

## Problem
`CoachProfile.fromWizardAnswers` can contain internal defaults such as
`depenses.loyer = 1500` and an estimated LAMal premium even when the user never
entered budget data. `BudgetProvider.refreshFromProfile` used
`BudgetInputs.fromCoachProfile`, persisted those values, and made Budget/Mon
Argent look as if the user had provided a budget.

## Scope
- Add a regression test proving a full profile without budget sources does not
  persist phantom housing or health-insurance expenses.
- Keep explicitly sourced profile expenses working.
- Use `CoachProfile.dataSources` and `userProvidedFields` as the trust gate.

## Acceptance Criteria
- Profile defaults are not persisted as budget inputs.
- Explicit user-provided profile expenses still replace stale stored budgets.
- Budget/Report targeted tests remain green.
