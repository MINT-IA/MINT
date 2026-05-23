---
phase: mint-data-spine-plan-vivant-v1
plan: 02
status: complete
completed_at: 2026-05-23
type: tdd
---

# Plan 02 Summary — Budget Trajectory Summary

## Goal

Add the first deterministic "plan vivant" primitive to the mobile data spine: a typed trajectory summary from current budget capacity to the user's first goal.

## Accomplished

- Added `TrajectoryStatus` and `TrajectorySummary` to `apps/mobile/lib/models/data_spine_snapshot.dart`.
- Added `DataSpineSnapshot.trajectory`.
- Extended `DataSpineService.fromProfile()` with pure trajectory derivation.
- Used the existing `BudgetSnapshot` and `BudgetLivingEngine` cashflow as the budget source.
- Covered three core states with tests:
  - `onTrack` when monthly capacity covers the required amount;
  - `blocked` when current monthly free cashflow is negative;
  - `insufficientData` when the target amount/date is missing.

## Verification

- `cd apps/mobile && flutter test test/services/data_spine_service_test.dart` — PASS, 8 tests.
- `cd apps/mobile && flutter test test/services/data_spine_service_test.dart test/services/budget_living_engine_test.dart` — PASS, 43 tests.
- `cd apps/mobile && flutter analyze lib/models/data_spine_snapshot.dart lib/services/data_spine/data_spine_service.dart` — PASS, no issues.
- `git diff --check` — PASS.

## Explicit Non-Work

- Did not wire UI.
- Did not add Maestro flow yet.
- Did not modify persistence.
- Did not modify backend.
- Did not route this into the coach prompt yet.

## Next

Plan 03 should generate a structured coach context packet from `DataSpineSnapshot`, so the LLM receives facts, freshness, missing fields, trajectory status, and citation-ready values without touching raw profile maps.
