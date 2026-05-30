# Phase 21 Summary

## What Changed
- `DataSpineService._explicitAmount` no longer treats an empty `userProvidedFields` set as implicit permission to expose profile amounts.
- `CoachContextPacketService` now adds missing-field entries for `situation.monthlyHousingCost` and `situation.lamalPremiumMonthly` when they are not trustable.
- Backend coach packet allowlists now accept the full mobile situation/pillar fact set needed by the coach packet contract, including housing, LAMal, liquidity, debt, and annual 3a contribution.
- Regression tests cover both the missing-data path and the backend sanitizer pass-through.

## Why
The coach should reason from structured evidence, not from profile defaults. This phase closes a divergence where Budget/Money screens could be cautious while the coach packet still exposed untrusted values as facts.

## Specialist Review Input
- Architecture agent confirmed the critical path: mobile budget setup -> `BudgetInputs` -> `BudgetLivingEngine`/`DataSpineService` -> `CoachContextPacketService` -> `CoachOrchestrator` -> backend sanitizer.
- QA agent recommended keeping P1 deterministic around packet/citation guards, with live LLM Maestro flows as smoke rather than primary proof.

## Remaining Risk
`get_budget_status` still has a separate backend path that can fall back to legacy `monthly_income` / `monthly_expenses` context. A later phase should converge that tool with the structured packet or explicitly define precedence.

