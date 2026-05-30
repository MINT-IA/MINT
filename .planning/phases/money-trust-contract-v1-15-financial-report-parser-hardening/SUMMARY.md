# Phase 15 Summary — FinancialReportService Parser Hardening

## Changed

- `_parseInt` now accepts numeric subtypes and decimal numeric strings.
- `_parseDouble` now accepts numeric subtypes, Swiss apostrophe thousands, and
  comma decimals.
- Added a regression test proving persisted strings feed:
  - `profile.birthYear = 1985`;
  - `profile.monthlyNetIncome = 5379`;
  - `taxSimulation.deductions['3a'] = 7258`;
  - `pillar3aAnalysis.annualContribution = 7258`.

## Product Impact

The financial report service now respects persisted user facts instead of
silently using defaults, reducing cross-screen drift and trust-breaking
numbers.
