# CJT-018 T5 Slider AX Bisect — 2026-06-03

## Scope

Probe only. Production code was temporarily changed to:

- start the real `OnboardingShellScreen` at seeded T5 revenue when built with
  `MINT_CJT018_ONB_START_STEP=revenue_seeded`;
- expose the T6 `Voir` CTA as `Semantics.identifier =
  onboarding-insight-view`;
- exclude the T5 revenue `Slider` from semantics when built with
  `MINT_CJT018_EXCLUDE_REVENUE_SLIDER_SEMANTICS=true`.

No production flow was changed.

## Runtime Setup

- Simulator: iPhone 17 Pro
  `B03E429D-0422-4357-B754-536637D979F9`.
- Build tool: XcodeBuildMCP `build_run_sim`.
- Dart defines:
  - `MINT_DISABLE_BETA_MODAL=true`
  - `MINT_CJT018_ONB_START_STEP=revenue_seeded`
  - `MINT_CJT018_EXCLUDE_REVENUE_SLIDER_SEMANTICS=true`
- Build result: succeeded.
- Build log:
  `/Users/julienbattaglia/Library/Developer/XcodeBuildMCP/workspaces/MINT.nosync-f3c6e3d560e9/logs/build_run_sim_2026-06-03T19-50-35-705Z_pid7997_70031bed.log`

## Evidence

Artifact folder:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-t5-slider-ax-bisect-20260603Tprobe/`

`flow_stop_at_t6.yaml` passed through the revenue CTA and stopped at T6.

`idb-t6-after-slider-ax-off.txt` still showed the T6 id with upper,
scaled-down geometry:

```text
AXUniqueId="onboarding-insight-view"
AXFrame="{{8, 196.5}, {118, 17.333333333333343}}"
```

## Interpretation

This rejects the hypothesis that the T5 revenue `Slider` semantics alone poison
the next T6 CTA frame. Removing the slider from the AX tree did not move the T6
identifier back to the visible lower CTA.

The remaining root slice stays at the T5 revenue mutation/advance boundary, but
not specifically the slider's own semantics node.

## Code State

The temporary probe code was reverted after this report. A fresh XcodeBuildMCP
build without CJT-018 probe defines succeeded:

`/Users/julienbattaglia/Library/Developer/XcodeBuildMCP/workspaces/MINT.nosync-f3c6e3d560e9/logs/build_run_sim_2026-06-03T19-52-36-845Z_pid7997_b0f7ef02.log`

S005 then passed on that current build:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-post-slider-ax-s005-current-build-20260603T2153/result.xml`

Keep active coordinate fallbacks until a runtime-green structural fix proves
T5→T6, T7, and T8 lower CTA ids can be tapped at their visible locations.
