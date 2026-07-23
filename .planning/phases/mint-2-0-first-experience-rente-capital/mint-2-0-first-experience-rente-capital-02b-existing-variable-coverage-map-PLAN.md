# Mint 2.0 Existing Variable Coverage Map

Status: Proposed planning artifact. Product code is out of scope for this PR.
This file refines Slice 2 by reconciling existing variable libraries before any
runtime data dictionary is introduced.

Evidence: repo extraction on 2026-06-15 at
`99b0cb69caa09d0173538c515da84796c2f613b1`, branch
`codex/mint-2-slice-2-code-map-plan-20260614`. Claude CLI reviewed the
extraction in `claude -p` mode and recommended a coverage map before
implementation. Caveat: the artifact is a snapshot; future code changes must
rerun the extraction instead of editing counts by memory.

## Purpose

Prevent a second profile, variable, or constants library from being created
because an existing key was hard to find. This map binds the current surfaces:

- backend profile schemas;
- coach `save_fact` whitelist and extractor schema;
- mobile coach-to-wizard mapping;
- onboarding flush keys;
- `SecureWizardStore` sensitive-key coverage;
- regulatory backend registry and generated mobile snapshot;
- Dart `reg()` consumers.

This is not a runtime model and not a new source of truth. The future runtime
contract must be generated from or checked against the existing sources below.

## Extraction Summary

| Surface | Count | Notes |
|---|---:|---|
| `ProfileBase` fields | 39 | Backend read/base profile surface. |
| `ProfileUpdate` fields | 42 | Write/update surface; includes three fields absent from `ProfileBase`. |
| `_SAVE_FACT_ALLOWED_KEYS` | 35 | Coach-write whitelist in `coach_chat.py`. |
| extractor schema keys | 35 | Exact parity with `_SAVE_FACT_ALLOWED_KEYS` on this extraction. |
| `_mapFactKeyToAnswers` cases | 34 | Missing `wealthEstimate`. |
| mapped wizard outputs | 34 | Outputs `q_*` and `_coach_*` keys. |
| static secure wizard keys | 93 | Plus dynamic prefixes. |
| current onboarding flush keys | 16 | Emits a smaller, partially overlapping key set. |
| regulatory parameters total | 113 | Registry total, including historical variants. |
| regulatory parameters active | 103 | Active on 2026-06-15. |
| generated mobile snapshot | 103 | `effective_on=2026-06-12`. |
| Dart `reg()` keys outside generated/l10n | 45 | 26 names do not match backend registry keys. |

Regulatory hash:
`6eb0dcbd291cd0a175d0c6c22558cf609203f1966a5aaa07066e2c831599f98b`.
The generated mobile hash matches the backend active hash. The total count
differs because the backend registry also keeps historical variants.

## Existing Libraries To Reuse

| Existing source | Role for future dictionary |
|---|---|
| `services/backend/app/schemas/profile.py` | Backend profile field bounds and write/read asymmetries. |
| `services/backend/app/api/v1/endpoints/coach_chat.py` | Coach-write whitelist. |
| `services/backend/app/services/coach/extractor_schema.py` | LLM extraction schema that must stay paired with coach whitelist. |
| `apps/mobile/lib/providers/coach_profile_provider.dart` | Canonical save_fact-to-wizard mapping currently used on mobile. |
| `apps/mobile/lib/models/coach_profile.dart` | Mobile profile paths, data source, timestamp, and user-provided-field semantics. |
| `apps/mobile/lib/services/secure_wizard_store.dart` | Sensitive key policy and dynamic prefix coverage. |
| `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart` | Existing onboarding flush and legacy `onb_intent` behavior. |
| `services/backend/app/services/regulatory/registry.py` | Backend regulatory constants and `version_hash()`. |
| `apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart` | Generated mobile regulatory snapshot. |

## Save Fact Coverage

