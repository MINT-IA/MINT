---
phase: 37
slug: ledger-runtime-readiness
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-12
---

# Phase 37 — Validation Strategy

> Per-phase sampling contract. A missing named test is Wave 0 work, not a PASS.

## Test Infrastructure

| Property | Value |
|---|---|
| **Frameworks** | pytest 8.4.2; Flutter test; Maestro; Patrol |
| **Configs** | `services/backend/pyproject.toml`; `apps/mobile/pubspec.yaml`; checked-in Mint OS wrappers |
| **Quick run** | ticket-specific command from `G1-blocking-gate-tickets.md` |
| **Static spine** | `python3 -m pytest tools/checks/tests/test_ledger_parity.py tools/checks/tests/test_g1_p0_ledger_dead_keys.py -q` |
| **Full affected mobile** | `cd apps/mobile && flutter test test/models/ test/providers/ test/navigation/ test/services/biography/ --reporter expanded` |
| **Full affected backend** | `cd services/backend && python3 -m pytest tests/test_source_crosswalk.py tests/test_enhanced_confidence.py tests/test_document_parser.py -q` |
| **Runtime closure** | full Doctor + Maestro watchdog/environment + Patrol guard/CLI |
| **Patrol process death** | versioned/tested two-stage orchestrator; write/read are separate `--no-uninstall --device "$UDID"` processes with archived `simctl terminate` between |
| **Target feedback** | <30s targeted contract; <5m affected suite; runtime bounded by watchdog |

## Sampling Rate

- After every test-only RED commit candidate: run the exact ticket command and
  retain a business-predicate failure, never merely a missing-file error. If
  the new contract is already GREEN, retain `baseline_green` plus a failing
  negative fixture or mutation control; never manufacture a RED.
- After every production task: run the same ticket command GREEN plus the
  smallest affected regression suite.
- Every mint-mobile task/dispatch that reads or changes `coach_profile.dart` or
  `coach_profile_provider.dart` independently reads `docs/data-flow.md` plus
  canonical ledger/wiring/screen SOTs as applicable, runs
  `grep "answers\[" apps/mobile/lib/models/coach_profile.dart | sort -u`, then
  runs `cd apps/mobile && flutter analyze && flutter test` before RED/code. A
  baseline from another task/agent is invalid. Every mint-backend dispatch
  independently runs `cd services/backend && ruff check . && pytest -q` before
  RED/code.
- After every wave: run Doctor repo-only, static spine, relevant affected suite,
  lefthook, and update the evidence index.
- Before runtime: run full Doctor, Patrol tooling guard, Mermaid guard, and
  route reconcile if navigation changed.
- Before Phase 37 verification: full affected/global suites, runtime composite,
  three external audit lenses, fail-closed machine-readable audit manifests,
  31/31 registry proof, and score >=9.0.
- Every Wave 0-6 manifest has exactly
  `required_modes: [code, product-domain]` and one unique accepted `runs[]`
  entry per mode. The final manifest has exactly code, product-domain, and
  architecture. Every run records wrapper command/model/base/head/exit 0/
  non-empty output/complete findings/severity counts. Failed attempts are
  separate artifacts, never duplicate accepted runs.
- No three consecutive tasks may execute without an automated behavioral sample.

## Per-Ticket Verification Map

