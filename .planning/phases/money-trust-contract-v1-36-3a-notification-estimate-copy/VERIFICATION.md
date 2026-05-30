# Phase 36 Verification

## Tests

Command:

```bash
cd apps/mobile && flutter test \
  test/services/notification_scheduler_service_test.dart \
  test/services/reengagement_engine_test.dart
```

Result:

```text
49 passed
```

## I18n

Command:

```bash
flutter gen-l10n
```

Result: completed successfully.

Command:

```bash
validate_arb_parity
```

Result:

```text
OK — 6 locale(s) parity (reference=fr, 6817 keys each).
```

## Mechanical

Command:

```bash
git diff --check
```

Result: clean.
