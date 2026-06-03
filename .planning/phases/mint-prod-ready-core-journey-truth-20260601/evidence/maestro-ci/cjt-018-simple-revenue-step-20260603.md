# CJT-018 Simple Revenue Step Probe — 2026-06-03

description: Runtime probe showing CJT-018 is triggered by the real `_RevenueStep` subtree rather than any T5-to-T6 shell transition.

## Hypothesis

After the skip-revenue and empty-interstitial matrices, the remaining high-value
question was whether the bad T6 iOS AX geometry is caused by the real
`_RevenueStep` subtree lifecycle or by any T5 -> T6 transition in the onboarding
shell.

## Probe Setup

Temporary code, reverted after the run:

- seeded `/onb` directly to T5 with intent, DOB, nationality, and canton;
- replaced the real `_RevenueStep` with a minimal T5 step using the same prompt,
  a static revenue display, and the same lower CTA id;
- exposed `onboarding-insight-view` temporarily on T6.

Probe folder:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-simple-revenue-step-20260603T224809/`

## Commands

```bash
flutter analyze lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart lib/screens/onboarding/mvp_wedge/onboarding_provider.dart
maestro check-syntax .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-simple-revenue-step-20260603T224809/flow-coordinate-t5.yaml
maestro test --udid B03E429D-0422-4357-B754-536637D979F9 --format junit --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-simple-revenue-step-20260603T224809/result.xml .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-simple-revenue-step-20260603T224809/flow-coordinate-t5.yaml
maestro test --udid B03E429D-0422-4357-B754-536637D979F9 --format junit --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-simple-revenue-step-20260603T224809/result-stop-before-t6-id.xml .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-simple-revenue-step-20260603T224809/flow-stop-before-t6-id.yaml
```

## Results

The first flow tapped T6 by id and advanced past T6. It then failed at the T7
`Continuer` assertion because the minimal probe did not write net monthly income,
so T7 correctly rendered the guard text `Il manque une donnée.`. The important
observation is that the T6 id tap did not stay stuck on `Avant de te montrer…`.

The stop-before-T6 flow passed and allowed `idb ui describe-all` to capture T6
before the id tap:

```text
AXUniqueId="onboarding-insight-view"
AXFrame="{{24, 620.5}, {354, 52}}"
AXLabel="Voir"
```

This matches the lower visible CTA geometry class and contrasts with the real
`_RevenueStep` path, which exposes the same id at roughly
`{{8,206.8},{118,17.3}}`.

## Conclusion

This confirms that CJT-018 is triggered by something inside the real
`_RevenueStep` subtree/lifecycle, not by the onboarding shell, the seeded T5
history, T5 coordinate activation, T6 layout, T6 id, or the dossier strip alone.

The next useful slice should isolate `_RevenueStep` internals one at a time
while keeping the minimal T5 control as the known-good baseline:

- add the `Slider` back into the simple T5;
- add the exact-mode `TextEditingController`/branch back;
- add the center `TextButton` back;
- add the min/max `Row` back;
- compare T6 `AXFrame` after each addition.

Do not ship the simple T5 step; it omits production data capture and only exists
as a root-cause probe.

## Post-Revert Current Build Check

After reverting all probe code, the current build passed S005 with the active
coordinate fallbacks:

```bash
maestro test --udid B03E429D-0422-4357-B754-536637D979F9 --format junit --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-post-simple-revenue-s005-current-build-20260603T225257/result.xml tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml
```

Result: `1/1 Flow Passed in 27s`.
