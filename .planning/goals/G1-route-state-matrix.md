# G1 Route-State Matrix

> Scope: G1 Ledger Reality Baseline only. This matrix specifies the route and
> degraded-state contract required before G2/G3. It does not implement
> DataQuest, CaseRegistry, or the six P0 loops.
>
> Reality audit: 2026-07-12 on
> `codex/mint-product-usability-plan-20260712`. `./tools/mint-routes reconcile`
> confirmed 141 live routes in parity after documented exemptions.

## Verdict and G1 boundary

**Matrix deliverable: GO. HEAD route readiness: 5.8/10. G1 overall: not yet
complete because the two hard-floor gates are not checked in. `G2 allowed?
NO`.**

G1 does **not** implement the target route states below. It records the exact
contract, fixes the mechanical hard floors, and tickets the remaining route
work. G1 may close with exact checked-in tickets and an explicit `G2 allowed?
NO`; implementing DataQuest, CaseRegistry, or all six loops would be forbidden
scope expansion.

All candidate paths exist in `route_metadata.dart`, but the registry cannot
currently encode empty/partial/stale/error handlers: `RouteMeta` exposes only
path, category, owner, auth, kill flag, description, and Sentry tag
(`apps/mobile/lib/routes/route_metadata.dart:31-76`). The target states below
therefore remain a G1 contract until code/tests prove them.

## State and navigation contract

Every non-alias route in this matrix must implement all six states without
using a local illustrative default as a user fact:

| state | required behavior |
|---|---|
| `empty` | Render the route shell and educational context, hide personalised output, show the first exact T0 Ask. |
| `partial` | Render known facts and unresolved facts separately. A high-stakes output may be educational/ranged only when its unknown assumptions are visible; otherwise hide it. |
| `stale` | Display the prior value, source and source date. Primary actions: `Oui, toujours`, `Mettre à jour`, and `Rescanner` when document-sourced. Never show a blank field first. |
| `error` | Show a localized recovery state with `Réessayer` and a safe destination. A last-good result may remain only with its old source/date and confidence. |
| `complete` | Compute only from fresh/explicit required facts plus labelled scenario levers; render range, confidence, source/legal year, and specialist questions. |
| `return-to-origin` | Every collection/reconfirm CTA appends `returnUri=<percent-encoded canonical origin URI>`. On save/reconfirm, return to that URI and recompute. Invalid/missing `returnUri` falls back to `safePop`, then `/home`; never silently `go` to an unrelated hub. |

### i18n placeholder convention

Placeholders in the matrix are contract names, not claims that ARB keys
already exist:

`g1RouteState_<slug>_{emptyTitle,emptyBody,partialBody,staleBody,errorTitle,errorBody,collectCta,reconfirmCta,retryCta}`.

Before implementation, each key must be added with parity across all six ARB
files. Existing shared keys such as `dataBlockStatusMissing`,
`dataQualityEnrich`, `freshnessConfirm`, and `freshnessStale` may replace a
placeholder only when their semantics match exactly.

## Exact P0 candidate routes

`current wiring` uses only the classifications required by G1:
`real-wired`, `local-slider`, `state.extra-domain-payload`,
`provider-island`, and `stub/facade`. Multiple classifications mean the route
has more than one active provenance path.

