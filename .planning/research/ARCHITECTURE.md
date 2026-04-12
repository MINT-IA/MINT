# Architecture Patterns — v2.4 Fondation (Infrastructure Recovery)

**Domain:** Infrastructure fix across Flutter + FastAPI app with broken pipes
**Researched:** 2026-04-12
**Scope:** 4-phase integration plan to fix backend infra, front-back connections, navigation shell, and end-to-end validation on an existing 143-route GoRouter + Railway-deployed FastAPI backend.

---

## Current Architecture State (Evidence-Based)

### Backend (FastAPI on Railway)
- **Deploy**: Dockerfile multi-stage build, gunicorn + uvicorn workers, Railway auto-deploy
- **DB**: PostgreSQL (Railway) with dangerous SQLite fallback in `config.py:17`
- **RAG**: ChromaDB with `persist_directory` at `services/backend/data/chromadb/` (relative path, ephemeral on Railway)
- **Education corpus**: path `../../education/inserts` resolves outside Docker context — corpus always empty post-deploy
- **Router**: FastAPI `api_router` mounted at `/api/v1` via `app.include_router(api_router, prefix=settings.API_V1_STR)`
- **Agent loop**: 5 max iterations, 8000 token budget, NO asyncio timeout — can exceed Railway's implicit gateway timeout
- **Gunicorn timeout**: 120s (railway.json), but Railway's reverse proxy likely cuts at 60s for HTTP

### Frontend (Flutter)
- **API base**: `ApiService.baseUrl` = `https://mint-production-3a41.up.railway.app/api/v1` — already includes `/api/v1`
- **5 broken services**: `document_service.dart` and `coach_memory_service.dart` build URLs as `$baseUrl/api/v1/...` = double prefix
- **Tool call parsing**: `coach_chat_api_service.dart:130` reads `json['tool_calls']` (snake_case), backend sends `toolCalls` (camelCase via Pydantic alias)
- **Router**: 143 flat `ScopedGoRoute` entries, zero `ShellRoute` or `StatefulShellRoute`, zero `BottomNavigationBar`
- **Navigation fallback**: `safePop()` goes to `/coach/chat` when stack is empty — traps users in infinite loop
- **ProfileDrawer**: 280-line widget in `widgets/profile_drawer.dart`, zero imports anywhere

### Integration Points Map

```
Flutter App
  |
  +-- ApiService.baseUrl = "https://.../api/v1"
  |     |
  |     +-- ApiService.get("/endpoint")    --> "$baseUrl/endpoint"   = CORRECT
  |     +-- ApiService.post("/endpoint")   --> "$baseUrl/endpoint"   = CORRECT
  |     |
  |     +-- document_service.dart (direct http)
  |     |     +-- "$baseUrl/api/v1/documents/..."  = DOUBLE PREFIX (404)
  |     |
  |     +-- coach_memory_service.dart (direct http)
  |           +-- "$baseUrl/api/v1/coach/..."      = DOUBLE PREFIX (404)
  |
  +-- CoachChatApiService
  |     +-- Reads json['tool_calls']  --> Backend sends json['toolCalls']  = MISMATCH
  |
  +-- GoRouter (143 flat routes)
        +-- No ShellRoute wrapper
        +-- safePop fallback = /coach/chat (loop)
        +-- ProfileDrawer never mounted
        +-- 7 Explorer hubs all redirect to /coach/chat
```

---

## Recommended Architecture: 4-Phase Integration

### Phase Dependency Graph

```
Phase 1 (Backend Infra)
    |
    v
Phase 2 (Front-Back Connections)   <-- Depends on Phase 1: backend must be stable
    |
    v
Phase 3 (Navigation Shell)         <-- Depends on Phase 2: routes must work before shell wraps them
    |
    v
Phase 4 (Validation)               <-- Depends on all: E2E proof
```

**This order is the ONLY safe order.** Rationale:
1. If backend crashes (SQLite fallback, empty RAG, agent timeout), fixing Flutter URLs is pointless — you get 500s instead of 404s.
2. If URLs 404, building a shell around them creates a polished cage with dead endpoints.
3. If navigation works but backend is broken, E2E validation will fail on every path.

---

## Phase 1 — Les Tuyaux (Backend Infrastructure)

### Component: SQLite Fail-Fast Guard

**Where:** `services/backend/app/core/config.py`
**What:** Add startup guard after `settings = Settings()`.
**Integration risk:** LOW. Pure additive. No existing behavior changes in dev mode.

