# Phase 14 Verification — Rapport Retirement AVS String Hardening

## Red/Green

```bash
cd apps/mobile
flutter test test/screens/advisor_banking_smoke_test.dart --plain-name 'retirement card accepts persisted AVS years as strings'
```

Result before fix: failed with `type 'String' is not a subtype of type 'num?' in type cast`.

Result after fix: pass.

## Targeted Suite

```bash
cd apps/mobile
flutter test test/screens/advisor_banking_smoke_test.dart
```

Result: pass, `33` tests.

## Static Analysis

```bash
cd apps/mobile
flutter analyze --no-fatal-infos lib/screens/advisor/financial_report_screen_v2.dart test/screens/advisor_banking_smoke_test.dart
```

Result: pass, no issues found.

## Diff Hygiene

```bash
git diff --check
```

Result: pass.
