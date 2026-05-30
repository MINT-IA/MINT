phase: mon-argent-budget-cleanup-v2
plan: 43
title: BudgetService canonical display read model
branch: codex/mon-argent-budget-cleanup-v2
date: 2026-05-27

# Phase 43 — BudgetService canonical display read model

`BudgetService.computePlan()` still computed `available`, distress and the
first budget insight from raw input decimals. Budget, Mon Argent and the coach
packet now display integer CHF read models, so this could recreate one-franc
trust drift between the screen, widgets and LLM-visible facts.

## Changes

- `BudgetService` now uses `PresentBudgetBuilder.displayChf()` for monthly net
  income and `PresentBudgetBuilder.fixedChargesFromInputs()` for fixed charges.
- `available`, `premierEclairage`, `BudgetPlan.distress` and `chargesRatio`
  now all derive from the same displayed CHF operands.
- Critical copy now says charges "atteignent ou dépassent" the income at the
  100% boundary instead of only "dépassent".
- `CoachContextPacketService` has a regression test proving budget facts sent
  to the coach come from the Data Spine displayed budget snapshot.

## Red-Green Evidence

- Added a fractional `BudgetService.computePlan()` test. It failed before the
  fix with raw `2797.9` available instead of displayed `2795`; it passed after
  canonical display math.
- Added threshold tests proving 70% and 100% distress decisions use displayed
  CHF values rather than raw cents.
- Added the identity check:
  `available + displayed fixed charges == displayed monthly net`.
- Added a coach packet test ensuring `budget.monthly_net`,
  `budget.monthly_charges` and `budget.monthly_free` come from the displayed
  `DataSpineSnapshot`.

## Verification

- `flutter test test/domain/budget test/services/coach_context_packet_service_test.dart test/services/mon_argent_coach_whisper_service_test.dart test/screens/budget_screen_smoke_test.dart` — PASS, 128 tests.
- `flutter analyze lib/domain/budget/budget_service.dart test/domain/budget/budget_service_test.dart test/services/coach_context_packet_service_test.dart` — PASS.
- `python3 tools/checks/prefer_mint_cta.py --file apps/mobile/lib/screens/budget/budget_screen.dart` — PASS.
- `git diff --check` — PASS.
- Opus review verdict: no blockers. The initial review requested
  PresentBudgetBuilder and coach packet verification; both were added and the
  final Opus review confirmed the concerns were sufficiently covered.
