---
phase: 15-coach-intelligence
plan: 01
subsystem: api
tags: [sqlalchemy, alembic, coach, provenance, earmark, system-prompt, tool-calling]

# Dependency graph
requires:
  - phase: 14-commitment-devices
    provides: "CommitmentDevice/PreMortemEntry models, coach_tools patterns, system prompt directive patterns, memory block builder pattern"
provides:
  - "ProvenanceRecord and EarmarkTag SQLAlchemy models"
  - "Alembic migration p15_earmark_tags (provenance_records + earmark_tags tables)"
  - "save_provenance, save_earmark, remove_earmark internal tools with immediate DB persistence"
  - "_PROVENANCE_TRACKING and _EARMARK_DETECTION system prompt directives"
  - "_build_intelligence_memory_block injecting PROVENANCE CONNUE and ARGENT MARQUE into system prompt"
affects: [15-02, coach-chat, system-prompt]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Immediate DB persistence for internal tools (vs ack-only in P14)", "Intelligence memory block builder parallel to commitment memory block"]

key-files:
  created:
    - services/backend/app/models/earmark.py
    - services/backend/alembic/versions/p15_earmark_tags.py
    - services/backend/tests/test_coach_intelligence.py
  modified:
    - services/backend/app/services/coach/coach_tools.py
    - services/backend/app/services/coach/claude_coach_service.py
    - services/backend/app/api/v1/endpoints/coach_chat.py
    - services/backend/tests/test_agent_loop.py

key-decisions:
  - "Immediate DB persistence for provenance/earmark tools (not ack-only like P14) because data must be available in NEXT conversation"
  - "user_id and db threaded through _run_agent_loop to _execute_internal_tool for DB access"
  - "amount_hint stored as String (not numeric) because users say 'environ 50k' not '50000.00'"

patterns-established:
  - "Intelligence memory block builder: parallel to commitment block, limit 10 records, graceful fallback on DB error"
  - "Internal tool with immediate persistence: import model lazily, try/commit/except-rollback pattern"

requirements-completed: [INTL-01, INTL-02, INTL-03, INTL-04]

# Metrics
duration: 10min
completed: 2026-04-12
---

# Phase 15 Plan 01: Coach Intelligence Summary

**Provenance tracking and earmark tagging via 3 internal tools with immediate DB persistence, system prompt directives, and CoachContext memory injection**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-12T17:58:32Z
- **Completed:** 2026-04-12T18:08:41Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Two SQLAlchemy models (ProvenanceRecord, EarmarkTag) with composite indexes for query performance
- Alembic migration chaining from P14, creating provenance_records and earmark_tags tables
- Three internal tools (save_provenance, save_earmark, remove_earmark) with immediate DB persistence
- Two system prompt directives instructing the LLM on natural provenance questioning and earmark detection
- Intelligence memory block injecting PROVENANCE CONNUE and ARGENT MARQUE sections into every authenticated conversation
- 34 tests covering models, tools, directives, handlers, and memory builder (5366 total backend tests pass)

## Task Commits

Each task was committed atomically:

1. **Task 1: DB models, Alembic migration, system prompt directives, and tool definitions** - `cf0d4ac2` (feat)
2. **Task 2: Internal tool handlers, CoachContext memory injection, and tests** - `56cae81e` (feat)

## Files Created/Modified
- `services/backend/app/models/earmark.py` - ProvenanceRecord and EarmarkTag SQLAlchemy models
- `services/backend/alembic/versions/p15_earmark_tags.py` - Migration creating provenance_records and earmark_tags tables
- `services/backend/app/services/coach/coach_tools.py` - 3 new internal tools added to INTERNAL_TOOL_NAMES and COACH_TOOLS
- `services/backend/app/services/coach/claude_coach_service.py` - _PROVENANCE_TRACKING and _EARMARK_DETECTION directives
- `services/backend/app/api/v1/endpoints/coach_chat.py` - Tool handlers, _build_intelligence_memory_block, wiring
- `services/backend/tests/test_coach_intelligence.py` - 34 tests for intelligence layer
- `services/backend/tests/test_agent_loop.py` - Fixed _capturing wrapper for new signature

## Decisions Made
- Immediate DB persistence for provenance/earmark tools (not ack-only like P14) because data must be available in the NEXT conversation per INTL-02/INTL-04
- user_id and db threaded through _run_agent_loop to _execute_internal_tool for DB access in tool handlers
- amount_hint stored as String (not numeric) because users say "environ 50k" not "50000.00"

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed test_agent_loop _capturing wrapper signature**
- **Found during:** Task 2 (regression test run)
- **Issue:** _execute_internal_tool signature gained user_id and db params; the mock wrapper in test_agent_loop.py did not accept kwargs, causing TypeError
- **Fix:** Added user_id=None, db=None params to _capturing wrapper and forwarded them to original
- **Files modified:** services/backend/tests/test_agent_loop.py
- **Verification:** Test passes, full suite 5366 passed
- **Committed in:** 56cae81e (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary fix for test compatibility. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Intelligence infrastructure complete, ready for Plan 02 (intent-first suggestions, biography enrichment)
- All 3 internal tools registered and handled with immediate persistence
- Memory block injection wired for every authenticated conversation

---
*Phase: 15-coach-intelligence*
*Completed: 2026-04-12*
