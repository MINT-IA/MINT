---
phase: 04-moteur-danticipation
plan: 03
subsystem: anticipation
tags: [anticipation, provider, widget, i18n, home-screen, dismiss, snooze, compliance]

# Dependency graph
requires:
  - phase: 04-moteur-danticipation
    provides: AnticipationEngine, AnticipationPersistence, AnticipationRanking, ComplianceGuard.validateAlert()
provides:
  - AnticipationProvider ChangeNotifier (session-cached evaluation, ComplianceGuard validation, dismiss/snooze)
  - AnticipationSignalCard widget (educational format with icon, title, fact, source, CTA, dismiss/snooze)
  - MintHomeScreen integration (cards after Chiffre Vivant, before Financial Plan)
  - _AnticipationOverflow expandable section for excess signals
  - 12 anticipation i18n keys in 6 ARB files (fr/en/de/es/it/pt)
affects: [05-interface-contextuelle]

# Tech tracking
tech-stack:
  added: []
  patterns: [provider-with-compliance-gate, arb-parameterized-signal-cards, overflow-expansion-tile]

key-files:
  created:
    - apps/mobile/lib/providers/anticipation_provider.dart
    - apps/mobile/lib/widgets/home/anticipation_signal_card.dart
    - apps/mobile/test/services/anticipation/anticipation_provider_test.dart
  modified:
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
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
  - "ComplianceGuard.validateAlert() runs on signal titleKey/factKey in provider before card reaches widget (T-04-08)"
  - "Signal text resolved via switch on titleKey/factKey to call correct S method with params (no dynamic reflection)"
  - "AnticipationProvider registered in app.dart MultiProvider alongside BiographyProvider"
  - "Evaluation triggered via addPostFrameCallback in MintHomeScreen.initState (avoids notifyListeners during build)"

patterns-established:
  - "Provider-with-compliance-gate: validate output before exposing to widget tree"
  - "ARB key resolver pattern: switch on signal.titleKey to dispatch to correct S.anticipation*() method"
  - "Test harness pattern: tests using MintHomeScreen must include BiographyProvider + AnticipationProvider"

requirements-completed: [ANT-01, ANT-02, ANT-03, ANT-04, ANT-05, ANT-06, ANT-07, ANT-08]

# Metrics
duration: 15min
completed: 2026-04-06
---

# Phase 04 Plan 03: UI Integration Summary

**AnticipationProvider with ComplianceGuard gate, AnticipationSignalCard educational widget, MintHomeScreen wiring (after Chiffre Vivant), and 12 i18n keys in 6 languages**

## Performance

- **Duration:** 15 min
- **Started:** 2026-04-06T16:36:13Z
- **Completed:** 2026-04-06T16:51:00Z
- **Tasks:** 2 completed, 1 deferred (checkpoint:human-verify)
- **Files modified:** 16

## Accomplishments
- AnticipationProvider evaluates once per session, validates every visible signal with ComplianceGuard.validateAlert() before display, and handles dismiss/snooze with persistence
- AnticipationSignalCard renders educational format: icon + title + fact + legal source + simulator CTA + dismiss/snooze buttons, all via AppLocalizations
- 12 anticipation i18n keys in all 6 ARB files with proper French diacritics and non-breaking spaces
- MintHomeScreen integration: cards appear after Chiffre Vivant, before Financial Plan, with overflow ExpansionTile
- 7 provider tests pass (evaluate, dismiss, snooze, session cache, reset). 81 total anticipation tests green.

## Task Commits

Each task was committed atomically:

1. **Task 1: AnticipationProvider + AnticipationSignalCard + i18n keys** - `0bd9cecf` (feat)
2. **Task 2: Wire into MintHomeScreen + register in MultiProvider** - `0fbf11cb` (feat)
3. **Task 3: Visual verification** - DEFERRED (checkpoint:human-verify approved without validation)

## Files Created/Modified
- `apps/mobile/lib/providers/anticipation_provider.dart` - ChangeNotifier with session caching, ComplianceGuard gate, dismiss/snooze
- `apps/mobile/lib/widgets/home/anticipation_signal_card.dart` - Educational card widget (MintSurface, icon mapping, ARB key resolver)
- `apps/mobile/test/services/anticipation/anticipation_provider_test.dart` - 7 tests for provider behavior
- `apps/mobile/lib/app.dart` - AnticipationProvider registered in MultiProvider
- `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` - Anticipation section + _AnticipationOverflow widget
- `apps/mobile/lib/l10n/app_fr.arb` - 12 anticipation keys (French with diacritics + non-breaking spaces)
- `apps/mobile/lib/l10n/app_en.arb` - 12 anticipation keys (English)
- `apps/mobile/lib/l10n/app_de.arb` - 12 anticipation keys (German/BVG terminology)
- `apps/mobile/lib/l10n/app_es.arb` - 12 anticipation keys (Spanish)
- `apps/mobile/lib/l10n/app_it.arb` - 12 anticipation keys (Italian/pilastro terminology)
- `apps/mobile/lib/l10n/app_pt.arb` - 12 anticipation keys (Portuguese)

## Decisions Made
- ComplianceGuard.validateAlert() runs on signal titleKey/factKey in provider, not in widget (T-04-08: compliance validation before rendering)
- Signal text resolved via explicit switch on titleKey/factKey to call correct S method with params -- avoids dynamic reflection
- Post-frame callback for evaluation trigger (follows BiographyProvider pattern: avoids notifyListeners during build)
- Non-compliant signals moved to overflow list rather than dropped entirely (future debugging visibility)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed 4 test harnesses missing provider registrations**
- **Found during:** Task 2 (MintHomeScreen integration)
- **Issue:** 33 tests failed because MintHomeScreen now reads BiographyProvider and AnticipationProvider in initState, but test harnesses lacked these providers
- **Fix:** Added BiographyProvider + AnticipationProvider (+ FinancialPlanProvider where missing) to MultiProvider in 4 test files
- **Files modified:** `mint_home_screen_test.dart`, `navigation_shell_test.dart`, `tab_deep_link_test.dart`, `core_app_screens_smoke_test.dart`
- **Verification:** All 33 provider-related failures resolved. 8854 tests run, 0 new failures.
- **Committed in:** `0fbf11cb` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Essential fix -- tests would fail without provider registrations. No scope creep.

## Deferred Items

**Task 3 (checkpoint:human-verify):** Visual verification of anticipation cards on Aujourd'hui tab. User chose to continue without validation. Automated verification passed (flutter test + flutter analyze). Visual check deferred.

## Issues Encountered
- 11 pre-existing test failures (intent_screen_test, auth_screens_smoke_test, navigation_route_integrity_test, quick_start_screen_golden_test) -- none related to anticipation changes

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Full anticipation engine pipeline complete: triggers (Plan 01) -> ranking+compliance+persistence (Plan 02) -> provider+cards+i18n (Plan 03)
- Phase 04 (Moteur d'Anticipation) is complete -- all 3 plans delivered
- AnticipationProvider ready for Phase 05 (Interface Contextuelle) smart card ranking integration
- 81 anticipation tests provide regression safety net

## Self-Check: PASSED

- All 4 key files: FOUND
- Commit 0bd9cecf: FOUND
- Commit 0fbf11cb: FOUND
- flutter analyze: 0 errors (1 pre-existing warning)
- flutter test anticipation/: 81/81 passed

---
*Phase: 04-moteur-danticipation*
*Completed: 2026-04-06*
