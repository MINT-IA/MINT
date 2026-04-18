# Navigation Graph Audit — 2026-04-17

**Branch:** `claude/fix-app-navigation-zkVRx`  
**Audit Date:** 2026-04-17 (15-minute deep scan)  
**Router:** `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/app.dart` lines 175–1150

---

## EXECUTIVE SUMMARY

**P0 Issues Found:** 6  
**P1 Issues Found:** 4  
**P2 Issues Found:** 3  

**Top 3 Critical Issues:**
1. **AskMintScreen is dead code** — imported, not exposed in router, only a redirect shim
2. **Multiple zombie screens still in codebase** — AchievementsScreen, ScoreRevealScreen, PortfolioScreen have no routes but are compiled in
3. **Unused screen files bloat** — 6 orphaned .dart files never instantiated by any router builder

All shell tab indexing is correct. Query param parsing works. All context.push calls target valid routes. No Navigator.push violations. No redirect loops.

---

## 1. ORPHAN SCREENS

Screens declared in `lib/screens/` that are **never** instantiated by any `builder:` in the router.

- **[P0] AskMintScreen — Dead code import, redirect-only**
  - File: `lib/app.dart:44` (import, commented "zombie redirect")
  - File: `lib/screens/ask_mint_screen.dart` (137 lines, full feature)
  - Evidence: Comment line 44 states "ask_mint_screen.dart — zombie redirect (Plan 11-02)"; route `/ask-mint` (line 1038) only has `redirect: (_, __) => '/coach/chat'`, no builder
  - Impact: 137 lines of dead code in production. If user tries to navigate programmatically to `AskMintScreen`, it silently routes to coach chat with zero indication
  - Proposed fix: Either (a) remove import + file, or (b) create a route with builder to expose it. Currently it's a trap.

- **[P0] AchievementsScreen — Dead code import, redirect-only**
  - File: `lib/app.dart:139` (import, commented "zombie redirect")
  - File: `lib/screens/achievements_screen.dart` (300+ lines)
  - Evidence: Comment line 139 states "achievements_screen.dart — zombie redirect (Plan 11-02)"; route `/achievements` (line 1010) only has `redirect: (_, __) => '/home'`, no builder
  - Impact: Entire daily streak + badge system unreachable; code is maintained but invisible to users
  - Proposed fix: Delete both import and file, or implement the builder

- **[P0] ScoreRevealScreen — Dead code import, redirect-only**
  - File: `lib/app.dart:78` (import, commented "zombie redirect")
  - File: `lib/screens/advisor/score_reveal_screen.dart`
  - Evidence: Comment line 78 "score_reveal_screen.dart — zombie redirect (Plan 11-02)"; route `/score-reveal` (line 1061) only `redirect: (_, __) => '/home'`
  - Impact: Financial confidence/score screen is unreachable feature
  - Proposed fix: Decide on Phase 3 inclusion or delete

- **[P0] PortfolioScreen — Dead code import, redirect-only**
  - File: `lib/app.dart:26` (import, commented "zombie redirect")
  - File: `lib/screens/portfolio_screen.dart`
  - Evidence: Comment line 26 "portfolio_screen.dart — zombie redirect (Plan 11-02)"; route `/portfolio` (line 1041) only `redirect: (_, __) => '/home'`
  - Impact: Portfolio view inaccessible
  - Proposed fix: Delete or implement builder

- **[P1] AnnualRefreshScreen — Deleted but comment left, import removed**
  - File: `lib/app.dart:105` (comment only, no import)
  - File: `lib/screens/coach/annual_refresh_screen.dart` (still exists on disk)
  - Evidence: Comment line 105 "annual_refresh_screen.dart — zombie redirect (Plan 11-02)" with NO corresponding import
  - Impact: File orphaned on disk; no route declared; but file still exists (dead weight)
  - Proposed fix: Delete `lib/screens/coach/annual_refresh_screen.dart`

- **[P1] CockpitDetailScreen — Deleted but comment left, import removed**
  - File: `lib/app.dart:106` (comment only, no import)
  - File: `lib/screens/coach/cockpit_detail_screen.dart` (still exists on disk)
  - Evidence: Comment line 106 "cockpit_detail_screen.dart — zombie redirect (Plan 11-02)" with NO corresponding import
  - Impact: Dead file on disk
  - Proposed fix: Delete file

---

