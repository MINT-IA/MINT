phase: mon-argent-budget-cleanup-v2
plan: 35
title: Maestro money-trust numeric alignment
branch: codex/mon-argent-budget-cleanup-v2
date: 2026-05-27

# Phase 35 — Maestro money-trust numeric alignment

The backend and mobile packet contracts already prove that persisted budget
answers reach the coach semantic packet. This phase tightens the runtime
Maestro guard so the canonical money-trust chain also proves that Mon Argent
shows the same monthly budget numbers as Budget after setup and relaunch.

## Changes

- Extended
  `tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
  with explicit Mon Argent numeric assertions:
  - charges `CHF 3'078`
  - available/free amount `CHF 1'922`
- Updated
  `tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml`
  to the same numeric contract.
- Kept the Coach section focused on the currently shipped behavior:
  - coach route/input/send anchors remain reachable,
  - the 3a opener uses `déductibles`,
  - the old misleading `économie d'impôt en jeu` copy stays absent.
- Kept the existing absurd-value guards for `19'272'200`, `420'420`, `19M`,
  `420k`, `NaN`, and `Infinity`.
- No new data layer, provider, or calculation service was added. The phase is
  only a stronger runtime proof over the existing canonical chain.

## Verification

- `cd services/backend && pytest -q tests/test_coach_tools_budget_snapshot.py tests/test_coach_chat_endpoint.py tests/coach/test_coach_chat_profile_sanitize_context_packet.py`
  - Result: `76 passed in 1.29s`.
- `cd apps/mobile && flutter test test/services/coach_context_packet_service_test.dart test/services/coach_chat_api_service_packet_contract_test.dart test/services/coach_context_packet_payload_test.dart`
  - Result: `20 passed`.
- `python3 tools/checks/maestro_locator_audit.py tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml tools/simulator/flows/maestro-perfect-set/flow_data_spine_visible_coach_packet.yaml`
  - Result: `[OK] All locators resolve.`
- `bash tools/simulator/maestro_env.sh check-syntax tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
  - Result: `OK`.
- Live simulator, after rebuild:
  - `flow_money_trust_chain_budget_mon_argent_rapport_coach`
  - Artifact: `.planning/walker/maestro-flows/money-trust-chain/20260527T144530Z/result.xml`
  - Result: `1/1 Flow Passed in 56s`.
- Live simulator, companion data-spine flow:
  - `flow_mon_argent_budget_setup_spine`
  - Artifact: `.planning/walker/maestro-flows/mon-argent-budget-spine/20260527T144646Z/result.xml`
  - Result: `1/1 Flow Passed in 42s`.

## Notes

- A first live run failed on the old `3'140 / 2'239` contract and showed
  `5'000 / 3'078 / 1'922` on the screenshot. That was not flakiness: this flow
  only enters logement + LAMal on a fresh local profile, so the app's default
  net-income fallback is the correct scenario.
- A separate live run exposed a one-franc drift (`2'239` vs `2'240`) before the
  BudgetLivingEngine rounding fix in Phase 37.
- Coach still opens on a generic 3a insight instead of a budget-context opener
  after this flow. That is a real UX/product backlog item for the next Coach
  phase, not something this Maestro proof should pretend is already shipped.
