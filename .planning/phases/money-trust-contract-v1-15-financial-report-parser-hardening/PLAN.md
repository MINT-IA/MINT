# Phase 15 — FinancialReportService Parser Hardening

## Goal

Make `FinancialReportService` parse persisted Swiss numeric strings instead of
falling back to defaults.

## Why

The report service feeds tax, retirement, 3a analysis, and profile summaries.
Its local parsers rejected values like `"5'379"`, `"7'258"`, and `"1985.0"`,
which could silently replace real user facts with defaults.

## Scope

- Add a service regression test with Swiss persisted string inputs.
- Harden `_parseInt` and `_parseDouble` for:
  - numeric strings with Swiss apostrophes;
  - comma decimals;
  - decimal year strings such as `"1985.0"`;
  - any numeric subtype.

## Gate

```bash
cd apps/mobile
flutter test test/services/financial_report_service_test.dart
flutter analyze --no-fatal-infos lib/services/financial_report_service.dart test/services/financial_report_service_test.dart
```
