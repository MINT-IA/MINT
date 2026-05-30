phase: mon-argent-budget-cleanup-v2
plan: 44
title: Tier A budget return display alignment
branch: codex/mon-argent-budget-cleanup-v2
date: 2026-05-27

# Phase 44 — Tier A budget return display alignment

The Budget screen's Tier A sequence return already emitted displayed fixed
charges, but still emitted raw decimal net income. Sequence summaries and coach
reactions can consume these step outputs, so `revenu_net` now follows the same
display CHF contract as the visible Budget read model.

## Changes

- `_emitFinalReturn()` now emits
  `PresentBudgetBuilder.displayChf(inputs.netIncome)` for `revenu_net`.
- The routeExtra smoke test now uses fractional inputs and asserts
  `revenu_net` directly against `PresentBudgetBuilder.displayChf(...)`.
- `PresentBudgetBuilder.displayChf()` now documents the Dart rounding contract
  and that values remain doubles for JSON map consumers.

## Red-Green Evidence

- The focused routeExtra test failed before the fix:
  expected `8000`, actual `8000.4`.
- After the fix, the test passes and `charges_totales` remains the canonical
  rounded fixed-charge sum.

## Verification

- `flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetContainerScreen routeExtra emits Tier A return on pop"` — PASS.
- `flutter test test/screens/budget_screen_smoke_test.dart test/domain/budget/present_budget_builder_test.dart test/services/sequence/sequence_summary_builder_test.dart` — PASS, 31 tests.
- `flutter analyze lib/domain/budget/present_budget_builder.dart lib/screens/budget/budget_screen.dart test/screens/budget_screen_smoke_test.dart` — PASS.
- `python3 tools/checks/prefer_mint_cta.py --file apps/mobile/lib/screens/budget/budget_screen.dart` — PASS.
- `git diff --check` — PASS.
- Opus review verdict: no blockers. Requested direct `revenu_net` assertion and
  downstream grep; direct assertion was added, and grep found sequence summary
  consumers read `revenu_net` as `num` then `toDouble()`, not `as double`.
