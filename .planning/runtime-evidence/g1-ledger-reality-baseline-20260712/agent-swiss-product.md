# G1 Swiss Product Audit — `mint-swiss-brain` + Product Lead

Date: 2026-07-12

Scope: G1 Ledger Reality Baseline only

Mode: read-only audit of the existing contracts and live repo before this evidence file

Auditor roles: `mint-swiss-brain`, MINT product lead

## Current AVS addendum — 2026-07-14

The permanent Swiss-brain reverified current HEAD with 285 targeted Flutter
tests, 68 backend tests and Doctor 7/7, all GREEN:

- **Registered partnership old P0: CLOSED.** Typed meaning, legacy aliases,
  wizard/DataBlock round trip and AVS predicates preserve marriage equivalence.
- **13th-AVS monthly-uplift old P0: CLOSED.** Ordinary pension remains 12
  payments and the supplement is separate and December-only. The broader
  `G1-AVS-02` ticket remains open for official evidence ingestion, persistence,
  dedicated rendering, activation and runtime proof.
- **Couple cap/splitting: NARROWED BUT OPEN.** The fixed-scale cap and
  salary-duration proxy are removed/quarantined; unknown partner never becomes
  zero. G1 still needs typed owner-scoped official splitting evidence,
  statutory-trigger state and production wiring.

The old AVS commits do not retain standalone failing-test RED transcripts.
Their parent snapshots are semantic controls and later bounded audits pass, but
the scorecard must disclose that evidence limitation rather than invent RED.

**Current machine truth: 13/31 GREEN; G1/G2/G3 remain NO-GO.**

## Verdict

**GO to continue G1. NO-GO to mark G1 complete or start G2/G3.**

The 2026-07-12 AVS/couple follow-up below adds an independent **NO-GO** for
household AVS outputs. It does not revoke the permission to continue bounded
G1 repairs; it forbids closing G1 while the named AVS evidence, civil-status,
consent, plafonnement, splitting, and 13th-pension predicates remain open.

- Launch package / handoff quality: **9.0/10**. It states the correct product
  spine, hard-floor gates, red-to-green requirement, permanent-agent panel,
  Opus architecture and product-domain audits, and the prohibition on starting
  G2/G3 early
  (`.planning/handoffs/mint-g1-goal-handoff-2026-07-12.md:127-232`,
  `:334-350`, `:470-498`).
- Current Swiss product/data-contract reality: **6.3/10**. The live repo still
  contains incomplete fact contracts, unsafe archetype fallbacks, local
  illustrative inputs that compute personalised-looking results, missing
  cross-border facts, and unresolved privacy/legal-time boundaries.
- The difference between 9.0 and 6.3 is intentional: the first score assesses
  the quality of the execution package; the second assesses what G1 can prove
  today against the code and executable specs.

`G2 allowed?` **NO**.

## What Was Verified

- `python3 tools/checks/mint_os_doctor.py --repo-only`: all checked-in repo tool
  contracts passed.
- Active branch was
  `codex/mint-product-usability-plan-20260712`; the worktree was clean before
  this evidence file.
- Read the G1 handoff/goal, parent plan, `DATA_LEDGER.md`, `DATA_QUEST.md`,
  `SCREEN_CONTRACTS.md`, Swiss-agent rules, operating/compliance skills,
  `LEGAL_RELEASE_CHECK.md`, `PRIVACY.md`, and the relevant live model/screens/
  services.
- `AGENT_SYSTEM_PROMPT.md`, required by
  `.claude/skills/mint-swiss-compliance/SKILL.md:20-26`, is absent. This is
  recorded as a workflow gap, not treated as a passed gate.

## P0 — Blocking Findings

### P0-1 — Five P0 loops do not yet have executable fact tiers

Only the Retirement Case has an explicit `minimum / useful /
specialist-only or source-sensitive` split
(`.planning/goals/G1-ledger-reality-baseline-2026-07-12.md:117-143`). The
parent plan lists required facts for the other loops but does not define which
result each fact unlocks or what must remain hidden when it is absent
(`.planning/mint-product-usability-plan-2026-07-12.md:155-221`).

Mechanical action:

- Add one section per P0 loop to `G1-ledger-gap-matrix.md`.
- Each row must include at least: `tier`, `required_for_output`,
  `allowed_output_when_missing`, `source/asOf`, `freshness`,
  `legal_jurisdiction`, `effectiveFrom/effectiveTo/taxYear`,
  `sensitivity/purpose`, `export/log policy`, `existing_gate | missing_gate |
  blocks_G2`, and exact ticket/commit.
