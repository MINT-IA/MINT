# CJT-018 Revenue Dossier Bisect — 2026-06-03

## Scope

Probe only. Production code was temporarily changed to:

- start the real `OnboardingShellScreen` at seeded T5 revenue when built with
  `MINT_CJT018_ONB_START_STEP=revenue_seeded`;
- expose the T6 `Voir` CTA as `Semantics.identifier =
  onboarding-insight-view`;
- keep the revenue value/confidence mutation but skip adding the `revenue`
  entry to `DossierStrip` when built with
  `MINT_CJT018_SKIP_REVENUE_DOSSIER=true`.

No production flow was changed.

## Runtime Setup

- Simulator: iPhone 17 Pro
  `B03E429D-0422-4357-B754-536637D979F9`.
- Build tool: XcodeBuildMCP `build_run_sim`.
- Dart defines:
  - `MINT_DISABLE_BETA_MODAL=true`
  - `MINT_CJT018_ONB_START_STEP=revenue_seeded`
  - `MINT_CJT018_SKIP_REVENUE_DOSSIER=true`
- Build result: succeeded.
- Build log:
  `/Users/julienbattaglia/Library/Developer/XcodeBuildMCP/workspaces/MINT.nosync-f3c6e3d560e9/logs/build_run_sim_2026-06-03T19-56-29-466Z_pid7997_6685a10e.log`

## Evidence

Artifact folder:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-revenue-dossier-bisect-20260603Tprobe/`

`flow_stop_at_t6.yaml` passed through the revenue CTA and stopped at T6.

`idb-t6-after-revenue-dossier-skip.txt` still showed the T6 id with upper,
scaled-down geometry:

```text
AXUniqueId="onboarding-insight-view"
AXFrame="{{8, 206.83333333333334}, {118, 17.333333333333343}}"
```

The dossier contained intent, DOB, and canton only; `Revenu net mensuel` was
absent from the captured AX tree as intended by the probe.

## Interpretation

This rejects the hypothesis that adding the revenue row to `DossierStrip` during
the T5→T6 transition is sufficient to produce the bad T6 frame. The bad geometry
still appears when the revenue value is stored but the dossier row is skipped.

The remaining root slice is the T5 revenue state mutation plus `advance()`
boundary, but not specifically slider semantics or dossier row growth.

## Code State

The temporary probe code was reverted after this report. A fresh XcodeBuildMCP
build without CJT-018 probe defines succeeded:

`/Users/julienbattaglia/Library/Developer/XcodeBuildMCP/workspaces/MINT.nosync-f3c6e3d560e9/logs/build_run_sim_2026-06-03T19-58-32-989Z_pid7997_5a18263b.log`

S005 then passed on that current build:

`.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/cjt-018-post-revenue-dossier-s005-current-build-20260603T2159/result.xml`

Keep active coordinate fallbacks until a runtime-green structural fix proves
T5→T6, T7, and T8 lower CTA ids can be tapped at their visible locations.
