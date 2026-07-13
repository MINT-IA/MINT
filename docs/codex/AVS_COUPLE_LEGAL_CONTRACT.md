# AVS Couple Legal Contract — G1 implementation spec

> Status: **NO-GO for activation of a complete couple AVS result**.
> This is the blocking specification for `G1-LDG-02`, `G1-LDG-06A`,
> `G1-BND-02A`, `G1-AVS-01`, and `G1-AVS-02`.
> Legal snapshot: **2026-07-13**, law in force on **2026-01-01** unless a
> source below states a later date. Product scope: AVS old-age projections.
> This document does not authorize G2/G3 and does not replace a decision by an
> AVS compensation fund or a Swiss civil-status authority.

## 0. G1 verdict at `fad6e9bc1`

The B2 hard floor is correct and must remain: live Forecaster and retirement
projection paths do not emit a complete AVS, household income, replacement
rate, or monthly gap while official person-owned AVS pensions and their source
dates are absent. The retirement sequences can record `avs_pending` and
continue without inventing numeric outputs.

G1 couple AVS nevertheless remains **NO-GO** because the production model still
destroys the registered-partnership status, the available couple calculator is
not scale/status/entitlement aware, the salary-duration splitting proxy is not
an official calculation, the 13th pension is still represented as a monthly
uplift in dormant code, and partner grants do not exist. Sections 6 and 7 are
the executable acceptance contract and current severity inventory.

## 1. Product rule

MINT models **one pension per person**, then an optional household view. Account
linking is optional and is neither proof of civil status nor blanket permission
to share financial data.

```text
self evidence ──> self individual pension/state ──┐
                                                   ├─> household aggregation
partner evidence ─> partner individual state ─────┘       │
                                                           └─> marital cap, only if legally applicable
```

An absent, unlinked, non-consenting, or partially documented partner is never
worth CHF 0. It produces a missing partner component. The known person's
individual view remains available whenever its own prerequisites are met.

The product must expose three different readiness states, never one generic
`coupleReady` boolean:

- `selfPensionReady`;
- `householdAggregationReady`;
- `maritalCapReady`.

## 2. Legal rules to encode

### 2.1 Civil status is a legal input, not a UI synonym

The canonical enum must distinguish:

- `single`;
- `married`;
- `registeredPartnership` (an existing or Swiss-recognized registered
  partnership);
- `cohabiting`;
- `divorced`;
- `widowed`.

For AVS, a registered partnership follows the rules of marriage; its judicial
dissolution follows divorce, and the surviving registered partner follows the
widowhood treatment. It remains a distinct civil-status value in MINT even when
an AVS calculation uses the same legal branch as marriage.

No new registered partnerships can be concluded **in Switzerland** since
1 July 2022, but existing partnerships can remain. A foreign registered
partnership may be recognized in Switzerland if it creates the required
civil-status bond; a PACS, generic civil union, or free-text `partenariat` must
not be assumed to have that effect.

The legacy bare token `partenariat` is ambiguous in MINT. Migration must preserve
the raw value and partner facts, set a `civilStatusNeedsConfirmation` state, and
ask for reconfirmation. It must not coerce the token to either cohabitation or a
registered partnership and must not activate an AVS marriage-equivalent rule.

Do not use one generic `isCouple` predicate for legal calculations. Provide at
least these explicit predicates:

- `hasPartnerContext`: married, registered partnership, or cohabiting;
- `isAvsMarriageEquivalent`: married or registered partnership;
- `isAvsCohabiting`: cohabiting;
- `isJudiciallySeparatedHousehold`: spouses or registered partners who no
  longer live in a common household following a judicial decision; this is a
  distinct sourced fact, never inferred from an address, invitation, account
  unlink, or user silence.

### 2.2 Individual pension first

Each person's ordinary monthly old-age pension is determined independently
from that person's applicable contribution scale, determining average annual
income, credits, and statutory adjustments. Missing data remains missing.

A current salary is not the determining average annual income recorded in the
individual accounts. A declared number of gaps, an arrival year, or a current
salary may support a clearly labelled illustration, but cannot become a
certificate-grade pension.

Minimum readiness must therefore be split:

| output | minimum evidence |
|---|---|
| self AVS illustration | self age/reference-age facts plus explicit illustrative assumptions; labelled estimate |
| self evidence-backed AVS | official pension estimate/decision, or CI-grade inputs sufficient for the explicitly declared confidence |
| partner AVS component | same evidence, owned by the partner; never a defaulted salary, age, RAMD, scale, gap count, or pension |
| household sum | both displayed person-owned components available at compatible confidence and authorized scope |
| marital cap | both qualifying benefits active, marriage-equivalent status known, judicial-separation exception known, both scales/percentages known, and both uncapped pensions known |

