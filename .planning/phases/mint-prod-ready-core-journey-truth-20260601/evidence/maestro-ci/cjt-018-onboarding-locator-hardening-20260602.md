# CJT-018 — Onboarding locator hardening probe

Date: 2026-06-02  
Branch: `qa/runtime-navigation-spine-20260602`

## Scope

CJT-018 tracks Maestro locator debt where flows depend on fragile text or
coordinate taps. This probe focused on the active onboarding path used by:

- `tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml`
- `tools/simulator/flows/maestro-perfect-set/flow_hero_marge_fiscale_3a.yaml`
- `tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`

## Changes Under Test

- Added stable semantics identifiers for onboarding intent cards:
  `onboarding-intent-retraite`, `onboarding-intent-achat`,
  `onboarding-intent-impots`, `onboarding-intent-explorer`.
- Added stable semantics identifiers for canton cells, including
  `onboarding-canton-vd`.
- Replaced active onboarding point taps in the scoped Maestro flows with
  semantic ids where runtime-verified (`intent`, `canton`). CTA coordinate
  fallbacks remain intentionally in place because the runtime exposed an iOS
  AX-frame bug.

## Static Gates

Passed:

```sh
cd apps/mobile
dart format lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart test/screens/onboarding/mvp_wedge_storyboard_test.dart
flutter analyze lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart
flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart
cd ..
python3 tools/checks/maestro_locator_audit.py
rg -n "point:" tools/simulator/flows/maestro-perfect-set tools/simulator/flows/regression -S
```

Results:

- Storyboard test passed: `12 passed`.
- Analyzer: `No issues found`.
- Locator audit: passed, `35 flows / 345 locators`.
- `point:` remains in active onboarding CTA fallbacks plus two historical
  drawer comments. This is the remaining CJT-018 work, not a closed gate.

## Runtime Findings

S005 was rerun against a freshly built iOS simulator app on:

- Simulator: `iPhone 17 Pro`, iOS `26.2`, UDID
  `B03E429D-0422-4357-B754-536637D979F9`
- Backend defines:
  `BACKEND_URL=https://mint-backend-staging.up.railway.app`
  and `API_BASE_URL=https://mint-backend-staging.up.railway.app`

Observed runs:

- `.planning/_walker/cjt-018-s005-20260602T223615/maestro.log`
- `.planning/_walker/cjt-018-s005-20260602T223846/maestro.log`
- `.planning/_walker/cjt-018-s005-20260602T224514/maestro.log`
- `.planning/_walker/cjt-018-s005-20260602T224858/maestro.log`

All attempted non-coordinate CTA runs failed in the same place:

1. `onboarding-canton-vd` succeeds and advances the flow.
2. Revenue `Continuer` succeeds and reaches the insight screen.
3. `Voir` is reported by Maestro as `COMPLETED`.
4. The app remains on `Avant de te montrer...`.
5. The next `Continuer` and `Plus tard` conditional steps are skipped.
6. Final S005 assertion `.*Aujourd'hui.*` fails.

The latest Maestro debug hierarchy confirms the problem is not a missing
identifier:

```text
accessibilityText = "Voir"
bounds = "[8,196][126,213]"
resource-id = "onboarding-insight-view"
```

`idb ui describe-all --udid B03E429D-0422-4357-B754-536637D979F9` independently
reports the same invalid AX frame:

```text
AXUniqueId: onboarding-insight-view
AXLabel: Voir
AXFrame: {{8, 196.5}, {118, 17.333333333333343}}
```

The visible button is rendered near the lower part of the screen, above
`DossierStrip`; the AX frame points near the top content area. xcodebuildmcp
therefore taps `x=67,y=205`, which does not activate the visible CTA.

After restoring CTA coordinate fallbacks, the final S005 run passed:

```text
.planning/_walker/cjt-018-s005-final-20260602T225704/maestro.log
Assert that ".*Aujourd'hui.*" is visible... COMPLETED
Assert that id: card_cap_du_jour is visible... COMPLETED
Assert that id: mint_card_action_bar is visible... COMPLETED
[watchdog] EXIT — maestro returned 0
```

This keeps the regression gate runnable while the product-side AX frame bug
remains open.

## Status

CJT-018 is not closed.

What is now proven:

- Intent and canton locator debt is reduced and runtime-proven for `VD`.
- Onboarding primary CTAs still have an iOS accessibility-frame defect that
  blocks non-coordinate Maestro progression.
- S005 remains green via documented CTA coordinate fallbacks.

Next work:

- Fix the Flutter/iOS AX frame for `_PrimaryButton` inside the onboarding
  MVP wedge.
- Rerun S005 until `Aujourd'hui`, `card_cap_du_jour`, and
  `mint_card_action_bar` pass.
- Then rerun the two affected perfect-set flows before marking CJT-018
  verified.
