phase: mon-argent-budget-cleanup-v2
plan: 45
title: LPP report gain copy uses estimated tax impact
branch: codex/mon-argent-budget-cleanup-v2
date: 2026-05-27

# Phase 45 — LPP report gain copy uses estimated tax impact

The financial report still labelled the visible LPP buyback amount as a
possible saving in all six locales. That is too close to the trust bug class
where a deductible amount or projected tax effect is read as a guaranteed
cash gain.

## Changes

- Reworded `reportTaxSavings` across `fr/en/de/es/it/pt` from saving language
  to estimated tax-impact language.
- Regenerated Flutter localizations and normalized generated line endings back
  to LF after `flutter gen-l10n` emitted CRLF locally.
- Added an ARB regression test that requires the six locale anchors and rejects
  saving-language fragments for `reportTaxSavings`; after Opus review, the
  test also locks the `{amount}` placeholder.

## Verification

- `flutter gen-l10n` — PASS.
- `flutter test test/services/financial_report_service_test.dart --plain-name "lpp buyback visible gain label remains an estimated tax impact"` — PASS.
- `flutter test test/services/financial_report_service_test.dart` — PASS, 73 tests.
- `flutter analyze lib/l10n/app_fr.arb test/services/financial_report_service_test.dart` — PASS.
- `validate_arb_parity()` MCP — PASS, 6 locales × 6807 keys.
- `check_banned_terms(...)` on the new FR/EN/DE copy — clean.
- `check_accent_patterns(...)` on the FR copy — clean.
- `git diff --check` — PASS after LF normalization.
- First Claude Opus CLI review attempt — INCONCLUSIVE: the non-interactive run
  reached `error_max_turns` after tool calls and returned no final verdict.
- Focused no-tools Claude Opus 4.7 review on the diff — APPROVE, no blockers;
  nit about `{amount}` placeholder coverage was applied.