A certificate-backed gap count alone does not prove RAMD, contribution scale,
splitting history, entitlement status, or the final pension amount. A field that
is absent, revoked, expired, stale beyond its declared policy, or outside the
current purpose remains `null`, never numeric zero.

### 2.3 Splitting

Splitting is the equal attribution of income earned during complete common
calendar years of marriage. Under LAVS art. 29quinquies, it is performed only
when one of the statutory triggers occurs:

- both spouses reach reference age;
- a widow or widower reaches reference age;
- the marriage is dissolved by divorce;
- both spouses are entitled to an AI pension; or
- one spouse is entitled to an AI pension and the other reaches reference age.

Only income from periods in which both spouses were insured under Swiss AVS is
shared. The calendar year in which marriage begins and the calendar year in
which it ends are excluded. The same AVS treatment applies to registered
partnership and its judicial dissolution.

An exact splitting calculation requires, for each person:

- the relevant year-by-year individual-account incomes/cotisations;
- marriage/partnership start and end dates;
- periods in which both persons were insured under Swiss AVS;
- applicable child-care and care credits and their allocation;
- the triggering event and effective date; and
- the applicable contribution scale after the histories are assembled.

`currentSalaryA`, `currentSalaryB`, and `marriageYears` are not sufficient. A
salary-duration proxy may remain only as an explicitly illustrative scenario
with uncertainty; it must not use an `exact`, `certified`, or `complete` result
state. Prefer an official AVS pension estimate already reflecting splitting.

### 2.4 When the household cap applies

The cap in LAVS art. 35 applies to the sum of two individual pensions only when:

1. the legal status is marriage or registered partnership;
2. both persons receive an old-age pension, including a percentage of it, or
   one receives an old-age pension and the other an AI pension; and
3. the judicially separated-household exception does not apply.

It does not apply to cohabitants. It does not apply merely because a partner
record or household membership exists. Before the second qualifying benefit is
active, the first recipient's pension remains individual.

For two complete scale-44 pensions, the 2026 monthly cap is CHF 3'780, or 150%
of the CHF 2'520 individual maximum. If one or both contribution durations are
incomplete, a fixed CHF 3'780 cap is wrong.

Let `pLow` and `pHigh` be the RAVS art. 52 percentages of the lower and higher
pension scales. RAVS art. 53bis defines:

```text
weightedScalePercent = (pLow + 2 × pHigh) / 3
formulaLayerMonthlyCap = CHF 3'780 × weightedScalePercent
```

Example for scale 26 (`59.09%`) and scale 38 (`86.36%`):

```text
weightedScalePercent = (59.09% + 2 × 86.36%) / 3 = 77.27% (scale 34)
formulaLayerMonthlyCap = CHF 3'780 × 0.7727 = CHF 2'920.806
```

The official mandatory calculation rules and pension tables govern the payable
result and rounding. Do not introduce a second handwritten scale table in a
screen or service.

When percentages of pension are drawn, RAVS art. 53ter also applies:

- for anticipation of a percentage, multiply the scale-aware cap by the higher
  pension percentage; the rule applies by analogy when the other spouse receives
  an AI pension;
- for deferral of a percentage, the full old-age pension is determinative.

If `rawA + rawB > payableMonthlyCap`, reduce both pensions proportionally:

```text
factor = payableMonthlyCap / (rawA + rawB)
cappedA = rawA × factor
cappedB = rawB × factor
```

The output must preserve person ownership and expose `raw`, `capped`,
`capState`, `legalYear`, `source`, and every assumption or missing input.

### 2.5 The 13th old-age pension is a December cash flow

From 2026, keep at least these separate values:

- `ordinaryMonthlyPension`: the regular monthly old-age pension; never
  multiplied by `13/12`;
- `decemberSupplement`: one twelfth of the old-age pensions actually received
  during the calendar year, payable only if the person has an old-age pension
  right in December;
- `decemberCashReceipt`: December ordinary pension plus the supplement; and
- `annualCashTotal`: actual ordinary payments plus the December supplement.

For a stable CHF 2'520 pension paid January–December:

- ordinary monthly pension: CHF 2'520;
- December supplement: CHF 2'520;
- December cash receipt: CHF 5'040;
- annual cash total: CHF 32'760.

For a CHF 2'520 pension first paid July–December:

