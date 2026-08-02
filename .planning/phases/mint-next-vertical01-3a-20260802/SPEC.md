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
batch8-lpp-runtime-probe: python3 tools/checks/mint_next_batch8_lpp_runtime_probe.py
batch9-contribution-written-scope: python3 tools/checks/mint_next_batch9_contribution_scope_guard.py
batch10-contribution-runtime-probe: python3 tools/checks/mint_next_batch10_contribution_runtime_probe.py
active-context: python3 tools/checks/active_context_guard.py
phase-contract: python3 tools/checks/phase_contract_guard.py
mint-rules: python3 tools/checks/mint_rules_guard.py
journey-os: python3 tools/checks/journey_os_check.py
workflow-contract: python3 tools/checks/workflow_contract_guard.py
contract-diff: git diff --check
```
