phase: mon-argent-budget-cleanup-v2
plan: 41
title: Budget Tier A charges include debt
branch: codex/mon-argent-budget-cleanup-v2
date: 2026-05-27

# Phase 41 — Budget Tier A charges include debt

Budget screen returns used by sequence/navigation memory must carry the same
charge total as the visible budget read model. `_emitFinalReturn()` was
recomputing fixed charges locally and omitted debt repayments, while
`PresentBudgetBuilder.fixedChargesFromInputs()` already includes them.

## Changes

- `BudgetScreen._emitFinalReturn()` now uses
  `PresentBudgetBuilder.fixedChargesFromInputs(inputs)`.
- The route-extra Tier A return test now includes CHF 333 of monthly debt and
  expects `charges_totales` to equal the same helper result as the visible
  budget read model.
- The test was first run red at `3570` before the code fix, proving the drift.

## Contract Audit

- `rg "charges_totales"` found no backend consumer.
- Mobile consumers are sequence templates and `SequenceSummaryBuilder`; they
  display `charges_totales` as charges, and do not re-add debt separately.
- Backend coach context uses `budget.monthly_charges`, not this Tier A
  `charges_totales` key.

## Verification

- Red test before fix:
  `flutter test test/screens/budget_screen_smoke_test.dart --plain-name "BudgetContainerScreen routeExtra emits Tier A return on pop"` — FAIL, actual `3570.0`.
- Green targeted test after fix — PASS.
- `flutter test test/screens/budget_screen_smoke_test.dart` — PASS.
- `flutter analyze lib/screens/budget/budget_screen.dart test/screens/budget_screen_smoke_test.dart` — PASS.
- `git diff --check` — PASS.
- `python3 tools/checks/prefer_mint_cta.py --file apps/mobile/lib/screens/budget/budget_screen.dart` — PASS.
