# Phase 20 — Verification

## Red
```bash
cd apps/mobile
flutter test test/domain/budget/budget_service_test.dart
```

Initial failures added during TDD:
- `isHousingMissing` / `isHealthMissing` did not exist.
- User-provided LAMal without `dataSources` was tagged as estimated.
- `ProfileDataSource.estimated` LAMal was dropped instead of marked estimated.
- Legacy maps without housing were treated as not missing.

## Green
```bash
cd apps/mobile
flutter test test/domain/budget/budget_service_test.dart test/data/budget/budget_local_store_test.dart test/providers/budget/budget_provider_test.dart test/screens/budget_setup_screen_test.dart
flutter test test/screens/mon_argent_screen_test.dart test/domain/budget/budget_service_test.dart test/data/budget/budget_local_store_test.dart test/providers/budget/budget_provider_test.dart test/screens/budget_setup_screen_test.dart
dart analyze lib/app.dart lib/domain/budget/budget_inputs.dart lib/screens/budget/budget_screen.dart lib/screens/mon_argent/mon_argent_screen.dart test/domain/budget/budget_service_test.dart test/data/budget/budget_local_store_test.dart test/providers/budget/budget_provider_test.dart test/screens/mon_argent_screen_test.dart
git diff --check
```

Result:
- Combined targeted suite passed: 103 tests.
- Targeted Dart analyzer passed with no issues.
- Diff whitespace check passed.

## Runtime
```bash
xattr -cr apps/mobile/build/ios/Debug-iphonesimulator/Flutter.framework apps/mobile/build/ios/Debug-iphonesimulator/App.framework 2>/dev/null || true
bash apps/mobile/ios/strip_provenance.sh apps/mobile/build/ios/Debug-iphonesimulator || true
cd apps/mobile
flutter build ios --simulator --debug --no-codesign --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true
cd ../..
xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app
MAESTRO_HARD_LIMIT=900 MAESTRO_STALL_THRESHOLD=120 bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml
```

Result:
- Simulator build passed after stripping xattrs/signatures from generated
  frameworks.
- Maestro passed with exit code 0.
- Artifact directory:
  `.planning/_walker/20260526T124006`.