- six ordinary payments: CHF 15'120;
- December supplement: CHF 1'260 (`15'120 / 12`);
- annual cash total: CHF 16'380.

If there is no old-age pension entitlement in December, the supplement is zero.
Child pensions, supplementary pensions, the AVS 21 transitional supplement,
survivor pensions, and AI pensions are excluded from the supplement basis.

A UI may show `annualCashTotal / 12` only as an explicitly labelled **annual
average including the December supplement**. It must not call that figure the
monthly AVS pension.

For marriage-equivalent couples, apply the legally applicable ordinary monthly
cap first, then compute each person's supplement from that person's actually
paid, capped old-age pension history. A status, cap, entitlement, or percentage
change during the year requires month-level cash-flow inputs rather than
`ordinaryMonthly × 13`.

## 3. Account linking, provenance, and consent

### 3.1 Separate membership, authorization, and facts

`HouseholdProvider` may own invitations, membership and grants. It must not own
partner salary, AVS, LPP, or other financial truth. `CoachProfileProvider` and
the Data Ledger remain the durable fact spine.

A linked partner fact envelope must include:

- `canonical_key`;
- `profile_owner_id`: a pseudonymous partner-owner token;
- typed `value` (`null` means missing, never zero);
- `source`, `source_date`, `updated_at`, freshness policy, and confidence;
- `grant_id`, `grant_purpose`, exact `grant_scopes`, `granted_at`, and, when
  applicable, `expires_at` or `revoked_at`;
- a lineage identifier used to invalidate derived results and caches; and
- no email, name, AVS number, or raw document in logs, routes, analytics,
  calculator payloads, or runtime screenshots.

The minimum purpose is `avs_household_projection`. Scopes are an allowlist of
canonical fields, for example `avs.gap_years`, `avs.contribution_scale`,
`avs.official_monthly_estimate`, and `avs.splitting_status`. An AVS-only grant
must not import salary, LPP, 3a, debt, cash, identity documents, or raw AVS
documents.

Membership and civil status are independent facts:

- membership never proves marriage, registered partnership, cohabitation, or
  judicial separation;
- civil status never authorizes data access;
- account unlink never changes civil status; and
- a grant never transfers fact ownership from the partner to the inviting user.

### 3.2 Optional, purpose-specific, and revocable lifecycle

| state | allowed behavior |
|---|---|
| no account link | self view works; user may leave partner unknown or enter a clearly owned manual declaration after the third-person notice/authorization step |
| invitation pending | identical to no link; pending membership imports no facts |
| active membership, no grant | membership UI only; imports no financial facts |
| active AVS grant | bridge only the explicitly granted, confirmed partner facts with partner ownership and provenance; recompute authorized derived views |
| grant narrowed | immediately invalidate fields and derived outputs no longer covered by the new purpose/scope |
| grant revoked/expired | immediately invalidate linked facts and dependent caches/results; retain or restore an independent manual declaration with its original provenance |
| account unlinked | same linked-fact invalidation as revocation; civil status remains unchanged |

Consent must be informed, purpose-specific, optional, and revocable. MINT adopts
this explicit-grant product covenant even where consent is not the only possible
nLPD justification. The partner must be informed of the collection, purpose,
data categories, recipients/processors, retention, rights, and any transfer
abroad. Linking two accounts is not permission to every field.

Manual entry or scanning of another person's data is third-person collection.
The product must require the entering user to confirm authorization and must
make the partner notice available; the nLPD art. 19 indirect-collection duty is
not satisfied merely because the entering user knows the value.

Revocation must win over an in-flight read or calculation. A late response with
a revoked `grant_id` or obsolete lineage must be discarded, not re-persisted.

## 4. Variable, explanation, and dossier contract

### 4.1 Variable tiers

| tier | variables |
|---|---|
| minimum self state | person owner, official monthly pension or explicit illustrative inputs, source, source date, confidence, ordinary/percentage entitlement state |
| minimum household sum | both person-owned components plus compatible date/scope/confidence and authorization for partner facts |
| minimum cap | Swiss AVS marriage-equivalent status, both qualifying benefits and percentages, both scales, both raw pensions, sourced judicial-separation state, legal year |
| minimum 13th cash flow | person-owned monthly old-age payments actually received, December entitlement, excluded-component breakdown |
| useful | compensation fund, estimate/decision date, contribution-account extract date, reference-age/anticipation/deferral choices, splitting trigger/date |
| compensation-fund or specialist handoff | year-by-year CI histories, cross-border coordination periods, disputed civil-status recognition, legal decision concerning separate households, unresolved credits or splitting |

MINT must not collect the year-by-year specialist tier merely to render an early
educational screen. Progressive disclosure applies: request the official pension
estimate first when it can answer the product question with less data.

### 4.2 Compliant degraded explanation

The AVS-pending surface must communicate all three ideas:

1. the known capital/LPP/3a view remains useful;
2. the AVS amount and household totals are not included yet; and
3. the missing partner amount is unknown, not CHF 0, and linking is optional.

Acceptable pattern:

> Ta rente AVS n'est pas encore incluse. Les montants connus restent visibles,
> mais le revenu total et le taux de remplacement attendent une estimation AVS
> officielle. Pour une vue de ménage, tu peux saisir les données autorisées de
> ton ou ta partenaire, relier vos comptes avec un partage AVS limité, ou
> continuer avec ta vue individuelle.

Do not rank manual entry above linking or linking above manual entry. Do not
imply that marriage makes financial disclosure compulsory.

### 4.3 Specialist-ready dossier/PDF

The dossier may contain an AVS couple section only when each included fact has
owner, source, source date, and authorization. It must show:

- each person's ordinary pension separately;
- raw versus capped amount and the legal cap state;
- contribution scale and percentage, or `missing`;
- splitting status, trigger, and evidence level;
- December supplement separately from the ordinary monthly pension;
- assumptions, missing fields, legal-year snapshot, and source links;
- grant purpose/scope in internal export metadata, without exposing identifiers
  to the other partner beyond the agreed dossier purpose; and
- questions for the compensation fund: applicable scale, splitting completion,
  cap/percentage treatment, judicial-separation exception, and 13th-pension
  payment history.

No PDF may present a salary-duration proxy as an official pension or silently
merge two person-owned facts into one unattributed household number.

## 5. Required degraded states

| legal/data state | self output | partner output | household output | cap state | required recovery |
|---|---|---|---|---|---|
| married/registered, partner absent or unlinked | show if self-ready | missing | null/partial | pending | ask only for missing partner AVS facts; offer manual entry and optional invitation equally |
| married/registered, partner gap count known but RAMD/scale/splitting missing | show if self-ready | partial, no CHF 0 | null/partial | pending | request official estimate/CI prerequisites |
| cohabiting, partner absent | show if self-ready | missing | null/partial | not applicable | optional partner data for a household view; never block self |
| cohabiting, both individual pensions known | show | show | uncapped sum | not applicable | explain that pensions remain individual |
| marriage-equivalent, both pensions/scales/rights complete | show raw and capped ownership clearly | show raw and capped ownership clearly | capped sum | applied/not needed | show source date, legal year, percentages, and assumptions |
| judicially separated household after a court decision | show | show if authorized | uncapped sum if requested | legal exception | source the judicial-decision fact; do not infer it |
| legacy bare `partenariat` | show if self-ready | do not discard existing partner facts | null/partial | pending | reconfirm exact civil status; do not guess |
| foreign PACS/civil union without Swiss recognition evidence | show if self-ready | show if authorized | uncapped/partial only | not applicable or pending | ask whether the status is recognized as a registered partnership in Switzerland |
| declared `noGaps` without evidence | partial/illustrative only | n/a | null | pending/not applicable | obtain/confirm evidence; declaration never fabricates certified zero years |
| grant revoked during calculation | unchanged self view | invalidated | recompute without revoked fields | pending/not applicable | discard late linked response and explain that sharing ended |

Manual partner entry must not be visually subordinated to account linking. The
CTA language must make clear that linking is optional and revocable.

## 6. Exact TDD acceptance tests

These are executable contracts, not prose examples. Tests that cover the B2
hard floor may already be green at `fad6e9bc1`; the remaining legal, cash-flow,
status, and grant contracts are expected to start RED. Do not weaken a B2 test
to make a later couple implementation pass.

### 6.1 Civil-status semantics

Target: `apps/mobile/test/models/coach_profile_semantic_roundtrip_test.dart`

1. `registered_partner stays registered partnership through wizard -> model -> json -> model`
   - input: `q_civil_status=registered_partner`;
   - expect: canonical `registeredPartnership`, not `single` or `cohabiting`;
   - expect: serialized/reloaded value preserves the same typed meaning.
2. `explicit registered partnership aliases converge`
   - inputs: `registered_partner`, `registered_partnership`, and
     `partenariat_enregistre`;
   - expect: all map to `registeredPartnership`;
   - `cohabiting`/`concubinage` map only to `cohabiting`.
3. `registered partner update does not clear spouse answers`
   - seed `q_partner_birth_year` and partner AVS facts; merge
     `q_civil_status=registered_partner`; expect partner keys retained.
4. `AVS legal predicates are distinct`
   - expect `isAvsMarriageEquivalent` true only for married/registered;
   - expect `hasPartnerContext` true also for cohabiting.
5. Widget RED: the composition-household DataBlock must render a distinct
   `civil_status_registered_partner_choice` and persist the canonical token.

### 6.2 Couple cap and splitting

Target:
`apps/mobile/test/services/financial_core/avs_couple_legal_contract_test.dart`

6. `married scale44 pair caps proportionally at 3780`
   - raw `2'520 + 2'520`; expect `1'890 + 1'890 = 3'780`.
