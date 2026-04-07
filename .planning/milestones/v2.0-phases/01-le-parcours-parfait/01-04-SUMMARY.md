---
phase: 01-le-parcours-parfait
plan: 04
subsystem: testing
tags: [flutter, integration-test, golden-path, onboarding, regional-voice]

# Dependency graph
requires:
  - phase: 01-le-parcours-parfait/01-03
    provides: Rewired 4-screen onboarding pipeline (intent -> quick-start -> chiffre-choc -> plan)
provides:
  - Lea golden path integration test (17 tests) covering full onboarding pipeline
  - CI guard: test fails if any navigation link, data flow, or onboarding flag breaks
affects: [01-05]

# Tech tracking
tech-stack:
  added: []
  patterns: [golden-path-persona-test-pattern]

key-files:
  created:
    - apps/mobile/test/journeys/lea_golden_path_test.dart
  modified: []

key-decisions:
  - "Used rawValue (double) instead of value (formatted String) for numeric assertions on ChiffreChoc"
  - "Service-level tests (not widget E2E) consistent with existing journey test pattern"

patterns-established:
  - "Golden path persona test: define persona constants, test each pipeline stage independently, verify flag lifecycle"

requirements-completed: [PATH-06]

# Metrics
duration: 3min
completed: 2026-04-06
---

# Phase 01 Plan 04: Lea Golden Path Integration Test Summary

**17 service-level integration tests covering full Lea (22, VD, firstJob) onboarding pipeline: intent routing, data flow, onboarding flag lifecycle, input validation edge cases, and VD regional voice**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-06T13:10:26Z
- **Completed:** 2026-04-06T13:13:34Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- 17 integration tests across 4 test groups covering Lea persona (age=22, canton=VD, intent=firstJob, salary=55000)
- Navigation pipeline: IntentRouter chip key resolution, suggestedRoute, stressType, MinimalProfileService validation
- Data flow: premier eclairage computation via ChiffreChocSelector with stress_prevoyance, retirement projections
- Onboarding flag lifecycle: false at start, false after intent-only, true only after full pipeline completion
- Edge cases: age=0 and negative salary handled gracefully without crashes
- Regional voice: VD -> romande region with septante/nonante in localExpressions
- All 17 tests pass, CI guard active for pipeline integrity

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Lea golden path integration test** - `03594e20` (test)

## Files Created/Modified
- `apps/mobile/test/journeys/lea_golden_path_test.dart` - 17 service-level tests for full golden path pipeline

## Decisions Made
- Used rawValue (double) for numeric assertion instead of value (formatted String) on ChiffreChoc
- Followed existing firstjob_journey_test.dart pattern: service-level tests with SharedPreferences mock, no widget E2E
- Tested onboarding flag lifecycle by simulating setSelectedOnboardingIntent without setMiniOnboardingCompleted

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed ChiffreChoc.value is String not number**
- **Found during:** Task 1 (TDD GREEN phase)
- **Issue:** Test used `isNonZero` on `choc.value` which is a formatted String ("CHF 1'089/an"), not a number
- **Fix:** Changed to `choc.value isNotEmpty` + `choc.rawValue isNonZero`
- **Files modified:** lea_golden_path_test.dart
- **Verification:** All 17 tests pass
- **Committed in:** 03594e20 (Task 1 commit)

**2. [Rule 1 - Bug] Fixed nullable IntentMapping access**
- **Found during:** Task 1 (TDD GREEN phase)
- **Issue:** Dart null safety: `mapping.suggestedRoute` fails on `IntentMapping?` type
- **Fix:** Added `!` null assertion after `isNotNull` expect
- **Files modified:** lea_golden_path_test.dart
- **Verification:** All 17 tests pass
- **Committed in:** 03594e20 (Task 1 commit)

**3. [Rule 1 - Bug] Fixed ChiffreChoc field name (label -> title)**
- **Found during:** Task 1 (TDD GREEN phase)
- **Issue:** ChiffreChoc class uses `title` not `label`
- **Fix:** Changed `choc.label` to `choc.title`
- **Files modified:** lea_golden_path_test.dart
- **Verification:** All 17 tests pass
- **Committed in:** 03594e20 (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (3 bugs in test code)
**Impact on plan:** Minor test code corrections for type safety and API alignment. No scope change.

## Issues Encountered
None

## User Setup Required
None - test-only plan, no external service configuration required.

## Known Stubs
None - all tests are fully functional against the implemented pipeline.

## Next Phase Readiness
- Golden path pipeline fully tested and CI-guarded
- Any future changes to intent_screen, quick_start_screen, chiffre_choc_screen, or plan_screen will be caught by these tests
- Ready for Plan 01-05 (Apple Sign-In or final plan)

---
*Phase: 01-le-parcours-parfait*
*Completed: 2026-04-06*