```python
# After settings = Settings() and before JWT check
if (
    os.getenv("ENVIRONMENT", "development") in ("production", "staging")
    and settings.DATABASE_URL.startswith("sqlite")
):
    raise RuntimeError(
        "CRITICAL: DATABASE_URL is SQLite in production/staging. "
        "Set DATABASE_URL to a PostgreSQL connection string."
    )
```

**Affects:** Only production/staging deploy. Dev keeps SQLite for local testing.
**Test:** Unit test that config raises in staging+sqlite, passes in staging+postgres, passes in dev+sqlite.

### Component: ChromaDB Persistence Fix

**Where:** `services/backend/app/main.py:214-229` + `Dockerfile`
**Problem:** Two issues stacked:
1. `persist_directory` = `services/backend/data/chromadb/` — ephemeral on Railway (filesystem resets on deploy)
2. Education inserts at `../../education/inserts` — outside Docker build context

**Fix strategy (ordered by reliability):**

**Option A (recommended): Copy education/ into Docker + Railway volume mount**
- Dockerfile: `COPY education/ /app/education/` (add to build context by adjusting Dockerfile path or copying during build)
- `main.py`: Change inserts_dir to `/app/education/inserts`
- Railway: Mount persistent volume at `/app/data/chromadb` (Railway dashboard > Service > Volumes)
- `main.py`: Use env var `CHROMADB_PERSIST_DIR` defaulting to `os.path.join(backend_dir, "data", "chromadb")`

**Option B (simpler, less durable): Pre-deploy script ingestion**
- Add ChromaDB ingest to `scripts/railway_pre_deploy_migrate.py`
- Still needs volume mount for persistence

**Integration risk:** MEDIUM. Requires Railway dashboard change (volume mount). Must verify Docker build context includes `education/` directory.

**Critical path:**
1. Adjust Dockerfile to copy education inserts
2. Add `CHROMADB_PERSIST_DIR` env var to Settings
3. Mount Railway persistent volume
4. Verify auto-ingest runs on first deploy, skips on subsequent deploys

### Component: Agent Loop Timeout

**Where:** `services/backend/app/api/v1/endpoints/coach_chat.py:929-1105`
**Problem:** `_run_agent_loop` has iteration and token limits but NO wall-clock timeout. Railway's reverse proxy cuts at ~60s, returning 502 to user.
**Gunicorn timeout:** 120s (railway.json). But Railway gateway is the bottleneck.

**Fix:** Wrap the agent loop call in `asyncio.wait_for()`:

```python
# In the chat endpoint, around line 1268:
import asyncio
try:
    loop_result = await asyncio.wait_for(
        _run_agent_loop(...),
        timeout=50.0  # 50s < Railway's 60s gateway timeout
    )
except asyncio.TimeoutError:
    # Return a graceful partial response
    loop_result = {
        "answer": "Je n'ai pas pu terminer ma reflexion dans le temps imparti. Peux-tu reformuler ta question plus simplement ?",
        "tool_calls": [],
        "sources": [],
        "disclaimers": [],
        "tokens_used": 0,
    }
```

**Integration risk:** LOW. Wraps existing async function. No behavior change when fast. Graceful degradation when slow.

### Component: OPENAI_API_KEY in Settings

**Where:** `services/backend/app/core/config.py`
**Problem:** `insight_embedder.py:49-50` uses `OPENAI_API_KEY` for ChromaDB embeddings but it is not in Settings.
**Fix:** Add `OPENAI_API_KEY: str = ""` to Settings + startup warning if RAG is available but key is missing.
**Integration risk:** LOW. Additive field.

### Component: Education Inserts Docker Path

**Where:** `services/backend/Dockerfile` + `services/backend/app/main.py:217-219`
**Current Dockerfile context:** `COPY . .` in stage 2 copies the `services/backend/` directory content. Education inserts are at `MINT/education/inserts/` — two directories up, outside the Docker build context.

**Fix:** Either:
1. Change Docker build context to repo root (affects all COPY paths)
2. Add a `COPY --from=... education/` step using build args
3. (Recommended) Add a pre-build script that copies `education/inserts/` into `services/backend/education_corpus/` before Docker build, and update `main.py` path

**Integration risk:** MEDIUM. Docker build context change can have cascading effects. Option 3 is safest.

---

