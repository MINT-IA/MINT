# Phase 13 — Reengagement 3a trust wording

## Goal

Remove the same 3a trust issue from backend and mobile reengagement messages: a ceiling is not a tax saving, and a tax saving must be framed as estimated.

## Changes

- Backend reengagement:
  - January now says the 3a ceiling/deductible room may change.
  - October, November, and December now say `Économie fiscale estimée`.
  - December no longer says `d'economie en jeu`.
- Mobile reengagement:
  - January now uses the formatted 3a ceiling and deductible-room wording.
  - October, November, and December now say `Économie fiscale estimée`.
- Added backend and mobile regressions blocking:
  - `économie potentielle`
  - `en jeu`
  - ceiling-as-tax-saving confusion

## Verification

- Backend TDD first: new tests failed on the old copy, then passed after implementation.
- `pytest tests/test_reengagement.py -q` -> 27 passed
- `ruff check app/services/reengagement/reengagement_engine.py tests/test_reengagement.py` -> passed
- `flutter test test/services/reengagement_engine_test.dart` -> 24 passed
- `flutter analyze lib/services/reengagement_engine.dart test/services/reengagement_engine_test.dart` -> no issues
- `check_accent_patterns` -> clean
- `check_banned_terms` -> clean
- Claude Opus 4.7 review -> PASS

## Notes

- The backend reengagement files are stored as CRLF in git. They were kept CRLF to avoid a noisy line-ending-only diff; review with `git diff --ignore-space-at-eol`.
