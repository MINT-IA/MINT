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

Completion requires every acceptance clause on Bead `MINT_nosync-ihj`, an
exact Figma frame/version, six-language ARB parity, inspected runtime renders,
P1/P2=0, and a tiny prevalidated build. Documents or a self-score cannot close
the phase.

```verify
batch5-runtime: python3 tools/checks/mint_next_batch5_runtime_probe.py --capture
active-context: python3 tools/checks/active_context_guard.py
phase-contract: python3 tools/checks/phase_contract_guard.py
mint-rules: python3 tools/checks/mint_rules_guard.py
journey-os: python3 tools/checks/journey_os_check.py
workflow-contract: python3 tools/checks/workflow_contract_guard.py
contract-diff: git diff --check
```
