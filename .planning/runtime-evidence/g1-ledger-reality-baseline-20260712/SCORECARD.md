# G1 Ledger Reality Baseline — SCORECARD

Date: 2026-07-14

Status: **REOPENED / NO-GO**

Quality threshold: **9.0/10**

Current interim score: **8.2/10**

The historical acceptance at `53c733827` is superseded for release purposes.
G1 was reopened after the AVS couple path could manufacture a complete
household projection from incomplete partner evidence. The canonical Phase 37
registry now has **31 rows: 13 GREEN, 17 `ticket_only`, 1 `red_proven`**. The B2
fail-closed slice and its exact runtime proof are green. The financial report/PDF now also keeps
AVS, LPP and 3a point values, totals and replacement rates unknown until the
required evidence exists, with a rebuilt-app Maestro/Patrol proof. Swiss-law,
official-source live wiring, partner-consent and remaining fallback gates still
block G1. `G1-PROV-03` is code- and runtime-GREEN with code/product-domain
audits PASS, but remains dark-launched. G2/G3 are forbidden.

## Blocking ledger

| severity | gate | disposition |
|---|---|---|
| GREEN | Missing partner age/RAMD/official pension could become a false CHF 0 household component. | Fixed end-to-end in `4bd3ba0bf`; household totals/rates/budgets/timelines remain null while known LPP/3a/capital remain visible. |
| GREEN | Invalid current-income denominator could become a known 0% replacement rate. | `safeReplacementRate` and every touched consumer preserve unknown; exact full Flutter suite green. |
| GREEN | B2 missing-official-AVS runtime path. | Exact SHA `c1a66cbea519646f6b5f722f745e7e3b76117b1f`: Maestro PASS with in-flow screenshot; Patrol 1/1 PASS; xcresult PASS. |
| GREEN | `/rapport` and its PDF could manufacture AVS/LPP/3a point values and complete aggregates from questionnaire inputs, a statutory minimum rate, buy-back capacity and annual contribution. | Three pillars now fail closed; totals/rate are null; real evidence CTAs are wired; replacement-rate math is canonical in `financial_core`; obsolete PDF claims are removed; full Flutter 8,514/30/0; exact pushed source `1bb9c8389` has Maestro PASS and Patrol 2/2 PASS; Opus first pass plus Sonnet rerun code/product-domain PASS without P0/P1. |
| GREEN — G1-PROV-03 code + runtime | A tax scan could remain an untyped island, promote an average rate to marginal, publish before persistence, leak source text, or die on cold restart. | Code accepted at `5a772865b` with 143/143 targeted and frozen full suite 8,896/33/0. Exact runtime SHA `ac74672db` passed normal iOS build/install, Maestro flag-off, Patrol writer → explicit process death → separate reader, two independent xcresults 1/1, restoration and final Doctor. Opus code and product-domain audits PASS with zero P0/P1. Production flags remain false; activation is not claimed. |
| GREEN — G1-LDG-04 nominal | Display defaults or invalid persisted values could become known facts. | Fixed in `f49ba797c`: canton/expense/conversion readiness requires canonical marker plus exact timestamp path(s); invalid/negative/NaN/infinite numeric values remain partial and explicit zero expenses remain known. Canton-domain weakness closed by `62e8ca7d5`: invalid/blank/forged canton evidence fails closed and valid codes normalize. Exact proof: RED 5 failures, GREEN 30/30, models+navigation+routes 494/494 in `g1-ldg04-bnd04-f49ba797c.md`. |
| GREEN — G1-BND-04 | The lazy production proxy could miss profile mutations until a MintState UI consumer materialised it. | Fixed in `f49ba797c`: the real `MintApp` proxy is eager and the production-context test observes one notification per salary and provenance-only mutation. Exact RED-to-GREEN evidence: `g1-ldg04-bnd04-f49ba797c.md`. |
| GREEN — G1-LDG-06A core only | The first certificate-only Fitness slice penalized married/registered owners when optional spouse evidence was absent and accepted certified gap years outside `0..44`. | Quality NO-GO at `1f87a79b4`; fixed in `d44d2aa83`: the AVS Fitness criterion is person-owned and invariant to spouse/status, while self/spouse evidence rejects `-1` and `45`. Rerun: static 8/8, targeted 54/54, wider models 321/321, Doctor 7/7, analyze/diffcheck PASS. Exact proof: `g1-ldg06a-core-d44d2aa83.md`. This does not close the global consumer inventory or change 8.2/10 NO-GO. |
| GREEN — registered-partnership AVS defect | Registered partnership could be lost or treated as cohabitation instead of marriage-equivalent for AVS. | Reverified at `ac74672db`: typed enum, migration aliases, wizard/DataBlock round trip and AVS predicates are wired; 285 targeted Flutter tests across the AVS review are GREEN. Adjacent non-AVS tax/LPP equality checks remain separate ticket scope. |
| P0 — narrowed AVS splitting contract | The obsolete fixed-scale cap and salary-duration splitting proxy were unsafe. | Fixed-scale cap/proxy are removed or quarantined; typed cap preserves owner, entitlement, scales and unknown partner. Still open: owner-scoped official splitting evidence, statutory-trigger state and production wiring. |
| GREEN defect / G1-AVS-02 still open | The 13th AVS could be smoothed into an ordinary monthly uplift. | Reverified absent in live mobile/backend paths: ordinary pension stays 12 payments and the supplement is separate/December-only. The broader G1-AVS-02 ticket remains open for official evidence ingestion, persistence, dedicated UI/PDF line and activation/runtime proof. |
| G1 floor | Eighteen registry rows remain non-green. | 17 are `ticket_only`; `G1-RUNTIME-01` is `red_proven` on the distinct salary/canton → mortgage cold-relaunch path. PROV-03 runtime does not close that global runtime ticket. |
| G1 floor | Static AVS `null -> 0` and undeclared-evidence consumers remain outside the closed report slice. | The report/PDF hard floor is 8/8 GREEN. Continue the canonical inventory across profile, Pulse, expat and remaining live consumers; a slice-local green is not a global waiver. |
| G1 source | Official future-pension ingestion is not yet live end-to-end. | Backend candidate parsing, classifier corpus and default-off boundary are green; mobile review/write-back and live consumer proof remain open. |
| Privacy/product | Optional partner linking lacks purpose-specific field grants and revocation invalidation. | Open; manual partner entry must remain an equal, non-subordinate path. |
| P1 | Adjacent report tax and LPP buy-back paths still expose exact/default-backed values. | Ordered next report-domain slice: neutralize missing-data tax output; fix canonical married status; verify AVS21 horizon; audit the separate buy-back tax-savings path. The stale 6% PDF claim is closed. |
| Audit | Remaining legal/source/live-consumer slices lack bounded final Claude code and product-domain confirmation. | The three-pillar report slice has converged; wrapper-only audits remain mandatory for every subsequent financial path. |

