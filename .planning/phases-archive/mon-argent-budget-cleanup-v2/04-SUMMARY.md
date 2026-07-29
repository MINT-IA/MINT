---
phase: mon-argent-budget-cleanup-v2
plan: 04
status: complete
completed_at: 2026-05-26
branch: codex/mon-argent-budget-cleanup-v2
---

# Summary — BudgetScreen Available Consistency

## Outcome

The BudgetScreen top breakdown now subtracts the future envelope before
showing `Disponible`, matching the hero number and the formula proof. When a
future envelope exists, it is displayed as its own row instead of being hidden
from the first breakdown.

## Files

- `apps/mobile/lib/screens/budget/budget_screen.dart`
- `apps/mobile/test/screens/budget_screen_smoke_test.dart`

## Verification

- `flutter test test/screens/budget_screen_smoke_test.dart --plain-name 'BudgetScreen top breakdown subtracts future envelope from available'`:
  1 passed.
- Focused Budget/Mon Argent/Data Spine suite: 78 passed after Phase 05.
- Targeted analyze: no issues.
- Claude Opus 4.7 review requested changes on deficit styling; fixed by
  rendering negative `Disponible` values in error color while preserving the
  unclamped amount.

## Next

Follow the architecture audit: introduce a shared present-budget view builder
only after direct-open regressions are covered. Keep the current fix small so
the editor semantics remain intact.
