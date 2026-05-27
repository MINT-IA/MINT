# Phase 51 — Micro-actions budget read model

## Goal
Align the emergency-fund micro-action with the same budget read model used by Budget and Financial Fitness.

## Why
`MicroActionEngine` still computed reserve months from `profile.totalDepensesMensuelles`. An implausible charge could therefore trigger a misleading “renforce ta réserve” action even when `BudgetInputs` would filter that charge out.

## Changed
- `MicroActionEngine._financialActions` now derives reserve months from `BudgetInputs.fromCoachProfile(profile)` and `BudgetService().computePlan(...).emergencyFundMonths`.
- Added a regression test where CHF 19'272'200 housing is ignored by budget plausibility filters and does not trigger `build_emergency_fund`.

## Verification
- `flutter test test/services/micro_action_engine_test.dart test/services/monthly_briefing_service_test.dart`
- `flutter analyze lib/services/micro_action_engine.dart test/services/micro_action_engine_test.dart`
- `git diff --check`
