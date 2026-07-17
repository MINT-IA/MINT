# Verification — G1 RET-REF-01 fiscal sub-vertical

Verified source SHA:
`0df65cde10b8dc94e1e69a37d478ff21e3208458`

Sanitized proof:
`runtime-proof-0df65cde1/`

Raw local source bundle:
`runtime-0df65cde10-20260717T205905Z/` (ignored, not promotion evidence by
itself).

## Quality verdict

The bounded fiscal reference technical vertical is **GREEN at 9.0/10** with
scoped `P0=0/P1=0`.

Production activation is **NO-GO with P0=0/P1=1** until a separate
currentness/DataQuest re-ask contract is implemented and proven. The
event-static legal reference must not be converted into a calendar TTL.

Whole `RET-REF-01` remains **ticket_only / open** because
`lppRegulationReference`, `lppCapitalNoticeDeadline` and
`pillar3aBeneficiaryClause` are missing. G1 remains **NO-GO**. Starting G2/G3
is forbidden.

## Commands and results

| Gate | Command | Result | Raw evidence |
|---|---|---|---|
| MINT OS | `python3 tools/checks/mint_os_doctor.py` | PASS | `preflight/mint-os-doctor.log` |
| Patrol tooling | `python3 tools/checks/patrol_tooling_guard.py` | PASS | `preflight/patrol-tooling-guard.log` |
| Runtime contract | `python3 -m pytest tools/checks/tests/test_g1_prov03_tax_runtime_orchestrator.py -q` | 19 passed | `preflight/runtime-orchestrator-contract.log` |
| Mermaid | `python3 tools/checks/mermaid_render_guard.py` | PASS | `preflight/mermaid-render-guard.log` |
| Documentation | `python3 -m pytest tools/checks/tests/test_codex_spec_reality_contract.py tools/checks/tests/test_data_quest_goal_aware_ranking_contract.py tools/checks/tests/test_screen_contracts_route_contract.py tools/checks/tests/test_interaction_journey_diagrams_contract.py tools/checks/tests/test_interaction_registry_contract.py tools/checks/tests/test_ledger_parity.py tools/checks/tests/test_mermaid_render_guard.py -q` | 30 passed | `preflight/docs-contracts.log` |
| Analyze | `(cd apps/mobile && flutter analyze)` | zero issues | `preflight/flutter-analyze.log` |
| Full Flutter | `(cd apps/mobile && flutter test --reporter compact)` | 9,592 passed / 44 skipped / 0 failed | `preflight/flutter-full-suite.log` |
| Maestro flag-off | `MINT_WALKER_ARTIFACTS=<LOCAL_RAW>/maestro bash tools/simulator/maestro_with_watchdog.sh test --device <SIMULATOR_UDID> apps/mobile/.maestro/g1_prov03_tax_flag_off.yaml` | 9/9 PASS, exit 0 | `maestro/maestro.log`, `maestro/maestro.console.log` |
| Patrol process death | `tools/simulator/patrol_tax_provenance_process_death.sh --device <SIMULATOR_UDID> --bundle-id ch.mint.app --sha 0df65cde10b8dc94e1e69a37d478ff21e3208458 --artifacts <LOCAL_RAW>/patrol-confirm` | exit 0 | `patrol-confirm/metadata.json`, `orchestrator-exit-code.txt` |
| Claude code | `CLAUDE_AUDIT_MAX_DIFF_LINES=7000 tools/checks/claude_external_audit.sh code 8d99646be` | Opus PASS, P0=0/P1=0 | `claude-audits/code-opus-first-pass.txt` |
| Claude product rerun | `CLAUDE_AUDIT_RERUN=1 CLAUDE_AUDIT_MAX_DIFF_LINES=7000 tools/checks/claude_external_audit.sh product-domain 8d99646be` | Sonnet PASS, P0=0/P1=0 | `claude-audits/product-domain-sonnet-rerun.txt` |
| Claude final confirmation | `CLAUDE_AUDIT_RERUN=1 CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1 CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_MAX_DIFF_LINES=7000 tools/checks/claude_external_audit.sh product-domain 8d99646be` | Opus overall PASS; activation P0=0/P1=1 | `claude-audits/product-domain-opus-final-confirmation.txt` |

## Runtime acceptance

- Maestro waited for visible `landing_route` after `clearState` and before the
  deep link. The generic document scan CTA rendered; all tax acquisition and
  review controls were absent. Screenshot SHA-256:
  `a31227792d9c60450c925fe31506fb00df6235871860256c0f700e2f0b6812c9`.
- Patrol writer executed the real scan-review/provider/persistence path using
  only synthetic values and produced one final, explicitly attested in-force
  assessment reference.
- `simctl terminate` returned 0 between the writer and reader.
- The independently built cold reader recovered the same canonical snapshot,
  validated exact provenance/reference coherence and precision readiness, and
  confirmed the matching `fiscal.assessedBaseline` prompt was absent.
- Independent xcresult summaries are 1/1 writer and 1/1 reader.
- Temporary build isolation reports `restoration_status=restored`.

## External-audit adjudication

The code gate completed one Opus first pass. The separate product-domain
audit loop is also complete:

1. its initial Opus pass was recorded before this runtime bundle;
2. the authorized Sonnet rerun passed;
3. the final allowed Opus confirmation passed overall and retained the
   activation-only P1.

The final Opus confirmation raised one P1: an old but still valid assessment
could silence a future “provide a newer assessment” ask. Permanent Swiss and
ledger review accepted the legal reference semantics but retained the finding
as an activation-only requirement:

- the decision/document reference is durable and event-static;
- current usability of the tax baseline is a distinct DataQuest/currentness
  question;
- flags cannot be enabled until that question, re-ask behavior and runtime
  proof exist.

There will be no further audit carousel for this unchanged gate.

## Privacy and integrity

Tracked artifacts replace local paths and device identifiers with placeholders.
They contain synthetic metadata and summaries only. No screenshot binary,
xcresult bundle, raw log, raw tax/OCR content, personal identifier, real
financial value, credential, token or secret is included.

`runtime-proof-0df65cde1/SHA256SUMS` covers the tracked proof bundle.
