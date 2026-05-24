# Summary 20 — Mon Argent trajectory

## Shipped
- Added a Mon Argent trajectory surface backed by `DataSpineSnapshot.trajectory`.
- Rendered progress, target amount, current monthly free, monthly gap, and next-step copy.
- Reused existing localized labels to avoid i18n churn.

## Validation
- `flutter analyze lib/screens/mon_argent/mon_argent_screen.dart test/screens/mon_argent_screen_test.dart`
- `flutter test test/screens/mon_argent_screen_test.dart --plain-name 'uses MintState data spine budget before stored budget inputs'`
- `flutter test test/screens/mon_argent_screen_test.dart test/services/mint_state_engine_test.dart test/services/data_spine_service_test.dart`
- 5 design lints, `git diff --check`

