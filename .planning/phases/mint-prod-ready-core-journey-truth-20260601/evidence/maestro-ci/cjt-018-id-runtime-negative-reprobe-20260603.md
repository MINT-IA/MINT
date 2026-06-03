# CJT-018 — ID tap runtime negative reprobe

Date: 2026-06-03
Branch: `qa/runtime-navigation-spine-20260602`

## Scope

Re-tested the onboarding CTA accessibility debt after a fresh local patch attempt that exposed `_PrimaryButton` keys as `Semantics(identifier:)` and replaced S005/perfect-set coordinate fallbacks with `id:` taps.

This patch was **not kept** because runtime iOS proof remained red.

## Commands

Static proof during the attempt:

- `cd apps/mobile && flutter analyze lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart test/screens/onboarding/mvp_wedge_storyboard_test.dart` -> passed.
- `cd apps/mobile && flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart --plain-name "primary CTA exposes stable semantics identifier" --reporter=expanded` -> passed.
- `cd apps/mobile && flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart --reporter=expanded` -> passed, `13 passed`.
- `python3 tools/checks/maestro_locator_audit.py` -> passed, `35 flows`, `363 locators`.

Runtime proof:

- Built fresh simulator binary: `cd apps/mobile && flutter build ios --simulator --debug --dart-define=MINT_DISABLE_BETA_MODAL=true` -> built `build/ios/iphonesimulator/Runner.app`.
- Installed on booted iPhone 17 Pro simulator: `xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app`.
- Ran S005 with `id:` taps: `MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=90 bash tools/simulator/maestro_with_watchdog.sh test --format junit --output <evidence>/result.xml tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml`.

Evidence directory:

- `.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-s005-id-runtime-20260603T082506/`

## Result

S005 failed:

- JUnit: `tests=1`, `failures=1`
- Exit code: `1`
- Failure: `Assertion is false: ".*Aujourd'hui.*" is visible`

Runtime inspection after failure:

- `snapshot_ui` showed the app stuck on `Avant de te montrer...`.
- The target list contained `onboarding-insight-view` with label `Voir`.
- Tapping the runtime elementRef tapped at `x=67,y=205` and did not advance the app.
- Screenshot: `stuck-on-insight-after-id-tap.jpg`.

This reproduces the same bad geometry documented on 2026-06-02: the iOS accessibility target exists, but its activation point is on the upper card/text area, not on the visible lower CTA.

## Decision

Do not close CJT-018 from widget semantics tests or locator audit.

The attempted production-code and Maestro-flow edits were reverted. Active S005/perfect-set flows must keep the documented coordinate fallbacks until a layout-level fix is runtime-proven.

## Follow-up Variant Rejected

After the first negative reprobe, a stricter `_PrimaryButton` wrapper was tried with `Semantics(container: true, identifier:, label:, button:, enabled:, onTap:)` around the full `SizedBox` and `ExcludeSemantics` around the visual `FilledButton`.

Static proof stayed green:

- `cd apps/mobile && flutter analyze lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart` -> passed.
- `cd apps/mobile && flutter build ios --simulator --debug --dart-define=MINT_DISABLE_BETA_MODAL=true` -> built after stopping the running app and removing the stale simulator bundle.

Runtime proof stayed red:

- Evidence: `.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-container-semantics-probe-20260603T083422/`
- JUnit: `tests=1`, `failures=1`
- Exit code: `1`
- Failure: `Assertion is false: ".*Aujourd'hui.*" is visible`
- `snapshot_ui` still showed `onboarding-insight-view` on `Avant de te montrer...`.
- MCP still tapped the target at `x=67,y=205` and the app did not advance.

This rejects both the non-container and container Semantics-wrapper variants. The next credible fix must change layout geometry, not only Semantics metadata.

Next credible slice: change the onboarding layout so bottom CTAs live in a stable bottom slot outside the `AnimatedSwitcher` step subtree / `Expanded` content, then re-run this exact S005 proof and capture a fresh `snapshot_ui` where `onboarding-insight-view` taps the visible lower button.
