# CJT-018 Current AX Frame Audit — 2026-06-04

## Scope

Runtime audit on the current no-`Slider` production onboarding build. The goal
was to prove whether T6/T7/T8 ids expose valid lower iOS AX frames before tap,
instead of the old stale upper frame class around `x=67,y=205`.

## Probes

Evidence folder:
`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-current-ax-frame-audit-20260604T085000/`

The three probe flows were temporary evidence-only variants of S005, generated
from `tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml`
during the run and not retained in git:

- `probe-stop-t6.yaml`: stops before tapping `onboarding-insight-view`.
- `probe-stop-t7.yaml`: stops before tapping `onboarding-scene-continue`.
- `probe-stop-t8.yaml`: stops before tapping `onboarding-bifurcation-plus-tard`.

Each probe passed, then `idb ui describe-all --json` captured the iOS
accessibility tree.

## Results

| Step | Target id | AX frame | Verdict |
|---|---|---|---|
| T6 | `onboarding-insight-view` | `{{24, 589.5}, {354, 52}}` | lower visible button frame |
| T7 | `onboarding-scene-continue` | `{{24, 589.5}, {354, 52}}` | lower visible button frame |
| T8 | `onboarding-bifurcation-plus-tard` | `{{24, 593.5}, {354, 48}}` | lower visible button frame |

Current S005 also passed in the regression sweep:
`.planning/_walker/sweep-20260604T084055/bug__S005__landing_anonymous_cta_to_home/`.

## Interpretation

CJT-018's stale upper-frame class is not present on the current build for the
active lower CTA ids. The earlier rejected candidates remain valuable
provenance, but the current runtime evidence supports closing the active
onboarding AX/locator gate.

This closure is scoped to simulator runtime automation for the supported
onboarding path. It does not close CJT-015 signed TestFlight/Universal Link
evidence.