7. `registered partnership uses identical AVS cap contract`
   - same fixture/status registered; expect the same AVS output as married.
8. `cohabiting pair is not capped`
   - raw `2'520 + 2'520`; expect `5'040`, cap `notApplicable`.
9. `scale38 plus scale26 uses RAVS weighted cap`
   - scale percentages `86.36` and `59.09`, raw pensions above the weighted
     cap; expect formula-layer cap close to `2'920.806`, never `3'780`, then
     apply the official calculation/rounding boundary.
10. `judicially separated spouses are not capped`
    - marriage-equivalent status plus sourced judicial separation; raw sum is
      returned uncapped with exception reason.
11. `first pension event does not activate couple cap`
    - one old-age pension active, partner has no qualifying AVS/AI entitlement;
      expect the active individual pension unchanged.
12. `missing partner scale makes cap pending, not scale44`
    - raw self pension plus partner pension but `partnerScale=null`; expect no
      complete capped household result and an exact missing field path.
13. `current salaries and marriageYears cannot certify splitting`
    - only `60'000`, `120'000`, `20 years`; expect splitting state
      `insufficientEvidence`, not a recalculated exact RAMD/pension.
14. `splitting requires a statutory trigger`
    - complete account histories but no statutory trigger; expect
      `notTriggered`; do not apply splitting prematurely.
