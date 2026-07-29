# Money Trust Contract v1 — 08 Report Budget Read Model

Move the Financial Report budget card onto the same budget read model used by
Budget and Mon Argent.

## Goal

Stop the report from displaying raw, implausible monthly captures as trusted
budget figures.

## Scope

- `FinancialReportScreenV2._buildBudgetSection`.
- Widget test covering the known `19'272'200` / `420'420` capture class.

## Out of Scope

- Full DataSpine migration for the report.
- Signed deficit presentation redesign.
- Maestro report parity flow.

## Acceptance

- Report budget card builds `BudgetInputs.fromMap(answers)`.
- Report budget card computes status/key figure through `BudgetService`.
- Implausible captured monthly values are not rendered.
- Existing advisor/banking smoke tests and budget domain tests still pass.
