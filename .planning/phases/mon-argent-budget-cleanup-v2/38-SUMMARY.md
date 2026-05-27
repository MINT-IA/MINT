phase: mon-argent-budget-cleanup-v2
plan: 38
title: Budget-first coach opener
branch: codex/mon-argent-budget-cleanup-v2
date: 2026-05-27

# Phase 38 — Budget-first coach opener

Live Maestro proved that Budget, Mon Argent, and Rapport were aligned, but the
Coach still opened on a generic 3a deductible-room message after the user had
just entered budget facts. That was technically safe after the 3a wording fix,
but product-wise wrong: the Coach should acknowledge the freshest concrete
financial context.

## Changes

- Added `DataOpenerType.budgetRoom`.
- `DataDrivenOpenerService.generate()` now acknowledges a positive present-only
  monthly budget margin before generic 3a opportunities.
- `PrecomputedInsightsService` stores and resolves the new opener type through
  the existing `budgetSetupResteAfterCharges` i18n key, avoiding new ARB churn.
- Maestro now expects Coach to surface `CHF 1'922` and `après tes charges`
  after the Budget -> Mon Argent -> Rapport flow, and guards that the generic
  `Ton 3a` / `déductibles` opener is absent in this path.
- The two touched Maestro flows now erase prefilled budget fields before
  entering amounts. This keeps simulator runs deterministic when launched with
  the `julien_swiss` E2E archetype.

## Verification

- `cd apps/mobile && flutter test test/services/coach/data_driven_opener_service_test.dart test/services/coach/precomputed_insights_service_test.dart`
  - Result: `39 passed`.
- `cd apps/mobile && flutter test test/services/budget_living_engine_test.dart test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart test/services/coach_context_packet_payload_test.dart test/widgets/mon_argent_budget_summary_card_test.dart test/services/coach/data_driven_opener_service_test.dart test/services/coach/precomputed_insights_service_test.dart`
  - Result: `110 passed`.
- `cd apps/mobile && flutter analyze lib/services/coach/data_driven_opener_service.dart lib/services/coach/precomputed_insights_service.dart test/services/coach/data_driven_opener_service_test.dart test/services/coach/precomputed_insights_service_test.dart`
  - Result: no issues.
- `python3 tools/checks/maestro_locator_audit.py tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml`
  - Result: all locators resolve.
- `validate_arb_parity()`
  - Result: OK, 6 locales with 6813 keys each.
- `check_banned_terms("Il te reste CHF 1'922 après tes charges.")`
  - Result: clean.
- `check_accent_patterns("Il te reste CHF 1'922 après tes charges.")`
  - Result: clean.
- `bash tools/simulator/maestro_env.sh check-syntax ...`
  - Result: both touched Maestro flows OK.
- `MINT_WALKER_ARTIFACTS=.planning/walker/maestro-flows/money-trust-chain/20260527T152416Z ... flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
  - Result: passed in 1m01s.
- `MINT_WALKER_ARTIFACTS=.planning/walker/maestro-flows/money-trust-chain/20260527T153416Z ... flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
  - Result: passed in 59s after narrowing the anti-3a assertion.
- `MINT_WALKER_ARTIFACTS=.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T152536Z ... flow_mon_argent_budget_setup_spine.yaml`
  - Result: passed in 47s.
- Claude Opus 4.7 review via `claude -p ... --system-prompt ... --model opus`
  - Result: no blockers; non-blocking follow-ups handled where scoped.
- `git diff --check`
  - Result: clean.

## Notes

- The budget-room opener only fires for present-only snapshots with a positive
  margin. If a full retirement gap is already available, gap/deadline logic can
  still take over.
