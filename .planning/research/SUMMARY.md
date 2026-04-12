# Project Research Summary

**Project:** MINT v2.4 Fondation
**Domain:** Infrastructure recovery for existing Flutter + FastAPI app (32 audit findings, 11 P0)
**Researched:** 2026-04-12
**Confidence:** HIGH

## Executive Summary

MINT v2.4 is not a feature milestone. It is emergency plumbing. The app compiles, 9256 tests pass, but the product is non-functional on a real device: the user is trapped on a single chat screen with no navigation, 5 backend endpoints return 404 due to double URL prefixes, tool calling is silently dead from a camelCase mismatch, the RAG corpus is empty after every deploy, and there is no shell, no tabs, no drawer. All 32 findings trace to the same root cause: parallel agent-driven development built components that look correct individually but were never connected end-to-end (the "facade sans cablage" pattern documented in project memory).

The fix requires zero new dependencies, zero version bumps, and zero feature additions. Every fix is configuration, wiring, or code-level correction using the existing stack (Flutter 3.6 + GoRouter 13.2, FastAPI + Pydantic v2, ChromaDB, Railway). The critical insight is that the fix order is non-negotiable: backend infrastructure must be stable before front-back connections are fixed, connections must work before navigation wraps them, and navigation must exist before human validation is meaningful. Violating this order recreates exactly the damage that caused the current state.

The highest-risk item is Phase 3 (shell migration): converting 143 flat GoRouter routes into a StatefulShellRoute with 3 tab branches while preserving all deep links and chat state. Only 3 routes go inside shell branches; everything else stays top-level as full-screen overlays. The #1 operational risk across all phases is partial fixes -- error swallowing in document_service.dart masks remaining 404s, and the graceful RAG fallback hides an empty corpus. Every fix must be verified by tracing from the wire to its consumer screen, not just checking the endpoint returns 200.

## Key Findings

### Stack (Zero Changes Needed)

No new dependencies. No version bumps. All 7 fixes are configuration and code patterns using the existing stack.

**Existing technologies (confirmed sufficient):**
- **GoRouter ^13.2.0**: StatefulShellRoute.indexedStack available since v7.0 -- no upgrade needed for shell migration
- **Railway (deploy)**: HTTP timeout is 15 minutes (not 60s as the audit initially stated) -- the real constraint is UX (>60s feels broken) and Gunicorn's 120s worker timeout
- **ChromaDB**: Persistence is a Railway volume config issue, not a version issue -- persist_directory needs an absolute path on a mounted volume
- **Pydantic v2**: camelCase serialization is correct on the backend side -- the fix is Flutter reading the right key name
- **Docker multi-stage**: Build context expansion to repo root is the cleanest way to include education corpus

### Expected Fixes (Not Features)

**Must fix (app non-functional without):**
- URL double-prefix deduplication (5 endpoints returning 404)
- JSON camelCase alignment (tool calling completely dead)
- StatefulShellRoute shell (user trapped, no navigation)
- ProfileDrawer mounting (profile/settings/logout inaccessible)
- RAG corpus persistence (coach has no knowledge base)
- SQLite fail-fast guard (silent data loss risk)
- Agent loop timeout (502 on multi-turn tool calls)

**Important fixes (app degraded without):**
- safePop fallback routing (40 screens dump to chat on back)
- Zombie screen cleanup (6 deleted screens still routable)
- Explorer hub wiring (7 hubs all redirect to chat)
- api.mint.ch DNS removal (+2s latency per API call)
- OPENAI_API_KEY validation (embeddings silently fail)

**Explicitly NOT building in v2.4:**
- SSE streaming (fix timeout first, SSE is v2.5+)
- New Explorer hub content (navigation shell must exist first)
- CORS for Flutter Web (mobile is the only real user)
- Coach prompt improvements (the pipe is broken, not the content)

### Architecture Approach

