# Technology Stack — v2.4 Fondation Infrastructure Fixes

**Project:** MINT v2.4 Fondation
**Researched:** 2026-04-12
**Confidence:** HIGH on all 7 items (verified against Railway docs, GoRouter docs, actual codebase)
**Scope rule:** Infrastructure FIXES only. Zero new dependencies. Zero version bumps. All fixes are configuration and code patterns using the existing stack.

---

## TL;DR — What to fix, what NOT to touch

| Fix | New Dep? | Version Change? | Config Change? |
|-----|----------|-----------------|----------------|
| 1. ChromaDB persistence | No | No | Railway volume + env var |
| 2. Education corpus in Docker | No | No | Dockerfile + Railway root dir |
| 3. Agent loop timeout | No | No | Code change only |
| 4. StatefulShellRoute (tabs) | No | No (go_router ^13.2.0 sufficient) | Code change only |
| 5. URL double-prefix (5x 404) | No | No | Code change only |
| 6. camelCase mismatch | No | No | Code change only |
| 7. SQLite fail-fast | No | No | Code change only |

**Net new dependencies on running app: ZERO.**

---

## 1. ChromaDB Persistence on Railway

### Problem
ChromaDB `persist_directory` is a relative path (`data/chromadb`) on Railway's ephemeral filesystem. Every deploy wipes the RAG corpus. 43 education files must be re-ingested each time, and user-uploaded document embeddings are permanently lost.

### Solution: Railway Persistent Volume

**Railway Volume Configuration** (via Railway Dashboard > Service > Volumes > Add Volume):
- Mount path: `/data/chromadb`
- Railway auto-injects `RAILWAY_VOLUME_MOUNT_PATH` env var at runtime
- Volume survives deploys and restarts (48-hour recovery grace period on deletion)
- Single volume per service (Railway limitation — sufficient for our use case)

**Critical constraint:** Volumes mount at **runtime, NOT during build**. Pre-deploy scripts cannot write to the volume. The existing auto-ingest in `main.py:215-239` already runs at app startup — this is the correct pattern, no change needed there.

**Config change in `config.py`:**
```python
# Add to Settings class
CHROMADB_PERSIST_DIR: str = "/data/chromadb"  # Railway volume mount point; dev uses default
```

**Code change in `main.py` (line ~215):**
```python
# Replace:
persist_dir = os.path.join(backend_dir, "data", "chromadb")
# With:
from app.core.config import settings
persist_dir = settings.CHROMADB_PERSIST_DIR
```

**Docker permission fix:** The Dockerfile runs as non-root user `mint`. Railway volumes mount as root. Set env var `RAILWAY_RUN_UID=0` in Railway dashboard. This is Railway's documented solution for non-root Docker images with volumes.

| Decision | Recommendation | Why |
|----------|---------------|-----|
| Volume vs separate ChromaDB service | Volume | Simpler ops for small corpus (~43 files + user docs). Separate service only warranted at >100k vectors. |
| Volume mount path | `/data/chromadb` | Outside `/app` to avoid conflicts with code deploys |
| `RAILWAY_RUN_UID` | `0` | Required for non-root Docker images. Railway's single-tenant container model makes this acceptable. |

**Confidence:** HIGH — Railway docs explicitly describe this pattern. Railway's ChromaDB deploy templates use this exact approach.

---

## 2. Education Corpus in Docker Image

### Problem
`main.py:217-219` looks for education inserts at `../../education/inserts` relative to the backend dir. In Docker (WORKDIR=/app), this resolves to a path outside the container. The `education/` directory is at repo root, outside the Docker build context (`services/backend/`).

### Solution: Expand Docker Build Context to Repo Root

**Change Railway's Root Directory to `/`** (repo root) via Railway Dashboard > Service > Settings > Source > Root Directory.

