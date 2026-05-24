description: Plan 24 added an investments row to Mon Argent's situation map with widget coverage.

# Plan 24 — Summary

## Changed

- Mon Argent now displays `situation.investments` as `Investissements` in the
  situation map.
- The existing `financialSummaryInvestissements` localization key is reused;
  no ARB files changed.
- The screen test verifies the label and the `12'000 CHF` value from the
  synthetic data spine.

## Verification

- Red test confirmed the UI did not render investments before implementation.
- `flutter test test/screens/mon_argent_screen_test.dart --plain-name 'uses MintState data spine budget before stored budget inputs'`
- `flutter test test/screens/mon_argent_screen_test.dart`
- `flutter analyze lib/screens/mon_argent/mon_argent_screen.dart test/screens/mon_argent_screen_test.dart`
