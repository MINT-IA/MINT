# Mint Data Spine + Plan Vivant v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first typed mobile data spine so Mint can derive situation, budget, pillars, trajectory, and coach context from one canonical profile path.

**Architecture:** Keep `wizard_answers_v2 -> CoachProfile` as the source path. Add a pure typed derivation layer first, then wire budget/pillars, coach context, UI, and Maestro proof in small phases. Avoid new persistence and avoid broad navigation changes.

**Tech Stack:** Flutter/Dart, existing `CoachProfile`, existing `BudgetLivingEngine`, existing mobile tests, Maestro simulator flows.

---

## File Structure

- `apps/mobile/lib/models/data_spine_snapshot.dart` — immutable typed objects for the spine.
- `apps/mobile/lib/services/data_spine/data_spine_service.dart` — pure derivation from `CoachProfile`.
- `apps/mobile/test/services/data_spine_service_test.dart` — TDD proof for Plan 01.
- `apps/mobile/lib/services/coach/data_spine_coach_context.dart` — later structured coach context packet.
- `tools/simulator/flows/maestro-perfect-set/flow_data_spine_budget_persistence.yaml` — later proof flow.

## Task 1: Data Spine Snapshot

**Files:**
- Create: `apps/mobile/lib/models/data_spine_snapshot.dart`
- Create: `apps/mobile/lib/services/data_spine/data_spine_service.dart`
- Test: `apps/mobile/test/services/data_spine_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create tests asserting:

```dart
final spine = DataSpineService.fromProfile(profile, now: fixedNow);
expect(spine.situation.canton.value, 'VD');
expect(spine.pillars.lpp.totalBalance.value, 50000);
expect(spine.pillars.lpp.totalBalance.state, PillarFactState.known);
expect(spine.budget.monthlyFree, closeTo(BudgetLivingEngine.compute(profile).monthlyFree, 0.01));
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/services/data_spine_service_test.dart`

Expected: FAIL because `DataSpineService` does not exist.

- [ ] **Step 3: Add immutable models**

Implement:

```dart
enum FieldConfidence { known, inferred, estimated, stale, missing }
enum FieldFreshness { fresh, stale, unknown }
enum PillarFactState { known, estimated, missing }

class DataSpineSnapshot {
  final FinancialSituation situation;
  final BudgetSnapshot budget;
  final PillarPosition pillars;
  final DateTime computedAt;
}
```

- [ ] **Step 4: Add pure service**

Implement:

```dart
abstract final class DataSpineService {
  static DataSpineSnapshot fromProfile(CoachProfile profile, {DateTime? now}) {
    final computedAt = now ?? DateTime.now();
    final budget = BudgetLivingEngine.compute(profile);
    return DataSpineSnapshot(
      situation: FinancialSituation.fromProfile(profile),
      budget: budget,
      pillars: PillarPosition.fromProfile(profile),
      computedAt: computedAt,
    );
  }
}
```

- [ ] **Step 5: Verify**

Run:

```bash
cd apps/mobile
flutter test test/services/data_spine_service_test.dart test/services/budget_living_engine_test.dart
flutter analyze lib/models/data_spine_snapshot.dart lib/services/data_spine/data_spine_service.dart
```

Expected: PASS.

## Task 2: Budget + Trajectory Derivation

**Files:**
- Modify: `apps/mobile/lib/models/data_spine_snapshot.dart`
- Modify: `apps/mobile/lib/services/data_spine/data_spine_service.dart`
- Test: `apps/mobile/test/services/data_spine_service_test.dart`

- [ ] Add `TrajectorySummary` with `onTrackStatus`, `currentPathMonthlyFree`, `targetPathMonthlyFree`, and `nextLeverId`.
- [ ] Add tests for deficit, insufficient data, and on-track cases.
- [ ] Keep calculations delegated to existing budget/projection services.

## Task 3: Coach Context

**Files:**
- Create: `apps/mobile/lib/services/coach/data_spine_coach_context.dart`
- Modify: existing mobile coach request payload code only after grep verification.
- Test: `apps/mobile/test/services/coach/data_spine_coach_context_test.dart`

- [ ] Serialize situation, budget, pillars, missing fields, and confidence warnings.
- [ ] Redact or omit sensitive raw values where current coach request policy requires it.
- [ ] Add tests proving missing fields are explicit and no field is invented.

## Task 4: UI + Maestro Proof

**Files:**
- Modify one existing budget/situation UI surface.
- Create: `tools/simulator/flows/maestro-perfect-set/flow_data_spine_budget_persistence.yaml`

- [ ] Wire one visible budget/situation surface to the spine.
- [ ] Add Maestro flow: enter budget/situation values, save, relaunch, assert UI values, ask coach, assert same values in explanation.
- [ ] Capture screenshots under `screenshots/walkthrough/data-spine/`.

## Self-Review

- Spec coverage: covers canonical data spine, budget, pillars, coach context, and Maestro proof.
- Scope control: does not include bank aggregation, Chat Vivant canvas, broad navigation redesign, or backend event-log deployment.
- Type consistency: `DataSpineSnapshot`, `FinancialSituation`, `PillarPosition`, and `BudgetSnapshot` are stable names used throughout.
