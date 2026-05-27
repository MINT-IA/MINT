# Phase 17 - Fresh budget grounds Mon Argent whisper

## Goal

Remove the last visible contradiction between the Mon Argent budget card and
the deterministic coach whisper.

## Changes

- `MonArgentScreen` now passes the same fresh-aware budget snapshot into
  `CoachWhisperService` as it passes into the budget card.
- When `BudgetProvider` has fresh profile inputs, the whisper falls back to
  those inputs instead of a stale `DataSpine` budget deficit.
- Added a widget regression where the visible budget is fresh but the stored
  spine contains an obsolete negative monthly free amount.

## Verification

- TDD: the new widget test failed before the production change because
  `Mois serre` was still rendered from the stale spine.
- `flutter test test/screens/mon_argent_screen_test.dart --name "fresh profile budget also grounds coach whisper over stale spine"`
- `flutter test test/screens/mon_argent_screen_test.dart test/services/mon_argent_coach_whisper_service_test.dart`
- `flutter analyze lib/screens/mon_argent/mon_argent_screen.dart test/screens/mon_argent_screen_test.dart`
- `git diff --check`
- Claude Opus 4.7 review: `NO_BLOCKING_FINDINGS`

## Notes

- The test uses `find.textContaining('Mois serré.')` because the UI prefixes the
  whisper with an icon; exact text without the prefix gave a false pass.