- Add `forbidden_conclusion`, `specialist_handoff`, and `persist?` to the
  scenario-lever matrix.

### P0-2 — `archetype` is not safe as a high-stakes readiness fact

`CoachProfile.archetype` currently:

- treats a G permit as sufficient for `crossBorder`, without residence-country
  evidence (`apps/mobile/lib/models/coach_profile.dart:1881-1887`);
- treats missing nationality and arrival age as `swissNative`
  (`apps/mobile/lib/models/coach_profile.dart:1901-1905`);
- infers an independent's current LPP affiliation from a positive LPP balance,
  although a balance can be historical/free-passage wealth
  (`apps/mobile/lib/models/coach_profile.dart:1892-1898`);
- allows a cross-border 3a conclusion from G permit plus Swiss income without a
  complete tax-residency/ordinary-taxation contract
  (`apps/mobile/lib/models/coach_profile.dart:1950-1963`).

Mechanical action:

- Classify `archetype` as a derived output, not a self-proving fact.
- Add an `archetype_evidence_complete` predicate whose inputs include
  nationality, explicit US-person/green-card status, residence country,
  permit, arrival history, employment status, and current LPP affiliation.
- Missing evidence must produce `unknown/partial + open questions`; it must not
  silently produce a confident Swiss-native or frontalier result.
- Seed a negative test: missing nationality/residence evidence must not unlock
  a Swiss-native tax, 3a, retirement, or frontalier conclusion.

### P0-3 — Frontalier is a local calculator façade without its minimum ledger

The documented screen contract reads only archetype, nationality, salary, and
one ambiguous canton (`docs/codex/SCREEN_CONTRACTS.md:233`). `CoachProfile`
contains a single `canton`, nationality, arrival age, and permit, but no
residence country or work canton/commune
(`apps/mobile/lib/models/coach_profile.dart:1383-1445`). The backend domain
service requires residence country, permit, work canton, income, 3a/LPP,
civil status, children, and Swiss-income share
(`services/backend/app/services/frontalier_service.py:224-235`).

The mobile screen nevertheless calculates during `initState` from local GE,
CHF 7'000, single, 180 office days, 40 home-office days, and France defaults
(`apps/mobile/lib/screens/frontalier_screen.dart:34-61`).

Mechanical action:

- Add canonical rows for `residenceCountry`, `residenceCommune/postcode`,
  `workCanton`, `workCommune`, `residencePermit`, `incomeCurrency`,
  `taxSourceStatus/taxYear`, `teleworkDays + referencePeriod`,
  `healthSystemChoice + optionDate`, `socialSecurityAffiliation`, and
  `worldIncomeSwissShare`.
- Employer identity is not a minimum fact. If ever needed for a specialist
  dossier, collect it only with a named purpose, consent, minimisation, and
  export/redaction policy.
- `/segments/frontalier` remains `partial/blocked` until residence and work
  jurisdictions are explicit and its current-law inputs are sourced.
- Seed a negative test: missing residence country or work canton yields no
  personalised tax/health/social-insurance result.

### P0-4 — Housing and Retirement still compute from illustrative local values

Housing examples:

- `/hypotheque` computes from CHF 120'000 income, CHF 800'000 target price,
  CHF 100'000 cash, CHF 50'000 3a, CHF 200'000 LPP, and VD defaults
  (`apps/mobile/lib/screens/mortgage/affordability_screen.dart:215-240`).
- `/mortgage/amortization` computes from CHF 700'000, 2.5%, 15 years, and a
  30% marginal rate (`apps/mobile/lib/screens/mortgage/amortization_screen.dart:30-41`).
- `/mortgage/epl-combined` computes from CHF 100'000 cash, CHF 60'000 3a,
  CHF 200'000 LPP, CHF 900'000 target price, and ZH
  (`apps/mobile/lib/screens/mortgage/epl_combined_screen.dart:28-41`).

Retirement example:

- `/rente-vs-capital` calls `_recalculate()` at startup with age 50, salary
  CHF 100'000, LPP CHF 350'000, certificate split CHF 500'000/150'000,
  pension CHF 37'000, and ZH defaults
  (`apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:60-86`,
  `:119-123`).

Mechanical action:

- Classify these routes `local-slider` in `G1-route-state-matrix.md`.
- Durable current facts such as income, explicit cash, current debts, LPP, 3a,
  current mortgage balance/rate, and current expenses must come from the
  ledger. Their absence blocks personalised computation.
