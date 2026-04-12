# Feature Landscape — MINT v2.4 Fondation (Infrastructure Fixes)

**Domain:** Infrastructure repair for existing Flutter + FastAPI app
**Researched:** 2026-04-12
**Scope:** Fixing broken wiring between existing components. Zero new features.
**Confidence:** HIGH — patterns verified against actual codebase + standard Flutter/FastAPI conventions

> This is NOT a feature-add milestone. Every item below is an existing feature
> that is broken due to wiring, URL, serialization, navigation, or deployment
> issues. The 32 findings from `14-INFRA-AUDIT-FINDINGS.md` are the input.

---

## Table Stakes (Must Fix — App Non-Functional Without These)

Features users expect to work. Currently broken. Missing = app is unusable.

| Fix | What's Broken | Root Cause | Complexity | Phase | Audit ID |
|-----|---------------|------------|------------|-------|----------|
| URL prefix deduplication (5 endpoints) | Document scan, Vision OCR, premier eclairage, coach sync, insight delete all 404 | `baseUrl` already ends with `/api/v1`; 5 call sites append `/api/v1/...` again = double prefix | **Low** | 2 | P0-PIPE-1..5 |
| JSON key casing alignment | Tool calling silently dead — coach returns tools but Flutter ignores them | Backend Pydantic `alias_generator=to_camel` serializes `tool_calls` as `toolCalls`; Flutter reads `json['tool_calls']` (snake) | **Low** | 2 | P1-PIPE-1 |
| Shell navigation (3 tabs + drawer) | User trapped on single chat screen, no way to discover 67+ screens | Zero `StatefulShellRoute`, zero `BottomNavigationBar` in codebase despite specs | **High** | 3 | P0-NAV-1 |
| ProfileDrawer mounting | Profile, documents, settings, logout all inaccessible | Widget built (280 lines), zero imports anywhere, no `endDrawer` on any scaffold | **Low** | 3 | P0-NAV-2 |
| Back button loop fix | Back button on chat = infinite loop to same screen | `safePop` fallback is `/coach/chat` = same screen when stack empty | **Low** | 3 | P0-NAV-3 |
| RAG corpus persistence | Coach has no knowledge base — RAG empty after every deploy | ChromaDB `persist_directory` is relative path on ephemeral Railway filesystem; `education/inserts` path outside Docker build context | **Medium** | 1 | P0-INFRA-2 |
| SQLite fallback guard | Silent data loss if Railway env var missing | `DATABASE_URL` defaults to `sqlite:///./mint.db` in prod — ephemeral | **Low** | 1 | P0-INFRA-1 |
| Agent loop timeout | Coach 502 Bad Gateway on multi-turn tool calls | 3x Claude calls (20-30s each) exceed Railway 60s gateway timeout | **Medium** | 1 | P1-INFRA-1 |

---

## Differentiators (Important Fixes — App Degraded Without These)

Not immediately blocking, but severely degrade experience.

| Fix | What's Broken | Root Cause | Complexity | Phase | Audit ID |
|-----|---------------|------------|------------|-------|----------|
| safePop fallback routing | Back from any screen teleports to chat | 40 call sites all use `/coach/chat` as fallback | **Medium** | 3 | P1-NAV-1 |
| Zombie screen cleanup | 6 deleted screens still routable + renderable | Routes + files exist despite being marked deleted in docs | **Low** | 3 | P1-NAV-2 |
| Explorer hub wiring | 7 Explorer hubs all redirect to /coach/chat | Routes exist but bodies are redirects, not screens | **High** | 3 | P1-NAV-3 |
| /profile redirect fix | "Mon profil" in drawer dumps to chat | Route `/profile` exact match redirects to `/coach/chat` | **Low** | 3 | P0-NAV-4 |
| Remove api.mint.ch from URL candidates | +2s latency on every API call in production | Unresolvable DNS in URL candidate list | **Low** | 2 | P1-PIPE-2 |
| OPENAI_API_KEY validation | Embeddings silently fail = RAG degraded | Key required for embeddings but not in Settings model | **Low** | 1 | P1-INFRA-2 |
| Education inserts Docker path | RAG auto-ingest never finds files | Path `../../education/inserts` resolves outside Docker container | **Low** | 1 | P1-INFRA-3 |

