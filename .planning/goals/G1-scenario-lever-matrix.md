# G1 Scenario-Lever Matrix

> Scope: G1 Ledger Reality Baseline only. This is a classification contract,
> not an implementation of DataQuest, CaseRegistry, or any P0 journey.
>
> Reality audit: 2026-07-13 on
> `codex/mint-product-usability-plan-20260712`. Route parity and cited source
> lines were rechecked against immutable evidence snapshot
> `e2cfef057c197b3b8ac122d9a9aa3ca645c85696`.

## Verdict and G1 boundary

**Matrix contract: GO. G1 mechanical hard floors are checked in and green
for route payloads and the six audited scenario sources. G1 overall remains
incomplete while exact route/default/freshness tickets remain unresolved.
`G2 allowed? NO`.**

G1 does **not** implement DataQuest, CaseRegistry, or the six P0 loops. For the
routes below, G1's responsibility is to classify every value, make the two
hard floors executable, remove or quarantine mechanical ledger violations,
and create exact blocking tickets for route-state work that remains. G1 may be
closed with those tickets and `G2 allowed? NO`; it must not pre-build G2/G3 to
make this matrix look green.

The encrypted cache authorised by G1-SCN-01 is deliberately limited to EPL and
rente-capital as a G1 closure slice. It is not Mint's universal scenario model
and does not narrow the product to retirement or housing.

The present route reality still blocks G2 because screens calculate from
illustrative local defaults and stale facts cannot be distinguished from fresh
facts. The audited scenario-to-fact mutations are mechanically closed, but the
Case-local scenario model is not implemented. In particular:

- `/hypotheque`, `/mortgage/amortization`, `/mortgage/epl-combined`,
  `/rente-vs-capital`, `/3a-deep/staggered-withdrawal`, and
  `/segments/frontalier` still compute from local defaults
  (`affordability_screen.dart:139-160,162-227`, `amortization_screen.dart:30-41`,
  `epl_combined_screen.dart:28-41`, `rente_vs_capital_screen.dart:61-76,295-324,361-402`,
  `staggered_withdrawal_screen.dart:39-47`,
  `frontalier_screen.dart:38-61`).
- The scenario hard floor classifies durable-sink method invocations by verb
  plus subject, proves seeded shapes such as `updateProfile(copyWith(...))`,
  `mergeAnswers`, `applySaveFact`, `setProfile`, and `updateFromAnswers` red,
  then scans exactly `/epl`, `/rente-vs-capital`, `/hypotheque`,
  `/rachat-lpp`, `/3a-retroactif`, and `/pilier-3a`
  (`no_scenario_writeback_to_profile_test.dart:5-46,48-90,92-159`). It does
  not claim recursive coverage of every simulator.
- None of the audited P0 screens reads `dataTimestamps`, `dataSourceDates`, or
  `FreshnessDecayService`; therefore no current input is mechanically
  stale-aware or reconfirmable.

## Classification rules

| class | meaning | persistence rule |
|---|---|---|
| `durable_fact` | A real user circumstance or balance that may be reused by another Case. | Persist only through `CoachProfileProvider`; provenance and freshness required. |
| `scenario_lever` | A hypothetical alternative, offer, choice, or sensitivity assumption. | Session/Case-local only; it may be cached encrypted with opaque ID/status when explicitly scoped, but is never silently promoted to the profile and its outputs remain recomputed. |
| `derived_output` | A calculator/result value produced from facts and levers. | Recompute; do not store as a user fact. A separately labelled snapshot may exist only as Case evidence. |
| `specialist_only` | Exact regulation, clause, deadline, legal classification, or source-sensitive value requiring authoritative evidence. | Persist only as sourced evidence after confirmation; otherwise remain an open dossier question. |

### Tier semantics

