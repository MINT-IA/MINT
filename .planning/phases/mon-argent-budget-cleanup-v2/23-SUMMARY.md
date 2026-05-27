---
phase: mon-argent-budget-cleanup-v2
plan: 23
status: complete
created_at: 2026-05-27
branch: codex/mon-argent-budget-cleanup-v2
type: arbitrage-summary-trust-copy
---

# Plan 23 - Neutral Arbitrage Summary Copy

## Goal

Prevent the arbitrage summary layer and dashboard teasers from reintroducing
winner/promise language above the now-neutral financial core.

## Changes

- Replaced "L'option..." / "pourrait donner" rente-vs-capital copy with
  neutral simulated-flow-gap language.
- Replaced "pourrait economiser" / "pourrait reduire ton impot" fiscal copy
  with `Impact fiscal indicatif`.
- Replaced location-vs-propriete "acheter/rester locataire" winner copy with
  a neutral simulated net-wealth gap.
- Replaced the allocation key insight that claimed a post-tax return is often
  superior with a dependency statement covering marginal tax rate, return and
  liquidity need.
- Normalized couple sequencing summary fields to a neutral impact line instead
  of forwarding the LPP calculator recommendation text.
- Hardened tests to scan title, verdict, key insight and embedded full-result
  narrative fields for ranking/promise fragments.

## Verification

- Red tests first:
  - `arbitrage_summary_service_test` caught `l'option`, `pourrait reduire`,
    `economie fiscale`, `pourrait generer`, `superieur`.
  - `arbitrage_teaser_card_test` caught `L'option ... pourrait donner`.
- Targeted tests:
  `flutter test test/services/arbitrage_summary_service_test.dart test/widgets/dashboard/arbitrage_teaser_card_test.dart`
- Broader arbitrage regression:
  `flutter test test/services/arbitrage_summary_service_test.dart test/widgets/dashboard/arbitrage_teaser_card_test.dart test/services/financial_core/arbitrage_engine_fields_test.dart test/services/financial_core/arbitrage_engine_hero_fields_test.dart test/services/financial_core/arbitrage_engine_rachat_antiabuse_test.dart`
- Analyzer:
  `flutter analyze lib/services/arbitrage_summary_service.dart lib/widgets/dashboard/arbitrage_teaser_card.dart test/services/arbitrage_summary_service_test.dart test/widgets/dashboard/arbitrage_teaser_card_test.dart`
- Diff hygiene:
  `git diff --check`
- MCP compliance tools:
  - `check_accent_patterns`: clean
  - `check_banned_terms`: clean
- Claude Opus 4.7 review:
  `NO_BLOCKING_FINDINGS`

## Notes

Claude flagged one non-blocking robustness improvement: include both straight
and typographic apostrophe forms in the `l option` service regression.
