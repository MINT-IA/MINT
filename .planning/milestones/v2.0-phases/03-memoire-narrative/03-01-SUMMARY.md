---
phase: 03-memoire-narrative
plan: 01
subsystem: database
tags: [sqflite_sqlcipher, encrypted-sqlite, freshness-decay, biography, provider]

# Dependency graph
requires: []
provides:
  - BiographyFact data model with FactType/FactSource enums and graph links
  - BiographyRepository encrypted CRUD with abstract DB interface
  - FreshnessDecayService two-tier decay (annual 12mo / volatile 3mo)
  - BiographyProvider ChangeNotifier with freshness-aware filtering
affects: [03-02-PLAN, 03-03-PLAN, coach-integration, privacy-screen]

# Tech tracking
tech-stack:
  added: [sqflite_sqlcipher, path_provider]
  patterns: [abstract-database-interface, two-tier-freshness-decay, in-memory-test-db]

key-files:
  created:
    - apps/mobile/lib/services/biography/biography_fact.dart
    - apps/mobile/lib/services/biography/biography_repository.dart
    - apps/mobile/lib/services/biography/freshness_decay_service.dart
    - apps/mobile/lib/providers/biography_provider.dart
    - apps/mobile/test/services/biography/biography_repository_test.dart
    - apps/mobile/test/services/biography/freshness_decay_test.dart
  modified:
    - apps/mobile/pubspec.yaml

key-decisions:
  - "Abstract BiographyDatabase interface for testability without native sqflite in flutter test"
  - "In-memory test DB simulates SQL query patterns for deterministic unit tests"
  - "Freshness decay uses updatedAt (when MINT confirmed) not sourceDate (document date)"

patterns-established:
  - "Abstract DB interface: BiographyDatabase abstraction allows in-memory testing without platform dependencies"
  - "Two-tier freshness: annual (12mo full / 36mo floor) and volatile (3mo full / 12mo floor) with 0.3 floor"
  - "Parameterized queries only: all SQL uses ? placeholders, never string concatenation"

requirements-completed: [BIO-01, BIO-02, BIO-06]

# Metrics
duration: 6min
completed: 2026-04-06
---

# Phase 03 Plan 01: FinancialBiography Data Layer Summary

**Encrypted local SQLite biography store with two-tier freshness decay, graph-linked facts, and Provider state management**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-06T15:03:14Z
- **Completed:** 2026-04-06T15:09:36Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- BiographyFact model with 13 FactType values, 4 FactSource values, causal/temporal graph links, and full JSON serialization
- BiographyRepository with encrypted SQLite CRUD (soft delete + hard delete for GDPR), parameterized queries, abstract DB interface for testability
- FreshnessDecayService with two-tier decay model matching confidence_scorer pattern but category-aware (annual vs volatile)
- BiographyProvider with cached state, activeFreshFacts/staleFacts filtering, and factsByCategory grouping
- 33 tests across 2 test files, flutter analyze 0 issues

## Task Commits

Each task was committed atomically:

1. **Task 1: BiographyFact model + encrypted BiographyRepository** - `976ba567` (feat)
2. **Task 2: FreshnessDecayService + BiographyProvider** - `62800ab3` (feat)

_Both tasks followed TDD: tests written alongside implementation, all passing._

## Files Created/Modified
- `apps/mobile/lib/services/biography/biography_fact.dart` - Immutable data model with FactType/FactSource enums, graph links, JSON serialization
- `apps/mobile/lib/services/biography/biography_repository.dart` - Encrypted SQLite CRUD with abstract DB interface, soft/hard delete, parameterized queries
- `apps/mobile/lib/services/biography/freshness_decay_service.dart` - Two-tier freshness decay (annual 12mo / volatile 3mo), needsRefresh, categoryFor
- `apps/mobile/lib/providers/biography_provider.dart` - ChangeNotifier wrapping repository with cached state and freshness-aware filtering
- `apps/mobile/test/services/biography/biography_repository_test.dart` - 16 tests: model serialization, CRUD operations, query filters
- `apps/mobile/test/services/biography/freshness_decay_test.dart` - 17 tests: decay boundaries for both tiers, needsRefresh, categoryFor
- `apps/mobile/pubspec.yaml` - Added sqflite_sqlcipher and path_provider dependencies

## Decisions Made
- **Abstract BiographyDatabase interface**: sqflite_sqlcipher requires native binaries unavailable in `flutter test`. Created abstract interface with InMemoryBiographyDatabase for fast, deterministic testing. Production wiring deferred to when full native integration is needed.
- **updatedAt for decay, not sourceDate**: Freshness measures when MINT last confirmed the data, not when the original document was issued. A 2024 LPP certificate confirmed today is fresh.
- **Parameterized queries only**: All SQL uses `?` placeholders per T-03-02 threat mitigation. No string concatenation anywhere in repository.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- BiographyRepository and BiographyProvider ready for coach integration (03-02)
- FreshnessDecayService ready for refresh detection and privacy screen (03-03)
- Abstract DB pattern established for all future local storage needs

## Self-Check: PASSED

- All 6 created files exist on disk
- Both commit hashes verified in git log (976ba567, 62800ab3)
- 33 tests pass, flutter analyze 0 issues

---
*Phase: 03-memoire-narrative*
*Completed: 2026-04-06*
