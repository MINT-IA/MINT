# Scan Recovery Maestro Evidence — 2026-07-09

## Scope

- `apps/mobile/.maestro/r1_scan_review.yaml`
- `apps/mobile/.maestro/r2_scan_impact.yaml`
- Device: iPhone 17 Pro simulator (`B03E429D-0422-4357-B754-536637D979F9`), iOS 26.2
- App bundle: `ch.mint.app`

## Build And Install

```bash
cd apps/mobile
flutter build ios --simulator --debug
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted ch.mint.app
```

Result:

```text
✓ Built build/ios/iphonesimulator/Runner.app
Installed at .../Runner.app
```

## Runtime Proof

```bash
maestro test --format JUNIT \
  --output /tmp/mint_scan_maestro_final.xml \
  --no-reinstall-driver \
  apps/mobile/.maestro/r1_scan_review.yaml \
  apps/mobile/.maestro/r2_scan_impact.yaml
```

Result:

```text
[Passed] r1_scan_review (5s)
[Passed] r2_scan_impact (5s)

2/2 Flows Passed in 10s
```

## Notes

- First run against the previously installed app failed because the build did not include the new semantics identifiers.
- After installing this worktree's build, R-2 passed and R-1 required a destination assertion aligned to the actual scan screen (`Prendre une photo`).
