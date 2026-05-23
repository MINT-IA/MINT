---
phase: mint-data-spine-plan-vivant-v1
plan: 01
status: complete
completed_at: 2026-05-23
type: tdd
---

# Plan 01 Summary — Data Spine Snapshot

## Goal

Create the first typed Data Spine layer for mobile without adding persistence, UI wiring, backend changes, or new financial calculations.

## Accomplished

- Added immutable data spine models in `apps/mobile/lib/models/data_spine_snapshot.dart`.
- Added pure derivation service `DataSpineService.fromProfile()` in `apps/mobile/lib/services/data_spine/data_spine_service.dart`.
- Added TDD coverage in `apps/mobile/test/services/data_spine_service_test.dart`.
- Reused `BudgetLivingEngine.compute(profile)` as the only budget source.
- Derived Swiss pillar position for AVS, LPP, and 3a.
- Marked missing pillar facts as `PillarFactState.missing` instead of estimating them.
- Added source/freshness/confidence metadata via existing `CoachProfile.dataSources` and `dataTimestamps`.

## Verification

- `cd apps/mobile && flutter test test/services/data_spine_service_test.dart` — PASS, 5 tests.
- `cd apps/mobile && flutter test test/services/data_spine_service_test.dart test/services/budget_living_engine_test.dart` — PASS, 40 tests.
- `cd apps/mobile && flutter analyze lib/models/data_spine_snapshot.dart lib/services/data_spine/data_spine_service.dart` — PASS, no issues.
- `git diff --check` — PASS.

## Explicit Non-Work

- Did not wire UI.
- Did not add Maestro flow yet.
- Did not modify persistence.
- Did not modify backend.
- Did not let the LLM own or infer facts.
- Did not duplicate budget calculations outside `BudgetLivingEngine`.

## Next

Plan 02 should add trajectory/plan summary derivation and decide how far to extend the existing `BudgetSnapshot` versus composing it inside the new spine.
