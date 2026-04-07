---
phase: 05-interface-contextuelle
plan: 02
subsystem: ui
tags: [flutter, provider, contextual-cards, coach-opener, compliance, i18n, deep-link]

requires:
  - phase: 05-interface-contextuelle
    plan: 01
    provides: ContextualCard sealed class, ContextualRankingService, HeroStatResolver, 4 card widgets
  - phase: 04-moteur-danticipation
    provides: AnticipationProvider, AnticipationSignal
  - phase: 03-memoire-narrative
    provides: BiographyFact, BiographyProvider, AnonymizedBiographySummary
provides:
  - CoachOpenerService generating biography-aware, compliance-validated greeting text
  - ContextualCardProvider bridging ranking + opener to widget tree with session caching
  - MintHomeScreen rewired to unified 5-card contextual feed
  - 25 i18n keys in all 6 ARB files (fr/en/de/es/it/pt)
  - Deep-link navigation per card type via GoRouter context.push
affects: [06-qa-profond (persona testing of Aujourd'hui tab)]

tech-stack:
  added: []
  patterns: [biography-aware-opener, provider-orchestration, sealed-class-widget-dispatch]

key-files:
  created:
    - apps/mobile/lib/services/contextual/coach_opener_service.dart
    - apps/mobile/lib/providers/contextual_card_provider.dart
    - apps/mobile/test/services/contextual/coach_opener_service_test.dart
    - apps/mobile/test/services/contextual/contextual_card_provider_test.dart
  modified:
    - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
    - apps/mobile/test/screens/main_tabs/mint_home_screen_test.dart
    - apps/mobile/test/screens/coach/navigation_shell_test.dart
    - apps/mobile/test/screens/coach/tab_deep_link_test.dart
    - apps/mobile/test/screens/core_app_screens_smoke_test.dart

key-decisions:
  - "CoachOpenerService uses 5-priority fallback chain: salary increase > recent document > 3a gap > profile completeness < 50% > fallback greeting"
  - "ContextualCardProvider evaluates after AnticipationProvider (data dependency: anticipation signals feed into contextual ranking)"
  - "Removed 6 dead private widget classes from MintHomeScreen (ChiffreVivant, DeltaChip, ConfidenceBar, SignalProactif, RadarAnticipate, AnticipationOverflow) -- all replaced by unified card feed"
  - "Sealed class switch expression dispatches card subtypes to widgets in _buildCardWidget for compile-time exhaustiveness"

patterns-established:
  - "Provider orchestration: AnticipationProvider evaluates first via await, then ContextualCardProvider evaluates with anticipation results"
  - "Coach opener compliance: all generated text validated via ComplianceGuard.validateAlert() before display, fallback on violation"
  - "Card feed dispatch: sealed class switch expression maps ContextualCard subtypes to widget constructors with deep-link onTap"

requirements-completed: [CTX-03, CTX-04, CTX-06]

duration: 20min
completed: 2026-04-06
---

# Phase 5 Plan 2: Contextual Cards Wiring + Coach Opener + i18n Summary

**Biography-aware CoachOpenerService with 5-priority compliance-validated greeting, ContextualCardProvider orchestrating ranking + opener, MintHomeScreen rewired to unified 5-card feed with deep-links, 25 i18n keys in 6 languages**

## Performance

- **Duration:** 20 min
- **Started:** 2026-04-06T19:02:35Z
- **Completed:** 2026-04-06T19:22:43Z
- **Tasks:** 2
- **Files modified:** 22

## Accomplishments
- CoachOpenerService generates biography-aware greeting with 5-priority fallback chain, ComplianceGuard validation, proper French typography (non-breaking spaces)
- ContextualCardProvider bridges ContextualRankingService + CoachOpenerService to widget tree with session caching and demoteCard support
- MintHomeScreen rewired from 8 ad-hoc sections to unified card feed with sealed class dispatch, staggered animations, and empty state
- 25 i18n keys added to all 6 ARB files with proper diacritics, placeholders, and Swiss German/Italian financial terms
- Deep-link navigation per card type via GoRouter context.push (CTX-04)
- 3-tab shell completely untouched (CTX-06)
- Removed ~750 lines of dead code from MintHomeScreen (6 obsolete private widget classes)

## Task Commits

Each task was committed atomically:

1. **Task 1: CoachOpenerService + ContextualCardProvider + i18n keys** (TDD)
   - `f3c848c3` (test: failing tests for CoachOpenerService and ContextualCardProvider)
   - `6d83c878` (feat: CoachOpenerService + ContextualCardProvider + 25 i18n keys)
2. **Task 2: Rewire MintHomeScreen + register provider** - `8538119b` (feat: rewire MintHomeScreen to unified contextual card system)

## Files Created/Modified
- `apps/mobile/lib/services/contextual/coach_opener_service.dart` - Biography-aware opener with 5-priority fallback, ComplianceGuard validation
- `apps/mobile/lib/providers/contextual_card_provider.dart` - ChangeNotifier orchestrating ranking + opener with session caching
- `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` - Unified card feed replacing 6 ad-hoc sections
- `apps/mobile/lib/app.dart` - ContextualCardProvider registered in MultiProvider
- `apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb` - 25 i18n keys per language
- `apps/mobile/test/services/contextual/coach_opener_service_test.dart` - 9 tests for opener generation
- `apps/mobile/test/services/contextual/contextual_card_provider_test.dart` - 5 tests for provider behavior
- `apps/mobile/test/screens/main_tabs/mint_home_screen_test.dart` - Updated harness with ContextualCardProvider
- `apps/mobile/test/screens/coach/navigation_shell_test.dart` - Updated harness
- `apps/mobile/test/screens/coach/tab_deep_link_test.dart` - Updated harness
- `apps/mobile/test/screens/core_app_screens_smoke_test.dart` - Updated harness

## Decisions Made
- CoachOpenerService salary detection requires FactSource.document + updatedAt within 90 days (not just any salary fact)
- Profile completeness threshold set at 50% (below triggers "more data needed" opener instead of fallback)
- Fallback test updated to account for 3a gap and profile completeness priorities firing before absolute fallback
- Dead code removal: 6 private widget classes fully removed rather than kept as legacy (clean codebase policy)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test expecting fallback when 3a gap fires**
- **Found during:** Task 1 (TDD GREEN phase)
- **Issue:** Test "no biography facts -> fallback opener" expected Bienvenue but got 3a gap opener because profile with salary=10000 has a 3a gap of 7258 CHF
- **Fix:** Split into two tests: one with salary=0 (tests profile completeness opener), one with maxed 3a contributions (tests retirement/fallback chain)
- **Files modified:** test/services/contextual/coach_opener_service_test.dart
- **Verification:** All 14 tests pass
- **Committed in:** 6d83c878

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor test adjustment. No scope creep.

## Issues Encountered
None beyond the auto-fixed item above.

## User Setup Required
None - no external service configuration required.

## Known Stubs
None. All services are fully implemented with real logic. No placeholder data or TODO markers.

## Next Phase Readiness
- Phase 05 (Interface Contextuelle) is now complete: Plan 01 built data layer + widgets, Plan 02 wired everything into MintHomeScreen
- Aujourd'hui tab shows unified 5-card contextual feed with biography-aware opener
- Ready for Phase 06 (QA Profond) to validate with 9 personas

## Self-Check: PASSED

- 22/22 files exist on disk
- 4/4 commits verified in git log

---
*Phase: 05-interface-contextuelle*
*Completed: 2026-04-06*
