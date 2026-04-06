---
phase: 07-life-event-journeys
plan: 03
subsystem: navigation, ui
tags: [gorouter, cap-sequence, intent-router, chiffre-choc, journeys]

# Dependency graph
requires:
  - phase: 07-life-event-journeys
    provides: "CapSequenceEngine firstJob + housingPurchase sequences, IntentRouter firstJob mapping, journey tests"
provides:
  - "Correct GoRouter-registered intentTags for fj_02 (/first-job) and hou_06 (/arbitrage/location-vs-propriete)"
  - "stress_prevoyance stressType for firstJob producing 3a/compound growth premier eclairage"
  - "Updated journey tests asserting registered route strings"
affects:
  - "cap-sequence navigation"
  - "intent-router routing"
  - "chiffre-choc-selector stress type dispatch"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "intentTag strings in CapSequenceEngine must match registered GoRouter paths exactly"
    - "stress_prevoyance stressType dispatches to 3a tax saving > compound growth > retirement income"

key-files:
  created: []
  modified:
    - apps/mobile/lib/services/cap_sequence_engine.dart
    - apps/mobile/lib/services/coach/intent_router.dart
    - apps/mobile/lib/services/chiffre_choc_selector.dart
    - apps/mobile/test/journeys/firstjob_journey_test.dart
    - apps/mobile/test/journeys/housing_journey_test.dart

key-decisions:
  - "stress_prevoyance routes to 3a tax saving first, then compound growth (age < 35), then retirement income as fallback — prioritizes most actionable insight for first job context"
  - "intentTag strings must exactly match GoRouter path declarations (verified against app.dart line 510 and 805)"

patterns-established:
  - "intentTag verification pattern: grep registered routes in app.dart before setting intentTag values"

requirements-completed: [LEJ-01, LEJ-02, LEJ-04]

# Metrics
duration: 25min
completed: 2026-04-06
---

# Phase 07 Plan 03: Gap Closure Summary

**Fixed 2 navigation-breaking GoRouter route mismatches and added stress_prevoyance case routing firstJob premier eclairage to 3a/compound growth numbers instead of hourly rate**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-06T06:20:00Z
- **Completed:** 2026-04-06T06:48:42Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Fixed `fj_02_salary_xray` intentTag: `/premier-emploi` (unregistered) -> `/first-job` (registered GoRouter path at app.dart line 510)
- Fixed `hou_06_compare` intentTag: `/location-vs-propriete` (unregistered) -> `/arbitrage/location-vs-propriete` (registered GoRouter path at app.dart line 805)
- Added `case 'stress_prevoyance'` to `ChiffreChocSelector._selectByStress()` cascading: 3a tax saving > compound growth (age < 35) > retirement income
- Fixed `intentChipPremierEmploi` mapping: `stress_budget` -> `stress_prevoyance`, `suggestedRoute` `/premier-emploi` -> `/first-job`
- Updated all 4 test assertions in firstjob_journey_test.dart and 1 in housing_journey_test.dart; all 63 journey tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix broken intentTags and add stress_prevoyance stressType** - `cc95fa14` (fix)
2. **Task 2: Update journey tests to assert correct registered routes** - `59602949` (test)

## Files Created/Modified

- `apps/mobile/lib/services/cap_sequence_engine.dart` - Fixed fj_02 and hou_06 intentTag strings to registered GoRouter paths
- `apps/mobile/lib/services/coach/intent_router.dart` - Fixed intentChipPremierEmploi stressType and suggestedRoute
- `apps/mobile/lib/services/chiffre_choc_selector.dart` - Added case 'stress_prevoyance' dispatching to 3a/compound/retirement numbers
- `apps/mobile/test/journeys/firstjob_journey_test.dart` - Updated 4 assertions (stress_budget->stress_prevoyance, /premier-emploi->/first-job x3)
- `apps/mobile/test/journeys/housing_journey_test.dart` - Updated 1 assertion (/location-vs-propriete->/arbitrage/location-vs-propriete)

## Decisions Made

- `stress_prevoyance` cascade order: 3a tax saving first (most actionable if eligible), then compound growth for young users (< 35), then retirement income if salary data exists. This matches the firstJob user mindset: "what should I start doing?" not "what will I earn in retirement?"
- Used all existing builder methods (`_buildTaxSaving3aChoc`, `_buildCompoundGrowthChoc`, `_buildRetirementIncomeChoc`) — no new calculation logic added, preserving single source of truth in financial_core/

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Git worktree sparse checkout required checking out specific files before editing (`git checkout HEAD -- file1 file2`). The worktree only had files modified in the planning branch commits, not the full project tree. Tests were verified by temporarily copying updated files to the main project (which has the full Flutter toolchain). No logic changes were required beyond what the plan specified.

## Known Stubs

None - all changes are targeted bug fixes to string constants and a new switch case. No UI stubs introduced.

## Threat Flags

No new security-relevant surfaces introduced. Changes are string constant corrections and a new switch case in existing pattern.

## Next Phase Readiness

- All 3 gap closure items resolved: both navigation-breaking GoRouter route mismatches and the stressType mismatch
- 63 journey tests pass with correct route string assertions
- No production code references unregistered routes `/premier-emploi` or bare `/location-vs-propriete`
- Phase 07 verification criteria for LEJ-01, LEJ-02, LEJ-04 satisfied

## Self-Check: PASSED

- `cc95fa14` — verified via `git log --oneline | grep cc95fa14`
- `59602949` — verified via `git log --oneline | grep 59602949`
- All 63 journey tests: `+63: All tests passed!` confirmed
- 0 matches for `/premier-emploi` in `lib/`: confirmed
- 0 matches for bare `/location-vs-propriete` intentTag in `lib/`: confirmed
- `case 'stress_prevoyance'` in chiffre_choc_selector.dart: confirmed at line 115

---
*Phase: 07-life-event-journeys*
*Completed: 2026-04-06*
