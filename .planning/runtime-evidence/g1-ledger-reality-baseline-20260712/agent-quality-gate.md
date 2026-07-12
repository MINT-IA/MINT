# G1 Ledger Reality Baseline — quality-gate closure evidence

Date: 2026-07-12

Agent: `mint-quality-gate`

Scope: G1 baseline closure only. This report does not authorize G2 or G3.

## Verdict

**FINAL PASS — G1 ACCEPTED — 9.2/10.** The final architecture Opus audit passed
against clean SHA `53c733827` with no P0 and no unresolved P1. All G1 closure
gates are now satisfied. Independently, `G2 allowed? NO` and `G3 allowed? NO`
because the 23 checked-in `ticket_only` behavioral contracts remain blocking.

## Live closure evidence

### Repository and contract gates

| proof | result | interpretation |
|---|---|---|
| `python3 tools/checks/mint_os_doctor.py --repo-only` and full doctor for runtime | PASS | Required host and repo tooling is available. |
| `python3 -m pytest tools/checks/tests/test_codex_spec_reality_contract.py -q` | PASS: 6 | Required spec-reality subset is current. |
| `python3 -m pytest tools/checks/tests/test_ledger_parity.py tools/checks/tests/test_no_bypass_persistence.py -q` | PASS: 7 | Required ledger parity and persistence boundary subset is current. |
| `python3 -m pytest tools/checks/tests/test_data_quest_goal_aware_ranking_contract.py tools/checks/tests/test_screen_contracts_route_contract.py -q` | PASS: 5 | Required DataQuest/spec routing subset is current. |
| `python3 -m pytest tools/checks/tests/test_g1_p0_ledger_dead_keys.py -q` | PASS: 3 | Matrix schema, code-truth readers, ticket coherence, and negative fixtures pass. |
| `python3 -m pytest tools/checks/tests -q` | PASS: 158 | The formerly red widened repository suite is fully GREEN. |
| `python3 tools/checks/mermaid_render_guard.py` | PASS | Checked-in Mermaid sources render. |
| `./tools/mint-routes reconcile` | PASS: 141 | Route registry parity is GREEN. |

The dead-key gate retains two genuine RED-to-GREEN sequences:

- missing registry: `2 failed, 1 passed` to `3 passed`;
- Opus code-truth extension: `1 failed, 2 passed` to `3 passed`.

Its reader proof is deliberately bounded: exact `repo/path.dart:line`, valid
file and line, then one row-derived semantic token inside only the surrounding
plus-or-minus-five-line window. It does not accept a whole-file grep.

### Flutter verification

| proof bundle | result | interpretation |
|---|---|---|
| Mandated scan, route, navigation, and provider verification bundle | PASS: 170 | Required mobile provider/route surfaces, including scan-session recovery, are GREEN. |
| Targeted G1, report, advisor, confidence, and scenario verification bundle | PASS: 41 | G1-specific provider boundary and product corrections are GREEN. |
| `no_domain_data_in_extra_test.dart` | RED `+1 -3` to GREEN `+4` | Domain casts, scan payload push, and financial prefill violations are removed. |
| `no_scenario_writeback_to_profile_test.dart` after mortgage widening | RED `+3 -1` to GREEN `+4` | `/hypotheque` now joins `/epl` and `/rente-vs-capital` in keeping derived scenario output outside durable facts. |
| Provider-boundary `/rapport` gate | RED `+0 -1` to GREEN `+3` | `/rapport` no longer reads persistence directly as a screen API; the route consumes the provider snapshot with bounded recovery. |
| Advisor/report smoke bundle | PASS: 32 inside the targeted bundle | Report compatibility and advisor rendering remain wired after the provider-boundary repair. |
| Targeted Flutter analysis of changed G1 files | CLEAN | No new analyzer finding in the G1 slice. |
| Full `flutter analyze` | 114 findings, exactly inherited | Count equals the pre-G1 baseline; it is not reported as globally clean. |
| Final full `flutter test` on current HEAD | **PASS: `+8500 ~26`, exit 0** | Final runner reported `All other tests passed!`; no failing test remains. |

The exact 170- and 41-test invocations are retained in the lead closure run;
this report records their live counts without reconstructing a shell command
that was not captured in this agent context.

## Runtime evidence

Runtime commit under test: `0d0950181`. Device: iPhone 17 Pro simulator,
iOS 26.2, arm64. All inputs were synthetic.