| loop | route + registry evidence | current wiring + source evidence | empty | partial | stale / reconfirm | error | complete | CTA / returnUri | i18n placeholder slug | Maestro proof | Patrol proof | severity |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Work | `/first-job` (`route_metadata.dart:597-603`) | `real-wired` for salary/age/canton; local scenario salary/activity rate. Ledger gate: `first_job_screen.dart:150-180`; scenario controls: `:486-507,1153-1187`. | Ask `q_gross_salary_annual`, then `q_birth_year`, then `q_canton`; no result cards. | Known-fact card; no personalised result until all T0 facts exist. | Reconfirm salary/canton when annual freshness <0.60; static birth year is reviewed only on contradiction. | Retry provider/recompute; fallback `/explore/travail`. | Payslip/LPP basis from ledger; presets remain visibly hypothetical. | `/data-block/revenu?inputKey=<key>&returnUri=%2Ffirst-job`. | `firstJob` | Checked in: `apps/mobile/.maestro/first_job_ledger.yaml:1`; verifies missing → collect → result, but runtime evidence not recorded in this audit. | Missing route-specific Patrol target: `test/patrol/first_job_runtime_test.dart`. | P1: stale/return proof missing. |
| Work | `/simulator/job-comparison` (`route_metadata.dart:611-616`) | `real-wired` current salary/age plus local current-plan defaults and new-offer levers (`job_comparison_screen.dart:77-101,120-173`). | Ask current `q_gross_salary_annual`, then `q_birth_year`; hide Compare result. | Show ledger facts; unverified current-plan terms marked missing/assumed; new offer remains editable. | Reconfirm current salary and source-sensitive LPP/IJM certificate facts; offer levers do not stale. | Preserve entered offer levers in Case session; retry calculator or back. | Compare sourced current plan against labelled offer assumptions; neutral zero delta stays “comparable”. | Existing exact CTAs at `job_comparison_screen.dart:402-407,487-496`; add `returnUri=%2Fsimulator%2Fjob-comparison`. | `jobComparison` | Checked in: `apps/mobile/.maestro/job_comparison.yaml:1`. | Checked in: `apps/mobile/test/patrol/job_comparison_runtime_test.dart:9-33`; seeded facts, not real-input collection. | P1: current-plan defaults/freshness. |
| Housing | `/hypotheque` (`route_metadata.dart:471-477`) | `local-slider` + `state.extra-domain-payload`; hardcoded facts survive missing provider (`affordability_screen.dart:54-137,215-236`). | Ask gross income → birth year → canton → explicit cash; hide capacity/verdict. | Show known funds/income; no accessible-price output until T0 set. LPP/3a may enrich after base gate. | Reconfirm annual income/cash/LPP/3a/canton; show prior values rather than resetting controls. | Retry calculator; last good range only if its inputs/source dates remain visible. | Range for capacity/payment with retirement affordability guard, confidence and source year. | `/data-block/revenu?inputKey=q_gross_salary_annual&returnUri=%2Fhypotheque`, then birth/canton; cash via patrimoine. | `mortgageAffordability` | Checked in: `apps/mobile/.maestro/f2_datablock_to_mortgage.yaml:1`; proves salary/canton consumption only, not empty/cash/stale. | Missing route-specific Patrol target: `test/patrol/mortgage_affordability_runtime_test.dart`. | P1 G1 ticket/quarantine; product P0 before route release; blocks G2. Domain prefill is P0 G1 if treated as canonical. |
| Housing | `/mortgage/amortization` (`route_metadata.dart:485-490`) | `local-slider`; profile-prefilled current debt/rate but otherwise default-driven (`amortization_screen.dart:30-76`). | Ask current mortgage balance and rate; for tax/retirement output also age, canton, income. | Generic direct-vs-indirect education; no personalised net-cost result. | Reconfirm volatile mortgage balance/rate and annual income/canton. | Retry calculator; route back to `/hypotheque`. | Sourced current-loan base plus local duration/rate sensitivity; no strategy ranking. | `/data-block/patrimoine?inputKey=_coach_dettes_hypotheque&returnUri=%2Fmortgage%2Famortization`; missing dedicated rate collection must be ticketed. | `mortgageAmortization` | Missing dedicated Maestro target: `.maestro/mortgage_amortization.yaml`. | Missing dedicated Patrol target. | P1 G1 exact ticket; product P0 before route release; blocks G2. |
| Housing | `/mortgage/epl-combined` (`route_metadata.dart:491-496`) | `local-slider`; all funding facts have defaults and compute immediately (`epl_combined_screen.dart:28-41,51-112`). | Ask explicit cash → 3a balance → LPP balance → canton; target price is a lever. | Funding-source inventory only; hide personalised mix/order. | Reconfirm cash, 3a and LPP annually; canton annually. | Retry calculator; safe route `/hypotheque`. | Sourced funds plus labelled target price; range/confidence and EPL constraints. | `/data-block/patrimoine?inputKey=q_cash_total&returnUri=%2Fmortgage%2Fepl-combined`, then 3a/LPP/canton. | `mortgageEplCombined` | Missing dedicated Maestro target. | Missing dedicated Patrol target. | P1 G1 exact ticket; product P0 before route release; blocks G2. |
| Housing | `/epl` (`route_metadata.dart:322-328`) | `local-slider` + `state.extra-domain-payload`; profile hydration is partial, and simulated withdrawal mutates LPP (`epl_screen.dart:44-67,79-110,195-219`). | Ask LPP → birth year → canton → last buyback/source-sensitive regulation. | Explain EPL mechanism; hide eligibility/impact and never alter profile. | Reconfirm annual LPP/certificate data; buyback dates remain sourced/static but must be reviewed against latest certificate. | Retry simulator; safe route `/hypotheque`; retain Case lever only. | Range for pension/tax impact with open pension-fund questions. | `/data-block/lpp?returnUri=%2Fepl`; missing exact buyback-date collector must be ticketed. | `epl` | Missing dedicated Maestro target. | Missing dedicated Patrol target. | **P0** scenario-to-fact write. P1 route ownership drift: metadata says retraite while screen contract says logement (`SCREEN_CONTRACTS.md:219`). |
| Retirement | `/rente-vs-capital` (`route_metadata.dart:280-286`) | `local-slider` + `state.extra-domain-payload`; calculates at init from defaults and writes derived/lever values (`rente_vs_capital_screen.dart:61-76,120-135,274-296,414-435`). | Run Retirement Case T0 gate: identity/archetype, canton/commune, family, AVS, LPP, 3a, cash, expenses. Hide personalised comparison. | Known-facts inventory plus general rente/capital forces; no confident option cards. | Reconfirm every annual financial fact; certificate facts offer rescan; current-law sources require legal year/source date. | Retry API/local engine; no fallback may silently reuse illustrative capitals as user data. | Rente/capital/mixed ranges, confidence, survivor/housing/tax/succession questions; no ranking. | Each Ask carries `returnUri=%2Frente-vs-capital`; heavy/specialist facts may route Coach with the same return URI. | `renteVsCapital` | `docs/codex/MAESTRO_FLOWS.md:118-135` specifies F-3, but `apps/mobile/.maestro/f3_retirement.yaml` is not checked in. | Missing dedicated Patrol target: `test/patrol/rente_vs_capital_runtime_test.dart`. | **P0** defaults, domain prefill, derived/lever persistence. |
| Retirement | `/decaissement` (`route_metadata.dart:336-342`) | `stub/facade`: educational screen reads no ledger and marks viewing completed (`optimisation_decaissement_screen.dart:30-60,63-100`). | Retirement Case T0 gate; education can remain visible. | Show missing-fact dossier checklist, not a personalised calendar. | Reconfirm balances, income/budget, legal/tax year, planned large expenses. | Static education remains available; calculation error routes to Coach/back. | Sourced withdrawal timeline ranges with editable Case levers and specialist questions. | First missing Ask with `returnUri=%2Fdecaissement`. | `decumulation` | Missing dedicated Maestro target. | Missing dedicated Patrol target. | P1 facade; blocks the retirement G3 slice, not permission to start G2. |
| Retirement | `/3a-deep/staggered-withdrawal` (`route_metadata.dart:449-454`) | `local-slider`; only empty when both 3a and income are absent, then computes from remaining defaults (`staggered_withdrawal_screen.dart:39-47,97-145,165-185`). | Ask 3a balance/accounts → canton → age/target age → tax/source year. | General staggering education; hide personalised tax economy. | Reconfirm annual 3a balances/accounts/canton; source-sensitive tax year must be current. | Retry simulator; `/pilier-3a` safe exit. | Tax range per labelled withdrawal schedule; no “optimal” account/order claim. | Exact DataBlock Ask with `returnUri=%2F3a-deep%2Fstaggered-withdrawal`; replace current generic Coach CTA at `:179-185`. | `staggeredWithdrawal` | Missing checked-in Maestro flow despite target described in docs. | Missing dedicated Patrol target. | P1 G1 exact ticket; product P0 before route release; blocks G2. |
| Retirement + Succession | `/succession` (`route_metadata.dart:385-391`) | `real-wired` for property/mortgage; later content is not gated by the full succession/retirement Case (`succession_patrimoine_screen.dart:31-37,73-125`). | Ask property, then mortgage, then family/canton/net estate facts required by the selected Case output. | Render legal concepts and known property note; hide reserve/tax conclusions without Case minimum. | Reconfirm volatile property/mortgage and annual canton/wealth; specialist legal facts show source/open-question status. | Keep educational content; retry ledger/reconciliation; Coach/notary checklist exit. | Net estate/transmission view from fresh facts, no legal decision. | Existing targeted pushes at `succession_patrimoine_screen.dart:81-103`; add `returnUri=%2Fsuccession`. | `succession` | Checked in: `apps/mobile/.maestro/f5_transmitting_property.yaml:1`. | Checked in: `apps/mobile/test/patrol/succession_transmission_runtime_test.dart:9-50`; missing and seeded-complete states. | P1 full Case/stale gap; ownership drift: metadata patrimoine vs contract famille (`SCREEN_CONTRACTS.md:223`). |
| Disability | `/invalidite` (`route_metadata.dart:657-663`) | `real-wired` + local IJM scenario lever; personalised result is properly gated (`disability_gap_screen.dart:297-315,348-405,473-591`). | Ask salary → birth year → explicit cash → explicit expenses. | Known fact card only; result section hidden. | Reconfirm annual salary/cash/charges; age static unless contradiction. | Retry recompute; safe `/explore/sante` or Coach. | Cliff/countdown/scorecard from facts plus labelled IJM scenario. | Existing exact routes `disability_gap_screen.dart:481-496`; append `returnUri=%2Finvalidite`. | `disabilityGap` | Checked in: `apps/mobile/.maestro/disability_gap.yaml:1`. | Checked in: `apps/mobile/test/patrol/disability_gap_runtime_test.dart:8-66`; real input chain. | P1 stale/returnUri only. |
| Disability | `/disability/insurance` (`route_metadata.dart:678-683`) | `real-wired` + local IJM/private-insurance levers; result gated (`disability_insurance_screen.dart:205-254,333-436`). | Ask salary → explicit cash → explicit expenses. | Known facts and coverage questions; scorecard hidden. | Reconfirm annual/volatile facts; policy toggles remain unverified levers until sourced. | Retry recompute; safe `/invalidite` or Coach. | Coverage comparison from facts and labelled scenario switches. | Existing targeted CTA plus `returnUri=%2Fdisability%2Finsurance`. | `disabilityInsurance` | Checked in: `apps/mobile/.maestro/disability_insurance.yaml:1`. | Checked in: `apps/mobile/test/patrol/disability_insurance_runtime_test.dart:8-55`; real input chain. | P1 stale/returnUri. |
| Disability | `/disability/self-employed` (`route_metadata.dart:684-689`) | `real-wired` + local loss-of-income lever; ordered missing routes exist (`disability_self_employed_screen.dart:209-303,345-376`). | Ask independent income → explicit cash → explicit expenses. | Ledger facts only; risk/countdown cards hidden according to their exact minimum. | Reconfirm annual income/cash/charges; policy lever does not stale until promoted by evidence. | Retry recompute; safe `/invalidite` or Coach. | Risk/countdown from facts plus labelled coverage scenario. | Existing targeted routes at `:216-226`; append `returnUri=%2Fdisability%2Fself-employed`. | `disabilitySelfEmployed` | Checked in: `apps/mobile/.maestro/disability_self_employed.yaml:1`. | Missing dedicated Patrol target. | P1 proof/stale. |
| Disability | `/independants/ijm` (`route_metadata.dart:631-636`) | `real-wired` + local waiting-period lever; no result without income/age (`ijm_screen.dart:72-90,135-155,229-298`). | Ask `q_self_employed_income`, then `q_birth_year`. | Ledger fact card; no result cards. | Reconfirm annual income; birth year static; no blank reset. | Retry calculation; safe `/segments/independant`. | Indicative policy scenario with selected waiting period and explicit non-entitlement label. | Existing exact routes at `ijm_screen.dart:229-275`; append `returnUri=%2Findependants%2Fijm`. | `independentIjm` | Checked in: `apps/mobile/.maestro/indep_ijm.yaml:1`. | Checked in but missing-state only: `apps/mobile/test/patrol/ijm_runtime_test.dart:10-27`; add real-input/complete proof. | P1 stale/complete Patrol proof. |
| Succession | `/life-event/donation` (`route_metadata.dart:891-896`) | `real-wired` + local Case levers; calculation blocks on ledger facts (`donation_screen.dart:51-105,336-415,1375-1465`). | Ask age → canton → civil status → children → reconciled net estate; property/mortgage for real-estate donation. | Fact tiles and educational framing; result null. | Reconfirm annual/volatile estate facts; source-sensitive tax/legal data shows year and specialist status. | Keep Case levers; retry calculator/reconciliation; Coach/notary exit. | Range/checklist from net estate and labelled gift assumptions; no legal/tax recommendation. | Existing targeted routes `donation_screen.dart:346-410`; append `returnUri=%2Flife-event%2Fdonation`. | `donation` | Checked in: `apps/mobile/.maestro/donation_ledger.yaml:1`; only missing-wealth navigation. | Checked in: `apps/mobile/test/patrol/donation_runtime_test.dart:9-67`; missing and seeded-result proof. | P1 stale/returnUri. |
| Frontalier | `/segments/frontalier` (`route_metadata.dart:877-882`) | `local-slider` + `provider-island`: no ledger/provider read; calculates GE/CHF 7k/single/France defaults on init (`frontalier_screen.dart:38-75,210-350`). | Ask residence country/permit/nationality → work canton → salary → household; dated work/home-office days for status output. | General bilateral/tax/social checklist only. | Reconfirm annual salary/canton/household and dated day counts; permit/residence static until event/contradiction. | Preserve educational tabs; retry source service; specialist checklist exit. | Source-tax/telework/social-charge ranges only with applicable regime and current sources. | First missing exact DataBlock/identity Ask with `returnUri=%2Fsegments%2Ffrontalier`; missing permit/residence collectors must be ticketed. | `frontalier` | Missing dedicated Maestro target: `.maestro/frontalier_ledger.yaml`. | Missing dedicated Patrol target. | P1 G1 exact ticket/provider quarantine; product P0 before route release; blocks G2. |

