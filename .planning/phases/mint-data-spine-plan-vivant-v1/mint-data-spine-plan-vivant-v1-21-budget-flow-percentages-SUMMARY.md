# Summary 21 — Budget flow percentages

## Shipped
- Added percentage labels to the Budget flow map amount rows.
- Kept the percentages derived from the same denominator as the existing segmented bar.
- Extended the BudgetScreen smoke test for the visible proportions.

## Validation
- `flutter analyze lib/screens/budget/budget_screen.dart test/screens/budget_screen_smoke_test.dart`
- `flutter test test/screens/budget_screen_smoke_test.dart`
- 5 design lints, `git diff --check`

