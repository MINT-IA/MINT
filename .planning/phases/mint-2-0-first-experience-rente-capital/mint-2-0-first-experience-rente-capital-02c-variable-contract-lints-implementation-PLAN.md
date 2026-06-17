# Mint 2.0 Variable Contract Lints Implementation Plan

Status: Proposed planning artifact. Product code is out of scope for this PR.
This file proposes the implementation order for resolving the variable-contract
blockers found by 02b before any runtime dictionary scaffold is introduced.

Evidence: read-only extraction rerun on 2026-06-15 from
`99b0cb69caa09d0173538c515da84796c2f613b1`, branch
`codex/mint-2-slice-2-code-map-plan-20260614`, using AST for Python schemas and
targeted regex for Dart bindings. Commands used:

```bash
python3 - <<'PY'
# AST: ProfileBase/ProfileUpdate, _SAVE_FACT_ALLOWED_KEYS, _ALLOWED_FACT_KEYS.
# Regex: _mapFactKeyToAnswers cases/outputs, SecureWizardStore keys/prefixes,
# completeAndFlushToProfile outputs, Dart reg('...') consumers.
# Import: RegulatoryRegistry.instance() for count(), active params, version_hash().
PY
```

Caveat: this plan creates no runtime dictionary, no linter, no code migration,
and no user-facing flow. Future implementation must rerun the extraction from
the then-current repo instead of copying these counts by memory.

## Objective

Prepare a small-PR implementation sequence that resolves the current variable
coverage blockers without creating a second profile library, a second constants
library, or a second calculation layer.

The future runtime dictionary is only a binding and lint target above existing
sources. It must not become a new source of truth for:

- backend profile fields;
- coach extractor keys;
- regulatory constants;
- `CoachProfile` semantics;
- any financial calculation.

## Reuse-Over-Create Gate

Every future PR in this chain must reuse the existing sources below.

| Existing source | Required use |
|---|---|
| `services/backend/app/schemas/profile.py` | Backend profile read/write field bounds and asymmetry. |
| `services/backend/app/api/v1/endpoints/coach_chat.py` | `_SAVE_FACT_ALLOWED_KEYS` coach-write whitelist. |
| `services/backend/app/services/coach/extractor_schema.py` | Literal extractor key contract. |
| `apps/mobile/lib/providers/coach_profile_provider.dart` | Existing save_fact-to-wizard mapping. |
| `apps/mobile/lib/models/coach_profile.dart` | Existing mobile profile derivation and provenance fields. |
| `apps/mobile/lib/services/secure_wizard_store.dart` | Existing sensitive-key policy and dynamic prefixes. |
| `services/backend/app/services/regulatory/registry.py` | Regulatory constants and `version_hash()`. |
| `apps/mobile/lib/services/financial_core/` | L1 mobile calculation home. |
| `services/backend/app/services/` | L2-L4 backend calculation home. |

Acceptance gate: a PR that adds a standalone variable/constants/calculator
library instead of binding these sources is out of scope for this chain.

## Calculation Boundary

The variable contract must respect the existing L1/L2-L4 boundary:

- L1 single-number deterministic calculations remain under
  `apps/mobile/lib/services/financial_core/`.
- L2-L4 compare, explain, and invariant calculations remain under
  `services/backend/app/services/`.
- The discriminator criterion is
  `services/backend/app/models/lucidity/_payload.py`: `L1ChiffrePayload`
  belongs to the mobile L1 path; `L2ComparePayload`, `L3EclairePayload`, and
  `L4InvariantPayload` belong to backend-canonical paths.

The runtime dictionary is a binding/lint layer above those homes. It must never
re-implement `_calculate*()` or `_compute*()` logic.

## Extraction Rerun Snapshot

The 02c rerun matches the 02b snapshot on the blocker counts.

