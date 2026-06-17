# Mint 2.0 Data Dictionary And Progressive Profile Plan

Status: Proposed planning artifact. Product code is out of scope for this PR.
This file refines Slice 2 before onboarding/profile implementation.

Evidence: repo inspection on 2026-06-15 read `docs/data-flow.md`,
`docs/calculator-graph.md`, `SOT.md`, `services/backend/app/schemas/profile.py`,
`services/backend/app/services/regulatory/registry.py`,
`apps/mobile/lib/models/coach_profile.dart`,
`apps/mobile/lib/providers/coach_profile_provider.dart`,
`apps/mobile/lib/services/secure_wizard_store.dart`, and
`apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart`.
Claude CLI review completed in read-only mode and returned the same core
finding: Mint already has the data, but lacks a single dictionary that binds
backend keys, wizard keys, profile fields, aliases, source, and readiness.
Caveat: this plan creates no runtime dictionary, no migration, and no UI.

## Objective

Define the variable contract Mint 2.0 needs before rewriting first experience
onboarding. The goal is an exhaustive catalogue for Swiss user data and
regulatory constants, paired with a minimal progressive profile flow that asks
only what the next user-visible answer needs.

## Binding Principle

Cataloguing can be exhaustive. Collection must be progressive.

Every future variable entry must declare:

- `canonical_id`: stable snake_case concept id, independent of language.
- `type`: money_chf, ratio, percent, year, date, enum, boolean, string, object.
- `unit`: CHF, ratio, percent, years, months, date, enum, none.
- `pii`: whether it must be sealed by `SecureWizardStore`.
- `bindings`: backend Pydantic, save_fact key, wizard key, CoachProfile path.
- `aliases_deprecated`: tolerated legacy keys that must not become writers.
- `source`: user_input, document_scan, backend, open_banking, derived, constant.
- `source_version`: calculation version or regulatory registry version/hash.
- `freshness`: timestamp field or expiry rule.
- `readiness`: per axis, not global.
- `forbidden_collection`: axes where the field must not be asked yet.

## Canonical Variable Groups

| Group | Canonical variables | Existing anchors |
|---|---|---|
| Identity | `birth_date`, `birth_year`, `age`, `gender`, `nationality`, `us_tax_person`, `residence_permit`, `arrival_age` | `q_date_of_birth`, `q_birth_year`, `q_gender`, `q_nationality`, `q_us_tax_person`, `q_residence_permit`; backend `birthYear`, `dateOfBirth`, `gender`, `nationality`, `usTaxPerson` |
| Residence | `canton`, `commune`, `tax_residence_context` | `q_canton`, `q_commune`; backend `canton`, `commune`; capital-tax constants by canton |
| Household | `civil_status`, `household_type`, `children_count`, spouse birth/income/AVS fields | `q_civil_status`, `q_household_type`, `q_children`, `q_partner_*`, `q_spouse_*`; backend `householdType`, `spouseBirthYear`, `spouseIncomeNetMonthly`, `spouseAvsContributionYears` |
| Employment | `employment_status`, `has_second_pillar`, `legal_form`, `primary_activity`, `employment_rate`, `annual_bonus` | `q_employment_status`, `q_has_pension_fund`, `q_employment_rate`, `q_annual_bonus`; backend `employmentStatus`, `has2ndPillar`, `legalForm`, `primaryActivity` |
| Income | `income_net_monthly`, `income_gross_yearly`, `self_employed_net_income_yearly`, `pay_frequency`, `income_range_low`, `income_range_high` | `q_net_income_period_chf`, `q_pay_frequency`, `q_gross_salary_annual`, `q_self_employed_net_income_annual_chf`, `q_net_income_range_low`, `q_net_income_range_high`; backend `incomeNetMonthly`, `incomeGrossYearly`, `selfEmployedNetIncome` |
| Budget | `housing_cost_monthly`, `lamal_premium_monthly`, `tax_provision_monthly`, `other_fixed_costs_monthly`, transport/telecom/electricity/medical/other fixed costs | `q_housing_cost_period_chf`, `q_lamal_premium_monthly_chf`, `q_tax_provision_monthly_chf`, `q_other_fixed_costs_monthly_chf`, `_coach_depenses_*` |
| Wealth | `cash_total`, `investments_total`, `property_market_value`, `mortgage_balance`, `mortgage_rate`, `monthly_rent` | `q_cash_total`, `q_investments_total`, `q_property_market_value`, `q_mortgage_balance`, `q_mortgage_rate`, `q_monthly_rent`; backend `totalSavings`, `wealthEstimate` |
| Debt | `has_consumer_debt`, `debt_balance_total`, `debt_payments_monthly`, mortgage/credit/leasing/other debt buckets | `q_has_consumer_debt`, `q_total_debt_balance_chf`, `q_debt_payments_period_chf`, `_coach_dettes_*`; backend `hasDebt`, `totalDebt` |
| AVS | `avs_contribution_years`, `avs_gaps_status`, `avs_years_abroad`, `avs_arrival_year`, `avs_ramd`, `avs_estimated_monthly` | `q_avs_contribution_years`, `q_avs_lacunes_status`, `q_avs_years_abroad`, `q_avs_arrival_year`, `_coach_avs_*`; backend `hasAvsGaps`, `avsContributionYears` |
| LPP | `lpp_avoir_total`, `lpp_avoir_obligatory`, `lpp_avoir_extra`, `lpp_insured_salary`, `lpp_buyback_max`, `lpp_conversion_rate`, `lpp_conversion_rate_extra`, `lpp_fund_return`, `lpp_projected_pension`, `lpp_projected_capital` | `_coach_avoir_lpp*`, `_coach_salaire_assure`, `_coach_rachat_maximum`, `_coach_taux_conversion*`, `_coach_rendement_caisse`; backend `avoirLpp*`, `lppInsuredSalary`, `lppBuybackMax` |
| 3a | `pillar3a_balance`, `pillar3a_annual_contribution`, `pillar3a_accounts_count`, `pillar3a_providers` | `q_3a_total`, `q_3a_annual_contribution`, `q_3a_accounts_count`, `q_3a_providers`; backend `pillar3aBalance`, `pillar3aAnnual` |
| Fiscal | `taxable_income`, `taxable_wealth`, `cantonal_tax`, `federal_tax`, `marginal_tax_rate`, `church_member` | `_coach_tax_*`; backend `isChurchMember`, `wealthEstimate`; fiscal signal axis cannot show a tax amount in this phase |
| Goals and lifecycle | `selected_axis`, `onb_axis_v2`, `onb_axis_schema_version`, `legacy_onb_intent`, `main_goal`, `primary_focus`, `target_retirement_age`, `saved_interest_axes` | planned `onb_axis_v2`; existing `onb_intent`, `q_main_goal`, `q_primary_focus`, `q_target_retirement_age` |
| Provenance and readiness | `data_source`, `data_timestamp`, `confidence`, `known_fields`, `missing_required_fields`, `missing_optional_fields`, `calculation_origin`, `calculation_version`, `constant_version` | `ProfileDataSource`, `dataSources`, `dataTimestamps`, `_coach_data_timestamps`, RvC receipt requirements |

