# CJT-018 T5→T6 History Bisect — 2026-06-03

## Scope

Probe only. Production code was temporarily changed to:

- start the real `OnboardingShellScreen` at T5 revenue when built with
  `MINT_CJT018_ONB_START_STEP=revenue_seeded`;
- expose the T6 `Voir` CTA as `Semantics.identifier =
  onboarding-insight-view`.

No production flow was changed.

## Runtime Setup

- Simulator: iPhone 17 Pro
  `B03E429D-0422-4357-B754-536637D979F9`.
- Build tool: XcodeBuildMCP `build_run_sim`.
- Dart defines:
  - `MINT_DISABLE_BETA_MODAL=true`
  - `MINT_CJT018_ONB_START_STEP=revenue_seeded`
- Build result: succeeded.
- Build log:
  `/Users/julienbattaglia/Library/Developer/XcodeBuildMCP/workspaces/MINT.nosync-f3c6e3d560e9/logs/build_run_sim_2026-06-03T19-33-36-140Z_pid7997_d7409985.log`

## Evidence

Artifact folder:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-t5-history-bisect-20260603Tprobe/`

### T5 Control

`flow_stop_at_t5.yaml` passed and stopped on the seeded revenue screen.

`idb-t5-before-tap.txt` showed the revenue CTA with correct lower geometry:

```text
AXUniqueId="onboarding-revenue-range-continue"
AXFrame="{{24, 620.5}, {354, 52}}"
```

### T6 After Revenue Advance

`flow_stop_at_t6.yaml` passed through `onboarding-revenue-range-continue` and
stopped at `Avant de te montrer…`.

`snapshot_ui` exposed the T6 target:

```text
e15|tap|button|Voir||onboarding-insight-view
```

`idb-t6-before-tap.txt` showed the T6 CTA id with upper, scaled-down geometry:

```text
AXUniqueId="onboarding-insight-view"
AXFrame="{{8, 196.5}, {118, 17.333333333333343}}"
```

MCP tap on that same target tapped:

```text
x=67,y=205
```

The app stayed on T6. Screenshot:

`t6-before-id-tap-mcp.jpg`

## Interpretation

This rejects the hypothesis that T1-T4 history is required to reproduce the bad
T6 activation geometry. A seeded T5 screen has correct AX geometry, then the
real T5 revenue tap plus T6 identified CTA produces the same non-activating
upper frame seen in prior full-path probes.

The next credible root-cause slice is narrower: compare why T5 identified CTA
geometry stays correct while the T6 identified CTA, after the T5→T6 step
transition, reports coordinates divided by the simulator scale. More wrapper
variants around the same T6 button are low-value because strict semantics,
label semantics, constrained semantics, explicit-child semantics, and simple
shell slots have already failed runtime.

## Code State

The temporary probe code was reverted after this report. A fresh XcodeBuildMCP
build without `MINT_CJT018_ONB_START_STEP` succeeded:

`/Users/julienbattaglia/Library/Developer/XcodeBuildMCP/workspaces/MINT.nosync-f3c6e3d560e9/logs/build_run_sim_2026-06-03T19-38-45-179Z_pid7997_394fa8de.log`

S005 then passed on that current build:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-post-bisect-s005-current-build-20260603T2140/result.xml`

Keep the active S005/perfect-set coordinate fallbacks until a runtime-green
structural fix moves T6/T7/T8 activation points to their visible CTAs.
