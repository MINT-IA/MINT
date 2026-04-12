# Pitfalls Research — v2.4 Fondation (Infrastructure Recovery)

**Domain:** Fixing broken infrastructure pipes in a Flutter + FastAPI codebase damaged by cascading agent-driven changes. 32 findings (11 P0, 8 P1, 7 P2, 6 P3) across backend infra, front-back wiring, and navigation architecture.
**Researched:** 2026-04-12
**Confidence:** HIGH on codebase-specific pitfalls (verified by grep against actual code, exact line numbers confirmed). MEDIUM on Railway volume gotchas (based on documentation + common reports).

---

## Critical Pitfalls

Mistakes that cause regressions, data loss, or require rework of already-fixed code.

### Pitfall 1: Partial URL Prefix Fix (The "4 of 5" Trap)

**What goes wrong:** You fix the double `/api/v1` prefix in `document_service.dart` (3 call sites) but miss `coach_memory_service.dart` (2 call sites), or vice versa. The fix works for document upload but insight sync silently 404s. Nobody notices because there is no error UI for sync failures.

**Why it happens:** The 5 broken URLs are spread across 2 files in 2 different directories. A developer greps for the pattern in one file and moves on. The `coach_memory_service.dart` uses the same `$baseUrl/api/v1/...` pattern but is in `services/memory/`, not `services/`.

**Consequences:** Premier eclairage works but coach memory never syncs to backend RAG. The coach answers questions without user context. Appears to work in testing (coach still responds), fails silently in production.

**Prevention:**
```bash
# BEFORE fix: count all instances (expect 5)
grep -rn 'baseUrl.*api/v1/' apps/mobile/lib/services/ | grep -v test | grep -v '//' | wc -l

# AFTER fix: count must be 0
grep -rn '\$baseUrl/api/v1/' apps/mobile/lib/services/ | grep -v test | grep -v '//'
# Expected: zero lines. Any match = missed instance.

# Also verify no NEW double-prefix introduced elsewhere:
grep -rn "api/v1.*api/v1" apps/mobile/lib/ | grep -v test
```

**Detection:** Backend access logs showing 404s on `/api/v1/api/v1/*` paths. Sentry error on `coach_memory_service` sync. Coach responses that ignore user-uploaded documents.

**Phase:** 2 (Les connexions)

---

### Pitfall 2: camelCase Fix Breaks BYOK Path

