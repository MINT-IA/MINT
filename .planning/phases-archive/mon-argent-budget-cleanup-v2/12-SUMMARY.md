# Phase 12 — Mobile 3a notification wording alignment

## Goal

Align mobile 3a calendar notifications with the backend Phase 11 wording so MINT never presents deductible room as a guaranteed or raw tax saving.

## Changes

- Replaced mobile 3a fallback notification copy from generic `Economie estimee` to `Economie fiscale estimee`.
- Replaced new-year 3a copy from `economie potentielle a change` to `marge deductible peut changer`.
- Updated FR/EN/DE/ES/IT/PT ARB strings and regenerated checked-in localizations.
- Added regression tests for:
  - Jan 5 new-year notification blocking `economie potentielle`.
  - Nov 1 and Dec 1 3a notifications using `Economie fiscale estimee`.
  - Nov 1 and Dec 1 blocking bare `Economie estimee` and `en jeu`.

## Verification

- `flutter gen-l10n`
- `validate_arb_parity` -> OK, 6 locales, 6812 keys each
- `check_accent_patterns` -> clean
- `check_banned_terms` -> clean
- `flutter analyze lib/services/notification_scheduler_service.dart test/services/notification_scheduler_service_test.dart lib/l10n/app_localizations_fr.dart lib/l10n/app_localizations_en.dart` -> no issues
- `flutter test test/services/notification_scheduler_service_test.dart` -> 26 passed
- `git diff --check` -> clean
- Claude Opus 4.7 review -> PASS

## Notes

- This completes the backend/mobile notification copy alignment for the 3a trust issue surfaced by the user.
- Remaining similar surface for a next phase: backend reengagement copy still contains older `economie potentielle` / `economie en jeu` phrasing.
