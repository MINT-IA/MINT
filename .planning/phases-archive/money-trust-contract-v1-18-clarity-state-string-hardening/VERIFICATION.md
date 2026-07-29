# Phase 18 — Verification

## Red
```bash
cd apps/mobile
flutter test test/wizard_test.dart --plain-name 'accepts persisted numeric strings for income and debt'
```

Initial failure:
- `type 'String' is not a subtype of type 'num?' in type cast`
- Source: `ClarityState._calculateDebtRatio`.

## Green
```bash
cd apps/mobile
flutter test test/wizard_test.dart --plain-name 'accepts persisted numeric strings for income and debt'
flutter test test/wizard_test.dart test/services/wizard_service_test.dart test/domain/budget/budget_service_test.dart
flutter analyze --no-fatal-infos lib/models/clarity_state.dart test/wizard_test.dart lib/services/wizard_service.dart test/services/wizard_service_test.dart lib/domain/budget/budget_inputs.dart test/domain/budget/budget_service_test.dart
git diff --check
```

Result:
- Targeted regression passed.
- Combined suite passed: 127 tests.
- Analyzer passed.
- Diff whitespace check passed.
