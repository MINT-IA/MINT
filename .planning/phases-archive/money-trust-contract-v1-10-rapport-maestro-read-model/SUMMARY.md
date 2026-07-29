# Phase 10 Summary — Rapport Maestro Read-Model Gate

## Completed

- Added `tools/simulator/flows/maestro-perfect-set/flow_rapport_budget_read_model_spine.yaml`.
- The flow covers budget setup → persistence → relaunch → `/rapport`.
- The flow asserts the report renders the budget section and rejects known
  absurd captured amounts (`19'272'200`, `420'420`).
- The flow asserts values it enters itself (`2'200` housing and `420` LAMal),
  avoiding false negatives from missing archetype income/tax seeds.

## Product Rationale

Rapport is a trust surface: if it tells a user their monthly budget with stale
or absurd values, the whole app loses credibility. This flow makes Rapport part
of the same money read-model contract as Budget and Mon Argent.
