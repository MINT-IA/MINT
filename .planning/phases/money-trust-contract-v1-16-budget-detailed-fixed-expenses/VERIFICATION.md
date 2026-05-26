# Phase 16 — Verification

## Red
```bash
cd apps/mobile
flutter test test/domain/budget/budget_service_test.dart --plain-name 'fromMap sums detailed coach fixed expenses when canonical is absent'
```

Initial failure:
- `otherFixedCosts` was `0.0` instead of `400.0`.

## Green
```bash
cd apps/mobile
flutter test test/domain/budget/budget_service_test.dart --plain-name 'fromMap sums detailed coach fixed expenses when canonical is absent'
flutter test test/domain/budget/budget_service_test.dart test/services/report_builder_test.dart test/screens/advisor_banking_smoke_test.dart
flutter analyze --no-fatal-infos lib/domain/budget/budget_inputs.dart test/domain/budget/budget_service_test.dart lib/services/report/report_builder.dart test/services/report_builder_test.dart lib/screens/advisor/financial_report_screen_v2.dart test/screens/advisor_banking_smoke_test.dart
git diff --check
```

Result:
- Targeted regression passed.
- Combined suite passed: 109 tests.
- Analyzer passed.
- Diff whitespace check passed.