| save_fact key | Backend profile | Mobile wizard output | Coverage status |
|---|---|---|---|
| `birthYear` | `ProfileBase` | `q_birth_year` | Covered. |
| `dateOfBirth` | `ProfileBase` | `q_date_of_birth`, `q_birth_year` | Covered. |
| `canton` | `ProfileBase` | `q_canton` | Covered; secure-storage decision remains separate. |
| `commune` | `ProfileBase` | `q_commune` | Covered. |
| `householdType` | `ProfileBase` | `q_household_type` | Covered; must reconcile with `q_civil_status`. |
| `employmentStatus` | `ProfileBase` | `q_employment_status` | Covered. |
| `has2ndPillar` | `ProfileBase` | `q_has_pension_fund` | Covered; sensitive classification needs a decision. |
| `goal` | `ProfileBase` | `q_main_goal` | Covered through `_mapGoalFact`. |
| `targetRetirementAge` | `ProfileBase` | `q_target_retirement_age` | Covered; sensitive classification needs a decision. |
| `gender` | `ProfileBase` | `q_gender` | Covered. |
| `incomeNetMonthly` | `ProfileBase` | `q_net_income_period_chf`, `q_pay_frequency=monthly` | Covered. |
| `incomeGrossMonthly` | No `ProfileBase` field | `q_gross_salary_annual` derived as monthly x 12 | Backend surface gap. |
| `incomeNetYearly` | No `ProfileBase` field | `q_net_income_period_chf`, `q_pay_frequency=yearly` | Backend surface gap. |
| `incomeGrossYearly` | `ProfileBase` | `q_gross_salary_annual` | Covered. |
| `selfEmployedNetIncome` | `ProfileBase` | `q_self_employed_net_income_annual_chf`, derived monthly proxy keys | Covered, but secure-storage gap likely. |
| `employmentRate` | No `ProfileBase` field | `q_employment_rate` | Backend surface gap and secure-storage decision needed. |
| `annualBonus` | No `ProfileBase` field | `q_annual_bonus` | Backend surface gap. |
| `lppInsuredSalary` | `ProfileBase` | `_coach_salaire_assure` | Covered. |
| `avoirLpp` | `ProfileBase` | `_coach_avoir_lpp` | Covered. |
| `avoirLppObligatoire` | No `ProfileBase` field | `_coach_avoir_lpp_oblig` | Backend surface gap. |
| `avoirLppSurobligatoire` | No `ProfileBase` field | `_coach_avoir_lpp_suroblig` | Backend surface gap. |
| `lppBuybackMax` | `ProfileBase` | `_coach_rachat_maximum` | Covered. |
| `hasVoluntaryLpp` | `ProfileBase` | `q_has_pension_fund` only for independent employment | Covered with conditional mapping. |
| `pillar3aAnnual` | `ProfileBase` | `q_3a_annual_contribution`, conditional `q_has_3a` | Covered. |
| `pillar3aBalance` | `ProfileBase` | `q_3a_total` | Covered. |
| `savingsMonthly` | `ProfileBase` | `q_savings_monthly` | Covered. |
| `totalSavings` | `ProfileBase` | `q_cash_total` | Covered. |
| `wealthEstimate` | `ProfileBase` | none | Blocker: accepted by coach/extractor but not mapped locally. |
| `hasDebt` | `ProfileBase` | `q_has_consumer_debt` | Covered; sensitive classification needs a decision. |
| `totalDebt` | `ProfileBase` | `q_total_debt_balance_chf` | Covered. |
| `spouseBirthYear` | `ProfileBase` | `q_partner_birth_year` | Covered. |
| `spouseIncomeNetMonthly` | `ProfileBase` | `q_partner_net_income_chf` | Covered. |
| `spouseAvsContributionYears` | `ProfileBase` | `q_spouse_avs_contribution_years` | Covered by dynamic prefix, not static list. |
| `hasAvsGaps` | `ProfileBase` | `q_avs_lacunes_status` only when false | Partial mapping; positive/unknown states are not equivalent. |
| `avsContributionYears` | `ProfileBase` | `q_avs_contribution_years` | Covered. |

## Backend Surface Asymmetry

`ProfileUpdate` is the backend write surface and must not be ignored. The
future dictionary uses `ProfileBase` union `ProfileUpdate`, then marks read/write
asymmetry explicitly.

ProfileUpdate-only fields:

- `householdGrossIncome`;
- `spouseEmploymentStatus`;
- `spouseSalaryGrossAnnual`.

Coach-write keys with no `ProfileBase` home:

- `annualBonus`;
- `avoirLppObligatoire`;
- `avoirLppSurobligatoire`;
- `employmentRate`;
- `incomeGrossMonthly`;
- `incomeNetYearly`.

