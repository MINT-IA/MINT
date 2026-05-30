# Phase 45-47 — budget/report/whisper coherence

## Goal

Close the remaining drift where user-facing budget numbers could still be derived from raw `BudgetInputs` or clamped `BudgetPlan.available` after the `PresentBudgetBuilder` read model was introduced.

## Changes

- `BudgetScreen` secondary visuals now use displayed CHF values for 50/30/20, sandwich, crash-test, debt disclosure, and other fixed charges.
- `FinancialReportScreenV2` budget card now uses signed `PresentBudget.monthlyFree` and `PresentBudget.monthlyNet`, so deficit months are not rendered as `CHF 0`.
- `BudgetWaterfall` now preserves signed availability instead of clamping deficits.
- `CoachWhisperService` bases 3a suggestions on signed monthly free cash, not `BudgetPlan.available`.

## Review

- Product/UX sidecar audit: Budget should stay monthly cashflow/debt; Mon Argent should become balance sheet/liquid-debt-illiquid-patrimoine; Trajectoire should own A-to-B planning.
- Architecture sidecar audit: highest drift risks were Rapport V2 clamped availability, Coach Whisper `available`-based 3a suggestions, legacy `BudgetReportSection`, and fitness score formula drift.
- Claude Opus review: first pass blocked on secondary-widget rounding drift; corrected pass returned `NO BLOCKERS`.

## Verification

- `flutter test test/screens/budget_screen_smoke_test.dart test/domain/budget/present_budget_builder_test.dart test/screens/advisor_banking_smoke_test.dart test/services/mon_argent/coach_whisper_service_test.dart`
- `flutter analyze lib/screens/budget/budget_screen.dart lib/screens/advisor/financial_report_screen_v2.dart lib/services/mon_argent/coach_whisper_service.dart lib/widgets/report/budget_waterfall.dart test/screens/budget_screen_smoke_test.dart test/screens/advisor_banking_smoke_test.dart test/services/mon_argent/coach_whisper_service_test.dart`
- `python3 tools/checks/prefer_mint_cta.py --file apps/mobile/lib/screens/budget/budget_screen.dart`
- `git diff --check`

## Remaining

- Audit or delete `BudgetReportSection` before it is wired again.
- Align `FinancialFitnessService` budget score with the same budget read model.
- Run Maestro money-trust-chain after the next simulator build.
