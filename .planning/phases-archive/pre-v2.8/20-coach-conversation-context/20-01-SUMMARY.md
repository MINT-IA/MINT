---
phase: 20-coach-conversation-context
plan: 01
subsystem: api
tags: [claude, multi-turn, conversation-history, llm, coach, pii-sanitization]

# Dependency graph
requires:
  - phase: 19-auth-state-propagation
    provides: auth state propagation so coach can authenticate to backend
provides:
  - Multi-turn conversation context for coach chat (server-key path)
  - Conversation history sanitization (PII scrub, injection filter, 8-msg cap)
  - Retry actions on coach chat error states
affects: [21-coach-memory-persistence, 22-markdown-rendering]

# Tech tracking
tech-stack:
  added: []
  patterns: [multi-turn-claude-messages, conversation-history-sanitization]

key-files:
  created: []
  modified:
    - apps/mobile/lib/services/coach/coach_orchestrator.dart
    - apps/mobile/lib/services/coach/coach_chat_api_service.dart
    - services/backend/app/schemas/coach_chat.py
    - services/backend/app/api/v1/endpoints/coach_chat.py
    - services/backend/app/services/rag/llm_client.py
    - services/backend/app/services/rag/orchestrator.py
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart

key-decisions:
  - "Conversation history as structured messages array (not concatenated text) for proper multi-turn Claude API usage"
  - "History only on first agent loop iteration to avoid duplication on tool re-calls"
  - "Retry chip re-sends last user message rather than generic retry text"

patterns-established:
  - "Multi-turn pattern: Flutter builds history from ConversationStore, sends as conversation_history array, backend sanitizes and passes to Claude as messages"
  - "Sanitization pattern: _sanitize_conversation_history applies PII scrub + injection filter + role whitelist + 8-msg cap + 500-char truncation"

requirements-completed: [CTX-01, CTX-04, CTX-05]

# Metrics
duration: 9min
completed: 2026-04-13
---

# Phase 20 Plan 01: Coach Conversation Context Summary

**Multi-turn conversation history wired through Flutter->Backend->Claude so the coach remembers its own questions across 4+ exchanges**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-13T11:40:18Z
- **Completed:** 2026-04-13T11:49:29Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments
- Coach server-key path now sends last 8 messages as structured conversation_history to backend
- Backend sanitizes history (PII scrub, injection filter, role whitelist, 8-msg cap, 500-char truncation) before forwarding to Claude
- Claude receives proper multi-turn messages array instead of single-turn, enabling context-aware responses
- Error states in coach chat now include retry action (re-sends last user message)

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire conversation history through Flutter to backend** - `995c3513` (feat)
2. **Task 2: Backend uses conversation history as multi-turn Claude messages** - `79fecc89` (feat)
3. **Task 3: Improve error handling and timeout for coach chat** - `6af6a8db` (fix)

## Files Created/Modified
- `apps/mobile/lib/services/coach/coach_orchestrator.dart` - _tryServerKeyChat builds conversation_history from last 8 messages
- `apps/mobile/lib/services/coach/coach_chat_api_service.dart` - chat() accepts and sends conversationHistory parameter
- `services/backend/app/schemas/coach_chat.py` - CoachChatRequest re-adds conversation_history field
- `services/backend/app/api/v1/endpoints/coach_chat.py` - _sanitize_conversation_history + wiring through agent loop
- `services/backend/app/services/rag/llm_client.py` - _call_claude builds multi-turn messages array
- `services/backend/app/services/rag/orchestrator.py` - RAGOrchestrator passes conversation_history through
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` - Error catch blocks include retry suggestedActions

## Decisions Made
- Used structured messages array (role/content dicts) rather than concatenated text for the Claude API, enabling proper multi-turn conversation
- History passed only on first iteration of agent loop -- subsequent iterations (tool result re-calls) already have context from the first call's response
- Retry action re-sends the last user message verbatim rather than using a generic "retry" label, so it works naturally through the existing suggested actions chip mechanism

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Threat Flags

None found -- all security surface was anticipated in the plan's threat model (T-20-01 through T-20-04).

## Known Stubs

None -- all data paths are fully wired end-to-end.

## Next Phase Readiness
- Conversation context is wired -- coach can now remember its own questions
- Ready for Phase 21 (coach memory persistence) or Phase 22 (markdown rendering)
- Manual verification needed: open coach, ask a question, get a follow-up question from coach, answer it, verify coach interprets answer in context

---
*Phase: 20-coach-conversation-context*
*Completed: 2026-04-13*
