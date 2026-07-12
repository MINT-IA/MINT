# G1 Swiss Product Audit — `mint-swiss-brain` + Product Lead

Date: 2026-07-12

Scope: G1 Ledger Reality Baseline only

Mode: read-only audit of the existing contracts and live repo before this evidence file

Auditor roles: `mint-swiss-brain`, MINT product lead

## Verdict

**GO to continue G1. NO-GO to mark G1 complete or start G2/G3.**

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