## Hard-floor routes outside the six loop matrix

These routes are mandatory for `no_domain_data_in_extra_test` even though they
are not themselves the six P0 Case roots.

| route + registry evidence | current violation | target empty/partial/stale/error/complete | return-to-origin | exact proof | severity |
|---|---|---|---|---|---|
| `/scan/review` (`route_metadata.dart:732-738`) | `ExtractionResult` is cast from `state.extra` (`app.dart:1004-1015`). Recovery exists when null, but a valid deep link cannot resolve a durable scan session. | Empty/error: resolve `scanSessionId` by id and offer rescan. Partial: show low-confidence extracted fields. Stale: show document issue/source date. Complete: confirmation writes facts through provider. | `/scan/review?scanSessionId=<id>&returnUri=<origin>`; after apply, go to `/scan/impact?scanSessionId=<id>&returnUri=<origin>`. | Maestro checked in `apps/mobile/.maestro/r1_scan_review.yaml:1`; widget repair test exists, but hard-floor extra test is not yet present. | **P0 hard floor**. |
| `/scan/impact` (`route_metadata.dart:739-745`) | Domain map with `ExtractionResult` and previous confidence comes from `state.extra` (`app.dart:1018-1033`). | Empty/error: resolve session id or recover home/scan. Partial/stale: recompute from ledger with confidence/source. Complete: read-only before/after delta. | Preserve original `returnUri`; CTA to origin/home after impact. | Maestro checked in `apps/mobile/.maestro/r2_scan_impact.yaml:1`. | **P0 hard floor**. |
| `/rapport` (`route_metadata.dart:792-798`) | Prefers `Map<String,dynamic>` wizard answers from `state.extra`; fallback spinner has no error/timeout (`app.dart:1077-1098`). | Empty/loading skeleton; partial dossier from ledger; stale fact badges; error retry/home; complete reads `CoachProfileProvider`/`MintStateProvider`, never wizard map extra. | Dossier actions preserve report URI; collection CTAs carry `returnUri=%2Frapport`. | R-3 is documented at `docs/codex/MAESTRO_FLOWS.md:210-221`, but `.maestro/r3_report_investment_card.yaml` is not checked in. No Patrol proof. | **P0 hard floor** plus P1 recovery proof. |
| `/confidence` (`route_metadata.dart:1027-1032`) | Reads `ConfidenceResult` from `state.extra`; otherwise computes against empty maps (`app.dart:1302-1312`). | Empty/partial/stale derive one confidence source from ledger/provenance; error retry/home; complete shows same headline/axes as home. | Enrichment CTA carries `returnUri=%2Fconfidence`. | No dedicated Maestro or Patrol proof checked in. | **P0 hard floor**. |

