# Summary 46 — Pulse tax preview copy

## Outcome

The Pulse fiscal focus preview now says the amount is estimated tax impact, not
money to recover.

## Changes

- Replaced `~CHF X/an récupérables` with `~CHF X/an d'impôt estimés`.
- Switched the preview to `estimate3aTaxImpact`.
- Added `test/widgets/pulse/focus_selector_test.dart`.

## Verification

- Red test first: old `récupérables` text failed.
- `flutter test test/widgets/pulse/focus_selector_test.dart`
- `flutter analyze lib/widgets/pulse/focus_selector.dart test/widgets/pulse/focus_selector_test.dart`
