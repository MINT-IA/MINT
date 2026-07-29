# Money Trust Contract v1 — 04 Budget Source Coherence Verification

This verification record covers the narrow trust fix for Budget and Mon Argent
monthly-number coherence.

## Result

PASS — focused Flutter checks pass locally.

## Commands

- `cd apps/mobile && flutter test test/widgets/mon_argent_budget_summary_card_test.dart`
  - Result: `All tests passed`
- `cd apps/mobile && flutter test test/screens/budget_screen_smoke_test.dart`
  - Result: `All tests passed`
- `cd apps/mobile && flutter analyze --no-fatal-infos lib/widgets/mon_argent/budget_summary_card.dart lib/screens/budget/budget_screen.dart test/widgets/mon_argent_budget_summary_card_test.dart test/screens/budget_screen_smoke_test.dart`
  - Result: `No issues found`
- `cd apps/mobile && flutter test test/domain/budget_service_test.dart test/domain/budget/budget_service_test.dart test/services/budget_living_engine_test.dart`
  - Result: `105 passed`
- `git diff --check`
  - Result: pass
- `python3 tools/checks/wiki_lint.py lint`
  - Result: no FAIL-level violations; existing warnings only

## Reviewed Risks

- `BudgetService.computePlan` still clamps `available` to zero. This is kept
  intentionally because `BudgetPlan.available` is the amount available to
  allocate, not the signed cashflow truth.
- `BudgetScreen` now keeps the signed `PresentBudget.monthlyFree`, so the
  detailed flow can show a deficit.
- `BudgetSummaryCard` now prefers fresh `BudgetInputs` plus `BudgetPlan` over a
  stale `BudgetSnapshot` when both are present.

## Still Open

- Device-level proof still needs Maestro:
  `tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml`.
- A larger convergence phase is still needed to remove or hash-guard stale
  `budget_inputs_v1` restore behavior.
