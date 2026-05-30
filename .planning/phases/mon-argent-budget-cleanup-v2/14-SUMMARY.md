# Phase 14 — 3a pedagogical pressure copy cleanup

## Goal

Remove pressure and overpromise wording from the remaining 3a pedagogical surfaces while preserving the useful educational idea: a 3a contribution can have an estimated tax impact depending on the user's situation.

## Changes

- Softened the 3a before/after tax copy across FR/EN/DE/ES/IT/PT:
  - Removed "lost deduction" / "full tax rate" penalty framing.
  - Replaced it with conditional, mechanical tax-deduction wording.
- Softened `coachInterrupt3aUnderMax` across six locales:
  - Removed "money/tax saving on the table" phrasing.
  - Replaced it with "remaining 3a room to verify" plus estimated tax saving.
- Softened `ctxHeroStat3aLabel` across six locales:
  - Removed "leaving money on the table".
  - Replaced it with a neutral remaining-room label.
- Updated `Countdown3aWidget`:
  - Removed "impots en moins" and "laisses sur la table".
  - Uses estimated fiscal saving wording in both incomplete and complete states.
  - Uses informational color when room remains instead of critical red.
- Added widget regression checks for the softened copy and the completed-state wording.

## Verification

- `flutter gen-l10n`
- `validate_arb_parity` -> OK, 6 locales, 6812 keys each
- `check_accent_patterns` -> clean
- `check_banned_terms` -> clean
- `git -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol diff --check` -> clean
- `flutter test test/widgets/coach/countdown_3a_widget_test.dart` -> 10 passed
- `flutter analyze lib/widgets/coach/countdown_3a_widget.dart test/widgets/coach/countdown_3a_widget_test.dart lib/l10n/app_localizations_fr.dart lib/l10n/app_localizations_en.dart` -> no issues
- Claude Opus 4.7 review -> PASS

## Notes

- Claude initially returned concerns: the no-action sibling copy still had penalty framing, the widget color still used `scoreCritique`, and the completed state lacked a direct assertion. All three were fixed before commit.
- `Countdown3aWidget` is stored as CRLF in git, so the diff-check command explicitly allows CR at EOL for this phase.
