# Phase 21: Coach Memory & Dossier - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Mode:** Auto-generated from Gate 0 findings + v2.5 infrastructure

<domain>
## Phase Boundary

Fix: coach doesn't remember facts across sessions. The retrieve_memories and save_insight internal tools exist (from v2.1+) but may not be wired correctly end-to-end. Coach must pull relevant past insights before responding and persist key facts learned during conversation.

Requirements: CTX-02 (retrieve_memories works), CTX-03 (save_insight persists)

Gate 0 finding: Coach asked for salary, user answered, but in next session coach doesn't know the salary. The memory tools exist in code but the round-trip (save → store → retrieve → inject into prompt) may be broken.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — this is a fix/verification phase.

Key investigation areas:
- Does save_insight actually persist to backend DB? (check coach_chat.py handler)
- Does retrieve_memories query the right DB/vector store? (check RAG service)
- Is the memory block injected into system prompt correctly? (check claude_coach_service.py)
- Does the coach_memory_service.dart on Flutter side sync correctly?
- Is the memory content visible in "Ce que MINT sait de toi"?

Key files:
- services/backend/app/api/v1/endpoints/coach_chat.py — save_insight handler, retrieve_memories handler
- services/backend/app/services/coach/claude_coach_service.py — memory block in system prompt
- apps/mobile/lib/services/memory/coach_memory_service.dart — Flutter-side memory
- apps/mobile/lib/services/rag_service.dart — RAG integration

</decisions>

<code_context>
## Existing Code Insights

From v2.5: ProvenanceRecord, EarmarkTag, CommitmentDevice, PreMortemEntry all persist to DB and inject into CoachContext. The save_insight tool should follow the same pattern but may predate the v2.5 wiring improvements.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — investigate and fix the save/retrieve round-trip.

</specifics>

<deferred>
## Deferred Ideas

None — pure fix.

</deferred>
