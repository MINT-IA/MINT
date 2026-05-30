# Phase 11 Summary — ReportBuilder Budget Read-Model Cutover

## Changed

- `ReportBuilder` no longer casts `q_debt_payments_period_chf` directly from
  raw `answers`.
- `ReportBuilder` displays tax provision from `BudgetInputs.taxProvision`
  instead of recomputing a separate estimate.
- `WizardService._calculateDebtRatio` now accepts persisted numeric strings
  for leasing, credit, and budget debt fields.
- Added a service-level regression test proving a persisted payload with
  `"5'379"`, `"2200"`, `"420"`, `"520"`, and `"0"` builds a report with:
  - `Disponible / mois = CHF 2239`;
  - `Impôts Estimés = CHF 520`.

## Product Impact

The report is now part of the same budget trust perimeter as the budget screen
and the Rapport Maestro flow. This reduces cross-screen financial drift and
prevents crashes when values come back from storage as strings.

## Follow-Up

The next cleanup target is the remaining user-money screens that still read
budget-adjacent fields directly from `answers` instead of the canonical budget
read model or a higher-level money snapshot.
