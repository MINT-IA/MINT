---
phase: 07-life-event-journeys
plan: 02
subsystem: testing
tags: [flutter-test, journey-test, intent-router, cap-sequence-engine, golden-profile]

requires:
  - phase: 07-01
    provides: [IntentRouter with 9 chip mappings, CapSequenceEngine with firstJob/newJob sequences]

provides:
  - firstJob E2E journey integration test (19 tests)
  - housingPurchase E2E journey integration test (21 tests)
  - newJob E2E journey integration test (23 tests)
  - 63 total journey tests covering happy paths + edge cases

affects: [IntentRouter, CapSequenceEngine, CapSequence, CapMemory]

tech-stack:
  added: []
  patterns: [standalone-journey-test, golden-profile-assertions, step-status-verification]

key-files:
  created:
    - apps/mobile/test/journeys/firstjob_journey_test.dart
    - apps/mobile/test/journeys/housing_journey_test.dart
    - apps/mobile/test/journeys/newjob_journey_test.dart
  modified: []

key-decisions:
  - "Tests follow exact pattern from cap_sequence_engine_test.dart (SFr() locale, SharedPreferences.setMockInitialValues)"
  - "Journey tests use CapStepStatus assertions, not string matching — catch structural changes"
  - "Each test file is fully standalone: no shared state, no imports between test files"
  - "fj_02_salary_xray becomes current (not upcoming) due to CapSequence.fromSteps() promotion logic — test asserts isNot(blocked) to remain robust"

patterns-established:
  - "Journey test pattern: intent chip → router → CapSequence build → step status assertions → route assertions"
  - "Golden profile helper functions (_julienProfile, _emptyProfile) per test file — not shared across files"
  - "Edge case variants: no-fonds profile, low-LPP profile, empty-profile, completed-actions memory"

requirements-completed: [LEJ-01, LEJ-02, LEJ-03, LEJ-04]

duration: 12min
completed: 2026-04-06
---

# Phase 07 Plan 02: Life Event Journey Integration Tests Summary

**63 standalone Flutter journey tests covering firstJob (19), housingPurchase (21), and newJob (23) E2E flows — intent chip to CapSequence step status to calculator routes, verified against Julien golden profile.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-06T06:30:00Z
- **Completed:** 2026-04-06T06:42:00Z
- **Tasks:** 3
- **Files modified:** 3 created

## Accomplishments

- 3 standalone integration test files in `test/journeys/` — no device needed, widget test pattern
- Each test traces the full chain: intent chip ARB key → IntentRouter → goalIntentTag → CapSequence → step IDs/statuses → calculator routes → plan entry
- Julien golden profile (VS, 122'207 CHF/an, LPP 70'377, 3a 32'000) used for all positive assertions
- Edge cases: empty profile blocking, EPL below OPP2 minimum (20k), no fonds propres, memory-driven progression

## Task Commits

Each task was committed atomically:

1. **Task 1: firstJob journey integration test** - `9188a25c` (test)
2. **Task 2: housingPurchase journey integration test** - `93a6ca3d` (test)
3. **Task 3: newJob journey integration test** - `d553e8af` (test)

## Files Created

- `apps/mobile/test/journeys/firstjob_journey_test.dart` — 19 tests: intent → first_job CapSequence (5 steps), Julien profile completion, empty profile blocking
- `apps/mobile/test/journeys/housing_journey_test.dart` — 21 tests: intent → housing_purchase CapSequence (7 steps), EPL null below 20k OPP2, no-fonds capacity blocking
- `apps/mobile/test/journeys/newjob_journey_test.dart` — 23 tests: intent → new_job CapSequence (5 steps), memory-driven progression (salary_compared, lpp_transfer_checked)

## Decisions Made

- Tests use `CapStepStatus` enum comparisons rather than string matching — will catch any status renames at compile time.
- `fj_02_salary_xray` step with Julien profile is asserted as `isNot(blocked)` (not `upcoming`) because `CapSequence.fromSteps()` auto-promotes the first non-completed step to `current`. This is the correct semantics.
- Each test file declares its own `_julienProfile()` helper — standalone isolation preferred over a shared test utility.
- `DepensesProfile` and `PatrimoineProfile` use named constructors with const — pattern confirmed from cap_sequence_engine_test.dart.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Merged dev branch to get Plan 01 infrastructure**
- **Found during:** Task 1 setup
- **Issue:** Worktree branch `worktree-agent-a4e5d040` was based on `main` pre-Plan 01. IntentRouter + CapSequenceEngine files for `first_job`/`new_job` sequences were missing.
- **Fix:** `git merge dev --no-edit` to bring in Plan 01 commits (98edd815, e895a4e8, 979c8e91).
- **Files modified:** All Plan 01 files merged in (non-conflicting).
- **Verification:** `find apps/mobile/lib -name cap_sequence_engine.dart` — FOUND with `_kGoalFirstJob` and `_kGoalNewJob`.
- **Impact:** Clean merge, no conflicts. Tests could now be written against the real implementation.

---

**Total deviations:** 1 auto-fixed (1 blocking — missing infrastructure)
**Impact on plan:** Required to unblock all 3 tasks. Plan 01 work was always the prerequisite per `depends_on: [07-01]`.

## Issues Encountered

None beyond the merge requirement above.

## Known Stubs

None. All test assertions are against production code. No hardcoded expected values — step statuses are computed from profile data.

## Threat Flags

None. Tests use Julien golden values from CLAUDE.md (public project documentation, no real PII). No new network endpoints or auth paths introduced.

## Self-Check: PASSED

- `apps/mobile/test/journeys/firstjob_journey_test.dart` — FOUND (314 insertions, 19 tests passing)
- `apps/mobile/test/journeys/housing_journey_test.dart` — FOUND (396 insertions, 21 tests passing)
- `apps/mobile/test/journeys/newjob_journey_test.dart` — FOUND (436 insertions, 23 tests passing)
- Commit 9188a25c — FOUND (firstJob test)
- Commit 93a6ca3d — FOUND (housing test)
- Commit d553e8af — FOUND (newJob test)
- `flutter test test/journeys/` — 63/63 tests PASSED

## Next Phase Readiness

- All 3 journey tests pass — any future regression in IntentRouter, CapSequenceEngine step IDs/statuses, or route assignments will be caught immediately.
- Tests cover the `depends_on: [07-01]` infrastructure fully — integration tested end-to-end.
- Phase 07 complete: journey infrastructure (Plan 01) + integration tests (Plan 02) both shipped.

---
*Phase: 07-life-event-journeys*
*Completed: 2026-04-06*