## P0 / P1 summary

### P0 G1 mechanical blockers — must be fixed before G1 can be complete

1. Scenario-to-fact writes on `/epl` and `/rente-vs-capital`.
2. Domain objects/maps in `state.extra` on the four hard-floor routes and any
   P0 prefill treated as canonical.
3. Executable `no_domain_data_in_extra_test` and `ledger_dead_key_test`, each
   with seeded red-to-green proof.

### P1 G1 debt — exact tickets permitted, but each blocks G2 until resolved

1. Default-driven personalised paths on housing, retirement, and frontalier
   must be removed/quarantined in G1 or receive exact blocking tickets; G1 does
   not rebuild those loops.
2. No audited route currently implements stale/reconfirm from durable
   provenance.
3. No audited P0 collection contract currently carries an explicit
   `returnUri`; back-stack behavior alone is insufficient, and DataBlock's
   Coach-mode `context.go` loses origin (`data_block_enrichment_screen.dart:180-191`).
4. Missing exact collectors for some mobile-only/source-sensitive facts.
5. Missing dedicated Maestro/Patrol proof for the routes identified above.
6. Registry/contract ownership and kill-flag drift, notably `/epl` and
   `/succession`; several P0 system routes have no kill flag
   (`route_metadata.dart:449-454,485-496,611-616,631-689,877-896`).

## Acceptance decision and phase boundary

`G2 allowed? NO`.

G1 may be marked complete without implementing the six loops once the four
matrices exist, both hard-floor tests prove red-to-green behavior, the P0 G1
mechanical blockers are fixed, and every remaining default/stale/return/proof
gap has an exact checked-in blocking ticket reflected in the scorecard.

`G2 allowed?` remains `NO` while any such P1 ticket is unresolved. Resolving
those tickets requires the next authorised slice; this matrix does not
authorise starting G2/G3.
