---
phase: 03-onboarding-pipeline
plan: 03
subsystem: onboarding-ui
tags: [premier-eclairage, coach-opener, i18n, mint-home-screen, animated-card]
dependency_graph:
  requires:
    - ReportPersistenceService.loadPremierEclairageSnapshot (03-01)
    - ReportPersistenceService.hasSeenPremierEclairage (03-01)
    - ReportPersistenceService.markPremierEclairageSeen (03-01)
    - ReportPersistenceService.getSelectedOnboardingIntent (03-01)
    - IntentScreen._onChipTap snapshot + intent persistence (03-02)
  provides:
    - PremierEclairageCard widget (Section 0 on MintHomeScreen, first-visit only)
    - MintHomeScreen Section 0 conditional rendering with exploredSimulators auto-dismiss
    - CoachChatScreen intent-aware opener (resolveIntentOpener top-level fn)
    - 13 new ARB keys in 6 languages (premierEclairageCard* + coachOpenerIntent*)
  affects:
    - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart
tech_stack:
  added: []
  patterns:
    - StatefulWidget with async initState for SharedPreferences load (MintHomeScreen)
    - AnimationController + FadeTransition + SlideTransition entrance animation
    - Top-level testable function (resolveIntentOpener) exported from screen file
    - injectStateForTest pattern for provider-heavy widget tests
key_files:
  created:
    - apps/mobile/lib/widgets/onboarding/premier_eclairage_card.dart
    - apps/mobile/test/widgets/onboarding/premier_eclairage_card_test.dart
    - apps/mobile/test/screens/main_tabs/mint_home_screen_test.dart
    - apps/mobile/test/screens/coach/coach_chat_opener_test.dart
  modified:
    - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb
decisions:
  - "resolveIntentOpener extracted as top-level function (not private method) for direct unit testing without mounting full CoachChatScreen widget tree"
  - "MintHomeScreen converted StatelessWidget → StatefulWidget to hold async SharedPreferences state without adding a new Provider"
  - "pumpAndSettle replaced with pump(Duration) in home screen tests to avoid CircularProgressIndicator spinner timeout; MintStateProvider.injectStateForTest used to bypass spinner"
  - "chiffreChocDisclaimer included in PremierEclairageCard mandatory per CLAUDE.md §6 T-03-08 mitigation"
metrics:
  duration: "~40 minutes"
  completed: "2026-04-05"
  tasks_completed: 3
  files_modified: 12
  tests_added: 20
---

# Phase 03 Plan 03: PremierEclairageCard + Coach Opener Summary

**One-liner:** PremierEclairageCard widget (animated, dismissible, pedagogical fallback) inserted as Section 0 on MintHomeScreen, plus intent-aware coach opener resolving 7 chip keys to distinct opener strings on first session.

## Tasks Completed

| Task | Description | Commit | Tests |
|------|-------------|--------|-------|
| 1a | Add 13 i18n ARB keys to all 6 language files + flutter gen-l10n | 24129808 | — |
| 1b | PremierEclairageCard widget + MintHomeScreen Section 0 + tests | 3c3a3cf8 | 13 |
| 2 | Intent-aware coach opener + resolveIntentOpener + behavioral tests | a255a8b5 | 7 |
| — | Lint cleanup (unused const, prefer_const in test files) | 24313ef8 | — |

**Total: 20 new tests, all green. flutter analyze: 0 issues. flutter test: 8161 passed, 0 regressions.**

## What Was Built

### Task 1a: i18n Keys (`apps/mobile/lib/l10n/`)

13 new ARB keys added to all 6 language files (fr/en/de/es/it/pt):

**PremierEclairageCard UI strings (7 keys):**
- `premierEclairageCardDismiss`, `premierEclairageCardCta`, `premierEclairageCardCtaPersonalize`
- `premierEclairageCardEstimate`, `premierEclairageCardSessionHint`
- `premierEclairageCardErrorTitle`, `premierEclairageCardErrorBody`

**Coach opener strings (6 keys):**
- `coachOpenerIntent3a`, `coachOpenerIntentBilan`, `coachOpenerIntentPrevoyance`
- `coachOpenerIntentFiscalite`, `coachOpenerIntentProjet`, `coachOpenerIntentChangement`
- `coachOpenerIntentAutre`

All translations use natural language (not machine translation). French uses non-breaking spaces before em dashes per MINT voice rules.

### Task 1b: PremierEclairageCard (`apps/mobile/lib/widgets/onboarding/premier_eclairage_card.dart`)

`StatefulWidget` with three states:
- **Normal**: `displayMedium` number + `headlineSmall` title + `bodyMedium` subtitle + full-width Comprendre CTA (accent fill) + dismiss x icon
- **Pedagogical** (`confidenceMode == 'pedagogical'`): number in `textMuted` + `premierEclairageCardEstimate` label in `warning` color
- **Error** (null snapshot): error title/body + Personnaliser CTA → `/onboarding/quick-start`

Design tokens: 12px border radius, 4px `saugeClaire` left accent bar, `MintSpacing.md` internal padding. Entrance animation: `FadeTransition` + `SlideTransition` from `Offset(0, 0.08)`, `MintMotion.slow` (600ms), `Curves.easeOut`. Mandatory `chiffreChocDisclaimer` per T-03-08.

