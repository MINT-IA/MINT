# Mint Lucidity DataQuest Clean Verification

## Deterministic Gates

- `python3 tools/checks/active_context_guard.py`
- `python3 tools/checks/phase_contract_guard.py`
- `python3 tools/checks/mint_rules_guard.py`
- `python3 tools/checks/workflow_contract_guard.py`
- `python3 tools/checks/verify_phase_acceptance.py`
- `python3 -m pytest tools/checks/tests/test_maestro_flows_doc_contract.py -q`
- `python3 -m pytest tools/checks/tests/test_screen_contracts_doc_contract.py -q`
- `cd services/backend && python3 -m pytest tests/test_suggest_actions_enrichment.py -q`
- `cd apps/mobile && flutter test test/architecture/financial_plan_wiring_contract_test.dart test/providers/financial_plan_provider_test.dart --reporter expanded`
- `bash tools/checks/mint_lucidity_gate.sh mobile-data-quest`
- `bash tools/checks/mint_lucidity_gate.sh mobile-scenarios`

## Runtime Gates

- Patrol P0 aggregate gate when mobile flows are touched.
- Maestro syntax/runtime flows for seeded deep-link coverage.

## External Audit

- `tools/checks/claude_external_audit.sh specs`
- `tools/checks/claude_external_audit.sh architecture`
- `tools/checks/claude_external_audit.sh code dev`