| Surface | Rerun result |
|---|---:|
| `ProfileBase` fields | 39 |
| `ProfileUpdate` fields | 42 |
| `ProfileUpdate`-only fields | 3: `householdGrossIncome`, `spouseEmploymentStatus`, `spouseSalaryGrossAnnual` |
| `_SAVE_FACT_ALLOWED_KEYS` | 35 |
| extractor `_ALLOWED_FACT_KEYS` | 35 |
| `_SAVE_FACT_ALLOWED_KEYS` minus extractor | 0 |
| extractor minus `_SAVE_FACT_ALLOWED_KEYS` | 0 |
| `_mapFactKeyToAnswers` cases | 34 |
| save_fact keys without Dart mapping | 1: `wealthEstimate` |
| mapped wizard outputs | 34 |
| `SecureWizardStore` static sensitive keys | 93 |
| `SecureWizardStore` dynamic prefixes | 8 |
| onboarding flush keys | 16 |
| backend regulatory parameters total | 113 |
| backend regulatory parameters active on 2026-06-15 | 103 |
| generated Dart snapshot count | 103 |
| generated Dart snapshot effective_on | 2026-06-12 |
| backend/Dart active hash | `6eb0dcbd291cd0a175d0c6c22558cf609203f1966a5aaa07066e2c831599f98b` |
| Dart `reg()` unique keys outside l10n/generated | 45 |
| Dart `reg()` keys without exact backend registry match | 26 |

The one failed extraction attempt during this session used the wrong internal
registry attribute (`_parameters`). The corrected rerun uses
`RegulatoryRegistry.instance().get_all()`.

Additional rerun lists used below:

- save_fact keys with no `ProfileBase` field:
  `annualBonus`, `avoirLppObligatoire`, `avoirLppSurobligatoire`,
  `employmentRate`, `incomeGrossMonthly`, `incomeNetYearly`;
- `ProfileBase` user-data fields not writable by coach:
  `isChurchMember`, `legalForm`, `nationality`, `primaryActivity`,
  `usTaxPerson`;
- mapped wizard outputs not covered by the static sensitive set or dynamic
  prefixes:
  `q_canton`, `q_employment_rate`, `q_has_3a`,
  `q_has_consumer_debt`, `q_has_pension_fund`, `q_main_goal`,
  `q_net_income_period_source`, `q_pay_frequency`,
  `q_self_employed_net_income_annual_chf`, `q_target_retirement_age`.

## Required Decisions Before Runtime Scaffold

These decisions are proposed gates, not decisions already taken.

| Blocker | Proposed disposition gate |
|---|---|
| `wealthEstimate` accepted by backend/extractor but not mapped on mobile | Future PR must either add an intentionally named non-cash wizard key, keep it backend-only, or remove it from coach-write scope. It must not map to `q_cash_total`. |
| `ProfileBase` / `ProfileUpdate` / `save_fact` asymmetry | Future contract must model read/write flags, not flatten everything into one writable dictionary. |
| `q_civil_status` vs `q_household_type` | Future PR must choose one canonical writer and one derived/alias path, with migration tests. |
| `q_nationality` vs backend `nationality` | Future PR must bind the wedge key to the backend field or explicitly keep it local-only until account handoff. |
| income range/confidence vs single income value | Future PR must preserve range/confidence metadata and define the effective value derivation rule. |
| SecureWizardStore coverage gaps | Future PR must classify uncovered keys as sensitive, non-sensitive, or product preference before collection expands. |
| Dart `reg()` exact-name misses | Future PRs must alias, rename, backfill registry entries, or de-scope each miss before static lint claims coverage. |
| Runtime-interpolated `reg()` key | Future PR must replace the interpolated AVS annual-pension key with deterministic keys before a static lint can enforce full coverage. |

## Future PR Sequence

### PR 1 — Freeze Extraction Fixtures And Drift Tests

Goal: create read-only tests that reproduce the extraction mechanically before
changing behavior.

Probable files:

- `tools/checks/mint_variable_contract_extract.py`
- `tools/checks/tests/test_mint_variable_contract_extract.py`
- optional JSON fixture under `tools/checks/fixtures/`

Expected tests:

```bash
python3 -m pytest tools/checks/tests/test_mint_variable_contract_extract.py -q
python3 tools/checks/mint_variable_contract_extract.py --check
```

Acceptance gates:

- AST extracts `ProfileBase`, `ProfileUpdate`, `_SAVE_FACT_ALLOWED_KEYS`, and
  `_ALLOWED_FACT_KEYS`.
- Regex extraction covers `_mapFactKeyToAnswers`, `SecureWizardStore`, onboarding
  flush keys, and Dart `reg()` keys.
