# Summary 41 — 3a opener tax wording guard

## Outcome

The coach savings-opportunity opener no longer labels the 3a ceiling as a tax
reduction. It now describes the amount as still deductible contribution room.

## Root Cause

`DataDrivenOpenerService` correctly passed the 3a ceiling as `plafond`, but the
French ARB string rendered that same value as `économie d'impôt`. The error was
in i18n copy, not in a tax calculator.

## Changes

- Rewrote `openerSavingsOpportunity` in fr/en/de/es/it/pt ARB files.
- Regenerated `app_localizations*.dart`.
- Added a regression assertion in
  `test/services/coach/data_driven_opener_service_test.dart`.

## Verification

- `flutter gen-l10n`
- `validate_arb_parity()` MCP: 6 locales, 6804 keys each.
- `check_banned_terms()` MCP on the French message.
- `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb`
- `flutter test test/services/coach/data_driven_opener_service_test.dart`
- `flutter analyze lib/services/coach/data_driven_opener_service.dart test/services/coach/data_driven_opener_service_test.dart`
- `flutter test test/services/coach test/screens/coach/precomputed_insight_opener_test.dart`
- `rg` negative scan for the old wording across l10n, coach services, and tests.
