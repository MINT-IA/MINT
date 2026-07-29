# Money Trust Contract v1 — 08 Report Budget Read Model Verification

## TDD Evidence

- `cd apps/mobile && flutter test test/screens/advisor_banking_smoke_test.dart --plain-name 'budget card rejects implausible captured monthly amounts'`
  - Red result before implementation: rendered `CHF 19'272'200`.
  - Green result after implementation: `1 passed`.

## Local Verification

- `cd apps/mobile && flutter test test/screens/advisor_banking_smoke_test.dart test/domain/budget/budget_service_test.dart`
  - Result: `95 passed`
- `cd apps/mobile && flutter test test/providers/budget/budget_provider_test.dart test/screens/budget_setup_screen_test.dart test/screens/budget_screen_smoke_test.dart test/screens/mon_argent_screen_test.dart test/screens/advisor_banking_smoke_test.dart test/domain/budget/budget_service_test.dart`
  - Result: `125 passed`
- `cd apps/mobile && flutter analyze --no-fatal-infos lib/screens/advisor/financial_report_screen_v2.dart test/screens/advisor_banking_smoke_test.dart lib/domain/budget/budget_inputs.dart lib/domain/budget/budget_service.dart`
  - Result: `No issues found`
- `cd apps/mobile && flutter analyze --no-fatal-infos lib/domain/budget/budget_inputs.dart lib/providers/budget/budget_provider.dart lib/screens/advisor/financial_report_screen_v2.dart lib/screens/budget/budget_container_screen.dart lib/screens/mon_argent/mon_argent_screen.dart test/domain/budget/budget_service_test.dart test/providers/budget/budget_provider_test.dart test/screens/advisor_banking_smoke_test.dart test/screens/budget_setup_screen_test.dart`
  - Result: `No issues found`

## Review

- Internal `code-reviewer` found a blocking regression risk: `BudgetInputs.fromMap`
  initially did not preserve legacy `q_net_income_monthly` and weekly/biweekly
  normalization from `WizardService.getMonthlyIncome`.
- Added failing tests for those cases, fixed `BudgetInputs.fromMap`, then reran
  the combined targeted suite.

## Remaining Risk

- Financial Report still has other locally generated sections beyond budget.
- Signed deficits still need an explicit UX decision because current
  `BudgetPlan.available` is intentionally clamped for allocation.
