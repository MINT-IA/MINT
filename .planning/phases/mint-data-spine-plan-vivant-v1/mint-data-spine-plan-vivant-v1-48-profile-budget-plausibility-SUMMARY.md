# Summary 48 — Profile budget plausibility

## Outcome

`CoachProfile` no longer lets stale implausible expense captures bypass the
budget guard through SafeMode or the legacy budget bridge.

## Changes

- Exposed `BudgetInputs.plausibleMonthlyAmount(...)`.
- `isInDebtCrisis` now computes emergency-fund shortfall from plausible
  housing, LAMal, and fixed charges.
- `CoachProfile.toBudgetInputs()` delegates to `BudgetInputs.fromCoachProfile`.
- Added regression tests for both paths.

## Verification

- Red test first: `isInDebtCrisis` returned `true` for `19'272'200` CHF monthly
  expenses before the fix.
- Red test first: `toBudgetInputs().housingCost` returned `19'272'200` before
  the fix.
- `flutter test test/models/coach_profile_safe_mode_test.dart test/models/coach_profile_bridge_test.dart test/domain/budget/budget_service_test.dart`
- `flutter analyze lib/domain/budget/budget_inputs.dart lib/models/coach_profile.dart test/models/coach_profile_safe_mode_test.dart test/models/coach_profile_bridge_test.dart test/domain/budget/budget_service_test.dart`
