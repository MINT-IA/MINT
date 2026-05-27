# Phase 30 — Debt report copy trust gate

Date: 2026-05-27

## Goal

Remove promise-style debt arbitrage copy from the financial report action text.
The old wording framed debt repayment as the "most profitable investment" and
said the user "saves" 6-10% per year.

## Change

- Rewrote `reportActionDescDette` in all six ARB locales to conditional,
  rate-dependent wording:
  - debt reduction can lower future interest costs;
  - the impact depends on the debt rate.
- Updated the generated localization Dart files with the same strings without
  committing `flutter gen-l10n` line-ending churn.
- Added `reportActionDescDette` to the fiscal trust l10n regression test.
- Added positive per-locale assertions requiring both:
  - a conditional modal (`peut`, `can`, `kann`, `puede`, `può`, `pode`);
  - a rate-dependency clause.

## Files

- `apps/mobile/lib/l10n/app_*.arb`
- `apps/mobile/lib/l10n/app_localizations*.dart`
- `apps/mobile/test/l10n/fiscal_trust_copy_test.dart`

## Verification

- Red-first check: fiscal trust l10n test failed on the old six translations.
- `flutter gen-l10n` was run; generated churn was restored and only the needed
  generated string lines were updated.
- `flutter test test/l10n/fiscal_trust_copy_test.dart` — PASS.
- `flutter analyze test/l10n/fiscal_trust_copy_test.dart lib/l10n/app_localizations*.dart` — PASS.
- `git diff --check` — PASS.
- `validate_arb_parity` — PASS, 6813 keys in each of 6 locales.
- MCP copy checks on the six new strings — clean.
- Claude Opus 4.7 review:
  - Verdict: PASS.
  - Blocking findings: none.
  - Applied non-blocking notes for stronger positive test assertions and more
    idiomatic DE/IT/PT financial register.

## Self-evaluation

Accuracy/effectiveness: 9/10.

Why not 10: the 6-10% range is still a copy fallback. A full production-grade
version should derive the range from the user's actual debt rate and confidence
band.

How to make it 10: move debt-rate data into the user financial situation model,
then render this action with a precise user-specific rate when known and a
clearly labelled fallback range when unknown.
