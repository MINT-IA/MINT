# Phase 09 - Budget monthly-net single derivation

## Goal

Keep the monthly net income used by BudgetInputs and BudgetLivingEngine aligned, especially for independent users and couples.

## Changes

- Moved household monthly-net derivation into `BudgetInputs.monthlyNetFromCoachProfile`.
- Reused that derivation from `BudgetLivingEngine._computePresent`.
- Preserved the existing independent approximation: annual gross x 90% / 12.
- Added regressions for:
  - independent solo user;
  - salaried user with annual gross including 13th salary;
  - independent partner contribution;
  - BudgetLivingEngine parity with BudgetInputs.

## Verification

- `flutter test test/domain/budget/budget_service_test.dart --plain-name 'fromCoachProfile uses independent net-income approximation'`
- `flutter test test/services/budget_living_engine_test.dart --plain-name 'independent monthlyNet matches BudgetInputs derivation'`
- `flutter test test/domain/budget/budget_service_test.dart --plain-name fromCoachProfile`
- `flutter analyze lib/domain/budget/budget_inputs.dart lib/services/budget_living_engine.dart test/domain/budget/budget_service_test.dart test/services/budget_living_engine_test.dart`
- Focused budget/Mon Argent/Data Spine suite: 169 tests passed.
- Claude Opus 4.7 review:
  - first pass requested salaried and couple regressions;
  - final pass: `PASS`.

## Follow-up

- The independent 90% approximation is now centralized but still intentionally simple. A future calculator phase should replace it with a Swiss self-employed net-income model when the required inputs are captured.
