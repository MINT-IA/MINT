---
phase: 04-moteur-danticipation
plan: 02
subsystem: anticipation
tags: [anticipation, compliance, ranking, persistence, shared-preferences, frequency-cap]

# Dependency graph
requires:
  - phase: 04-moteur-danticipation
    provides: AnticipationEngine, AnticipationTrigger enum, AlertTemplate enum, AnticipationSignal model
provides:
  - ComplianceGuard.validateAlert() static method (layers 1-2 only)
  - AnticipationPersistence service (weekly cap + dismiss + snooze)
  - AnticipationRanking.rank() with priority_score formula and top-2 split
  - AnticipationRankResult model (visible + overflow lists)
affects: [04-03 cards, 05-interface-contextuelle]

# Tech tracking
tech-stack:
  added: []
  patterns: [alert-specific-compliance (layers 1-2 only), iso-week-frequency-cap, per-trigger-cooldown, priority-score-formula]

key-files:
  created:
    - apps/mobile/lib/services/anticipation/anticipation_persistence.dart
    - apps/mobile/lib/services/anticipation/anticipation_ranking.dart
    - apps/mobile/test/services/anticipation/anticipation_persistence_test.dart
    - apps/mobile/test/services/anticipation/anticipation_ranking_test.dart
  modified:
    - apps/mobile/lib/services/coach/compliance_guard.dart
    - apps/mobile/test/services/coach/compliance_guard_test.dart

key-decisions:
  - "validateAlert() skips layers 3-4 (hallucination/disclaimer) since alerts are template-based, not LLM-generated"
  - "ISO week ID format ({year}-W{weekNumber}) for weekly frequency cap reset"
  - "Per-trigger dismiss cooldowns: fiscal3a=365, cantonal=30, lppRachat=60, salary=90, ageMilestone=365"
  - "Per-trigger snooze durations: fiscal3a=7, cantonal=7, lppRachat=14, salary=14, ageMilestone=30"
  - "Priority formula: timeliness*0.5 + userRelevance*0.3 + confidence*0.2 with 90-day timeliness horizon"
  - "Default confidence=0.8 for template-based signals (Phase 5 can refine with biography freshness)"

patterns-established:
  - "Alert compliance validation: reuse existing banned-term/prescriptive checks, skip LLM-specific layers"
  - "AnticipationPersistence follows NudgePersistence pattern (static methods, injectable SharedPreferences/DateTime)"
  - "AnticipationRankResult(visible, overflow) pattern for top-N card split"

requirements-completed: [ANT-04, ANT-05, ANT-06, ANT-07]

# Metrics
duration: 4min
completed: 2026-04-06
---

# Phase 04 Plan 02: Compliance + Persistence + Ranking Summary

**ComplianceGuard.validateAlert() with layers 1-2 only, AnticipationPersistence with ISO-week cap/dismiss/snooze, and AnticipationRanking with timeliness*0.5+relevance*0.3+confidence*0.2 formula and top-2 split**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-06T16:29:33Z
- **Completed:** 2026-04-06T16:33:45Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- ComplianceGuard.validateAlert() runs banned-term + prescriptive checks only, intentionally skipping hallucination detection and disclaimer injection for template-based alerts (ANT-04)
- AnticipationPersistence enforces max 2 signals/week via ISO week ID, per-trigger dismiss cooldowns (30-365 days), and per-trigger snooze durations (7-30 days) (ANT-05, ANT-07)
- AnticipationRanking.rank() computes deterministic priority_score, splits top-2 into visible and rest into overflow, respects weekly budget (ANT-06)
- 30 new tests (15 persistence + 15 ranking) + 12 new validateAlert tests, all green. 0 analyze errors.

## Task Commits

Each task was committed atomically:

1. **Task 1: ComplianceGuard.validateAlert() + AnticipationPersistence** - `bbfce773` (feat)
2. **Task 2: AnticipationRanking with priority_score and top-2 split** - `25a6af2d` (feat)

_Note: TDD tasks with RED+GREEN phases committed together (tests pass on GREEN)._

## Files Created/Modified
- `apps/mobile/lib/services/coach/compliance_guard.dart` - Added validateAlert() static method (layers 1-2 only)
- `apps/mobile/lib/services/anticipation/anticipation_persistence.dart` - Weekly cap + dismiss + snooze via SharedPreferences
- `apps/mobile/lib/services/anticipation/anticipation_ranking.dart` - Priority score ranking + AnticipationRankResult model
- `apps/mobile/test/services/anticipation/anticipation_persistence_test.dart` - 15 tests for cap, dismiss, snooze
- `apps/mobile/test/services/anticipation/anticipation_ranking_test.dart` - 15 tests for formula, budget, sort
- `apps/mobile/test/services/coach/compliance_guard_test.dart` - 12 new validateAlert tests added to existing file

## Decisions Made
- validateAlert() skips layers 3-4: alerts include source refs per ANT-03 and are template-based (not LLM-generated), so hallucination detection and disclaimer injection are unnecessary
- ISO week ID format ({year}-W{weekNumber}) chosen for clean weekly reset semantics
- Per-trigger cooldowns tuned to trigger frequency: fiscal3a/ageMilestone=365 (annual), cantonal=30, lppRachat=60, salary=90
- Snooze durations shorter than dismiss: designed as "remind me later" vs "I got it"
- Default confidence 0.8 for all template-based signals; Phase 5 can refine with biography freshness data
- Timeliness horizon of 90 days: signals beyond 90 days score 0.0 timeliness

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ComplianceGuard.validateAlert() ready for card rendering in Plan 03 (validate alert text before display)
- AnticipationPersistence ready for integration in Plan 03 (filter dismissed/snoozed signals before ranking)
- AnticipationRanking.rank() ready for Aujourd'hui card rendering (visible list = cards, overflow = expandable)
- All services are pure static / SharedPreferences-based, zero dependency on external services

## Self-Check: PASSED

- All 6 files: FOUND
- Commit bbfce773: FOUND
- Commit 25a6af2d: FOUND
- flutter test anticipation/: 74/74 passed
- flutter test compliance_guard: 89/89 passed
- flutter analyze: 0 issues