| Ticket | Wave | Threat | Secure behavior | Test type | Automated command | File now | Status |
|---|---:|---|---|---|---|---|---|
| progressive evidence gate | 0 | false batch GREEN | each row requires evidence SHA/artifact | contract | `python3 -m pytest tools/checks/tests/test_g1_p0_ledger_dead_keys.py -q` | ✅ | ⬜ pending redesign |
| G1-SOURCE-01 | 1A | unknown source fallback | exact fail-closed crosswalk | pytest | `cd services/backend && python3 -m pytest tests/test_source_crosswalk.py -q` | ❌ W0 | ⬜ pending |
| G1-LDG-02 | 1B | enum meaning loss | canonical aliases round-trip | Flutter model | `cd apps/mobile && flutter test test/models/coach_profile_semantic_roundtrip_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-LDG-04 | 1B | defaults presented known | missing remains missing | Flutter model | `cd apps/mobile && flutter test test/models/default_is_not_known_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-LDG-05 | 1B | field semantic collision | independent exact fields | Flutter model | `cd apps/mobile && flutter test test/models/direct_field_semantics_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-LDG-06 | 1B | fabricated AVS years | status/count order independent | Flutter model | `cd apps/mobile && flutter test test/models/avs_gap_write_order_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-LDG-07 | 1B | mortgage disagreement | deterministic dated winner/quarantine | Flutter model | `cd apps/mobile && flutter test test/models/mortgage_reconciliation_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-BND-04 | 1C | duplicate/missed recompute | exactly one recompute | Flutter provider | `cd apps/mobile && flutter test test/providers/mint_state_proxy_recompute_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-PROV-01 | 2 | value/source split crash | atomic value+source+dates+owner | Flutter provider | `cd apps/mobile && flutter test test/providers/provenance_on_write_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-PROV-02 | 2 | certificate provenance loss | restart preserves fact and provenance | Flutter provider | `cd apps/mobile && flutter test test/providers/provenance_restart_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-PROV-03 | 2 | tax precision without legal date | typed source date/legal year | Flutter provider | `cd apps/mobile && flutter test test/providers/tax_provenance_profile_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-LDG-03 | 2 | dead P0 consumer | parameterized live-key round-trip | Flutter provider | `cd apps/mobile && flutter test test/providers/g1_p0_ledger_roundtrip_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-BND-02 | 3 | partner reassigned to self | pseudonymous owner + consent bridge | Flutter provider | `cd apps/mobile && flutter test test/providers/household_bridge_recompute_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-BND-03 | 3 | budget provider divergence | canonical write then rehydrate cache | Flutter provider | `cd apps/mobile && flutter test test/providers/provider_bridge_recompute_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-BND-05 | 3 | raw document in ledger/route | opaque reference + confirmed facts only | Flutter provider | `cd apps/mobile && flutter test test/providers/document_reference_bridge_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-BND-06 | 3 | stale financial plan shown fresh | input-hash invalidation | Flutter provider | `cd apps/mobile && flutter test test/providers/financial_plan_staleness_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-BND-01 | 3 | legacy semantic fork | named consumers use canonical provider | Flutter provider | `cd apps/mobile && flutter test test/providers/legacy_provider_migration_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-FRONT-01 | 4 | jurisdiction conflation | three explicit jurisdiction facts | Flutter model | `cd apps/mobile && flutter test test/models/frontier_canonical_fields_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-RET-REF-01 | 4 | unsupported retirement precision | references/source date/legal year required | Flutter model | `cd apps/mobile && flutter test test/models/specialist_reference_contract_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-SUCCESSION-01 | 4 | inferred regime/instruments | explicit refs or educational fallback | Flutter model | `cd apps/mobile && flutter test test/models/estate_reference_contract_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-SCN-01 | 5 | scenario corrupts certified fact | scenario ID isolation | Flutter provider | `cd apps/mobile && flutter test test/providers/scenario_fact_isolation_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-FRESH-01 | 5 | stale value reused/blank re-ask | prior value one-tap reconfirm | Flutter service | `cd apps/mobile && flutter test test/services/biography/stale_reconfirmation_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-RETURN-01 | 5 | forged/open return route | registered internal return URI | Flutter navigation | `cd apps/mobile && flutter test test/navigation/data_block_return_uri_test.dart --reporter expanded` | ❌ W0 | ⬜ pending |
| G1-RUNTIME-01 | 7 | green tests, broken restart | real write/process-death/reload/read/recompute | Maestro + Patrol | canonical registry command: full Doctor + Patrol guard + watchdog Maestro pinned to `$UDID` + versioned two-stage Patrol orchestrator with `--no-uninstall --device "$UDID"` and archived `simctl terminate` | ❌ W0 | ⬜ pending |
| RDY-GATE-01 | 7 | score hides a hard-floor failure | 31 G1 tickets, both runtime harnesses, suites, audits, design review and build are green | acceptance | `python3 -m pytest tools/checks/tests/test_g1_p0_ledger_dead_keys.py -q` plus Plan 37-07 hard floor | ✅ | ⬜ pending |

