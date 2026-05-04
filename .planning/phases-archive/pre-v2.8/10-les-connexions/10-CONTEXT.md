# Phase 10: Les connexions - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Every Flutter-to-backend API call reaches its endpoint and returns structured data — zero 404, zero silent failure, tool calling works on server-key path.

Requirements: PIPE-01, PIPE-02, PIPE-03, PIPE-04, PIPE-05, PIPE-06, PIPE-07, PIPE-08

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — infrastructure wiring phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Key constraints from research:
- 5 URL double-prefix fixes: ApiService.baseUrl already ends with /api/v1 via _normalizeBaseUrl(), call sites add /api/v1/ again
- Fix is mechanical: remove /api/v1 prefix from 5 call sites in document_service.dart and coach_memory_service.dart
- camelCase fix: backend Pydantic sends toolCalls, Flutter reads json['tool_calls'] — read json['toolCalls'] instead, with ?? fallback for both
- BYOK path constructs CoachResponse directly in Dart (never hits fromJson) — fix must NOT break BYOK path
- api.mint.ch: unreachable domain, remove from URL candidates
- Staging URL: add Railway staging URL to candidates for TestFlight builds
- PIPE-05 requires creating a backend DELETE endpoint that doesn't exist yet

</decisions>

<code_context>
## Existing Code Insights

### Key Files
- `apps/mobile/lib/services/document_service.dart` — 3 broken URLs (lines ~1086, ~1125, ~1169)
- `apps/mobile/lib/services/memory/coach_memory_service.dart` — 2 broken URLs (lines ~80, ~106)
- `apps/mobile/lib/services/coach/coach_chat_api_service.dart` — toolCalls/tool_calls mismatch (line ~128-150)
- `apps/mobile/lib/services/api_service.dart` — URL candidates list, _normalizeBaseUrl()
- `services/backend/app/api/v1/endpoints/coach_chat.py` — needs DELETE endpoint for sync-insight

### Established Patterns
- ApiService.baseUrl ends with /api/v1 via _normalizeBaseUrl()
- Services should use $baseUrl/endpoint (not $baseUrl/api/v1/endpoint)
- Pydantic v2 with alias_generator=to_camel sends camelCase JSON

### Integration Points
- document_service → backend /documents/* endpoints
- coach_memory_service → backend /coach/sync-insight endpoint
- coach_chat_api_service → backend /coach/chat endpoint (server-key path)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure wiring phase. Refer to ROADMAP phase description and success criteria.

Audit findings reference: `.planning/architecture/14-INFRA-AUDIT-FINDINGS.md` (P0-PIPE-1 through P0-PIPE-5, P1-PIPE-1, P1-PIPE-2, P2-PIPE-1)

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure wiring stayed within scope.

</deferred>
