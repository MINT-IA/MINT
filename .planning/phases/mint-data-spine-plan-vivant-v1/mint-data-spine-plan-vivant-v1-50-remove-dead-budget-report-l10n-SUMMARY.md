# Phase 50 — Remove dead budget report l10n

## Goal
Remove localization keys that only existed for the deleted `BudgetReportSection`.

## Why
After Phase 49, `budgetReport*` strings had no UI consumer. Keeping them would make future search and generated APIs noisier and could encourage reusing the old clamped budget-report surface.

## Changed
- Removed `budgetReportTitle`, `budgetReportDisponible`, `budgetReportVariables`, `budgetReportFutur`, `budgetReportChfAmount`, `@budgetReportChfAmount`, and `budgetReportStopWarning` from all 6 ARB files.
- Ran `flutter gen-l10n`.
- Normalized regenerated localization Dart files back to LF after the generator wrote CRLF.

## Verification
- `validate_arb_parity` MCP: OK — 6 locales, 6807 keys each.
- `rg "budgetReport" apps/mobile/lib/l10n apps/mobile/lib apps/mobile/test`
- `flutter analyze lib/l10n`
- `flutter test test/screens/budget_screen_smoke_test.dart`
- `git diff --check`
