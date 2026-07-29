# Phase 40 — Mon Argent Grouped Situation Map

## Goal

Make the first `Mon Argent` situation screen easier to parse by separating
daily budget facts, accessible wealth facts, and Swiss pension facts.

## Scope

- Keep the existing data spine read model and values.
- Add structural groups inside the `Aujourd'hui` situation map.
- Expose stable Maestro semantics anchors for each group.
- Update the canonical Mon Argent Maestro flow to assert those anchors.

## Acceptance

- `MonArgentScreen` still renders the same financial values.
- The situation map exposes:
  - `mon_argent_situation_group_month`
  - `mon_argent_situation_group_wealth`
  - `mon_argent_situation_group_pension`
- Widget tests pass.
- Targeted Flutter analyze passes.
- The Mon Argent/Budget/Coach Maestro flow passes on iPhone 17 Pro simulator.
