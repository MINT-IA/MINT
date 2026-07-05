# Mint Lucidity DataQuest Clean Spec

## Acceptance Criteria

1. Mint OS guards run in this worktree without pointing to stale phases.
2. `docs/codex/` claims are audited against code before product patches.
3. Route payload contracts reject domain data in `state.extra`.
4. Scan review/impact and report routes recover from missing persisted data
   with user-facing, localized states instead of hardcoded blank/error text.
5. Legacy `ProfileProvider` is not used by production screens/widgets for
   financial data gates.
6. Redirect shims preserve query context.
7. P0 Data Quest scenarios use the canonical variable registry and do not
   duplicate collection for an already-known fresh fact.
8. Patrol/Maestro runtime evidence is recorded for touched P0 mobile flows.
9. Claude CLI external audit records no unresolved critical/high finding for
   acceptance.

```verify
# tier: deterministic
os-active-context: python3 tools/checks/active_context_guard.py
os-phase-contract: python3 tools/checks/phase_contract_guard.py
os-rules: python3 tools/checks/mint_rules_guard.py
os-workflow: python3 tools/checks/workflow_contract_guard.py
ledger-parity: python3 -m pytest tools/checks/tests/test_codex_ledger_parity.py tools/checks/tests/test_no_bypass_persistence.py tools/checks/tests/test_p0_case_variable_registry.py tools/checks/tests/test_patrol_p0_gate_contract.py -q
maestro-doc: python3 -m pytest tools/checks/tests/test_maestro_flows_doc_contract.py -q
screen-contracts-doc: python3 -m pytest tools/checks/tests/test_screen_contracts_doc_contract.py -q
backend-suggest-actions: cd services/backend && python3 -m pytest tests/test_suggest_actions_enrichment.py -q
provider-wiring: cd apps/mobile && flutter test test/architecture/financial_plan_wiring_contract_test.dart test/providers/financial_plan_provider_test.dart --reporter expanded
mobile-data-quest: bash tools/checks/mint_lucidity_gate.sh mobile-data-quest
```