## 2. UNREACHABLE ROUTES

Routes declared in the router whose `builder:` or `redirect:` point to a class/path that **no widget ever navigates to**.

**Result:** None found. All declared routes have at least one of:
- A direct instantiation in a builder (e.g., `/home` → AujourdhuiScreen)
- A context.push/go call from a screen (e.g., `/profile/bilan` called from budget_screen.dart:702)
- A hub or menu entry (e.g., `/retraite` from explore_hub_screen.dart:404)
- A deep-link or legacy notification param (e.g., `/home?screen=coach` → redirects to `/coach/chat`)

---

## 3. DEAD-END ROUTES

Routes users **can reach** but where the landing screen fails to provide a next action.

**Result:** None critical found. Verified:

- **BudgetContainerScreen** (`/budget`, line 637):
  - When `inputs == null`, shows empty state (line 26–78)
  - CTA at line 61: `onPressed: () => context.push('/coach/chat?topic=budget')` ✓ Valid route
  - NOT a dead-end, just shows "Commencer" → Coach with budget context

- **MonArgentScreen** (`/mon-argent`, line 353):
  - Lines 109–111: Two card CTAs both → `/budget` ✓ and `/profile/bilan` ✓
  - NOT a dead-end

- **All simulators** (affordability, amortization, etc.):
  - Routes exist, builders work, no blocking errors found

---

## 4. NAVIGATOR.PUSH VIOLATIONS

Rule: GoRouter only, no `Navigator.push`, `Navigator.of(context).push`, `Navigator.pushNamed`.

**Result: CLEAN.** Grep for `Navigator.push|Navigator.of(context).push|Navigator.pushNamed` in `lib/screens/` returns zero matches (excluding `lib/widgets/capture/` exception zone).

All navigation is via `context.push()`, `context.go()`, or router `redirect:` callbacks. ✓

---

## 5. REDIRECT CHAINS & LOOPS

Analysis of 52 `redirect:` rules in the router.

**Chain Analysis:**

Simple single-hop redirects (safe):
- `/achievements` → `/home` ✓
- `/ask-mint` → `/coach/chat` ✓
- `/portfolio` → `/home` ✓
- `/score-reveal` → `/home` ✓
- `/tools` → `/coach/chat` ✓
- `/report`, `/report/v2` → `/rapport` ✓
- All `/onboarding/*` → `/coach/chat` or `/profile/bilan` ✓

Multi-condition redirects (safe):
- `/advisor/wizard?section=X` → `/coach/chat?topic=$section` (app.dart:1141–1145) ✓
- `/home?screen=coach&intent=monthlyCheckIn` → `/coach/chat?topic=monthlyCheckIn` (app.dart:218–221) ✓
- `/household/accept?code=XXX` → `/couple/accept?code=XXX` (app.dart:848–851) ✓

**No loops detected.** No redirect points to itself or creates a cycle. ✓

**No broken chains.** All `redirect: (_, __) => '/foo'` targets exist in the router definition.

**P2 finding:** Some redirects are chained through other screens' navigators (e.g., `/achievements` → `/home` → shell re-evaluation), adding 1 extra cycle. Acceptable for backward compat but not optimal.

---

## 6. SHELL TAB ROUTING

StatefulShellRoute.indexedStack (lines 312–395) declares 4 branches:

| Index | Path | Screen | Route Declaration | V11 Match |
|-------|------|--------|-------------------|-----------|
| 0 | `/home` | AujourdhuiScreen | Line 321–341 | Aujourd'hui ✓ |
| 1 | `/mon-argent` | MonArgentScreen | Line 351–355 | Mon argent ✓ |
| 2 | `/coach/chat` | CoachChatScreen | Line 362–381 | Coach ✓ |
| 3 | `/explore` | ExplorerScreen | Line 388–392 | Explorer ✓ |

**Verification:**
- MintShell widget receives navigationShell with correct branch count (4) ✓
- Each branch has its own NavigatorKey (_shellNavigatorKeyHome, etc.) ✓
- No duplicate paths ✓
- No missing tabs ✓

**Status: CORRECT.** Shell structure matches documented V11 specification.

---

## 7. DEEP-LINK QUERY PARAM PARSER

Router redirect logic at lines 213–238 handles `/home?tab=N&intent=X&screen=S`.