- Target purchase price, interest shock, retirement age, withdrawal mix, and
  return/inflation assumptions are Case/scenario levers and must remain visibly
  labelled assumptions.
- Resolve the contract contradiction whereby `mortgageCapacity` and
  `estimatedMonthlyPayment` are stored as profile fields
  (`docs/codex/DATA_LEDGER.md:298-300`) although G1 says derived outputs are
  recomputed and never stored as user facts
  (`.planning/goals/G1-ledger-reality-baseline-2026-07-12.md:55-60`).
- Seed negative tests for missing explicit cash/current debts and missing
  source-sensitive LPP facts.

### P0-5 — Retirement, disability, and succession output gates are incomplete

Retirement:

- The current contract makes `annual expenses/budget floor` a minimum fact and
  later lists `budget floor` as a scenario lever
  (`.planning/goals/G1-ledger-reality-baseline-2026-07-12.md:120-138`).
- Split this into `current annual expenses` as a durable fact and
  `retirement budget floor` as a scenario lever.
- Exact LPP split, caisse conversion terms, withdrawal eligibility/deadline,
  and spouse-consent requirements are conditionally required for a personalised
  rente/capital/mixed result. If absent, the screen may explain the mechanism
  and ask questions, but not display a confident comparison.

Disability:

- The current route contracts correctly require explicit salary, cash, and
  expenses, but model IJM/private-insurance switches as local coverage levers
  (`docs/codex/SCREEN_CONTRACTS.md:234-236`).
- A confirmed current coverage fact is not the same thing as a hypothetical
  coverage toggle. Exact IJM waiting period/rate/duration, LAA branch, and LPP
  invalidity/death benefit require provenance; existing certificate facts are
  documented in `DATA_LEDGER.md:265-283`.
- Without confirmed terms, output is limited to a range, unknown-coverage
  warning, and specialist checklist. MINT must not declare an actual AI/LPP/IJM
  entitlement.

Succession/donation:

- `nombreEnfants` is not an heir structure. `CoachProfile` has no dedicated
  heir-relationship or matrimonial-regime fact
  (`apps/mobile/lib/models/coach_profile.dart:1383-1418`).
- The current donation contract acknowledges that matrimonial regime is not
  collected and prohibits fake precision
  (`docs/codex/SCREEN_CONTRACTS.md:223-224`).
- No reserve/quotité, gift-tax, or legal-course conclusion may render until the
  required domicile/jurisdiction, family/heir relationships, ownership shares,
  mortgage/debts, and retirement-liquidity guard are sufficiently documented.

Mechanical action:

- Add explicit conditional result gates and negative fixtures for all three
  loops.
- Treat diagnosis/medical narrative as out of scope for the disability ledger;
  do not collect sensitive health free text.
- Treat matrimonial liquidation, testament/pact, usufruct/right of habitation,
  tax ruling, and policy interpretation as source-sensitive handoff questions,
  not automated legal answers.

### P0-6 — Legal-time metadata and privacy boundaries are absent from G1 acceptance

The required ledger-gap columns include user source and freshness but omit the
legal source, jurisdiction, tax/legal year, and effective interval that govern
Swiss calculations
(`.planning/goals/G1-ledger-reality-baseline-2026-07-12.md:35-39`).

The backend already has a better reference-data primitive: `RegulatoryRegistry`
stores source, jurisdiction-aware parameters, effective dates, tax year, and a
review timestamp (`services/backend/app/services/regulatory/registry.py:9-19`,
`:33-44`, `:54-64`). Frontalier mobile bypasses that model with simplified
flat source-tax rates and a TODO to use the backend
(`apps/mobile/lib/services/expat_service.dart:19`, `:37-46`).

Privacy contradictions also block acceptance of expanded backend provenance:

- `PRIVACY.md` says all personal data remains on-device, then says profiles are
  synchronised to Railway in the US (`PRIVACY.md:97-109`).
- It says no sensitive data is transmitted while the processor table lists
  profiles, scenarios, and snapshots on Railway (`PRIVACY.md:156-175`,
  `:245-264`).
- `DATA_LEDGER.md` says key-to-source/date provenance maps are safe to log
  (`docs/codex/DATA_LEDGER.md:418-430`), but a field name plus date can reveal a
  disability, pension, donation, or family event even without the raw amount.

Mechanical action:

- Keep legal/reference data separate from user facts. Every high-stakes
  constant must expose `jurisdiction`, `source_url/title`, `source_type`,
  `effectiveFrom/effectiveTo`, `taxYear`, and `reviewedAt`.
- A stale, unverified, or jurisdiction-mismatched constant produces partial
  state and an open question, not a confident result.
- Add `sensitivity`, `purpose`, `retention`, `backend_sync`, `LLM_allowed`,
  `log_allowed`, and `dossier_export` policy to relevant G1 rows/tickets.
- Default provenance metadata to **not loggable** for financial, family,
  health, pension, tax, and succession fields.
- Reconcile `PRIVACY.md` with actual local/backend flows before accepting new
  provenance sync or dossier/export behavior.

## Tiered Contract Required For Each P0 Loop

The tiers below are product gates, not a request to implement G2/G3 in G1.
`Specialist/source-sensitive` means MINT may collect a document-confirmed fact
or prepare a question, but may not replace the specialist's interpretation.
When a result depends on such a fact, it becomes **conditionally required** for
that result rather than being silently optional.

### 1. Work / first salary / tax / first 3a

Minimum for personalised payslip/tax orientation:

- gross pay and pay frequency/number of salary months;
- birth year/date, employment status, employment rate;
- residence canton; commune only when communal-tax precision is claimed;
- current LPP affiliation;
- civil status/children when the displayed tariff depends on them;
- nationality, permit, and explicit US-person status before 3a eligibility.

Useful:

- annual bonus, declared net income, current 3a, LPP certificate terms, work
  canton, recurring professional costs.

Specialist/source-sensitive:

- salary/tax-at-source certificate, exact tariff decision, caisse regulation,
  IJM policy, and US/cross-border tax interaction.

### 2. Housing affordability / mortgage / EPL

Minimum for a personalised affordability range:

- birth year and retirement horizon;
- gross household income with spouse/co-borrower status;
- explicit liquid cash and existing debts/fixed obligations;
- target purchase price as a Case lever, not current wealth;
- intended occupancy/use and household status.

Conditionally minimum when EPL/pledge is modelled:

- 3a/LPP balances, current affiliation, oblig/suroblig facts when relevant,
  dates of recent buybacks, and own-funds composition.

Useful:

- canton/commune, current mortgage rank/rate/renewal, expected retirement
  income, property running costs, and post-retirement expense range.

Specialist/source-sensitive:

- bank underwriting decision, caisse EPL regulation/eligible amount,
  pledge-vs-withdrawal interpretation, spouse consent, and exact tax treatment.

### 3. Retirement preparation / decumulation / rente vs capital

Minimum for a personalised range:

- complete archetype evidence;
- birth year/date, target retirement age, civil/partner status;
- canton/commune for claimed tax precision;
- AVS estimate or contribution-year/gap evidence;
- LPP balance and sufficient payout basis for the displayed option;
- 3a accounts/balances;
- current annual expenses, explicit liquid cash, mortgage/property/debts.

Useful:

- dependants, spouse pension context, other assets/debts, future large
  expenses/gifts, survivor/beneficiary context.

Specialist/source-sensitive:

- caisse regulation, oblig/suroblig conversion terms, capital-withdrawal
  deadline/eligibility, spouse consent, latest tax decision, beneficiary
  clauses, matrimonial regime, testament/pact/mandate.

Scenario levers kept out of user facts:

- retirement age alternative, rente/capital/mixed ratio, 3a withdrawal order,
  retirement budget floor, return/inflation/withdrawal assumptions, planned
  gift/advance.

### 4. Disability / income protection

Minimum for a cash-runway/gap range:

- employment status and legal form where self-employed;
- gross/net income basis, age, explicit liquid cash, fixed monthly expenses;
- illness-versus-accident branch;
- whether each current coverage is known, unknown, or absent.

Conditionally minimum for an exact coverage phase:

- IJM waiting period/rate/duration, LAA affiliation/insured salary, LPP
  invalidity/death benefits, and employer continuation terms, all with source.

Useful:

- dependants, spouse income, debt payments, other recurring obligations.

Specialist/source-sensitive:

- policy exclusions, certificate interpretation, actual AI/LPP entitlement,
  coordination of benefits. Diagnosis and medical free text are not collected.

### 5. Succession / property transmission / donation

Minimum before an estate/reserve illustration:

- domicile and applicable jurisdiction trigger, nationality where conflicts of
  laws may matter;
