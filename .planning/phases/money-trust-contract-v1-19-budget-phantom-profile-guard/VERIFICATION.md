# Phase 19 — Verification

## Red
```bash
cd apps/mobile
flutter test test/providers/budget/budget_provider_test.dart --plain-name 'full profile does not persist phantom default expenses'
```

Initial failure:
- `provider.inputs!.housingCost` was `1500.0` instead of `0`.

## Green
```bash
cd apps/mobile
flutter test test/providers/budget/budget_provider_test.dart --plain-name 'full profile does not persist phantom default expenses'
flutter test test/providers/budget/budget_provider_test.dart test/domain/budget/budget_service_test.dart test/screens/budget_setup_screen_test.dart test/screens/advisor_banking_smoke_test.dart test/services/report_builder_test.dart
flutter analyze --no-fatal-infos lib/domain/budget/budget_inputs.dart lib/providers/budget/budget_provider.dart test/providers/budget/budget_provider_test.dart test/domain/budget/budget_service_test.dart
git diff --check
```

Result:
- Targeted regression passed.
- Combined suite passed: 123 tests.
- Analyzer passed.
- Diff whitespace check passed.
