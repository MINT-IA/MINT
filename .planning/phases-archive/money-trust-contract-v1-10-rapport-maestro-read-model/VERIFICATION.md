# Phase 10 Verification — Rapport Maestro Read-Model Gate

## Static Checks

```bash
python3 tools/checks/maestro_locator_audit.py --strict
```

Result: pass. Note: this audit currently scans only the configured top-level
subset, not every nested `maestro-perfect-set` flow. The new flow should still
be run directly.

## Runtime Check

```bash
cd apps/mobile
xattr -cr build/ios ios 2>/dev/null || true
flutter build ios --simulator --debug \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true

cd ../..
xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app
bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_rapport_budget_read_model_spine.yaml
```

Result: pass. Artifacts:

- `.planning/_walker/20260526T065903/maestro.log`
- Maestro screenshot: `rapport-01-budget-read-model`

Note: the first simulator build failed because `App.framework/App` had extended
attributes / Finder metadata. `xattr -cr apps/mobile/build/ios apps/mobile/ios`
cleared the codesign blocker and the simulator build then passed.