**What goes wrong:** You change `json['tool_calls']` to `json['toolCalls']` in `coach_chat_api_service.dart:130` to match the Pydantic `to_camel` alias generator output. This fixes server-key tool calling. But the BYOK path (direct Anthropic API) returns `tool_calls` (snake_case, per Anthropic's API spec). Now BYOK tool calling breaks.

**Why it happens:** There are TWO distinct response formats reaching the same Flutter model:
1. **Server-key** (`/coach/chat` endpoint): Pydantic schema with `alias_generator=to_camel` outputs `toolCalls`
2. **BYOK** (direct Anthropic SDK): Anthropic API returns `tool_use` content blocks, which `coach_orchestrator.dart` transforms into `toolCalls` on the `CoachResponse` object (lines 721, 804)

The BYOK path builds `CoachResponse` objects directly in Dart, never going through `CoachChatApiResponse.fromJson`. The server-key path goes through `CoachChatApiResponse.fromJson` which reads from JSON.

**Consequences:** Fix server-key, break BYOK. Or fix BYOK, break server-key. The codebase has no integration test that covers both paths with tool calls.

**Prevention:**
1. The fix is ONLY in `CoachChatApiResponse.fromJson` (line 130): change `json['tool_calls']` to `json['toolCalls']`. This only affects server-key JSON deserialization.
2. The BYOK path never touches `fromJson` -- it constructs `CoachResponse` directly in `coach_orchestrator.dart`. No change needed there.
3. Write a test that sends a mock server-key JSON response with `toolCalls` key AND a test that verifies BYOK path still works.

```bash
# Verify the two paths are truly independent:
grep -n "fromJson" apps/mobile/lib/services/coach/coach_chat_api_service.dart
# Should show fromJson only used for server-key deserialization

grep -n "CoachChatApiResponse" apps/mobile/lib/services/coach/coach_orchestrator.dart
# Should show it is only used in the server-key branch, not BYOK
```

**Detection:** After fix, test both chat modes: (1) with ANTHROPIC_API_KEY in SecureStorage (BYOK), (2) without it (server-key fallback). Both must show tool-triggered widgets.

**Phase:** 2 (Les connexions)

---

### Pitfall 3: Shell Migration Breaks 143 Deep Links

**What goes wrong:** Adding `StatefulShellRoute` with 3 tabs wraps child routes in a shell scaffold. But 143 existing `GoRoute` entries use `context.go('/some/path')` navigation. If routes are not correctly nested inside the shell's route tree, they render without the shell (no tabs, no drawer) or trigger full-page rebuilds that destroy chat state.

**Why it happens:** GoRouter's `ShellRoute`/`StatefulShellRoute` requires child routes to be NESTED inside the shell definition. Routes defined outside the shell tree render without the shell scaffold. Moving 143 routes inside the shell tree is a massive diff that is easy to get wrong.

**Consequences:** 
- Routes outside shell: user navigates to `/lpp-deep` and loses all tabs -- trapped again
- Routes wrongly nested: chat state destroyed on every navigation (StatefulShellRoute exists precisely to prevent this, but only if the chat branch is a separate `StatefulNavigationShell`)
- Back button behavior changes: `context.pop()` inside a shell may pop within the tab, not the shell

**Prevention:**
1. Use `StatefulShellRoute.indexedStack` to preserve state across tabs
2. Chat MUST be its own branch (index 0 or 1) so navigating to other tabs does not rebuild it
3. Routes that are NOT in the shell (e.g., onboarding, auth) must be explicitly placed as siblings, not children
4. Test with a route inventory:

```bash
# Count all GoRoute definitions
grep -c "GoRoute(" apps/mobile/lib/app.dart
# Must equal: (routes inside shell) + (routes outside shell like /onboarding, /auth)

# Verify no orphan context.go() targets routes not in the tree
grep -rn "context.go('" apps/mobile/lib/ | grep -oP "go\('([^']+)'" | sort -u > /tmp/go_targets.txt
grep -oP "path: '([^']+)'" apps/mobile/lib/app.dart | sort -u > /tmp/defined_routes.txt
# diff the two files -- any target not in defined routes = broken navigation
```

5. The `safePop` fallback (`/coach/chat`) must change to `/` (shell root) since `/coach/chat` will be a tab, not a standalone route

**Detection:** After migration, open every Explorer hub and every profile sub-screen. Verify tabs remain visible. Verify back button returns to previous tab, not chat.

**Phase:** 3 (La navigation)

---

### Pitfall 4: safePop Fallback Creates Infinite Loop in Shell Context

**What goes wrong:** Current `safePop` (40 call sites) falls back to `context.go('/coach/chat')`. After shell migration, `/coach/chat` becomes a tab inside the shell. `context.go('/coach/chat')` from inside the shell navigates to the same shell, potentially resetting state or creating a loop.

**Why it happens:** `context.go()` replaces the entire navigation stack. Inside a `StatefulShellRoute`, you should use `context.goNamed()` or tab index switching, not `context.go()` to a tab route.

**Consequences:** User taps back on any of 40 screens, gets dumped to chat tab with full state reset. Conversation history may be lost if the chat widget rebuilds.

**Prevention:**
1. Replace `safePop` with a shell-aware navigation helper:
   - Inside shell: `context.pop()` or switch tab index via `StatefulNavigationShell.of(context).goBranch(index)`
   - Outside shell (onboarding/auth): `context.go('/')` to enter shell
2. Do NOT fix all 40 call sites individually -- replace the single `safePop` function body
3. Test: from a deep screen (e.g., `/lpp-deep/epl`), tap back. Should return to previous screen in same tab, not jump to chat tab.

```bash
# Inventory all safePop consumers (must ALL be retested):
grep -rn "safePop" apps/mobile/lib/screens/ | grep -v test
# Current count: 40 screens. After fix, verify same count (no missed removals).
```

**Phase:** 3 (La navigation)

---

### Pitfall 5: Railway Persistent Volume for ChromaDB (Mount Timing + Permissions)

**What goes wrong:** You add a Railway persistent volume mounted at `/app/data/chromadb`. But:
1. The volume is empty on first deploy -- ChromaDB initializes correctly
2. On subsequent deploys, the volume has data from the previous deploy, BUT the new container's `mint` user (non-root, UID from `useradd`) may have a different UID than the previous container's `mint` user
3. ChromaDB's SQLite files get permission-denied errors
4. App starts, RAG silently falls back to `_NoRagOrchestrator`, coach works but without context

**Why it happens:** Railway persistent volumes preserve Unix permissions from the writing process. If the Docker image changes the `mint` user's UID (e.g., base image update changes `useradd` ordering), the new process cannot read old files.

**Consequences:** RAG silently degrades. The graceful fallback (already implemented in commit 2f65bf01) masks the failure. Coach responds but without document context. Hard to detect because the app "works."

**Prevention:**
1. Pin the UID in Dockerfile: `RUN groupadd -r -g 1001 mint && useradd -r -g mint -u 1001 -d /app mint`
2. Add a startup health check that verifies ChromaDB is readable:
   ```python
   # In main.py startup
   store = MintVectorStore(persist_directory=persist_dir)
   count = store.count()
   logger.info("RAG corpus: %d documents", count)
   if count == 0:
       logger.warning("RAG corpus is EMPTY - coach will operate without document context")
   ```
3. Add `/health` endpoint that reports RAG status (not just HTTP 200)

**Detection:** Monitor startup logs for "RAG corpus: 0 documents" after a deploy that should have preserved data. Add Sentry breadcrumb when `_NoRagOrchestrator` is used as fallback.

**Phase:** 1 (Les tuyaux)

---

### Pitfall 6: Docker COPY Bloats Image with Unnecessary Files

**What goes wrong:** The Dockerfile line `COPY . .` (line 34) copies the ENTIRE backend directory into the production image. To fix P0-INFRA-2 (education inserts path), you might add `COPY ../../education/ /app/education/` which (a) fails because Docker COPY cannot reference paths outside build context, and (b) if you expand the build context to the project root, you copy `apps/mobile/`, `node_modules/`, `.git/`, etc. into the image.

**Why it happens:** Docker build context is `services/backend/`. The `education/inserts/` directory lives at the project root. Expanding build context to `/` is the naive fix.

**Consequences:** Image goes from ~500MB to 2GB+. Deploy times triple. Railway may hit storage limits.

**Prevention:**
1. Keep build context as `services/backend/`
2. Copy education inserts INTO the backend directory BEFORE build (in CI or a pre-build script):
   ```bash
   cp -r education/inserts services/backend/education_inserts/
   ```
3. Add `education_inserts/` to `.gitignore` in backend dir
4. Update `main.py` path to look for `/app/education_inserts/` first, fall back to `../../education/inserts/` for local dev
5. Alternative: multi-stage build that copies only needed files from a context that includes both dirs

```bash
# Verify image size before and after:
docker images mint-backend --format "{{.Size}}"
# Should stay under 600MB
```

**Phase:** 1 (Les tuyaux)

---

### Pitfall 7: Agent Loop Timeout Cuts Off Mid-Generation (Data Corruption)

**What goes wrong:** Adding `asyncio.wait_for(timeout=50)` to the agent loop in `coach_chat.py` (P1-INFRA-1 fix). The timeout fires between Claude API calls in the multi-iteration loop. The first iteration returns tool calls, the second iteration is mid-execution when timeout hits. The function raises `asyncio.TimeoutError`, but the partial result (first iteration's tool calls without final answer) is either lost or returned malformed.

**Why it happens:** The agent loop makes 2-3 sequential Claude API calls (each 15-25s). Total can exceed 50s. A naive `wait_for` on the entire loop kills it mid-flight.

**Consequences:**
- Partial tool call results returned to Flutter (e.g., `toolCalls` present but `message` empty)
- Flutter tries to render tool widgets with incomplete data
- User sees broken UI or empty chat bubble
- Conversation memory saves a corrupted exchange

**Prevention:**
1. Timeout per-iteration, not the whole loop:
   ```python
   for iteration in range(max_iterations):
       try:
           result = await asyncio.wait_for(single_claude_call(), timeout=25)
       except asyncio.TimeoutError:
           return graceful_partial_response(accumulated_so_far)
   ```
2. The `graceful_partial_response` must return whatever text was accumulated plus a user-visible message ("Je reflechis encore, repose-moi la question")
3. NEVER save a timed-out exchange to conversation memory -- it pollutes future context
4. Set Railway request timeout to 120s (double the expected max) via `railway.json` or env var

**Detection:** Monitor for responses where `message` is empty but `tool_calls` is non-null. Log timeout events with iteration count.

**Phase:** 1 (Les tuyaux)

---

## Moderate Pitfalls

### Pitfall 8: The "Facade sans Cablage" Pattern (MINT's #1 Historical Trap)

**What goes wrong:** You fix the URL prefix in `document_service.dart` (the wire) but do not verify that the CONSUMER of the response (`extraction_review_screen.dart`, `impact_screen.dart`) correctly handles the now-working response. The endpoint starts returning data, but the screen expects a different shape or ignores the response entirely because it was coded against a mock.

**Why it happens:** This is MINT's documented #1 failure pattern (see `feedback_facade_sans_cablage.md`). Agent-driven development builds components that look correct individually but are never connected end-to-end. The audit found 11 P0 findings -- many are exactly this pattern.

**Consequences:** Fix looks done. Tests pass (unit tests mock the HTTP layer). But real user sees no change because the consumer was never wired to use the real data.

**Prevention:**
For EVERY pipe fix in Phase 2, follow this checklist:
1. Fix the URL/format issue (the wire)
2. Trace the CONSUMER: what screen/service reads this response?
3. Verify the consumer USES the response (not a hardcoded fallback)
4. Write an integration test that sends a real HTTP request and verifies the consumer renders the result

```bash
# For each fixed endpoint, find all consumers:
grep -rn "sendScanConfirmation\|extractWithVision\|fetchPremierEclairage\|syncInsight" \
  apps/mobile/lib/screens/ apps/mobile/lib/services/ | grep -v test

# For each consumer, verify it does something with the response:
# (manual review -- look for: is the response assigned to a variable that's used?)
```

**Phase:** 2 (Les connexions) -- but also applies to Phase 1 and 3

---

### Pitfall 9: SQLite Fail-Fast Guard Breaks Local Development

**What goes wrong:** You add a fail-fast guard for P0-INFRA-1: if `ENVIRONMENT in ('production', 'staging')` and `DATABASE_URL` starts with `sqlite`, raise `RuntimeError`. But you forget that `ENVIRONMENT` defaults to `"development"` (config.py line 14). A developer who sets `ENVIRONMENT=staging` for local testing (to debug a staging bug) gets a crash with no SQLite, no PostgreSQL. They remove the guard "temporarily" and push it.

**Consequences:** Guard is weakened or removed. Production falls back to SQLite on next deploy if Railway env var is accidentally cleared.

**Prevention:**
1. The guard must ONLY check `ENVIRONMENT` values, not require PostgreSQL locally
2. Allow `ENVIRONMENT=development` with SQLite (current default)
3. Log a WARNING (not error) if `ENVIRONMENT=development` and using SQLite
4. The fail-fast MUST be in `Settings` model validator (Pydantic `@model_validator`), not in application code, so it runs at import time before any request

```python
@model_validator(mode="after")
def validate_production_database(self) -> "Settings":
    if self.ENVIRONMENT in ("production", "staging"):
        if self.DATABASE_URL.startswith("sqlite"):
            raise ValueError(
                f"SQLite is not allowed in {self.ENVIRONMENT}. "
                "Set DATABASE_URL to a PostgreSQL connection string."
            )
    return self
```

**Phase:** 1 (Les tuyaux)

---

### Pitfall 10: DNS Timeout on api.mint.ch Adds Latency to Every Request

**What goes wrong:** You fix P1-PIPE-2 by removing `api.mint.ch` from the URL candidates list. But the URL selection logic (`api_service.dart`) tries candidates in order and falls back on failure. If you remove the wrong candidate or reorder them, ALL requests hit a different broken URL first.

**Why it happens:** The `_baseUrlCandidates` list (api_service.dart:105-113) has multiple entries with conditional inclusion based on `kReleaseMode`. Removing one entry shifts the fallback order.

**Prevention:**
```bash
# Before change, document the exact candidate list:
grep -A 10 "_baseUrlCandidates" apps/mobile/lib/services/api_service.dart

# After change, verify:
# 1. Release mode: first candidate is mint-production-3a41.up.railway.app
# 2. Debug mode: first candidate is localhost:8888
# 3. api.mint.ch is GONE from all modes
# 4. No staging URL added yet (P2-PIPE-1 is deferred)
```

**Phase:** 2 (Les connexions)

---

### Pitfall 11: ProfileDrawer Mount Without Shell = Drawer Over Nothing

**What goes wrong:** You fix P0-NAV-2 by importing `ProfileDrawer` and adding it as `endDrawer` to a Scaffold. But if done before the shell migration (Phase 3), the drawer opens over the current screen (coach chat) with no way to navigate back to other parts of the app. The drawer becomes the ONLY navigation surface, creating a worse UX than before.

**Why it happens:** Phase ordering dependency. The drawer needs the shell (tabs) to be meaningful. Without tabs, the drawer is a dead-end menu.

**Prevention:** ProfileDrawer MUST be mounted as part of Phase 3 (shell migration), not Phase 2. The drawer goes on the SHELL scaffold, not individual screen scaffolds.

**Phase:** 3 (La navigation) -- do NOT attempt in Phase 2

---

## Minor Pitfalls

### Pitfall 12: Zombie Route Deletion Breaks Bookmarked Deep Links

**What goes wrong:** Deleting 6 zombie screens (P1-NAV-2) removes their route handlers. Users who bookmarked or have push notifications targeting these routes get unhandled route errors.

**Prevention:** Add redirect routes (301-style) that point to the nearest valid screen. Keep redirects for 2 releases, then remove.

**Phase:** 3

---

### Pitfall 13: Error Swallowing in document_service.dart Hides Fix Failures

**What goes wrong:** P2-PIPE-2 notes that 3 methods in `document_service.dart` silently swallow errors (catch-all with no rethrow). After fixing the URLs, these methods will start receiving real HTTP responses. If the response format is unexpected, the error is swallowed and the method returns null/empty, appearing as if the endpoint is still broken.

**Prevention:** Before fixing URLs, add logging to all catch blocks in `document_service.dart`:
```bash
grep -n "catch" apps/mobile/lib/services/document_service.dart
# Review each: does it log? Does it rethrow? Does it return a meaningful error?
```

**Phase:** 2 (before URL fixes, not after)

---

### Pitfall 14: OPENAI_API_KEY Missing on Railway = Embedding Failure

**What goes wrong:** P1-INFRA-2: the embeddings service requires `OPENAI_API_KEY` but it is not in the Settings model. You add it to Settings but forget to set it on Railway. First deploy with RAG persistence works, but embeddings for NEW documents fail silently (existing ChromaDB data is fine, new uploads get no embeddings).

**Prevention:**
1. Add to `Settings` with empty default
2. Add startup warning if empty AND `ENVIRONMENT` is production/staging
3. Verify on BOTH Railway environments (staging AND production):
   ```bash
   railway variables --environment staging | grep OPENAI
   railway variables --environment production | grep OPENAI
   ```

**Phase:** 1 (Les tuyaux)

---

## Phase-Specific Warnings

| Phase | Likely Pitfall | Mitigation | Verification Command |
|-------|---------------|------------|---------------------|
| 1 - Tuyaux | SQLite guard breaks local dev | Use Pydantic model_validator, not app-level check | `ENVIRONMENT=development pytest tests/ -q` must still pass |
| 1 - Tuyaux | ChromaDB volume permissions | Pin UID/GID in Dockerfile | `docker run --rm mint-backend ls -la /app/data/` |
| 1 - Tuyaux | Docker image bloat from education copy | Pre-build copy script, not build context expansion | `docker images mint-backend --format "{{.Size}}"` |
| 1 - Tuyaux | Agent timeout data corruption | Per-iteration timeout, graceful partial response | Log timeout events, monitor empty message + non-null tool_calls |
| 2 - Connexions | Partial URL fix (4 of 5) | Grep for ALL `$baseUrl/api/v1/` patterns, expect 0 after | `grep -rn '\$baseUrl/api/v1/' apps/mobile/lib/services/` |
| 2 - Connexions | camelCase fix breaks BYOK | Only change `fromJson`, not orchestrator | Test both BYOK and server-key paths with tool calls |
| 2 - Connexions | Facade sans cablage | Trace every fix to its consumer screen | Manual: fix endpoint -> find consumer -> verify render |
| 2 - Connexions | Error swallowing hides failures | Add logging to catch blocks BEFORE fixing URLs | `grep -n "catch" apps/mobile/lib/services/document_service.dart` |
| 3 - Navigation | Shell migration breaks 143 routes | Route inventory, indexedStack, separate chat branch | Diff `context.go()` targets vs defined routes |
| 3 - Navigation | safePop infinite loop in shell | Replace function body once, not 40 call sites | `grep -c "safePop" apps/mobile/lib/` before and after |
| 3 - Navigation | ProfileDrawer mounted too early | Drawer on SHELL scaffold only, Phase 3 not Phase 2 | N/A -- ordering discipline |
| 3 - Navigation | Zombie route deletion breaks deep links | Add redirects, keep for 2 releases | `grep -rn "achievements\|score_reveal\|cockpit\|annual_refresh\|portfolio\|ask_mint" apps/mobile/lib/app.dart` |
| 4 - Validation | "Works on simulator" | Test on REAL iPhone via `flutter run --release` | Creator device walkthrough, cold start to first insight |

---

## Meta-Pitfall: Sequential Phase Execution Is Non-Negotiable

The MOST IMPORTANT lesson from v2.0 and v2.1 is that parallel agent execution caused the current damage. Phase 1 MUST be complete and verified before Phase 2 starts. Phase 2 MUST be complete before Phase 3. The temptation will be to "quickly fix the URL while working on the shell." Do not. Every cross-phase change risks reintroducing the facade-sans-cablage pattern.

**Gate between phases:**
- Phase 1 -> 2: `pytest tests/ -q` passes, Railway staging deploy succeeds, RAG corpus count > 0 in logs
- Phase 2 -> 3: ALL 5 URLs return 200, tool calling works on staging, premier eclairage loads after document scan
- Phase 3 -> 4: All 3 tabs visible, drawer opens, back button never loops, no 404 routes
- Phase 4: Real human, real iPhone, cold start, zero help

---

## Sources

- `.planning/architecture/14-INFRA-AUDIT-FINDINGS.md` -- all 32 findings with file/line references (HIGH confidence)
- `.planning/PROJECT.md` -- milestone structure and constraints (HIGH confidence)
- `.planning/MILESTONES.md` -- v2.0 and v2.1 lessons learned (HIGH confidence)
- `feedback_facade_sans_cablage.md` -- documented historical pattern (HIGH confidence)
- `feedback_tests_green_app_broken.md` -- "9256 tests green, app broken" lesson (HIGH confidence)
- Codebase grep verification of all patterns cited (HIGH confidence)
- Railway persistent volume behavior -- based on Railway documentation and common reports (MEDIUM confidence)
- GoRouter StatefulShellRoute behavior -- based on go_router package documentation (MEDIUM confidence)
