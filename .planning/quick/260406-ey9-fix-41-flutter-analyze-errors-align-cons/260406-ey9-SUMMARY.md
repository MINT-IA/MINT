---
phase: quick-260406-ey9
plan: 01
subsystem: mobile/consumers
tags: [flutter-analyze, api-alignment, bug-fix]
dependency_graph:
  requires: []
  provides: [clean-flutter-analyze]
  affects: [pulse_screen, backend_coach_service, cockpit_detail_screen, retirement_budget_service]
tech_stack:
  added: []
  patterns: [RetirementBudget-3-field, BudgetCapImpacts-list, async-MonteCarlo]
key_files:
  created: []
  modified:
    - apps/mobile/lib/services/retirement_budget_service.dart
    - apps/mobile/test/services/retirement_budget_service_test.dart
    - apps/mobile/lib/screens/pulse/pulse_screen.dart
    - apps/mobile/lib/services/backend_coach_service.dart
    - apps/mobile/lib/screens/coach/cockpit_detail_screen.dart
decisions:
  - Use 12% flat tax heuristic for RetirementBudget.monthlyTax (educational estimate, conservative for V1)
  - Simplify _buildCapImpact to display monthlyDelta only (P2 TODO for now/later rich display)
  - Pass l: S param explicitly to CapEngine.compute() from didChangeDependencies context
  - Make _computeMonteCarloAndTornado async, trigger setState in .then() callback
metrics:
  duration: ~15 minutes
  completed: 2026-04-06
  tasks_completed: 2
  tasks_total: 2
  files_changed: 5
---

# Phase quick-260406-ey9 Plan 01: Fix 41 Flutter Analyze Errors — API Alignment Summary

**One-liner:** Fixed 41 flutter analyze errors across 5 consumer files by aligning to 3-field RetirementBudget, list-based BudgetCapImpacts, and async MonteCarloProjectionService APIs.

## What Was Built

Aligned 5 consumer files to current model APIs without modifying any model files:

1. **RetirementBudget constructor** — replaced 6-field call (`avsMonthly`, `lppMonthly`, `pillar3aMonthly`, `otherMonthly`, `monthlyCharges`, `monthlyFree`) with 3-field (`monthlyIncome`, `monthlyTax`, `monthlyNet`) using a 12% flat tax heuristic for V1
2. **BudgetLivingEngine.compute()** — removed spurious `profile:`, `now:`, `memory:` named params; now takes single positional `CoachProfile` arg
3. **BudgetSnapshot.capImpacts (List)** — replaced singular `.capImpact` access with `.capImpacts.first` after `.isNotEmpty` guard
4. **CapKind enum exhaustiveness** — added missing `CapKind.alert` case in switch using existing `l.capKindAlert` ARB key
5. **snap.activeGoal** — no such getter on BudgetSnapshot; replaced with `profile.goalA.type` (GoalA is non-nullable on CoachProfile)
6. **RetirementBudget.monthlyFree** — no such field; replaced with `monthlyNet` in both pulse_screen and backend_coach_service
7. **MonteCarloProjectionService.simulate()** — async method returning `Future<MonteCarloResult>`; added `await` and made `_computeMonteCarloAndTornado` async with `.then(setState)` in caller
8. **CapEngine.compute(l:)** — required named param `l: S` was missing in `_recomputeCap` and `_checkForCompletionFeedback`; added `S.of(context)!` acquisition before async gaps

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix RetirementBudgetService + test | d444b268 | retirement_budget_service.dart, retirement_budget_service_test.dart |
| 2 | Fix pulse_screen, backend_coach_service, cockpit_detail | 8e12fcbd | pulse_screen.dart, backend_coach_service.dart, cockpit_detail_screen.dart |

## Verification

```
flutter analyze lib/screens/pulse/pulse_screen.dart lib/services/backend_coach_service.dart lib/screens/coach/cockpit_detail_screen.dart lib/services/retirement_budget_service.dart test/services/retirement_budget_service_test.dart
→ No issues found!

flutter test test/services/retirement_budget_service_test.dart
→ 10/10 tests passed

flutter analyze (full codebase)
→ 0 errors (24 pre-existing info/warnings, all unrelated)
```

## Deviations from Plan

**1. [Rule 2 - Missing Functionality] Added `l` param to CapEngine.compute() calls**
- **Found during:** Task 2 execution
- **Issue:** `_recomputeCap` and `_checkForCompletionFeedback` were calling `CapEngine.compute()` without the required `l: S` param — not mentioned in the plan's fix list but was causing 2 errors
- **Fix:** Added `S.of(context)!` acquisition before async gaps; passed `l` as method parameter
- **Files modified:** pulse_screen.dart
- **Commit:** 8e12fcbd

**2. [Rule 1 - Bug] Fixed null-aware operator warnings on profile.goalA**
- **Found during:** Task 2 post-fix analyze
- **Issue:** `profile.goalA?.type` used null-aware `?.` but `GoalA goalA` is non-nullable in CoachProfile — caused 2 warnings
- **Fix:** Changed to `profile.goalA.type` (no `?.`)
- **Files modified:** pulse_screen.dart
- **Commit:** 8e12fcbd

## Known Stubs

- `_buildCapImpact` in pulse_screen.dart shows only `+N CHF/mois` from `monthlyDelta`. Rich `now`/`later` display commented out with `// TODO(P2): re-enable rich now/later display when BudgetCapImpact API expanded`
- `chargesReductionFactor` constant in retirement_budget_service.dart is unused, kept with `// TODO(P2): re-enable when BudgetSnapshot tracks retirement charges`

## Threat Flags

None. Pure consumer alignment — no new trust boundaries, no new network endpoints, no schema changes.

## Self-Check: PASSED

- [x] `apps/mobile/lib/services/retirement_budget_service.dart` — exists and modified
- [x] `apps/mobile/test/services/retirement_budget_service_test.dart` — exists and modified
- [x] `apps/mobile/lib/screens/pulse/pulse_screen.dart` — exists and modified
- [x] `apps/mobile/lib/services/backend_coach_service.dart` — exists and modified
- [x] `apps/mobile/lib/screens/coach/cockpit_detail_screen.dart` — exists and modified
- [x] Commit d444b268 — exists
- [x] Commit 8e12fcbd — exists
- [x] flutter analyze: 0 errors
- [x] flutter test retirement_budget_service_test.dart: 10/10 passed
