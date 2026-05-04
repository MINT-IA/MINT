---
phase: 10-les-connexions
plan: 01
subsystem: api
tags: [flutter, fastapi, url-fix, json-serialization, tool-calling, rag]

# Dependency graph
requires:
  - phase: 09-les-tuyaux
    provides: "Backend infra hardening (SQLite, RAG persistence, Docker, timeouts)"
provides:
  - "5 Flutter-to-backend URLs fixed (no more double /api/v1 prefix)"
  - "Tool calling restored on server-key path (camelCase JSON alignment)"
  - "DELETE /sync-insight/{insight_id} endpoint for RAG insight pruning"
  - "Dead DNS removed, staging URL added as fallback"
  - "Error logging in document_service catch blocks"
affects: [11-la-navigation, 12-la-preuve]

# Tech tracking
tech-stack:
  added: []
  patterns: ["baseUrl already includes /api/v1 — call sites use $baseUrl/endpoint directly"]

key-files:
  created: []
  modified:
    - apps/mobile/lib/services/document_service.dart
    - apps/mobile/lib/services/memory/coach_memory_service.dart
    - apps/mobile/lib/services/api_service.dart
    - apps/mobile/lib/services/coach/coach_chat_api_service.dart
    - services/backend/app/api/v1/endpoints/coach_chat.py

key-decisions:
  - "No camelCase fallback in fromJson — backend is source of truth, single key name only"
  - "Staging URL as fallback after production, not replacement"

patterns-established:
  - "URL pattern: always $baseUrl/endpoint, never $baseUrl/api/v1/endpoint (baseUrl already ends with /api/v1)"
  - "JSON key pattern: fromJson must use camelCase keys matching Pydantic alias_generator=to_camel"

requirements-completed: [PIPE-01, PIPE-02, PIPE-03, PIPE-04, PIPE-05, PIPE-06, PIPE-07, PIPE-08]

# Metrics
duration: 6min
completed: 2026-04-12
---

# Phase 10 Plan 01: Les Connexions Summary

**Fix 5 broken Flutter-to-backend URLs (double /api/v1 prefix), restore tool calling via camelCase JSON alignment, add DELETE endpoint for insight pruning, clean URL candidates**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-12T09:51:29Z
- **Completed:** 2026-04-12T09:57:30Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- Fixed all 5 Flutter URLs that 404'd due to double /api/v1 prefix (document scan, vision extract, premier eclairage, insight sync, insight delete)
- Restored tool calling on server-key path by fixing camelCase JSON key mismatch (tool_calls -> toolCalls, tokens_used -> tokensUsed)
- Created DELETE /sync-insight/{insight_id} backend endpoint for RAG insight pruning (was missing, Flutter already called it)
- Removed dead api.mint.ch DNS entry (was adding 2s latency), added staging Railway URL as fallback
- Added debugPrint error logging to 3 silently-swallowing catch blocks in document_service.dart

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix 5 double-prefix URLs + clean URL candidates** - `1d7c2cb2` (fix)
2. **Task 2: Create backend DELETE /sync-insight/{insight_id} endpoint** - `a5ed8f73` (feat)
3. **Task 3: Fix camelCase JSON key mismatch in fromJson** - `d015a966` (fix)

## Files Created/Modified
- `apps/mobile/lib/services/document_service.dart` - Fixed 3 double-prefix URLs, added debugPrint logging, added foundation.dart import
- `apps/mobile/lib/services/memory/coach_memory_service.dart` - Fixed 2 double-prefix URLs
- `apps/mobile/lib/services/api_service.dart` - Removed dead api.mint.ch, added staging Railway URL
- `apps/mobile/lib/services/coach/coach_chat_api_service.dart` - Fixed 2 snake_case JSON keys to camelCase
- `services/backend/app/api/v1/endpoints/coach_chat.py` - Added DELETE /sync-insight/{insight_id} endpoint

## Decisions Made
- No camelCase fallback (`json['toolCalls'] ?? json['tool_calls']`) -- backend is source of truth, single key enforces contract clarity
- Staging URL placed after production in candidates list so production is always tried first
- BYOK path confirmed independent of fromJson changes (CoachChatApiResponse not used in coach_orchestrator.dart)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added missing flutter/foundation.dart import for debugPrint**
- **Found during:** Task 1 (URL fixes + error logging)
- **Issue:** document_service.dart did not import foundation.dart, needed for debugPrint
- **Fix:** Added `import 'package:flutter/foundation.dart';`
- **Files modified:** apps/mobile/lib/services/document_service.dart
- **Verification:** flutter analyze 0 errors
- **Committed in:** 1d7c2cb2 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Trivial import addition required for debugPrint to compile. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All Flutter-to-backend pipes are now wired correctly
- Phase 11 (La navigation) can proceed -- shell/tabs/drawer architecture
- Phase 12 (La preuve) device gate will validate these connections end-to-end on real iPhone

---
*Phase: 10-les-connexions*
*Completed: 2026-04-12*
