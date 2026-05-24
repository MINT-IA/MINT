# Plan 14 — Budget capture readiness summary

## Goal

Make budget readiness honest by separating explicit user-entered budget facts
from `CoachProfile.fromWizardAnswers` fallback values.

## Changed

- `CoachProfile.fromWizardAnswers` now marks explicit budget/cash/debt answers
  in `userProvidedFields` and `dataSources`.
- `DataSpineService` only exposes housing, LAMal, liquid savings, and debt as
  situation facts when explicit or from a trusted source.
- Explicit zero debt is now a known situation value.
- `BudgetSetupScreen` avoids pre-filling default budget values as if they were
  user-entered and exposes stable test keys.
- Added a widget test proving `BudgetSetupScreen` persists canonical budget
  keys through `ReportPersistenceService`.

## Verification

- `flutter test test/services/data_spine_service_test.dart test/services/data_spine_readiness_digest_service_test.dart test/screens/budget_setup_screen_test.dart` — PASS.
- `flutter analyze lib/models/coach_profile.dart lib/services/data_spine/data_spine_service.dart lib/screens/budget/budget_setup_screen.dart test/services/data_spine_service_test.dart test/screens/budget_setup_screen_test.dart` — PASS.
- `python3 tools/checks/prefer_mint_cta.py --file apps/mobile/lib/screens/budget/budget_setup_screen.dart` — PASS.
- `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb` — PASS.
- `python3 tools/checks/wiki_lint.py lint` — PASS with historical warnings only.
- `git -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol diff --check` — PASS.

## Notes

- No new route, backend path, ARB key, or budget engine was added.
- The raw buttons in `BudgetSetupScreen` remain legacy and are locally
  lint-ignored pending CTA unification.
