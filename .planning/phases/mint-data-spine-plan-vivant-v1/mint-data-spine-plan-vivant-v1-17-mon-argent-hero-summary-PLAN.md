Plan 17 makes the Mon argent data spine visible above the legacy cards.

## Goal

Add a compact summary surface that shows monthly free cash, confidence, and net patrimoine from `MintUserState.dataSpineSnapshot`.

## Contract

When the data spine is ready, Mon argent must show the central snapshot before the user opens detailed cards. The screen keeps the existing budget and patrimoine cards as drill-down surfaces.

## Verification

- `flutter test test/screens/mon_argent_screen_test.dart --plain-name 'uses MintState data spine budget before stored budget inputs'`
- `flutter test test/screens/mon_argent_screen_test.dart test/services/mint_state_engine_test.dart test/services/data_spine_service_test.dart`
- `flutter analyze lib/screens/mon_argent/mon_argent_screen.dart test/screens/mon_argent_screen_test.dart`
- Five design lints: color token, text style, fonts, radius, CTA