| tier | meaning |
|---|---|
| `T0` | Hard blocker: without a fresh explicit fact, no personalised high-stakes result. |
| `T1` | Required for the named personalised output; partial education may remain. |
| `T2` | Useful enrichment that tightens range/confidence or specialist handoff. |
| `S` | Scenario lever, not a user fact. |
| `D` | Derived output. |
| `X` | Specialist/source-sensitive input. |

`persist? = conditional` means that the current real-world fact can be
persisted after explicit confirmation, while an alternative value explored on
the same control remains a scenario lever.

## 1. Work / first salary

| route | local input / concept | class | canonical key / field | tier | required_for_output | allowed_output_when_missing | forbidden_conclusion | specialist_handoff | persist? | HEAD reality / evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| `/first-job` | `_salaire` current declared salary | `durable_fact` | `q_gross_salary_annual` | T0 | personalised payslip/LPP basis | educational salary anatomy only | a personalised net salary or pension basis | payslip/HR question if gross basis is uncertain | yes | Real ledger gate exists at `first_job_screen.dart:150-180`; local scenario presets remain at `:1153-1187`. |
| `/first-job` | `_salaire` median/alternative salary preset | `scenario_lever` | none | S | comparison only | show the labelled generic scenario | that the preset is the user's salary | none | no | The test intentionally preserves a selected salary scenario after provider notify (`life_event_screens_additional_smoke_test.dart:641-687`). |
| `/first-job` | `_age`, `_canton` | `durable_fact` | `q_birth_year`, `q_canton` | T0 | personalised deductions/LPP | known-fact card plus exact missing CTA | age/canton-specific output | none | yes | Both are read only when user-provided (`first_job_screen.dart:150-166`). |
| `/first-job` | `_tauxActivite` | `scenario_lever` for an offer; `durable_fact` only after explicit “current rate” confirmation | `q_employment_rate` when confirmed | S/T1 | offer comparison; current-profile calculation if confirmed | labelled full-time illustration | that the explored rate is current employment | employment contract/HR | conditional | Local slider starts at 100 and is explicitly headed “Scenario lever” (`first_job_screen.dart:486-507`). |
| `/simulator/job-comparison` | current salary and age | `durable_fact` | `q_gross_salary_annual`, `q_birth_year` | T0 | any personalised comparison | missing-fact card; no comparison result | that two plans are comparable | none | yes | Result is blocked until both facts exist (`job_comparison_screen.dart:120-141,455-499`). |
| `/simulator/job-comparison` | `_currentPartEmployeur`, `_currentTauxConversion`, `_currentAvoirVieillesse`, `_currentCouvertureInvalidite`, `_currentCapitalDeces`, `_currentRachatMax` | `durable_fact` if describing the current certificate; otherwise `scenario_lever` | existing LPP certificate fields where available; missing dedicated fields must be ticketed | T1/X | comparison of the actual current plan | clearly labelled unverified current-plan template | that defaults describe the current pension fund | pension certificate/regulation/HR | conditional | All start as local defaults (`job_comparison_screen.dart:77-84`) and feed the current plan (`:143-153`). |
| `/simulator/job-comparison` | `_currentHasIjm` | `scenario_lever` until a dedicated confirmed coverage fact exists | none today | S/T2 | coverage comparison only | show “coverage not verified” | that the current employer provides IJM | employer/insurer policy | no today | Local boolean defaults true (`job_comparison_screen.dart:84,143-153`). |
| `/simulator/job-comparison` | all `_new*` offer values | `scenario_lever` | none | S | new-offer comparison | editable empty/unknown offer card | that the offer terms are contractual facts | offer letter, pension regulation, HR | no | New salary, plan, death/disability and IJM values are local (`job_comparison_screen.dart:86-94,155-165`). |
| both | payslip amounts, contribution deltas, LPP/IJM verdict/checklist | `derived_output` | none | D | facts plus labelled levers | educational explanation/checklist | “better job” or advice-shaped ranking | HR/pension/insurer checklist | no | Computed by `FirstJobService` and `JobComparisonService`; current screen supports a neutral comparable verdict (`job_comparison_screen.dart:409-451`). |

