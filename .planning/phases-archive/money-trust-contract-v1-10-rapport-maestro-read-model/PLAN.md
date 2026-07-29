# Phase 10 — Rapport Maestro Read-Model Gate

## Goal

Promote Rapport into the same runtime trust perimeter as Mon Argent, Budget,
and Coach.

## Why

The budget/report convergence fixed widget-level drift, but without a Maestro
flow `/rapport` could still regress at runtime after persistence, relaunch, or
deep-link navigation.

## Scope

- Add a Maestro flow that:
  - starts from a clean app state;
  - enters monthly housing and LAMal in budget setup;
  - saves and relaunches without clearing state;
  - deep-links to `/rapport`;
  - asserts `Ton Plan Mint`, `Ton Budget`, sane budget values, and absence of
    known absurd captures.
- The flow asserts values it enters itself (`2'200` housing and `420` LAMal)
  instead of depending on seeded income/tax assumptions.

## Gate

```bash
bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_rapport_budget_read_model_spine.yaml
```
