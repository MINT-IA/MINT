---
phase: 01-architectural-foundation
plan: 01a
subsystem: mobile/router
tags: [routing, auth-guard, navigation, scope]
dependency_graph:
  requires: []
  provides: [RouteScope, ScopedGoRoute, scope-based-redirect-guard]
  affects: [apps/mobile/lib/app.dart, apps/mobile/lib/router/]
tech_stack:
  added: [ScopedGoRoute]
  patterns: [declarative-route-scope, fail-closed-auth]
key_files:
  created:
    - apps/mobile/lib/router/route_scope.dart
    - apps/mobile/lib/router/scoped_go_route.dart
  modified:
    - apps/mobile/lib/app.dart
decisions:
  - RouteScope enum with 3 values (public, onboarding, authenticated)
  - Default scope = authenticated (fail-closed)
  - Redirect-only routes keep default scope (irrelevant since they redirect)
  - ProfileDrawer already in authenticated subtree - no structural change needed
  - topRoute property (go_router 13.2.5) used to read scope in redirect callback
metrics:
  duration: 11m
  completed: 2026-04-09
---

# Phase 01 Plan 01a: Scope infra + router migration + guard replacement Summary

RouteScope enum + ScopedGoRoute wrapper replacing protectedPrefixes whitelist with declarative per-route auth scoping across 144 routes

## What Was Done

### Task 1: RouteScope enum + ScopedGoRoute class
- Created `route_scope.dart` with 3-value enum: `public`, `onboarding`, `authenticated`
- Created `scoped_go_route.dart` extending GoRoute with `final RouteScope scope` field
- Default is `authenticated` (fail-closed: any route that forgets to set scope requires auth)

### Task 2: Router migration (144 routes)
- Replaced all 144 `GoRoute(` declarations with `ScopedGoRoute(`
- 7 routes marked `RouteScope.public`: `/` (landing), `/auth/login`, `/auth/register`, `/auth/forgot-password`, `/auth/verify-email`, `/auth/verify`, `/about`
- 2 routes marked `RouteScope.onboarding`: `/onboarding/intent`, `/data-block/:type`
- 135 routes use default `RouteScope.authenticated` (including all simulators, calculators, coach, explorer hubs, profile, documents, settings, and redirect-only routes)

### Task 3: Guard replacement
- Deleted the 5-entry `protectedPrefixes` string list
- Replaced with scope-based redirect that reads `RouteScope` from the matched `ScopedGoRoute` via `state.topRoute`
- `public` routes: always allowed (no auth check)
- `onboarding` routes: always allowed (completion check handled per-screen)
- `authenticated` routes: require `isLoggedIn`, redirect to `/auth/register?redirect=...`
- Fail-closed: if `topRoute` is not a `ScopedGoRoute`, treated as `authenticated`

### Task 4: ProfileDrawer re-mount (no-op)
- Verified ProfileDrawer is mounted only in `main_navigation_shell.dart:423` as `endDrawer`
- MainNavigationShell is only reachable via `/home` route which is `RouteScope.authenticated` by default
- No structural change needed — ProfileDrawer is already correctly scoped

## Verification Results

- `flutter analyze lib/app.dart lib/router/` : 0 issues
- `flutter test` : 9302 passed, 6 skipped, 6 failed (same 6 pre-existing failures; baseline without changes had 12 failures, so net improvement)
- No new warnings or errors introduced

## Decisions Made

1. **topRoute for scope resolution**: Used `state.topRoute` (go_router 13.2.5 API) to read scope from matched route in redirect callback, rather than walking the match chain manually
2. **Redirect routes keep default scope**: Routes that only redirect never render, so their scope is irrelevant — left as default `authenticated`
3. **No ProfileDrawer change**: Already correctly scoped inside authenticated subtree via MainNavigationShell

## Deviations from Plan

None - plan executed exactly as written.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | a587296b | feat(01): add RouteScope enum + ScopedGoRoute wrapper [NAV-01] |
| 2 | baa8a1f3 | refactor(01): migrate every GoRoute in app.dart to ScopedGoRoute [NAV-01] |
| 3 | 9ccc4482 | refactor(01): replace protectedPrefixes whitelist with scope-based redirect guard [NAV-02] |
| 4 | (no-op) | ProfileDrawer already in authenticated subtree |
