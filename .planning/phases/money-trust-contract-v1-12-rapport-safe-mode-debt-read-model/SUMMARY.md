# Phase 12 Summary — Rapport Safe-Mode Debt Read Model

## Changed

- `FinancialReportScreenV2._buildSafeModeReasons` now reads debt payments from
  `BudgetInputs.fromMap(answers).debtPayments`.
- Added a red/green widget test proving the report no longer crashes when
  stored debt is the string `'150'`.

## Product Impact

The Rapport screen now uses the canonical budget read model both for the budget
card and for safe-mode debt reasons. This closes a crash path visible only after
persistence or user-data hydration.