## Canonical Bindings For Critical Fields

| Canonical id | Backend | save_fact | Wizard canonical | CoachProfile | Deprecated aliases |
|---|---|---|---|---|---|
| `birth_year` | `birthYear` | `birthYear` | `q_birth_year` | `birthYear` | none |
| `birth_date` | `dateOfBirth` | `dateOfBirth` | `q_date_of_birth` | `dateOfBirth` | none |
| `canton` | `canton` | `canton` | `q_canton` | `canton` | none |
| `household_type` | `householdType` | `householdType` | `q_household_type` | derived with `q_civil_status` | old single/couple residues |
| `civil_status` | none | none | `q_civil_status` | `etatCivil` | `q_civil_status_choice` |
| `income_net_monthly` | `incomeNetMonthly` | `incomeNetMonthly` | `q_net_income_period_chf` + `q_pay_frequency=monthly` | `explicitMonthlyNetIncome` | `q_net_income_monthly`, `q_income_net_monthly`, `q_salaire` |
| `income_gross_yearly` | `incomeGrossYearly` | `incomeGrossYearly` | `q_gross_salary_annual` | `revenuBrutAnnuel` | `q_gross_salary`, `q_gross_income`, `q_monthly_gross_salary_chf` |
| `self_employed_net_income_yearly` | `selfEmployedNetIncome` | `selfEmployedNetIncome` | `q_self_employed_net_income_annual_chf` | `independentNetProfessionalIncomeAnnual` | none |
| `lpp_avoir_total` | `avoirLpp` | `avoirLpp` | `_coach_avoir_lpp` | `prevoyance.avoirLppTotal` | `q_avoir_lpp`, `q_lpp_avoir`, `q_lpp_current_capital` |
| `lpp_insured_salary` | `lppInsuredSalary` | `lppInsuredSalary` | `_coach_salaire_assure` | `prevoyance.salaireAssure` | none |
| `lpp_buyback_max` | `lppBuybackMax` | `lppBuybackMax` | `_coach_rachat_maximum` | `prevoyance.rachatMaximum` | `q_lpp_buyback_available` as read alias |
| `pillar3a_balance` | `pillar3aBalance` | `pillar3aBalance` | `q_3a_total` | `prevoyance.totalEpargne3a` | `q_total_3a`, `q_3a_capital` |
| `pillar3a_annual_contribution` | `pillar3aAnnual` | `pillar3aAnnual` | `q_3a_annual_contribution` | planned contribution source | `q_3a_annual_amount` |
| `debt_balance_total` | `totalDebt` | `totalDebt` | `q_total_debt_balance_chf` | `dettes.totalDettes` | `q_dettes_total` |
| `debt_payments_monthly` | none | none | `q_debt_payments_period_chf` | `dettes.mensualiteConsommation` | must not be converted to capital |

