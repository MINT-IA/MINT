---
phase: mint-data-spine-plan-vivant-v1
plan: 15
type: flutter-tdd
depends_on:
  - mint-data-spine-plan-vivant-v1-14-budget-capture-readiness-PLAN.md
files_modified:
  - apps/mobile/lib/models/mint_user_state.dart
  - apps/mobile/lib/services/mint_state_engine.dart
  - apps/mobile/lib/services/data_spine/data_spine_service.dart
  - apps/mobile/test/services/mint_state_engine_test.dart
autonomous: true
requirements:
  - REQ-DSP-15
must_haves:
  truths:
    - "Situation financière and budget are core inputs, not side widgets."
    - "All future visualisations, arbitrages, and coach scenes must converge on the same central read model."
    - "Do not create a second profile or budget truth beside CoachProfile, BudgetSnapshot, and DataSpineSnapshot."
    - "The first step is a contract layer; UI beauty follows once data injection is stable."
---

# Plan 15 — Core input contract

## TLDR

Promote `DataSpineSnapshot` into the unified `MintUserState` so future widgets,
visualisations, arbitrages, and chat scenes can consume one central structured
read model: situation, budget, pillars, and trajectory.

## Context

Plans 13 and 14 made the current situation and budget capture paths more honest:

```text
wizard_answers_v2 -> CoachProfile -> DataSpineSnapshot
```

But most app surfaces still read directly from `CoachProfile`,
`BudgetProvider`, or specialized local aggregators. That keeps the historical
risk alive:

```text
widget value != coach value != arbitrage value
```

The product direction after the visual brainstorm and `_to-MINT 4` review is:

- situation financière = Swiss long-term spine: AVS, LPP, 3a, libre/dettes;
- budget = daily movement layer: monthly free, charges, cadence, capacity;
- chat vivant = interpretation surface that shows scenes based on those same
  facts;
- screens should become quieter and more visual, but not by inventing new data
  paths.

## Scope

### Task 1 — RED: central state exposes data spine

Add a failing test in `mint_state_engine_test.dart`:

- `MintStateEngine.compute()` returns a `MintUserState.dataSpineSnapshot`;
- the `dataSpineSnapshot.budget` instance is the same `BudgetSnapshot` held by
  `MintUserState.budgetSnapshot`;
- situation and pillar values are present for the Julien golden profile.

### Task 2 — Make `DataSpineService` accept a precomputed budget

Extend `DataSpineService.fromProfile()` with an optional `BudgetSnapshot`
argument.

Invariant:

- if a budget is passed, do not recompute `BudgetLivingEngine`;
- if no budget is passed, keep current behavior for existing callers.

### Task 3 — Add `DataSpineSnapshot?` to `MintUserState`

Add:

- `final DataSpineSnapshot? dataSpineSnapshot`;
- `bool get hasDataSpineSnapshot`;
- `copyWith(dataSpineSnapshot: ...)`.

### Task 4 — Compute data spine once in `MintStateEngine`

After `budgetSnapshot = BudgetLivingEngine.compute(profile)`, derive:

```dart
dataSpineSnapshot = DataSpineService.fromProfile(
  profile,
  now: currentTime,
  budget: budgetSnapshot,
);
```

If budget computation fails, leave both fields null. Do not silently recompute
budget in a fallback branch.

### Task 5 — Verify

Minimum commands:

```bash
cd apps/mobile && flutter test test/services/mint_state_engine_test.dart test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart
cd apps/mobile && flutter analyze lib/models/mint_user_state.dart lib/services/mint_state_engine.dart lib/services/data_spine/data_spine_service.dart test/services/mint_state_engine_test.dart test/services/data_spine_service_test.dart
git diff --check
```

## Non-Goals

- No new visual widget in this plan.
- No route change.
- No ARB change.
- No new financial calculation.
- No backend change.
- No migration of every screen yet; that is the next plan.

## Next

Plan 16 should migrate one narrow consumer surface to this central read model.
Recommended first target: `MonArgentScreen`, because it currently combines
`BudgetProvider`, `CoachProfileProvider`, and `PatrimoineAggregator` manually.

The design target for that follow-up is not a dense dashboard. It should be:

- one hero number;
- confidence/freshness visible;
- 3-pillar situation rows;
- budget movement as cadence;
- chat CTA that opens a scene only when useful.