- civil/partner status and heir relationships, not only child count;
- ownership shares, property value, mortgage, other estate assets/debts;
- retirement-liquidity guard for the donor/parents;
- donation amount, recipient relationship, type, and advancement flag as Case
  levers.

Useful:

- previous gifts/advances, beneficiary context, spouse/partner pension and
  survivor liquidity, broad wealth reconciliation.

Specialist/source-sensitive:

- matrimonial liquidation and own/acquired-property classification,
  testament/pact, usufruct/right of habitation, cantonal tax ruling, notarial
  deed, and land-register implications.

### 6. Cross-border worker / frontalier

Minimum for any personalised regime map:

- residence country and work canton/commune as separate facts;
- permit and employment status;
- gross income/currency and applicable tax year;
- civil/family/dependant context;
- tax-at-source status;
- telework days plus reference period;
- health-system/right-of-option status and date;
- AVS/LPP affiliation and current 3a context.

Useful:

- share of worldwide income earned in Switzerland, spouse/household income,
  secondary activities, employer legal location without storing employer name,
  and travel pattern.

Specialist/source-sensitive:

- treaty/competent-authority interpretation, actual withholding assessment,
  A1/social-security certificate, health-option proof, payroll certificate,
  and tax-residence attestation.

## No-Advice Output Boundary

All six loops must render facts, ranges, alternatives, missing data, source/year,
open questions, and a specialist-ready handoff. They must not rank or decide.

| Loop | Forbidden conclusion | Allowed educational output |
|---|---|---|
| Work | provider/product instruction or definitive 3a eligibility from incomplete archetype | payslip mechanism, ranges, missing facts, questions for payroll/caisse/tax specialist |
| Housing | prediction that a bank will approve; instruction to pledge/withdraw LPP | affordability range under visible assumptions; own-funds and post-retirement questions |
| Retirement | ranking rente vs capital or telling the user which form to take | rente/capital/mixed side-by-side, sensitivity, survivor/liquidity/tax questions |
| Disability | declaration of entitlement or policy purchase instruction | gap/runway ranges, known/unknown coverage map, documents/questions to verify |
| Succession | notarial/legal answer, automatic usufruct/donation course, unsupported gift-tax figure | net-mass reconciliation, legal forces, guard questions, specialist checklist |
| Frontalier | choice of LAMal/CMU, tax election, or treaty conclusion for incomplete facts | jurisdiction map, dated rules, uncertainty, authority/specialist questions |

This boundary follows the repo's no-advice/no-ranking doctrine
(`rules.md:70-76`, `docs/AGENTS/swiss-brain.md:101-109`) and the explicit
Retirement Case prohibition
(`.planning/mint-product-usability-plan-2026-07-12.md:187-192`).

## AVS / Couple Follow-Up — NO-GO

Audit date: 2026-07-12. Official sources were rechecked against the 2026
AVS/AI information and the current OFAS implementation notice for the 13th
old-age pension.

### Product contract

#### Optional account linking

- A partner-account link is optional. Refusing or revoking it must not block
  the user's own MINT profile, own AVS explanation, or non-household flows.
- A household membership, invitation, or `invitationLevel=linked` is not by
  itself permission to import financial facts. Every shared fact requires the
  partner owner token, source, source date, purpose/scope grant, grant date,
  and revocation behavior described by `G1-provider-boundary.md`.
- Facts entered by one person about a partner remain
  `declared_about_partner`; they do not become `partner_confirmed` or
  certificate-backed merely because both accounts are members of one
  household.
- A revocation must invalidate linked facts and derived household outputs
  without deleting an independently declared value owned by the remaining
  user. A field-level link grant must not silently expand to AVS, LPP, tax,
  cash, or budget facts outside its scope.
- The CI contract supports this boundary: an individual-account extract is
  delivered only to the insured person, their legal representative, or their
  lawyer. MINT therefore needs either a partner-authorized fact bridge or a
  separately consented partner-document flow; it must not make account linking
  compulsory.

#### Married, registered, and cohabiting households

- Old-age pensions and contribution gaps remain individual. MINT first
  computes or imports each person's individual pension; it never sums the two
  persons' gap years into one household gap.
- For AVS, an existing registered partnership is assimilated to marriage. A
  dissolution is assimilated to divorce and the survivor to a widow/widower.
  Cohabiting partners remain two individual pension recipients: no married
  150% cap and no marital splitting.
