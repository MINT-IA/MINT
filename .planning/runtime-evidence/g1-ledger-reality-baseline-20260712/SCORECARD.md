# G1 Ledger Reality Baseline — SCORECARD

Date: 2026-07-16

Status: **REOPENED / NO-GO**

Quality threshold: **9.0/10**

Current interim score: **8.2/10**

The historical acceptance at `53c733827` is superseded for release purposes.
G1 was reopened after the AVS couple path could manufacture a complete
household projection from incomplete partner evidence. The canonical Phase 37
registry now has **31 rows: 17 GREEN, 13 `ticket_only`, 1 `red_proven`**. The B2
fail-closed slice and its exact runtime proof are green. The financial report/PDF now also keeps
AVS, LPP and 3a point values, totals and replacement rates unknown until the
required evidence exists, with a rebuilt-app Maestro/Patrol proof. Swiss-law,
official-source live wiring, partner-consent and remaining fallback gates still
block G1. `G1-PROV-03` is code- and runtime-GREEN with code/product-domain
audits PASS, but remains dark-launched. G2/G3 are forbidden.

`G1-PROV-02` is also ticket- and runtime-GREEN at exact SHA `30728b8a0671`:
same-command semantic RED-to-GREEN, native writer, explicit process death,
separate cold reader, restored default-off Maestro proof and bounded Claude
audits. Both LPP flags remain false. Its downstream consumer and represented-
accountability outcome are now technical GREEN at exact SHA `1d022c508`; the
eight external production facts remain activation blockers, not waived work.

`G1-BND-03` is ticket- and exact-SHA runtime-GREEN at `7ed54e282`: its
identical command passes 12/12, and the real synthetic writer → explicit
process death → cold reader chain continues through an exact Git-archive
production build, strict signature/xattr verification, install and Maestro.
Cleanup/privacy checks and both wrapper-only Opus audit lenses pass with no
P0/P1. This promotion does not close `G1-RUNTIME-01` or authorize G2/G3.

## Blocking ledger