**Update `railway.json`:**
```json
{
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "services/backend/Dockerfile"
  },
  "deploy": {
    "startCommand": "sh -c 'python scripts/railway_pre_deploy_migrate.py && gunicorn app.main:app -w 2 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:${PORT:-8080} --timeout 120 --access-logfile - --error-logfile -'",
    "healthcheckPath": "/api/v1/health",
    "healthcheckTimeout": 15,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3
  }
}
```

**Update Dockerfile (key changes only — full file in Phase 1 plan):**
```dockerfile
# Stage 1: Builder (build context is now repo root)
COPY services/backend/pyproject.toml .
COPY services/backend/app/ app/
RUN pip install --no-cache-dir ".[rag]"

# Stage 2: Production
COPY services/backend/ .
COPY education/inserts/ /app/education/inserts/
COPY services/backend/scripts/ /app/scripts/
COPY services/backend/alembic/ /app/alembic/
COPY services/backend/alembic.ini /app/alembic.ini
```

**Update `main.py` inserts path:**
```python
# Replace ../../education/inserts with path relative to /app
inserts_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "education", "inserts")
# Resolves to /app/education/inserts/ in Docker (WORKDIR=/app, __file__=/app/app/main.py)
```

### Alternatives Considered

| Option | Verdict | Why |
|--------|---------|-----|
| Expand build context to repo root | **CHOSEN** | Idiomatic Docker. Clean. No extra scripts. |
| Pre-build copy script | Reject | Railway has no pre-build hook. Fragile. |
| Embed corpus in Python package | Reject | Overcomplicated for 43 markdown files. |
| Download from S3 at startup | Reject | Adds AWS dependency. Files are in the repo. |

**Confidence:** HIGH — standard Docker multi-stage pattern.

---

## 3. Agent Loop Timeout Handling

### Problem
`_run_agent_loop` (coach_chat.py:929) can make up to 5 sequential Claude API calls (each 20-30s). No total deadline exists. The finding P1-INFRA-1 claims "Railway 60s timeout" but this is **incorrect** — Railway's actual HTTP timeout is **15 minutes** (confirmed via Railway Help Station: "any limit that is lower than that would be a self imposed limit at the application level"). The real constraints are:

1. **Gunicorn worker timeout: 120s** — already configured in `railway.json`, sufficient
2. **No explicit total deadline on the agent loop** — could exceed 120s on 5 iterations
3. **UX ceiling: ~60s** — user waiting >60s for chat response assumes the app is broken

### Solution: asyncio.wait_for() Deadline Pattern

**Wrap the agent loop call with a total deadline:**
```python
import asyncio

AGENT_LOOP_DEADLINE_SECONDS = 55  # Leave margin for response serialization

async def coach_chat_endpoint(...):
    try:
        result = await asyncio.wait_for(
            _run_agent_loop(...),
            timeout=AGENT_LOOP_DEADLINE_SECONDS,
        )
    except asyncio.TimeoutError:
        result = {
            "answer": "Je n'ai pas pu terminer ma recherche dans le temps imparti. "
                      "Repose ta question, je serai plus rapide.",
            "tool_calls": [],
            "sources": [],
            "disclaimers": [],
            "tokens_used": 0,
            "timed_out": True,
        }
```

**Per-iteration timeout within the loop (coach_chat.py ~line 992):**
```python
for iteration in range(MAX_AGENT_LOOP_ITERATIONS):
    try:
        result = await asyncio.wait_for(
            orchestrator.query(...),
            timeout=25,  # Per-call cap
        )
    except asyncio.TimeoutError:
        logger.warning("Agent iteration %d timed out for user %s", iteration, user_id)
        break  # Return partial answer
```

**Reduce MAX_AGENT_LOOP_ITERATIONS from 5 to 3:**
- 3 iterations x 25s max = 75s theoretical max, but early-exit on end_turn typically completes in 1-2 iterations
- Combined with the 55s total deadline, this prevents runaway loops

