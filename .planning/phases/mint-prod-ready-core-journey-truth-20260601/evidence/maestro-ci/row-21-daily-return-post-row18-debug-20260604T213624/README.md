# Row 21 runtime non-regression after Row 18 action completion work

This evidence reruns the existing Row 21 daily-return attention/action Maestro
flow after the Row 18 surfaced-commitment completion lot.

## Scope

This is a non-regression proof only. It confirms that the `Aujourd'hui`
first attention/action surface still opens on the iPhone 17 Pro simulator, the
Cap du jour action identifiers remain reachable, tapping `Simule` still avoids
the Coach overlay, and the app routes to Explorer.

It does not close Row 21. The remaining Row 21 gap is still the full stateful
loop: complete or acknowledge an action, persist that state, restart, and show
the next correct daily priority.

## Build and install

The first plain simulator build failed because the repo lives under
`MINT.nosync` and Xcode hit the known macOS Tahoe/FileProvider codesign path:
resource fork / Finder information detritus on generated simulator bundles.

The passing build used the existing MINT simulator doctrine:

```bash
cd apps/mobile
BUILT_PRODUCTS_DIR="$PWD/build/ios/Debug-iphonesimulator" bash ios/strip_provenance.sh
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
cd ../..
timeout 60s xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app
```

Result: build succeeded and install returned exit code `0`.

## Maestro

```bash
FLOW=tools/simulator/flows/maestro-perfect-set/flow_row21_daily_return_attention_action.yaml
EVIDENCE=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-21-daily-return-post-row18-debug-20260604T213624
MAESTRO_HARD_LIMIT=360 MAESTRO_STALL_THRESHOLD=120 MINT_WALKER_ARTIFACTS="$EVIDENCE" \
  bash tools/simulator/maestro_with_watchdog.sh test \
    --format junit \
    --debug-output "$EVIDENCE/debug" \
    --output "$EVIDENCE/result.xml" \
    "$FLOW"
```

Result:

- Device: iPhone 17 Pro iOS 26.2, `B03E429D-0422-4357-B754-536637D979F9`
- JUnit: `tests=1`, `failures=0`, `time=21.0`
- Watchdog: `EXIT`, Maestro returned `0`

## Artifacts

- `result.xml` — JUnit success for `flow_row21_daily_return_attention_action`
- `debug/.maestro/tests/2026-06-04_213626/commands-(flow_row21_daily_return_attention_action).json` — command trace proving the stable ids and route assertions completed
- `maestro.log` and debug log exist locally but are ignored by Git

Note: unlike the earlier Row 21 evidence run, this pass did not copy
`takeScreenshot` images into the evidence directory. Treat this as JUnit plus
command-trace runtime evidence, not screenshot evidence.
