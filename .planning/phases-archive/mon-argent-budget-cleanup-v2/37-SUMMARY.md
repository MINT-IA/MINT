phase: mon-argent-budget-cleanup-v2
plan: 37
title: Mobile budget display rounding alignment
branch: codex/mon-argent-budget-cleanup-v2
date: 2026-05-27

# Phase 37 — Mobile budget display rounding alignment

Live Maestro exposed a one-franc drift between Budget and Mon Argent: Budget
rendered `CHF 2'239`, while the Data Spine / Mon Argent path rendered
`CHF 2'240` for the same user state. The cause was two different rounding
boundaries: Budget used `PresentBudgetBuilder`, while `BudgetLivingEngine`
summed unrounded components and rounded later through its consumers.

## Changes

- Made `PresentBudgetBuilder.displayChf()` public so other read models can use
  the same display boundary.
- Updated `BudgetLivingEngine._computePresent()` to derive monthly net, fixed
  charges, and savings through the same display read model as Budget.
- Added a unit contract proving `BudgetLivingEngine.compute(profile).present`
  matches `PresentBudgetBuilder.fromInputs(...)` for the budget-screen read
  model.

## Verification

- `cd apps/mobile && flutter test test/services/budget_living_engine_test.dart test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart test/services/coach_context_packet_payload_test.dart test/widgets/mon_argent_budget_summary_card_test.dart`
  - Result: `70 passed`.
- `cd apps/mobile && flutter analyze lib/domain/budget/present_budget_builder.dart lib/services/budget_living_engine.dart test/services/budget_living_engine_test.dart`
  - Result: `No issues found!`.
- Live simulator after rebuild:
  - `flow_money_trust_chain_budget_mon_argent_rapport_coach`
  - Result: `1/1 Flow Passed in 56s`.
  - Artifact: `.planning/walker/maestro-flows/money-trust-chain/20260527T144530Z/result.xml`.

## Notes

- This phase intentionally changes only display/read-model rounding. It does
  not change underlying financial projections.
- The important invariant is not that every flow always shows the same literal
  amount across all seed states. The invariant is that Budget, Mon Argent, the
  Data Spine, and Coach packet payloads use the same displayed budget read
  model for the same profile.
