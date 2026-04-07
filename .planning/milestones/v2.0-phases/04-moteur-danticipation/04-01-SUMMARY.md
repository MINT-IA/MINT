---
phase: 04-moteur-danticipation
plan: 01
subsystem: anticipation
tags: [anticipation, triggers, pure-static, lpp, avs, 3a, cantonal-tax, biography]

# Dependency graph
requires:
  - phase: 03-memoire-narrative
    provides: BiographyFact model and FactType/FactSource enums
provides:
  - AnticipationEngine.evaluate() pure static method with 5 trigger types
  - AnticipationTrigger enum (5 values)
  - AlertTemplate enum (5 values)
  - AnticipationSignal immutable model
  - CantonalDeadline map (26 cantons)
affects: [04-02 ranking, 04-03 cards, 05-interface-contextuelle]

# Tech tracking
tech-stack:
  added: []
  patterns: [pure-static-engine (follows NudgeEngine), injectable-DateTime testing, trigger-signal-template architecture]

key-files:
  created:
    - apps/mobile/lib/services/anticipation/anticipation_trigger.dart
    - apps/mobile/lib/services/anticipation/anticipation_signal.dart
    - apps/mobile/lib/services/anticipation/anticipation_engine.dart
    - apps/mobile/lib/services/anticipation/cantonal_deadlines.dart
    - apps/mobile/test/services/anticipation/anticipation_signal_test.dart
    - apps/mobile/test/services/anticipation/anticipation_engine_test.dart
  modified: []

key-decisions:
  - "AnticipationEngine follows NudgeEngine pure-static pattern exactly (private constructor, static evaluate, injectable DateTime)"
  - "Cantonal deadlines: 26 cantons mapped, TI/NW/OW at April 30, all others March 31, with getCantonalDeadline() fallback"
  - "Salary increase threshold: >5% OR >2000 CHF absolute (dual condition per research)"
  - "userEdit FactSource filtered out from salary increase detection (correction vs real increase)"

patterns-established:
  - "AnticipationTrigger/AlertTemplate 1:1 mapping pattern for trigger-to-template"
  - "Signal ID format: {trigger.name}_{yyyyMMdd} for deduplication"
  - "Archetype-aware plafond: independentNoLpp=36288, others=7258"

requirements-completed: [ANT-01, ANT-02, ANT-03, ANT-08]

# Metrics
duration: 8min
completed: 2026-04-06
---

# Phase 04 Plan 01: AnticipationEngine Core Summary

**Pure stateless AnticipationEngine with 5 trigger types (3a deadline, cantonal tax, LPP rachat, salary increase, age milestone), 26-canton deadline map, and 44 unit tests -- zero async/LLM per ANT-08**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-06T16:19:35Z
- **Completed:** 2026-04-06T16:27:08Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- AnticipationEngine.evaluate() returns correct signals for all 5 trigger types with injectable DateTime
- All triggers are pure static methods -- zero async, zero LLM, zero network (ANT-08 verified via grep)
- AlertTemplate enum has exactly 5 values matching trigger types (ANT-03 educational format)
- 44 tests covering all trigger conditions including edge cases (archetype plafond, salary delta threshold, userEdit filtering, bracket boundary detection, cantonal specifics)

## Task Commits

Each task was committed atomically:

1. **Task 1: AnticipationTrigger enum + AlertTemplate enum + AnticipationSignal model** - `0b6a7b74` (feat)
2. **Task 2: AnticipationEngine + cantonal deadlines + comprehensive tests** - `8e629487` (feat)

_Note: TDD tasks with RED+GREEN phases committed together (tests pass on GREEN)._

## Files Created/Modified
- `apps/mobile/lib/services/anticipation/anticipation_trigger.dart` - Enum with 5 trigger types
- `apps/mobile/lib/services/anticipation/anticipation_signal.dart` - AlertTemplate enum + AnticipationSignal immutable model
- `apps/mobile/lib/services/anticipation/anticipation_engine.dart` - Pure stateless engine with evaluate() and 5 check methods
- `apps/mobile/lib/services/anticipation/cantonal_deadlines.dart` - 26-canton deadline map with CantonalDeadline model
- `apps/mobile/test/services/anticipation/anticipation_signal_test.dart` - 9 tests for enums and signal model
- `apps/mobile/test/services/anticipation/anticipation_engine_test.dart` - 35 tests for all 5 trigger types + dismissal + expiry

## Decisions Made
- AnticipationEngine follows NudgeEngine pure-static pattern exactly (private constructor, static evaluate, injectable DateTime)
- Cantonal deadlines: 26 cantons mapped with TI/NW/OW at April 30, all others March 31, with getCantonalDeadline() fallback for unknown cantons
- Salary increase uses dual threshold: >5% OR >2000 CHF absolute (catches both percentage and absolute increases)
- userEdit FactSource filtered from salary increase detection (per research pitfall 4: corrections are not real increases)
- LPP rachat trigger checks both avoirLppTotal > 0 and rachatMaximum > 0 (either qualifies)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- AnticipationEngine core ready for Plan 02 (ranking with relevance scoring + frequency cap)
- AlertTemplate enum ready for compliance validation (ComplianceGuard.validateAlert in Plan 02)
- Signal model supports copyWith(priorityScore) for ranking phase
- All 5 trigger types tested and verified -- ready for card rendering in Plan 03

## Self-Check: PASSED

- All 7 files: FOUND
- Commit 0b6a7b74: FOUND
- Commit 8e629487: FOUND
- flutter analyze: 0 issues
- flutter test: 44/44 passed

---
*Phase: 04-moteur-danticipation*
*Completed: 2026-04-06*
