# Phase 11 Verification — ReportBuilder Budget Read-Model Cutover

## Regression

```bash
cd apps/mobile
flutter test test/services/report_builder_test.dart
```

Result: pass, `3` tests.

## Targeted Suite

```bash
cd apps/mobile
flutter test test/services/report_builder_test.dart test/services/wizard_service_test.dart test/domain/budget/budget_service_test.dart
```

Result: pass, `114` tests.

## Static Analysis

```bash
cd apps/mobile
flutter analyze --no-fatal-infos lib/services/report/report_builder.dart lib/services/wizard_service.dart test/services/report_builder_test.dart test/services/wizard_service_test.dart
```

Result: pass, no issues found.

## Diff Hygiene

```bash
git diff --check
```

Result: pass.

## Review

Claude review was requested through `tools/claude_review.sh` on:

- `apps/mobile/lib/services/report/report_builder.dart`
- `apps/mobile/lib/services/wizard_service.dart`
- `apps/mobile/test/services/report_builder_test.dart`

Result: Claude challenged a potential `CHF 0` tax regression and asked for
proof that debt parsing and canton fallback were safe. Follow-up:

- `BudgetInputs.fromMap` already computes a tax fallback when
  `q_tax_provision_monthly_chf` is absent.
- `CantonalDataService.getByCode('CH')` returns the `Moyenne Suisse` fallback.
- Added tests for no declared tax provision and persisted string debt.
