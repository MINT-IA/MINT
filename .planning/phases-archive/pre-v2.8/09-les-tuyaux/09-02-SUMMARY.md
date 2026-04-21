---
phase: 09-les-tuyaux
plan: 02
subsystem: infra
tags: [asyncio, timeout, agent-loop, coach-chat, fastapi]

# Dependency graph
requires:
  - phase: 09-les-tuyaux/01
    provides: RAG graceful fallback (coach_chat.py baseline)
provides:
  - 55s total agent loop deadline (asyncio.wait_for)
  - 25s per-iteration timeout on LLM calls
  - Graceful French timeout message instead of 502 Bad Gateway
affects: [10-les-connexions]

# Tech tracking
tech-stack:
  added: []
  patterns: [asyncio.wait_for for application-level deadline enforcement]

key-files:
  created: []
  modified:
    - services/backend/app/api/v1/endpoints/coach_chat.py
    - services/backend/tests/test_agent_loop.py

key-decisions:
  - "55s total deadline chosen to stay well under Gunicorn 120s and Railway gateway timeout"
  - "25s per-iteration cap prevents one hung API call from consuming all time"
  - "MAX_AGENT_LOOP_ITERATIONS reduced from 5 to 3 — sufficient for tool_use + response"
  - "Timeout returns graceful French message with loop_result dict, not 502"

patterns-established:
  - "asyncio.wait_for wrapping for application-level deadline enforcement on external API calls"

requirements-completed: [INFRA-04]

# Metrics
duration: 2min
completed: 2026-04-12
---

# Phase 9 Plan 2: Agent Loop Timeout Summary

**55s total deadline + 25s per-iteration cap on coach chat agent loop, returning graceful French message instead of 502 Bad Gateway**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-12T09:18:34Z
- **Completed:** 2026-04-12T09:20:34Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- Agent loop now has a 55-second total wall-clock deadline via asyncio.wait_for at the call site
- Each orchestrator.query iteration is capped at 25 seconds — one hung LLM call cannot consume all time
- MAX_AGENT_LOOP_ITERATIONS reduced from 5 to 3 (sufficient for tool_use + response pattern)
- Timeout returns a graceful French message ("Je n'ai pas pu terminer ma recherche...") instead of a 502 Bad Gateway
- 3 new tests added, all 27 tests pass (24 existing + 3 new)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add asyncio.wait_for deadline to agent loop + per-iteration timeout** - `85fa2e14` (feat)

## Files Created/Modified
- `services/backend/app/api/v1/endpoints/coach_chat.py` - Added AGENT_LOOP_DEADLINE_SECONDS (55), AGENT_ITERATION_TIMEOUT_SECONDS (25), reduced MAX_AGENT_LOOP_ITERATIONS to 3, wrapped orchestrator.query and _run_agent_loop with asyncio.wait_for, added TimeoutError handler returning graceful message
- `services/backend/tests/test_agent_loop.py` - Added 3 tests: total timeout, per-iteration timeout, iteration cap constant verification

## Decisions Made
- 55s total deadline chosen to stay well under Gunicorn's 120s worker timeout and Railway's gateway timeout, while exceeding the UX ceiling (~60s) by only the minimum needed
- 25s per-iteration cap — one hung API call breaks the loop but preserves partial answers from completed iterations
- Reduced iterations from 5 to 3 — the agent loop pattern (tool_use + execute + response) rarely needs more than 2-3 turns
- TimeoutError caught before the generic Exception handler to prevent 502 — returns a graceful loop_result dict so the rest of the endpoint proceeds normally

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Agent loop timeout hardening complete
- Ready for Phase 10 (Les connexions) to wire front-back connections
- The timeout message is in French only — i18n for other languages is out of scope for this plan

---
*Phase: 09-les-tuyaux*
*Completed: 2026-04-12*
