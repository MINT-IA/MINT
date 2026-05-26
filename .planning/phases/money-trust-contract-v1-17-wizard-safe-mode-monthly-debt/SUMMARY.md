# Phase 17 — Summary

## What Changed
- Added `WizardService.isSafeModeActive` regression coverage for weekly income
  with monthly budget debt.
- Added biweekly debt coverage and income-priority pins after Claude Opus review.
- Updated `WizardService._calculateDebtRatio` so
  `q_debt_payments_period_chf` is added as a monthly amount.

## Why It Matters
Safe mode is a trust surface. It should activate on real financial fragility,
not because MINT multiplied a monthly debt value by the user's pay cadence.

## Files
- `apps/mobile/lib/services/wizard_service.dart`
- `apps/mobile/test/services/wizard_service_test.dart`
- `apps/mobile/test/domain/budget/budget_service_test.dart`

## Product Decision
The current storage contract is:
- `q_net_income_period_chf`: amount per pay period.
- `q_debt_payments_period_chf`: monthly budget debt amount in current budget
  setup and wizard V2 flows.

If the storage contract changes later, the budget read model and data-flow docs
must change together.