## Phase 2 — Les Connexions (Front-Back Wiring)

### Component: URL Double-Prefix Fix (5 locations)

**Where:** 3 in `document_service.dart`, 2 in `coach_memory_service.dart`
**Root cause:** These services bypass `ApiService.get()/post()` and build URLs directly using `ApiService.baseUrl` + hardcoded `/api/v1/...`.
**The central `ApiService` methods already work correctly** — they do `$baseUrl$endpoint` where endpoint is `/documents/...` without prefix.

**Fix pattern (identical for all 5):**

| File | Line | Current | Fixed |
|------|------|---------|-------|
| document_service.dart | 1086 | `'$baseUrl/api/v1/documents/scan-confirmation'` | `'$baseUrl/documents/scan-confirmation'` |
| document_service.dart | 1125 | `'$baseUrl/api/v1/documents/extract-vision'` | `'$baseUrl/documents/extract-vision'` |
| document_service.dart | 1169 | `'$baseUrl/api/v1/documents/premier-eclairage'` | `'$baseUrl/documents/premier-eclairage'` |
| coach_memory_service.dart | 80 | `'$baseUrl/api/v1/coach/sync-insight'` | `'$baseUrl/coach/sync-insight'` |
| coach_memory_service.dart | 106 | `'$baseUrl/api/v1/coach/sync-insight/$insightId'` | `'$baseUrl/coach/sync-insight/$insightId'` |

**Risk of breaking existing working paths:** ZERO for these 5. They are currently producing 404s. There are no working paths to break. The fix makes them match the pattern used by ALL other services that go through `ApiService.get()/post()`.

**Verify after fix:** Confirm `ApiService.baseUrl` ends with `/api/v1` (it does: line 109-111 of api_service.dart). The fixed paths append `/documents/...` to that base, producing the correct full URL `https://.../api/v1/documents/scan-confirmation`.

**Additional fix needed (P0-PIPE-5):** Backend endpoint `DELETE /coach/sync-insight/{id}` does not exist. Must be created in `services/backend/app/api/v1/endpoints/coach_chat.py` or a new `coach.py` endpoint.

**Integration risk:** LOW for URL fixes. MEDIUM for new DELETE endpoint (requires backend route + handler + test).

### Component: camelCase Mismatch Fix

**Where:** `apps/mobile/lib/services/coach/coach_chat_api_service.dart:130`
**Current:** `json['tool_calls']` — key does not exist in backend response
**Backend sends:** `toolCalls` (Pydantic v2 with `alias_generator = to_camel`)

**Fix:**
```dart
// Line 130: Change from
toolCalls: (json['tool_calls'] as List?)
// To
toolCalls: (json['toolCalls'] as List?)
```

**Risk of breaking existing working paths:** NONE. The current code silently returns empty list because `json['tool_calls']` is always null. The fix reads the actual data.

**Broader concern:** Check all other JSON deserialization in coach services for the same pattern. The backend consistently uses camelCase aliases. Any Flutter code expecting snake_case from the backend is broken.

**Integration risk:** LOW. One-line change. Currently broken, cannot make it worse.

### Component: DNS Cleanup

**Where:** `apps/mobile/lib/services/api_service.dart:110`
**Current:** `api.mint.ch/api/v1` is in URL candidates. DNS does not resolve. Adds 2s latency during URL probing.
**Fix:** Remove from candidates until DNS is configured. Keep Railway URLs only.
**Integration risk:** LOW. Removes a timeout, does not change behavior.

---

## Phase 3 — La Navigation (Shell Architecture)

### Component: StatefulShellRoute Integration

**This is the highest-risk phase.** The router has 143 routes, all flat (no nesting). Adding a shell requires wrapping a subset of routes while preserving all deep links.

**Strategy: Additive wrapping, not restructuring.**