- The fixture reports `wealthEstimate` as the only save_fact key without a Dart
  mapping on this repo snapshot.
- The tool reports registry count/hash from `RegulatoryRegistry`, not from a
  duplicated constants table.
- The tool marks interpolated `reg()` names, currently
  `avs.max_annual_pension_${year >= avs13emeRenteAnneeDebut ? "13m" : "12m"}`,
  as non-statically-coverable until replaced with deterministic keys.

### PR 2 — `wealthEstimate` Disposition

Goal: resolve the only current save_fact-to-mobile mapping miss.

Probable files:

- `apps/mobile/lib/providers/coach_profile_provider.dart`
- `apps/mobile/test/providers/coach_profile_provider*_test.dart`
- `services/backend/tests/test_extractor_schema.py` only if backend scope changes

Allowed outcomes:

- Add a non-cash wizard key such as `q_wealth_estimate_chf` with provenance and
  secure-storage classification.
- Keep `wealthEstimate` backend-only and add a fail-loud client lint.
- Remove or de-scope `wealthEstimate` from coach-write scope with extractor
  parity tests.

Rejected outcome:

- Mapping `wealthEstimate` to `q_cash_total`, because total wealth is not liquid
  cash.

Acceptance gates:

- A test proves the chosen disposition.
- No silent drop remains for save_fact payloads.
- No UI financial number is introduced by this PR.

### PR 3 — Backend Profile Union And Write-Scope Contract

Goal: reconcile `ProfileBase`, `ProfileUpdate`, and `save_fact` without making
all fields writable.

Probable files:

- `tools/checks/mint_variable_contract_extract.py`
- `tools/checks/tests/test_mint_variable_contract_extract.py`
- planning or generated fixture only if needed by the checker

Expected checks:

- `ProfileUpdate`-only fields stay visible:
  `householdGrossIncome`, `spouseEmploymentStatus`, `spouseSalaryGrossAnnual`.
- save_fact keys absent from `ProfileBase` are classified:
  `annualBonus`, `avoirLppObligatoire`, `avoirLppSurobligatoire`,
  `employmentRate`, `incomeGrossMonthly`, `incomeNetYearly`.
- `ProfileBase` user-data fields not writable by coach are classified:
  `isChurchMember`, `legalForm`, `nationality`, `primaryActivity`,
  `usTaxPerson`.

Acceptance gate:

- The contract can express `read_only`, `write_only`, `coach_writable`,
  `derived_mobile`, and `out_of_scope` without changing product behavior.

### PR 4 — Onboarding Key Reconciliation Contract

Goal: reconcile wedge/onboarding outputs with canonical fields before onboarding
v2 expands.

Probable files:

- `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart`
- `apps/mobile/test/screens/onboarding/mvp_wedge/*`
- `apps/mobile/test/providers/*` if profile hydration is asserted

Required pairs:

- `onb_intent` vs future `onb_axis_v2`;
- `q_civil_status` vs `q_household_type`;
- `q_nationality` vs backend `nationality`;
- `q_net_income_range_low`, `q_net_income_range_high`,
  `q_net_income_confidence`, and `q_net_income_period_chf`;
- `q_avs_arrival_year` / `q_avs_years_abroad` vs derived `arrivalAge`;
- `q_wants_deeper` as product preference, not financial input.

Expected tests:

- range/confidence survives profile flush and reload;
- civil status either derives household type or remains explicitly local, with
  no two-writer drift;
- nationality is not coerced to `CH` when absent;
- legacy `onb_intent` is not silently overwritten by `onb_axis_v2`.

### PR 5 — SecureWizardStore Classification

Goal: classify all mapped wizard outputs outside static secure coverage.

Probable files:

- `apps/mobile/lib/services/secure_wizard_store.dart`
- `apps/mobile/test/services/secure_wizard_store*_test.dart`
- `tools/checks/mint_variable_contract_extract.py`

Current uncovered by static set and dynamic prefixes:

- `q_canton`;
- `q_employment_rate`;
- `q_has_3a`;
- `q_has_consumer_debt`;
- `q_has_pension_fund`;
- `q_main_goal`;
- `q_net_income_period_source`;
- `q_pay_frequency`;
- `q_self_employed_net_income_annual_chf`;
- `q_target_retirement_age`.

