# Mint Lucidity DataQuest Clean Verification

## Deterministic Gates

- `python3 tools/checks/active_context_guard.py`
- `python3 tools/checks/phase_contract_guard.py`
- `python3 tools/checks/mint_rules_guard.py`
- `python3 tools/checks/workflow_contract_guard.py`
- `python3 tools/checks/verify_phase_acceptance.py`
- `bash tools/checks/mint_lucidity_gate.sh mobile-data-quest`
- `bash tools/checks/mint_lucidity_gate.sh mobile-scenarios`

## Runtime Gates

- Patrol P0 aggregate gate when mobile flows are touched.
- Maestro syntax/runtime flows for seeded deep-link coverage.

## External Audit

- `tools/checks/claude_external_audit.sh specs`
- `tools/checks/claude_external_audit.sh architecture`
- `tools/checks/claude_external_audit.sh code dev`