## 2. Housing / mortgage / EPL

| route | local input / concept | class | canonical key / field | tier | required_for_output | allowed_output_when_missing | forbidden_conclusion | specialist_handoff | persist? | HEAD reality / evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| `/hypotheque` | `_revenuBrut`, `_canton` | `durable_fact` | `q_gross_salary_annual`, `q_canton` | T0 | personalised affordability | educational 33%/stress-rule explanation | an accessible price or affordability verdict | bank/adviser for recognised income | yes | Profile hydration exists, but provider absence keeps hardcoded defaults (`affordability_screen.dart:54-94,139-160,162-227`). |
| `/hypotheque` | age/birth year | `durable_fact` | `q_birth_year` | T0 | amortisation-to-retirement and post-retirement affordability | flag that retirement affordability is unresolved | affordability through/after retirement | bank/pension specialist | yes | Required by the audited G1 housing contract but not read by the current calculator; current calculator call has no age (`affordability_screen.dart:153-160`). |
| `/hypotheque` | `_epargneDispo`, `_avoir3a`, `_avoirLpp` | `durable_fact` | `q_cash_total`, `q_3a_total`, `_coach_avoir_lpp` | T0/T1 | personalised own-funds mix | source-labelled composition shell | that illustrative balances are available funds | bank/pension fund; EPL restrictions | yes | Editable local amounts, with fixed defaults, directly feed result (`affordability_screen.dart:139-160,162-227`). |
| `/hypotheque` | `_prixAchat` | `scenario_lever` | none; `q_property_market_value` only for an owned/current property | S | target-price scenario | generic target-price input | that target price is current property wealth | bank/valuer for actual valuation | no | Local target price (`affordability_screen.dart:139-160`). |
| `/mortgage/amortization` | `_montantHypothecaire`, `_tauxInteret` | `durable_fact` for the current loan; scenario levers for alternative loan/rate | `patrimoine.mortgageBalance`, `patrimoine.mortgageRate` | T0/S | current-loan comparison | labelled generic example | current debt/cost from defaults | mortgage statement/bank offer | conditional | Defaults calculate immediately; optional provider hydration only (`amortization_screen.dart:30-76`). |
| `/mortgage/amortization` | `_dureeAns`, `_tauxMarginal` | `scenario_lever`; marginal rate is derived when profile facts exist | none | S/D | amortisation sensitivity | generic illustrative comparison | exact tax saving or required strategy | tax adviser/bank | no | Local defaults are 15 years and 30% (`amortization_screen.dart:31-40`). |
| `/mortgage/epl-combined` | `_epargneCash`, `_avoir3a`, `_avoirLpp`, `_canton` | `durable_fact` | `q_cash_total`, `q_3a_total`, `_coach_avoir_lpp`, `q_canton` | T0 | personalised own-funds composition | empty/partial funding-source list | that defaults are available assets | bank/pension fund | yes | All four have illustrative defaults and compute unconditionally (`epl_combined_screen.dart:28-41,84-112`). |
| `/mortgage/epl-combined` | `_prixCible` | `scenario_lever` | none | S | target purchase comparison | labelled target input | that it is owned-property value | valuation/bank | no | Local target price defaults to CHF 900k (`epl_combined_screen.dart:32-40`). |
| `/epl` | `_avoirTotal`, `_age`, `_canton`, `_grossAnnualSalary`, `_obligRatio`, buyback history | `durable_fact` / `specialist_only` for regulation-sensitive split and buyback dates | LPP balance/split, `q_birth_year`, `q_canton`, `q_gross_salary_annual`, `prevoyance.dateRachats` | T0/X | personalised EPL feasibility/impact | legal mechanism and missing-fact checklist | eligibility, available amount, tax or pension impact | pension fund regulation, bank, tax specialist | yes when sourced | Local defaults feed the simulator (`epl_screen.dart:44-67`); provider hydration is partial (`:195-219`). |
| `/epl` | `_montantSouhaite` | `scenario_lever` | none | S | withdrawal sensitivity | labelled editable amount | that the withdrawal occurred | pension fund/bank | no | G1 fixed: current facts hydrate from `CoachProfileProvider`; `GoRouter.extra` carries only `runId`/`stepId` (`epl_screen.dart:76-82,135-180`), and slider edits do not update the durable profile. |
| housing routes | capacity, monthly payment, own-funds split, direct/indirect amortisation delta, EPL impact | `derived_output` | none | D | fresh minimum facts plus levers | general education/ranges only | approval, entitlement, optimal order, exact tax saving | bank/pension/tax checklist | no | Fixed G1: `/hypotheque` capacity/payment and `/epl` impact stay recomputed outputs; the hard floor asserts both named housing sources contain no durable sink call (`no_scenario_writeback_to_profile_test.dart:92-103,113-119`). Full Case gating remains ticketed. |