**MintHomeScreen** converted from `StatelessWidget` to `StatefulWidget`. `initState` loads `hasSeenPremierEclairage`, `getSelectedOnboardingIntent`, and `UserActivityProvider.exploredSimulators`. Section 0 conditional: `!_hasSeenPremierEclairage && _selectedIntent != null && !_hasExploredSimulators`. Dismiss and Comprendre CTA both call `markPremierEclairageSeen` + `setState`.

### Task 2: Intent-Aware Coach Opener (`apps/mobile/lib/screens/coach/coach_chat_screen.dart`)

- `_loadOnboardingPayload()` extended to load `getSelectedOnboardingIntent` + `hasSeenPremierEclairage`; sets `_pendingIntentChipKey` when first-session conditions met
- `_addInitialGreeting()` resolves `_pendingIntentChipKey` via `resolveIntentOpener()`, sets `_intentOpenerText`, consumes key once (D-09)
- `_buildSilentOpener()`: if `_intentOpenerText` non-null, shows intent-specific text (17px, w500) + `coachSilentOpenerQuestion`; falls back to generic `_computeKeyNumber()` opener on subsequent sessions
- Top-level `resolveIntentOpener(String chipKey, S l10n) → String?` maps 7 chip keys to distinct ARB strings; returns null for unknown keys

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused `_hasSeen` constant in card test**
- **Found during:** flutter analyze after task 1b
- **Issue:** Test file declared `_hasSeen` constant that was never referenced
- **Fix:** Removed the unused constant
- **Files modified:** `test/widgets/onboarding/premier_eclairage_card_test.dart`
- **Commit:** 24313ef8

**2. [Rule 1 - Bug] Added `prefer_const_constructors` ignore to home screen test**
- **Found during:** flutter analyze after task 1b
- **Issue:** `MaterialApp(` constructor flagged as non-const (analyzer info warning)
- **Fix:** Added to `ignore_for_file` list in test file
- **Files modified:** `test/screens/main_tabs/mint_home_screen_test.dart`
- **Commit:** 24313ef8

**3. [Rule 1 - Bug] SharedPreferences keys corrected in test files**
- **Found during:** Task 1b test execution (all tests failed with 0 matches)
- **Issue:** Tests used wrong SharedPreferences keys (`mint_premier_eclairage_snapshot` etc.) instead of the actual keys in `ReportPersistenceService` (`premier_eclairage_snapshot_v1`, `has_seen_premier_eclairage_v1`, `selected_onboarding_intent_v1`)
- **Fix:** Updated all 3 key constants in both test files to match `ReportPersistenceService` private constants
- **Files modified:** both test files
- **Commit:** 3c3a3cf8 (inline fix during development)

**4. [Rule 3 - Blocking] pumpAndSettle replaced with pump(Duration)**
- **Found during:** Task 1b — MintHomeScreen tests timed out because `CircularProgressIndicator.adaptive()` never settles
- **Issue:** `pumpAndSettle` times out when an animation runs indefinitely
- **Fix:** Used `pump()` + `pump(Duration(milliseconds: 200))` to drain microtasks; injected pre-computed `MintUserState` via `MintStateProvider.injectStateForTest()` to bypass spinner
- **Files modified:** `test/screens/main_tabs/mint_home_screen_test.dart`
- **Commit:** 3c3a3cf8 (inline fix during development)

## Known Stubs

None — all UI wiring is complete:
- PremierEclairageCard reads real snapshot persisted by Plan 02 ✓
- MintHomeScreen Section 0 conditional fully wired ✓
- CoachChatScreen intent opener fully wired ✓
- All 13 ARB keys present in 6 languages ✓

## Threat Flags

None — no new network endpoints, auth paths, or schema changes. All changes are UI-layer reads from existing SharedPreferences persistence boundary (established in Plan 01).

T-03-07 mitigated: PremierEclairageCard reads only from snapshot display fields (value, title, subtitle, suggestedRoute, confidenceMode). No raw `CoachProfile` data.
T-03-08 mitigated: `chiffreChocDisclaimer` ARB text included in card widget (both normal and error states).
T-03-09 accepted: null/corrupt snapshot shows error state gracefully.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| `apps/mobile/lib/widgets/onboarding/premier_eclairage_card.dart` | FOUND |
| `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` | FOUND |
| `apps/mobile/lib/screens/coach/coach_chat_screen.dart` | FOUND |
| `apps/mobile/test/widgets/onboarding/premier_eclairage_card_test.dart` | FOUND |
| `apps/mobile/test/screens/main_tabs/mint_home_screen_test.dart` | FOUND |
| `apps/mobile/test/screens/coach/coach_chat_opener_test.dart` | FOUND |
| `.planning/phases/03-onboarding-pipeline/03-03-SUMMARY.md` | FOUND |
| Commit `24129808` | FOUND |
| Commit `3c3a3cf8` | FOUND |
| Commit `a255a8b5` | FOUND |
| Commit `24313ef8` | FOUND |
| flutter analyze 0 issues | PASSED |
| flutter test 8161 passed, 0 regressions | PASSED |
