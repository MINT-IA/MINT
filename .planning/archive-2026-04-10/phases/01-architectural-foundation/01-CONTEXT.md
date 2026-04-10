# Phase 1: Architectural foundation - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning
**Mode:** Expert-panel autonomous (no AskUserQuestion popups, hermeneutic decisions)

<domain>
## Phase Boundary

Make scope leaks and nav regressions mechanically impossible before any deletion begins. This phase ships:
1. Scope-tagged GoRouter routes (`public` / `onboarding` / `authenticated`)
2. Scope-based redirect guard replacing the operation-based whitelist
3. Five mechanical CI tests (cycle DFS, scope-leak, payload consumption, guard snapshot, doctrine string lint) that block merge on any regression of the 4 v2.2 P0 bug classes

**This phase ships NO user-facing change.** It is the safety net for Phase 2 (deletion spree). Without it, every other phase is reversible. Gate 0 for this phase = CI dashboard green, not an iPhone walkthrough.

**Requirements covered:** NAV-01, NAV-02, GATE-01, GATE-02, GATE-03, GATE-04, GATE-05, DEVICE-01 (recurring).

</domain>

<decisions>
## Implementation Decisions

### Route Scope Tagging (NAV-01)
- Introduce `RouteScope` enum (`public` / `onboarding` / `authenticated`) in `apps/mobile/lib/router/route_scope.dart`
- Introduce typed wrapper `ScopedGoRoute extends GoRoute` carrying a `final RouteScope scope` field — type-safe, machine-readable from the cycle/leak tests, no abuse of `extra`
- Migrate every `GoRoute(...)` declaration in `apps/mobile/lib/app.dart` and any sub-routers to `ScopedGoRoute(...)` with explicit scope. Default for any unmigrated route is `authenticated` (fail-closed).
- Constants/enum live in `lib/router/`, NOT under `screens/` — routing metadata is infrastructure.

### Auth Guard Replacement (NAV-02)
- DELETE the `protectedPrefixes` whitelist at `apps/mobile/lib/app.dart:167-173`. It IS the bug.
- REPLACE with a `GoRouter.redirect` callback that:
  1. Walks the matched route subtree from the current location
  2. Reads the topmost matched `ScopedGoRoute`'s `scope` field
  3. For `authenticated` scope: requires `AuthState.signedIn || AuthState.localAnonymous`. Else redirect to landing.
  4. For `onboarding` scope: requires `!completedOnboarding`. Else redirect to `/coach/chat`.
  5. For `public` scope: always allowed.
- Mount ProfileDrawer ONLY inside the authenticated scope subtree (it must be unreachable from any public/onboarding route, regardless of leak path).

### CI Mechanical Gates Layout (GATE-01..05)
- New directory: `apps/mobile/test/architecture/`
- One file per gate (failures are surgical, easy to bisect):
  - `route_cycle_test.dart` — DFS the GoRouter graph; fail on any non-whitelisted SCC. Whitelist explicitly: none for v2.3 (any cycle is a bug until proven otherwise).
  - `route_scope_leak_test.dart` — for every navigation call site (`context.go`, `context.push`, `router.go`, `router.push`) found via static analysis on the codebase, assert source-route scope ≤ target-route scope. `public → authenticated` and `onboarding → authenticated` are forbidden edges. The analysis loads route metadata from the centralized router file.
  - `route_payload_consumption_test.dart` — for every screen widget that receives navigation payload via `state.extra` or `GoRouterState.of(context).extra`, assert the widget consumes the payload BEFORE any short-circuit return (e.g., empty state, loading state). Mechanical fix for Bug 2 root cause at `coach_chat_screen.dart:1317`.
  - `route_guard_snapshot_test.dart` — golden-text snapshot of the guard's protected scope set + every routed page's scope tag. Any unreviewed change fails the test, forcing explicit acknowledgment via test update.
  - `route_doctrine_lint_test.dart` — walks every routed widget's text content (literal Strings + ARB lookups) and fails on banned terms. Inline corpus:
    - `garanti`, `certain`, `sans risque`, `assuré` (compliance)
    - `optimal`, `meilleur`, `parfait` (compliance)
    - `nLPD art.`, `LIFD art.`, `LPP art.` in user-facing copy (raw legal references — backend metadata leaking to UI)
    - `N1 —`, `N2 —`, `N3 —`, `N4 —`, `N5 —` (internal voice cursor naming exposed)
    - `top \d+%` (social comparison)
    - `\d+ %` followed by `il manque|complète|reste` (gamified completion framing)
    - `+\d+ %` as a badge (anti-shame gamification)
    - `Bestie`, `Cher client`, `Il est important de noter` (banned tone)

