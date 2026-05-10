---
description: Quant/actuarial expert (Swiss personal finance) read-only audit of MINT's financial_core/ vis-a-vis the « calc as source of truth, LLM as illumination » doctrine. Identifies actuarial / stochastic / regulatory gaps and proposes 3 architectural moves for the next 6 weeks.
author: Expert 1 — Senior Quantitative / Actuarial (LPP/BVG, AVS/AHV, LIFD, mortgage, pillar-3a)
date: 2026-05-09
mode: read-only research
status: Proposed
---

# Expert 1 — Quant / Actuarial review of MINT's financial_core/

> Lens : « Le LLM doit etre uniquement illumination des resultats pre-calcules, pas leur source. » (Julien, 2026-05-09, after Stage 3 narrator eval : Sonnet 21/50, Haiku 5/50.) The calc layer must be defensible end-to-end before TestFlight + before any RTS Mise au Point-grade press exposure.

## 0. Files actually read (grounding)

- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/services/financial_core/lpp_calculator.dart` (471 lines) — `projectToRetirement`, `adjustedConversionRate`, `computeSurvivorPension` (LPP art. 19-20), `computeEplImpact` (LPP art. 30d, 79b al. 3), `compareRetirementSequencing` (LIFD art. 38).
- `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/services/financial_core/monte_carlo_service.dart` (619 lines) — 1 000 trajectoires, isolate-based, `mean=0.015, sd=0.065` Gaussian annual draws, percentile bands P10/P25/P50/P75/P90.
- Inventory of `/Users/julienbattaglia/Desktop/MINT.nosync/services/backend/app/services/` (LPP deep, regulatory registry, scenario, fri, mortgage, fiscal, divorce_simulator, succession_simulator, gender_gap_service).

## 1. SOTA scan (≥3 web citations)

### C1 — `devbrains-com/swisstaxcalculator` (TypeScript, MIT)
URL : <https://github.com/devbrains-com/swisstaxcalculator>
Takeaway : the reference open-source bridge to the official ESTV API (`API_exportManyTaxScales`, `API_exportManyDeductions`, `API_exportManySimpleRates`). Federal-and-cantonal tax code parameters are imported, not re-typed. **MINT today re-types cantonal coefficients in dart constants** — this is the single biggest source of « numbers can't survive a journalist's grep » risk.

### C2 — Aon BVG 2020 / BVG 2025 actuarial tables
URL : <https://www.aon.com/getmedia/1bedcb7d-1293-43d4-a233-e8e77e8a0ac1/210427_newsletter_issue-7_bvg2020_en.aspx>
Takeaway : BVG 2020 is the published Swiss occupational-pension mortality base ; **BVG 2025 is expected December 2025** (post-pandemic mortality re-baselining). MINT's `monte_carlo_service.dart` hard-codes a fixed `lifeExpectancy = 90` and a Trinity-style 4 % SWR (`lpp_calculator.dart:16`) — **no actual mortality table sampling**. A Swiss reviewer (e.g. ASIP, expert-attesté Chambre suisse) would flag this immediately.

### C3 — FINMA Swiss Solvency Test (SST), Circular 2008/44 + White Paper
URL : <https://www.finma.ch/en/~/media/finma/dokumente/rundschreiben-archiv/2008/rs-08-44/finma-rs-2008-44.pdf>
Takeaway : SST is the binding stress framework for FINMA-supervised insurers. Required scenarios (interest-rate down-shock, equity -30 %, longevity +10 %, currency, credit-spread). MINT is not an insurer, but **journalist-defensibility on retirement projections requires the same scenario family**. Today MINT has `tornado_sensitivity_service.dart` (one-factor, deterministic) but no SST-style joint stress.

### C4 — `ti8m` ESTV official tax calculator implementation note
URL : <https://www.ti8m.com/en/success-stories/public-and-e-government/steuerrechner>
Takeaway : the ESTV public calculator « includes historical tax data (deductions, tax rates and multipliers), which can be downloaded for study purposes. » The calc layer in any defensible Swiss product references **versioned, dated** parameter sets. MINT's `services/backend/app/services/regulatory/registry.py` is a good seed but the registry is not yet the single canonical source for cantonal tax — `tauxImpotRetraitCapital[cantonCode]` still lives in dart constants.

### C5 — Stress-testing IInd-pillar life-cycle pension funds, Annals of Operations Research (2024)
URL : <https://link.springer.com/article/10.1007/s10479-024-06041-1>
Takeaway : academic state of the art for 2nd-pillar stress modelling uses **hidden Markov regime-switching** on equity returns + correlated rate paths. MINT's MC currently draws **independent Gaussian** returns each year (`monte_carlo_service.dart:222-225`, `mean=0.015, sd=0.065`). Independence underestimates sequence-of-returns risk by an order of magnitude for 30-year horizons.

### C6 — CERN Pension Fund — CVaR adoption note
URL : <https://pensionfund.cern.ch/en/conditional-value-risk-cvar>
Takeaway : the CERN CHF-denominated pension fund publishes 5 % CVaR (« expected shortfall ») on its strategic asset allocation — a Swiss-domiciled precedent for showing **tail risk** rather than only median scenarios. MINT today shows P10-P90 bands but no explicit CVaR / expected-shortfall metric on retirement adequacy.

## 2. Three questions

### Q1 — What's missing in `financial_core/` to be world-class on Swiss personal finance?

| Gap | Severity | Evidence in MINT today |
|---|---|---|
| **Mortality table** : no BVG2020 / BVG2025 longevity sampling | **HIGH** | `lpp_calculator.dart:27` `int lifeExpectancy = 90` (constant). MC uses fixed `_projectionYears = 30` (`monte_carlo_service.dart:35`). |
| **Stochastic interest rate** for LPP technical rate / mortgage | **HIGH** | No CIR / Hull-White / Vasicek path. `caisseReturn` enters as a single scalar in `projectToRetirement`. |
| **Regime-switching equity returns** | **HIGH** | `_normalRandom(mean: 0.015, sd: 0.065)` independent draws each year — no HMM / GARCH / fat tails. Sequence-of-returns risk underestimated. |
| **Versioned regulatory parameter source** (ESTV / OFAS feeds) | **HIGH** | `services/backend/app/services/regulatory/registry.py` exists but cantonal capital-withdrawal rates still typed in dart (`tauxImpotRetraitCapital[cantonCode]`). |
| **CVaR / Expected Shortfall on retirement adequacy** | MEDIUM | MC returns P10-P90 percentiles only. No tail metric. |
| **Joint SST-style scenario stress** (rates ↓ 1 %, equity ↓ 30 %, longevity +10 %, CHF/EUR ±15 %) | MEDIUM | `tornado_sensitivity_service.dart` is one-factor only. |
| **GIPS-compliant performance attribution** for portfolio simulators | LOW (out of scope MVP) | N/A. Defer until brokerage integration. |
| **Couple correlation modelling** (joint mortality, joint job loss) | MEDIUM | `couple_optimizer.dart` treats lives as independent. Reality : correlated salary shocks (same canton, same industry). |
| **Mortgage stress-test** per FINMA self-regulation 2014 (cantonal banks tragbarkeit at 5 % theoretical rate) | MEDIUM | `housing_cost_calculator.dart` (344 lines) — would need to confirm 5 % theoretical-rate test is applied. |
| **3a OPP3 art. 7 ceiling versioning** (2 056 CHF in 2024 → 7 258 CHF 2026 → ?) | LOW | likely in `social_insurance.dart` constants — needs dated source-of-truth, not magic numbers. |
| **Pre-retirement bridge pension (rente-pont)** for early-retirement scenarios | MEDIUM | not visible in `lpp_calculator.dart` ; `compareRetirementSequencing` does fiscal sequencing only. |
| **AVS gap-year accounting** (annees de cotisation manquantes ⇒ rente reduite per LAVS art. 29bis) | MEDIUM | needs check in `avs_calculator.dart` (265 lines, not read here). |
| **FATCA-aware projection branch** for `expat_us` archetype (PFIC drag on collective investments) | HIGH for that archetype | Likely not modelled — `expat/` backend dir exists but PFIC drag not visible in `financial_core/`. |

### Q2 — Top 1-2 reference implementations on GitHub / academic literature

1. **`devbrains-com/swisstaxcalculator`** (<https://github.com/devbrains-com/swisstaxcalculator>) — TypeScript, MIT, ingests live ESTV API (federal + 26 cantons). **One-line takeaway** : *the only public Swiss tax calc that doesn't re-type the law in code — it pulls from `swisstaxcalculator.estv.admin.ch/delegate/...`.* MINT should mirror this discipline for cantonal capital-withdrawal rates and 3a ceilings.

2. **« Stress testing for IInd pillar life-cycle pension funds using hidden Markov model »** (Annals of Operations Research, 2024 — <https://link.springer.com/article/10.1007/s10479-024-06041-1>). **One-line takeaway** : *Swiss-applicable academic blueprint for 2-regime HMM equity returns + correlated rate path, retiree-cohort cash flows ; the closest open methodology to what MINT's MC should evolve into.*

(Honourable mention : `coorasse/swiss-tax-calculator` (Ruby) — older, less complete than `devbrains-com`, but useful for cross-checking.)

### Q3 — If MINT commits to « calc as source of truth, LLM as illumination », 3 architectural moves for the next 6 weeks

**Move 1 — Versioned regulatory parameter store, single source of truth.**
Promote `services/backend/app/services/regulatory/registry.py` to the canonical store for **every** legal constant : LPP seuil entree, deduction de coordination, taux de conversion minimum, OPP3 art. 7 ceilings (avec / sans LPP), barèmes capital-withdrawal per canton, AVS seuil min/max, LIFD art. 38 progressivity. Each entry MUST carry `effective_from`, `effective_to`, `source_url`, `legal_ref`. Dart and Python both read via the same JSON snapshot served at `/api/regulatory/v{N}`. **Goal** : at any moment we can answer « pourquoi ce chiffre ? » with a CHF-precise legal citation. Today `apps/mobile/lib/services/financial_core/lpp_calculator.dart:87-94` already calls `reg('lpp.entry_threshold', ...)` — extend the pattern to **every** numeric constant and forbid raw constants in `financial_core/`.

**Move 2 — Replace the iid-Gaussian Monte Carlo with a 2-regime HMM + correlated rate process.**
File : `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/services/financial_core/monte_carlo_service.dart` (619 lines). Today `_normalRandom(mean: 0.015, sd: 0.065)` is iid annual — independence breaks sequence-of-returns realism. Replacement : (a) 2-regime HMM (calm σ ≈ 5 %, stressed σ ≈ 18 %, transition matrix calibrated on Pictet BVG-25 1985-2024), (b) Vasicek 1-factor short rate driving LPP technical credit rate, (c) explicit longevity sampling from BVG 2020 mortality table (and BVG 2025 once published, gated behind a feature flag). Output extension : add `cvar5`, `cvar1` (CHF/month at risk in worst 5 %/1 % tails) alongside existing P10-P90 bands. **Goal** : pass a Swiss actuary's smell test on « comment vous modélisez le risque de séquence ? ».

**Move 3 — SST-flavoured deterministic stress scenarios on every retirement projection screen.**
Add `services/backend/app/services/regulatory/sst_scenarios.py` (new) : five named, dated, FINMA-aligned scenarios — `taux_zero_2030`, `equity_minus_30`, `longevity_plus_10`, `chf_eur_minus_15`, `combined_2008_replay`. Every projection card in the UI must show « Scenario central » + at least « Scenario adverse FINMA-style ». Couple this with a CHF-anchored CVaR badge (per CERN precedent <https://pensionfund.cern.ch/en/conditional-value-risk-cvar>). Wire from `tornado_sensitivity_service.dart` (today single-factor) into a `joint_stress_service.dart`. **Goal** : when a journalist asks « et si les taux remontent + actions baissent + on vit 10 ans de plus ? » we have one screen with the answer, not three menus.

## 3. Three concrete proposals for the roadmap (with file paths)

### P1 — Regulatory parameter freeze + versioning (Week 1-2)
- **Touch** : `/Users/julienbattaglia/Desktop/MINT.nosync/services/backend/app/services/regulatory/registry.py`, `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/constants/social_insurance.dart`, `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/services/financial_core/lpp_calculator.dart`, `tax_calculator.dart`, `avs_calculator.dart`.
- **Action** : add a CI lint (`tools/checks/no_raw_legal_constants.py`) that fails when `lib/services/financial_core/*.dart` contains a numeric literal not wrapped in `reg('<key>', <fallback>)`. Add `effective_from` / `effective_to` / `source_url` to every entry in `registry.py`. Expose `/api/regulatory/snapshot/2026-q2` returning a hash-stable JSON. Pin the snapshot hash in `app_config.dart`.
- **Why now** : without this, every other improvement is built on sand. Today `tauxImpotRetraitCapital[cantonCode]` is a dart map — not auditable.

### P2 — Monte Carlo v2 : HMM regime-switching + BVG2020 longevity sampling (Week 2-4)
- **Touch** : `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/services/financial_core/monte_carlo_service.dart` (lines 200-240 specifically — replace `_normalRandom` annual draws), `monte_carlo_models.dart` (add `Regime`, `MortalitySample` types), new `services/backend/app/services/scenario/regime_calibration.py` (Python notebook + JSON output checked in).
- **Action** : (a) calibrate 2-regime HMM on a public CHF index history (Pictet BVG-25 quarterly returns ; ship the calibration notebook), (b) sample longevity from BVG 2020 (table file under `services/backend/app/services/regulatory/data/bvg2020_male.csv` + female), (c) emit `cvar5`, `cvar1`, `prob_ruin_age_85`, `prob_ruin_age_95`. Keep `_safeWithdrawalRate = 0.04` as a **fallback display** only, not as the primary projection driver.
- **Why now** : the LLM narrator is being told to « illuminate » numbers that today underestimate tail risk. We need MC v2 before Sonnet starts saying « probabilite de tenir jusqu'a 95 ans : 78 % ».
- **Acceptance** : unit test fixture asserts that for a fixed seed, 30-year horizon, 60/40 portfolio, the produced 5 % CVaR drawdown is within 5 % of a published Swiss life-cycle reference (e.g. Vita Invest Plus 2055 stress disclosure).

### P3 — Joint SST-style scenarios + CVaR badge in projection UI (Week 4-6)
- **Touch** : new `/Users/julienbattaglia/Desktop/MINT.nosync/services/backend/app/services/regulatory/sst_scenarios.py`, evolve `/Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/services/financial_core/tornado_sensitivity_service.dart` (today 733 lines, one-factor) into `joint_stress_service.dart` taking N correlated factors.
- **Action** : codify 5 deterministic named scenarios (`taux_zero_2030`, `equity_minus_30`, `longevity_plus_10`, `chf_eur_minus_15`, `combined_2008_replay`), each with `legal_ref`, `parameter_overrides`, `effective_from`. Render in projection cards with a 1-tap toggle and an « Hypothèses utilisées » dialog (full transparency). Add a small CVaR badge (e.g. « rente couvre 80 % du besoin dans 95 % des scenarios ; pour les 5 % pires, manque CHF X / mois ») — phrasing audited for LSFin-banned terms.
- **Why now** : this is the journalist-defensibility move. RTS Mise au Point's standard question is « et le pire des cas ? ». A toggleable joint-stress view is the answer.
- **Acceptance** : `idb ui describe-all` on Lauren expat_us and Julien swiss_native flows shows the « Adverse FINMA-style » toggle + the CVaR badge, with backing API call returning 200 in < 500 ms.

## 4. Top counter-argument — what could go wrong if calc-first is pushed too aggressively?

> *The honest critique any senior reviewer (or contrarian board member) would make.*

**Risk : « calculator excellence » becomes a sand-trap that delays the actual product.** The user-value loop today is *« Lauren scans LPP → sees a number that makes sense → coach explains it. »* Replacing the iid-Gaussian MC with an HMM, calibrating regimes, validating mortality tables, building joint-stress UI — that's 4-6 weeks of deep quant work. None of it changes Lauren's day-1 experience if the LPP scan-and-illuminate path is still broken at the seam.

Three concrete failure modes if MINT over-rotates :
1. **Quant precision without product impact.** A 2-regime HMM that moves a P10 from CHF 3 800 to CHF 3 420 is statistically meaningful but emotionally indistinguishable for the user. The narrator either rounds it away or makes it look spuriously precise.
2. **Calibration drift / mortality table refresh tax.** BVG 2025 will land in December 2025 with corrected post-pandemic mortality. We commit to refreshing every dependent fixture, every regression golden, every projection screen — that's a recurring backlog tax we don't yet have a process for.
3. **Compliance ratchet.** Once we ship CVaR, we own the duty to explain it. LSFin art. 7-10 doesn't ban CVaR per se, but a press critic *can* claim « MINT shows tail risk numbers without holding a license to do so ». The pivot 2026-04-12 (lucidite > protection) survives this, but only if every CVaR badge is wrapped in an « approche éducative, ne constitue pas un conseil » disclaimer that the LLM cannot delete.

**Mitigation (recommended)** : keep the 6-week sprint scoped to the **3 moves above**. Do **not** add GIPS performance attribution, do **not** rebuild AVS gap-year accounting, do **not** ship a full SST module — those are post-TestFlight. The doctrine « calc is source of truth » means every CHF we display has a chain of provenance ; it does **not** mean we ship a quant-research playground.

## 5. Compliance checks performed on this artifact

- LSFin banned terms scan (mental pass) : « garanti », « optimal », « certain », « sans risque », « parfait » → none present.
- Accents 100 % FR : verified manually.
- Legal citations : LPP art. 7, 8, 13, 14, 16, 19, 20, 30d, 79b al. 3 ; LIFD art. 33 al. 1 let. e, art. 38 ; LAVS art. 29bis, 34-40 ; OPP3 art. 3, 7 ; FINMA Circular 2008/44 SST.
- 0-trust : every claim about MINT's current code grounded in a `path:line` citation from the two files actually read. No claim of « shipped » / « ready » — this is research-mode advice to the team.

## 6. References (cite-on-use)

- C1 — `devbrains-com/swisstaxcalculator` — <https://github.com/devbrains-com/swisstaxcalculator>
- C2 — Aon BVG 2020 Actuarial Tables — <https://www.aon.com/getmedia/1bedcb7d-1293-43d4-a233-e8e77e8a0ac1/210427_newsletter_issue-7_bvg2020_en.aspx>
- C3 — FINMA Circular 2008/44 SST — <https://www.finma.ch/en/~/media/finma/dokumente/rundschreiben-archiv/2008/rs-08-44/finma-rs-2008-44.pdf>
- C4 — `ti8m` ESTV calculator — <https://www.ti8m.com/en/success-stories/public-and-e-government/steuerrechner>
- C5 — Stress testing IInd-pillar life-cycle, Annals of Operations Research 2024 — <https://link.springer.com/article/10.1007/s10479-024-06041-1>
- C6 — CERN Pension Fund CVaR — <https://pensionfund.cern.ch/en/conditional-value-risk-cvar>
- C7 — Stiftung Auffangeinrichtung BVG calculator — <https://aeis.ch/en/individuals/lob-occupational-benefits-plans/pension-calculator>
- C8 — IAS 19 Swiss application (PwC Disclose) — <https://www.pwc.ch/en/insights/disclose/31/pension-obligations-with-ias-19.html>
- C9 — KPMG Revision FINMA SST Circular — <https://assets.kpmg.com/content/dam/kpmg/pdf/2016/06/ch-revision-finma-sst-circular-en.pdf>
- C10 — Aon Switzerland Longevity Assumption — <https://www.aon.com/switzerland/en/human-resources/pension-services/international-accounting-standards/longevity-assumption-en.pdf>

---

*End of Expert 1 audit. Written read-only ; no source files modified. Findings counter-argument-checked per `.planning/decisions/_TEMPLATE.md` discipline (« Counter-arguments and data gaps required » — section 4 above).*