- Splitting distributes the incomes from the relevant civil years of marriage
  or registered partnership equally. It is performed on the statutory events,
  including divorce/dissolution and when both spouses reach reference age.
  When only one spouse has reached reference age, the incomes used for that
  first calculation are not yet split; both pensions are recalculated when
  the second entitlement triggers splitting. Current salary multiplied by a
  marriage duration is an educational proxy, not an exact statutory
  calculation.
- When the cap applies and both contribution durations are complete, the 2026
  maximum sum is CHF 3'780 per month. If `R1 + R2` exceeds the applicable cap,
  each pension is reduced proportionally: `Ri_after = Ri_before * cap /
  (R1 + R2)`.
- CHF 3'780 is not a universal cap. If either contribution duration is
  incomplete, RAVS art. 53bis requires a lower cap derived from the applicable
  pension-scale percentages. Judicial dissolution of the common household is
  also a required legal exception to the ordinary married cap.
- A non-working spouse's contribution can be considered paid when the active
  spouse pays at least twice the minimum contribution. In 2026 this means CHF
  1'060 per year. This married/registered rule must not be applied to
  cohabiting partners. If the active spouse retires or ceases to meet the
  threshold, MINT must ask whether the non-working spouse registered and paid
  separately; it must not infer a gap or absence of gap.

#### 13th old-age pension from 2026

- The first payment is in December 2026. Eligibility requires a right to an
  old-age pension in December.
- The supplement equals one twelfth of the old-age pensions actually paid
  during the calendar year and is rounded to the nearest franc. A person whose
  pension begins mid-year does not receive one full ordinary monthly pension
  as the supplement.
- Child pensions, supplementary pensions, the AVS 21 transitional supplement,
  survivor pensions, and AI pensions are excluded from the calculation. The
  13th old-age pension is excluded from income relevant to supplementary
  benefits.
- Product outputs must keep `ordinaryMonthlyPension`,
  `december13thSupplement`, and `annualOldAgePension` separate. Dividing an
  annual 13-payment total by twelve and presenting it as the legal monthly
  pension is not acceptable.

### Live-repo blockers

1. `CoachProfile.avsGapEvidence` sets `spouseRequired = isCouple && conjoint !=
   null` (`apps/mobile/lib/models/coach_profile.dart:2030`). A married user with
   no `conjoint` object can therefore become `householdReady=true` from self
   evidence alone. The checked-in test currently asserts that fail-open
   behavior (`apps/mobile/test/models/avs_gap_evidence_test.dart:155-165`).
2. The wizard writes `registered_partner`
   (`apps/mobile/lib/data/wizard_questions_v2.dart:84-85`), but
   `CoachCivilStatus` has no registered-partnership member
   (`apps/mobile/lib/models/coach_profile.dart:27`) and the parser either falls
   back to single or maps legacy `partenariat` to cohabitation
   (`apps/mobile/lib/models/coach_profile.dart:3510-3529`).
3. No production writer found by repo-wide grep writes certificate provenance
   for `conjoint.prevoyance.lacunesAVS`. The field is currently present only in
   the evidence model and tests, so `spouseCertifiedYears` has no product
   unlock path.
4. `AvsGapEvidence` is a useful narrow certificate-only gap contract, but it is
   not complete AVS projection readiness. A numeric pension also depends on
   the applicable contribution scale/duration, RAMD or official pension
   estimate, reference age and pension percentage, relevant splitting, and
   educational/assistance credits.
5. `AvsCalculator.computeCouple` always uses the flat CHF 3'780 cap
   (`apps/mobile/lib/services/financial_core/avs_calculator.dart:165-181`) and
   cannot model incomplete scales or the judicial-separation exception.
6. The calculator's splitting path reduces per-year statutory history to
   current salary, ex-spouse current salary, and `marriageYears`
   (`apps/mobile/lib/services/financial_core/avs_calculator.dart:65-86`). It
   must remain explicitly illustrative unless grounded in sufficient CI or an
   official pension estimate.
7. `annualRente()` multiplies one monthly amount by 13
   (`apps/mobile/lib/services/financial_core/avs_calculator.dart:215-233`), and
   `CoupleOptimizer` divides it by twelve to inflate displayed monthly amounts
   (`apps/mobile/lib/services/financial_core/couple_optimizer.dart:354-367`).
8. `.claude/skills/mint-swiss-compliance/SKILL.md` attributes divorce
   splitting to LAVS art. 29sexies. The correct provision is art.
   29quinquies; art. 29sexies governs educational credits.

