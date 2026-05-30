# Phase 10 - Coach 3a opener trust regression

## Goal

Prevent the coach chat opener from presenting the CHF 7'258 3a legal ceiling as a tax saving.

## Changes

- Strengthened the `CoachChatScreen` precomputed-insight regression.
- The test now requires the 3a opener to call CHF 7'258 a deductible room.
- The test explicitly blocks:
  - `economie d'impot` wording;
  - `en jeu` pressure wording;
  - raw `7258 CHF` formatting.

## Verification

- `flutter test test/screens/coach/precomputed_insight_opener_test.dart --plain-name 'cached fresh insight surfaces RouteSuggestionCard chip + clears cache'`
- `flutter test test/screens/coach/precomputed_insight_opener_test.dart`
- `flutter analyze test/screens/coach/precomputed_insight_opener_test.dart`
- Claude Opus 4.7 review: `PASS`.

## Follow-up

- Backend notification and narrator paths still contain legitimate 3a ceiling/tax-saving wording. They should be audited separately so every surface distinguishes deductible amount, contribution room, and estimated tax saving.
