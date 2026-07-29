# Money Trust Contract v1 — 06 Budget Proof Maestro

Stabilize the Budget calculation proof so the device flow can verify the
trusted monthly numbers after setup and relaunch.

## Goal

Make the Budget formula proof visible and addressable in Maestro, then pass the
Mon Argent/Budget setup flow on the iPhone simulator.

## Scope

- Budget calculation detail visibility.
- Stable semantic anchor for the calculation detail toggle.
- Maestro flow selector update.

## Acceptance

- `flow_mon_argent_budget_setup_spine.yaml` passes on the booted iOS simulator.
- The flow verifies `3'140`, `2'239`, and absence of `19'272'200` / `420'420`.
