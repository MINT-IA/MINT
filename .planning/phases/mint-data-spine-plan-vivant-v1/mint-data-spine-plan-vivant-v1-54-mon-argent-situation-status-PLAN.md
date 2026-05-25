description: Plan 54 exposes source status on Mon Argent situation values so user-facing numbers carry their data quality.

# Plan 54 - Mon Argent Situation Status

## Problem

Mon Argent already reads central situation values from `DataSpineSnapshot`, but non-pillar rows displayed only the amount. That makes a user-entered value and an estimated value look equally solid, which weakens trust in every downstream budget, trajectory, and planning widget.

## Scope

- Surface a compact status chip for each Mon Argent situation row.
- Derive the label from `SpineFieldMeta.confidence`, not from display text.
- Reuse existing i18n labels: `budgetQualityProvided`, `budgetQualityEstimated`, `budgetQualityMissing`.
- Keep the change local to `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart`.
- Add a widget regression in `apps/mobile/test/screens/mon_argent_screen_test.dart`.

## Non-goals

- No new financial formula.
- No data spine schema change.
- No navigation change.
- No new ARB key.

## TDD

Initial failing assertion:

```bash
cd apps/mobile
flutter test test/screens/mon_argent_screen_test.dart
```

Observed failure before implementation:

- `find.text('saisi')` had zero matching widgets.
- The fixture now marks `investments` as `FieldConfidence.estimated` to prove the screen distinguishes user-entered and estimated values.

## Verification Plan

- `flutter test test/screens/mon_argent_screen_test.dart`
- `flutter analyze lib/screens/mon_argent/mon_argent_screen.dart test/screens/mon_argent_screen_test.dart`
- `flutter test test/screens/mon_argent_screen_test.dart test/widgets/mon_argent_budget_summary_card_test.dart`
- `python3 tools/checks/wiki_lint.py`
- Maestro Mon Argent / Budget flow after local tests.