| Setting | Current | Recommended | Why |
|---------|---------|-------------|-----|
| Gunicorn --timeout | 120s | 120s (keep) | Covers full request lifecycle with margin |
| Agent loop total deadline | None | 55s | UX ceiling: user perceives >60s as broken |
| Per-iteration timeout | None | 25s | One hung API call doesn't consume all time |
| MAX_AGENT_LOOP_ITERATIONS | 5 | 3 | 3 iterations is enough for tool use + response |

**No infrastructure changes needed.** Railway's 15-minute timeout and Gunicorn's 120s timeout are both adequate. The fix is purely in application code.

**Confidence:** HIGH — Railway 15-min limit confirmed from their Help Station. asyncio.wait_for is standard Python stdlib.

---

## 4. Flutter StatefulShellRoute (Persistent Tabs)

### Problem
Zero shell exists in `app.dart`. All 143 routes are top-level `GoRoute`. No `BottomNavigationBar`, no tabs, no persistent navigation. User is trapped on a single chat screen with no visible way to discover 67+ screens.

### Solution: StatefulShellRoute.indexedStack

**Current go_router version: `^13.2.0`** — `StatefulShellRoute` is available since go_router 7.0+. No version bump needed.

**Architecture:**
```
StatefulShellRoute.indexedStack
  |-- Branch 0: Aujourd'hui (/home)
  |-- Branch 1: Coach (/coach/chat)
  |-- Branch 2: Explorer (/explorer)
  
All other routes: top-level GoRoute with parentNavigatorKey: _rootNavigatorKey
  (auth, onboarding, simulators, deep screens = full-screen overlays)
```

**Shell widget (MintShell):**
```dart
class MintShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MintShell({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      endDrawer: const ProfileDrawer(),  // Fixes P0-NAV-2
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: "Aujourd'hui"),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Coach'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Explorer'),
        ],
      ),
    );
  }
}
```

**Router integration pattern:**
```dart
final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/coach/chat',  // Coach is the center of gravity
  routes: [
    // Auth routes (outside shell, no bottom nav)
    GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    // ... other auth routes

    // THE SHELL (3 tabs with persistent state)
    StatefulShellRoute.indexedStack(
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state, navigationShell) {
        return MintShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/coach/chat',
            builder: (_, __) => const CoachChatScreen(),
            routes: [
              GoRoute(path: 'history', builder: (_, __) => const ConversationHistoryScreen()),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/explorer', builder: (_, __) => const ExplorerScreen()),
        ]),
      ],
    ),

    // Full-screen routes (outside shell — simulators, detail screens, etc.)
    GoRoute(path: '/retraite', ...),
    GoRoute(path: '/hypotheque', ...),
    // ... all 140+ other routes stay as-is with parentNavigatorKey: _rootNavigatorKey
  ],
);
```

### Key Integration Concerns

| Concern | Solution |
|---------|----------|
| 143 existing routes must keep working | Routes outside shell remain top-level. Only 3 root paths go into branches. Deep links unaffected. |
| Chat state preserved when switching tabs | `StatefulShellRoute.indexedStack` uses `IndexedStack` internally — chat scroll position, input text preserved. |
| Back button loop (P0-NAV-3) | Shell root tabs: system back exits app. Nested routes: back pops to tab root. |
| ProfileDrawer (P0-NAV-2) | `endDrawer` on MintShell scaffold. Open via `Scaffold.of(context).openEndDrawer()`. |
| safePop fallback (P1-NAV-1) | Change 40 call sites: fallback from `/coach/chat` to `/home`. |
| /profile redirect (P0-NAV-4) | Redirect `/profile` to open ProfileDrawer (via query param or direct route). |

### Anti-Patterns to Avoid

