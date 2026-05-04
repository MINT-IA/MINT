---
phase: 26-navigation-coherence
plan: 01
subsystem: ui
tags: [navigation, gorouter, lightning-menu, auth-state, shell]

requires:
  - phase: 17-tension-cards
    provides: auth-aware GoRoute builder pattern
  - phase: 22-coach-chat-ux
    provides: lightning menu and chat drawer host
provides:
  - Lightning menu route fallback to push navigation
  - Auth loading state on home tab preventing flash of wrong content
affects: [coach-chat, explorer, aujourdhui]

tech-stack:
  added: []
  patterns:
    - "Route fallback: drawer resolution fails -> push navigation"
    - "Auth loading gate: show spinner while checkAuth() resolves"

key-files:
  created: []
  modified:
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart
    - apps/mobile/lib/app.dart

key-decisions:
  - "Push navigation fallback for lightning menu routes without drawer support"
  - "Loading indicator during auth resolution prevents LandingScreen flash"

patterns-established:
  - "Lightning menu onNavigate: try drawer first, fall back to push"
  - "Shell tab builders must check isLoading before isLoggedIn"

requirements-completed: [NAV-01, NAV-02, NAV-03, NAV-04, WID-03]

duration: 4min
completed: 2026-04-13
---

# Phase 26 Plan 01: Navigation Coherence Summary

**Lightning menu route fallback to push navigation + auth loading state on home tab preventing flash of unauthenticated content**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-13T18:42:14Z
- **Completed:** 2026-04-13T18:47:08Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Lightning menu "Scanner un document" and "Completer mon profil" now navigate correctly via push when no drawer widget is available
- Home tab shows loading indicator while `checkAuth()` resolves, preventing flash of LandingScreen for authenticated users
- Verified back navigation works correctly via `MintNav.back()` and `parentNavigatorKey` on hub routes
- Verified explorer tab accessible when authenticated (router scope defaults to authenticated, correct behavior)
- Verified `_MintErrorScreen` handles unknown routes

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix lightning menu route handling** - `65c424a0` (fix)
2. **Task 2: Auth loading state on home tab** - `57c0ed7b` (fix)
3. **Task 3: Verify back navigation and dead routes** - No changes needed (verification-only)

## Files Created/Modified

- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` - Added push navigation fallback in lightning menu onNavigate callback
- `apps/mobile/lib/app.dart` - Added auth loading state check in /home route builder

## Decisions Made

- **Push fallback over silent swallow**: When `ChatDrawerHost.resolveDrawerWidget()` returns null, fall back to `context.push(route)` instead of doing nothing. This covers `/scan` (needs camera), `/profile/bilan`, and any future routes not yet in the drawer map.
- **Loading indicator over LandingScreen flash**: During `checkAuth()` async resolution, show a spinner instead of the LandingScreen. This prevents the Gate 0 finding where authenticated users briefly saw "Creer ton compte".

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 26 is the FINAL phase of v2.6. All navigation coherence issues identified in Gate 0 walkthrough have been addressed:
- NAV-01: Explorer accessible when authenticated
- NAV-02: Aujourd'hui shows correct content when authenticated
- NAV-03: No dead routes (all verified)
- NAV-04: Back navigation works via MintNav.back()
- WID-03: Lightning menu actions all functional

Ready for milestone verification.

---
*Phase: 26-navigation-coherence*
*Completed: 2026-04-13*
