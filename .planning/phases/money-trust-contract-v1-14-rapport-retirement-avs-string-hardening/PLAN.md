# Phase 14 — Rapport Retirement AVS String Hardening

## Goal

Make the Rapport retirement card robust to persisted AVS year answers stored as
strings.

## Why

`FinancialReportScreenV2` had already converged its budget and safe-mode debt
paths, but the retirement card still cast `q_birth_year`,
`q_avs_arrival_year`, `q_avs_years_abroad`, and
`q_first_employment_year` as numeric values. These values may be hydrated from
storage as strings, causing a crash in the report flow.

## Scope

- Add a widget regression test with AVS year fields persisted as strings.
- Replace direct numeric casts with a local `_parseIntAnswer` helper.
- Keep retirement projection behavior and UI copy unchanged.

## Gate

```bash
cd apps/mobile
flutter test test/screens/advisor_banking_smoke_test.dart
flutter analyze --no-fatal-infos lib/screens/advisor/financial_report_screen_v2.dart test/screens/advisor_banking_smoke_test.dart
```