## Fixed-rubric score

| dimension | max | score | current evidence / deduction |
|---|---:|---:|---|
| Data contract | 2.0 | 1.8 | Field provenance no longer trusts a document-wide marker; missing official pensions stay nullable. Official writer/source-date contract remains open. |
| Swiss correctness | 1.5 | 0.7 | False complete AVS totals, registered-partnership equivalence and monthly-smoothed 13th pension are corrected. Typed official splitting evidence/trigger/wiring and other open registry contracts still block acceptance. |
| UX lucidity | 1.5 | 1.3 | Report and PDF now expose neutral AVS/LPP/3a evidence gaps with real recovery CTAs instead of fabricated amounts. Couple recovery and consent UX remain open. |
| Runtime proof | 1.5 | 1.5 | B2 has an exact committed SHA; the report runtime indexed-diff SHA exactly equals pushed commit `1bb9c8389`, with full Doctor/build, built-versus-installed payload proof, Maestro semantic positives/negatives plus visual artifacts, Patrol 2/2 and xcresult summary. |
| Automated tests | 1.0 | 1.0 | Final report/PDF snapshot: analyze 0; 8,514 successful + 30 skipped; 0 fail. Targeted report matrix 95/95; B2 matrix 187/187. |
| External audit | 1.0 | 0.7 | Report/PDF and PROV-03 code/product-domain lenses PASS without P0/P1. The PROV-03 architecture first pass correctly kept full G1 NO-GO because acceptance evidence was stale; a single Sonnet architecture rerun follows reconciliation. Remaining global slices are not converged. |
| Integration / privacy hygiene | 1.0 | 0.7 | Synthetic runtime data and field-scoped provenance are green; partner grants/revocation and official-source persistence remain open. |
| Diff discipline | 0.5 | 0.5 | Provenance, recovery, nullable contract, wiring docs, runtime harness and screenshot fix are atomic commits with regular pushes. |
| **Total** | **10.0** | **8.2** | **Below 9.0 and hard blockers remain; G1 stays NO-GO.** |

