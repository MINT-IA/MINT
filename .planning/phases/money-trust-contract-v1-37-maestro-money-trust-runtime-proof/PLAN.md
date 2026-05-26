# Phase 37 — Maestro Money Trust Runtime Proof

## Goal

Prove the money trust chain on the iOS simulator, not only in unit tests:
Budget setup writes fixed charges, Budget restores them after app restart,
Mon Argent and Rapport reuse the same values, and Coach stays reachable without
visible absurd values.

## Scope

- Build the current Flutter app for iOS Simulator with the MINT E2E archetype.
- Install the build on the booted iPhone 17 Pro simulator.
- Run the canonical Maestro flow:
  `tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`.
- Capture the exact runtime verdict and artifact path.

## Acceptance

- Budget setup accepts CHF 2'200 housing and CHF 420 LAMal.
- After app restart, Budget shows charges around CHF 3'140 and available CHF 2'239.
- Mon Argent exposes the budget summary and flow bar.
- Rapport exposes Ton Budget with CHF 2'200 and CHF 420.
- Coach chat opens with input and send controls.
- No visible `19'272'200`, `420'420`, `19M`, `420k`, `NaN`, or `Infinity`.
- No visible Flutter overflow, exception, or `NoSuchMethodError` on Rapport.
