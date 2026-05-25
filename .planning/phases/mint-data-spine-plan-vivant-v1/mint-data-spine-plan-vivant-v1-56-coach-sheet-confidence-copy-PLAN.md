description: Plan 56 removes ASCII-flattened and overconfident copy from coach/confidence widgets.

# Plan 56 - Coach Sheet Confidence Copy

## Problem

After Plan 55, a grep pass still found visible French copy that looked like implementation text instead of product text:

- `Plus de donnees = projections fiables` in the coach quick sheet.
- `Simuler un scenario` and `hypotheque` in the same sheet.
- `Precision des donnees` in the confidence breakdown card.

The first string is also too strong for a fintech trust surface: more data improves projections, but the UI should not imply certainty.

## Scope

- Add widget regressions for the coach quick sheet and confidence breakdown card.
- Replace ASCII-flattened French with accented French.
- Replace the strong projection claim with more prudent copy.
- Fix any layout issue surfaced by the new tests in the coach quick sheet.

## Non-goals

- No navigation redesign of the coach FAB.
- No route changes.
- No financial calculation changes.
- No localization expansion for this legacy hardcoded widget pass.

## TDD

Initial failing command:

```bash
cd apps/mobile
flutter test test/widgets/mentor_fab_test.dart test/widgets/confidence_breakdown_card_test.dart
```

Observed failures before completion:

- The tests detected the old ASCII-flattened strings.
- The coach quick sheet also overflowed vertically in a constrained widget-test viewport.

## Verification Plan

- `flutter test test/widgets/mentor_fab_test.dart test/widgets/confidence_breakdown_card_test.dart`
- `flutter analyze lib/widgets/mentor_fab.dart lib/widgets/confidence_breakdown_card.dart test/widgets/mentor_fab_test.dart test/widgets/confidence_breakdown_card_test.dart`
- `check_accent_patterns` on the new French strings.
- `check_banned_terms` on the new French strings.
- `python3 tools/checks/wiki_lint.py`