### MUST before G1 acceptance

- Replace one overloaded readiness boolean with, at minimum, `selfReady`,
  `householdTotalReady`, and `maritalCapReady`. Partner evidence is required
  for a household total whenever a couple total is requested, regardless of
  whether the `conjoint` object already exists.
- Add an explicit registered-partnership civil status and round-trip aliases;
  apply married AVS behavior to it and never to cohabitation.
- Provide a real, authorized path for spouse CI/gap evidence without requiring
  account linking; preserve owner and field-level grant through persistence,
  restart, revocation, and recompute.
- Keep `noGaps`, `arrivedLate`, `livedAbroad`, and `unknown` as declarations.
  They never create certificate-backed numeric years. Every AVS-sensitive
  consumer must preserve unknown as partial/null rather than `?? 0`.
- Introduce a broader AVS projection-readiness contract before publishing
  pension, replacement-rate, household-cap, ruin-probability, or AVS-sensitive
  action amounts.
- Implement scale-aware proportional plafonnement and the named legal
  exceptions; do not use CHF 3'780 for incomplete scales.
- Quarantine or clearly label simplified splitting until sufficient
  person-owned history or an official calculation is present.
- Model the 13th pension as a dated annual cash flow from actual payments and
  December eligibility, never as a permanent 8.3% monthly uplift.

### Deterministic negative and positive fixtures

| id | fixture | required result |
|---|---|---|
| AVS-CPL-01 | married, self certified zero gaps, `conjoint=null` | `selfReady=true`, household total/cap not ready, partner path missing |
| AVS-CPL-02 | `q_civil_status=registered_partner` | typed registered partnership; married splitting/cap rules active |
| AVS-CPL-03 | cohabitants, CHF 2'520 each | CHF 5'040 combined educational view; no 150% cap |
| AVS-CPL-04 | married/registered, complete scales, CHF 2'520 each | proportional result CHF 1'890 each; total CHF 3'780 |
| AVS-CPL-05 | married/registered, CHF 2'520 + CHF 1'680 | ratio 0.9; CHF 2'268 + CHF 1'512 |
| AVS-CPL-06 | either pension scale incomplete | applicable cap is below CHF 3'780 and follows RAVS art. 53bis percentages |
| AVS-CPL-07 | married but common household judicially dissolved | no ordinary married cap |
| AVS-SPL-01 | only first spouse reaches reference age | no splitting yet; household result remains staged/partial |
| AVS-SPL-02 | second entitlement triggers splitting | both pensions recalculated from eligible civil-year incomes; no current-salary proxy labelled exact |
| AVS-CONTRIB-01 | married/registered, non-working spouse, active spouse pays CHF 1'060 in 2026 | contribution considered paid for that year; no invented gap |
| AVS-CONTRIB-02 | same facts but cohabiting | no derived contribution coverage |
| AVS-LINK-01 | household membership without AVS field grant | no partner AVS import; linked membership remains metadata only |
| AVS-LINK-02 | AVS-only grant then revocation | linked AVS fact and derived household outputs invalidated; independent declaration preserved |
| AVS-13-01 | stable CHF 1'890 old-age pension paid Jan-Dec, entitled in December | supplement CHF 1'890; annual CHF 24'570; ordinary monthly remains CHF 1'890 |
| AVS-13-02 | CHF 1'890 pension paid Jul-Dec, entitled in December | supplement CHF 945, rounded to franc; not CHF 1'890 |
| AVS-13-03 | no old-age-pension entitlement in December | no 13th pension |
| AVS-13-04 | child, supplementary, AVS21 transitional, survivor, or AI component | excluded from 13th-pension base |

### Official sources

- AVS/AI Information Centre, *3.01 — Old-age pensions and helplessness
  allowances, status 1 January 2026*: https://www.ahv-iv.ch/p/3.01.f
- AVS/AI Information Centre, *Old-age pensions — calculation, splitting and
  plafonnement*:
  https://www.ahv-iv.ch/fr/assurances-sociales/assurance-vieillesse-et-survivants-avs/rentes-de-vieillesse
- AVS/AI Information Centre, *Registered partnership assimilated to marriage*:
  https://www.ahv-iv.ch/fr/Assurances-sociales/Assurance-vieillesse-et-survivants-AVS/G%C3%A9n%C3%A9ralit%C3%A9s
- AVS/AI Information Centre, *Contributions and individual account*:
  https://www.ahv-iv.ch/fr/Assurances-sociales/Assurance-vieillesse-et-survivants-AVS/Cotisations
