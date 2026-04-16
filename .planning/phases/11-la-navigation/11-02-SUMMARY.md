---
phase: 11-la-navigation
plan: 02
subsystem: ui
tags: [flutter, go_router, navigation, explorer, shell]

# Dependency graph
requires:
  - phase: 11-la-navigation plan 01
    provides: 3-tab shell with MintShell, StatefulShellRoute, _ExplorerPlaceholder
provides:
  - MintNav.back() shell-aware back navigation with /home fallback
  - ExplorerScreen with 7 domain hub cards in 2-column grid
  - ExploreHubScreen generic hub listing tools per domain
  - 7 /explore/* routes (retraite, famille, travail, logement, fiscalite, patrimoine, sante)
  - 6 zombie routes replaced with redirects (achievements, score-reveal, cockpit, refresh, portfolio, ask-mint)
affects: [12-la-preuve]

# Tech tracking
tech-stack:
  added: []
  patterns: [MintNav.back() as single back-navigation entry point, ExploreHubScreen data-driven hub pattern]

key-files:
  created:
    - apps/mobile/lib/services/navigation/mint_nav.dart
    - apps/mobile/lib/screens/explore/explorer_screen.dart
    - apps/mobile/lib/screens/explore/explore_hub_screen.dart
  modified:
    - apps/mobile/lib/services/navigation/safe_pop.dart
    - apps/mobile/lib/app.dart

key-decisions:
  - "MintNav.back() fallback is /home (shell root) not /coach/chat — prevents infinite loop on coach tab"
  - "safePop kept as shim delegating to MintNav.back() — zero risk, all 44 call sites unchanged"
  - "Explorer hubs push over shell (parentNavigatorKey: _rootNavigatorKey) — own AppBar and back button"
  - "Zombie routes are redirects not deletions — preserves deep links for 2 releases"
  - "Used MintColors.accent instead of plan's MintColors.vertMint (does not exist in codebase)"

patterns-established:
  - "MintNav.back(): single entry point for shell-aware back navigation"
  - "ExploreHubScreen: data-driven hub screen pattern with HubEntry list"
  - "Zombie redirect pattern: ScopedGoRoute(path: '/x', redirect: (_, __) => '/y')"

requirements-completed: [NAV-05, NAV-06, NAV-07]

# Metrics
duration: 5min
completed: 2026-04-12
---

# Phase 11 Plan 02: Explorer & Navigation Cleanup Summary

**MintNav.back() replaces safePop with /home fallback, 7 Explorer hub screens with 40 tool entries, 6 zombie routes redirected**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-12T10:27:25Z
- **Completed:** 2026-04-12T10:32:54Z
- **Tasks:** 2 of 2 auto tasks completed (1 checkpoint pending human verify)
- **Files modified:** 5

## Accomplishments
- MintNav.back() created with /home fallback, safePop delegates to it — all 44 call sites work without changes, no more /coach/chat infinite loop
- ExplorerScreen shows 7 domain hub cards (Retraite, Famille, Travail, Logement, Fiscalite, Patrimoine, Sante) in 2-column grid
- ExploreHubScreen is a generic data-driven hub showing tool entries per domain, 40 total entries across 7 hubs
- 6 zombie routes (achievements, score-reveal, cockpit, refresh, portfolio, ask-mint) replaced with redirects preserving deep links
- 7 unused imports removed from app.dart, _ExplorerPlaceholder class deleted

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MintNav and replace safePop body** - `cd389307` (feat)
2. **Task 2: Build Explorer screens, wire 7 hub routes, delete 6 zombies** - `2b3d3c4a` (feat)
3. **Task 3: Verify navigation on real device** - CHECKPOINT (human-verify, pending)

## Files Created/Modified
- `apps/mobile/lib/services/navigation/mint_nav.dart` - Shell-aware back navigation with /home fallback
- `apps/mobile/lib/services/navigation/safe_pop.dart` - Now delegates to MintNav.back()
- `apps/mobile/lib/screens/explore/explorer_screen.dart` - Explorer tab root with 7 hub cards
- `apps/mobile/lib/screens/explore/explore_hub_screen.dart` - Generic hub screen with HubEntry data model
- `apps/mobile/lib/app.dart` - 7 hub routes added, 6 zombie redirects, ExplorerScreen wired, imports cleaned

## Decisions Made
- MintNav.back() fallback is /home (shell root Aujourd'hui tab) not /coach/chat — the old /coach/chat fallback caused infinite loops when user was already on the coach tab
- safePop kept as thin shim — changing 44 call sites is unnecessary risk when changing the single function body achieves the same result
- Explorer hubs use parentNavigatorKey: _rootNavigatorKey to push over the shell — they get their own AppBar with back button
- Used MintColors.accent (deep green) instead of plan's MintColors.vertMint which does not exist in the codebase
- Used MintColors.lightBorder for hub list dividers instead of MintColors.ardoise (better visual weight)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] MintColors.vertMint does not exist**
- **Found during:** Task 2 (ExplorerScreen creation)
- **Issue:** Plan referenced MintColors.vertMint but this color token does not exist in colors.dart
- **Fix:** Used MintColors.accent (deep green, 0xFF00382E) as the green accent color
- **Files modified:** apps/mobile/lib/screens/explore/explorer_screen.dart
- **Verification:** flutter analyze passes with 0 errors

**2. [Rule 1 - Bug] Divider color MintColors.ardoise too dark for list separators**
- **Found during:** Task 2 (ExploreHubScreen creation)
- **Issue:** Plan used MintColors.ardoise for dividers but this is a deep slate color, too heavy for subtle separators
- **Fix:** Used MintColors.lightBorder for dividers, MintColors.textSecondary for subtitles, MintColors.textMuted for trailing chevron
- **Files modified:** apps/mobile/lib/screens/explore/explore_hub_screen.dart
- **Verification:** flutter analyze passes, visual hierarchy follows design system

---

**Total deviations:** 2 auto-fixed (2 bugs — non-existent color token, poor visual weight)
**Impact on plan:** Cosmetic adjustments only. All functionality delivered as specified.

## Checkpoint: Human Verification Pending

**Task 3 (checkpoint:human-verify)** requires real device walkthrough:
1. Verify 3 tabs visible at bottom (Aujourd'hui, Coach, Explorer)
2. Tap Explorer tab — verify 7 hub cards in grid
3. Tap any hub — verify tool listing with back navigation
4. Tap any tool — verify it opens real screen
5. Back button returns to hub, then to Explorer
6. Navigate to deep screen, back goes to previous screen (NOT /coach/chat)
7. Profile icon opens ProfileDrawer from any tab

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Shell architecture complete (Plan 01 + Plan 02)
- Navigation works: tabs, back button, explorer hubs, zombie cleanup
- Ready for Phase 12 (La preuve) — end-to-end device validation
- Checkpoint Task 3 (device walkthrough) should be verified during Phase 12

---
*Phase: 11-la-navigation*
*Completed: 2026-04-12*
