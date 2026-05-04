---
phase: 16-couple-mode-dissymetrique
plan: 01
subsystem: api
tags: [coach, couple, tools, privacy, system-prompt]

requires:
  - phase: 15-coach-intelligence
    provides: provenance/earmark tool pattern, _execute_internal_tool dispatch, build_system_prompt directive chain
provides:
  - save_partner_estimate and update_partner_estimate internal tools (ack-only)
  - _COUPLE_DISSYMETRIQUE system prompt directive for natural couple detection
  - Privacy guarantee: zero DB access in partner handlers
affects: [16-02-couple-mode-dissymetrique, coach-chat, couple-projections]

tech-stack:
  added: []
  patterns: [ack-only internal tool with source-code privacy verification tests]

key-files:
  created:
    - services/backend/tests/test_couple_mode.py
  modified:
    - services/backend/app/services/coach/coach_tools.py
    - services/backend/app/services/coach/claude_coach_service.py
    - services/backend/app/api/v1/endpoints/coach_chat.py

key-decisions:
  - "Ack-only handlers with zero DB/user_id access — privacy guarantee enforced by source inspection tests"
  - "System prompt asks one question at a time in priority order (salary > age > LPP > 3a > canton)"

patterns-established:
  - "Source-code inspection tests: verify handler blocks do not reference db. or user_id via regex on source"
  - "Ack-only couple tools: backend never persists partner data, Flutter intercepts and stores locally"

requirements-completed: [COUP-01, COUP-04]

duration: 4min
completed: 2026-04-12
---

# Phase 16 Plan 01: Backend Couple Mode Summary

**Two ack-only internal tools (save/update_partner_estimate), system prompt directive for natural couple detection, and 13 tests with source-code privacy verification**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-12T18:29:40Z
- **Completed:** 2026-04-12T18:34:29Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- save_partner_estimate and update_partner_estimate registered as internal tools with full input schemas (5 fields each)
- _COUPLE_DISSYMETRIQUE system prompt directive guides coach to detect couple context and collect estimates one question at a time
- Ack-only handlers in coach_chat.py return field-name confirmations without any DB writes or user_id access
- 13 tests covering registration, directive, handlers, and privacy guarantee (including source-code inspection)

## Task Commits

Each task was committed atomically:

1. **Task 1: Tool definitions, system prompt directive, and ack-only handlers** - `eb9db486` (feat)
2. **Task 2: Tests for couple mode tools, directive, handlers, and privacy guarantee** - `9ce4baaf` (test)

## Files Created/Modified
- `services/backend/app/services/coach/coach_tools.py` - Added save_partner_estimate and update_partner_estimate to INTERNAL_TOOL_NAMES and COACH_TOOLS
- `services/backend/app/services/coach/claude_coach_service.py` - Added _COUPLE_DISSYMETRIQUE directive and appended to build_system_prompt
- `services/backend/app/api/v1/endpoints/coach_chat.py` - Added ack-only handlers for both partner estimate tools
- `services/backend/tests/test_couple_mode.py` - 13 tests: registration, directive, handlers, privacy

## Decisions Made
- Ack-only handlers with zero DB/user_id access — enforced by both runtime mock test and source-code inspection test
- System prompt asks one question at a time in priority order: salary, age, LPP, 3a, canton
- Privacy reminder in prompt: "Les donnees de ton/ta conjoint-e restent uniquement sur ton telephone"

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Backend couple tools ready for Plan 02 (Flutter local persistence + CoachContext aggregate injection)
- Flutter needs to intercept save_partner_estimate/update_partner_estimate tool calls and persist locally
- CoachContext needs partner_declared (bool) and partner_confidence (float) aggregate flags

---
*Phase: 16-couple-mode-dissymetrique*
*Completed: 2026-04-12*