## 3. Retirement Case 50-60

| route | local input / concept | class | canonical key / field | tier | required_for_output | allowed_output_when_missing | forbidden_conclusion | specialist_handoff | persist? | HEAD reality / evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| all retirement routes | age, canton/commune, civil/partner status, archetype/nationality/residence permit/arrival age/FATCA/employment | `durable_fact` | `q_birth_year`, `q_canton`, `q_commune`, `q_civil_status`, identity/archetype fields | T0 | any personalised Swiss retirement result | Case inventory and exact missing asks | resident/archetype-specific eligibility or tax conclusion | fiduciary/AVS/pension specialist for cross-border/FATCA | yes | Required by G1 goal `G1-ledger-reality-baseline-2026-07-12.md:117-143`; current rente-vs-capital reads only a subset (`rente_vs_capital_screen.dart:193-220`). |
| all retirement routes | AVS years/gaps/estimate, LPP balances/splits/rates/regulation, 3a accounts/balances, cash and budget floor | `durable_fact` / `specialist_only` for regulation terms | AVS/LPP/3a ledger keys, `q_cash_total`, explicit monthly charges | T0/X | rente/capital, decumulation, tax, housing and survivor output | partial known-facts view plus dossier questions | confident result from general defaults | AVS extract, pension certificate/regulation, 3a provider, tax specialist | yes when sourced | Current rente-vs-capital starts with fabricated controllers (`rente_vs_capital_screen.dart:61-76`) and parse/API fallbacks (`:295-324,361-402`). |
| `/rente-vs-capital` | declared target retirement age | `durable_fact` | `q_target_retirement_age` | T1 | base Case timeline | show no timeline conclusion | that a default age is the user's plan | pension specialist | yes after explicit declaration | Profile can hydrate the value (`rente_vs_capital_screen.dart:248-252`). |
| `/rente-vs-capital` | alternative `_ageRetraiteSlider` | `scenario_lever` | none | S | compare alternative ages | labelled sensitivity control | that the explored age changed the user's plan | pension specialist | no | G1 fixed: the lever stays local; simulator inputs hydrate from `CoachProfileProvider`, route extra is limited to `runId`/`stepId`, and the static hard floor forbids profile writes (`rente_vs_capital_screen.dart:120-165`; `no_scenario_writeback_to_profile_test.dart:105-111`). |
| `/rente-vs-capital` | rente/capital/mixed ratio, `_hypotheses` rendement/SWR/inflation, `_lifeExpectancy`, annual buyback, `_hasEpl`/EPL amount | `scenario_lever` | none | S | trade-off and sensitivity views | generic educational ranges | advice, ranking, promised return/longevity | pension/tax/investment specialist | no | Local hypotheses and controls are declared at `rente_vs_capital_screen.dart:78-117` and feed the engine at `:439-505`. |
| `/3a-deep/staggered-withdrawal` | actual 3a total/account count, canton | `durable_fact` | `q_3a_total`, `prevoyance.comptes3a[]`, `q_canton` | T0 | personalised withdrawal-tax illustration | missing-fact checklist | a personalised tax saving | canton tax authority/fiduciary | yes | Screen hides only when both 3a and income are absent, otherwise retains defaults (`staggered_withdrawal_screen.dart:97-145`). |
| `/3a-deep/staggered-withdrawal` | withdrawal start/end, alternative number/order of accounts, taxable-income assumption | `scenario_lever` | none | S | stagger scenarios | general stagger explanation | optimal account count/order or exact tax | fiduciary/3a provider | no | All are local sliders (`staggered_withdrawal_screen.dart:326-351`). |
| `/rachat-lpp` | LPP balance, remaining buy-back gap, income, canton, civil status, age and certificate context | `durable_fact` | typed `CoachProfile`/`prevoyance` fields | T0/T1 | personalised staged-buy-back illustration | partial fact inventory and labelled assumptions | that a local default is the certificate value | pension certificate/regulation, tax specialist | yes when sourced | G1 fixed: these inputs hydrate from `CoachProfileProvider` (`rachat_echelonne_screen.dart:162-199`); no financial route prefill is consumed. |
| `/rachat-lpp` | annual buy-back amount, horizon and manual marginal-rate override | `scenario_lever` | none | S | staged-buy-back sensitivity | labelled local scenario | that the explored buy-back occurred or changed the remaining gap | pension fund/fiduciary | no | Controls update local state and `ScreenReturn` only (`rachat_echelonne_screen.dart:207-212`); provider-recorder proof asserts zero writes and unchanged LPP facts (`rachat_echelonne_screen_test.dart:63-113`). |
| `/pilier-3a` | age, canton, gross income, civil/children context and LPP affiliation | `durable_fact` | typed `CoachProfile` fields | T0/T1 | personalised 3a illustration | educational 3a mechanism plus missing asks | that defaults describe the user | 3a provider/fiduciary | yes | G1 fixed: simulator inputs hydrate from `CoachProfileProvider` (`simulator_3a_screen.dart:114-153`); the old `ProfileProvider` hydration fallback is removed. The remaining legacy read is only the separately ticketed `hasDebt` SafeMode boundary (`:182`). |
| `/pilier-3a` | annual contribution, horizon and return assumptions | `scenario_lever` | none | S | contribution sensitivity | labelled local scenario | that a simulated contribution was paid or is a durable fact | 3a provider/fiduciary | no | G1 fixed: no automatic profile write; the scenario-write hard floor covers this screen (`no_scenario_writeback_to_profile_test.dart:134-145`). |
| `/3a-retroactif` | gross income, canton-derived tax context and LPP affiliation | `durable_fact` / `derived_output` | typed `CoachProfile` fields; marginal rate remains derived | T0/T1/D | retroactive-gap illustration | general eligibility mechanism and open questions | exact personal tax saving from missing facts | 3a provider/fiduciary | yes for source facts only | G1 fixed: source facts hydrate from `CoachProfileProvider` (`retroactive_3a_screen.dart:63-100`). |
| `/3a-retroactif` | gap years, contribution choices and tax-rate override | `scenario_lever` | none | S | retroactive contribution sensitivity | labelled local scenario | that a simulated catch-up happened or changed LPP projections | 3a provider/fiduciary | no | G1 fixed: controls remain local; provider-recorder proof asserts zero writes and unchanged LPP facts (`retroactive_3a_screen_test.dart:63-91`). |
| `/fiscal` | canton, income and household/tax context | `durable_fact` | typed `CoachProfile` fields | T0/T1 | personalised tax comparison | partial fact inventory and missing asks | exact personal tax or withdrawal-tax conclusion | cantonal tax authority/fiduciary | yes | G1 fixed: source facts hydrate from `CoachProfileProvider` (`fiscal_comparator_screen.dart:107-132`); no financial route prefill is consumed. |
| `/fiscal` | planned `montant_retrait` | `scenario_lever` | none | S | withdrawal-tax scenario only | remain missing until an explicit local/Case control exists | `montant_retrait = 0` or `impot_retrait = 0` inferred from absence | fiduciary/pension/3a provider | no | Fail closed: the screen has no withdrawal control, so final return omits `impot_retrait` instead of fabricating zero (`fiscal_comparator_screen.dart:149-186`). |
| `/decaissement` | all displayed calendar values | `derived_output` once wired; currently static education | none | D | Retirement Case facts and levers | educational decumulation principles | personalised calendar | pension/tax specialist | no | Screen reads no ledger facts and treats viewing as completion (`optimisation_decaissement_screen.dart:30-60,63-100`). |
| retirement Case | LPP/AVS/capital projections, tax ranges, decumulation, survivor/housing/succession impacts | `derived_output` | none | D | complete/fresh minimum-fact groups | partial state plus open questions | confident recommendation or “best” choice | dossier handoff to pension/tax/notary/bank | no | `persist? = no` applies to these derived outputs. G1 fixed for the audited routes: outputs are recomputed/local and the static hard floor rejects writes into profile-shaped targets (`no_scenario_writeback_to_profile_test.dart:5-46,48-90,92-159`). G1-SCN-01 may persist only opaque ID/status plus typed EPL/rente-capital levers in a bounded encrypted local cache; outputs and general Case evidence persistence remain future scoped. |

