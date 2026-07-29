# Phase 16 — Summary

## What Changed
- `BudgetInputs.fromMap` now falls back to summing detailed budget setup keys when
  `q_other_fixed_costs_monthly_chf` is absent.
- Added `BudgetInputs._sumDetailedFixedCosts`.
- Added a regression test in `budget_service_test.dart`.

## Why It Matters
The budget setup screen already captured transport, telecom, electricity,
medical, and other fixed expenses. The read model ignored those details unless a
separate aggregate key existed. That created inconsistent money surfaces and
could make Mint tell a user they had more free monthly cash than they really had.

## Files
- `apps/mobile/lib/domain/budget/budget_inputs.dart`
- `apps/mobile/test/domain/budget/budget_service_test.dart`

## Product Decision
`q_other_fixed_costs_monthly_chf` remains the preferred aggregate. The detailed
`_coach_depenses_*` keys are a compatibility/read-model fallback because they are
already written by the budget setup flow.