### Architecture Test Runner Strategy
- All 5 tests run as part of `flutter test apps/mobile/test/architecture/` and are wired into the existing CI workflow at `.github/workflows/` (the workflow that already runs `flutter test`).
- No new GitHub Action job — append to existing test command. Failures bubble up identically.
- The doctrine lint test loads ARB files from `apps/mobile/lib/l10n/` and walks routed widget source via static analysis (read .dart files, find String literals, find AppLocalizations.of(context)!.X references, resolve via ARB). This is mechanical, not LLM.

### Migration Strategy
- Phase 1 migrates EVERY route. No partial migration. The `route_guard_snapshot_test` golden file is generated at the end of the phase and committed — it becomes the source of truth.
- All existing tests must continue passing after migration. Any test breakage means the migration changed behavior, which is a bug — investigate and fix the migration, not the test.

### Gate 0 (DEVICE-01) for Phase 1
- This phase ships ZERO user-facing change. There is no value moment for Julien to walk on iPhone.
- Gate 0 for Phase 1 = screenshot of the CI dashboard showing the 5 new architecture tests GREEN on the Phase 1 PR, plus a screenshot of an intentionally-broken commit demonstrating one of the gates RED (proves the gate fires, not just exists).
- This is the meta-gate: "the gates work", not "the user reached value". Phase 2 onward will have user-facing Gate 0.

### Claude's Discretion
- Choice of `GoRouter.redirect` vs `redirectLimit` configuration details
- Exact file naming inside `lib/router/` (e.g., `route_scope.dart` vs `scopes.dart`)
- Whether to expose `RouteScope` via a public barrel file
- Internal naming of test helpers
- Whether the doctrine lint test outputs a per-violation report or just a count

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Existing GoRouter declaration in `apps/mobile/lib/app.dart` (lines ~140-700 based on audit)
- Existing test infrastructure under `apps/mobile/test/` (8137 Flutter tests passing, harness ready)
- Existing ARB files in `apps/mobile/lib/l10n/app_*.arb` (6 languages)
- Existing CI workflow that runs `flutter test`

### Established Patterns
- Provider for state management (auth state lives in a Provider)
- GoRouter for navigation (no Navigator.push allowed per CLAUDE.md, though some legacy may leak — NAV-06 addresses in Phase 4)
- ARB-based i18n (no hardcoded strings allowed)

### Integration Points
- `apps/mobile/lib/app.dart` (router declaration + redirect callback) — primary edit target
- `apps/mobile/lib/router/` (new directory) — new metadata + scope enum
- `apps/mobile/test/architecture/` (new directory) — new tests
- Auth state Provider (read for guard) — reuse, do not reinvent

### Key Reference Files (read before implementing)
- `docs/NAVIGATION_MAP_v2.2_REALITY.md` — file:line root causes, scope-leak inventory, doctrine matrix
- `apps/mobile/lib/app.dart:167-173` — the buggy whitelist to delete
- `apps/mobile/lib/app.dart:653-656` — example of an authenticated-scope route registration to migrate
- `apps/mobile/lib/screens/auth/register_screen.dart:431,445` — example of `context.go('/profile/consent')` that the scope-leak test must catch as forbidden

</code_context>

<specifics>
## Specific Ideas

- The 5 mechanical tests are described in NAVIGATION_MAP_v2.2_REALITY.md as the ~200 LOC Dart that would have caught all 4 P0 bugs before ship. This phase IS that 200 LOC.
- The cycle test specifically must catch the Phase 2 Bug 2 cycle (`intent → diagnostic → intent`) — test it explicitly with a fixture before deletion happens, prove it would have fired.
- The scope-leak test specifically must catch the Phase 1 Bug 1 leak (`register_screen.dart:431 → /profile/consent`) — test it explicitly with a fixture, prove it would have fired.
- The payload-consumption test specifically must catch the Bug 2 short-circuit at `coach_chat_screen.dart:1317` — fixture proving it would have fired.
- These three "would have fired" assertions are the proof that the safety net is real, not theatrical.

</specifics>

<deferred>
## Deferred Ideas

- Doctrine lint extension to backend Python (out of v2.3 scope; backend is not user-facing)
- Visual regression CI gate (deferred to Phase 5 polish)
- Performance regression CI gate (deferred to v2.4 PERF-01/02)

</deferred>