The architecture is a strict 4-phase sequential pipeline where each phase depends on the previous one being deployed and verified. The key structural decision is that the shell wraps only 3 tab roots (Aujourd'hui, Coach, Explorer) while all 140+ other routes remain top-level with `parentNavigatorKey: _rootNavigatorKey`, pushing over the shell as full-screen overlays. This "additive wrapping, not restructuring" approach minimizes blast radius.

**Major components to fix:**
1. **Backend infra** (config.py, main.py, Dockerfile, coach_chat.py) -- fail-fast guards, RAG persistence, agent timeout
2. **Front-back pipes** (document_service.dart, coach_memory_service.dart, coach_chat_api_service.dart) -- URL prefix, JSON casing, DNS
3. **Navigation shell** (app.dart, new MintShell widget, safePop) -- StatefulShellRoute, ProfileDrawer, back button
4. **Validation** -- real iPhone, cold start, 8 E2E flows, creator walkthrough

### Critical Pitfalls

1. **Partial URL fix (the "4 of 5" trap)** -- 5 broken URLs across 2 files in 2 directories. Missing one means one feature silently 404s while others appear fixed. Prevention: grep for `$baseUrl/api/v1/` after fix, expect 0 matches.

2. **camelCase fix breaks BYOK path** -- Server-key responses use camelCase (Pydantic), but BYOK path constructs CoachResponse directly in Dart. The fix is ONLY in `fromJson` (server-key deserialization). The BYOK path never touches `fromJson`. Both paths must be tested.

3. **Shell migration breaks deep links** -- Only 3 routes go in shell branches. All others stay top-level with `_rootNavigatorKey`. Adding routes inside the shell that should be overlays destroys chat state and removes tabs. Route inventory before and after is mandatory.

4. **Docker image bloat from build context expansion** -- Expanding build context to repo root copies apps/mobile, .git, node_modules into image. Use a .dockerignore or pre-build copy script to keep image under 600MB.

5. **Error swallowing masks remaining failures** -- document_service.dart silently swallows errors. After URL fixes, endpoints return real data but unexpected response shapes get caught and discarded. Add logging to catch blocks BEFORE fixing URLs.

## Implications for Roadmap

### Phase 1: Les Tuyaux (Backend Infrastructure)
**Rationale:** If the backend crashes, fixing Flutter is pointless. Backend must be stable and deployed before any frontend work.
**Delivers:** Stable backend on Railway with persistent RAG, fail-fast guards, and bounded agent loop.
**Addresses:** P0-INFRA-1 (SQLite), P0-INFRA-2 (RAG persistence), P1-INFRA-1 (timeout), P1-INFRA-2 (OpenAI key), P1-INFRA-3 (education path)
**Avoids:** Pitfall 5 (volume permissions -- pin UID), Pitfall 6 (image bloat), Pitfall 7 (timeout data corruption), Pitfall 9 (guard breaks local dev)
**Estimated effort:** 2-3 days
**Gate to Phase 2:** pytest passes, Railway staging deploy succeeds, RAG corpus count > 0 in startup logs

### Phase 2: Les Connexions (Front-Back Wiring)
**Rationale:** Backend is stable. Now fix the 5 broken URLs and the camelCase mismatch so data actually flows. These are string edits with surgical scope.
**Delivers:** All endpoints return 200, tool calling works, premier eclairage loads after document scan.
**Addresses:** P0-PIPE-1..5 (URL prefix), P1-PIPE-1 (camelCase), P1-PIPE-2 (DNS)
**Avoids:** Pitfall 1 (partial fix -- grep verify all 5), Pitfall 2 (BYOK regression -- test both paths), Pitfall 8 (facade -- trace to consumer), Pitfall 13 (error swallowing -- add logging first)
**Estimated effort:** 2-3 days
**Gate to Phase 3:** All 5 URLs return 200 on staging, tool calling works in both BYOK and server-key modes

### Phase 3: La Navigation (Shell Architecture)
**Rationale:** Backend and pipes work. Now give the user a way to navigate. This is the highest-risk phase: 143 routes, but only 3 go into shell branches.
**Delivers:** 3-tab shell with persistent state, ProfileDrawer, working back button, safePop that does not loop.
**Addresses:** P0-NAV-1 (shell), P0-NAV-2 (drawer), P0-NAV-3 (back loop), P0-NAV-4 (/profile), P1-NAV-1 (safePop), P1-NAV-2 (zombies), P1-NAV-3 (Explorer hubs)
**Avoids:** Pitfall 3 (deep link breakage -- route inventory), Pitfall 4 (safePop loop in shell -- replace function body once), Pitfall 11 (drawer without shell -- mount on shell scaffold only), Pitfall 12 (zombie deletion -- add redirects)
**Estimated effort:** 5-7 days (largest phase)
**Gate to Phase 4:** All 3 tabs visible, drawer opens, back button never loops, route inventory matches

### Phase 4: La Preuve (Validation)
**Rationale:** Everything is wired. Now prove it works on a real device, cold start, zero help. This is the only gate that matters per project memory: "creator-device, mandatory, non-skippable."
**Delivers:** Confidence that the app is functional for a real user. 8 E2E flows verified.
**Addresses:** The meta-finding that 9256 tests green means nothing if the app is broken on iPhone.
**Estimated effort:** 3-5 days (human time, not agent time)
**Gate:** Creator walks cold-start to first insight on real iPhone with annotated screenshots.

### Phase Ordering Rationale

- **Sequential execution is non-negotiable.** Parallel agent execution caused the current damage. Phase 1 must be deployed and verified before Phase 2 starts.
- **Backend before frontend** because fixing Flutter URLs when the backend crashes yields 500s instead of 404s -- no improvement.
- **Connections before navigation** because building a polished shell around dead endpoints creates a beautiful cage. The user can navigate to screens that do nothing.
- **Validation is human, not automated.** 9256 passing tests proved nothing. The only real gate is a cold-start device walkthrough.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (Tuyaux):** Railway volume mount specifics (mount timing, permissions, RAILWAY_RUN_UID) -- documentation is good but deploy-test cycle needed to verify
- **Phase 3 (Navigation):** GoRouter StatefulShellRoute integration with 143 existing routes -- well-documented pattern but MINT's ScopedGoRoute custom wrapper may have edge cases

Phases with standard patterns (skip research-phase):
- **Phase 2 (Connexions):** Pure string edits. 5 URL fixes + 1 JSON key change. Zero ambiguity.
- **Phase 4 (Validation):** Human walkthrough. No code research needed.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All findings verified against actual codebase with line numbers. Zero speculation on versions or dependencies. |
| Features | HIGH | Every "feature" is a confirmed broken endpoint/route from the 32-finding audit. No guesswork. |
| Architecture | HIGH | 4-phase structure follows directly from dependency analysis. Phase order is deterministic. |
| Pitfalls | HIGH (code), MEDIUM (Railway) | Code pitfalls verified by grep. Railway volume behavior based on docs + community reports, not firsthand testing. |

**Overall confidence:** HIGH

### Gaps to Address

- **Railway reverse proxy timeout:** STACK.md corrects the audit's claim of 60s to 15 minutes (per Railway Help Station), but the exact behavior under Railway's paid vs hobby plans should be verified on first staging deploy. The application-level 55s timeout makes this moot in practice.
- **ScopedGoRoute compatibility with StatefulShellRoute:** MINT uses a custom `ScopedGoRoute` wrapper (not standard `GoRoute`). Phase 3 planning must verify this wrapper works inside shell branches. If not, the 3 shell routes may need to use raw `GoRoute`.
- **BYOK tool calling format:** Pitfall 2 analysis concludes the BYOK path is independent of `fromJson`, but no integration test exists to prove this. Phase 2 must add one.
- **DELETE endpoint for coach/sync-insight/{id}:** The backend endpoint does not exist. Phase 2 must create it or the 5th URL fix is pointless.

## Sources

### Primary (HIGH confidence)
- Codebase inspection: api_service.dart, coach_chat_api_service.dart, document_service.dart, coach_memory_service.dart, coach_chat.py, config.py, main.py, Dockerfile, railway.json -- all line numbers verified
- `.planning/architecture/14-INFRA-AUDIT-FINDINGS.md` -- 32 findings with file/line references
- `feedback_facade_sans_cablage.md` -- documented #1 failure pattern
- `feedback_tests_green_app_broken.md` -- "9256 tests green, app broken" lesson

### Secondary (MEDIUM confidence)
- Railway Volumes docs (https://docs.railway.com/reference/volumes) -- persistence, mount path, runtime-only mount
- Railway HTTP timeout = 15 min (https://station.railway.com/questions/increase-max-http-timeout-1c360bf9) -- confirmed via Help Station
- GoRouter StatefulShellRoute pattern -- go_router package docs + community guides

### Tertiary (LOW confidence)
- Railway volume UID/permission behavior with non-root Docker users -- based on community reports, needs firsthand verification on staging deploy

---
*Research completed: 2026-04-12*
*Ready for roadmap: yes*
