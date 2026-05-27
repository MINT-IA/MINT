# Phase 49 — Delete dead BudgetReportSection

## Goal
Remove a stale budget widget that had no callers and still displayed clamped `BudgetPlan.available`.

## Why
`BudgetReportSection` was flagged during the budget data-spine audit as a drift risk. It was not wired anywhere in `apps/mobile/lib` or `apps/mobile/test`, but if reused later it would reintroduce the old budget semantics instead of the signed `PresentBudget` read model.

## Changed
- Deleted `apps/mobile/lib/widgets/budget/budget_report_section.dart`.
- Kept `SpendingMeter`, which is still used by `BudgetScreen`.

## Verification
- `rg "BudgetReportSection\\(|budget_report_section" apps/mobile/lib apps/mobile/test`
- `flutter analyze lib/screens/budget/budget_screen.dart lib/widgets/budget/spending_meter.dart`
- `flutter test test/screens/budget_screen_smoke_test.dart`

## Notes
The old `budgetReport*` localization keys remain for now because removing generated localization APIs would touch all ARB/generated l10n files. They are now dead strings and can be removed in a dedicated i18n cleanup phase with ARB parity verification.
