---
phase: mon-argent-budget-cleanup-v2
plan: 07
status: complete
completed_at: 2026-05-26
branch: codex/mon-argent-budget-cleanup-v2
---

# Summary — Budget RouteExtra Return Contract

## Outcome

Added a navigation regression for orchestrated chat-to-budget flows. A
`BudgetContainerScreen` opened with `routeExtra` must forward the sequence
context into `BudgetScreen`; when the user pops the route, Budget emits a Tier A
`ScreenReturn.completed` with the original `runId`, `stepId`, and budget
outputs.

## Files

- `apps/mobile/test/screens/budget_screen_smoke_test.dart`

## Verification

- `flutter test test/screens/budget_screen_smoke_test.dart --plain-name 'BudgetContainerScreen routeExtra emits Tier A return on pop'`:
  1 passed.
- `flutter analyze test/screens/budget_screen_smoke_test.dart`: no issues.
- Focused Budget/Mon Argent/Data Spine suite: 80 passed.
- Claude Opus 4.7 review verdict: pass, no actionable findings.

## Next

Move toward the shared present-budget view builder only after these route/data
guards are merged, because the tests now protect the central chat and tab entry
paths.
