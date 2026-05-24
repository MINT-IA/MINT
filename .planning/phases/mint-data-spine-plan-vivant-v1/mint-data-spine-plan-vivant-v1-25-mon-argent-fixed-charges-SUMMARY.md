description: Plan 25 added housing and LAMal rows to Mon Argent's situation map with widget coverage.

# Plan 25 — Summary

## Changed

- Mon Argent now displays:
  - `situation.monthlyHousingCost` as `Logement`
  - `situation.lamalPremiumMonthly` as `Primes maladie (LAMal)`
- Existing localization keys were reused; no ARB files changed.
- The screen test verifies the labels plus `2'400 CHF` and `390 CHF` from the
  synthetic data spine.

## Verification

- Red test confirmed the UI did not render fixed charges before implementation.
- `flutter test test/screens/mon_argent_screen_test.dart --plain-name 'uses MintState data spine budget before stored budget inputs'`
- `flutter test test/screens/mon_argent_screen_test.dart`
- `flutter analyze lib/screens/mon_argent/mon_argent_screen.dart test/screens/mon_argent_screen_test.dart`
