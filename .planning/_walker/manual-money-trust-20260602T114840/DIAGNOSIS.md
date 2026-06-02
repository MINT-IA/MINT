---
description: Diagnosis for the 2026-06-02 Money Trust Maestro rerun that failed at /budget after restart.
status: active
date: 2026-06-02
---

# Money Trust Rerun Diagnosis

## Result

`flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml` failed on
2026-06-02 at:

```text
Assertion is false: id: budget_screen is visible
```

The post-failure screenshot showed SpringBoard, so the first-order failure was
not enough to prove a Budget route bug. A manual `mintapp:///budget` open then
rendered Budget's empty state, not the expected computed budget.

## Evidence

- Maestro result: `.planning/_walker/manual-money-trust-20260602T114840/result.xml`
- Maestro log: `.planning/_walker/manual-money-trust-20260602T114840/maestro.log`
- Post-failure screenshot: `.planning/_walker/manual-money-trust-20260602T114840/post-failure-screen.png`
- Manual route screenshot: `.planning/_walker/manual-money-trust-20260602T114840/manual-open-budget.png`

Simulator plist after the run contained:

```text
flutter.budget_inputs_v1 = {"q_net_income_period_chf":0.0,"q_housing_cost_period_chf":2200.0,"q_lamal_premium_monthly_chf":420.0,...}
flutter.budget_inputs_v1_origin = directInput
flutter.wizard_answers_v2 = {"q_housing_cost_period_chf":"__secure__","q_pay_frequency":"monthly","q_lamal_premium_monthly_chf":"__secure__"}
```

## Root Cause

The flow expects `MINT_E2E_ARCHETYPE=julien_swiss` to provide the salary/read
model after restart. In the app, that seed is intentionally in-memory only:
`CoachProfileProvider.loadFromWizard()` injects `CoachProfileSeeds.activeSeed`
after persisted answers are absent, and the code comments explicitly say this
bypasses the wizard answer flush.

When `/budget/setup` saves housing and LAMal, `CoachProfileProvider.mergeAnswers`
correctly re-reads persisted answers from disk before merging. Since the debug
seed was never persisted, the saved truth becomes only housing + LAMal. Budget
then has `netIncome == 0` and renders the empty state.

## Decision

Do not treat this failed rerun as a production Budget bug yet. It is a stale QA
contract: the flow mixes an in-memory debug seed with a persistence proof.

Next proof must use one of these real contracts:

1. A full persisted profile/onboarding path, then Budget -> restart -> Budget.
2. A debug-only explicit persistent seed harness, clearly marked as test-only.
3. A narrower seed-only flow that does not claim to prove restart persistence.

Until then, previous `flow_money_trust_chain_budget_mon_argent_rapport_coach`
passes are supporting evidence only, not sufficient closure for the Money Trust
P0 gate.
