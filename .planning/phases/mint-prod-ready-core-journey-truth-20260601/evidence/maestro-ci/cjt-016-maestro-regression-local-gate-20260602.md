---
description: CJT-016 local Maestro regression gate proof for the Core Journey Truth mission.
date: 2026-06-02
status: verified-local-gate
---

# CJT-016 — Maestro Regression Local Gate

## Scope

This closes CJT-016 as a repeatable local regression gate, not as a
GitHub PR-blocking Maestro workflow and not as signed device evidence.

The CI workflow named in `tools/simulator/flows/regression/_INDEX.md`
(`.github/workflows/maestro-regression.yml`) is still future/TBD. The
current release-safe gate is the existing local sweep harness:

```bash
MAESTRO_HARD_LIMIT=600 MAESTRO_STALL_THRESHOLD=90 \
  tools/simulator/maestro_sweep.sh --tier regression
```

## Build Under Test

The app was built from the current branch files at
`2c75e8aae7038052450955cc5693242455e0c5a3` plus the local S005 flow
selector fix in `tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml`.

The normal in-repo simulator build failed locally because macOS extended
attributes under the Desktop workspace caused iOS simulator codesign to
reject `App.framework`:

```text
Failed to codesign .../App.framework/App with identity -.
resource fork, Finder information, or similar detritus not allowed
Disallowed xattr com.apple.FinderInfo found on .../App.framework
```

To isolate QA from this local metadata issue, the same mobile source was
copied to `/tmp/mint_mobile_build_src`, cleaned with `xattr -cr`, and
built there:

```bash
rsync -a --delete --exclude='.git' --exclude='build' --exclude='.dart_tool' \
  --exclude='.packages' apps/mobile/ /tmp/mint_mobile_build_src/
xattr -cr /tmp/mint_mobile_build_src
cd /tmp/mint_mobile_build_src
flutter build ios --simulator --debug \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Build result:

```text
Xcode build done. 43.0s
Built build/ios/iphonesimulator/Runner.app
```

Install / launch:

```bash
xcrun simctl uninstall booted ch.mint.app
xcrun simctl install booted /tmp/mint_mobile_build_src/build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted ch.mint.app
```

## Red Then Fix

Initial sweep:

```text
Sweep: .planning/_walker/sweep-20260602T200259/
Green: 5 / 6
Red: 1 / 6
```

Red flow:

```text
bug__S005__landing_anonymous_cta_to_home
Assertion '".*Aujourd'hui.*" is visible' failed.
```

Failure evidence:

- `.planning/_walker/sweep-20260602T200259/sweep-summary.md`
- `.planning/_walker/sweep-20260602T200259/bug__S005__landing_anonymous_cta_to_home/last-screen.png`
- `.planning/_walker/sweep-20260602T200259/bug__S005__landing_anonymous_cta_to_home/maestro.log`

Root cause: S005 still used coordinate taps for the iOS date picker.
The failure screenshot showed the user stuck on
`Quelle est ta date de naissance ?` with `Continuer` disabled. The
product code was already date-of-birth based:

- `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart`
  stores a selected `_dateOfBirth` and disables `Continuer` until set.
- `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart`
  writes both `q_date_of_birth` and `q_birth_year` during completion.

Fix: update S005 to reuse the CJT-020-proven iOS AX selector pattern:
open `Choisir ma date`, wait for `OK`, tap `.*15.*juillet.*1992.*`,
confirm, assert `15.07.1992`, then continue.

Targeted proof after fix:

```bash
MINT_WALKER_ARTIFACTS=.planning/_walker/cjt-016-s005-rerun-20260602T200850 \
  MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=75 \
  tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml
```

Result:

```text
Assert that "15.07.1992" is visible... COMPLETED
Assert that ".*Aujourd'hui.*" is visible... COMPLETED
Assert that id: card_cap_du_jour is visible... COMPLETED
Assert that id: mint_card_action_bar is visible... COMPLETED
[watchdog] EXIT — maestro returned 0
```

## Final Sweep

Final command:

```bash
MAESTRO_HARD_LIMIT=600 MAESTRO_STALL_THRESHOLD=90 \
  tools/simulator/maestro_sweep.sh --tier regression
```

Final artifact directory:

```text
.planning/_walker/sweep-20260602T200945/
```

Final summary:

```text
Green:   6 / 6
Red:     0 / 6
Stalled: 0 / 6
Hard:    0 / 6
```

Flows covered:

- `bug__S005__landing_anonymous_cta_to_home`
- `bug__F001__chat_input_bar_exists`
- `bug__S001__cap_du_jour_action_bar_reachable`
- `bug__S002__maestro_cold_launch_fragment`
- `bug__P004__overlay_populated_on_open`
- `bug__F001_S001_combined__chat_via_cap_du_jour`

Primary evidence:

- `.planning/_walker/sweep-20260602T200945/sweep-summary.md`
- `.planning/_walker/sweep-20260602T200945/bug__S005__landing_anonymous_cta_to_home/maestro.log`
- `.planning/_walker/cjt-016-s005-rerun-20260602T200850/maestro.log`

## Remaining QA Boundary

This proof does not close:

- CJT-015: signed device/TestFlight deep-link and Universal Link proof.
- CJT-018: broader point-tap debt in remaining Maestro flows.
- FATCA/expat tier: requires a dedicated expat_us build.

