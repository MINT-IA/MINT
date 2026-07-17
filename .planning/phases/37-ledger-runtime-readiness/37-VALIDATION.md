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
| progressive evidence gate | 0 | false batch GREEN | each row requires evidence SHA/artifact | contract | `python3 -m pytest tools/checks/tests/test_g1_p0_ledger_dead_keys.py -q` | ✅ | ✅ active |
| G1-SOURCE-01 | 1A | unknown source fallback | exact fail-closed crosswalk | pytest | `cd services/backend && python3 -m pytest tests/test_source_crosswalk.py -q` | ✅ | ✅ green |
| G1-LDG-02 | 1B | enum meaning loss | canonical aliases round-trip | Flutter model | `cd apps/mobile && flutter test test/models/coach_profile_semantic_roundtrip_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-LDG-04 | 1B | defaults presented known | missing remains missing | Flutter model | `cd apps/mobile && flutter test test/models/default_is_not_known_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-LDG-05 | 1B | field semantic collision | independent exact fields | Flutter model | `cd apps/mobile && flutter test test/models/direct_field_semantics_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-LDG-06 | 1B | fabricated AVS years | status/count order independent | Flutter model | `cd apps/mobile && flutter test test/models/avs_gap_write_order_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-LDG-06A | 1B | certified-null becomes zero/household-ready | self/household readiness preserves missing person-owned evidence | pytest + Flutter model/consumer | `python3 -m pytest tools/checks/tests/test_g1_avs_certified_null_contract.py -q && cd apps/mobile && flutter test test/models/avs_gap_evidence_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-LDG-07 | 1B | mortgage disagreement | deterministic dated winner/quarantine | Flutter model | `cd apps/mobile && flutter test test/models/mortgage_reconciliation_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-BND-04 | 1C | duplicate/missed recompute | exactly one recompute | Flutter provider | `cd apps/mobile && flutter test test/providers/mint_state_proxy_recompute_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-PROV-01 | 2 | value/source split crash | atomic value+source+dates+owner | Flutter provider | `cd apps/mobile && flutter test test/providers/provenance_on_write_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-PROV-02 | 2 | certificate provenance loss | restart preserves fact and provenance | Flutter provider | `cd apps/mobile && flutter test test/providers/provenance_restart_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-PROV-03 | 2 | tax precision without legal date | typed source date/legal year | Flutter provider | `cd apps/mobile && flutter test test/services/document_parser/tax_declaration_parser_test.dart test/providers/tax_provenance_profile_test.dart test/screens/document_scan/tax_extraction_review_screen_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-LDG-03 | 2 | dead P0 consumer | parameterized live-key round-trip | Flutter provider | `cd apps/mobile && flutter test test/providers/g1_p0_ledger_roundtrip_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-BND-02A | 3 | membership/proxy/legacy receipt mistaken for direct consent | isolated minimized receipt + exact owner binding + real BND-02 caller + lifecycle invalidation; activation facts remain fail-closed | backend + Flutter + Swiss/ledger/quest verdicts | `(cd services/backend && python3 -m pytest tests/test_partner_accountability.py tests/test_lpp_candidate_only_extraction.py tests/services/document/test_third_party_declaration.py -q) && (cd apps/mobile && flutter test test/providers/partner_financial_consent_lifecycle_test.dart test/providers/household_bridge_recompute_test.dart test/screens/coach/manual_partner_lpp_accountability_rendering_test.dart --reporter expanded)` | ✅ | ✅ green |
| G1-BND-02 | 3 | partner reassigned to self, cold fact has no scoped consumer, or exact self 2.00% is treated as missing | pseudonymous owner + named fail-closed recompute; caisse rate scoped/quarantined and exact 0.02 distinct from missing | Flutter provider | `cd apps/mobile && flutter test test/providers/household_bridge_recompute_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-BND-03 | 3 | budget provider divergence | canonical write then rehydrate cache | Flutter provider | `cd apps/mobile && flutter test test/providers/provider_bridge_recompute_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-BND-05 | 3 | raw document in ledger/route | opaque reference + confirmed facts only | Flutter provider | `cd apps/mobile && flutter test test/providers/document_reference_bridge_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-BND-06 | 3 | stale financial plan shown fresh | input-hash invalidation | Flutter provider | `cd apps/mobile && flutter test test/providers/financial_plan_staleness_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-BND-01 | 3 | legacy semantic fork | historical matches reconcile to one live canonical reader; missing authority fails closed and dead facades are removed while the API/Wizard DTO remains | Flutter provider + widget route | `cd apps/mobile && flutter test test/providers/legacy_provider_migration_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-COACH-01 | 3 | live coach amount drops or writes wrong unit | three renderer keys use applySaveFact with exact canonical units/provenance | Flutter integration | `cd apps/mobile && flutter test test/integration/coach_inline_amount_write_contract_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-FRONT-01 | 4 | jurisdiction conflation | three explicit jurisdiction facts | Flutter model | `cd apps/mobile && flutter test test/models/frontier_canonical_fields_test.dart --reporter expanded` | ❌ W0 | ⬜ ticket_only |
| G1-RET-REF-01 | 4 | unsupported retirement precision | references/source date/legal year required | Flutter model | `cd apps/mobile && flutter test test/models/specialist_reference_contract_test.dart --reporter expanded` | ❌ W0 | ⬜ ticket_only |
| G1-SUCCESSION-01 | 4 | inferred regime/instruments | explicit refs or educational fallback | Flutter model | `cd apps/mobile && flutter test test/models/estate_reference_contract_test.dart --reporter expanded` | ❌ W0 | ⬜ ticket_only |
| G1-AVS-01 | 4 | couple cap/splitting legal error | person-first scale-aware law contract | Flutter financial core | `cd apps/mobile && flutter test test/services/financial_core/avs_couple_legal_contract_test.dart --reporter expanded` | ✅ | ✅ green |
| G1-AVS-02 | 4 | 13th pension evidence is not durable or visible, or cash-flow law is wrong | owner-scoped evidence cold-reloads; monthly/December/annual lines remain separate | Flutter calculator + provider restart + screen | `cd apps/mobile && flutter test test/services/financial_core/avs_thirteenth_pension_calculator_test.dart test/providers/avs_thirteenth_evidence_restart_test.dart test/screens/coach/avs_thirteenth_cashflow_rendering_test.dart test/services/independants_avs_thirteenth_scenario_test.dart --reporter expanded` | ❌ W0 | ⬜ ticket_only |
| G1-AVS-03 | 4 | unofficial gap count priced as personal loss | count-only quarantine until official scale/amount | backend + Flutter | `(cd services/backend && python3 -m pytest tests/test_avs_unofficial_gap_effect_quarantine.py -q) && (cd apps/mobile && flutter test test/services/financial_core/avs_unofficial_gap_effect_quarantine_test.dart --reporter expanded)` | ✅ | ✅ green |
| G1-SCN-01 | 5 | scenario corrupts certified fact | scenario ID isolation | Flutter provider | `cd apps/mobile && flutter test test/providers/scenario_fact_isolation_test.dart --reporter expanded` | ❌ W0 | ⬜ ticket_only |
| G1-FRESH-01 | 5 | stale value reused/blank re-ask | prior value one-tap reconfirm | Flutter service | `cd apps/mobile && flutter test test/services/biography/stale_reconfirmation_test.dart --reporter expanded` | ❌ W0 | ⬜ ticket_only |
| G1-RETURN-01 | 5 | forged/open return route | registered internal return URI | Flutter navigation | `cd apps/mobile && flutter test test/navigation/data_block_return_uri_test.dart --reporter expanded` | ❌ W0 | ⬜ ticket_only |
| G1-RET-STATE-01 | 5 | unavailable projection has no recovery | cause-specific target correction returns to /retraite | Flutter screen | `cd apps/mobile && flutter test test/screens/coach/retirement_dashboard_test.dart --reporter expanded` | ✅ | ⬜ ticket_only |
| G1-COACH-02 | 5 | valid empty-profile route intent disappears | visible readiness/recovery action through registry | Flutter integration | `cd apps/mobile && flutter test test/integration/coach_tool_choreography_test.dart --reporter expanded` | ✅ | ⬜ ticket_only |
| G1-RUNTIME-01 | 7 | green tests, broken restart | real write/process-death/reload/read/recompute | Maestro + Patrol | `UDID="${UDID:?set UDID}" && python3 tools/checks/mint_os_doctor.py && python3 tools/checks/patrol_tooling_guard.py && MINT_WALKER_ARTIFACTS=.planning/runtime-evidence/phase-37/runtime-01/maestro bash tools/simulator/maestro_with_watchdog.sh test --device "$UDID" apps/mobile/.maestro/r4_persistence.yaml && bash tools/simulator/patrol_persistence_process_death.sh --device "$UDID" --bundle-id ch.mint.app --sha "$(git rev-parse HEAD)" --artifacts .planning/runtime-evidence/phase-37/runtime-01/patrol` | ✅ | 🟥 red_proven |
| RDY-GATE-01 | 7 | score hides a hard-floor failure | 31 G1 tickets, both runtime harnesses, suites, audits, design review and build are green | acceptance | `python3 -m pytest tools/checks/tests/test_g1_p0_ledger_dead_keys.py -q` plus Plan 37-07 hard floor | ✅ | ⬜ pending |

## Business-to-GSD Wave Mapping

| Business wave | GSD plan/wave | Acceptance boundary |
|---|---|---|
| Gate infrastructure | 37-00 / 0 | Evidence schema only; `requirements: []`. |
| 1A | 37-01 / 1 | SOURCE-01. |
| 1B + 1C | 37-02 / 2 | Historical six-row wave plus independent GREEN LDG-06A traceability addendum. |
| 2 | 37-03 / 3 | Atomic provenance and live-key round trip. |
| 3 | 37-04 / 4 | Partner accountability, provider/document/plan/legacy bridges, canonical coach writes. |
| 4 | 37-05 / 5 | Swiss jurisdiction, specialist references and AVS-01/02/03. |
| 5 | 37-06 / 6 | Scenario, freshness, safe return, retirement and coach recovery. |
| 6 | 37-07 / 7 | Maestro + Patrol, final audits, iOS simulator build, design review, score and G2 gate. |

## Wave 0 Requirements

- [x] Evolve `test_g1_p0_ledger_dead_keys.py` TDD-first so status transitions
  require evidence rather than forcing all 31 rows to remain `ticket_only`.
- [ ] Create each missing unit/integration test file before its production
  change and capture semantic RED or controlled baseline-GREEN evidence.
- [x] Create `.maestro/r4_persistence.yaml`, separate Patrol write/read tests,
  `tools/simulator/patrol_persistence_process_death.sh`, and its checked-in
  fail-closed test before runtime repair.
- [x] Migrate the `G1-RUNTIME-01` target files and identical RED/GREEN commands
  to that one canonical same-UDID watchdog-plus-orchestrator contract; remove
  the obsolete mono-process Patrol target/command.
- [x] Create `.planning/runtime-evidence/phase-37/` evidence indexes without
  committing PII or unbounded tool output.
- [x] Preserve existing pytest/Flutter/Maestro/Patrol infrastructure; no new test
  framework or ad-hoc runner.

## Manual-Only Verifications

| Behavior | Requirement | Why manual/runtime | Instructions |
|---|---|---|---|
| iPhone persistence/recompute | RDY-RUNTIME-01 | process death/native input | full Doctor; pin Maestro and both Patrol stages to the same UDID/SHA/bundle; run separate persistent Patrol write/read processes with archived successful `simctl terminate` between; retain metadata/artifacts |
| Swiss reference/no-advice/AVS meaning | RDY-RET-REF-01, RDY-SUCCESSION-01, RDY-FRONT-01, RDY-AVS-01/02/03 | specialist domain judgment | mint-swiss-brain review then wrapper product-domain audit |
| Partner indirect collection/accountability | RDY-BND-02A | named legal/privacy decision and implemented outcome | Technical ticket proof is accepted at `1d022c508`: exact combined tests, Patrol writer→terminate→cold-reader, Maestro and four wrapper-only audits. Verified controller/contact, Anthropic role/DPA and regions, transfer/TIA, retention/ZDR, account-free rights channel and AIPD decision remain required before activation. |
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
