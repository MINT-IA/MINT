---
phase: mint-data-spine-plan-vivant-v1
plan: 02
type: tdd
wave: 2
depends_on:
  - mint-data-spine-plan-vivant-v1-01-data-spine-snapshot-PLAN.md
files_modified:
  - apps/mobile/lib/models/data_spine_snapshot.dart
  - apps/mobile/lib/services/data_spine/data_spine_service.dart
  - apps/mobile/test/services/data_spine_service_test.dart
autonomous: true
requirements:
  - REQ-DSP-02
must_haves:
  truths:
    - "Trajectory is derived from CoachProfile.goalA and the existing BudgetSnapshot."
    - "Budget cashflow remains owned by BudgetLivingEngine."
    - "Blocked budget state is explicit when monthly free cashflow is negative."
    - "Missing target data is explicit and does not produce invented monthly requirements."
  artifacts:
    - path: "apps/mobile/lib/models/data_spine_snapshot.dart"
      provides: "TrajectoryStatus and TrajectorySummary models."
      contains: "class TrajectorySummary"
    - path: "apps/mobile/lib/services/data_spine/data_spine_service.dart"
      provides: "Pure trajectory derivation inside DataSpineService."
      contains: "_trajectoryFromProfile"
    - path: "apps/mobile/test/services/data_spine_service_test.dart"
      provides: "TDD coverage for on-track, blocked, and insufficient-data trajectories."
      contains: "derives on-track trajectory"
---

# Plan 02 — Budget Trajectory Summary

## Objective

Extend the mobile data spine with a deterministic A-to-B trajectory summary derived from the current budget and the user's first goal.

This is the first "plan vivant" primitive: Mint can now say whether the user is currently on track, drifting, blocked, or missing enough data before any LLM narration is involved.

Out of scope:
- no UI wiring;
- no coach prompt wiring;
- no persistence changes;
- no backend changes;
- no new budget engine.

## Context

@.planning/phases/mint-data-spine-plan-vivant-v1/CONTEXT.md
@.planning/phases/mint-data-spine-plan-vivant-v1/mint-data-spine-plan-vivant-v1-01-data-spine-snapshot-PLAN.md
@apps/mobile/lib/models/financial_plan.dart
@apps/mobile/lib/models/budget_snapshot.dart
@apps/mobile/lib/services/budget_living_engine.dart
@apps/mobile/lib/services/plan_tracking_service.dart

## Tasks

### Task 1: Write failing trajectory tests

Files: `apps/mobile/test/services/data_spine_service_test.dart`

Add tests for:
- on-track trajectory when monthly capacity covers target;
- blocked trajectory when current monthly free cashflow is negative;
- insufficient-data trajectory when no target amount exists.

Verify red first:

```bash
cd apps/mobile && flutter test test/services/data_spine_service_test.dart
```

### Task 2: Add trajectory model

Files: `apps/mobile/lib/models/data_spine_snapshot.dart`

Add:
- `TrajectoryStatus`;
- `TrajectorySummary`;
- `DataSpineSnapshot.trajectory`.

Acceptance:
- model is immutable;
- model has no Flutter, provider, storage, or API dependency;
- `monthlyRequired` is nullable for insufficient data.

### Task 3: Derive trajectory from budget and goal

Files: `apps/mobile/lib/services/data_spine/data_spine_service.dart`

Implement trajectory derivation from:
- `BudgetSnapshot.monthlyFree`;
- `BudgetSnapshot.present.monthlySavings`;
- `CoachProfile.goalA.targetAmount`;
- `CoachProfile.goalA.targetDate`.

Acceptance:
- negative monthly free cashflow returns `TrajectoryStatus.blocked`;
- missing target amount/date returns `TrajectoryStatus.insufficientData`;
- capacity >= required returns `TrajectoryStatus.onTrack`;
- capacity < required returns `TrajectoryStatus.drifting`;
- no storage, network, backend call, or LLM inference.

### Task 4: Verify targeted perimeter

Run:

```bash
cd apps/mobile && flutter test test/services/data_spine_service_test.dart test/services/budget_living_engine_test.dart
cd apps/mobile && flutter analyze lib/models/data_spine_snapshot.dart lib/services/data_spine/data_spine_service.dart
git diff --check
```

## Success Criteria

- Data spine exposes a typed trajectory summary.
- Existing budget tests still pass.
- No persistence or UI changed.
- The next plan can build a structured coach context packet from this spine.
