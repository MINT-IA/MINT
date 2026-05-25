# Plan 47 — Budget emergency fund plausibility

## Problem

`BudgetInputs.fromCoachProfile` already drops implausible rent and LAMal values
for the budget breakdown, but `emergencyFundMonths` still used raw
`profile.depenses.totalMensuel`. A stale simulator capture such as
`19'272'200` CHF rent could therefore contaminate reserve metrics even when the
visible charges were filtered.

## Scope

- Reproduce the issue with a `CoachProfile` built from implausible monthly
  charges.
- Derive reserve-month expenses from the same plausible charges used by the
  budget breakdown.
- Keep the fallback to 70% of net income when no plausible expense is known.

## Non-goals

- Redesign budget visuals.
- Change budget setup validation limits.
- Rework tax or LAMal estimation.

## Steps

1. Add a failing `BudgetInputs.fromCoachProfile` regression test.
2. Replace raw `profile.depenses.totalMensuel` with the plausibilized charge
   sum for reserve-month computation.
3. Run the budget test file and targeted analyzer.
