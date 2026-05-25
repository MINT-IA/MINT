description: Plan 55 removes raw source labels and ASCII-flattened French from the Mon Argent patrimoine card.

# Plan 55 - Patrimoine Localized Source Copy

## Problem

The simulator snapshot after Plan 54 exposed two trust issues in the Mon Argent patrimoine card:

- The pulse semantics label said `donnees` instead of `données`.
- The latest-update label surfaced the raw source value `estimated` in the French UI.

Both issues make the central money surface feel less reliable, even when the underlying values are reasonable.

## Scope

- Add a widget regression for the patrimoine summary card.
- Localize the pulse semantics label with `monArgentPatrimoineKnownDataLabel`.
- Localize the latest-update label with `monArgentPatrimoineLastUpdated`.
- Map raw source codes (`userInput`, `estimated`, `certificate`, `openBanking`, `crossValidated`, fallback) to user-facing labels in all 6 locales.
- Use locale-aware month labels instead of ASCII-flattened month abbreviations.

## Non-goals

- No new calculation.
- No schema change to `PatrimoineSummary`.
- No visual redesign of the card.
- No change to Mon Argent navigation.

## TDD

Initial failing command:

```bash
cd apps/mobile
flutter test test/widgets/mon_argent_patrimoine_summary_card_test.dart
```

Observed failure before implementation:

- The test expected `100 % des données connues` and `Mis à jour le 25 mai · estimé`.
- The existing widget still emitted the ASCII-flattened semantics label and raw source code.

## Verification Plan

- `flutter gen-l10n`
- `flutter test test/widgets/mon_argent_patrimoine_summary_card_test.dart test/widgets/mon_argent_budget_summary_card_test.dart`
- `flutter test test/screens/mon_argent_screen_test.dart test/widgets/mon_argent_budget_summary_card_test.dart test/widgets/mon_argent_patrimoine_summary_card_test.dart`
- `flutter analyze lib/screens/mon_argent/mon_argent_screen.dart lib/widgets/mon_argent/patrimoine_summary_card.dart test/screens/mon_argent_screen_test.dart test/widgets/mon_argent_patrimoine_summary_card_test.dart`
- `validate_arb_parity`
- `check_accent_patterns` on the new French strings.
