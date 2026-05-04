---
phase: 13-anonymous-hook-auth-bridge
plan: 01
subsystem: api
tags: [fastapi, anonymous-chat, rate-limiting, compliance, sqlalchemy, pydantic]

# Dependency graph
requires: []
provides:
  - "POST /api/v1/anonymous/chat endpoint with 3-message lifetime rate limit"
  - "AnonymousSession DB model for device-token tracking"
  - "Discovery system prompt (mode decouverte) — no tools, no profile, no memory"
  - "AnonymousChatRequest/AnonymousChatResponse Pydantic schemas"
affects: [13-02 (Flutter anonymous chat screen), 13-03 (session migration on auth)]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Device-scoped rate limiting via X-Anonymous-Session UUID header + DB tracking", "Stripped-down system prompt written from scratch for anonymous context"]

key-files:
  created:
    - services/backend/app/api/v1/endpoints/anonymous_chat.py
    - services/backend/app/schemas/anonymous_chat.py
    - services/backend/app/models/anonymous_session.py
    - services/backend/tests/test_anonymous_chat.py
  modified:
    - services/backend/app/api/v1/router.py

key-decisions:
  - "Discovery prompt written from scratch (not derived from authenticated prompt) to prevent information disclosure about authenticated capabilities"
  - "Own _NoRagOrchestrator in anonymous_chat.py instead of importing from coach_chat to maintain full separation between anonymous and authenticated paths"
  - "UUID format validation on session header as primary defense, IP-based slowapi as secondary"

patterns-established:
  - "Anonymous endpoint pattern: separate router, no auth deps, own DB model, own orchestrator"
  - "Compliance wording: avoid banned terms literally in prompt source code (use rephrased equivalents)"

requirements-completed: [ANON-01, ANON-05, ANON-06]

# Metrics
duration: 9min
completed: 2026-04-12
---

# Phase 13 Plan 01: Anonymous Chat Endpoint Summary

**Anonymous chat POST endpoint with device-scoped 3-message rate limiting, discovery system prompt, and compliance filtering via ComplianceGuardrails**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-12T14:15:20Z
- **Completed:** 2026-04-12T14:24:30Z
- **Tasks:** 1 (TDD: RED + GREEN)
- **Files modified:** 5

## Accomplishments
- POST /api/v1/anonymous/chat endpoint with full request/response cycle
- 3-message lifetime rate limit per device token (UUID), enforced via AnonymousSession DB model
- Discovery system prompt ("mode decouverte") with zero references to tools, profile, memory, or dossier
- ComplianceGuardrails applied to all LLM output, PII scrubbing on all input
- 11 tests passing (HTTP contract, rate limiting, prompt content, session isolation, DB model, UUID validation)
- Full backend suite: 5285 passed, 0 failures, 0 regressions

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Failing tests for anonymous chat** - `716a1646` (test)
2. **Task 1 GREEN: Implement anonymous chat endpoint** - `830b27d5` (feat)

## Files Created/Modified
- `services/backend/app/api/v1/endpoints/anonymous_chat.py` - Anonymous chat endpoint with rate limiting, discovery prompt, PII scrubbing, compliance filtering
- `services/backend/app/schemas/anonymous_chat.py` - AnonymousChatRequest/AnonymousChatResponse Pydantic v2 schemas with camelCase aliases
- `services/backend/app/models/anonymous_session.py` - AnonymousSession SQLAlchemy model (session_id, message_count, created_at)
- `services/backend/app/api/v1/router.py` - Added anonymous_chat router with /anonymous prefix
- `services/backend/tests/test_anonymous_chat.py` - 11 tests covering all acceptance criteria

## Decisions Made
- Discovery prompt written from scratch (not derived from authenticated prompt) to prevent information disclosure about authenticated capabilities (T-13-05)
- Own _NoRagOrchestrator instead of importing from coach_chat — full separation between anonymous and authenticated paths (T-13-06)
- UUID format validation on session header as primary defense (T-13-01), IP-based slowapi 10/min as secondary (T-13-03)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Rephrased banned terms in discovery prompt source code**
- **Found during:** Task 1 GREEN (implementation)
- **Issue:** Compliance wording test (test_compliance_wording.py) scans Python source for banned terms. Discovery prompt lines contained 'garanti', 'garantie' as part of "never use these terms" instructions, triggering 2 violations.
- **Fix:** Rephrased prompt rules to convey the same constraint without using banned terms literally: "Jamais de promesse de rendement ni de certitude sur les resultats" and "Jamais de langage absolu ou prescriptif. Utilise le conditionnel."
- **Files modified:** services/backend/app/api/v1/endpoints/anonymous_chat.py
- **Verification:** test_compliance_wording.py passes, discovery prompt still enforces the same constraints
- **Committed in:** 830b27d5 (Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Essential fix for compliance test suite. No scope creep.

## Issues Encountered
- Test env needed ANTHROPIC_API_KEY set to avoid 503 from the server key check — added `os.environ.setdefault` in test file

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Anonymous chat endpoint is ready for Flutter consumption (Plan 13-02)
- Session migration (Plan 13-03) can query AnonymousSession model to transfer conversation history on auth
- DB migration script needed for production deployment (AnonymousSession table creation)

---
*Phase: 13-anonymous-hook-auth-bridge*
*Completed: 2026-04-12*
