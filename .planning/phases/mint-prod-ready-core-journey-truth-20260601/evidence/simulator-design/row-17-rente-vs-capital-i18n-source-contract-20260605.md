# Row 17 — Rente vs Capital i18n + Source Contract — 2026-06-05

## Claim

Canonical `/rente-vs-capital` now has deterministic local proof for two
trust-quality contracts:

- the financial result produced by `ArbitrageEngine.compareRenteVsCapital()`
  carries an LSFin educational disclaimer and legal sources including
  `LPP art. 14` and `LIFD art. 38`;
- the warning label and core Row 17 user-facing labels are localized in the
  supported non-French locales instead of leaking French fragments such as
  `Ton age`, `{age} ans`, `/mois`, `A {age} ans`, `Rien`, or `Dans 20 ans`.

This does **not** close Row 17. It closes the local i18n/source-contract slice
only. Runtime scroll proof for the disclaimer card, accessibility semantics,
dynamic type, chart semantics, and broader top-simulator review remain open.

## Deterministic Evidence

Commands:

```bash
cd apps/mobile
flutter gen-l10n
flutter test test/screens/arbitrage_screens_smoke_test.dart
flutter analyze test/screens/arbitrage_screens_smoke_test.dart \
  lib/l10n/app_localizations_en.dart \
  lib/l10n/app_localizations_de.dart \
  lib/l10n/app_localizations_es.dart \
  lib/l10n/app_localizations_it.dart \
  lib/l10n/app_localizations_pt.dart
```

MCP ARB parity:

```text
OK — 6 locale(s) parity (reference=fr, 6871 keys each).
```

Results:

- `flutter test test/screens/arbitrage_screens_smoke_test.dart`: `26` tests
  passed.
- Targeted `flutter analyze`: no issues.
- ARB parity: `ok`, `6871` keys each.

## Covered Contracts

Tests added:

- `engine result includes warning disclaimer and legal sources`
- `warning label is localized in the 6 supported locales`
- `core Row 17 labels are localized outside French`

Corrected locales:

- EN/DE/ES/IT/PT warning labels;
- EN/DE/ES/IT/PT core labels around age, monthly unit, chart axis, age delta,
  inflation, transmission/inheritance, and single-person survivor wording;
- ES/IT/PT `renteVsCapitalHypInflation`.

## Remaining Gaps

- 2026-06-05 addendum: the widget-level lower disclaimer-card reachability and
  semantic identifier gap is now covered by CJT-044 at
  `row-17-rente-vs-capital-semantic-disclaimer-contract-20260605.md`. Runtime
  Maestro screenshot proof remains open.
- CJT-042 did not prove that the lower disclaimer card was reachable by
  widget/runtime scroll; CJT-044 now covers widget reachability only.
- Text-field labels and advanced controls still need explicit semantic proof.
- Charts need accessible summaries, not only generic chart labels.
- Dynamic type and tap-target checks for `/rente-vs-capital` are still open.
- The broader top-simulator source/disclaimer/i18n/accessibility audit remains
  open.