---

## Anti-Features (Explicitly NOT Building in v2.4)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|--------------------|
| SSE streaming for coach | Adds complexity to a fix-only milestone; current sync works once timeout is fixed | Fix timeout with `asyncio.wait_for(50s)`. SSE is P3-PIPE-2, defer to v2.5+ |
| New Explorer hub screens | Navigation shell must exist first; building hub content is feature work | Wire Explorer routes to redirect to relevant existing screens (e.g., `/explore/retraite` -> `/retirement/overview`) |
| Multi-LLM support | Phase 3 roadmap item, not infrastructure | Keep Claude-only, fix the wiring that makes it work |
| CORS for Flutter Web | P2 priority; mobile is the only real user today | Note in P2 backlog, fix when web becomes a target |
| New navigation patterns (drawer gestures, animations) | Polish, not plumbing | Ship working tabs first, polish in next milestone |
| Coach personality/prompt improvements | Content, not infrastructure | Current prompts work; the pipe to deliver them is what's broken |

---

## Feature Dependencies (Fix Order Matters)

```
Phase 1 (Backend Infra) — no frontend dependencies
  P0-INFRA-1 (SQLite guard)        → standalone
  P0-INFRA-2 (RAG persistence)     → depends on P1-INFRA-3 (Docker path)
  P1-INFRA-1 (timeout)             → standalone
  P1-INFRA-2 (OpenAI key)          → standalone
  P1-INFRA-3 (education path)      → P0-INFRA-2 depends on this

Phase 2 (Front-Back Pipes) — depends on Phase 1 being deployed
  P0-PIPE-1..5 (URL double-prefix) → all same pattern, fix together
  P1-PIPE-1 (camelCase mismatch)   → standalone
  P1-PIPE-2 (DNS removal)          → standalone

Phase 3 (Navigation) — depends on Phase 2 (screens need working APIs)
  P0-NAV-1 (shell)                 → BLOCKS P0-NAV-2, P0-NAV-3, P1-NAV-1
  P0-NAV-2 (ProfileDrawer)         → depends on P0-NAV-1 (needs shell scaffold)
  P0-NAV-3 (back loop)             → depends on P0-NAV-1 (shell changes fallback)
  P1-NAV-1 (safePop 40 sites)      → depends on P0-NAV-1 (shell defines fallbacks)
  P0-NAV-4 (/profile redirect)     → standalone route fix
  P1-NAV-2 (zombie screens)        → standalone deletion
  P1-NAV-3 (Explorer hubs)         → depends on P0-NAV-1 (needs tab structure)

Phase 4 (Validation) — depends on all above
  End-to-end human walkthrough      → all fixes deployed
```

---

## Detailed Pattern Analysis for Each Fix Category

### 1. URL Prefix Management (P0-PIPE-1..5, P1-PIPE-2)

**Current bug:** `ApiService.baseUrl` guarantees the URL ends with `/api/v1` (see `_normalizeBaseUrl` at line 126-135 of `api_service.dart`). Five methods in `document_service.dart` and `coach_memory_service.dart` then append `/api/v1/...` again, producing `https://host/api/v1/api/v1/documents/...`.

**Standard pattern:** A central `baseUrl` that includes the API version prefix. All consumers use relative paths only:
```dart
// CORRECT: baseUrl = "https://host/api/v1"
Uri.parse('$baseUrl/documents/scan-confirmation')

// WRONG (current): double prefix
Uri.parse('$baseUrl/api/v1/documents/scan-confirmation')
```

**Fix scope:** 5 URLs in `document_service.dart` (lines 1086, 1125, 1169) and `coach_memory_service.dart` (lines 80, 106). Remove the `/api/v1` from each path string. Also remove `api.mint.ch` from `_baseUrlCandidates` (P1-PIPE-2).

**Confidence:** HIGH — verified in actual source code. The `_normalizeBaseUrl` function explicitly appends `/api/v1` if missing.

**Complexity:** Low. 5 string edits + 1 list removal. Risk: other call sites might also have the bug — grep for `/api/v1/` in all Flutter service files.

### 2. JSON Key Casing (P1-PIPE-1)

