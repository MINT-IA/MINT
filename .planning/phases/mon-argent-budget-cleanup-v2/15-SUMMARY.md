# Phase 15 — Fiscal coaching shock-copy cleanup

## Goal

Remove remaining tax-shock wording from coaching suggestions and local notification copy, while keeping useful educational language around estimated tax impact.

## Changes

- Softened `coachSuggestTaxImpact` across FR/EN/DE/ES/IT/PT from "less tax" framing to "estimate the tax impact".
- Softened day-7 notification copy across six locales:
  - Removed "money with the taxman" framing.
  - Replaced it with "3a room to verify" plus an estimated monthly amount.
- Softened `chocQuestionTaxSaving` across six locales:
  - Removed "CHF X less in taxes / worth 10 minutes".
  - Replaced it with "estimated tax saving" and scenario verification.
- Softened `coachGreetingRandom17` across six locales:
  - Removed "pay thousands less" and "but you would have to open the certificate".
  - Replaced it with a neutral LPP buyback impact statement.
- Updated the French fallback in `NotificationStrings.french` to match the new day-7 notification wording.

## Verification

- `flutter gen-l10n`
- `validate_arb_parity` -> OK, 6 locales, 6812 keys each
- `check_accent_patterns` -> clean
- `check_banned_terms` -> clean
- `git -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol diff --check` -> clean
- `flutter analyze lib/services/notification_service.dart lib/services/coach_llm_service.dart lib/screens/coach/coach_chat_screen.dart lib/l10n/app_localizations_fr.dart lib/l10n/app_localizations_en.dart` -> no issues
- Targeted `rg` for removed shock phrases -> no matches in touched surfaces
- Claude Opus 4.7 review -> PASS

## Notes

- Claude flagged NBSP as a minor observation; the FR ARB day-7 question was byte-checked and contains `c2 a0` before `?`.
- This phase deliberately does not touch simulator result labels where "economy/saving" is a computed financial output rather than a pressure CTA.
