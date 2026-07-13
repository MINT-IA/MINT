# G1 Ledger Reality Baseline — SCORECARD

Date: 2026-07-13

Status: **REOPENED / NO-GO**

Quality threshold: **9.0/10**

Current interim score: **7.6/10**

The historical acceptance at `53c733827` is superseded for release purposes.
G1 was reopened after the AVS couple path could manufacture a complete
household projection from incomplete partner evidence. The B2 fail-closed slice
and its exact runtime proof are now green, but Swiss-law, official-source,
partner-consent and remaining fallback gates still block G1. G2/G3 are
forbidden.

## Blocking ledger

| severity | gate | disposition |
|---|---|---|
| GREEN | Missing partner age/RAMD/official pension could become a false CHF 0 household component. | Fixed end-to-end in `4bd3ba0bf`; household totals/rates/budgets/timelines remain null while known LPP/3a/capital remain visible. |
| GREEN | Invalid current-income denominator could become a known 0% replacement rate. | `safeReplacementRate` and every touched consumer preserve unknown; exact full Flutter suite green. |
| GREEN | B2 missing-official-AVS runtime path. | Exact SHA `c1a66cbea519646f6b5f722f745e7e3b76117b1f`: Maestro PASS with in-flow screenshot; Patrol 1/1 PASS; xcresult PASS. |
| P0 | Registered partnership is not preserved as marriage-equivalent AVS status. | Open; typed enum/aliases/UI round trip and legal predicates required. |
| P0 | Couple cap is fixed-scale and splitting can overstate exactness. | Open; scale-aware cap, entitlement/exception states and splitting evidence contract required. |
| P0 | The 13th AVS pension is still treated as a monthly uplift in legacy paths. | Open; December cash-flow model required. |
| G1 floor | Static AVS `null -> 0` and undeclared-evidence consumers remain. | `tools/checks/tests/test_g1_avs_certified_null_contract.py` intentionally RED until the inventory is migrated or quarantined. |
| G1 source | Official future-pension parser/writer has no field `source_date` and kill switch. | Open; self-only first, explicit personal labels, secure persistence and default-off flag required. |
| Privacy/product | Optional partner linking lacks purpose-specific field grants and revocation invalidation. | Open; manual partner entry must remain an equal, non-subordinate path. |
| Audit | Current B2 plus subsequent legal/source slices lack bounded final Claude code and product-domain confirmation. | Open; wrapper only, no raw `claude -p`. |

## Fixed-rubric score

| dimension | max | score | current evidence / deduction |
|---|---:|---:|---|
| Data contract | 2.0 | 1.8 | Field provenance no longer trusts a document-wide marker; missing official pensions stay nullable. Official writer/source-date contract remains open. |
| Swiss correctness | 1.5 | 0.7 | False complete AVS totals are blocked, but registered partnership, scale-aware cap, splitting and 13th-pension cash flow are P0-open. |
| UX lucidity | 1.5 | 1.2 | Partial dashboard explains why CI is insufficient, shows known capital and routes to official form 318.282. Couple recovery and consent UX remain open. |
| Runtime proof | 1.5 | 1.5 | Exact committed SHA, full Doctor/build, Maestro semantic positives/negatives plus visual artifact, Patrol 1/1 and xcresult summary. |
| Automated tests | 1.0 | 1.0 | Exact B2 snapshot: analyze 0; 8,538 visible pass + 28 skipped; 0 fail. Targeted regression matrix 187/187. |
| External audit | 1.0 | 0.2 | Historical B1 audits are retained, but current B2/legal/source architecture still requires bounded code and product-domain convergence. |
| Integration / privacy hygiene | 1.0 | 0.7 | Synthetic runtime data and field-scoped provenance are green; partner grants/revocation and official-source persistence remain open. |
| Diff discipline | 0.5 | 0.5 | Provenance, recovery, nullable contract, wiring docs, runtime harness and screenshot fix are atomic commits with regular pushes. |
| **Total** | **10.0** | **7.6** | **Below 9.0; G1 remains NO-GO.** |

## Verification inventory

| verification | result |
|---|---|
| Flutter analyze on exact staged B2 snapshot | PASS, 0 issues |
| Full Flutter unit/widget suite on exact staged B2 snapshot | PASS: 8,538 visible pass, 28 skipped, 0 failed |
| Targeted B2 regression matrix | PASS: 187/187 |
| Canonical RetirementProjection suite | PASS: 29/29, including 14 non-AVS invariants |
| Provenance slice | PASS: 117 targeted tests plus analyze |
| ARB parity | PASS: 6 languages, 6,881 keys each |
| Route reconcile | PASS |
| Mermaid render guard | PASS |
| Patrol tooling guard | PASS |
| Full Mint OS Doctor at exact runtime SHA | PASS |
| iOS simulator build at exact runtime SHA | PASS |
| Maestro missing-official-AVS flow | PASS, watchdog exit 0; in-flow screenshot retained |
| Patrol missing-official-AVS contract | PASS: 1 passed, 0 failed, 0 skipped |
| `xcresulttool` independent summary | PASS: `result=Passed`, `totalTestCount=1` |

## Exact B2 evidence

- Runtime SHA: `c1a66cbea519646f6b5f722f745e7e3b76117b1f`.
- Evidence: `avs-b2-runtime-c1a66cbea/RUNTIME_PROOF.md`.
- Visual: `avs-b2-runtime-c1a66cbea/maestro/final-screen.png`.
- Logs: full Doctor, iOS build, Maestro watchdog, Patrol and xcresult summary.
- Integrity: `avs-b2-runtime-c1a66cbea/SHA256SUMS`.

## Current pushed chain

- `7758defa4` — stop legacy AVS provenance laundering.
- `3812b1a7c` — route AVS recovery to official calculation 318.282.
- `4bd3ba0bf` — fail closed end-to-end without official self/spouse pensions.
- `13fb1386b` — align the ten-invariant Mermaid contract.
- `cf69f91f9` — add Maestro and Patrol missing-AVS runtime contracts.
- `c1a66cbea` — capture the visual proof inside the passing Maestro flow.

## Release decision

- G1: **REOPENED / NO-GO at 7.6/10**.
- `G2 allowed?` **NO**.
- `G3 allowed?` **NO**.
- Next ordered gates: bounded current audits; official parser/source-date/kill
  switch; legal status/cap/splitting/13th/partner grants; remaining fallback
  inventory; full re-score only after every hard floor is green.
