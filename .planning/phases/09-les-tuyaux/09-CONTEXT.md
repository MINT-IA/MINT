# Phase 9: Les tuyaux - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Backend is stable on Railway with persistent RAG corpus, fail-fast guards, and bounded agent loop — deploys survive restarts, crashes are loud not silent.

Requirements: INFRA-01, INFRA-02, INFRA-03, INFRA-04, INFRA-05

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Key constraints from research:
- Railway timeout is 15 min (not 60s) — the 55s asyncio.wait_for is a UX choice, not a platform limit
- ChromaDB persistence requires Railway Volume mount at /data/chromadb + RAILWAY_RUN_UID=0 for non-root Docker
- Education corpus: expand Docker build context or COPY education/inserts/ into image
- SQLite fail-fast mirrors existing JWT fail-fast pattern in same config.py file
- OPENAI_API_KEY needed for embeddings — add to Settings with optional warning

</decisions>

<code_context>
## Existing Code Insights

### Key Files
- `services/backend/app/core/config.py` — Settings class, DATABASE_URL default, JWT fail-fast pattern
- `services/backend/app/main.py:215-219` — ChromaDB init, education path resolution
- `services/backend/app/api/v1/endpoints/coach_chat.py:929-1002` — Agent loop (multi-iteration Claude calls)
- `services/backend/app/services/rag/insight_embedder.py:49-50` — OPENAI_API_KEY usage
- `services/backend/Dockerfile` — Docker build context

### Established Patterns
- Settings class uses pydantic-settings with env var loading
- Startup validation: JWT settings already fail-fast in production
- RAG init happens in main.py lifespan handler

### Integration Points
- Railway dashboard: volume mount, env vars, root directory config
- Docker: build context, COPY paths, user permissions
- main.py: startup sequence, error handling

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Refer to ROADMAP phase description and success criteria.

Audit findings reference: `.planning/architecture/14-INFRA-AUDIT-FINDINGS.md` (P0-INFRA-1, P0-INFRA-2, P1-INFRA-1, P1-INFRA-2, P1-INFRA-3)

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure phase stayed within scope.

</deferred>
