---
phase: 06-qa-profond
plan: 05
subsystem: infra
tags: [ci, golden-tests, patrol, github-actions, flutter-test]

requires:
  - phase: 06-qa-profond (plans 01-04)
    provides: "Phase 6 test files in test/journeys/, test/accessibility/, test/i18n/, test/golden_screenshots/, test/patrol/"
provides:
  - "All Phase 6 test directories integrated into CI screens shard"
  - "TolerantGoldenFileComparator enforcing 1.5% pixel diff threshold"
  - "Patrol manual gate policy documentation"
affects: [ci-pipeline, golden-screenshots, release-gate]

tech-stack:
  added: []
  patterns: ["TolerantGoldenFileComparator extending LocalFileComparator with diffPercent tolerance"]

key-files:
  created:
    - "apps/mobile/test/golden_screenshots/tolerant_comparator.dart"
    - ".github/workflows/patrol.md"
  modified:
    - ".github/workflows/ci.yml"
    - "apps/mobile/test/golden_screenshots/golden_screenshot_test.dart"

key-decisions:
  - "Phase 6 test dirs added to existing screens shard (not new shard) to avoid CI matrix bloat"
  - "Patrol documented as manual gate (not CI) due to emulator infrastructure requirements"
  - "TolerantGoldenFileComparator uses Flutter SDK recommended pattern (compareLists + diffPercent)"

patterns-established:
  - "TolerantGoldenFileComparator pattern: extend LocalFileComparator, override compare(), check diffPercent <= tolerance"
  - "Manual gate documentation pattern: .github/workflows/{tool}.md for CI-excluded test categories"

requirements-completed: [QA-03, QA-04, QA-05, QA-10]

duration: 3min
completed: 2026-04-06
---

# Phase 06 Plan 05: CI Integration Gap Closure Summary

**Phase 6 test directories (journeys, accessibility, i18n, golden_screenshots) wired into CI screens shard with 1.5%-tolerant golden comparator and Patrol manual gate policy**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-06T20:48:53Z
- **Completed:** 2026-04-06T20:51:39Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- All 4 Phase 6 test directories (~332 new tests) now run in CI on every push via screens shard
- TolerantGoldenFileComparator enforces 1.5% pixel diff threshold in code (was documentation-only)
- Patrol integration tests documented as manual gate with clear execution instructions

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Phase 6 test directories to CI shards + Patrol gate doc** - `be25ccc7` (chore)
2. **Task 2: Implement TolerantGoldenFileComparator with 1.5% threshold** - `bcfcc448` (feat)

## Files Created/Modified
- `.github/workflows/ci.yml` - Added test/journeys/, test/accessibility/, test/i18n/, test/golden_screenshots/ to screens shard test_dirs
- `.github/workflows/patrol.md` - Manual gate policy: when to run, prerequisites, commands, future CI plan
- `apps/mobile/test/golden_screenshots/tolerant_comparator.dart` - TolerantGoldenFileComparator extending LocalFileComparator with 0.015 (1.5%) tolerance
- `apps/mobile/test/golden_screenshots/golden_screenshot_test.dart` - Wired tolerant comparator via goldenFileComparator assignment + import

## Decisions Made
- Phase 6 test dirs added to existing `screens` shard rather than creating a new shard -- screens was the smallest (~34 files), adding ~20 more keeps it balanced
- Patrol remains manual-only: GitHub Actions ubuntu runners lack iOS simulator support, macOS runners are 10x more expensive
- Used Flutter SDK's own recommended TolerantGoldenFileComparator pattern (from goldenFileComparator docs) rather than custom pixel comparison

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `dart:typed_data` import in tolerant_comparator.dart was flagged as unnecessary (already provided by `package:flutter/foundation.dart`) -- removed to keep analysis clean

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- CI pipeline now runs all Phase 6 tests automatically
- Golden screenshot threshold is code-enforced, not just documented
- Remaining VERIFICATION.md gaps (QA-09 DocumentFactory SVG/PDF, WCAG status colors) are out of scope for this plan

---
*Phase: 06-qa-profond*
*Completed: 2026-04-06*
