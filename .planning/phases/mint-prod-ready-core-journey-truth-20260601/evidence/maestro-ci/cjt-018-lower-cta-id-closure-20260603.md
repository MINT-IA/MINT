# CJT-018 Lower CTA ID Closure — 2026-06-03

## Scope

CJT-018 tracked the onboarding Maestro locator debt where T6/T7/T8 lower CTAs
could not be tapped reliably by accessibility id after the full onboarding
history.

This wave closes that debt for the active onboarding flows by removing the
remaining Flutter `Slider` controls from the MVP wedge sequence and replacing
the documented coordinate fallbacks with stable runtime ids.

## Production Changes

- `onboarding_shell_screen.dart`
  - T6 `Voir`: `onboarding-insight-view`
  - T7 `Continuer`: `onboarding-scene-continue`
  - T8 `Creuser`: `onboarding-bifurcation-creuser`
  - T8 `Plus tard`: `onboarding-bifurcation-plus-tard`
- `discrete_adjust_control.dart`
  - shared non-Slider plus/minus control for onboarding numeric adjustments.
- Scene sliders removed:
  - `MintSceneRenteTrouee`
  - `MintSceneCapaciteAchat`
  - `MintScene3aLevier`
- Maestro fallbacks removed from:
  - `tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml`
  - `tools/simulator/flows/maestro-perfect-set/flow_hero_marge_fiscale_3a.yaml`
  - `tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
  - `tools/simulator/flows/salvage01_retraite_onboarding_coach.yaml`

## Review Fixes

Subagent review found two medium issues before landing:

- age accessibility labels were localized around a French `ans` placeholder;
- the 3a control could hit CHF 7'258 then decrement by CHF 250 into irregular
  values.

Fixes:

- added `onboardingAdjustYearLabel` across six locales;
- kept the legal CHF 7'258 constant visible in copy, but bounded the discrete
  control to the nearest lower CHF 250 step derived from that constant;
- added a widget regression that renders all three scenes and asserts no
  `Slider` plus the expected discrete-control ids.

## Mechanical Proof

- `flutter gen-l10n`: passed.
- ARB parity MCP: `OK — 6 locale(s) parity (reference=fr, 6860 keys each)`.
- Accent MCP on new FR labels: clean.
- Banned-term MCP on new FR labels: clean.
- `python3 tools/checks/maestro_locator_audit.py`: passed, `35 flows`
  scanned, `366 locators`.
- `rg -n "Slider\(|RangeSlider\(|CupertinoSlider" apps/mobile/lib/screens/onboarding/mvp_wedge apps/mobile/test/screens/onboarding`: no matches.
- `flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart`:
  `15` tests passed.
- Targeted `flutter analyze` for modified onboarding files/tests: no issues.
- `flutter build ios --simulator --debug --no-codesign --dart-define=MINT_DISABLE_BETA_MODAL=true`: passed.

## Runtime Proof

Device: iPhone 17 Pro simulator
`B03E429D-0422-4357-B754-536637D979F9`.

Fresh build installed from `apps/mobile/build/ios/iphonesimulator/Runner.app`.

- S005 current-build proof:
  - flow: `tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml`
  - result: `1/1 Flow Passed in 27s`
  - artifact: `evidence/maestro-ci/cjt-018-s005-current-build-closure-20260603T234216/`
- Salvage01 current-build proof:
  - flow: `tools/simulator/flows/salvage01_retraite_onboarding_coach.yaml`
  - result: `1/1 Flow Passed in 46s`
  - artifact: `evidence/maestro-ci/cjt-018-salvage01-current-build-closure-20260603T234344/`
- Hero 3a current-build proof:
  - flow: `tools/simulator/flows/maestro-perfect-set/flow_hero_marge_fiscale_3a.yaml`
  - result: `1/1 Flow Passed in 1m`
  - artifact: `evidence/maestro-ci/cjt-018-hero-3a-current-build-20260603T234453/`

Supporting lower-id probes:

- `evidence/maestro-ci/cjt-018-lower-ids-proof-20260603T232017/`
- `evidence/maestro-ci/cjt-018-s005-id-closure-20260603T233111/`

## Non-CJT Follow-Up Found

The wider money-trust flow now fails after the onboarding/Coach path and budget
setup save:

- flow: `tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
- result: `1/1 Flow Failed in 1m13`
- failure: `id: budget_screen is visible`
- artifact: `evidence/maestro-ci/cjt-018-money-trust-current-build-20260603T234613/`
- runtime snapshot after failure showed the budget entry/setup surface:
  `Tes charges fixes, au clair.`

This is opened as CJT-024. It is not a CJT-018 locator failure because the same
flow had already passed onboarding T6/T7/T8 ids and reached `coach_input_field`.

## Verdict

CJT-018 is verified for the active onboarding lower-CTA locator debt on the
current simulator build. The remaining red discovered by the wider sweep is a
separate Money Trust budget restart/deep-link issue tracked under CJT-024.
