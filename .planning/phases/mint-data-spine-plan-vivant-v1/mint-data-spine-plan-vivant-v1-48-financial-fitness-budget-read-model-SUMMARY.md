# Phase 48 — Financial Fitness budget read model

## Goal
Align the Budget sub-score in `FinancialFitnessService` with the canonical budget read model so Mint does not score a user from stale or parallel budget formulas.

## Why
The user-facing Budget, Report, and Coach surfaces now use `BudgetInputs` → `BudgetService` → `PresentBudget`. `FinancialFitnessService` still used `CoachProfile.resteAVivreMensuel` plus an inline payslip estimate, which could produce a healthier budget score than the UI when planned savings or trusted budget inputs made the real monthly free cash tight.

## Changed
- `FinancialFitnessService._calculateBudget` now builds `BudgetInputs`, computes `BudgetPlan`, derives `PresentBudget`, and uses `presentBudget.monthlyNet` as the denominator.
- `reste_a_vivre` now scores `presentBudget.monthlyFree - planned monthly contributions`, making the score reflect cash left after the user’s plan.
- `fonds_urgence` now uses `budgetPlan.emergencyFundMonths`, so implausible charges filtered by the budget read model do not contaminate the liquidity score.
- Added regression tests where:
  - trusted housing/LAMal plus a planned 3a contribution leave positive free cash before plan but negative free cash after planned savings, forcing `reste_a_vivre` to 0 points;
  - an implausible housing value like CHF 19'272'200 is filtered by `BudgetInputs` and does not destroy the emergency-fund score.

## Verification
- `flutter test test/services/financial_fitness_service_test.dart test/services/coach_loop_numeric_test.dart`
- `flutter analyze lib/services/financial_fitness_service.dart test/services/financial_fitness_service_test.dart`
- `git diff --check`

## Notes
- This phase intentionally avoids broad service refactoring. It removes one duplicated financial formula from a trust-critical score while keeping the public score shape stable.
- Review notes resolved:
  - Sidecar code review found emergency-fund drift; fixed in this phase.
  - Claude Opus flagged possible double-subtraction of planned contributions. Code inspection confirmed `BudgetInputs`/`BudgetService` do not carry `plannedContributions` into `plan.future`; the test now asserts the pre-plan free cash is positive and the post-plan free cash is negative.
  - Final Claude Opus pass returned `NO BLOCKERS`; two non-blocking hardenings were applied: negative ratios are scored via an explicit 0 floor, and the test now requires the detail string to start with `-`.
- Remaining cleanup target: audit legacy budget/report widgets and any remaining direct `CoachProfile.resteAVivreMensuel` consumers.