15. `missing partner age or RAMD does not become zero or age 45`
    - partner has certified gap years but no birth date, scale, RAMD, or
      official estimate; expect partner pension and household total
      null/partial.

### 6.3 13th pension cash flow

Target:
`apps/mobile/test/services/financial_core/avs_thirteenth_pension_cashflow_test.dart`

16. `full-year pension keeps ordinary monthly amount and doubles December cash`
    - 12 × CHF 2'520 old-age payments, December eligible;
    - expect ordinary monthly `2'520`, supplement `2'520`, December cash
      `5'040`, annual cash `32'760`.
17. `July start receives one twelfth of payments actually made`
    - six × CHF 2'520, December eligible;
    - expect supplement `1'260`, annual cash `16'380`.
18. `no December old-age entitlement means no supplement`
    - any January–November old-age payments, December not eligible;
    - expect supplement `0`.
19. `excluded components never enter supplement basis`
    - child, supplementary, AVS 21 transitional, survivor, and AI amounts added
      beside old-age pension; expect supplement based only on old-age payments.
20. `monthly display never uses annual divided by twelve as legal monthly pension`
    - CHF 2'520 stable pension; expect `ordinaryMonthlyPension=2'520` and, if
      exposed, `annualAverageIncludingDecemberSupplement=2'730` under that
      exact label only.
21. `couple supplement uses capped person-owned payment histories`
    - two scale-44 raw maxima; cap ordinary pensions to CHF 1'890 each, then
      expect a CHF 1'890 supplement for each full-year recipient.

### 6.4 Readiness and optional linking

Targets: `apps/mobile/test/models/avs_gap_evidence_test.dart` and
`apps/mobile/test/providers/partner_financial_consent_lifecycle_test.dart`

22. `married without conjoint object preserves self individual readiness`
    - self evidence complete, no partner object; expect self result available,
      partner/household/cap pending and partner missing path present.
23. `registered partnership without link behaves like married partial state`
    - same expected readiness, without coercing account linking.
24. `cohabiting without partner data never blocks self`
    - expect self available, household partial, cap not applicable.
25. `declared no gaps is not certified zero`
    - status `noGaps`, no certificate; expect certified gap years null.
26. `active household membership without grants imports zero fields`
    - expect membership visible; no partner financial ledger writes.
27. `AVS-only grant imports only exact AVS scopes`
    - linked payload includes AVS, salary, and LPP; grant contains AVS scopes;
      expect only AVS facts bridged with partner-owner/grant provenance.
28. `revocation invalidates linked facts and derived results`
    - seed linked AVS plus older independent manual declaration; revoke;
      expect linked facts/caches invalidated and manual declaration restored.
29. `missing linked value remains null`
    - partner payload omits/returns null gap, scale, or pension; expect no zero
      write and no complete household output.

### 6.5 Strengthened migration, percentage, and race contracts

