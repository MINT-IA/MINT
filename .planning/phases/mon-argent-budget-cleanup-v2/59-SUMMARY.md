# Phase 59 Summary — Signed Report Budget

## Context
Phase 59 ensures report surfaces show the user's real signed monthly cashflow instead of the clamped allocation value from `BudgetPlan.available`.

## Changes
- `apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart` was already using `PresentBudgetBuilder.monthlyFree`.
- Updated `apps/mobile/lib/services/report/report_builder.dart` so the legacy/local report scoreboard also uses `PresentBudgetBuilder.monthlyFree`.
- Added a deficit regression in `apps/mobile/test/services/report_builder_test.dart`.

## Verification
- `flutter test test/services/report_builder_test.dart test/screens/advisor_banking_smoke_test.dart`
- `flutter analyze lib/services/report/report_builder.dart test/services/report_builder_test.dart test/screens/advisor_banking_smoke_test.dart`

## Decision
`BudgetPlan.available` remains valid for allocation/envelope logic, but user-facing report copy must use signed present cashflow.