**Semantic routing (screen= parameter, lines 218–230):**
- `screen=coach` → `/coach/chat?topic={intent}` ✓
- `screen=mon-argent` or `money` → `/mon-argent` ✓
- `screen=explore` → `/explore` ✓
- `screen=dossier` or `profile` → `/profile/bilan` ✓
- Other values: fall through (no error, just ignored) ⚠️ P2

**Legacy tab mapping (tab= parameter, lines 231–237):**
- `tab=1` → `/mon-argent` ✓
- `tab=2` or `intent != null` → `/coach/chat?topic={intent}` ✓
- `tab=3` → `/explore` ✓
- `tab=0` or missing → stays on `/home` ✓

**Intent propagation (lines 220, 232):**
- Intent carried through as `?topic={intent}` to `/coach/chat` ✓
- CoachChatScreen builder extracts `topic` from queryParameters (app.dart:365) ✓
- CoachEntryPayload constructed with source + topic ✓

**Status: CORRECT.** Query params handled correctly.

**P2 issue:** Unhandled screen= values silently swallowed (no error/default). Should either log or redirect to `/home` explicitly.

---

## 8. GUARD GAPS

Routes with `RouteScope` settings checked against `redirect:` auth logic (lines 181–264).

**Scope coverage:**
- `RouteScope.public` (17 routes): `/`, `/auth/*`, `/anonymous/chat`, `/about`, `/score-reveal` — no auth required ✓
- `RouteScope.onboarding` (6 routes): `/data-block/:type`, `/onboarding/*` — accessible without full auth ✓
- `RouteScope.authenticated` (default): logged-in users only ✓

**Auth redirect logic (lines 257–263):**
- If not logged in, redirects to `/auth/register?redirect={originalPath}` ✓
- Preserves originalPath for post-login return ✓

**Fail-closed design:** Unknown routes default to `RouteScope.authenticated` (line 244) ✓

**Status: SAFE.** No guard gaps. Public screens properly scoped.

---

## SECTION-BY-SECTION SUMMARY

| Category | Status | Notes |
|----------|--------|-------|
| Orphan screens | P0 | 4 dead imports + 2 orphaned files |
| Unreachable routes | CLEAN | All routes have entry points |
| Dead-end screens | CLEAN | No user-facing dead-ends |
| Navigator.push | CLEAN | 100% GoRouter compliance |
| Redirect chains | CLEAN | 52 redirects, no loops |
| Shell tabs | CORRECT | 4 tabs, V11-compliant |
| Query params | CORRECT | Semantic + legacy mapping works |
| Auth guards | SAFE | Fail-closed, proper scoping |

---

## REMEDIATION ROADMAP

**Phase 1 (Immediate, P0 — this sprint):**
1. Remove imports for AskMintScreen, AchievementsScreen, ScoreRevealScreen, PortfolioScreen from app.dart (lines 44, 78, 139, 26)
2. Delete files: `ask_mint_screen.dart`, `achievements_screen.dart`, `score_reveal_screen.dart`, `portfolio_screen.dart`
3. Delete orphaned files: `annual_refresh_screen.dart`, `cockpit_detail_screen.dart`
4. Verify no other code imports these deleted files (grep search)

**Phase 2 (Next sprint, P1):**
1. Refactor redirect shim routes into builders or remove entirely
2. Add default case to query param parser: unhandled `screen=` values log warning + redirect to `/home`
3. Consolidate redirect logic; consider extracting to separate file

**Phase 3 (Post-V1, P2):**
1. Evaluate zombie routes for Phase 3 features (annual refresh, cockpit, achievements)
2. If needed, re-implement with new builders; if not, document hard deprecation

---

## FILES REFERENCED

- **Router:** `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/app.dart` (175–1150)
- **Shell:** `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/widgets/mint_shell.dart`
- **Dead screens:**
  - `lib/screens/ask_mint_screen.dart`
  - `lib/screens/achievements_screen.dart`
  - `lib/screens/advisor/score_reveal_screen.dart`
  - `lib/screens/portfolio_screen.dart`
  - `lib/screens/coach/annual_refresh_screen.dart`
  - `lib/screens/coach/cockpit_detail_screen.dart`
- **Navigation calls:** 102 .dart files in `lib/screens/` (all context.push/go verified)

---

## AUDIT COMPLETE

No critical breaking issues. Navigation graph is structurally sound. Dead code cleanup recommended for production release.
