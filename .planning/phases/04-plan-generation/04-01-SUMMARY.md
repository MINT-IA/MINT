---
phase: 04-plan-generation
plan: 01
subsystem: ui
tags: [flutter, shared-preferences, dart, provider, i18n, financial-plan]

# Dependency graph
requires: []
provides:
  - "FinancialPlan data model with JSON round-trip, milestone generation, and deterministic profile hash"
  - "FinancialPlanService static CRUD with SharedPreferences, max-3 eviction, and corruption resilience"
  - "FinancialPlanProvider ChangeNotifier with hasPlan/isPlanStale/currentPlan and profile-change staleness detection"
  - "12 planCard_* i18n keys in all 6 ARB files (fr/en/de/es/it/pt)"
affects:
  - "04-02-PLAN"
  - "04-03-PLAN"
  - "Any UI rendering financial plans"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Polynomial rolling hash for deterministic profile hashing (hash = (hash * 31 + c) & 0x7FFFFFFF)"
    - "Static service class pattern (GoalTrackerService-style) for SharedPreferences persistence"
    - "SchedulerBinding.addPostFrameCallback for safe notifyListeners from profile listener"
    - "@visibleForTesting helpers on provider for test isolation without full Flutter widget tree"

key-files:
  created:
    - apps/mobile/lib/models/financial_plan.dart
    - apps/mobile/lib/services/financial_plan_service.dart
    - apps/mobile/lib/providers/financial_plan_provider.dart
    - apps/mobile/test/models/financial_plan_test.dart
    - apps/mobile/test/services/financial_plan_service_test.dart
    - apps/mobile/test/providers/financial_plan_provider_test.dart
  modified:
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
    - apps/mobile/lib/l10n/app_localizations*.dart (regenerated)

key-decisions:
  - "Used salaireBrutMensuel (not salaireBrutAnnuel) in computeProfileHash — plan spec used simplified interface; actual CoachProfile field is monthly"
  - "Exposed @visibleForTesting setPlanDirect/checkStalenessForTest on provider instead of injecting SharedPreferences — avoids complex dependency injection for unit tests while keeping production code clean"
  - "Separate test-time staleness check (synchronous, no postFrameCallback) and production check (async, postFrameCallback) — prevents test harness frame scheduling issues"

patterns-established:
  - "Profile hash: polynomial rolling hash on concatenated key fields, never Object.hash()"
  - "Service pattern: static methods + optional SharedPreferences parameter for testability"
  - "Provider staleness: addListener on CoachProfileProvider triggers _checkStaleness, notifyListeners in postFrameCallback"

requirements-completed:
  - PLN-02
  - PLN-03
  - PLN-04

# Metrics
duration: 25min
completed: 2026-04-05
---

# Phase 04 Plan 01: FinancialPlan data layer with deterministic profile-hash staleness detection

**FinancialPlan model + SharedPreferences service + reactive provider with postFrameCallback-safe staleness detection, plus 12 plan card i18n keys across 6 languages**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-05T17:30:00Z
- **Completed:** 2026-04-05T17:54:42Z
- **Tasks:** 2 (TDD: 4 commits across RED + GREEN phases)
- **Files modified:** 12 (3 new Dart, 3 new test files, 6 ARB + 7 generated l10n)

## Accomplishments

- `FinancialPlan` + `PlanMilestone` data classes with full JSON round-trip and defensive fromJson (clamped monthlyTarget, optional projectedLow/High)
- `computeProfileHash()` top-level function using polynomial rolling hash — deterministic across Dart sessions unlike Object.hash()
- `FinancialPlanService` static CRUD with upsert-by-id, max-3 eviction (oldest evicted), corruption-resilient loadAll (try/catch returns empty list)
- `FinancialPlanProvider` ChangeNotifier detecting profile changes via hash comparison, using SchedulerBinding.addPostFrameCallback to avoid setState-during-build
- 12 planCard_* i18n keys in all 6 ARB files with correct placeholder metadata in French template
- 21 tests passing (10 model + 6 service + 5 provider)

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: failing model tests** — `e05090ff` (test)
2. **Task 1 GREEN: FinancialPlan model** — `13dc7e6f` (feat)
3. **Task 2 RED: failing service/provider tests** — `4c788525` (test)
4. **Task 2 GREEN: service + provider + i18n** — `343f250e` (feat)

## Files Created/Modified

- `apps/mobile/lib/models/financial_plan.dart` — FinancialPlan + PlanMilestone + computeProfileHash()
- `apps/mobile/lib/services/financial_plan_service.dart` — SharedPreferences CRUD, max-3 eviction
- `apps/mobile/lib/providers/financial_plan_provider.dart` — ChangeNotifier with staleness detection
- `apps/mobile/test/models/financial_plan_test.dart` — 10 tests: round-trip, milestones, hash
- `apps/mobile/test/services/financial_plan_service_test.dart` — 6 tests: save/load/upsert/evict/corrupt/delete
- `apps/mobile/test/providers/financial_plan_provider_test.dart` — 5 tests: initial state, load, staleness, clear
- `apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb` — 12 planCard_* keys each (16 entries in fr with @metadata)

## Decisions Made

- **salaireBrutMensuel vs salaireBrutAnnuel:** Plan interface spec used `salaireBrutAnnuel` but actual `CoachProfile` has `salaireBrutMensuel`. Used the real field.
- **Test helper methods `@visibleForTesting`:** Rather than injecting a mock service, exposed synchronous `setPlanDirect` and `checkStalenessForTest` methods. Keeps production code clean, tests deterministic.
- **Two staleness check paths:** Production path uses `addPostFrameCallback` (safe during widget tree builds); test path (`checkStalenessForTest`) is synchronous to avoid scheduler frame issues in test harness.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan interface used non-existent field `salaireBrutAnnuel`**
- **Found during:** Task 1 (writing tests using CoachProfile constructor)
- **Issue:** Plan's `<interfaces>` block specified `CoachProfile.salaireBrutAnnuel` but actual class has `salaireBrutMensuel`
- **Fix:** Used `salaireBrutMensuel` in both `computeProfileHash()` and test fixtures
- **Files modified:** financial_plan.dart, financial_plan_test.dart
- **Verification:** All hash tests pass with actual CoachProfile constructor
- **Committed in:** 13dc7e6f (Task 1 GREEN)

---

**Total deviations:** 1 auto-fixed (Rule 1 — interface mismatch)
**Impact on plan:** Fix was necessary for correctness. No scope creep.

## Issues Encountered

- Test initially failed to compile due to `const GoalA(targetDate: DateTime(...))` — `DateTime()` is not const in Dart. Removed `const` keyword from test fixture.

## Known Stubs

None — all fields populated, no placeholder text, service wired to SharedPreferences.

## Next Phase Readiness

- `FinancialPlan`, `FinancialPlanService`, `FinancialPlanProvider` are ready to consume in plan generation (04-02) and plan card UI (04-03)
- Provider must be registered in `main.dart` or the widget tree before use — 04-02 will handle this
- `attachProfileProvider()` must be called after both providers are initialized — 04-02 will handle this

## Self-Check: PASSED

- financial_plan.dart: FOUND
- financial_plan_service.dart: FOUND
- financial_plan_provider.dart: FOUND
- financial_plan_test.dart: FOUND
- financial_plan_service_test.dart: FOUND
- financial_plan_provider_test.dart: FOUND
- Commit e05090ff: FOUND
- Commit 13dc7e6f: FOUND
- Commit 4c788525: FOUND
- Commit 343f250e: FOUND

---
*Phase: 04-plan-generation*
*Completed: 2026-04-05*
