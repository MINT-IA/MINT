---
phase: 21-coach-memory-dossier
plan: 01
subsystem: api
tags: [sqlalchemy, coach, memory, system-prompt, persistence]

# Dependency graph
requires:
  - phase: 15-coach-intelligence
    provides: ProvenanceRecord/EarmarkTag pattern, _build_intelligence_memory_block, _execute_internal_tool with user_id/db
provides:
  - CoachInsightRecord ORM model (coach_insights table)
  - _build_insight_memory_block function for system prompt injection
  - DB-persistent save_insight handler (replaces ack-only stub)
  - retrieve_memories DB search (Pass 0 before memory_block text)
affects: [coach-chat, system-prompt, coach-tools]

# Tech tracking
tech-stack:
  added: []
  patterns: [insight-dedup-by-topic, relative-time-formatting, three-pass-memory-search]

key-files:
  created:
    - services/backend/app/models/coach_insight.py
    - services/backend/tests/test_coach_memory_roundtrip.py
  modified:
    - services/backend/app/models/__init__.py
    - services/backend/app/api/v1/endpoints/coach_chat.py

key-decisions:
  - "Dedup by user_id+topic: upsert pattern (update existing row instead of creating duplicate) caps DB growth"
  - "Relative time in memory block (aujourd'hui/hier/il y a N jours) gives LLM temporal context for recency"
  - "DB insights searched first in retrieve_memories (Pass 0) before memory_block text for priority ordering"

patterns-established:
  - "Insight persistence pattern: save_insight -> CoachInsightRecord upsert -> _build_insight_memory_block -> system prompt"
  - "Three-pass retrieve_memories: DB insights (Pass 0) -> exact substring (Pass 1) -> fuzzy match (Pass 2)"

requirements-completed: [CTX-02, CTX-03]

# Metrics
duration: 7min
completed: 2026-04-13
---

# Phase 21 Plan 01: Coach Memory Round-trip Summary

**CoachInsightRecord model with DB-persistent save_insight handler, insight memory block injection into system prompt, and three-pass retrieve_memories search**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-13T17:37:08Z
- **Completed:** 2026-04-13T17:44:13Z
- **Tasks:** 2 (TDD: RED + GREEN)
- **Files modified:** 4

## Accomplishments
- save_insight tool call now persists CoachInsightRecord to DB with dedup by user_id+topic (was ack-only stub)
- _build_insight_memory_block loads saved insights with relative timestamps and injects into system prompt alongside commitment_block and intelligence_block
- retrieve_memories now searches DB-persisted insights first (Pass 0) before memory_block text search
- 12 integration tests prove the full round-trip: save -> DB -> memory block -> system prompt
- Full backend test suite green: 5397 passed, 0 failures

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): Failing tests for coach memory round-trip** - `066047d7` (test)
2. **Task 1 (GREEN): Persist save_insight to DB and inject into system prompt** - `1a714641` (feat)

_TDD task: RED commit has failing tests, GREEN commit has implementation + all tests passing_

## Files Created/Modified
- `services/backend/app/models/coach_insight.py` - CoachInsightRecord ORM model (coach_insights table)
- `services/backend/app/models/__init__.py` - Register CoachInsightRecord import
- `services/backend/app/api/v1/endpoints/coach_chat.py` - save_insight DB persistence, _build_insight_memory_block, insight_block wiring, retrieve_memories DB search
- `services/backend/tests/test_coach_memory_roundtrip.py` - 12 integration tests for full round-trip

## Decisions Made
- Dedup by user_id+topic: upsert pattern prevents unbounded DB growth while keeping insights current
- Relative time formatting in memory block gives LLM temporal awareness (e.g., "il y a 2 jours")
- DB insights get priority in retrieve_memories (Pass 0) over ephemeral memory_block text
- SQLite naive datetime handling: treat as UTC when tzinfo is None (compatibility with test fixtures)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added datetime import to coach_chat.py top-level**
- **Found during:** Task 1 (save_insight handler)
- **Issue:** datetime was only imported locally at line 1693, but save_insight handler needs datetime.now(timezone.utc) at module scope
- **Fix:** Added `from datetime import datetime, timedelta, timezone` to top-level imports
- **Files modified:** services/backend/app/api/v1/endpoints/coach_chat.py
- **Verification:** All tests pass
- **Committed in:** 1a714641 (Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Essential import for persistence handler. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Coach memory round-trip is complete: save_insight persists, insights load into system prompt
- Ready for next plans in Phase 21 (if any)
- Backend test suite fully green (5397 passed)

---
*Phase: 21-coach-memory-dossier*
*Completed: 2026-04-13*
