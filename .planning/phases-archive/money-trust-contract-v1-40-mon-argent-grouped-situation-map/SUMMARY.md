# Phase 40 — Summary

## Result

The `Mon Argent` `Aujourd'hui` situation map now groups facts by human mental
model instead of listing everything in one long mixed block.

## What changed

- Added `_SituationGroup` in `MonArgentScreen`.
- Grouped situation rows into:
  - monthly budget facts: income, housing, LAMal;
  - accessible wealth facts: cash, investments, debt;
  - pension facts: AVS, LPP, 3a.
- Added semantics identifiers for the three groups.
- Updated `flow_mon_argent_budget_setup_spine.yaml` to assert the group
  anchors and to navigate sections via deep links after the first scroll.

## Why

This is the first small step toward the larger information architecture:
`Mon Argent` must distinguish what the user lives with every month from what
is wealth, debt, or pension capital. The values are unchanged; only the
presentation is made more legible and testable.

## Evidence

- Maestro artifact: `.planning/_walker/20260526T164240/maestro.log`.
- Screenshots:
  - `.planning/phases/money-trust-contract-v1-40-mon-argent-grouped-situation-map/mon-argent-01-data-spine.png`
  - `.planning/phases/money-trust-contract-v1-40-mon-argent-grouped-situation-map/mon-argent-02-budget-setup.png`
  - `.planning/phases/money-trust-contract-v1-40-mon-argent-grouped-situation-map/mon-argent-03-budget-direct-relaunch.png`
  - `.planning/phases/money-trust-contract-v1-40-mon-argent-grouped-situation-map/mon-argent-04-coach-return.png`
