---
phase: quick
plan: 260412-dr1
subsystem: backend
tags: [fastapi, rag, sentry, error-handling, coach-chat]

provides:
  - "Resilient RAG initialization in coach_chat.py — never 503 on missing pgvector/chromadb"
  - "_NoRagOrchestrator fallback class for LLM-only coach responses"
  - "4 tests proving graceful degradation for both Sentry error scenarios"
affects: [coach-ai, rag, staging-deployment]

tech-stack:
  added: []
  patterns: ["_NoRagOrchestrator fallback when RAG backends unavailable"]

key-files:
  created: []
  modified:
    - services/backend/app/api/v1/endpoints/coach_chat.py
    - services/backend/tests/test_coach_chat_endpoint.py

key-decisions:
  - "Used _NoRagOrchestrator class (duck-typed .query()) instead of string sentinel for cleaner fallback"
  - "Catch Exception (not just ImportError) in all 3 RAG init functions"
  - "RAG endpoints (rag.py) left with 503 on ImportError — RAG IS their purpose, unlike coach chat"

requirements-completed: []

duration: 5min
completed: 2026-04-12
---

# Quick Task 260412-dr1: Fix 2 Sentry Errors Blocking Coach Chat

**Widened exception handling in coach_chat.py RAG init to catch ALL failures (not just ImportError), falling back to _NoRagOrchestrator for LLM-only responses without vector search**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-12T06:57:47Z
- **Completed:** 2026-04-12T07:02:36Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Coach chat no longer returns HTTP 503 when pgvector document_embeddings table is missing (Sentry error 1)
- Coach chat no longer crashes when chromadb persist directory is unavailable (Sentry error 2)
- Added _NoRagOrchestrator fallback class that provides identical .query() interface but skips retrieval
- 4 new tests prove graceful degradation for all failure scenarios
- Full backend test suite passes: 5250 passed, 0 failures

## Task Commits

1. **Task 1: Harden RAG init with broad exception handling** - `2f65bf01` (fix)
2. **Task 2: Add tests proving graceful RAG degradation** - `11093e46` (test)

## Files Created/Modified
- `services/backend/app/api/v1/endpoints/coach_chat.py` - Widened exception handling in _get_vector_store, _get_hybrid_search, _get_orchestrator; added _NoRagOrchestrator fallback class; removed HTTP 503 on RAG init failure
- `services/backend/tests/test_coach_chat_endpoint.py` - 4 new tests: operational error, permission error, import error, no-RAG fallback

## Decisions Made
- Used `_NoRagOrchestrator` class with duck-typed `.query()` method instead of a `"NO_RAG"` string sentinel. This avoids special-case checks in `_run_agent_loop` — the fallback orchestrator simply calls the LLM without RAG context chunks.
- Did NOT fix the same pattern in `rag.py` — those are dedicated RAG endpoints where 503 is appropriate when RAG is unavailable. Coach chat is different because it must always respond.
- Scanned the entire backend for similar `ImportError -> 503` patterns; coach_chat.py was the only problematic case.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Replaced "NO_RAG" string sentinel with _NoRagOrchestrator class**
- **Found during:** Task 1 (implementation)
- **Issue:** Plan specified `"NO_RAG"` string sentinel which would require special-case handling everywhere `orchestrator.query()` is called
- **Fix:** Created `_NoRagOrchestrator` class with identical `.query()` interface that calls LLM directly without retrieval — no special-case code needed in callers
- **Files modified:** services/backend/app/api/v1/endpoints/coach_chat.py
- **Verification:** All 38 tests pass, _NoRagOrchestrator instantiates correctly
- **Committed in:** 2f65bf01

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing critical functionality)
**Impact on plan:** Cleaner implementation than planned. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Coach chat will work on Railway staging without pgvector migration
- RAG enrichment will activate automatically once pgvector migration 003 is executed (P3-A milestone)
- No blockers for deployment

---
## Self-Check: PASSED

- FOUND: coach_chat.py
- FOUND: test_coach_chat_endpoint.py
- FOUND: SUMMARY.md
- FOUND: commit 2f65bf01
- FOUND: commit 11093e46

---
*Plan: quick/260412-dr1*
*Completed: 2026-04-12*
