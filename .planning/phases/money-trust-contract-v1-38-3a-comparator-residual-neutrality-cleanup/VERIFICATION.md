# Phase 38 — Verification

## Commands

```sh
flutter test \
  test/data/financial_explanations_test.dart \
  test/widgets/comparators/pillar3a_comparator_widget_test.dart
```

Result: `2` tests passed.

```sh
validate_arb_parity
```

Result: OK, six locales, `6812` keys each.

```sh
git diff --check
```

Result: pass.