Targets: the same files plus
`apps/mobile/test/services/retirement_projection_avs_hard_floor_test.dart`

30. `bare partenariat is quarantined for reconfirmation`
    - input legacy `q_civil_status=partenariat`;
    - expect `civilStatusNeedsConfirmation=true`, no AVS marriage-equivalent
      predicate, and existing partner facts preserved but not consumed.
31. `foreign PACS is not automatically a registered partnership`
    - input `pacs` or generic foreign civil union without Swiss recognition;
    - expect no marriage-equivalent cap/splitting and a recognition question.
32. `anticipated percentage applies RAVS 53ter highest percentage cap`
    - scale-aware couple cap plus two anticipated pension percentages;
    - expect the art. 53bis cap multiplied by the higher percentage, not the
      lower percentage and not the fixed CHF 3'780.
33. `deferred percentage uses the full pension as determinant`
    - one deferred percentage plus a qualifying partner pension;
    - expect the RAVS art. 53ter al. 2 rule, not the anticipation multiplier.
34. `legacy AVS fields without source date stay avs_pending`
    - seed certified gaps, RAMD, contribution years, and a legacy monthly
      estimate but no official pension/source date;
    - expect live Forecaster/RetirementProjection complete AVS totals,
      replacement rate, and monthly gap to remain null.
35. `dormant CoupleOptimizer cannot emit uncertified AVS cap`
    - seed only current salaries and ages;
    - expect `avsCap=null`/`insufficientEvidence`, never an AVS pension or 13th
      monthly uplift.
36. `revocation wins over an in-flight linked read`
    - start a linked AVS read, revoke its grant, then complete the old response;
    - expect no linked fact or derived result to reappear.
37. `narrower regrant invalidates removed scopes`
    - replace a pension+scale grant with scale-only scope;
    - expect the linked pension and every dependent household result removed,
      while unrelated manual/self facts remain.

## 7. Current code findings and severity

Line references are from commit `fad6e9bc1` on 2026-07-13. Other agents may
have uncommitted shared-tree work; this inventory deliberately uses that commit
as its review boundary.

### Resolved by B2 — regression hard floor, not a remaining finding

1. **Live Forecaster no longer turns missing partner inputs into CHF 0 AVS.**
   `forecaster_service.dart:893-897` fixes the AVS amount at null until the
   official pension/source-date path exists; `:1005-1028` keeps only non-AVS
   income available and complete retirement income null.
2. **Live RetirementProjection is fail-closed.**
   `retirement_projection_service.dart:205-269` keeps the complete pension,
   phases, early comparisons, budget gap, and replacement rate unavailable;
   `:308-312` documents the deliberately disabled official AVS path. The former
   missing-partner age-45 AVS completion finding is therefore obsolete.
3. **The guided retirement sequences no longer deadlock on that partial state.**
   `retirement_dashboard_screen.dart:69-75` emits explicit non-numeric
   `avs_pending` step outputs. This is completion of a reviewed screen, not
   certification of the missing pension.

### P0 — blocks any activation of a complete couple AVS result

1. **Registered partnership is destroyed at the model boundary.**
   `CoachCivilStatus` has no registered-partnership value
   (`coach_profile.dart:27`); `CoachProfile.fromJson` falls back to single for
   an unknown enum (`:2398-2400`) and `_parseCivilStatus` maps no explicit
   registered token (`:3510-3529`). The live wizard emits
   `registered_partner` (`wizard_questions_v2.dart:66-86`).
   `_setsNonCoupledCivilStatus` does not recognize it
   (`coach_profile_provider.dart:1271-1281`) and may clear partner facts.
2. **The only couple-cap API is legally incomplete.**
   `AvsCalculator.computeCouple` accepts only two amounts and `isMarried`, then
   always uses the fixed full-scale cap (`avs_calculator.dart:166-180`). It has
   no registered-partnership status, entitlement/percentage state, scales, or
   judicial-separation exception required by LAVS art. 35 and RAVS arts. 53bis-
   53ter.
3. **The advertised splitting algorithm is a salary-duration proxy.**
   `computeMonthlyRente` uses current salary, ex-spouse current salary, and
   `marriageYears` (`avs_calculator.dart:38-43`, `:73-88`). Those values cannot
   implement LAVS art. 29quinquies exactly. Existing tests still describe this
   proxy as divorce splitting.
4. **The dormant CoupleOptimizer can manufacture an uncertified AVS answer.**
   `_analyzeAvsCap` derives pensions from current salary/age, applies the fixed
   cap, and converts the 13th pension into a monthly uplift
   (`couple_optimizer.dart:319-367`). No production caller was found at the
   commit boundary, but the public `optimize` method exposes the result
   (`:148-175`); it must be quarantined or corrected before any caller is wired.
