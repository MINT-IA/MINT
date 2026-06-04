# Row 23 — Home Action Chip Fit Manual Simulator Proof — 2026-06-04

## Why Manual

The intended Maestro rerun of
`flow_row21_daily_return_attention_action.yaml` was blocked by the local Java
runtime before app interaction. Maestro loaded OpenJDK 25 and macOS rejected
`libextnet.dylib` by system policy. This is an environment failure, not a
product failure.

The app was still built and installed on the booted simulator, so this folder
contains a manual `simctl` screenshot for the narrow visual question: do Home
action chips still truncate `Explique-moi` / `Rassure-moi`?

## Commands

```bash
cd apps/mobile
flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_DISABLE_BETA_MODAL=true \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss

cd ../..
xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted ch.mint.app
xcrun simctl openurl booted mintapp:///home
xcrun simctl io booted screenshot \
  .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-home-action-chip-fit-manual-20260604/row23-home-action-chip-fit-manual.png
```

## Result

`row23-home-action-chip-fit-manual.png` shows:

- `Explique-moi` fully visible;
- `Simule` fully visible;
- `Rassure-moi` fully visible;
- no action-chip ellipsis on the iPhone-width Home viewport.

This is a visual proof only. Row 23 remains `PARTIAL` until runtime
accessibility/focus evidence exists.