## 4. Disability / protection

| route | local input / concept | class | canonical key / field | tier | required_for_output | allowed_output_when_missing | forbidden_conclusion | specialist_handoff | persist? | HEAD reality / evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| `/invalidite` | salary, age, explicit cash, explicit monthly charges, employment status | `durable_fact` | `q_gross_salary_annual`, `q_birth_year`, `q_cash_total`, housing/LAMal expense keys, `q_employment_status` | T0 | cliff/countdown/scorecard | ledger fact card and first exact CTA | countdown or score from heuristic cash/default charges | insurer/pension/HR | yes | Personal results are gated on all facts (`disability_gap_screen.dart:297-315,348-405`). |
| `/invalidite` | `_hasIjm` | `scenario_lever` until confirmed-policy fact exists | none today | S/T2 | compare coverage states | show both labelled states | that the user is covered | employer/insurer contract | no today | Local toggle is explicitly kept in the fact card (`disability_gap_screen.dart:579-586`). |
| `/disability/insurance` | salary, explicit cash, explicit monthly charges | `durable_fact` | same as above | T0 | employee scorecard | missing-fact card | coverage score from defaults | insurer/pension/HR | yes | Result is hidden until all three exist (`disability_insurance_screen.dart:205-254`). |
| `/disability/insurance` | `_hasIjm`, `_hasPrivateInsurance` | `scenario_lever` until policy evidence is confirmed | none today | S/T2 | coverage comparison | labelled unverified switches | actual insurance coverage | policy/HR | no today | Both are local switches (`disability_insurance_screen.dart:32-33,427-436`). |
| `/disability/self-employed` | independent income, explicit cash, explicit charges | `durable_fact` | `q_self_employed_income`, `q_cash_total`, expense keys | T0 | red-screen/countdown | missing-fact card | protection duration from estimates | insurer/fiduciary | yes | Ordered missing routes exist (`disability_self_employed_screen.dart:209-303`). |
| `/disability/self-employed` | `_hasPerteDegain` | `scenario_lever` until a confirmed policy fact exists | none today | S/T2 | compare protected/unprotected states | labelled alternative | that coverage exists | insurer policy | no today | Local choice at `disability_self_employed_screen.dart:345-376`. |
| `/independants/ijm` | independent income and age | `durable_fact` | `q_self_employed_income`, `q_birth_year` | T0 | illustrative IJM contract scenario | exact missing CTA | verified entitlement/benefit | insurer/fiduciary | yes | Calculator returns null until both facts exist (`ijm_screen.dart:72-90,229-298`). |
| `/independants/ijm` | `_delaiCarence` and fixed 80% coverage model | `scenario_lever` | none | S | compare waiting periods | generic policy education | verified policy terms or legal entitlement | insurer quote/policy | no | Local 30/60/90-day choice (`ijm_screen.dart:31,335-370`); output is labelled illustrative in ScreenReturn (`:113-127`). |
| disability routes | gap, cliff, countdown, grade, indicative premium | `derived_output` | none | D | required facts plus labelled coverage lever | education/checklist | actual insured benefit or recommendation | insurer/pension/HR dossier | no | Real missing-fact gating exists, but no stale/reconfirm path exists. |

