# Phase 17 — Wizard Safe Mode Monthly Debt

## Goal
Make `WizardService.isSafeModeActive` use the same budget debt semantics as
`BudgetInputs`: income can be stored per pay period, but budget debt payments
are monthly in current MINT flows.

## Problem
`WizardService._calculateDebtRatio` multiplied `q_debt_payments_period_chf` by
`q_pay_frequency`. For weekly-paid users, CHF 350 of monthly debt became
CHF 1'516.55, which could trigger safe mode from a false debt ratio.

## Scope
- Add a failing regression test for weekly income + monthly budget debt.
- Remove the incorrect debt frequency multiplier.
- Keep income normalization unchanged.

## Acceptance Criteria
- Weekly income is still normalized to monthly income.
- `q_debt_payments_period_chf` is treated as monthly debt.
- Wizard, budget, and report targeted suites remain green.
