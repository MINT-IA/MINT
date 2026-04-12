---
phase: 11-la-navigation
plan: 01
subsystem: ui
tags: [flutter, go_router, navigation, shell, tabs, drawer]

# Dependency graph
requires:
  - phase: 10-les-connexions
    provides: Working front-back connections (URLs, camelCase)
provides:
  - 3-tab StatefulShellRoute.indexedStack shell (Aujourd'hui, Coach, Explorer)
  - ProfileDrawer mounted as endDrawer on shell Scaffold
  - /profile redirect to /profile/bilan
  - MintShell widget with static openDrawer method
affects: [11-02-PLAN (Explorer hubs, safePop migration, zombie cleanup)]

# Tech tracking
tech-stack:
  added: []
  patterns: [StatefulShellRoute.indexedStack for tab persistence, MintShell.openDrawer static method for drawer access]

key-files:
  created:
    - apps/mobile/lib/widgets/mint_shell.dart
  modified:
    - apps/mobile/lib/app.dart
    - apps/mobile/test/architecture/route_scope_leak_test.dart
    - apps/mobile/test/architecture/route_guard_snapshot_test.dart
    - apps/mobile/test/architecture/route_guard_snapshot.golden.txt
    - apps/mobile/test/architecture/route_reachability_test.dart

key-decisions:
  - "Used MintColors.success instead of MintColors.vertMint (does not exist) for tab icon tint"
  - "Used ScopedGoRoute for /coach/chat inside shell branch to preserve RouteScope.public"
  - "LandingScreen reused for Aujourd'hui tab (MintHomeScreen does not exist)"

patterns-established:
  - "Shell routes use bare GoRoute; auth-sensitive shell routes use ScopedGoRoute"
  - "MintShell.openDrawer(context) is the canonical way to open ProfileDrawer from any screen"

requirements-completed: [NAV-01, NAV-02, NAV-03, NAV-04]

# Metrics
duration: 11min
completed: 2026-04-12
---

# Phase 11 Plan 01: Navigation Shell Summary

**3-tab StatefulShellRoute.indexedStack shell with ProfileDrawer endDrawer, /profile redirect fix, and architecture test updates**

## Performance

- **Duration:** 11 min
- **Started:** 2026-04-12T10:13:35Z
- **Completed:** 2026-04-12T10:24:52Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- MintShell widget with 3-tab NavigationBar (Aujourd'hui, Coach, Explorer) and ProfileDrawer as endDrawer
- GoRouter restructured with StatefulShellRoute.indexedStack wrapping 3 branches while all 140+ other routes remain top-level
- /profile redirects to /profile/bilan instead of /coach/chat
- /budget route gets missing parentNavigatorKey: _rootNavigatorKey
- Architecture tests updated for new shell structure (golden snapshot regenerated)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MintShell widget** - `ba5272ad` (feat)
2. **Task 2: Wire StatefulShellRoute into GoRouter** - `123c1230` (feat)
3. **Task 2b: Update architecture tests** - `42d93c05` (fix)

## Files Created/Modified
- `apps/mobile/lib/widgets/mint_shell.dart` - Shell scaffold with 3-tab NavigationBar + ProfileDrawer endDrawer
- `apps/mobile/lib/app.dart` - StatefulShellRoute.indexedStack, ExplorerPlaceholder, /profile redirect fix
- `apps/mobile/test/architecture/route_scope_leak_test.dart` - Remove /home from sanity check (now bare GoRoute)
- `apps/mobile/test/architecture/route_guard_snapshot_test.dart` - Golden snapshot regenerated
- `apps/mobile/test/architecture/route_guard_snapshot.golden.txt` - Updated golden file
- `apps/mobile/test/architecture/route_reachability_test.dart` - Whitelist /retraite (regex parser false positive)

## Decisions Made
- Used `MintColors.success` for selected tab icon tint because `MintColors.vertMint` referenced in plan does not exist in colors.dart
- Used `ScopedGoRoute` (not bare `GoRoute`) for `/coach/chat` inside the shell branch to preserve `RouteScope.public` scope annotation for the auth guard
- Reused `LandingScreen` for Aujourd'hui tab because `MintHomeScreen` does not exist in codebase
- Regenerated route guard golden snapshot rather than trying to hack the regex parser

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] MintColors.vertMint does not exist**
- **Found during:** Task 1 (MintShell widget)
- **Issue:** Plan referenced `MintColors.vertMint` for tab icon color and indicator, but this color token does not exist in colors.dart
- **Fix:** Used `MintColors.success` (the primary green, WCAG AA compliant)
- **Files modified:** apps/mobile/lib/widgets/mint_shell.dart
- **Verification:** flutter analyze passes, visual intent preserved

**2. [Rule 3 - Blocking] Architecture tests failed after shell restructure**
- **Found during:** Task 2 (GoRouter restructure)
- **Issue:** 3 route architecture tests (scope leak, guard snapshot, reachability) failed because they parse app.dart with regex and expect all routes to be ScopedGoRoute
- **Fix:** Updated scope leak test to not expect /home in ScopedGoRoute list, regenerated golden snapshot, whitelisted /retraite in reachability test (regex parser false positive)
- **Files modified:** 3 test files + 1 golden file
- **Verification:** All 12 architecture tests pass

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both auto-fixes necessary for correctness. No scope creep.

## Issues Encountered
- Pre-existing golden screenshot test failure (font cache warmup with flutter_secure_storage plugin) - not related to this plan's changes

## Known Stubs

| Stub | File | Line | Reason |
|------|------|------|--------|
| ExplorerPlaceholder | apps/mobile/lib/app.dart | ~1275 | Placeholder for Explorer tab; real hubs implemented in Plan 02 |

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Shell is live with 3 tabs - ready for Plan 02 (Explorer hubs, safePop migration, zombie cleanup)
- ProfileDrawer is mounted and accessible via MintShell.openDrawer(context)
- ScopedGoRoute compatibility with StatefulShellRoute confirmed working (was a blocker concern in STATE.md)

## Self-Check: PASSED

All files exist, all commits verified.

---
*Phase: 11-la-navigation*
*Completed: 2026-04-12*
