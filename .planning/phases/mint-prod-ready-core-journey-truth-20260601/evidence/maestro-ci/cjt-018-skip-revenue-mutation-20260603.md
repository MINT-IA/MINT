# CJT-018 Skip Revenue Mutation Matrix — 2026-06-03

description: Runtime matrix narrowing CJT-018 after seeded T5 revenue without revenue mutation.

## Hypothesis

The previous CJT-018 probes narrowed the bad iOS AX frame to the real
T5 revenue -> T6 insight transition. This matrix tested whether the trigger was
the revenue write itself, the T5 id tap, the artificial `Semantics(onTap)` owner,
or shared `_PrimaryButton` identity.

## Probe Setup

Temporary code, reverted after the run:

- seeded `/onb` directly to T5 revenue with intent, DOB, nationality, and canton;
- skipped `setNetMonthlyRange()` so T5 `Continuer` only advanced to T6;
- exposed `onboarding-insight-view` temporarily on T6;
- ran three variants:
  - mode A: current artificial owner (`Semantics(identifier, button, onTap)` +
    `ExcludeSemantics`);
  - mode A/control: T5 tapped by visible coordinates instead of id;
  - mode B: wrapper supplied only `identifier`, leaving the visible button as the
    native semantic owner;
  - mode C: T6 used a unique inline probe widget instead of shared
    `_PrimaryButton`.

Probe folder:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-skip-revenue-mutation-20260603T222046/`

## Commands

Static checks:

```bash
flutter analyze lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart lib/screens/onboarding/mvp_wedge/onboarding_provider.dart
maestro check-syntax .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-skip-revenue-mutation-20260603T222046/flow.yaml
maestro check-syntax .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-skip-revenue-mutation-20260603T222046/flow-coordinate-t5.yaml
```

Runtime checks:

```bash
maestro test --udid B03E429D-0422-4357-B754-536637D979F9 --format junit --output .../result.xml .../flow.yaml
maestro test --udid B03E429D-0422-4357-B754-536637D979F9 --format junit --output .../result-coordinate-t5.xml .../flow-coordinate-t5.yaml
maestro test --udid B03E429D-0422-4357-B754-536637D979F9 --format junit --output .../result-native-owner-coordinate-t5.xml .../flow-coordinate-t5.yaml
maestro test --udid B03E429D-0422-4357-B754-536637D979F9 --format junit --output .../result-unique-inline-coordinate-t5.xml .../flow-coordinate-t5.yaml
```

## Results

All three T6 id-tap variants failed before the T7 `Continuer` assertion.

| Variant | Result | AX observation |
|---|---:|---|
| mode A, T5 id tap, no revenue mutation | failed | `onboarding-insight-view` at `{{8, 206.8333}, {118, 17.3333}}` |
| mode A, T5 coordinate tap, no revenue mutation | failed | `onboarding-insight-view` at `{{8, 206.8333}, {118, 17.3333}}` |
| mode B, native owner, T5 coordinate tap | failed | `Voir` still at `{{8, 206.8333}, {118, 17.3333}}`; id absent |
| mode C, unique inline T6 widget, T5 coordinate tap | failed | `onboarding-insight-view` at `{{8, 206.8333}, {118, 17.3333}}` |

Direct-T6 control from the earlier probe remains the contrast point:
`{{24, 589.5}, {354, 52}}`.

## Conclusion

This matrix rejects these root hypotheses:

- revenue write / dossier revenue mutation as the trigger;
- T5 activation by id as the trigger;
- artificial `Semantics(onTap)` owner as the sole trigger;
- shared `_PrimaryButton` identity as the trigger.

The remaining slice is narrower: the real `_RevenueStep` lifecycle/teardown
after T5 leaves the next step's iOS AX geometry scaled by device scale, even
when no revenue data is written and T5 is tapped by visible coordinates.

## Follow-Up

Next useful probe: insert a reversible semantics-empty interstitial between T5
and T6, then compare the T6 AX frame. If the frame becomes lower/correct, the
fix target is AX cache invalidation across step replacement. If it stays
scaled, investigate Flutter/iOS transform retention tied to the real revenue
step subtree.

The active production S005 flow must keep coordinate fallbacks for T6/T7/T8
until the full path exposes lower CTA frames and id taps advance to
`Aujourd'hui`, `card_cap_du_jour`, and `mint_card_action_bar`.

## Post-Revert Current Build Check

After reverting all probe code, the current build passed S005 with the active
coordinate fallbacks:

```bash
maestro test --udid B03E429D-0422-4357-B754-536637D979F9 --format junit --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-post-skip-revenue-s005-current-build-20260603T223058/result.xml tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml
```

Result: `1/1 Flow Passed in 27s`.