## Business-to-GSD Wave Mapping

| Business wave | GSD plan/wave | Acceptance boundary |
|---|---|---|
| Gate infrastructure | 37-00 / 0 | Evidence schema only; `requirements: []`. |
| 1A | 37-01 / 1 | SOURCE-01. |
| 1B + 1C | 37-02 / 2 | Five ledger semantics plus exact-once recompute. |
| 2 | 37-03 / 3 | Atomic provenance and live-key round trip. |
| 3 | 37-04 / 4 | Provider/document/plan/legacy bridges. |
| 4 | 37-05 / 5 | Swiss jurisdiction and specialist references. |
| 5 | 37-06 / 6 | Scenario, freshness, safe return. |
| 6 | 37-07 / 7 | Maestro + Patrol, final audits, iOS simulator build, design review, score and G2 gate. |

## Wave 0 Requirements

- [ ] Evolve `test_g1_p0_ledger_dead_keys.py` TDD-first so status transitions
  require evidence rather than forcing all 31 rows to remain `ticket_only`.
- [ ] Create each missing unit/integration test file before its production
  change and capture semantic RED or controlled baseline-GREEN evidence.
- [ ] Create `.maestro/r4_persistence.yaml`, separate Patrol write/read tests,
  `tools/simulator/patrol_persistence_process_death.sh`, and its checked-in
  fail-closed test before runtime repair.
- [ ] Migrate the `G1-RUNTIME-01` target files and identical RED/GREEN commands
  to that one canonical same-UDID watchdog-plus-orchestrator contract; remove
  the obsolete mono-process Patrol target/command.
- [ ] Create `.planning/runtime-evidence/phase-37/` evidence indexes without
  committing PII or unbounded tool output.
- [ ] Preserve existing pytest/Flutter/Maestro/Patrol infrastructure; no new test
  framework or ad-hoc runner.

## Manual-Only Verifications

| Behavior | Requirement | Why manual/runtime | Instructions |
|---|---|---|---|
| iPhone persistence/recompute | RDY-RUNTIME-01 | process death/native input | full Doctor; pin Maestro and both Patrol stages to the same UDID/SHA/bundle; run separate persistent Patrol write/read processes with archived successful `simctl terminate` between; retain metadata/artifacts |
| Swiss reference/no-advice meaning | RDY-RET-REF-01, RDY-SUCCESSION-01, RDY-FRONT-01 | specialist domain judgment | mint-swiss-brain review then wrapper product-domain audit |
| Final merge/no-merge | RDY-GATE-01 | holistic evidence judgment | Plan 37-07 only: mint-quality-gate scorecard then mint-lead decision |

## Validation Sign-Off

- [ ] Every ticket has semantic RED→GREEN or baseline-GREEN plus a non-vacuous negative/mutation control.
- [ ] All tasks have automated verify or declared runtime dependency.
- [ ] Sampling continuity has no three consecutive tasks without automation.
- [ ] Wave 0 covers all missing named artifacts.
- [ ] No watch-mode flags or ad-hoc substitute runners.
- [ ] Evidence logs cite exact SHA and contain synthetic/redacted data only.
- [ ] Feedback targets are met or slow/flaky behavior is explicitly triaged.
- [ ] DATA_LEDGER/WIRING_GRAPH/SCREEN_CONTRACTS are synchronized and gated in
  Plans 37-02 and 37-03/04/06; DATA_LEDGER is synchronized/gated in 37-05.
- [ ] Final post-repair SHA reruns full Doctor, Patrol guard, routes, ARB,
  Mermaid, interaction lint/coverage, no-bypass/ledger gates, tools/backend/
  Flutter tests and builds, both runtime harnesses, and lefthook.
- [ ] After Mint OS GREEN, gsd-code-review, gsd-validate-phase,
  gsd-secure-phase, and conditional design-review complete as supplemental
  gates. New MINT skills remain deferred to Phase 38 until versioned, tested,
  and Doctor-visible.
- [ ] Final push leaves empty porcelain and HEAD exactly equal to upstream.
- [ ] `nyquist_compliant: true` and `wave_0_complete: true` only after evidence.

**Approval:** pending plan verification