1. **DO NOT nest all 143 routes inside the shell.** Only 3 tab roots go in branches. Everything else is full-screen overlay with `parentNavigatorKey: _rootNavigatorKey`.
2. **DO NOT use ShellRoute (stateless).** Must be `StatefulShellRoute.indexedStack` to preserve chat state across tab switches.
3. **DO NOT create a custom IndexedStack.** go_router 13 handles this internally via `.indexedStack()` constructor.
4. **DO NOT put auth/landing routes inside the shell.** Public scope routes have no bottom nav.
5. **DO NOT create nested StatefulShellRoute.** One flat shell with 3 branches is sufficient. Sub-navigation within Explorer uses regular `GoRoute` nesting.

**Confidence:** HIGH — go_router ^13.2.0 has stable StatefulShellRoute. Pattern is the standard recommended approach in Flutter ecosystem.

---

## 5. URL Double-Prefix Fix Pattern

### Problem
5 places in Flutter build URLs as `$baseUrl/api/v1/...` but `baseUrl` already ends with `/api/v1` (enforced by `_normalizeBaseUrl` in `api_service.dart:126-134` which appends `/api/v1` if missing). Result: `/api/v1/api/v1/...` = 404.

### Root Cause
`ApiService.baseUrl` returns `https://mint-production-3a41.up.railway.app/api/v1`. Some service files (document_service.dart, coach_memory_service.dart) manually prepend `/api/v1/` again.

### Solution: Remove Redundant Prefix + Add Prevention

**Fix pattern (5 locations):**
```dart
// WRONG:
Uri.parse('$baseUrl/api/v1/documents/scan-confirmation')
// CORRECT:
Uri.parse('$baseUrl/documents/scan-confirmation')
```

**All 5 fix locations:**

| File | Line | Current Path | Fixed Path |
|------|------|-------------|------------|
| `document_service.dart` | ~1086 | `$baseUrl/api/v1/documents/scan-confirmation` | `$baseUrl/documents/scan-confirmation` |
| `document_service.dart` | ~1125 | `$baseUrl/api/v1/documents/extract-vision` | `$baseUrl/documents/extract-vision` |
| `document_service.dart` | ~1169 | `$baseUrl/api/v1/documents/premier-eclairage` | `$baseUrl/documents/premier-eclairage` |
| `coach_memory_service.dart` | ~80 | `$baseUrl/api/v1/coach/sync-insight` | `$baseUrl/coach/sync-insight` |
| `coach_memory_service.dart` | ~106 | `$baseUrl/api/v1/coach/sync-insight/$id` | `$baseUrl/coach/sync-insight/$id` |

**Prevention — URL helper method:**
```dart
// Add to ApiService
static Uri endpoint(String path) {
  assert(!path.startsWith('/api/'),
    'Do not include /api/v1 prefix — baseUrl already includes it');
  final cleanPath = path.startsWith('/') ? path.substring(1) : path;
  return Uri.parse('$baseUrl/$cleanPath');
}
```

**Prevention — CI grep gate:**
```bash
# Add to GitHub Actions Flutter workflow
if grep -rn 'baseUrl/api/v1/' apps/mobile/lib/services/; then
  echo "FAIL: double-prefix URL detected" && exit 1
fi
```

**Confidence:** HIGH — confirmed by reading the actual code in both `_normalizeBaseUrl` and all 5 call sites.

---

## 6. camelCase Mismatch Fix (Tool Calling)

### Problem
Backend sends `toolCalls` (camelCase, from Pydantic `alias_generator = to_camel`). Flutter reads `json['tool_calls']` (snake_case). Key doesn't exist, tool calls silently dropped. Coach tool calling (navigate, simulate) is completely dead.

### Solution
```dart
// In coach_chat_api_service.dart ~line 128-150
// WRONG:
final toolCalls = json['tool_calls'] as List?;
// CORRECT (defensive, handles both conventions):
final toolCalls = (json['toolCalls'] ?? json['tool_calls']) as List?;
```

The `??` fallback handles both server response (camelCase) and any cached/mocked responses (snake_case). This is the standard defensive pattern for Pydantic v2 backends with `populate_by_name=True`.