## Verification inventory

| verification | result |
|---|---|
| Flutter analyze on exact staged B2 snapshot | PASS, 0 issues |
| Full Flutter unit/widget suite on exact staged B2 snapshot | PASS: 8,538 visible pass, 28 skipped, 0 failed |
| Final Flutter suite after report/PDF quarantine and hook fixes | PASS: 8,514 successful, 30 skipped, 0 failed |
| Targeted report/PDF/retirement matrix after hook fixes | PASS: 95/95, including replacement-rate and obsolete-footer contracts |
| Targeted B2 regression matrix | PASS: 187/187 |
| Canonical RetirementProjection suite | PASS: 29/29, including 14 non-AVS invariants |
| Provenance slice | PASS: 117 targeted tests plus analyze |
| ARB parity | PASS: 6 languages, 6,900 keys each |
| Route reconcile | PASS |
| Mermaid render guard | PASS |
| Patrol tooling guard | PASS |
| Full Mint OS Doctor at exact pushed report source `1bb9c8389` | PASS; committed mobile diff equals the tested indexed diff |
| iOS simulator build/install at exact pushed report source `1bb9c8389` | PASS; built and installed `App.framework/App` and kernel blob match |
| Maestro missing-official-AVS flow | PASS, watchdog exit 0; in-flow screenshot retained |
| Patrol missing-official-AVS contract | PASS: 1 passed, 0 failed, 0 skipped |
| `xcresulttool` independent summary | PASS: `result=Passed`, `totalTestCount=1` |
| Three-pillar report canonical runtime | PASS: 32 indexed mobile files and diff SHA stable and identical to pushed `1bb9c8389`; rebuilt/installed App.framework; Maestro exit 0; separate AVS/LPP/3a pending captures; Patrol 2/2 and xcresult PASS |
| Report/PDF external audits | PASS: Opus code + product-domain first pass; Sonnet code + product-domain rerun; no P0/P1 |
| PROV-03 exact-SHA runtime | PASS at `ac74672db`: normal iOS build/install; Maestro flag-off before/after; Patrol writer/process-death/reader 1/1 + 1/1; restored normal app; Doctor, Patrol guard and 19/19 orchestrator contracts GREEN |
| PROV-03 exact-SHA full Flutter suite | PASS at `ac74672db`: analyze 0; 8,899 passed, 33 skipped, 0 failed |
| PROV-03 external audits | PASS: Opus code and product-domain, no P0/P1. Architecture first pass NO-GO for stale G1 acceptance docs, not for a PROV-03 implementation defect. |
| Phase 37 registry | 31 total: 13 GREEN, 17 `ticket_only`, 1 `red_proven`; count-drift guard RED→GREEN added to active acceptance docs |

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
- `1bb9c8389` — quarantine uncertified AVS/LPP/3a report and PDF values with exact runtime contracts.
- `5a772865b` — accept the typed, fail-closed PROV-03 code gate.
- `ac74672db` — complete the exact-SHA PROV-03 process-death runtime chain.

## Release decision

- G1: **REOPENED / NO-GO at 8.2/10**.
- `G2 allowed?` **NO**.
- `G3 allowed?` **NO**.
- Current machine truth: **13/31 GREEN; 18 hard floors open**.
- Next ordered gates: one Sonnet architecture rerun after evidence
  reconciliation; then dependency-valid remaining G1 tickets, including
  PROV-02/BND-02A, AVS splitting evidence, G1-AVS-02 activation and the global
  `G1-RUNTIME-01`. Full re-score only after every hard floor is green.
