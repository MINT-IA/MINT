# CJT-018 Batched Revenue Advance Probe — 2026-06-03

## Scope

Probe only. Production code was temporarily changed to:

- start the real `OnboardingShellScreen` at seeded T5 revenue when built with
  `MINT_CJT018_ONB_START_STEP=revenue_seeded`;
- expose the T6 `Voir` CTA as `Semantics.identifier =
  onboarding-insight-view`;
- call `setNetMonthlyRange(..., notifyListenersAfterSet: false)` before
  `advance()` when built with `MINT_CJT018_BATCH_REVENUE_ADVANCE=true`.

No production flow was changed.

## Runtime Setup

- Simulator: iPhone 17 Pro
  `B03E429D-0422-4357-B754-536637D979F9`.
- Build tool: XcodeBuildMCP `build_run_sim`.
- Dart defines:
  - `MINT_DISABLE_BETA_MODAL=true`
  - `MINT_CJT018_ONB_START_STEP=revenue_seeded`
  - `MINT_CJT018_BATCH_REVENUE_ADVANCE=true`
- Build result: succeeded.
- Build log:
  `/Users/julienbattaglia/Library/Developer/XcodeBuildMCP/workspaces/MINT.nosync-f3c6e3d560e9/logs/build_run_sim_2026-06-03T20-02-19-656Z_pid7997_bb8af475.log`

## Evidence

Artifact folder:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-batched-revenue-advance-20260603Tprobe/`

`flow_stop_at_t6.yaml` passed through the revenue CTA and stopped at T6.

`idb-t6-after-batched-revenue-advance.txt` still showed the T6 id with upper,
scaled-down geometry:

```text
AXUniqueId="onboarding-insight-view"
AXFrame="{{8, 196.5}, {118, 17.333333333333343}}"
```

## Interpretation

This rejects the hypothesis that the bad T6 frame is caused by two successive
provider notifications (`setNetMonthlyRange()` then `advance()`). Batching the
revenue mutation so that only `advance()` notified listeners did not move the
T6 id to the visible CTA.

The remaining root slice is inside the revenue mutation/step transition itself,
but not specifically T1-T4 history, T6 layout/id alone, slider semantics,
dossier row growth, or double notification.

## Code State

The temporary probe code was reverted after this report. A fresh XcodeBuildMCP
build without CJT-018 probe defines succeeded:

`/Users/julienbattaglia/Library/Developer/XcodeBuildMCP/workspaces/MINT.nosync-f3c6e3d560e9/logs/build_run_sim_2026-06-03T20-04-33-098Z_pid7997_3c58c08c.log`

S005 then passed on that current build:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-post-batched-revenue-s005-current-build-20260603T2204/result.xml`

Keep active coordinate fallbacks until a runtime-green structural fix proves
T5→T6, T7, and T8 lower CTA ids can be tapped at their visible locations.
