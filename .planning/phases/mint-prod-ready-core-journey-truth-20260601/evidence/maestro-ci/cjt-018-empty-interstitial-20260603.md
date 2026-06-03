# CJT-018 Empty Interstitial Rejection — 2026-06-03

description: Runtime probe testing whether a semantics-empty frame between T5 and T6 clears the bad iOS AX geometry.

## Hypothesis

After the skip-revenue matrix, the remaining suspect was a stale Flutter/iOS AX
transform after the real `_RevenueStep` lifecycle. This probe tested whether a
one-frame semantics-empty interstitial between T5 and T6 would clear that state.

## Probe Setup

Temporary code, reverted after the run:

- seeded `/onb` directly to T5 with intent, DOB, nationality, and canton;
- skipped revenue mutation;
- inserted `ExcludeSemantics(child: SizedBox.shrink())` as a one-frame step
  between T5 and T6;
- exposed `onboarding-insight-view` temporarily on T6.

Probe folder:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-empty-interstitial-20260603T223540/`

## Commands

```bash
flutter analyze lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart lib/screens/onboarding/mvp_wedge/onboarding_provider.dart
maestro check-syntax .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-empty-interstitial-20260603T223540/flow-coordinate-t5.yaml
maestro test --udid B03E429D-0422-4357-B754-536637D979F9 --format junit --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-empty-interstitial-20260603T223540/result.xml .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-empty-interstitial-20260603T223540/flow-coordinate-t5.yaml
```

## Result

Maestro failed before the T7 `Continuer` assertion:

```xml
<failure>Assertion is false: "Continuer" is visible</failure>
```

`idb ui describe-all` still exposed the T6 button at the same bad geometry:

```text
AXUniqueId="onboarding-insight-view"
AXFrame="{{8, 206.83333333333334}, {118, 17.333333333333343}}"
AXLabel="Voir"
```

## Conclusion

This rejects "a one-frame semantics-empty interstitial clears the bad AX frame"
as a sufficient mitigation. The problem is now narrower than simple cache
invalidation by an empty intermediate semantics tree. The remaining class is a
Flutter/iOS transform retention issue tied to leaving the real `_RevenueStep`
subtree.

Do not ship this interstitial pattern: it did not fix the frame and would add a
non-product lifecycle state to onboarding.

## Post-Revert Current Build Check

After reverting all probe code, the current build passed S005 with the active
coordinate fallbacks:

```bash
maestro test --udid B03E429D-0422-4357-B754-536637D979F9 --format junit --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-post-empty-interstitial-s005-current-build-20260603T223901/result.xml tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml
```

Result: `1/1 Flow Passed in 27s`.