- AVS/AI Information Centre, *2.03 — Contributions of non-working persons,
  2026*: https://www.ahv-iv.ch/p/2.03.f
- OFAS, *Implementation of the 13th AVS pension*, updated 19 June 2026:
  https://www.bsv.admin.ch/fr/misenoeuvre-13-rente-avs
- AVS/AI Information Centre, *Request for an individual-account extract*:
  https://www.ahv-iv.ch/fr/Formulaires/Demande-dextrait-de-compte
- Fedlex, LAVS, state 1 January 2026 (arts. 29quinquies, 34ter, 35):
  https://www.fedlex.admin.ch/eli/cc/63/837_843_843/fr
- PFPDT, *Privacy by design and by default*:
  https://www.edoeb.admin.ch/fr/la-nouvelle-loi-federale-sur-la-protection-des-donnees-du-point-de-vue-du-pfpdt

Ticket routing: certified-null consumption and household readiness are
`G1-LDG-06A`; field-level partner authorization/revocation is `G1-BND-02A`;
registered status, splitting, scale-aware cap, and legal exceptions are
`G1-AVS-01`; the annual December cash-flow contract is `G1-AVS-02`. These
sub-tickets remain G1 blockers and do not authorize G2/G3 implementation.

## P1 — Must Be Triaged Before G1 Acceptance

1. `/first-job` now blocks results until salary, age, and canton are explicit,
   but employment rate remains a local default in the calculation even though
   the plan names it as required
   (`apps/mobile/lib/screens/first_job_screen.dart:68-78`, `:150-175`;
   `.planning/mint-product-usability-plan-2026-07-12.md:157-161`). Make current
   employment rate a ledger fact or visibly label it as an illustrative
   assumption; do not present it as known.
2. `/simulator/job-comparison` correctly takes current salary/age from the
   ledger but seeds current and new LPP/IJM values locally
   (`apps/mobile/lib/screens/job_comparison_screen.dart:72-94`, `:120-165`).
   Current-job certificate values are durable/source-sensitive facts; new-offer
   values are scenario assumptions. The matrix must keep that boundary.
3. Rename the conceptual tier `specialist-only` to
   `specialist/source-sensitive` in explanatory text, while retaining the
   requested three-tier contract. Some facts can be document-confirmed by the
   user, but their legal interpretation remains a handoff question.
4. Every calculation output must carry a dated source and the standard
   educational disclaimer
   (`.claude/skills/mint-swiss-compliance/SKILL.md:43-58`); checked boxes in
   `LEGAL_RELEASE_CHECK.md` are not runtime evidence
   (`LEGAL_RELEASE_CHECK.md:15-44`).

## P2 — Non-Blocking Documentation/Workflow Debt

1. Restore, replace, or remove the stale `AGENT_SYSTEM_PROMPT.md` must-read
   reference in the compliance skill; record the chosen source of truth.
2. Reconcile `PRIVACY.md` phase labels and claims with the live product before
   public release. Its February 2026 copy is not a reliable description of the
   July 2026 data spine (`PRIVACY.md:1-5`).
3. Add a compact glossary distinguishing `user fact`, `Case fact`, `scenario
   lever`, `derived output`, `reference/legal constant`, and
   `specialist-handoff-only datum` so future matrices cannot collapse them.

## Required Negative Fixtures / Mechanical Predicates

At minimum, G1 tickets or executable tests must prove these seeded violations:

1. missing nationality/residence evidence does not become `swissNative`;
2. frontalier missing residence country or work canton produces no result;
3. mortgage missing explicit cash/current debts produces no personalised result;
4. retirement missing source-sensitive LPP payout facts produces partial state;
5. disability with unknown IJM/LAA/LPP terms produces no exact coverage grade;
6. succession missing heir structure/matrimonial context produces no
   reserve/quotité or legal conclusion;
7. stale, unsourced, or wrong-jurisdiction regulatory constants produce partial
   state;
8. sensitive provenance field names/dates are not logged or sent to LLM/audit
   prompts.

## Final Decision

`G2 allowed?` **NO**.

G1 may continue. It becomes eligible for re-audit only after the six tiered
contracts, archetype-evidence gate, legal-time/privacy columns, current route
classifications, blocking tickets, hard-floor red-to-green proof, and scorecard
are checked in. No G2 DataQuest implementation and no G3 loop implementation
is authorised by this audit.
