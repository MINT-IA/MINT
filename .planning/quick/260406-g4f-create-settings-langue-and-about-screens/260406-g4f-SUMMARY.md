---
phase: quick-260406-g4f
plan: 01
subsystem: mobile/navigation
tags: [i18n, settings, about, go-router, flutter]
dependency_graph:
  requires: []
  provides:
    - /settings/langue GoRoute
    - /about GoRoute
  affects:
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/l10n/
tech_stack:
  added: []
  patterns:
    - GoRoute flat path with parentNavigatorKey
    - MintSurface(blanc) for list items
    - LocaleProvider.setLocale via context.read<LocaleProvider>()
    - launchUrl(mode: LaunchMode.externalApplication) for legal links
key_files:
  created:
    - apps/mobile/lib/screens/settings/langue_settings_screen.dart
    - apps/mobile/lib/screens/about_screen.dart
    - apps/mobile/test/navigation_route_integrity_test.dart
  modified:
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_pt.arb
    - apps/mobile/lib/l10n/app_localizations*.dart (regenerated)
decisions:
  - "Used flat /settings/langue path (not nested) — GoRouter supports slash paths at top level"
  - "Restored cap_engine.dart from HEAD to fix navigation test broken route check"
metrics:
  duration: ~15 minutes
  completed: "2026-04-06T09:49:12Z"
  tasks_completed: 3
  tasks_total: 3
  files_created: 2
  files_modified: 9
---

# Phase quick-260406-g4f Plan 01: Create LangueSettingsScreen and AboutScreen Summary

**One-liner:** Two new GoRouter screens (6-language selector + legal/about page) fixing broken `/settings/langue` and `/about` route references from settings_sheet.dart and unblocking navigation_route_integrity_test.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Add i18n keys to all 6 ARB files | 552af2d9 | 6 ARB files + 7 generated dart files |
| 2 | Create screens and register GoRoutes | f5d21fa7 | langue_settings_screen.dart, about_screen.dart, app.dart |
| 3 | Verify CI-blocking test passes | (no new files) | navigation_route_integrity_test.dart |

## Verification Results

- `flutter test test/navigation_route_integrity_test.dart` — **PASSED (1/1)**
- `flutter analyze lib/screens/settings/... lib/screens/about_screen.dart lib/app.dart lib/l10n/` — **0 issues**
- All 6 ARB files updated with 11 new keys (13 entries in fr with @metadata)
- `flutter gen-l10n` ran successfully

## Screen Details

### LangueSettingsScreen (`/settings/langue`)
- Lists all 6 locales from `MintLocales.supportedLocales`
- Shows flag emoji (fontSize 24) + display name + check icon for current locale
- On tap: `context.read<LocaleProvider>().setLocale(locale)` + SnackBar with `langueScreenChanged`
- Background: `MintColors.porcelaine`, list items in `MintSurface(blanc)`

### AboutScreen (`/about`)
- MINT heading (fontSize 48, Montserrat w800) + tagline + version
- Legal links section in `MintSurface(blanc)`: CGU, Privacy, Disclaimer, Mentions légales
- Each link opens with `launchUrl(externalApplication)`
- Compliance disclaimer at bottom

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Restored cap_engine.dart to fix navigation test pre-existing breakage**
- **Found during:** Task 3 verification
- **Issue:** The soft reset left cap_engine.dart with old routes (`/deces-proche` without `/life-event/` prefix) causing 5 broken route failures in navigation_route_integrity_test
- **Fix:** Restored `apps/mobile/lib/services/cap_engine.dart` from HEAD (85090e55) which has correct `/life-event/` prefix routes
- **Files modified:** apps/mobile/lib/services/cap_engine.dart (restored to HEAD, not committed as separate change)
- **Commit:** N/A (working tree restore, not a new commit)

## Known Stubs

None — both screens are fully wired:
- LangueSettingsScreen reads from LocaleProvider (real state)
- AboutScreen version is hardcoded to `'1.0.0'` — placeholder until package_info_plus is wired. This does not prevent the screen's goal but should be tracked.

## Threat Flags

No new threat surface introduced. Both screens are read-only UI:
- Language selection reads from fixed enum (MintLocales.supportedLocales) — no injection vector
- About screen displays only static public information

## Self-Check: PASSED

- langue_settings_screen.dart: FOUND
- about_screen.dart: FOUND
- commit 552af2d9 (i18n keys): FOUND
- commit f5d21fa7 (screens + routes): FOUND
- navigation_route_integrity_test: PASSED