ProfileBase user-data fields not writable by coach:

- `isChurchMember`;
- `legalForm`;
- `nationality`;
- `primaryActivity`;
- `usTaxPerson`.

ProfileBase system/meta fields not writable by coach:

- `factfindCompletionIndex`;
- `fragileModeEnteredAt`;
- `n5IssuedThisWeek`;
- `recentGravityEvents`;
- `voiceCursorPreference`.

## Onboarding Reconciliation

Current onboarding flush emits:

`onb_intent`, `q_avs_arrival_year`, `q_avs_lacunes_status`,
`q_avs_years_abroad`, `q_birth_year`, `q_canton`, `q_civil_status`,
`q_date_of_birth`, `q_employment_status`, `q_has_pension_fund`,
`q_nationality`, `q_net_income_confidence`, `q_net_income_period_chf`,
`q_net_income_range_high`, `q_net_income_range_low`, `q_wants_deeper`.

Keys that need explicit reconciliation before onboarding v2:

| Key or pair | Risk |
|---|---|
| `onb_intent` vs planned `onb_axis_v2` | Legacy enum must not be silently overwritten. |
| `q_civil_status` vs `q_household_type` | Two representations can drift. |
| `q_nationality` vs backend `nationality` | Same user datum in two namespaces. |
| `q_net_income_range_low/high/confidence` vs `q_net_income_period_chf` | Range and confidence can be lost when collapsed to one value. |
| `q_avs_arrival_year` and `q_avs_years_abroad` | Mobile derives `arrivalAge`, but backend profile has no direct field. |
| `q_wants_deeper` | Product preference, not a financial input. |

## Secure Storage Coverage

Static sensitive keys count: 93.
Dynamic prefixes:
`_coach_depenses_`, `_coach_dettes_`, `_coach_conjoint_`, `_coach_avs_`,
`q_avs_`, `q_partner_`, `q_spouse_`, `_coach_tax_`.

Mapped wizard outputs not in the static sensitive set:

| Key | Prefix covered | Decision needed |
|---|---|---|
| `q_avs_lacunes_status` | yes, `q_avs_` | No code change in this planning PR. |
| `q_spouse_avs_contribution_years` | yes, `q_spouse_` | No code change in this planning PR. |
| `q_canton` | no | Decide whether canton remains non-sealed while commune is sealed. |
| `q_employment_rate` | no | Likely sensitive employment data; route to security review. |
| `q_has_3a` | no | Financial signal; route to security review. |
| `q_has_consumer_debt` | no | Financial signal; route to security review. |
| `q_has_pension_fund` | no | Pension signal; route to security review. |
| `q_main_goal` | no | Product preference; classify intentionally. |
| `q_net_income_period_source` | no | Derived metadata; classify intentionally. |
| `q_pay_frequency` | no | Income metadata; classify intentionally. |
| `q_self_employed_net_income_annual_chf` | no | Financial data; route to security review. |
| `q_target_retirement_age` | no | Life-planning datum; classify intentionally. |

## Regulatory Constant Coverage

Backend registry:

- total parameters: 113;
- active parameters on 2026-06-15: 103;
- categories: `ac`, `ai`, `apg`, `avs`, `capital_tax`, `lamal`, `lpp`,
  `mortgage`, `pillar3a`;
- active hash:
  `6eb0dcbd291cd0a175d0c6c22558cf609203f1966a5aaa07066e2c831599f98b`.

Generated mobile snapshot:

- effective on: 2026-06-12;
- param count: 103;
- same active hash as backend.

Dart `reg()` key names without exact backend registry key match:

| Dart key | Required disposition |
|---|---|
| `ac.employee_rate` | Candidate alias; bind or rename to registry key. |
| `ac.enhanced_rate_threshold` | Backfill or documented Dart-only default. |
| `ac.days_18_months` | Backfill or documented Dart-only default. |
| `ac.max_monthly_insured_income` | Backfill or documented Dart-only default. |
| `ac.days_12_months` | Backfill or documented Dart-only default. |
| `ac.salary_ceiling` | Candidate alias; bind or rename to registry key. |
| `ac.senior_age_threshold` | Backfill or documented Dart-only default. |
| `ac.days_22_months_senior` | Backfill or documented Dart-only default. |
| `ac.solidarity_rate` | Candidate alias; bind or rename to registry key. |
| `avs.early_retirement_reduction` | Candidate alias for `avs.anticipation_reduction`; confirm. |
| `avs.employee_rate` | Candidate alias for `avs.contribution_rate_employee`; confirm. |
| `avs.max_annual_pension_${year >= avs13emeRenteAnneeDebut ? "13m" : "12m"}` | Unbindable as static key; replace with deterministic names before linting. |
| `avs.min_self_employed_contribution` | Candidate alias for `avs.min_contribution_independent`; confirm. |
| `avs.total_rate` | Candidate alias for `avs.contribution_rate_total`; confirm. |
| `avs.voluntary_max` | Candidate alias for `avs.voluntary_contribution_max`; confirm. |
| `avs.voluntary_min` | Candidate alias for `avs.voluntary_contribution_min`; confirm. |
| `lpp.conversion_rate_min` | Candidate alias for `lpp.conversion_rate`; confirm. |
| `lpp.conversion_rate_suroblig` | Backfill or documented Dart-only assumption. |
| `mortgage.accessory_rate` | Candidate alias for `mortgage.maintenance_rate`; confirm. |
| `mortgage.max_2nd_pillar_ratio` | Candidate alias for `mortgage.max_2nd_pillar`; confirm. |
| `mortgage.min_equity_ratio` | Candidate alias for `mortgage.min_equity`; confirm. |
| `mortgage.total_charges_rate` | Composite assumption; cannot alias to one key without formula. |
| `projection.avs_indexation_rate` | Projection assumption; needs provenance/version strategy. |
| `projection.inflation_rate` | Projection assumption; needs provenance/version strategy. |
| `projection.life_expectancy` | Projection assumption; needs provenance/version strategy. |
| `projection.safe_withdrawal_rate` | Projection assumption; needs provenance/version strategy. |

## Coupled Invariants

These pairs must move together:

| Pair | Current extraction | Future check |
|---|---|---|
| `_SAVE_FACT_ALLOWED_KEYS` and extractor schema Literal | 35 / 35 exact parity | Existing parity test plus dictionary lint. |
| `_SAVE_FACT_ALLOWED_KEYS` and `_mapFactKeyToAnswers` | 35 / 34, missing `wealthEstimate` | New lint before onboarding v2. |
| `ProfileBase` and `ProfileUpdate` | 39 / 42, three update-only fields | Dictionary must model union with read/write flags. |
| backend regulatory active hash and generated mobile hash | same hash, 103 active params | Existing codegen check plus runtime receipt hash. |
| Dart `reg()` keys and backend registry names | 26 exact-name misses | Alias/backfill lint before financial UI changes. |
| wizard financial keys and secure storage | at least five security decisions | Security review before collection expansion. |

## Implementation Blockers

1. Close or explicitly de-scope `wealthEstimate` in the mobile mapping.
2. Decide whether no-ProfileBase fact keys become backend fields, derived
   wizard-only facts, or deprecated coach outputs.
3. Decide which ProfileBase user-data gaps the coach may write:
   `usTaxPerson`, `nationality`, `isChurchMember`, `legalForm`,
   `primaryActivity`.
4. Reconcile `q_civil_status` with `q_household_type`.
5. Reconcile income range/confidence keys with the single effective income
   value used by older profile flows.
6. Classify mapped wizard outputs outside secure storage static coverage.
7. Bind, alias, backfill, or de-scope all 26 Dart `reg()` names without exact
   backend registry key match.
8. Replace runtime-interpolated regulatory key names with deterministic keys
   before any static lint claims full coverage.

## Future Artifact Shape

The first runtime dictionary should be a scaffold generated from or checked
against these sources. Required columns:

- `canonical_id`;
- backend `ProfileBase` field;
- backend `ProfileUpdate` field;
- `save_fact` key;
- extractor key;
- mobile wizard key or keys;
- `CoachProfile` path;
- secure storage status;
- source and source version;
- per-axis readiness role;
- alias/deprecated status;
- collection permission by axis.

The runtime dictionary must not become a new calculator, a new constants store,
or a replacement for `CoachProfile`. It is a binding and lint target.
