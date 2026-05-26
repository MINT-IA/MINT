# Phase 27 — Maestro Money Trust Proof

## Goal

Validate the full money trust chain on iOS simulator after the backend and mobile trust fixes.

## Scope

- Build the Flutter iOS simulator app without `flutter clean`.
- Install it on the booted iPhone 17 Pro simulator.
- Run the canonical Maestro flow:
  `tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`.

## Success Criteria

- Budget setup accepts housing `2200` and LAMal `420`.
- Budget screen restores and shows `3'140` charges and `2'239` free monthly margin.
- Mon Argent renders the budget summary and flow bar.
- Rapport renders the same budget values.
- Coach chat is reachable.
- No absurd known-regression values are visible:
  `19'272'200`, `420'420`, `19M`, `420k`, `NaN`, `Infinity`.
- No visible Flutter crash markers in Rapport:
  `A RenderFlex overflowed`, `Exception caught`, `NoSuchMethodError`.

## Out of Scope

- No new UI design changes.
- No broad perfect-set sweep.
- No backend live LLM call validation; this flow validates deterministic visible surfaces.
