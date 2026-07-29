# Phase 40 — Verification

## Red Test

```sh
flutter test test/screens/mon_argent_screen_test.dart \
  --name 'exposes Maestro semantics anchors for central money surfaces'
```

Initial result: failed because the new group semantics anchors did not exist.

## Green Tests

```sh
flutter test test/screens/mon_argent_screen_test.dart \
  --name 'exposes Maestro semantics anchors for central money surfaces'
```

Result: pass.

```sh
flutter test \
  test/screens/mon_argent_screen_test.dart \
  test/widgets/mon_argent_budget_summary_card_test.dart
```

Result: `11` tests passed.

```sh
flutter analyze \
  lib/screens/mon_argent/mon_argent_screen.dart \
  test/screens/mon_argent_screen_test.dart
```

Result: no issues.

## Build and Maestro

```sh
xattr -cr build/ios ios/Flutter
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Result: build passed.

```sh
MAESTRO_HARD_LIMIT=300 MAESTRO_STALL_THRESHOLD=90 \
  bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml
```

Result: Maestro exit `0`.
