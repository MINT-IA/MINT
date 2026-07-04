NO_UNRESOLVED_CRITICAL_HIGH

---

## JOS-009 Audit — Swiss Financial Data Chronology & Runtime QA

**Scope:** `q_pay_frequency` isolation · `q_housing_cost_frequency` introduction · legacy fallback correctness · duplicate data · `/budget/setup` navigability · test/runtime coverage.

---

### Core fix verification

The JOS-009 corruption path was: `BudgetSetupScreen._save()` writing `q_pay_frequency: 'monthly'`, which overwrote an existing `q_pay_frequency: 'yearly'` set by income collection, silently corrupting `salaireBrutMensuel` and all income-derived projections.

The fix correctly addresses this in three places:

- `budget_setup_screen.dart:161` — `q_pay_frequency` replaced by `q_housing_cost_frequency` at the point of write. Clean, surgical.
- `coach_profile_provider.dart:654–658` — `mergeAnswers` injects `q_housing_cost_frequency='monthly'` when housing cost arrives without it and the store has no prior value. Prevents the `fromWizardAnswers` fallback from silently picking up `q_pay_frequency`.
- `coach_profile.dart:2468–2474` — `fromWizardAnswers` reads `q_housing_cost_frequency` first, falls back to `payFrequency`. Migration-safe for pre-fix stored data where budget_setup had always written `q_pay_frequency='monthly'` (fallback gives correct result for those profiles).

Income isolation confirmed: `q_pay_frequency` remains exclusively set by income collection paths (`incomeNetMonthly`, `incomeNetYearly`, `applySaveFact`). Budget setup no longer touches it.

---

### Findings

**MEDIUM — M1: No migration path for existing `_coach_depenses_loyer` open-banking profiles**

The `updateFromOpenBanking` change correctly migrates new writes to canonical `q_housing_cost_period_chf` + `q_housing_cost_frequency`. However, existing profiles that previously went through a bLink/OB sync have `_coach_depenses_loyer` in their persisted answer map, which `fromWizardAnswers` never reads. Those users' open-banking housing data is silently absent from `depenses.loyer` until they re-sync or visit `/budget/setup`. The test `open banking writes canonical housing cost keys` only validates new writes; no back-fill or lazy migration is wired. This is a pre-existing gap but JOS-009 is the right place to close it.

**MEDIUM — M2: `q_housing_cost_frequency` dossier legacy fallback scope is wide**

`dossier_payload_service.dart` housing block uses `legacyPeriodFrequencyKey: 'q_pay_frequency'`. For profiles where no `q_housing_cost_frequency` exists and `q_pay_frequency='yearly'` (e.g., annual-salary user who has never opened `/budget/setup`), the dossier will divide housing cost by 12. The `mergeAnswers` injection closes this for any future write through the provider, but a profile that was written directly to `ReportPersistenceService` (test harness, scenario loader) without going through `mergeAnswers` is still exposed. Scenario fixtures in the test suite should explicitly include `q_housing_cost_frequency` to prevent false dossier values.

**LOW — L1: Single Patrol scenario, canPop path untested at E2E level**

The Patrol suite (`budget_housing_frequency_patrol_test.dart`) routes directly to `/budget/setup` with no prior page on the stack, exercising only the `router.go('/budget')` fallback. The `router.canPop()` branch (normal deep-link or in-app navigation where a previous route exists) is exercised only by widget tests. Not a blocker but increases confidence gap.

**LOW — L2: `'annual'` token added but not enumerated in DATA_LEDGER**

`coach_profile.dart` and `dossier_payload_service.dart` now accept `'annual'` alongside `'yearly'`/`'annuel'`. `DATA_LEDGER.md` and `DATA_QUEST.md` still show `monthly|yearly|annuel` as the valid enumeration. A future writer injecting `'annual'` from a coach fact or scenario won't be caught by any schema check.

**LOW — L3: `q_debt_payments_period_chf` remains income-frequency-coupled**

`dossier_payload_service.dart:1143` uses `periodFrequencyKey: 'q_pay_frequency'` for debt payments, unchanged by this PR. A user paid annually with monthly debt payments would see their debt annualized and divided by 12. This is pre-existing behavior, not a regression, but is now more visible by contrast.

---

### Residual risks

- Pre-fix open-banking profiles that stored housing under `_coach_depenses_loyer` silently compute `depenses.loyer = 1500` (default) until re-sync or budget setup.
- Scenario test fixtures that omit `q_housing_cost_frequency` but include `q_pay_frequency='yearly'` will produce divided-by-12 housing costs in dossier builds.

---

### Score: **8 / 10**

Core isolation is correct and well-tested. Navigation crash fix is sound. Patrol + 56 unit tests on iPhone 17 Pro constitute adequate runtime proof for the specific contract. Score held from 10 by the two MEDIUMs: open-banking back-fill gap (M1) and the dossier legacy fallback exposure for scenarios without an explicit `q_housing_cost_frequency` (M2). Neither is a blocker for merge; both should be tracked as follow-on work.
