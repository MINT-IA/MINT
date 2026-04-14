---
phase: quick-260412-szs
plan: 01
subsystem: coach-chat
tags: [i18n, ux, coach, greeting]
dependency_graph:
  requires: []
  provides: [coachGreetingRandom1-20 i18n keys, random greeting display]
  affects: [coach_chat_screen.dart, all 6 ARB files]
tech_stack:
  added: []
  patterns: [Random field initializer for per-instance randomization]
key_files:
  created: []
  modified:
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_pt.arb
    - apps/mobile/lib/l10n/app_localizations.dart
    - apps/mobile/lib/l10n/app_localizations_fr.dart
    - apps/mobile/lib/l10n/app_localizations_en.dart
    - apps/mobile/lib/l10n/app_localizations_de.dart
    - apps/mobile/lib/l10n/app_localizations_it.dart
    - apps/mobile/lib/l10n/app_localizations_es.dart
    - apps/mobile/lib/l10n/app_localizations_pt.dart
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart
decisions:
  - Greeting index fixed per screen instantiation (Random in field initializer, not per build)
  - GoogleFonts.montserrat for greeting text (heading font per design system)
  - Removed felt-state pills entirely from coach chat (replaced, not hidden)
metrics:
  duration: 8min
  completed: 2026-04-12
---

# Quick 260412-szs: 20 Random Coach Greeting Messages with i18n Summary

20 provocative Swiss-finance greeting messages replacing felt-state pills in coach chat, with full 6-language i18n support (FR/EN/DE/IT/ES/PT).

## Commits

| Task | Name | Commit | Key Changes |
|------|------|--------|-------------|
| 1 | Add 20 greeting keys to all 6 ARB files + gen-l10n | bd018ec3 | 120 i18n entries (20 keys x 6 langs), generated localization Dart files |
| 2 | Replace felt-state pills with random greeting | f8f14ddc | Removed _buildFeltStatePills, added _buildRandomGreeting, dart:math + GoogleFonts imports |

## What Changed

**ARB files (6 languages):** Added `coachGreetingRandom1` through `coachGreetingRandom20` with `@metadata` descriptions. French uses proper `\u00a0` non-breaking spaces. German has Swiss German tone. Italian has Ticino warmth.

**coach_chat_screen.dart:**
- Added `import 'dart:math'` and `import 'package:google_fonts/google_fonts.dart'`
- Added `final int _greetingIndex = Random().nextInt(20)` field
- Replaced `_buildFeltStatePills()` with `_buildRandomGreeting()` (Montserrat 18px w500, centered, MintColors.textPrimary)
- Updated `_buildSilentOpenerWithTone()` to use `greeting` variable instead of `pills`

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- `flutter gen-l10n` succeeded (all 6 ARB files valid JSON)
- `flutter analyze coach_chat_screen.dart` - 0 errors (5 pre-existing warnings unrelated to changes)
- `grep -c coachGreetingRandom app_fr.arb` = 40 (20 keys + 20 @metadata)

## Self-Check: PASSED

All modified files exist. Both commits verified in git log.
