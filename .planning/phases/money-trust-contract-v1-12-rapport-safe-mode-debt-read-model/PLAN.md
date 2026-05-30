# Phase 12 — Rapport Safe-Mode Debt Read Model

## Goal

Remove the remaining raw debt cast from `FinancialReportScreenV2` safe-mode
reason generation.

## Why

The report budget section had converged to `BudgetInputs`, but the safe-mode
reason list still parsed `q_debt_payments_period_chf` directly as `num`.
Persisted answers can be strings, so the report could still crash even when the
budget card itself was correct.

## Scope

- Add a widget regression test with `q_debt_payments_period_chf: '150'`.
- Replace the local cast with `BudgetInputs.fromMap(answers).debtPayments`.
- Keep debt reason copy and UI behavior unchanged.

## Gate

```bash
cd apps/mobile
flutter test test/screens/advisor_banking_smoke_test.dart
flutter analyze --no-fatal-infos lib/screens/advisor/financial_report_screen_v2.dart test/screens/advisor_banking_smoke_test.dart
```
