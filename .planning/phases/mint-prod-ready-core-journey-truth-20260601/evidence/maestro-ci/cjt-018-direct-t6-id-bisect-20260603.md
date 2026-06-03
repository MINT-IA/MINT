# CJT-018 Direct T6 ID Bisect — 2026-06-03

## Scope

Probe only. Production code was temporarily changed to:

- start the real `OnboardingShellScreen` directly at T6 insight when built
  with `MINT_CJT018_ONB_START_STEP=insight_seeded`;
- pre-seed intent, nationality, DOB, canton, and revenue;
- expose the T6 `Voir` CTA as `Semantics.identifier =
  onboarding-insight-view`.

No production flow was changed.

## Runtime Setup

- Simulator: iPhone 17 Pro
  `B03E429D-0422-4357-B754-536637D979F9`.
- Build tool: XcodeBuildMCP `build_run_sim`.
- Dart defines:
  - `MINT_DISABLE_BETA_MODAL=true`
  - `MINT_CJT018_ONB_START_STEP=insight_seeded`
- Build result: succeeded.
- Build log:
  `/Users/julienbattaglia/Library/Developer/XcodeBuildMCP/workspaces/MINT.nosync-f3c6e3d560e9/logs/build_run_sim_2026-06-03T19-43-53-303Z_pid7997_0636de01.log`

## Evidence

Artifact folder:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-direct-t6-id-bisect-20260603Tprobe/`

`flow_stop_at_t6_direct.yaml` passed and stopped on the seeded T6 screen.

`idb-direct-t6-before-tap.txt` showed correct lower geometry for the T6 id:

```text
AXUniqueId="onboarding-insight-view"
AXFrame="{{24, 589.5}, {354, 52}}"
```

MCP `snapshot_ui` exposed:

```text
e15|tap|button|Voir||onboarding-insight-view
```

MCP tap on that target tapped:

```text
x=201,y=616
```

The app advanced to T7 and exposed the scene `Continuer` CTA.

## Interpretation

This rejects the hypothesis that the T6 layout plus `Semantics.identifier`
alone produces the bad frame. Direct T6 has correct geometry and navigates by
id.

Combined with the T5→T6 bisect, CJT-018 is now narrowed to the real transition
from T5 revenue to T6 insight. T5 identified CTA geometry is correct before the
tap; direct T6 identified CTA geometry is correct without the tap; the bad
upper geometry appears only after the revenue CTA mutates revenue state and
advances into T6.

## Code State

The temporary probe code was reverted after this report. A fresh XcodeBuildMCP
build without `MINT_CJT018_ONB_START_STEP` succeeded:

`/Users/julienbattaglia/Library/Developer/XcodeBuildMCP/workspaces/MINT.nosync-f3c6e3d560e9/logs/build_run_sim_2026-06-03T19-46-11-217Z_pid7997_365cb996.log`

S005 then passed on that current build:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-post-direct-t6-s005-current-build-20260603T2147/result.xml`

Keep active coordinate fallbacks until a runtime-green structural fix proves
T5→T6, T7, and T8 lower CTA ids can be tapped at their visible locations.