**Current bug:** Backend uses Pydantic v2 with `alias_generator=to_camel` (confirmed in `coach_chat.py` schema, line 30). Field `tool_calls` serializes as `toolCalls` in JSON responses. Flutter's `CoachChatApiResponse.fromJson` reads `json['tool_calls']` (line 130 of `coach_chat_api_service.dart`). Key does not exist. Tool calls silently dropped.

**Standard pattern in this codebase:** The backend convention is already established — Pydantic `to_camel` alias generator. Flutter should read camelCase keys from JSON:
```dart
// CORRECT: match backend's camelCase serialization
toolCalls: (json['toolCalls'] as List?) ...
tokensUsed: json['tokensUsed'] as int? ?? 0,
cashLevel: json['cashLevel'] as int? ?? 3,
```

**Fix scope:** `CoachChatApiResponse.fromJson` — change `tool_calls` to `toolCalls`, `tokens_used` to `tokensUsed`. Also audit all other `fromJson` factories that consume backend responses for the same mismatch.

**Confidence:** HIGH — Pydantic config confirmed at line 30 of schema, Flutter parse confirmed at line 130.

**Complexity:** Low for the fix itself. Medium for the audit — every `fromJson` in the Flutter codebase that consumes a backend Pydantic model needs checking.

### 3. Flutter Shell Navigation (P0-NAV-1, P0-NAV-2, P0-NAV-3)

**Current state:** 143 GoRouter routes defined in `app.dart`. Zero `ShellRoute` or `StatefulShellRoute`. The app is a flat list of routes with no persistent scaffold, no tab bar, no drawer mount point.

**Standard Flutter pattern:** `StatefulShellRoute.indexedStack` (GoRouter 10+) wraps child routes in a persistent scaffold with `BottomNavigationBar`. Each tab maintains its own `Navigator` stack. The shell scaffold provides the `endDrawer` mount point for `ProfileDrawer`.

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) => MintShell(
    navigationShell: navigationShell,
  ),
  branches: [
    StatefulShellBranch(routes: [/* Aujourd'hui routes */]),
    StatefulShellBranch(routes: [/* Coach routes */]),
    StatefulShellBranch(routes: [/* Explorer routes */]),
  ],
)
```

**Key decisions:**
- **3 branches** matching the spec: Aujourd'hui | Coach | Explorer
- **ProfileDrawer** as `endDrawer` on the shell scaffold (not per-screen)
- **indexedStack** (not default) to preserve tab state when switching
- **Back button**: shell root screens suppress back button; non-root screens pop within their branch

**Fix scope:** Major refactor of `app.dart`. All 143 routes need re-parenting under the shell or marked as full-screen overlays. `safePop` fallback logic changes from hardcoded `/coach/chat` to branch-aware navigation.

**Confidence:** HIGH — `StatefulShellRoute.indexedStack` is the documented GoRouter pattern for persistent tab navigation.

**Complexity:** High. This is the largest single fix. Touches every route, changes the scaffold hierarchy, requires testing all 67+ screens still render correctly under the new shell.

### 4. RAG Corpus Deployment (P0-INFRA-2, P1-INFRA-3)

**Current bug:** Two compounding issues:
1. `education/inserts` path (`../../education/inserts` relative to backend dir) resolves outside the Docker build context. The Dockerfile `COPY . .` copies `services/backend/` contents, not the repo root.
2. ChromaDB `persist_directory` is a relative path (`data/chromadb`) on Railway's ephemeral filesystem. Lost on every deploy.

**Standard patterns (two viable approaches):**

**Option A — Embed in Docker image (recommended for MINT's scale):**
```dockerfile
# Add to Dockerfile before COPY . .
COPY education/inserts /app/education/inserts
```
Adjust the Docker build context or use a multi-stage copy. Fix the path in `main.py` to `/app/education/inserts`. ChromaDB rebuilds from these files on each startup (acceptable for ~103 education docs).

**Option B — Railway persistent volume:**
Mount a Railway volume at `/data/chromadb`. Only re-ingest when corpus changes. Better for large corpora but adds infrastructure dependency.

**Recommendation:** Option A. The corpus is ~103 documents. Rebuilding on startup takes seconds. No external volume dependency. The Dockerfile already does `COPY . .` from the backend dir; the fix is to also copy `education/inserts` into the image (requires adjusting the Docker build context in the CI/CD pipeline or the `railway.json`).

**Confidence:** HIGH for Option A pattern. MEDIUM for Railway volume specifics (Railway docs confirm persistent volumes exist but exact mount syntax depends on their current API).

**Complexity:** Medium. Requires changes to Dockerfile, possibly `railway.json` or GitHub Actions build context, and the path resolution in `main.py`.

### 5. Backend Timeout / Agent Loop (P1-INFRA-1)

**Current bug:** Coach chat endpoint runs up to 3 Claude API calls sequentially (agent loop: tool_use -> execute -> re-call). Each call takes 20-30s. Total can exceed Railway's 60s gateway timeout, resulting in 502.

**Standard pattern:** `asyncio.wait_for()` with a total deadline below the gateway timeout:
```python
async def _run_agent_loop(...):
    try:
        result = await asyncio.wait_for(
            _agent_loop_inner(...),
            timeout=50.0  # 10s buffer before Railway's 60s
        )
    except asyncio.TimeoutError:
        return _graceful_timeout_response(partial_result)
