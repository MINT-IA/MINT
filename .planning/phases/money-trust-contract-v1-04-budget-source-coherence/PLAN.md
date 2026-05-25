# Money Trust Contract v1 — 04 Budget Source Coherence

## Goal
Make Budget and Mon Argent display the same trusted monthly numbers after direct budget setup/relaunch, without allowing stale DataSpine/BudgetSnapshot values to override fresh BudgetInputs.

## Scope
- BudgetSummaryCard source precedence.
- BudgetScreen present budget deficit preservation.
- Focused widget/screen tests.

## Acceptance
- Mon Argent month card prefers fresh BudgetInputs/BudgetPlan over stale BudgetSnapshot when both are present.
- BudgetScreen detailed flow keeps negative monthlyFree for deficit mode.
- Existing budget/mon_argent focused tests pass.
