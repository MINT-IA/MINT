# MINT Next Vertical 01 — 3a Specification

Status: `in_progress`

## Promise

From one human 3a question, progressively obtain only the facts needed for a
bounded result, explain tax and liquidity together, and end in one real next
action or safe exit.

## Hard boundaries

- One canonical profile write path; no legacy `ProfileProvider` fallback.
- No default personal result from invented tax rate, horizon, return or income.
- Changed facts hide stale output.
- Every control has a tested destination.
- No recommendation, provider ranking, transaction or unsupported Swiss claim.
- Legacy/dev stay untouched until the isolated candidate is accepted.
- Current Batch 5 evidence is explicitly `bounded_micro_lesson`.

## Completion evidence

Completion requires every acceptance clause on Bead `MINT_nosync-ihj`, the
machine-verified canonical navigation graph, an executable Flutter Design Lab,
six-language ARB parity, inspected runtime renders, P1/P2=0, and a tiny
prevalidated build. Figma is optional reference material. Documents, static
frames, or a self-score cannot close the phase.

```verify
batch5-runtime: python3 tools/checks/mint_next_batch5_runtime_probe.py --capture
batch6-figma-receipt: python3 tools/checks/mint_next_batch6_figma_receipt.py
batch6-navigation: python3 tools/checks/mint_next_batch6_navigation_guard.py
batch6-navigation-diagram: python3 tools/checks/mint_next_batch6_navigation_diagram.py
batch6-navigation-acceptance: python3 tools/checks/mint_next_batch6_navigation_acceptance.py
batch7-design-lab-acceptance: python3 tools/checks/mint_next_batch7_design_lab_guard.py
batch8-lpp-written-scope: python3 tools/checks/mint_next_batch8_lpp_scope_guard.py
batch8-lpp-runtime: python3 tools/checks/mint_next_batch8_lpp_runtime_guard.py
batch9-contribution-written-scope: python3 tools/checks/mint_next_batch9_contribution_scope_guard.py
batch10-contribution-runtime: python3 tools/checks/mint_next_batch10_contribution_runtime_guard.py
batch11-amount-written-scope: python3 tools/checks/mint_next_batch11_amount_scope_guard.py
batch12-amount-runtime-probe: python3 tools/checks/mint_next_batch12_amount_runtime_probe.py
batch12-amount-runtime: python3 tools/checks/mint_next_batch12_amount_runtime_guard.py
batch12-amount-hostile-tests: python3 -m unittest tools.checks.tests.test_mint_next_batch12_amount_runtime_guard
batch12-package-manifest: python3 tools/checks/mint_next_artifact_manifest.py verify product/mint_next/batch12/design-lab-manifest.yaml
batch13-multi-provider-written-contract: python3 tools/checks/mint_next_batch13_multi_provider_contract_guard.py
batch13-multi-provider-hostile-tests: python3 -m unittest tools.checks.tests.test_mint_next_batch13_multi_provider_contract_guard
batch17-canton-written-contract: python3 tools/checks/mint_next_batch17_canton_scope_guard.py
batch18-canton-runtime-scope: python3 tools/checks/mint_next_batch18_runtime_scope_guard.py
batch18-canton-runtime-scope-hostiles: python3 -m unittest tools.checks.tests.test_mint_next_batch18_runtime_scope_guard
batch18-dispatcher-decoupling: python3 tools/checks/mint_next_batch18_dispatcher_decoupling_guard.py --release
batch18-dispatcher-decoupling-hostiles: python3 -m unittest tools.checks.tests.test_mint_next_batch18_dispatcher_decoupling_guard
active-context: python3 tools/checks/active_context_guard.py
phase-contract: python3 tools/checks/phase_contract_guard.py
mint-rules: python3 tools/checks/mint_rules_guard.py
journey-os: python3 tools/checks/journey_os_check.py
workflow-contract: python3 tools/checks/workflow_contract_guard.py
contract-diff: git diff --check
```
