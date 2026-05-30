---
phase: mon-argent-budget-cleanup-v2
plan: 05
status: complete
completed_at: 2026-05-26
branch: codex/mon-argent-budget-cleanup-v2
---

# Summary — Direct Mon Argent Route Regressions

## Outcome

Added direct-route regressions for the two central Mon Argent money sections.
Opening the month section directly must use the canonical `BudgetSnapshot`
instead of a stale local budget cache. Opening the patrimoine section directly
must show investments, debts and the resulting net worth.

## Files

- `apps/mobile/test/screens/mon_argent_screen_test.dart`

## Verification

- `flutter test test/screens/mon_argent_screen_test.dart`: 11 passed.
- Focused Budget/Mon Argent/Data Spine suite: 78 passed.
- Targeted analyze: no issues.

## Next

Use these direct-route guards before refactoring toward a shared present-budget
view builder. They protect the user journeys most likely to be entered via tabs,
deep links or chat navigation.
