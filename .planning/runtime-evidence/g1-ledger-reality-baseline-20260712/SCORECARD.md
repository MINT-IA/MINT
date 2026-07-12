# G1 Ledger Reality Baseline — SCORECARD

Date: 2026-07-12

Status: **FINAL PASS / G1 ACCEPTED**

Quality threshold: 9.0/10

Current score: **9.2/10**

The final full Flutter suite is GREEN and the final architecture Opus audit is
PASS on clean SHA `53c733827`, with no P0 and no unresolved P1. G1 is accepted.
G2/G3 remain blocked independently by 23 exact behavioral tickets.

## Fixed-rubric score

| dimension | max | score | evidence / deduction |
|---|---:|---:|---|
| Data contract | 2.0 | 1.9 | Four matrices, 73-key canonical registry, provider/scenario boundary, 23 exact tickets, and bounded code-truth reader gate are committed. Comprehensive runtime behavior remains intentionally ticketed for G2. |
| Swiss correctness | 1.5 | 1.4 | Swiss/product audit defines fail-closed and source-sensitive boundaries. Product-domain Opus found no P0; its mortgage P1 was fixed with RED `+3 -1` to GREEN `+4`. P2 display debts remain below. |
| UX lucidity | 1.5 | 1.4 | Route matrix covers empty/partial/stale/error/complete/return states; Maestro proves both cold scan recoveries and Patrol proves one real missing-fact-to-result loop. Six-loop runtime breadth remains ticketed. |
| Runtime proof | 1.5 | 1.2 | Maestro R1/R2 PASS and Patrol LAMal 1/1 PASS on iPhone 17 Pro with retained artifacts. Artifacts honestly declare tested SHA `0d0950181`, earlier than final audit SHA, and do not prove every future loop. |
| Automated tests | 1.0 | 1.0 | Required Python 6+7+5+3 PASS, full tools checks 158 PASS, routes 141, Flutter bundles 170 and 41 PASS, targeted analyze clean, and final full Flutter GREEN at `+8500 ~26`, exit 0. |
| External audit | 1.0 | 1.0 | Code Opus PASS; product-domain P1 fixed with a widened non-vacuous guard; final architecture Opus PASS on clean SHA `53c733827`, P0 none and P1 none unresolved. |
| Integration / privacy hygiene | 1.0 | 0.9 | Provider-boundary and scenario leaks are repaired, scan payloads are ID-only, runtime data is synthetic, and no audit P0/P1 privacy issue remains. P2 display/tooling debt is explicit. |
| Diff discipline | 0.5 | 0.4 | G1 fixes are split into reviewable pushed commits through `85a9b4d3b`; this isolated evidence package is the final pre-confirmation slice. |
| **Total** | **10.0** | **9.2** | **G1 threshold met — FINAL PASS.** |

## Deliverables and gates

| deliverable / gate | status | proof |
|---|---|---|
| Ledger gap matrix | GREEN | `.planning/goals/G1-ledger-gap-matrix.md` |
| Provider boundary | GREEN | `.planning/goals/G1-provider-boundary.md` |
| Scenario lever matrix | GREEN | `.planning/goals/G1-scenario-lever-matrix.md` |
| Route state matrix | GREEN | `.planning/goals/G1-route-state-matrix.md` |
| Blocking registry | GREEN as G1 contract | 23 complete `ticket_only` rows; each still blocks G2. |
| P0 dead-key hard floor | GREEN | Registry RED `2F/1P`; code-truth RED `1F/2P`; final `3P`. |
| Domain data in route state | GREEN | RED `+1 -3`; final `+4`. |
| Scenario output outside facts | GREEN | Mortgage widening RED `+3 -1`; final `+4`. |
| `/rapport` provider boundary | GREEN | RED `+0 -1`; final `+3`; advisor/report smoke GREEN. |
| Mermaid | GREEN | Render guard PASS. |
| Routes | GREEN | Reconcile PASS: 141. |
| Runtime | GREEN for G1 baseline evidence | Maestro R1/R2 PASS; Patrol LAMal 1/1 PASS. |
| Final full Flutter suite | GREEN | `+8500 ~26`, exit 0, `All other tests passed!`. |
| Final architecture Opus | GREEN | PASS on clean SHA `53c733827`; P0 none, P1 none unresolved. |

## Verification inventory

| verification | result |
|---|---|
| Required Python spec-reality subset | 6 passed |
| Required ledger/persistence subset | 7 passed |
| Required DataQuest/screen subset | 5 passed |
| G1 dead-key gate | 3 passed |
| Full `tools/checks/tests` | 158 passed |
| Route registry | 141 passed |
| Mermaid render | PASS |
| Mandated Flutter scan/routes/providers bundle | 170 passed |
| Targeted G1/report/advisor bundle | 41 passed |
| Full Flutter analyze | 114 findings, exactly inherited |
| Targeted analyze | CLEAN |
| Maestro R1 and R2 | PASS / PASS |
| Patrol LAMal on iPhone 17 Pro | 1 passed, 0 failed, 0 skipped |
| Final full Flutter test | PASS: `+8500 ~26`, exit 0 |

The exact 170- and 41-test shell invocations remain in the lead closure run;
the scorecard records verified counts without inventing reconstructed commands.

## Audit disposition

| audit | disposition |
|---|---|
| Claude Opus code | PASS; no P0/P1. |
| Claude Opus product-domain | No P0. Mortgage P1 fixed and committed; guard widened with RED-to-GREEN proof. |
| Claude Sonnet architecture rerun | Historical NO-GO findings `/rapport`, runtime, scorecard, return/stale evidence are corrected and committed. |
| Claude Opus architecture final | PASS on clean SHA `53c733827`; external recommended score 9.2/10. |

## P2 debt — triaged, not P1

| debt id | finding | owner / target | phase effect |
|---|---|---|---|
| `G1-P2-GATE-NAME-01` | Hard-floor name is broader than its static `state.extra` matcher scope. | `mint-quality-gate`; rename/rescope or widen later | P2; does not block G1/G2 by itself. |
| `G1-P2-RUNTIME-SHA-01` | Runtime evidence targets `0d0950181`, earlier than final clean audit SHA, and declares that boundary honestly. | `mint-quality-gate`; retain SHA provenance with artifacts | P2; no contradictory runtime claim. |
| `G1-P2-PROPERTY-01` | Property market/effective crosswalk can conflate a display-only confidence axis. | `mint-mobile`; adapter semantic fixture | P2; no P0-loop financial output impact. |

These evidence-local debt IDs do not replace or reduce the 23 checked-in G2
blocking tickets.

## Release decision

- G1 baseline: **FINAL PASS / ACCEPTED at 9.2/10**.
- Final architecture Opus is PASS; no P0 or unresolved P1 remains.
- `G2 allowed?` **NO** — all 23 behavioral tickets must be implemented first.
- `G3 allowed?` **NO**.

G1 closure does not authorize G2: implement and verify all 23 blocking tickets
before any G2/G3 work begins.