```dart
// NEW: Shell wraps 3 tab destinations
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) => MintShell(
    navigationShell: navigationShell,
  ),
  branches: [
    // Tab 0: Aujourd'hui (home/dashboard)
    StatefulShellBranch(
      routes: [
        ScopedGoRoute(
          path: '/home',
          builder: (context, state) => const TodayScreen(),
        ),
      ],
    ),
    // Tab 1: Coach (chat)
    StatefulShellBranch(
      navigatorKey: _coachNavigatorKey,
      routes: [
        ScopedGoRoute(
          path: '/coach/chat',
          scope: RouteScope.public,
          builder: (context, state) => CoachChatScreen(...),
        ),
        // Sub-routes under coach tab
        ScopedGoRoute(
          path: '/coach/history',
          builder: (context, state) => const ConversationHistoryScreen(),
        ),
      ],
    ),
    // Tab 2: Explorer
    StatefulShellBranch(
      routes: [
        ScopedGoRoute(
          path: '/explore',
          builder: (context, state) => const ExplorerScreen(),
        ),
      ],
    ),
  ],
),

// ALL existing routes STAY as top-level routes (outside shell)
// They navigate using _rootNavigatorKey and overlay the shell
ScopedGoRoute(
  path: '/retraite',
  parentNavigatorKey: _rootNavigatorKey,
  builder: ...,
),
// ... (all 130+ other routes unchanged)
```

**Critical migration rules:**
1. **DO NOT move existing routes into shell branches** — only `/home`, `/coach/chat`, `/coach/history`, and `/explore` go inside the shell
2. **All other routes keep `parentNavigatorKey: _rootNavigatorKey`** — they push over the shell as full-screen overlays
3. **Deep links continue to work** because GoRouter resolves paths globally, shell or not
4. **The shell only provides persistent bottom navigation** — it does not change route resolution

**ProfileDrawer integration:**
- `MintShell` scaffold includes `endDrawer: const ProfileDrawer()`
- Icon button in AppBar opens it via `Scaffold.of(context).openEndDrawer()`
- No route change needed — drawer is a scaffold feature, not a route

**safePop fix:**
```dart
void safePop(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home'); // NOT /coach/chat — go to shell root
  }
}
```

**Explorer hubs:**
- Replace 7 redirect-to-chat routes with actual `/explore/*` sub-routes
- Each hub is a simple list screen that links to existing tool/simulator routes
- If building hub screens is too costly for this phase, redirect to `/explore` (not `/coach/chat`)

**Zombie screen cleanup:**
- Delete files + routes for: achievements, score_reveal, cockpit, annual_refresh (if truly dead), portfolio, ask_mint
- Add redirects: `/achievements` -> `/home`, `/ask-mint` -> `/coach/chat`, etc.

**Integration risk:** HIGH. GoRouter StatefulShellRoute has specific constraints:
- Shell branches must have unique paths
- `initialLocation` must point to a shell branch path
- Auth redirect logic must account for shell routes
- Tab state persistence across navigation

**Mitigation:** Build shell in isolation first. Wire one branch at a time. Test deep links after each branch addition. Keep all non-shell routes completely unchanged.

### Data Flow After Shell

```
User opens app
  --> GoRouter resolves '/' (landing) or '/home' (if logged in)
  --> MintShell renders with 3 tabs
      |
      Tab 0: TodayScreen (dashboard, cards, recent insights)
      Tab 1: CoachChatScreen (chat + tool calling + document upload)
      Tab 2: ExplorerScreen (7 hubs linking to tool screens)
      |
      Tapping a tool/simulator link:
        --> context.go('/retraite') or context.push('/retraite')
        --> Route resolves with _rootNavigatorKey
        --> Full-screen overlay above shell
        --> Back button / safePop returns to shell
      |
      ProfileDrawer (endDrawer):
        --> Profile, Documents, Settings, Logout
        --> Opened via icon button, not a route
```

---

## Phase 4 — La Preuve (Validation Architecture)

### E2E Flows That Must Pass

| # | Flow | Touches | Gate |
|---|------|---------|------|
| 1 | Cold start -> landing -> register -> chat | Auth, Router, Backend health | User sees chat with greeting |
| 2 | Type question -> get coach response | Coach chat, API, Agent loop, RAG | Response in < 10s, no 502 |
| 3 | Upload document -> scan -> extraction -> premier eclairage | Document service, Vision OCR, 4-layer insight | All 4 layers render |
| 4 | Navigate tabs (Today/Coach/Explorer) | Shell, BottomNav, tab persistence | Tabs work, state preserved |
| 5 | Open ProfileDrawer -> view profile -> close | Drawer, profile screen | Profile data visible |
| 6 | Deep link `/retraite` -> back -> shell | GoRouter, safePop, shell | Returns to shell, not loop |
| 7 | Tool call in chat -> navigate to screen | camelCase fix, tool_call_parser | Screen opens from chat suggestion |
| 8 | Background + foreground -> chat state preserved | Provider state, conversation persistence | Messages still visible |