| severity | gate | disposition |
|---|---|---|
| GREEN | Missing partner age/RAMD/official pension could become a false CHF 0 household component. | Fixed end-to-end in `4bd3ba0bf`; household totals/rates/budgets/timelines remain null while known LPP/3a/capital remain visible. |
| GREEN | Invalid current-income denominator could become a known 0% replacement rate. | `safeReplacementRate` and every touched consumer preserve unknown; exact full Flutter suite green. |
| GREEN | B2 missing-official-AVS runtime path. | Exact SHA `c1a66cbea519646f6b5f722f745e7e3b76117b1f`: Maestro PASS with in-flow screenshot; Patrol 1/1 PASS; xcresult PASS. |
| GREEN | `/rapport` and its PDF could manufacture AVS/LPP/3a point values and complete aggregates from questionnaire inputs, a statutory minimum rate, buy-back capacity and annual contribution. | Three pillars now fail closed; totals/rate are null; real evidence CTAs are wired; replacement-rate math is canonical in `financial_core`; obsolete PDF claims are removed; full Flutter 8,514/30/0; exact pushed source `1bb9c8389` has Maestro PASS and Patrol 2/2 PASS; Opus first pass plus Sonnet rerun code/product-domain PASS without P0/P1. |
| GREEN — G1-PROV-03 code + runtime | A tax scan could remain an untyped island, promote an average rate to marginal, publish before persistence, leak source text, or die on cold restart. | Code accepted at `5a772865b` with 143/143 targeted and frozen full suite 8,896/33/0. Exact runtime SHA `ac74672db` passed normal iOS build/install, Maestro flag-off, Patrol writer → explicit process death → separate reader, two independent xcresults 1/1, restoration and final Doctor. Opus code and product-domain audits PASS with zero P0/P1. Production flags remain false; activation is not claimed. |
| GREEN — G1-PROV-02 ticket + runtime | Self/manual-partner LPP facts or provenance could disappear after restart, or publish before persistence. | Same command: semantic RED at `ffaa2c6f` and 22/22 GREEN at exact SHA `30728b8a0671`. Native writer → explicit termination → cold reader passed 1/1 + 1/1; normal build restoration and default-off Maestro before/after passed. Flutter 9,031/36/0 and backend 6,108/7/0. Code/product-domain audits PASS with every finding dispositioned. Activation remains NO pending the named downstream-consumer and legal/privacy accountability decisions. |
| GREEN — G1-BND-02 / technical G1-BND-02A | Partner certificate facts require an exact owner/active-receipt gate and visible fail-closed consumer; legacy nominative receipts must never authorize LPP; exact self 0.02 must stay distinct from missing; lifecycle and rights surfaces must fail closed. | RED remains archived at `fcf720c48`. At exact SHA `1d022c508`, BND-02 passes 7/7 and the identical combined BND-02A command passes backend 66/66 + mobile 20/20. Patrol writer→terminate→cold-reader passes 1/1 + 1/1 with restored normal build; Maestro completes 17/17 flag-off/stale-recovery steps; four Claude-wrapper final confirmations pass with P0=0/P1=0. Technical GREEN leaves every flag false. Eight external facts still make activation and G1 NO-GO. |
| GREEN — G1-BND-03 ticket + runtime | Stale budget cache/cadence collisions could diverge from the canonical ledger, recompute the wrong charge delta, or disappear after process death. | Semantic RED remains at `683e2a1f2`. At exact pushed SHA `7ed54e282`, the identical command passes 12/12; Patrol writer→terminate→cold-reader, exact physical Git-archive production build, CodeSign/xattr checks, install and Maestro all pass. Fourteen sanitized logs, restoration/privacy verification and wrapper code/product-domain audits are accepted with P0=0/P1=0. |
| GREEN — G1-LDG-04 nominal | Display defaults or invalid persisted values could become known facts. | Fixed in `f49ba797c`: canton/expense/conversion readiness requires canonical marker plus exact timestamp path(s); invalid/negative/NaN/infinite numeric values remain partial and explicit zero expenses remain known. Canton-domain weakness closed by `62e8ca7d5`: invalid/blank/forged canton evidence fails closed and valid codes normalize. Exact proof: RED 5 failures, GREEN 30/30, models+navigation+routes 494/494 in `g1-ldg04-bnd04-f49ba797c.md`. |
| GREEN — G1-BND-04 | The lazy production proxy could miss profile mutations until a MintState UI consumer materialised it. | Fixed in `f49ba797c`: the real `MintApp` proxy is eager and the production-context test observes one notification per salary and provenance-only mutation. Exact RED-to-GREEN evidence: `g1-ldg04-bnd04-f49ba797c.md`. |
| GREEN — G1-LDG-06A core only | The first certificate-only Fitness slice penalized married/registered owners when optional spouse evidence was absent and accepted certified gap years outside `0..44`. | Quality NO-GO at `1f87a79b4`; fixed in `d44d2aa83`: the AVS Fitness criterion is person-owned and invariant to spouse/status, while self/spouse evidence rejects `-1` and `45`. Rerun: static 8/8, targeted 54/54, wider models 321/321, Doctor 7/7, analyze/diffcheck PASS. Exact proof: `g1-ldg06a-core-d44d2aa83.md`. This does not close the global consumer inventory or change 8.2/10 NO-GO. |
| GREEN — registered-partnership AVS defect | Registered partnership could be lost or treated as cohabitation instead of marriage-equivalent for AVS. | Reverified at `ac74672db`: typed enum, migration aliases, wizard/DataBlock round trip and AVS predicates are wired; 285 targeted Flutter tests across the AVS review are GREEN. Adjacent non-AVS tax/LPP equality checks remain separate ticket scope. |
| P0 — narrowed AVS splitting contract | The obsolete fixed-scale cap and salary-duration splitting proxy were unsafe. | Fixed-scale cap/proxy are removed or quarantined; typed cap preserves owner, entitlement, scales and unknown partner. Still open: owner-scoped official splitting evidence, statutory-trigger state and production wiring. |
| GREEN defect / G1-AVS-02 still open | The 13th AVS could be smoothed into an ordinary monthly uplift. | Reverified absent in live mobile/backend paths: ordinary pension stays 12 payments and the supplement is separate/December-only. The broader G1-AVS-02 ticket remains open for official evidence ingestion, persistence, dedicated UI/PDF line and activation/runtime proof. |
| G1 floor | Fourteen registry rows remain non-green. | 13 are `ticket_only`; only `G1-RUNTIME-01` is `red_proven`. The BND-02/BND-02A and BND-03 runtimes are slice-specific and do not close that distinct salary/canton→mortgage runtime floor. |
| G1 floor | Static AVS `null -> 0` and undeclared-evidence consumers remain outside the closed report slice. | The report/PDF hard floor is 8/8 GREEN. Continue the canonical inventory across profile, Pulse, expat and remaining live consumers; a slice-local green is not a global waiver. |
| G1 source | Official future-pension ingestion is not yet live end-to-end. | Backend candidate parsing, classifier corpus and default-off boundary are green; mobile review/write-back and live consumer proof remain open. |
| Privacy/product activation | Controller identity, privacy contact, Anthropic role/DPA and processing regions, transfer/TIA, retention/ZDR, AIPD decision and the public account-free rights channel remain unverified. | Activation stays fail-closed; optional linking is not required and manual partner entry remains an equal path. |
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
| External audit | 1.0 | 0.7 | Report/PDF, PROV-03, BND-02/BND-02A and BND-03 closure lenses PASS without P0/P1. The BND-03 archive retains one wrapper-only Opus confirmation per lens without an audit carousel. Full G1 remains NO-GO for 14 open rows; remaining global slices are not converged. |
| Integration / privacy hygiene | 1.0 | 0.7 | Synthetic runtime data, exact owner/receipt lifecycle and targeted invalidation are green; eight external activation facts and official-source persistence remain open. |
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
| PROV-03 external audits | PASS: Opus code and product-domain, no P0/P1. Sonnet architecture rerun at `9daede134` confirms PROV-03 clean and the prior acceptance-drift P1s resolved; full G1 correctly remains NO-GO. |
| PROV-02 exact TDD ticket proof | PASS: same exact command failed semantically at `ffaa2c6f` then passed 22/22 at `30728b8a0671` |
| PROV-02 exact-SHA runtime | PASS at `30728b8a0671`: normal iOS build/install; Maestro flag-off before/after; Patrol writer/process-death/cold-reader 1/1 + 1/1; restored normal app; Doctor and Patrol guard GREEN; orchestrator contracts 23 passed, 0 failed |
| PROV-02 exact-SHA broad suites | PASS: analyze 0; Flutter 9,031 passed, 36 skipped, 0 failed; backend 6,108 passed, 7 skipped, 0 failed. Global backend Ruff's 93-error baseline remains separately RED and unrelated. |
| PROV-02 external audits | PASS: Opus first pass plus accepted Sonnet code/product-domain reruns; UUID P1 resolved directly; downstream consumer and named legal/privacy accountability decision/outcome remain activation/later-G1 blockers. |
| BND-02/BND-02A independent baselines | Backend functional suite PASS: 6,108/7/0; exact chained baseline truthfully stops on 93 unrelated global Ruff errors. Flutter analyze PASS and full suite 9,031/36/0. |
| BND-02/BND-02A semantic RED | Pushed SHA `fcf720c48`: BND-02 2/4; BND-02A backend 38/6 and mobile 7/12. The authoritative combined command exits 1 on backend and short-circuits mobile; the identical mobile component is recorded independently. No harness/import/fixture/private-certificate failure. |
| BND-02/BND-02A identical-command GREEN | PASS at exact SHA `1d022c508`: focused BND-02 7/7; BND-02A backend 66/66 + mobile 20/20. Technical acceptance only; flags, activation and G1 remain NO-GO. |
| BND-02/BND-02A exact-SHA runtime | PASS: Patrol writer→explicit termination→separate cold reader 1/1 + 1/1, synthetic-only/private-fixture=false, normal build restored; normal exact-SHA Maestro default-off + stale review/impact 17/17. |
| BND-02/BND-02A external audits | PASS: four wrapper-only Opus final confirmations, one code + product-domain lens for backend and mobile, P0=0/P1=0; no audit carousel. |
| BND-03 identical-command GREEN | PASS at exact SHA `7ed54e282`: provider bridge 12/12; dedicated budget setup routing 11/11; targeted analyze/format clean. |
| BND-03 exact-SHA runtime | PASS: Patrol writer→explicit termination→cold reader, exact Git archive/export, real Flutter production build, strict CodeSign/xattr verification, install and Maestro; 13 stages exit 0, 14 sanitized logs, restoration/privacy cleanup PASS. |
| BND-03 external audits | PASS: wrapper-only Opus code and product-domain first passes, P0=0/P1=0; real-toolchain P2 resolved by runtime and route P2 already covered by the dedicated budget setup suite. |
| Sonnet architecture P1 remediation | PASS: exact disclaimer REDs `21/2`, then `14/1`; final targeted 23 passed / 0 failed, accent lint 4/4 files, analyze 0, financial_core 689/689 and full Flutter 8,900 passed / 33 skipped / 0 failed |
| Phase 37 registry | 31 total: 17 GREEN, 13 `ticket_only`, 1 `red_proven`; 14 hard floors remain open |

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
- `30728b8a0` — close the bounded PROV-02 correction and exact-SHA runtime
  source; activation remains default-off.
- `37d8d4a49` — capture the isolated backend partner-accountability RED.
- `fcf720c48` — capture the mobile lifecycle, caller, caisse-rate and UI/ARB RED.
- `1d022c508` — freeze the complete default-off BND-02/BND-02A technical
  implementation at the exact runtime source; activation remains NO-GO.
- `233dd0851` — align the BND-03 budget setup harness with the production
  GoRouter contract.
- `7ed54e282` — close the BND-03 exact-archive runtime source and FileProvider
  CodeSign blocker.

## Release decision

- G1: **REOPENED / NO-GO at 8.2/10**.
- `G2 allowed?` **NO**.
- `G3 allowed?` **NO**.
- Current machine truth: **17/31 GREEN; 14 hard floors open**.
- Next ordered gates remain inside G1: proceed to BND-05 after this BND-03
  promotion diff is accepted; continue the eight external LPP activation facts,
  AVS splitting evidence, G1-AVS-02 activation and the global
  `G1-RUNTIME-01`. The authorized architecture rerun is recorded; do not start
  an audit carousel. Full re-score only after every hard floor is green.