## 5. Succession / transmission

| route | local input / concept | class | canonical key / field | tier | required_for_output | allowed_output_when_missing | forbidden_conclusion | specialist_handoff | persist? | HEAD reality / evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| `/succession` | property value and mortgage | `durable_fact` | `q_property_market_value`, `_coach_dettes_hypotheque` | T0 | property-transmission note | exact missing property/mortgage CTA | net property estate from gross property alone | bank/notary | yes | Ledger-only missing cards exist (`succession_patrimoine_screen.dart:31-37,73-105`). |
| `/succession` | civil status, children/heirs, canton, net estate base, spouse context | `durable_fact` | household/canton/reconciled wealth facts | T0/T1 | succession reserve/tax/legal framing | educational notions and open checklist | legal shares, tax or action recommendation | notary/fiscalist | yes | Current route uses property facts but does not enforce the complete Case minimum before later widgets (`succession_patrimoine_screen.dart:108-125`). |
| `/life-event/donation` | age, canton, civil status, children, reconciled net estate, property/mortgage for real estate | `durable_fact` | exact ledger keys documented in `SCREEN_CONTRACTS.md:224` | T0 | donation scenario | known/missing fact tiles; result hidden | reserve/tax output from incomplete or gross estate | notary/fiscal authority/bank | yes | `canSimulate` requires the base facts (`donation_screen.dart:1375-1465`); UI routes each missing fact exactly (`:336-415`). |
| `/life-event/donation` | `_montant`, `_lienParente`, `_typeDonation`, `_avancementHoirie` | `scenario_lever` | none | S | planned-gift scenario | editable Case assumptions | that the gift occurred or recipient relation belongs in global profile | notary/fiscalist | no | Local Case state is declared at `donation_screen.dart:51-76` and used only in the calculation (`:84-105`). |
| succession routes | reserve/quotité, tax status, net property note, checklist | `derived_output` | none | D | fresh minimum facts and sourced legal year | education plus specialist questions | legal/tax decision or exact unsupported tax | notary/fiscalist/bank/pension | no | Donation correctly keeps result null when facts are insufficient (`donation_screen.dart:84-88`). |
| succession routes | matrimonial regime, testament/pact/mandate, beneficiary clauses, exact cantonal tax table | `specialist_only` | dedicated sourced facts not fully present today | X | exact legal/tax conclusion only | dossier question marked unresolved | legal validity or exact tax | notary/fiscal authority | only with source | G1 goal explicitly treats these as source-sensitive (`G1-ledger-reality-baseline-2026-07-12.md:125-131`). |