5. **Dormant RetirementProjection branches retain both former defects.**
   `_buildTransitionPhase` uses `annualRente(...)/12`
   (`retirement_projection_service.dart:688-708`, `:778-794`) and still
   defaults a missing partner age to 45 (`:780`). The live B2 gate prevents
   those branches (`:242-260`, `:312`), but enabling official AVS facts without
   replacing them would reintroduce a false age and monthly amount.
6. **Registered partnerships are excluded by the remaining marriage
   predicates.** CoupleOptimizer activates the AVS cap only for
   `CoachCivilStatus.marie` (`couple_optimizer.dart:347-352`), while Forecaster
   and RetirementProjection use the same narrow comparison in adjacent
   tax/capital paths. Adding an enum without migrating each domain-specific
   predicate would preserve the AVS defect and create cross-domain drift.

### P1 — blocking incompleteness or unusable product state

1. `AvsGapEvidence.spouseRequired = isCouple`
   (`coach_profile.dart:2017-2050`) conflates self, household-sum, and marital-
   cap readiness and also treats cohabitation as a spouse-cap requirement.
2. `HouseholdProvider` stores membership as untyped maps and has no field grant
   or ledger bridge (`household_provider.dart:12-47`, `:52-183`). Membership,
   authorization, ownership, purpose, and partner facts are not separated.
3. No authorized production writer currently certifies person-owned partner
   AVS pension/scale/source-date fields. The spouse gap path exists as a read
   prerequisite but no purpose-scoped grant lifecycle can populate it.
4. The composition-household DataBlock offers no registered-partnership choice
   (`data_block_enrichment_screen.dart:697-733`) even though the older wizard
   does, so reconfirmation can erase the legally distinct status.
5. AVS readiness proves only certificate-backed gap years, not contribution
   scale, RAMD/splitting completeness, qualifying benefit status, percentage,
   official pension, source date, or the judicial-separation exception. The
   name `householdReady` overstates what is known.
6. There is no typed 2026 cash-flow object for ordinary pension, December
   supplement, December receipt, and annual total. `annualRente(monthly)` and
   its tests assume a stable 13-payment year
   (`avs_calculator.dart:215-233`), so they cannot represent a mid-year start,
   December ineligibility, or excluded components.
7. The B2 gate is intentionally always false. This prevents false output but is
   not a completed official-pension parser/source-date/grant architecture.

### P2 — important follow-through after the blockers

1. The registered-partnership enum affects tax, succession, survivor, debt,
   housing, and dossier paths beyond this AVS-only contract. The enum migration
   needs a repo-wide caller inventory; silently limiting it to the AVS screen
   would create cross-domain inconsistency.
2. The generic `partenariat` alias already has conflicting historical meaning.
   Migration analytics must count the quarantined records without logging raw
   financial or identity values.
3. Projection source strings are mostly free text. The final AVS output should
   carry structured legal references, legal year, official-source date, and
   confidence so the dossier and UI do not invent their own citations.

## 8. Implementation boundary and acceptance

Required order:

1. keep the B2 hard floor and tests green;
2. add registered-partnership and ambiguous-migration states, aliases, legal
   predicates, persistence, UI choice, and repo-wide status inventory;
3. separate self, household-sum, and marital-cap readiness;
4. introduce official person-owned pension/source-date facts and a default-off
   parser/kill switch;
5. replace the cap API with legal status, benefit entitlement/percentage,
   scale-aware inputs, and judicial-separation evidence;
6. quarantine the salary-duration splitting proxy and use official estimates or
   sufficiently complete account histories for evidence-backed results;
7. introduce typed ordinary-monthly and 13th-pension cash-flow outputs;
8. implement partner grant receipts, purpose/scope enforcement, revocation,
   race-safe invalidation, and the authorized ledger bridge;
9. migrate every Forecaster, RetirementProjection, CoupleOptimizer, coach,
   dashboard, dossier, and PDF consumer; remove or make unreachable any obsolete
   API that can still emit the old semantics;
10. prove RED → GREEN with section 6, full relevant tests, runtime manual-vs-
    optional-link degraded states, and bounded code plus product-domain audits.

Acceptance is blocked while any P0 or P1 remains. A fail-closed household path
may remain partial, but it must deliver the known person's individual view and
an equal-choice recovery path: manual authorized partner facts, optional scoped
account linking, or continue self-only.

## 9. Primary official sources and proposition map