```

**Key detail:** The timeout must wrap the ENTIRE agent loop, not individual calls. A per-call timeout of 25s still allows 3x25s=75s total. The fix is a single `wait_for` around the outer loop with a 50s budget, returning whatever partial result exists if time runs out.

**Alternative (future, not v2.4):** SSE streaming eliminates the timeout problem entirely — Railway doesn't timeout streaming responses the same way. But SSE is a feature add, not a fix. Defer to P3-PIPE-2.

**Confidence:** HIGH — `asyncio.wait_for` is standard Python. Railway 60s timeout is documented.

**Complexity:** Medium. Need to capture partial results (the text generated before the timeout) and return them gracefully instead of a 502.

---

## MVP Recommendation (v2.4 Scope)

**Phase 1 — Backend Infra (2-3 days):**
1. SQLite fallback guard (P0-INFRA-1) — 30 min
2. Education inserts Docker path fix (P1-INFRA-3) — 2 hours
3. RAG corpus persistence via embedded Docker (P0-INFRA-2) — 2 hours (depends on #2)
4. OpenAI API key validation (P1-INFRA-2) — 30 min
5. Agent loop timeout (P1-INFRA-1) — 3 hours

**Phase 2 — Front-Back Pipes (2-3 days):**
1. URL double-prefix fix, all 5 endpoints (P0-PIPE-1..5) — 1 hour
2. JSON casing alignment (P1-PIPE-1) — 1 hour + 2 hours audit of other fromJson
3. Remove api.mint.ch DNS (P1-PIPE-2) — 15 min

**Phase 3 — Navigation (5-7 days):**
1. StatefulShellRoute + 3 tabs (P0-NAV-1) — 3-4 days (largest item)
2. Mount ProfileDrawer as endDrawer (P0-NAV-2) — 2 hours (after shell exists)
3. Fix back button loop (P0-NAV-3) — 1 hour (after shell exists)
4. Fix /profile redirect (P0-NAV-4) — 15 min
5. safePop branch-aware fallbacks (P1-NAV-1) — 4 hours
6. Delete zombie screens (P1-NAV-2) — 1 hour
7. Wire Explorer hub redirects (P1-NAV-3) — 2 hours

**Phase 4 — Validation (3-5 days, human):**
End-to-end walkthrough on real iPhone. The ONLY gate that matters per project memory: "creator-device, mandatory, non-skippable."

**Defer:** SSE streaming (P3-PIPE-2), CORS for web (P2-INFRA-2), legacy redirect cleanup (P2-NAV-1).

---

## Sources

- **Codebase verified:** All findings confirmed by reading actual source files (api_service.dart, coach_chat_api_service.dart, document_service.dart, coach_chat.py, coach_chat schema, Dockerfile, main.py)
- **14-INFRA-AUDIT-FINDINGS.md:** 32 findings from 3 parallel audits (2026-04-12)
- **GoRouter StatefulShellRoute:** Standard Flutter navigation pattern (go_router package docs)
- **Pydantic v2 alias_generator:** Confirmed in codebase schema (`alias_generator=to_camel`, `populate_by_name=True`)
- **Railway deployment:** Ephemeral filesystem documented; persistent volumes available
- **asyncio.wait_for:** Python stdlib, standard timeout pattern
