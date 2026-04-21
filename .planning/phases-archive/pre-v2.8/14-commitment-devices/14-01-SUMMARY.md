---
phase: 14-commitment-devices
plan: 01
subsystem: database, api, ai
tags: [sqlalchemy, alembic, coach-tools, system-prompt, commitment-devices, pre-mortem, implementation-intentions]

# Dependency graph
requires:
  - phase: 13-anonymous-flow
    provides: Coach chat endpoint, system prompt builder, internal tool pattern
provides:
  - CommitmentDevice and PreMortemEntry SQLAlchemy models
  - Alembic migration p14_commitment_devices (two tables)
  - record_commitment and save_pre_mortem internal tools
  - show_commitment_card Flutter-bound tool
  - _IMPLEMENTATION_INTENTION and _PRE_MORTEM_PROTOCOL system prompt directives
  - _build_commitment_memory_block for CoachContext injection
  - 25 unit tests for commitment device backend
affects: [14-02, 14-03, coach-ai, dossier]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Ack-only internal tool pattern (persist later via dedicated endpoint)"
    - "Memory block injection from DB into system prompt"
    - "Behavioral economics directives in LLM system prompt"

key-files:
  created:
    - services/backend/app/models/commitment.py
    - services/backend/alembic/versions/p14_commitment_devices.py
    - services/backend/tests/test_commitment_devices.py
  modified:
    - services/backend/app/services/coach/coach_tools.py
    - services/backend/app/services/coach/claude_coach_service.py
    - services/backend/app/api/v1/endpoints/coach_chat.py

key-decisions:
  - "Ack-only tool handlers: record_commitment and save_pre_mortem return acknowledgement strings without DB persistence (Plan 02 adds dedicated endpoints)"
  - "show_commitment_card as Flutter-bound tool (NOT internal) for user-editable commitment card rendering"
  - "Memory block injection always includes commitment data (LLM references naturally per directive)"

patterns-established:
  - "Ack-only internal tool pattern: handler returns confirmation string, persistence deferred to dedicated endpoint"
  - "DB-sourced memory block builder: query models, format markdown, inject into system prompt"

requirements-completed: [CMIT-01, CMIT-05, CMIT-06, LOOP-02]

# Metrics
duration: 7min
completed: 2026-04-12
---

# Phase 14 Plan 01: Commitment Devices Backend Summary

**SQLAlchemy models + Alembic migration for implementation intentions and pre-mortem entries, LLM system prompt directives for behavioral engagement, internal tool handlers, and CoachContext memory injection with 25 passing tests**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-12T17:14:17Z
- **Completed:** 2026-04-12T17:21:19Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Two SQLAlchemy models (CommitmentDevice, PreMortemEntry) with user_id indexes and correct schemas
- Alembic migration p14_commitment_devices creating both tables with composite indexes
- System prompt now instructs LLM to propose WHEN/WHERE/IF-THEN implementation intentions after Layer 4 insights
- System prompt now triggers pre-mortem protocol before irrevocable decisions (EPL, capital withdrawal, 3a closure)
- CoachContext memory block injects ENGAGEMENTS ACTIFS and RISQUES IDENTIFIES from DB
- 25 unit tests covering models, tools, directives, handlers, and memory builder — all passing
- Full backend suite: 5310 passed, 0 regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: DB models, migration, system prompt directives, and tool definitions** - `c277c9fb` (feat)
2. **Task 2: Internal tool handlers, CoachContext memory injection, and tests** - `3e7f6529` (feat)

## Files Created/Modified
- `services/backend/app/models/commitment.py` - CommitmentDevice + PreMortemEntry SQLAlchemy models
- `services/backend/alembic/versions/p14_commitment_devices.py` - Migration creating both tables with indexes
- `services/backend/app/services/coach/coach_tools.py` - Added record_commitment, save_pre_mortem (internal), show_commitment_card (Flutter-bound)
- `services/backend/app/services/coach/claude_coach_service.py` - Added _IMPLEMENTATION_INTENTION and _PRE_MORTEM_PROTOCOL directives
- `services/backend/app/api/v1/endpoints/coach_chat.py` - Tool handlers + _build_commitment_memory_block + memory injection
- `services/backend/tests/test_commitment_devices.py` - 25 tests covering full commitment device backend

## Decisions Made
- Ack-only tool handlers: record_commitment and save_pre_mortem return acknowledgement strings without DB persistence — actual persistence comes via dedicated endpoint in Plan 02
- show_commitment_card registered as Flutter-bound tool (NOT in INTERNAL_TOOL_NAMES) — Flutter renders an editable card, user can accept/edit/dismiss
- Memory block always includes commitment data when it exists — the system prompt directive tells the LLM to reference past commitments and pre-mortem entries naturally

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test for SQLAlchemy Column defaults**
- **Found during:** Task 2 (test execution)
- **Issue:** SQLAlchemy Column `default=` values are not applied to instances before flush — test was asserting `c.status == "pending"` on an unflushed object
- **Fix:** Changed test to verify `CommitmentDevice.status.default.arg == "pending"` (column metadata check)
- **Files modified:** services/backend/tests/test_commitment_devices.py
- **Verification:** All 25 tests pass
- **Committed in:** 3e7f6529 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix in test)
**Impact on plan:** Trivial test assertion fix. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Models and migration ready for Plan 02 (Flutter commitment card widget + dedicated persistence endpoint)
- System prompt directives active — LLM will propose implementation intentions and pre-mortem on next conversation
- Plan 03 (fresh-start anchors) can build on the commitment_devices table

---
*Phase: 14-commitment-devices*
*Completed: 2026-04-12*