### Validation Method
- **NOT flutter test** (9256 tests pass, app is broken)
- **Device walkthrough**: `flutter run --release` on iPhone, connected to staging backend
- Creator (Julien) performs each flow cold-start, annotates screenshots
- Any flow failure = milestone not complete

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Fixing URLs in bulk with find-replace
**What:** Global replacement of `/api/v1/` across all Dart files
**Why bad:** `ApiService.get("/documents/...")` already works correctly. Only the 5 direct-http calls are broken. A global replace would BREAK the working paths.
**Instead:** Fix only the 5 identified locations. Verify each one individually.

### Anti-Pattern 2: Restructuring all 143 routes into shell branches
**What:** Moving every route inside StatefulShellRoute branches
**Why bad:** GoRouter shell branches expect their routes to share a navigator. Tool screens (simulators, deep dives) should push OVER the shell, not inside it.
**Instead:** Only 3-4 routes go inside shell branches. Everything else stays top-level with `parentNavigatorKey: _rootNavigatorKey`.

### Anti-Pattern 3: Adding Railway volume mount without testing persistence
**What:** Configuring ChromaDB persist_directory and assuming it survives deploys
**Why bad:** Railway volumes must be explicitly mounted. The directory must exist before ChromaDB writes. Permission issues with non-root user.
**Instead:** Test with a deploy cycle: write data -> redeploy -> verify data persists.

### Anti-Pattern 4: Changing initialLocation before shell is stable
**What:** Setting `initialLocation: '/home'` before the TodayScreen and shell exist
**Why bad:** GoRouter will crash if initialLocation points to a route inside a shell that is not fully configured.
**Instead:** Keep `initialLocation: '/'` until shell is proven stable. Add `/` -> `/home` redirect only after shell works.

---

## Scalability Considerations

| Concern | Current (broken) | After v2.4 (fixed) | Future (v3.0+) |
|---------|-------------------|---------------------|-----------------|
| RAG corpus | Empty (ephemeral) | 103 education docs persisted | User documents + conversations |
| Agent loop | No timeout, 502s | 50s timeout, graceful fallback | SSE streaming (P3-PIPE-2) |
| Navigation | 143 flat routes, no shell | Shell + 3 tabs + drawer | Dynamic routes from coach |
| Tool calling | Dead (camelCase) | Working for server-key path | All 3 tiers (SLM/BYOK/server) |
| URL construction | Mixed patterns, 5 broken | Consistent via ApiService | OpenAPI-generated client |

---

## Component Boundaries

| Component | Responsibility | Communicates With | Phase |
|-----------|---------------|-------------------|-------|
| `config.py` | Environment validation, fail-fast guards | App startup | 1 |
| `main.py` lifespan | DB check, RAG auto-ingest | ChromaDB, education corpus | 1 |
| `coach_chat.py` _run_agent_loop | LLM orchestration with timeout | Anthropic API, RAG | 1 |
| `Dockerfile` | Build context, education corpus inclusion | Railway deploy | 1 |
| `document_service.dart` (3 methods) | Document scan/extract/insight HTTP calls | Backend `/documents/*` | 2 |
| `coach_memory_service.dart` (2 methods) | Insight sync HTTP calls | Backend `/coach/*` | 2 |
| `coach_chat_api_service.dart` | JSON deserialization of coach response | Backend `/coach/chat` | 2 |
| `api_service.dart` | URL candidate list | Railway endpoints | 2 |
| `app.dart` GoRouter | Route resolution, shell structure | All screens | 3 |
| `MintShell` (new) | Persistent bottom nav + drawer scaffold | GoRouter, ProfileDrawer | 3 |
| `safePop()` | Back navigation fallback | GoRouter | 3 |
| `ExplorerScreen` (new) | Hub linking to tool screens | GoRouter | 3 |

---

## Sources

- **Evidence from codebase**: All findings verified by direct file inspection (2026-04-12 audit)
- **Railway deployment**: `services/backend/railway.json` — gunicorn 120s timeout, Dockerfile builder
- **GoRouter StatefulShellRoute**: go_router package documentation (verified pattern for additive shell wrapping)
- **ChromaDB persistence**: ChromaDB docs — `persist_directory` must exist and be writable
- **Pydantic v2 aliases**: Backend uses `alias_generator = to_camel` confirmed in CLAUDE.md and code patterns
