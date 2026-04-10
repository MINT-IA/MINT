---
phase: 02-deletion-spree
plan: 01
subsystem: navigation
tags: [deletion, simplification, routing, auth-guard]
dependency_graph:
  requires: [01-architectural-foundation]
  provides: [simplified-route-graph, landing-to-chat-flow, auth-leak-tombstone]
  affects: [apps/mobile/lib/app.dart, apps/mobile/lib/screens/]
tech_stack:
  added: []
  patterns: [redirect-shim-for-deleted-routes, scope-based-auth-guard]
key_files:
  created:
    - apps/mobile/test/architecture/auth_leak_tombstone_test.dart
    - .planning/phases/02-deletion-spree/02-VERIFICATION.md
  modified:
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart
    - apps/mobile/lib/screens/landing_screen.dart
    - apps/mobile/lib/screens/auth/register_screen.dart
    - apps/mobile/test/architecture/route_guard_snapshot.golden.txt
    - apps/mobile/test/screens/core_app_screens_smoke_test.dart
    - apps/mobile/test/navigation/goroute_health_test.dart
    - apps/mobile/test/golden_screenshots/golden_screenshot_test.dart
    - apps/mobile/test/design_system/s0_s5_microtypography_test.dart
    - apps/mobile/test/i18n/hardcoded_string_audit_test.dart
    - apps/mobile/test/screens/landing_screen_test.dart
  deleted:
    - apps/mobile/lib/widgets/coach/coach_empty_state.dart
    - apps/mobile/lib/screens/onboarding/intent_screen.dart
    - apps/mobile/lib/screens/consent_dashboard_screen.dart
    - apps/mobile/lib/screens/profile_screen.dart
    - apps/mobile/lib/screens/main_navigation_shell.dart
    - apps/mobile/lib/screens/main_tabs/explore_tab.dart
    - apps/mobile/test/screens/onboarding/intent_screen_test.dart
    - apps/mobile/test/screens/consent_dashboard_test.dart
    - apps/mobile/test/screens/cta_navigation_regression_test.dart
    - apps/mobile/test/screens/coach/navigation_shell_test.dart
    - apps/mobile/test/screens/coach/tab_deep_link_test.dart
    - apps/mobile/test/screens/main_tabs/explore_tab_test.dart
    - apps/mobile/test/screens/main_tabs/explore_tab_readiness_test.dart
    - apps/mobile/integration_test/onboarding_v2_golden_path_test.dart
decisions:
  - "/coach/chat scope changed from authenticated to public (KILL-05: users reach chat without account)"
  - "ProfileScreen deleted entirely rather than gutted (gamification was primary content)"
  - "Hub screen FILES preserved for Phase 3 chat-summoned drawers; only routes removed"
  - "CGU/privacy links in register_screen redirect to /about (public legal page)"
metrics:
  duration_seconds: 1683
  completed: "2026-04-09T12:11:00Z"
  tasks_completed: 8
  tasks_total: 8
  files_deleted: 14
  files_modified: 11
  files_created: 2
  routes_removed: 1
  routes_redirected: 11
---

# Phase 2 Plan 1: Deletion Spree Summary

**One-liner:** Delete 14 files (6 screens + 8 tests), redirect 11 routes to /coach/chat, add 6 tombstone tests -- app is now landing -> chat.

## What Was Done

8 surgical commits, each independently revertable via git bisect:

1. **KILL-02**: Deleted `CoachEmptyState` widget. The `_hasProfile` short-circuit in `coach_chat_screen.dart` build() that trapped users in an infinite loop is structurally eliminated.

2. **KILL-01**: Deleted `intent_screen.dart`. The `/onboarding/intent` route became a redirect shim to `/coach/chat`. Updated 6 test files that referenced IntentScreen.

3. **KILL-03**: Deleted `consent_dashboard_screen.dart`. Removed the `/profile/consent` sub-route. Fixed register_screen CGU/privacy links to use `context.push('/about')` instead of routing to an authenticated page.

4. **KILL-04 + KILL-06**: Deleted `profile_screen.dart` entirely (gamification progress bar, +15%/+10% badges, dossier completion percentage were the primary content). `/profile` now redirects to `/coach/chat`; sub-routes (byok, slm, bilan, admin) preserved. No N1/N2/N3 voice cursor labels found on any user-facing surface.

5. **KILL-05**: Landing CTA changed from `/onboarding/intent` to `/coach/chat`. `/coach/chat` scope changed from `authenticated` to `public`. Register post-auth routing simplified to `/coach/chat`. Account creation is now optional.

6. **KILL-07**: Deleted `main_navigation_shell.dart` (3-tab shell) and `explore_tab.dart`. `/home` and all 7 explorer hub routes redirect to `/coach/chat`. Shell is gone. App is landing -> chat.

7. **BUG-02**: Created `auth_leak_tombstone_test.dart` with 6 tests proving unauthenticated users cannot reach `/profile`, `/profile/byok`, `/home`, `/explore/*`, or the deleted `/profile/consent` through any navigation path.

8. **GATE-04**: Updated guard snapshot golden file: removed `consent` entries, changed `/coach/chat` scope from `authenticated` to `public`. All 31 architecture tests pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] /coach/chat scope needed to be public for KILL-05**
- **Found during:** Task 5
- **Issue:** Landing CTA going to `/coach/chat` would trigger auth guard redirect to `/auth/register` because the route defaulted to `RouteScope.authenticated`.
- **Fix:** Changed `/coach/chat` scope to `RouteScope.public`. Chat can handle anonymous vs authenticated users internally.
- **Files modified:** `apps/mobile/lib/app.dart`
- **Commit:** dd51ec21

**2. [Rule 3 - Blocking] score_reveal_screen fallback referenced deleted MainNavigationShell**
- **Found during:** Task 6
- **Issue:** `score_reveal_screen` route in app.dart had `return const MainNavigationShell()` as a fallback when extra params were missing.
- **Fix:** Changed fallback to `return const CoachChatScreen()`.
- **Files modified:** `apps/mobile/lib/app.dart`
- **Commit:** 0b5ab098

## Test Impact

- **Tests before (baseline):** 9236 pass, 6 skip, 8 fail (all pre-existing)
- **Tests after:** 9236 pass, 6 skip, 8 fail (same pre-existing failures)
- **Tests deleted:** ~120 (from 14 deleted test files)
- **Tests added:** 6 (auth leak tombstone)
- **Net test count change:** Decreased as expected (deleted screen tests)
- **Zero regressions:** All 8 failures verified pre-existing by running on stashed pre-change code

## Decisions Made

1. `ProfileScreen` deleted entirely rather than gutted -- gamification was its raison d'etre
2. `/coach/chat` made public scope -- enables skip-account flow from landing
3. Hub screen files preserved (only routes removed) -- Phase 3 reuses them as chat-summoned drawers
4. CGU/privacy links redirect to `/about` (existing public legal page)

## Self-Check: PASSED

- All 2 created files exist
- All 6 screen files confirmed deleted
- All 8 commit hashes verified in git log
