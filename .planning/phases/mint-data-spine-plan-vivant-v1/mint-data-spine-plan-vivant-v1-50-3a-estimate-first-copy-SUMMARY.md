# Summary 50 — 3a estimate-first copy

## Outcome

The 3a simulator now frames tax output as an estimated impact and frames the
education section as scenarios to compare.

## Changes

- Replaced `Gain fiscal annuel` with `Impact fiscal estimé`.
- Replaced `Économie fiscale cumulée` with `Impact fiscal cumulé estimé`.
- Replaced `Stratégie gagnante` with `Scénarios à comparer`.
- Rewrote the 100% equity guidance as a risk/return scenario instead of
  capital-maximizing language.
- Updated all 6 ARB locales and regenerated Flutter localizations.
- Updated `flow_3a_calculator.yaml`, `flow_fatca_3a_gate.yaml`, and the
  Maestro flow README.

## Verification

- Red test first: `flutter test test/screens/simulator_screens_smoke_test.dart`
  failed on missing `Impact fiscal estimé`.
- Green after copy update: `flutter test test/screens/simulator_screens_smoke_test.dart`.
- `flutter analyze lib/l10n test/screens/simulator_screens_smoke_test.dart`.
- `python3 tools/checks/arb_parity.py`.
- MCP `validate_arb_parity`.
- MCP `check_banned_terms` and `check_accent_patterns` on the new French copy.
- `python3 tools/checks/wiki_lint.py lint` passed with historical warnings only.
- iOS simulator debug build with `MINT_E2E_ARCHETYPE=julien_swiss`.
- Maestro `flow_3a_calculator.yaml` passed on iPhone 17 Pro after reinstalling
  the new build.
