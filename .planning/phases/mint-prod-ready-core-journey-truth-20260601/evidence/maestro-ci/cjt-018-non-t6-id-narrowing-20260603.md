# CJT-018 non-T6 id narrowing — 2026-06-03

## Scope

Narrow the onboarding Maestro locator debt without reintroducing the rejected
T6 `onboarding-insight-view` semantics candidates.

## What changed

- `_PrimaryButton` can now expose a tested `Semantics.identifier` contract for
  selected upper onboarding CTAs.
- Stable ids were added only for:
  - `onboarding-entry-open`
  - `onboarding-dob-continue`
  - `onboarding-revenue-range-continue`
  - `onboarding-revenue-exact-continue`
- The S005 and perfect-set flows now use `id: onboarding-revenue-range-continue`.
- T6, T7, and T8 CTA taps remain coordinate fallbacks because live iOS AX
  hierarchy shows stale upper frames for those lower CTAs after the full
  onboarding history.

## Runtime findings

- Revenue screen hierarchy after full path exposed:
  `accessibilityText=Continuer; resource-id=onboarding-revenue-range-continue; bounds=[24,620][378,672]`.
- T7 scene CTA exposed `resource-id=onboarding-scene-continue` at stale
  bounds `[8,196][126,213]` while the visible CTA was near the bottom of the
  screen.
- T8 bifurcation CTA ids exposed stale bounds around `[8,177][126,213]` while
  visible buttons were near the bottom of the screen.
- The safe production posture for this wave is therefore:
  - use ids for proven upper CTAs;
  - avoid adding runtime ids to stale-frame lower CTAs;
  - keep documented coordinate fallbacks for T6/T7/T8 until the AX frame root
    cause is fixed.

## Verification

- `flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart --plain-name "primary CTAs expose stable non-T6 semantics identifiers"` passed.
- `maestro check-syntax` passed for:
  - `tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml`
  - `tools/simulator/flows/maestro-perfect-set/flow_hero_marge_fiscale_3a.yaml`
  - `tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
- `python3 tools/checks/maestro_locator_audit.py` passed (`35 flows`, `349 locators`).
- `build_run_sim` via XcodeBuildMCP passed on iPhone 17 Pro simulator
  `B03E429D-0422-4357-B754-536637D979F9`.
- S005 runtime proof passed:
  `evidence/maestro-ci/cjt-018-s005-current-build-20260603T212309/`.

## Remaining CJT-018 work

CJT-018 remains open. The next root-cause work is not more id swapping; it is
to isolate why the real `OnboardingShellScreen` lower CTA frames are retained
or transformed after the full step history while the revenue CTA frame is
correct.
