# CJT-018 Simple Revenue Slider Probe — 2026-06-03

description: Runtime probe showing that adding a Flutter `Slider` back to the known-good minimal T5 reintroduces the bad T6 iOS AX geometry.

## Hypothesis

The simple revenue step probe showed that a minimal T5 step in the real
onboarding shell exposes a correct T6 `onboarding-insight-view` frame. This
probe added only the Flutter `Slider` back into that known-good baseline to
test whether the slider subtree is enough to trigger CJT-018.

## Probe Setup

Temporary code, reverted after the run:

- seeded `/onb` directly to T5 with intent, DOB, nationality, and canton;
- replaced the real `_RevenueStep` with a simple T5 step containing:
  - the same prompt;
  - the range headline;
  - a Flutter `Slider`;
  - the lower `onboarding-revenue-range-continue` CTA;
- exposed `onboarding-insight-view` temporarily on T6.

Probe folder:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-simple-revenue-slider-20260603T225644/`

## Commands

```bash
flutter analyze lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart lib/screens/onboarding/mvp_wedge/onboarding_provider.dart
maestro check-syntax .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-simple-revenue-slider-20260603T225644/flow-stop-before-t6-id.yaml
maestro test --udid B03E429D-0422-4357-B754-536637D979F9 --format junit --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-simple-revenue-slider-20260603T225644/result-stop-before-t6-id.xml .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-simple-revenue-slider-20260603T225644/flow-stop-before-t6-id.yaml
```

## Result

The stop-before-T6 flow passed, then `idb ui describe-all` showed the bad frame:

```text
AXUniqueId="onboarding-insight-view"
AXFrame="{{8, 206.83333333333334}, {118, 17.333333333333343}}"
AXLabel="Voir"
```

This is the same bad geometry class seen with the real `_RevenueStep`, and it
contrasts with the known-good minimal T5 frame:

```text
AXFrame="{{24, 620.5}, {354, 52}}"
```

## Conclusion

Adding the Flutter `Slider` back to the minimal T5 baseline is sufficient to
reintroduce CJT-018's bad T6 iOS AX geometry. The root slice is now narrower
than the full `_RevenueStep`: it is tied to the outgoing slider subtree or to a
Flutter/iOS transform side effect caused by that slider.

This does not contradict the earlier "exclude slider semantics" rejection: that
probe removed the slider from semantics in the full production T5, while this
probe shows the slider widget/layout itself is enough to poison the next T6
frame when added to a known-good baseline.

Next useful proof: test a production-shaped, non-`Slider` stepped control for
the same revenue range interaction. If T6 stays correct, replace the slider with
that accessible control behind a small, reviewed production patch; if it stays
bad, inspect other stateful/gesture layers around the control.

## Post-Revert Current Build Check

After reverting all probe code, the current build passed S005 with the active
coordinate fallbacks:

```bash
maestro test --udid B03E429D-0422-4357-B754-536637D979F9 --format junit --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-post-slider-trigger-s005-current-build-20260603T230034/result.xml tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml
```

Result: `1/1 Flow Passed in 27s`.
