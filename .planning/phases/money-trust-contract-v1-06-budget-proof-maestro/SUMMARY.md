# Money Trust Contract v1 — 06 Budget Proof Maestro Summary

This phase turns the Budget formula proof into a stable, visible trust surface
and validates it on the simulator.

## What Changed

- Budget wraps its calculation detail in the
  `budget_calculation_detail_toggle` semantic anchor.
- Budget opens the calculation detail by default.
- Maestro taps/asserts stable ids instead of fragile localized text for this
  part of the flow.

## Why

The user must immediately see why the monthly free amount is what it is. Hiding
the formula behind a fragile accordion creates both UX friction and test drift.

## Device Result

`flow_mon_argent_budget_setup_spine.yaml` passed on iPhone 17 Pro simulator in
39 seconds, with screenshots and JUnit under:
`.planning/walker/maestro-flows/mon-argent-budget-source-coherence/20260525T220249Z/`.
