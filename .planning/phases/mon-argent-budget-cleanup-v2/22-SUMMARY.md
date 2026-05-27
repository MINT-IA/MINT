---
phase: mon-argent-budget-cleanup-v2
plan: 22
status: complete
created_at: 2026-05-27
branch: codex/mon-argent-budget-cleanup-v2
type: financial-core-compliance-fix
---

# Plan 22 - Neutral Location Arbitrage Copy

## Goal

Remove ranking/prescriptive language from the location vs propriete arbitrage
copy while preserving the calculation output and explanatory value.

## Changes

- Replaced the display summary branch that said one option "domine" with
  neutral trade-off language about liquidity, flexibility and fees.
- Tightened French accents in the same visible output block:
  - FINMA theoretical-charge alert
  - market/property/mortgage assumptions
  - LSFin educational disclaimer
  - LIFD/FINMA source labels
- Added a grid regression test that exercises multiple capital, rent and
  property-price cases and fails if visible output contains ranking terms:
  `domine`, `meilleur`, `optimal`.

## Verification

- Red test first: the new no-ranking regression failed against the previous
  `une option domine` copy.
- Targeted test suite:
  `flutter test test/services/financial_core/arbitrage_engine_fields_test.dart test/services/financial_core/arbitrage_engine_hero_fields_test.dart test/services/financial_core/arbitrage_engine_rachat_antiabuse_test.dart`
- Analyzer:
  `flutter analyze lib/services/financial_core/arbitrage_engine.dart test/services/financial_core/arbitrage_engine_fields_test.dart`
- Diff hygiene:
  `git diff --check`
- MCP compliance tools:
  - `check_accent_patterns`: clean
  - `check_banned_terms`: clean
- Claude Opus 4.7 review:
  `NO_BLOCKING_FINDINGS`

## Notes

This keeps the arbitrage engine aligned with MINT's LSFin posture: show the
trajectory, assumptions, constraints and risk context, but do not name a winner.