## 6. Frontalier

| route | local input / concept | class | canonical key / field | tier | required_for_output | allowed_output_when_missing | forbidden_conclusion | specialist_handoff | persist? | HEAD reality / evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| `/segments/frontalier` | work canton, salary, civil status, children | `durable_fact` | `q_canton`, income key, `q_civil_status`, `q_children` | T0 | personalised source-tax comparison | general cross-border checklist | tax-at-source amount | cross-border fiduciary/employer | yes | Screen uses local GE/7000/single/0 defaults and no provider (`frontalier_screen.dart:38-61,210-350`). |
| `/segments/frontalier` | residence country, permit G, nationality, archetype/FATCA | `durable_fact` | residence/permit/nationality/archetype fields | T0 | applicable bilateral/social/tax regime | unresolved-regime state | that French/Geneva rules apply to every frontalier | cross-border fiduciary/social-insurance specialist | yes | Current only local `_chargesCountry='France'`; no ledger read (`frontalier_screen.dart:50-61`). |
| `/segments/frontalier` | actual prior home-office/work days | `durable_fact` if reporting an elapsed period | dedicated dated Case fact required | T1 | retrospective threshold status | missing dated-period question | compliance status from generic days | employer/payroll/social-insurance authority | conditional | Current local days are 180/40 (`frontalier_screen.dart:45-48`). |
| `/segments/frontalier` | planned `_bureauDays`, `_homeOfficeDays`, alternative `_taxSalary`, `_taxCanton`, `_chargesCountry` | `scenario_lever` | none | S | sensitivity/planning | generic alternative comparison | that explored values are current facts | fiduciary/employer | no | All are mutable local inputs (`frontalier_screen.dart:38-53,246-269`). |
| `/segments/frontalier` | source tax, 90-day/telework status, social-charge delta | `derived_output` | none | D | current-law sources plus required facts | broad educational forces/checklist | definitive tax/social-security result | cross-border specialist dossier | no | Calculated at init from defaults (`frontalier_screen.dart:55-75`). |

