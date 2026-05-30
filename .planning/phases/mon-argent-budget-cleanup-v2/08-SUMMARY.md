---
phase: mon-argent-budget-cleanup-v2
plan: 08
status: complete
completed_at: 2026-05-26
branch: codex/mon-argent-budget-cleanup-v2
---

# Summary — Present Budget Read Model Builder

## Outcome

Extracted the explicit-input present budget derivation into
`PresentBudgetBuilder`. This separates the real user-facing monthly remainder
from `BudgetPlan.available`, which is intentionally clamped for envelope
allocation. BudgetScreen now uses the shared builder for its flow map and
breakdown available amount.

## Files

- `apps/mobile/lib/domain/budget/present_budget_builder.dart`
- `apps/mobile/lib/screens/budget/budget_screen.dart`
- `apps/mobile/test/domain/budget/present_budget_builder_test.dart`

## Verification

- `flutter test test/domain/budget/present_budget_builder_test.dart`: 4 passed.
- `flutter test test/screens/budget_screen_smoke_test.dart --plain-name 'BudgetScreen top breakdown subtracts future envelope from available'`:
  1 passed.
- `flutter analyze lib/domain/budget/present_budget_builder.dart lib/screens/budget/budget_screen.dart test/domain/budget/present_budget_builder_test.dart`:
  no issues.
- Focused Budget/Mon Argent/Data Spine suite: 84 passed.
- Claude Opus 4.7 review verdict: pass. Notes only: future rounding policy
  changes should keep BudgetScreen line rounding and builder rounding aligned.

## Next

Use this builder as the local BudgetScreen bridge before a larger convergence of
BudgetSnapshot, Mon Argent and future budget visualizations. Keep the scope
small until the direct-route guards from phases 05-07 are merged.