| harness | result | semantic proof | artifacts |
|---|---|---|---|
| Maestro R1 `/scan/review` | PASS | Cold deep link renders recovery, then reaches scan capture without a domain payload. | `maestro-r1/maestro.log`, `maestro-r1/final-screen.png` |
| Maestro R2 `/scan/impact` | PASS | Cold deep link renders recovery, then returns to `home_route`. | `maestro-r2/maestro.log`, `maestro-r2/final-screen.png` |
| Patrol LAMal real-input flow | PASS: 1/1 | Missing facts → synthetic collection → ledger read → result section on iPhone 17 Pro. | `patrol-lamal/ios_results.xcresult` |

Both Maestro watchdogs exited 0. Patrol independently reports one passed test,
zero failed, zero skipped. This is product runtime proof, not merely tooling
discovery. It proves recovery plus one real collection/consumer loop; the six
future P0 loops and comprehensive restart coverage remain G2-blocking tickets.

## External audit disposition

| lens | live disposition | G1 effect |
|---|---|---|
| Claude Opus code audit | **PASS**, no P0/P1 | Code correctness/privacy/routing gate is satisfied; its P2 observations are triaged below. |
| Claude Opus product-domain audit | Initial NO-GO had no P0 and one P1: `/hypotheque` persisted theoretical capacity/payment. The guard was widened, produced RED `+3 -1`, the write-back was removed, and GREEN is `+4`; fix is committed. | Product-domain P1 is resolved by code plus non-vacuous regression proof. No unresolved product-domain P0/P1 remains. |
| Claude Sonnet architecture rerun | NO-GO named `/rapport`, absent runtime/scorecard, return coverage, and stale matrix/evidence. Those findings are now corrected and committed; live runtime and scorecard exist. | Historical NO-GO is remediated, but Sonnet is not the required final architecture authority. |
| Claude Opus final architecture confirmation | **PASS** on clean SHA `53c733827`; P0 none, P1 none unresolved; external recommendation 9.2/10. | Final G1 closure gate is satisfied. No additional audit carousel is authorized. |

## P1 disposition

There is no untriaged P1 left that blocks the G1 baseline itself. The audit
findings on `/rapport`, mortgage scenario persistence, runtime evidence,
scorecard presence, and stale matrix state were fixed and committed.

The 23 rows in `.planning/goals/G1-blocking-gate-tickets.md` intentionally
remain `ticket_only`. They cover provenance, source crosswalk, provider
convergence, semantic round trips, freshness/reconfirmation, return-to-origin,
scenario identity, source-sensitive facts, and comprehensive persistence. They
are accepted as the executable debt inventory delivered by G1, but every row
blocks G2. A ticket proves actionable scope, not runtime implementation.

## P2 debt tickets — accepted and non-blocking

These findings remain P2. They must not be promoted to P1 merely to inflate the
closure checklist:

| debt id | owner | exact debt | target | blocks G1 | blocks G2 by itself |
|---|---|---|---|---|---|
| `G1-P2-GATE-NAME-01` | `mint-quality-gate` | The hard-floor test name is broader than its actual static `state.extra` scope. | Rename/rescope the gate or widen it in a later quality slice. | no | no |
| `G1-P2-RUNTIME-SHA-01` | `mint-quality-gate` | Runtime artifacts honestly prove commit `0d0950181`, earlier than the final clean audit SHA. | Keep the declared SHA with the artifacts; rerun only when later code materially changes the proven flows. | no | no |
| `G1-P2-PROPERTY-01` | `mint-mobile` | Property market/effective-value crosswalk can conflate a display-only confidence axis. | `coach_profile_confidence_adapter.dart` and semantic fixture. | no | no |

These scorecard-local debt IDs do not replace or alter the 23 checked-in G2
blocking tickets.

## Privacy and evidence hygiene

- Scan extraction is session-ID based; raw domain payloads no longer transit
  route state.
- Runtime proof used only synthetic financial inputs.
- No real user document, identifier, production write, prompt content, or
  screenshot was added to the evidence package.
- Claude code audit found no P0/P1 privacy issue.

## Final release decision

- Final full Flutter is GREEN: `+8500 ~26`, exit 0.
- Final architecture Opus is PASS on clean SHA `53c733827`.
- No P0 or unresolved P1 remains for G1.
- The three P2 findings above are accepted, explicit debt.
- G1 is accepted at 9.2/10.
- G2/G3 remain blocked until the 23 behavioral tickets are implemented.

**Current G1 decision: FINAL PASS / G1 ACCEPTED**

**G2 allowed? NO**

**G3 allowed? NO**