## Blocking findings and acceptance

### P0 G1 mechanical closures

- **GREEN:** the recursive production-tree route gate enforces its exact
  `GoRouter.extra` allowlist, proves seeded invalid writers/readers red, and
  proves the coach path carries no prefill or route payload
  (`no_domain_data_in_extra_test.dart:5-20,32-37,143-225,256-355,357-467`).
- **GREEN:** the scenario hard floor uses durable sink verbs/subjects, includes
  seeded bypass shapes, and scans the six exact audited sources; focused widget
  tests prove zero provider updates for buy-back and retroactive-3a controls
  (`no_scenario_writeback_to_profile_test.dart:5-46,48-90,92-159`).
- **GREEN:** `COACH-PREFILL-RISK` was closed by `e1d42191a`; ready routing now
  comes from `RoutePlanner` plus the profile. The fixture requires explicit
  canton provenance and timestamp and proves canonical `/rachat-lpp` with null
  destination extra (`widget_renderer_test.dart:25-44,99-132`).

### P1 G1 debt that blocks G2 unless fixed

- For each default-driven screen named in the verdict, either remove/quarantine
  the false personalised path inside G1 or create an exact blocking ticket with
  owner, predicate, red/green command, and affected loops. Do not rebuild the
  complete loop in G1.
- Add provenance/freshness lookup so a fresh fact is reused, a stale fact is
  shown with its prior value, and `reconfirm` never starts from a blank input.
- Add a bounded encrypted local cache for typed EPL/rente-capital scenario
  levers and opaque ID/status; do not overload `CoachProfile` or
  `ScreenReturn.updatedFields`, and do not build CaseRegistry/DataQuest in G1.
- Every missing/stale Ask must carry an encoded `returnUri` to the exact origin
  route.

### G2 gate

G1 may be marked complete once the four matrices exist, the two hard floors are
green with red-to-green proof, the P0 G1 mechanical blockers above are fixed,
and every remaining P1 route/default/freshness item has an exact checked-in
blocking ticket reflected in the scorecard.

`G2 allowed? NO` while any of those P1 tickets remains unresolved. Resolving
them belongs to the next authorised implementation slice; this matrix does not
authorise starting G2/G3.
