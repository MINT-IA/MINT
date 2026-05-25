# Summary 47 — Budget emergency fund plausibility

## Outcome

Budget reserve-month calculations now ignore implausible monthly charges when
rebuilding `BudgetInputs` from `CoachProfile`.

## Changes

- `BudgetInputs.fromCoachProfile` computes monthly expenses from filtered
  housing, LAMal, and other fixed charges.
- The 70% net-income fallback remains active when no plausible expense is
  available.
- Added a regression test covering the `19'272'200` rent and `420'420` LAMal
  failure shape.

## Verification

- Red test first: `emergencyFundMonths` was `0.000609...` before the fix.
- `flutter test test/domain/budget/budget_service_test.dart`
- `flutter analyze lib/domain/budget/budget_inputs.dart test/domain/budget/budget_service_test.dart`
