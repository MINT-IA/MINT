# Money Trust Contract v1 — 08 Report Budget Read Model Summary

## Changes

- Replaced the Financial Report budget card's raw answer arithmetic with
  `BudgetInputs.fromMap(answers)` and `BudgetService.computePlan(inputs)`.
- Removed the local LAMal and budget tax reconstruction from the report budget
  section.
- Extended `BudgetInputs.fromMap` so it preserves legacy
  `q_net_income_monthly` and normalizes weekly/biweekly income to monthly.
- Added a widget regression test proving the report no longer renders
  `19'272'200` or `420'420` as monthly charges.

## Product Decision

The report is a dossier of proofs, not an independent calculator. Its budget
card should therefore reuse the same read model and plausibility guards as the
budget domain.

## Follow-up

- Add Maestro parity assertions that Mon Argent, Budget, and Report all reject
  the known implausible capture class.
- Decide separately how to show signed deficits in report cards, because
  `BudgetPlan.available` remains an allocation amount clamped at zero.