Acceptance gates:

- Every key is classified as sensitive, non-sensitive, or product preference.
- Financial/life-planning facts are not demoted to plain SharedPreferences by
  accident.
- Dynamic-prefix behavior stays covered for `q_avs_`, `q_partner_`,
  `q_spouse_`, `_coach_tax_`, `_coach_depenses_`, `_coach_dettes_`,
  `_coach_conjoint_`, `_coach_avs_`.

### PR 6 — Regulatory Registry Alias And Backfill Plan

Goal: bind or de-scope every Dart `reg()` key without exact backend registry
match.

Probable files:

- `services/backend/app/services/regulatory/registry.py`
- `tools/codegen/regulatory_constants_to_dart.py` if generated output changes
- `apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart`
- tests around registry/codegen/checker

Current exact-name misses:

```text
ac.employee_rate
ac.enhanced_rate_threshold
ac.intermediate_days
ac.max_monthly_insured_income
ac.min_days
ac.salary_ceiling
ac.senior_age_threshold
ac.senior_days
ac.solidarity_rate
avs.early_retirement_reduction
avs.employee_rate
avs.max_annual_pension_${year >= avs13emeRenteAnneeDebut ? "13m" : "12m"}
avs.min_self_employed_contribution
avs.total_rate
avs.voluntary_max
avs.voluntary_min
lpp.conversion_rate_min
lpp.conversion_rate_suroblig
mortgage.accessory_rate
mortgage.max_2nd_pillar_ratio
mortgage.min_equity_ratio
mortgage.total_charges_rate
projection.avs_indexation_rate
projection.inflation_rate
projection.life_expectancy
projection.safe_withdrawal_rate
```

Disposition classes:

- alias to an existing backend key;
- add missing registry parameter with source, unit, effective date, and review
  metadata;
- replace a composite Dart assumption with deterministic component keys;
- de-scope from static lint until the owning calculator has its own phase.

Acceptance gates:

- generated Dart snapshot still comes from backend registry codegen;
- active registry hash is surfaced in receipts without a second constants store;
- logement and fiscal axes remain signalétique in this phase and do not become
  calculators because a constant was bound.

### PR 7 — Runtime Dictionary Scaffold And Lints

Goal: only after PRs 1-6, add the first runtime binding scaffold and mechanical
lints.

Probable files:

- `tools/checks/mint_variable_dictionary_lint.py`
- generated or checked contract fixture under a repo-approved location;
- tests under `tools/checks/tests/`.

Required columns:

- canonical id, defined only as a non-authoritative join key derived from
  existing source keys;
- backend `ProfileBase` field;
- backend `ProfileUpdate` field;
- save_fact key;
- extractor key;
- mobile wizard key(s);
- `CoachProfile` path;
- secure storage status;
- source and source version;
- per-axis readiness role;
- alias/deprecated status;
- collection permission by axis.

Acceptance gates:

- the scaffold imports/checks existing sources; it does not own the truth;
- every save_fact key has binding/disposition;
- every sensitive key has classification;
- every active calculation variable names its L1 or L2-L4 owner;
- no signalétique axis requires detailed unused fields;
- no future UI financial value can pass without provenance, assumptions,
  sources, readiness/confidence, missing fields, and calculation or constants
  version.
- the lint fails if any non-statically-coverable `reg()` key remains after the
  PR 6 disposition pass.

## Future Runtime Proof Gates

These gates belong to later implementation PRs, not this planning-only change.

- Feature flag or kill switch: `FeatureFlags.enableMint2FirstExperienceEntry`
  remains default off until the entry flow has runtime evidence.
- Maestro: add
  `tools/simulator/flows/maestro-perfect-set/flow_mint2_first_experience_rente_capital_entry.yaml`
  starting with `launchApp: { clearState: true }`.
- iPhone 13 mini: capture a simulator screenshot or UI snapshot proving the
  three axes, live RvC door, receipt/missing-fields state, and no clipped CTA or
  receipt text.
- No simulator is run for this planning-only artifact.

## Public Repo Discipline

This artifact is Proposed, not Decided. It avoids legal/forensic phrasing and
does not claim product behavior. Any future public decision artifact must remain
Proposed unless Julien explicitly promotes it.
