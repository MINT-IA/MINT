phase: mon-argent-budget-cleanup-v2
plan: 42
title: Mon Argent whisper canonical budget math
branch: codex/mon-argent-budget-cleanup-v2
date: 2026-05-27

# Phase 42 — Mon Argent whisper canonical budget math

`CoachWhisperService` was still recomputing fixed charges from raw
`BudgetInputs` in two private helpers. That duplicated the budget read-model
math and could drift from the visible Budget/Mon Argent values at fractional
CHF boundaries.

## Changes

- `_essentialMonthlyExpenses()` now uses
  `PresentBudgetBuilder.fixedChargesFromInputs(inputs)`.
- `_signedMonthlyFree()` now computes with rounded/display operands:
  rounded net income, canonical fixed charges, rounded future envelope.
- The missing-charges fallback now uses rounded/display net income as well.

## Red-Green Evidence

- Added a fractional-charge emergency-fund test. It failed before the fix,
  then passed after routing through `PresentBudgetBuilder`.
- Added a fractional displayed-deficit test. It failed before the fix because
  raw inputs looked slightly positive; it passed after canonical rounding.
- Added a missing-charges fallback test for rounded net income.

## Verification

- `flutter test test/services/mon_argent_coach_whisper_service_test.dart` —
  PASS.
- `flutter test test/services/mon_argent_coach_whisper_service_test.dart test/domain/budget/present_budget_builder_test.dart test/screens/budget_screen_smoke_test.dart` — PASS, 23 tests.
- `flutter analyze lib/services/mon_argent/coach_whisper_service.dart test/services/mon_argent_coach_whisper_service_test.dart` — PASS.
- `git diff --check` — PASS.
- Opus review verdict: approve, no blockers; nit about rounded net-income
  fallback was applied and covered.
