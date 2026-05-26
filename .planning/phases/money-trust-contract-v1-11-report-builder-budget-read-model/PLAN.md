# Phase 11 — ReportBuilder Budget Read-Model Cutover

## Goal

Remove the remaining duplicated budget parsing path from `ReportBuilder` so
the report uses the same budget read model as Budget, Mon Argent, and Rapport.

## Why

The report still trusted raw `answers` casts for debt and recomputed tax
provision locally. That creates the exact class of Mint bug we are eliminating:
one screen displays sane values while another crashes or invents a different
financial picture from the same user data.

## Scope

- Add a regression test for persisted numeric strings in `ReportBuilder`.
- Make `ReportBuilder` use `BudgetInputs` for:
  - debt detection;
  - tax provision displayed in the scoreboard;
  - monthly available budget.
- Harden `WizardService` safe-mode debt parsing so persisted strings do not
  crash report generation.

## Out of Scope

- Redesigning the report UI.
- Changing the safe-mode monthly/periodic debt semantics.
- Reworking the recommendation copy or 3a arbitrage engine.

## Gate

```bash
cd apps/mobile
flutter test test/services/report_builder_test.dart test/services/wizard_service_test.dart test/domain/budget/budget_service_test.dart
flutter analyze --no-fatal-infos lib/services/report/report_builder.dart lib/services/wizard_service.dart test/services/report_builder_test.dart test/services/wizard_service_test.dart
```
