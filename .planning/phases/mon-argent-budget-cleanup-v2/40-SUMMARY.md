phase: mon-argent-budget-cleanup-v2
plan: 40
title: Budget hero de-duplication
branch: codex/mon-argent-budget-cleanup-v2
date: 2026-05-27

# Phase 40 — Budget hero de-duplication

Opus review identified the Budget screen's main redundancy: the hero exposed the
answer and a full row-by-row breakdown, then the expanded calculation detail
repeated the same decomposition. For a mobile financial app, the first viewport
should state the answer; the proof should live behind the detail affordance.

## Changes

- Budget hero now shows one large monthly remainder plus one compact formula.
- The row-by-row breakdown was removed from the hero.
- Indebted users keep an immediate trust signal in the hero:
  `Remboursement dettes: CHF ...`.
- The compact formula has a dedicated semantics identifier and avoids duplicate
  screen-reader labels.
- `_BudgetFlowMap` and `budget_formula_proof` remain the calculation proof
  surface used by tests and Maestro after the detail section is expanded.
- No new read model, provider, route, or ARB key was added.

## Verification

- `flutter test test/screens/budget_screen_smoke_test.dart` — PASS.
- `flutter analyze lib/screens/budget/budget_screen.dart test/screens/budget_screen_smoke_test.dart` — PASS.
- `flutter test test/screens/budget_screen_smoke_test.dart test/services/budget_living_engine_test.dart test/widgets/mon_argent_budget_summary_card_test.dart` — PASS.
- `git diff --check` — PASS.
- MCP `validate_arb_parity` — PASS, 6 locales, 6813 keys each.
- MCP banned-term/accent checks on the new debt copy — PASS.
- iOS simulator build/install with `MINT_E2E_ARCHETYPE=julien_swiss` — PASS.
- Maestro `flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml` —
  PASS in 1m02s, artifacts under
  `.planning/walker/maestro-flows/money-trust-chain/20260527T161738Z/`.

## Opus Review Notes

- Opus agreed with the de-duplication principle: the hero should state the
  answer, while proof belongs in the expanded calculation detail.
- Opus flagged indebted-user trust as the main risk. The phase now keeps a
  visible debt repayment disclosure and tests it from `CoachProfile` hydration.
- Opus requested coverage for the zero-future branch. The phase now asserts the
  two-term formula and verifies no `CHF 0` future subtraction is shown.
- Final Opus review verdict: mergeable, no blockers.