## Versioned Constants And Assumptions

The regulatory registry remains the constant source of truth. Future receipts
must cite the relevant keys and registry version/hash.

| Category | Registry examples | Used by |
|---|---|---|
| 3a | `pillar3a.max_with_lpp`, `pillar3a.max_without_lpp`, historical limits | 3a room, fiscal signal, self-employed ceiling |
| LPP | `lpp.entry_threshold`, `lpp.coordination_deduction`, `lpp.conversion_rate`, age bonifications, EPL keys | LPP eligibility, RvC, logement signal |
| AVS | pension min/max, contribution rates, full years, reference ages, deferral/anticipation | AVS readiness, family/career future slices |
| Mortgage | theoretical rate, amortization, maintenance, max charge ratio, equity | logement signal only in this phase |
| Capital tax | `capital_tax.default_rate`, brackets, `capital_tax.cantonal.*`, married discount | RvC receipt and fiscal signal |

Constants or assumptions currently outside the registry must be tracked before
new onboarding code depends on them: net-to-gross factors in
`income_converter.dart`, Dart default `rendementCaisse`, default 3a return
assumptions, and backend `MAX_PILLAR3A_ANNUAL`.

## Progressive Onboarding Contract

The first experience asks the smallest set that can create a useful dossier.
It does not ask for detailed logement, fiscal, debt, spouse, or full budget data
until a live answer needs them.

| Step | Field | Why now | Axis status |
|---|---|---|---|
| 1 | `selected_axis` / `onb_axis_v2` | route the dossier to live or signal axis | required |
| 2 | `birth_date` or `birth_year` | age-dependent LPP/AVS/RvC readiness | required for live RvC |
| 3 | `canton` | capital-tax and Swiss context | required for live RvC |
| 4 | `us_tax_person` | hard gate before financial collection | required gate |
| 5 | `employment_status` and `has_second_pillar` | distinguish employee, independent, retired, no-LPP | required for profile |
| 6 | `civil_status` / `household_type` | capital-tax split and spouse-field invariants | required before personalized value |
| 7 | `lpp_avoir_total` or certificate scan | core RvC input | required for amount |
| 8 | `lpp_conversion_rate` / `lpp_insured_salary` / `lpp_buyback_max` | improve receipt when certificate has them | optional unless result needs them |
| 9 | `target_retirement_age` | user scenario parameter | optional |

Logement and fiscal axes may save `selected_axis` and notification/follow-up
interest. They must not ask for mortgage amount, property value, taxable income,
taxable wealth, or detailed deductions in this phase.

## Readiness Model

Replace global completion claims with per-axis readiness:

- `blocked`: a required field is absent or provenance is insufficient.
- `partial`: enough for education or missing-fields response, not enough for a
  value.
- `complete`: a value may be shown only with receipt.

For `lpp_rente_capital`, a displayed value requires:

- user data: birth year/date, canton, employment context, civil/household
  context, LPP amount or certificate-derived equivalent;
- provenance: source and timestamp for each used field;
- version: calculation version and regulatory registry version/hash;
- receipt: assumptions, sources, readiness, missing fields, origin.

## Future Lints Before Product Code

Add mechanical checks before moving this contract into runtime:

- every `_SAVE_FACT_ALLOWED_KEYS` entry has a data-dictionary binding or is
  explicitly marked out of scope;
- every `pii: true` variable maps to `SecureWizardStore.isSensitive`;
- every deprecated alias is read-only or has a migration rule;
- every variable used by an active calculation has per-axis readiness;
- every value shown in a receipt cites calculation origin, calculation version,
  constant version, assumptions, sources, and missing fields;
- no signal axis has required fields beyond `selected_axis` and follow-up
  preference.

## Implementation Precedence

This file does not rename the existing Slice 2A implementation label. Slice 2A
remains the calculator-boundary decision and receipt work from the code-map
plan. This data dictionary precondition must be applied before Slice 2B onward,
and any Slice 2A receipt fields must use these canonical ids when they touch
profile/readiness terminology.

1. Slice 2A stays focused on calculator boundary and RvC receipt origin/version.
2. Before Slice 2B axis persistence, add a runtime dictionary scaffold under a
   neutral location chosen in a separate implementation plan.
3. Add parity lint for backend save_fact, Dart mapping, secure keys, and
   CoachProfile paths.
4. Derive progressive profile readiness from the dictionary.
5. Wire onboarding v2 axis persistence and minimal live RvC collection.
6. Wire RvC receipt gate to dictionary readiness and registry version.
7. Capture Maestro proof from clear state; iPhone 13 mini remains mandatory for
   first entry layout.

## Open Blockers

- Decide whether the runtime dictionary belongs under `.planning` first,
  `docs/data`, or a generated shared contract directory.
- Decide how to handle old aliases with real persisted user state.
- Decide whether `factfindCompletionIndex` stays as a legacy scalar or becomes
  a derived view from per-axis readiness.
- Decide how to expose regulatory `version_hash()` in mobile receipts without
  creating a second constant source.
