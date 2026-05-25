# Plan 40 — Budget numerical coherence

## Problem

After Plan 39, the budget no longer accepted implausible millions-level
charges, but the detail screen could still mix two valid-looking data sources:
the current `BudgetInputs` and a stale global `BudgetSnapshot`. This produced
an incoherent story, for example CHF 5'379 net income in the breakdown and CHF
8'624 net income in the flow map.

## Scope

- `BudgetScreen` numeric source of truth.
- Widget regression coverage for stale `MintState` snapshots.
- Maestro budget flow assertions for visible CHF values.
- Data-flow documentation.

## Non-goals

- Redesigning the budget method.
- Changing tax/LAMal estimators.
- Changing PulseScreen or the global data-spine snapshot model.

## Implementation Plan

1. Make the budget detail screen derive hero, breakdown, and flow map from the
   same `BudgetInputs` + `BudgetPlan` pair.
2. Keep `BudgetSnapshot` as a global/Pulse model, but do not let it override
   explicit budget inputs in the detail screen.
3. Add a widget regression test with a hostile stale `MintState` snapshot.
4. Extend the Maestro Mon Argent/Budget flow with visible value assertions:
   CHF 2'200 housing, CHF 420 LAMal, and absence of the old absurd values.
5. Rebuild and rerun the targeted Maestro flow on the iOS simulator.

## Acceptance Criteria

- A budget detail screen opened with explicit inputs does not render stale
  `MintState` values in the flow map.
- Breakdown, hero, and flow map use one coherent monthly net/charges/free
  story.
- Maestro verifies business values, not only screen reachability.
