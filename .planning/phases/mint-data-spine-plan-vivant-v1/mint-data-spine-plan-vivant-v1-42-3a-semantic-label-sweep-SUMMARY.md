# Summary 42 — 3a semantic label sweep

## Outcome

The 3a first-job plan step and onboarding card fixture now label `7'258 CHF`
as deductible contribution room, not as a tax reduction.

## Changes

- Rewrote `capStepFirstJob04Desc` in fr/en/de/es/it/pt.
- Regenerated `app_localizations*.dart`.
- Updated the `PremierEclairageCard` fixture title to `Ton montant 3a déductible`.
- Added regression assertions in `cap_sequence_engine_test.dart` and
  `premier_eclairage_card_test.dart`.

## Verification

- `flutter gen-l10n`
- `validate_arb_parity()` MCP: 6 locales, 6804 keys each.
- `check_banned_terms()` MCP on the corrected French copy.
- `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb --file apps/mobile/test/services/cap_sequence_engine_test.dart --file apps/mobile/test/widgets/onboarding/premier_eclairage_card_test.dart`
- `flutter test test/services/cap_sequence_engine_test.dart test/widgets/onboarding/premier_eclairage_card_test.dart`
- `flutter analyze lib/services/cap_sequence_engine.dart test/services/cap_sequence_engine_test.dart test/widgets/onboarding/premier_eclairage_card_test.dart`
- `git diff --check`