**Also grep for other potential mismatches:**
```bash
grep -rn "json\['[a-z_]*_[a-z_]*'\]" apps/mobile/lib/services/coach/
# Any snake_case key access to backend JSON is suspect
```

**Confidence:** HIGH — verified from audit findings + code inspection of both backend Pydantic schemas and Flutter JSON parsing.

---

## 7. SQLite Fail-Fast Guard

### Problem
`DATABASE_URL` defaults to `sqlite:///./mint.db` (config.py:17). If Railway env var is missing, app silently uses ephemeral SQLite. All user data lost on every restart.

### Solution
Add fail-fast guard to `config.py`, matching the existing JWT fail-fast pattern (lines 94-101):

```python
# Fail-fast: reject SQLite in production/staging
if (
    os.getenv("ENVIRONMENT", "development") in ("production", "staging")
    and settings.DATABASE_URL.startswith("sqlite")
):
    raise RuntimeError(
        "CRITICAL: DATABASE_URL must point to PostgreSQL in production/staging. "
        "SQLite is ephemeral on Railway and will lose all data on restart."
    )
```

**Confidence:** HIGH — mirrors existing pattern in same file. Zero risk.

---

## Bonus: DNS Cleanup (P1-PIPE-2)

### Problem
`api_service.dart:110` includes `api.mint.ch` as a URL candidate. This domain doesn't resolve. Adds 2s connection timeout latency before falling through to the real Railway URL.

### Solution
Remove from `_baseUrlCandidates`:
```dart
// REMOVE this line until DNS is configured:
if (kReleaseMode) 'https://api.mint.ch/api/v1',
```

Also remove any other unreachable fallback URLs. The candidate list should contain ONLY reachable endpoints.

**Confidence:** HIGH — DNS non-resolution is a fact, not opinion.

---

## What NOT to Touch

| Leave Alone | Why |
|-------------|-----|
| go_router version (^13.2.0) | StatefulShellRoute is stable in this version. No upgrade needed. |
| Provider | State management is orthogonal to these infrastructure fixes. |
| ChromaDB version (^0.5.5) | Persistence is a config issue, not a version issue. |
| Gunicorn timeout (120s) | Already adequate. Railway allows 15 minutes. |
| anthropic SDK version | Current version works. Agent loop fix is application logic. |
| Flutter SDK (^3.6.0) | No Flutter-level changes needed for any fix. |
| Pydantic v2 | camelCase fix is on Flutter side, not backend side. Backend serialization is correct. |

---

## Sources

- [Railway Volumes reference](https://docs.railway.com/reference/volumes) — persistence, mount path, single-volume-per-service limit
- [Railway Using Volumes guide](https://docs.railway.com/volumes) — mount at runtime not build, `RAILWAY_RUN_UID=0` for non-root images
- [Railway ChromaDB deploy template](https://railway.com/deploy/chromadb-1) — confirms volume-based persistence pattern
- [Railway HTTP timeout = 15 minutes](https://station.railway.com/questions/increase-max-http-timeout-1c360bf9) — "any limit lower is self-imposed at application level"
- [GoRouter StatefulShellRoute pattern](https://medium.com/@mohitarora7272/stateful-nested-navigation-in-flutter-using-gorouters-statefulshellroute-and-statefulshellbranch-8bb91443edad)
- [GoRouter StatefulShellRoute complete guide](https://medium.com/@harshhub.414/indexedstack-shellroute-and-statefulshellroute-in-flutter-gorouter-the-complete-guide-to-759b2975808c)
- [Sentry — FastAPI long-running task timeout](https://sentry.io/answers/make-long-running-tasks-time-out-in-fastapi/) — asyncio.wait_for pattern
- Codebase inspection: `api_service.dart:126-134` (_normalizeBaseUrl), `config.py:17` (DATABASE_URL default), `coach_chat.py:565-566` (MAX_AGENT_LOOP constants), `main.py:215-239` (ChromaDB init), `railway.json` (gunicorn --timeout 120)
