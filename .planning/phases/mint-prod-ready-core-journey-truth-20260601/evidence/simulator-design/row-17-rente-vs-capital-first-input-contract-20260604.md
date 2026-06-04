---
description: Row 17/23 proof for the canonical Rente vs Capital first-input contract.
status: verified
date: 2026-06-04
---

# Row 17/23 — Rente vs Capital First-Input Contract

## Finding

Canonical `/rente-vs-capital` still exposed secondary parameters directly in
the first input surface:

- annual LPP buyback
- EPL withdrawal
- canton
- marital status

The estimate-mode income field also used salary-only copy. For a Swiss
retirement decision surface, that is too narrow: MINT must support employment,
self-employment, mixed income, rents, allowances, transition periods, and
wealth-funded situations.

## Change

- Reworded the visible estimate input from salary to gross annual income across
  FR/EN/DE/ES/IT/PT.
- Reworded the projection source copy from salary to income across 6 locales.
- Added `renteVsCapitalAdvancedParameters` across 6 locales.
- Moved buyback, EPL, canton, and marital-status inputs into a collapsed
  advanced section by default.
- Left calculation behavior unchanged.

## Proof

- Red proof: `flutter test test/screens/arbitrage_screens_smoke_test.dart --plain-name "keeps first decision inputs neutral and advanced fields folded"` failed before the fix because `Ton revenu brut annuel (CHF)` was absent.
- Green proof: same targeted test passed after the fix.
- Full arbitrage smoke: `flutter test test/screens/arbitrage_screens_smoke_test.dart` passed (`23 tests`).
- Analyze: `flutter analyze lib/screens/arbitrage/rente_vs_capital_screen.dart test/screens/arbitrage_screens_smoke_test.dart` passed.
- ARB parity: `python3 tools/checks/arb_parity.py --arb-dir apps/mobile/lib/l10n` passed (`6871` keys each).
- MCP ARB parity: `validate_arb_parity` passed (`6` locales / `6871` keys).
- Guardrails: `python3 tools/checks/cjt_context_guard.py` and `git diff --check` passed.

## Scope

This improves Row 17 and Row 23 locally, but does not close either row. The
remaining gate is runtime/visual/source/disclaimer review for canonical
`/rente-vs-capital` and broader primary-screen accessibility evidence.
