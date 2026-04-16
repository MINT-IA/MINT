---
phase: 03-memoire-narrative
plan: 03
subsystem: ui
tags: [privacy-screen, biography, fact-card, bottom-sheet, gorouter, i18n, nLPD]

# Dependency graph
requires:
  - phase: 03-01
    provides: BiographyFact model, BiographyRepository, FreshnessDecayService, BiographyProvider
provides:
  - PrivacyControlScreen with grouped fact list, edit, delete
  - FactCard widget with freshness indicator and source badge
  - FactEditSheet bottom sheet for inline value editing
  - GoRouter route /profile/privacy-control
  - ProfileDrawer entry for privacy control
  - 22 i18n keys in all 6 ARB files
affects: [user-trust, nLPD-compliance, profile-drawer]

# Tech tracking
tech-stack:
  added: []
  patterns: [post-frame-callback-load, grouped-fact-display, destructive-confirmation-dialog]

key-files:
  created:
    - apps/mobile/lib/screens/profile/privacy_control_screen.dart
    - apps/mobile/lib/widgets/biography/fact_card.dart
    - apps/mobile/lib/widgets/biography/fact_edit_sheet.dart
    - apps/mobile/test/screens/profile/privacy_control_screen_test.dart
  modified:
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/widgets/profile_drawer.dart

key-decisions:
  - "Post-frame callback for loadFacts() to avoid notifyListeners during build phase"
  - "hardDeleteFact (physical delete) for privacy screen delete action -- user explicitly wants MINT to forget"
  - "InMemoryBiographyDatabase duplicated in test file to avoid test coupling with repository tests"

patterns-established:
  - "Post-frame callback load: use WidgetsBinding.instance.addPostFrameCallback for initial Provider data loads in StatefulWidget"
  - "Destructive confirmation: AlertDialog with red confirm button for irreversible actions"
  - "Grouped fact display: factsByCategory map with section headers and FactCard list"

requirements-completed: [BIO-05]

# Metrics
duration: 9min
completed: 2026-04-06
---

# Phase 03 Plan 03: Privacy Control Screen Summary

**Privacy control screen ("Ce que MINT sait de toi") with grouped fact cards, inline edit bottom sheet, destructive delete dialog, freshness indicators, and 9 widget tests**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-06T15:19:48Z
- **Completed:** 2026-04-06T15:28:48Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments
- PrivacyControlScreen with grouped sections (financial, life events, decisions), summary stat, pull-to-refresh, empty/error states
- FactCard widget with freshness dot (green/yellow/red), source badge (color-coded per source), edit/delete actions with 48px touch targets
- FactEditSheet bottom sheet with pre-filled input, source note, and save button
- 22 i18n keys in all 6 ARB files (fr/en/de/es/it/pt) with proper diacritics and non-breaking spaces
- GoRouter route at /profile/privacy-control and ProfileDrawer entry
- 9 widget tests covering: title, empty state, fact cards, stale warning, delete dialog, edit sheet, summary count, delete confirmation, grouped headers

## Task Commits

Each task was committed atomically:

1. **Task 1: i18n keys + FactCard + FactEditSheet widgets** - `cce5894b` (feat)
2. **Task 2: PrivacyControlScreen + GoRouter route + ProfileDrawer entry + tests** - `2c32acfb` (feat)

## Files Created/Modified
- `apps/mobile/lib/screens/profile/privacy_control_screen.dart` - Privacy control screen with grouped facts, edit/delete actions, pull-to-refresh
- `apps/mobile/lib/widgets/biography/fact_card.dart` - Fact display card with freshness indicator, source badge, edit/delete icons
- `apps/mobile/lib/widgets/biography/fact_edit_sheet.dart` - Bottom sheet for inline fact value editing
- `apps/mobile/test/screens/profile/privacy_control_screen_test.dart` - 9 widget tests
- `apps/mobile/lib/l10n/app_*.arb` (6 files) - 22 privacy control i18n keys each
- `apps/mobile/lib/app.dart` - Added privacy-control GoRoute under /profile
- `apps/mobile/lib/widgets/profile_drawer.dart` - Added privacy control entry

## Decisions Made
- **Post-frame callback for loadFacts()**: Calling loadFacts() directly in didChangeDependencies caused notifyListeners during build. Using addPostFrameCallback defers the load safely.
- **hardDeleteFact for delete action**: Privacy screen delete uses physical delete (not soft delete) because the user explicitly wants MINT to forget that data (nLPD compliance).
- **Duplicated InMemoryBiographyDatabase in test**: Avoided importing from another test file to prevent test coupling. Minimal duplication for test isolation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed notifyListeners during build**
- **Found during:** Task 2 (widget tests)
- **Issue:** loadFacts() in didChangeDependencies triggered notifyListeners during build phase, causing setState-during-build exception
- **Fix:** Wrapped loadFacts() call in WidgetsBinding.instance.addPostFrameCallback
- **Files modified:** apps/mobile/lib/screens/profile/privacy_control_screen.dart
- **Committed in:** 2c32acfb (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Essential fix for correct widget lifecycle. No scope creep.

## Issues Encountered
- Test for grouped section headers initially used partial text "vnements" which missed the Unicode accent character. Fixed to use "nements de vie" for reliable matching.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Full FinancialBiography pipeline complete: data model -> repository -> freshness decay -> provider -> anonymization -> coach integration -> privacy screen
- Phase 03 (Memoire Narrative) fully delivered: BIO-01 through BIO-08, COMP-02, COMP-03
- Ready for Phase 04 (Anticipation Engine)

## Self-Check: PASSED

- All 4 created files exist on disk
- Both commit hashes verified in git log (cce5894b, 2c32acfb)
- 9 widget tests pass, flutter analyze 0 issues

---
*Phase: 03-memoire-narrative*
*Completed: 2026-04-06*
