# Phase 17 — Verification

## Red
```bash
cd apps/mobile
flutter test test/services/wizard_service_test.dart --plain-name 'budget debt remains monthly even when income is weekly'
```

Initial failure:
- Expected safe mode `false`.
- Actual safe mode `true`.

## Green
```bash
cd apps/mobile
flutter test test/services/wizard_service_test.dart --plain-name 'budget debt remains monthly even when income is weekly'
flutter test test/services/wizard_service_test.dart test/services/report_builder_test.dart test/domain/budget/budget_service_test.dart
flutter analyze --no-fatal-infos lib/services/wizard_service.dart test/services/wizard_service_test.dart lib/domain/budget/budget_inputs.dart test/domain/budget/budget_service_test.dart lib/services/report/report_builder.dart test/services/report_builder_test.dart
git diff --check
```

## Claude Review
```bash
MINT_CLAUDE_MODEL=opus MINT_CLAUDE_MAX_BYTES=40000 MINT_CLAUDE_TIMEOUT=900 \
  tools/claude_review.sh \
  apps/mobile/lib/domain/budget/budget_inputs.dart \
  apps/mobile/lib/services/wizard_service.dart \
  apps/mobile/test/domain/budget/budget_service_test.dart \
  apps/mobile/test/services/wizard_service_test.dart
```

Verdict:
- No blocking findings.
- Non-blocking review requested extra tests around non-monthly income, biweekly
  debt, and legacy monthly income priority.

Follow-up green run:
```bash
cd apps/mobile
dart format test/services/wizard_service_test.dart test/domain/budget/budget_service_test.dart
flutter test test/services/wizard_service_test.dart test/domain/budget/budget_service_test.dart test/services/report_builder_test.dart
flutter analyze --no-fatal-infos lib/services/wizard_service.dart test/services/wizard_service_test.dart lib/domain/budget/budget_inputs.dart test/domain/budget/budget_service_test.dart lib/services/report/report_builder.dart test/services/report_builder_test.dart
git diff --check
```

Result:
- Targeted regression passed.
- Combined suite passed: 121 tests.
- Analyzer passed.
- Diff whitespace check passed.
