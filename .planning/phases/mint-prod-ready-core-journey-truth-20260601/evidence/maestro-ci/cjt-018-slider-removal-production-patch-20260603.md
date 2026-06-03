# CJT-018 Slider Removal Production Patch — 2026-06-03

description: Production patch replacing the T5 revenue `Slider` with a discrete non-Slider control, with widget/analyze/i18n checks and S005 runtime proof.

## Context

The previous `cjt-018-simple-revenue-slider` probe showed that adding only a
Flutter `Slider` to the known-good minimal T5 revenue step reintroduced the bad
T6 iOS AX geometry:

```text
AXFrame="{{8, 206.83333333333334}, {118, 17.333333333333343}}"
```

The production patch therefore removes the real T5 `Slider` from
`_RevenueStep` and replaces it with ordinary decrement/increment buttons. It
preserves the existing revenue contract:

- default lower bound: `7000`;
- step size: `500`;
- `_rangeFor(v)` remains `v` to `v + 500`;
- `onboarding-revenue-range-continue` still writes
  `setNetMonthlyRange(range.low, range.high)`;
- exact-entry mode is unchanged.

T6/T7/T8 coordinate fallbacks remain in S005 for this wave. Re-introducing
lower CTA semantic ids is a separate proof step.

## Code-Level Checks

```bash
flutter gen-l10n
flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart --plain-name 'CJT-018: revenue range uses discrete controls, not Slider'
flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart --plain-name 'primary CTAs expose stable non-T6 semantics identifiers'
flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart
flutter analyze lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart test/screens/onboarding/mvp_wedge_storyboard_test.dart
```

Results:

- targeted CJT-018 widget test: passed;
- non-T6 semantics contract test: passed;
- full onboarding storyboard file: `14` tests passed;
- targeted Flutter analyze: no issues.

## i18n / Compliance Checks

The replacement adds no new visible copy. It adds ARB-only accessibility labels
for the revenue decrement/increment controls and the selected range.

```text
validate_arb_parity -> OK — 6 locale(s) parity (reference=fr, 6856 keys each)
check_accent_patterns -> clean
check_banned_terms -> clean
```

## Runtime Proof

Fresh iOS simulator build:

```bash
cd apps/mobile
flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Result:

```text
✓ Built build/ios/iphonesimulator/Runner.app
```

Install and launch:

```bash
xcrun simctl terminate booted ch.mint.app >/dev/null 2>&1 || true
xcrun simctl uninstall booted ch.mint.app >/dev/null 2>&1 || true
xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted ch.mint.app
```

Runtime S005 command:

```bash
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-slider-removal-s005-20260603T231451 \
MAESTRO_HARD_LIMIT=420 \
MAESTRO_STALL_THRESHOLD=75 \
bash tools/simulator/maestro_with_watchdog.sh test \
  --udid B03E429D-0422-4357-B754-536637D979F9 \
  --debug-output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-slider-removal-s005-20260603T231451/debug \
  --format junit \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-slider-removal-s005-20260603T231451/result.xml \
  tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml
```

Result:

```text
[Passed] bug__S005__landing_anonymous_cta_to_home (27s)
1/1 Flow Passed in 27s
```

JUnit:

```xml
<testsuite name="Test Suite" device="iPhone 17 Pro - iOS 26.2 - B03E429D-0422-4357-B754-536637D979F9" tests="1" failures="0" time="27.0">
```

## Conclusion

The production T5 revenue step no longer contains a `Slider`, keeps the same
range data contract, has localized accessibility labels for the new discrete
controls, and still passes the public S005 path with the existing coordinate
fallbacks.

CJT-018 is not fully closed by this wave. The next wave should add explicit
T6/T7/T8 semantic identifiers and prove with `idb ui describe-all` plus Maestro
`id:` taps that the lower CTA frames are visible-button frames before removing
coordinate fallbacks from S005/perfect-set flows.
