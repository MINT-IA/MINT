# Phase 16 — Budget Detailed Fixed Expenses

## Goal
Make the canonical budget read model ingest the detailed fixed-expense keys written by the budget setup flow.

## Problem
`BudgetSetupScreen` writes detailed fixed expenses under `_coach_depenses_transport`,
`_coach_depenses_telecom`, `_coach_depenses_electricite`,
`_coach_depenses_frais_medicaux`, and `_coach_depenses_autres`.

Before this phase, `BudgetInputs.fromMap` only read
`q_other_fixed_costs_monthly_chf`. When that aggregate key was absent, the
budget read model treated other fixed expenses as missing/zero, overstating
the user's monthly available cash.

## Scope
- Add a regression test proving the detailed keys are summed.
- Keep `q_other_fixed_costs_monthly_chf` as the canonical aggregate when it is present.
- Route the fix through `BudgetInputs.fromMap`, so Budget, Mon Argent, Rapport,
  and ReportBuilder benefit from the same contract.

## Out of Scope
- Redesigning the budget UI.
- Changing the persisted key names.
- Adding new budget categories.

## Acceptance Criteria
- Detailed fixed expenses are summed when the canonical aggregate is absent.
- `isOtherFixedMissing` is false when at least one detailed fixed-expense key is present.
- Existing report and advisor smoke tests remain green.
