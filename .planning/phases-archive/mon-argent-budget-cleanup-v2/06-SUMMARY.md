---
phase: mon-argent-budget-cleanup-v2
plan: 06
status: complete
completed_at: 2026-05-26
branch: codex/mon-argent-budget-cleanup-v2
---

# Summary — Budget Direct Debt Hydration

## Outcome

Added a direct-open regression for `/budget`: a complete `CoachProfile` with
debts must hydrate `BudgetContainerScreen` through `BudgetInputs.fromCoachProfile`
instead of keeping stale local budget inputs with zero debt. The visible budget
screen must expose the debt repayment row.

## Files

- `apps/mobile/test/screens/budget_screen_smoke_test.dart`

## Verification

- `flutter test test/screens/budget_screen_smoke_test.dart --plain-name 'BudgetContainerScreen hydrates debts from CoachProfile'`:
  1 passed.
- `flutter analyze test/screens/budget_screen_smoke_test.dart`: no issues.
- Focused Budget/Mon Argent/Data Spine suite: 79 passed.
- Claude Opus 4.7 review verdict: pass. Low nits on assertion precision and
  36-month coupling were addressed in the test.

## Next

Continue closing the QA audit list: route-extra completion on direct `/budget`
open is the next navigation guard before any shared present-budget view builder.