| proposition | primary source | snapshot/effective state |
|---|---|---|
| splitting events, common insured years, exclusion of marriage start/end years | [LAVS art. 29quinquies, version 01.01.2026](https://www.fedlex.admin.ch/filestore/fedlex.data.admin.ch/eli/cc/63/837_843_843/20260101/fr/pdf-a/fedlex-data-admin-ch-eli-cc-63-837_843_843-20260101-fr-pdf-a.pdf) | in force 01.01.2026 |
| 13th pension entitlement, one-twelfth basis, December payment | [LAVS art. 34ter, version 01.01.2026](https://www.fedlex.admin.ch/filestore/fedlex.data.admin.ch/eli/cc/63/837_843_843/20260101/fr/pdf-a/fedlex-data-admin-ch-eli-cc-63-837_843_843-20260101-fr-pdf-a.pdf) | in force 01.01.2026 |
| cap trigger, court-ordered separate-household exception, proportional reduction | [LAVS art. 35, version 01.01.2026](https://www.fedlex.admin.ch/filestore/fedlex.data.admin.ch/eli/cc/63/837_843_843/20260101/fr/pdf-a/fedlex-data-admin-ch-eli-cc-63-837_843_843-20260101-fr-pdf-a.pdf) | in force 01.01.2026 |
| scale percentages, mandatory tables/rounding, incomplete-scale and pension-percentage cap rules | [RAVS arts. 52, 53, 53bis and 53ter, version 01.01.2026](https://www.fedlex.admin.ch/filestore/fedlex.data.admin.ch/eli/cc/63/1185_1183_1185/20260101/fr/pdf-a/fedlex-data-admin-ch-eli-cc-63-1185_1183_1185-20260101-fr-pdf-a.pdf) | in force 01.01.2026 |
| 2026 pension minima/maxima and full-scale couple maximum | [OFAS — Montants valables à partir du 1er janvier 2026](https://www.bsv.admin.ch/dam/bsv/fr/dokumente/ahv/uebersichten/renten-und-beitraege-20260101.pdf.download.pdf/renten-und-beitraege-20260101.pdf) | CHF 1'260 / 2'520 / 3'780; document 06.11.2025 |
| registered partnership AVS-equivalent to marriage; dissolution/death equivalences | [Centre d'information AVS/AI — Généralités](https://www.ahv-iv.ch/fr/assurances-sociales/assurance-vieillesse-et-survivants-avs/g%C3%A9n%C3%A9ralit%C3%A9s) | consulted 2026-07-13 |
| no new Swiss registered partnership after 01.07.2022; existing status remains; foreign recognition nuance | [OFJ — Mariage et « mariage pour tous » FAQ](https://www.bj.admin.ch/fr/faq-mariage-et-mariage-pour-tous) and [Directive OFEC 10.22.04.01](https://www.bj.admin.ch/dam/bj/fr/data/gesellschaft/zivilstand/weisungen/ws-ks-am/10-22-04-01.pdf.download.pdf/10-22-04-01-f.pdf) | FAQ consulted 2026-07-13; directive state 15.07.2025 |
| educational calculation, pension factors, cap, and splitting summary | [Centre d'information AVS/AI — Rentes de vieillesse](https://www.ahv-iv.ch/fr/Assurances-sociales/Assurance-vieillesse-et-survivants-AVS/Rentes-de-vieillesse) | consulted 2026-07-13 |
| 13th-pension payment implementation and excluded components | [OFAS — mise en œuvre de la 13e rente AVS](https://www.bsv.admin.ch/fr/misenoeuvre-13-rente-avs) | page published/updated 19.06.2026 |
| direct official future-pension estimate recovery | [Form 318.282 — Demande de calcul d'une rente future](https://www.ahv-iv.ch/p/318.282.f) | form state 01.01.2026 |
| purpose limitation, accuracy, valid consent, privacy by design/default, indirect-collection notice | [LPD arts. 6, 7 and 19, version 01.09.2023](https://www.fedlex.admin.ch/filestore/fedlex.data.admin.ch/eli/cc/2022/491/20230901/fr/pdf-a/fedlex-data-admin-ch-eli-cc-2022-491-20230901-fr-pdf-a-2.pdf) and [PFPDT — devoir d'informer](https://www.edoeb.admin.ch/fr/devoir-dinformer) | law in force 01.09.2023; PFPDT consulted 2026-07-13 |

### Standard educational disclaimer

> Les résultats présentés sont des estimations à titre indicatif, basées sur
> les données fournies et la législation en vigueur. Ils ne constituent pas un
> conseil financier personnalisé. Consultez un·e spécialiste pour votre
> situation spécifique.
