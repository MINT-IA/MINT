# Phase 33 — LAMal and 3a trust copy hardening

## Goal

Remove deterministic savings/recommendation wording from visible LAMal, 3a, and couple education copy.

## Findings

- The product/compliance subagent found remaining trust-breaking phrases such as “économiser jusqu’à CHF 1’500/an”, “recommandé : CHF 1’500”, “Conseillé si maladies chroniques”, “Déduction fiscale directe”, “plus de 200’000 CHF”, and “perdent jusqu’à CHF 8’000/an”.
- These phrases were educational strings, but visually they read like advice or acquisition promises without user-specific assumptions.

## Changes

- Reframed LAMal deductible copy around total cost: premium + deductible/franchise + coinsurance/quote-part.
- Reframed 3a copy as taxable-income deductibility depending on situation, with explicit dependence on contributions, return, fees, and withdrawal tax.
- Reframed couple copy as scenario comparison instead of missed-optimization loss.
- Extended `fiscal_trust_copy_test.dart` to guard the newly cleaned keys across fr/en/de/es/it/pt.

## Verification

- `flutter test test/l10n/fiscal_trust_copy_test.dart`
- `flutter analyze lib/l10n/app_localizations_fr.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_de.dart lib/l10n/app_localizations_es.dart lib/l10n/app_localizations_it.dart lib/l10n/app_localizations_pt.dart test/l10n/fiscal_trust_copy_test.dart`
- MCP `validate_arb_parity`: OK, 6 locales, 6813 keys each
- MCP `check_banned_terms`: clean on the revised French copy
