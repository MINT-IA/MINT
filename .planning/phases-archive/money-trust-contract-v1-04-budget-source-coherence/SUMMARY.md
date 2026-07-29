# Money Trust Contract v1 — 04 Budget Source Coherence Summary

This phase removes one trust-breaking Budget and Mon Argent divergence while
keeping the diff small and testable.

## What Changed

- `BudgetSummaryCard` now renders fresh `BudgetInputs` plus `BudgetPlan` before
  falling back to `BudgetSnapshot`.
- `BudgetScreen` no longer clamps signed present-budget cashflow to zero.
- Added widget regression coverage for stale snapshot override.
- Added screen regression coverage for a monthly deficit.

## Why

The app could show old or sanitized monthly numbers after direct budget setup or
relaunch. For a financial lucidity app, a false zero or a stale remaining amount
is worse than an explicit incomplete state.

## Agent Review Synthesis

- Product review: the user journey must answer one question first: how much is
  left this month, why, and how reliable that number is.
- QA review: the next blocking Maestro proof should be
  `flow_mon_argent_budget_setup_spine.yaml`, then coach data-spine visibility.
- Architecture review: a bigger follow-up must converge Budget, Mon Argent,
  coach packet, and financial report around one read model.

## Next Phase

Recommended next phase:
`money-trust-contract-v1-05-budget-read-model-convergence`.

Target:
- stop stale `budget_inputs_v1` from overriding newer profile/spine data;
- make Budget, Mon Argent, coach packet, and financial report consume the same
  canonical present-budget read model;
- add Maestro proof from setup to relaunch to Mon Argent to Budget to coach.
