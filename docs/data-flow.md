# MINT Data Flow — the authoritative map

**Why this file exists.** MINT data capture lives in three storage layers
(SharedPreferences, Keychain fallback, backend Postgres) mutated by seven
write paths (wizard, scan, coach save_fact, Dart regex fallback, inline
coach pickers, budget form, tax annual refresh). Drifting between them is
the #1 source of « the UI says captured, the profile is empty at
relaunch » bugs — the exact bug class that killed the MVP walkthrough
2026-04-20.

This doc gives every writer + every reader explicit ownership of every
storage key. If your edit changes one, this doc must be updated in the
same PR. CI lint (TODO, Phase 34 extension) will enforce.

---

## The storage model — three layers, deliberate

```mermaid
flowchart LR
    U[User action] --> W1[Scan confirmer]
    U --> W2[Coach chat]
    U --> W3[Budget setup form]
    U --> W4[Wizard inline picker]
    U --> W5[Annual refresh]

    W1 --> PROV[CoachProfileProvider]
    W2 --> PROV
    W3 --> PROV
    W4 --> PROV
    W5 --> PROV

    PROV -- mergeAnswers --> SP[(SharedPreferences<br/>wizard_answers_v2)]
    W3 -. degraded direct-input fallback .-> BUDGET[(SharedPreferences<br/>budget_inputs_v1)]
    PROV -- syncToBackend --> BE[(Backend Postgres<br/>ProfileModel.data)]
    SP --> LOAD[loadFromWizard → fromWizardAnswers]
    LOAD --> PROFILE[CoachProfile in memory]
    PROFILE --> CALCS[12 calculators]
    BUDGET -. only when no material profile supersedes it .-> UI
    CALCS --> UI[Mon argent / Aujourd'hui / Explorer]
```

**Invariants.**

1. `wizard_answers_v2` (SharedPreferences key) is the **local source of
   truth**. Everything derives from it via `CoachProfile.fromWizardAnswers`.
2. Backend `ProfileModel.data` is the **remote mirror**, only for
   authenticated users. Anonymous users **never** have backend state —
   Keychain failure for anon sessions falls back to SharedPreferences (see
   `anonymous_session_service.dart`).
3. The `CoachProfile` instance in memory is **recomputed** from answers on
   every write. Never mutate the profile directly — always go through
   `mergeAnswers` / `updateProfile` / `updateFrom*Extraction`.
4. New data capture paths **must** write into `wizard_answers_v2` via one
   of the existing setters, or add a new key listed below.
5. `budget_inputs_v1` is a degraded local read model, not a competing
   profile source. It may preserve a user's direct budget entry when secure
   `wizard_answers_v2` persistence fails, but readers may use it only when no
   material `CoachProfile` can supersede it. Any later successful profile
   hydration wins.

---

## The 6 writers — who mutates `wizard_answers_v2`

Every canonical profile writer persists via
`ReportPersistenceService.saveAnswers(answers)` which encrypts sensitive keys
via `SecureWizardStore` (Keychain) and mirrors to SharedPreferences. **This is
the only legal write path for `wizard_answers_v2`.** The budget form has one
documented degradation path: if that canonical write leaves no material profile
after reload, it may save direct `BudgetInputs` to `budget_inputs_v1` so the
budget UI and Coach opener can preserve the user's typed budget until the
canonical profile path is available again.

| # | Writer | Entry points | Keys written | Lifecycle trigger |
|---|---|---|---|---|
| 1 | **Wizard full** | `wizard_service.dart` | `q_firstname`, `q_birth_year`, `q_canton`, `q_net_income_period_chf`, `q_pay_frequency`, `q_housing_cost_period_chf`, … (all `q_*`) | `WizardProvider.complete()` sets `_completed_key` flag |
| 2 | **Mini-onboarding** | `smart_flow_screen.dart` | Subset of `q_*` (3 questions) | `ReportPersistenceService.setMiniOnboardingCompleted(true)` |
| 3 | **Scan confirmation** | `extraction_review_screen.dart:659` → `updateFrom{Lpp,Avs,Tax,Salary}Extraction` | `_coach_avoir_lpp*`, `_coach_salaire_assure`, `_coach_rachat_maximum`, `_coach_taux_conversion*`, `_coach_avs_*`, `_coach_tax_*` + `_coach_<type>_source = 'document_scan'` | Post-scan flow |
| 4 | **Coach chat inline picker** | `coach_chat_screen.dart` → `coachProvider.mergeAnswers()` | Arbitrary `q_*` single field | User taps inline picker in conversation |
| 5 | **Flutter save_fact dispatcher + Dart regex fallback** | backend/remote `save_fact` payloads or `lib/services/chat/fact_extraction_fallback.dart` → `applySaveFact`/remote mapper → `mergeAnswers`/safe merge | `q_birth_year`, `q_date_of_birth`, `q_net_income_period_chf`, `q_gross_salary_annual`, `q_self_employed_net_income_annual_chf` + derived monthly `q_net_income_period_chf`/`q_pay_frequency='monthly'` when the canonical fact is `selfEmployedNetIncome`, `_coach_avoir_lpp`, `_coach_salaire_assure`, `q_3a_total`, `_coach_rachat_maximum`, `q_total_debt_balance_chf` (regex fallback remains restricted to 1st-person matches and does not infer independent status by itself) | Every coach chat send or backend profile sync |
| 6 | **Budget setup form** | `budget_setup_screen.dart` → `coachProvider.mergeAnswers` + `budgetProvider.setInputs` | `q_net_income_period_chf`, `q_housing_cost_period_chf`, `q_lamal_premium_monthly_chf`, `q_pay_frequency='monthly'`, `_coach_depenses_{transport,telecom,electricite,frais_medicaux,autres}` | Tap « Enregistrer » |
| 7 | **Annual refresh** (scheduled) | `updateFromRefresh` (CoachProfileProvider) | Updates `_coach_updated_at` + tax + salary | Annual trigger (currently orphaned, cf façade audit) |

**Legend.** Keys prefixed `q_*` come from wizard-style answers
(`fromWizardAnswers` reads them natively). Keys prefixed `_coach_*` come
from richer sources (scan extractions, annotations) — `fromWizardAnswers`
also reads these via the `<code_context>` block at
[`coach_profile.dart:2400-2500`](../apps/mobile/lib/models/coach_profile.dart).

---

## The `q_*` key reference — canonical wizard keys

Read by `CoachProfile.fromWizardAnswers`. Sorted by domain.

**Identity**
- `q_firstname` (str), `q_birth_year` (int), `q_date_of_birth` (ISO str),
  `q_canton` (2-letter, default `ZH`), `q_civil_status`
  (celibataire/marie/concubinage/divorce/veuf), `q_children` (int),
  `q_gender`, `q_commune`

**Income**
- `q_pay_frequency` (`monthly`|`yearly`|`annuel`|`annual`),
  `q_net_income_period_chf` (double, amount per period),
  `q_self_employed_net_income_annual_chf` (double, annual professional net
  income for independent/no-LPP OPP3 art. 7 calculations; Coach `save_fact`
  also writes a derived monthly proxy `q_net_income_period_chf = annual/12`
  with `q_pay_frequency='monthly'` when no better cashflow is known, so
  Budget/Rapport start coherent. Auth/backend hydration refreshes the annual
  fact and only refreshes the monthly cashflow when it was missing or still
  equal to the old annual-derived monthly value, preserving explicit Budget
  entries. Budget Setup clears `q_net_income_period_source` when the user types
  a monthly income so later annual corrections cannot overwrite an explicit
  cashflow that happens to equal the old derived proxy. Budget read models
  normalize non-monthly income to monthly and persist normalized Budget inputs
  back as `q_pay_frequency='monthly'` to avoid reload drift. Rapport uses the
  annual fact directly for the OPP3 art. 7 3a ceiling and uses the monthly key
  for cashflow),
  `q_gross_salary_annual` (preferred when known — avoids net↔brut roundtrip),
  `q_employment_status` (salarie/independant/retraite/etc.),
  `q_employment_rate` (%), `q_annual_bonus` (CHF), `q_partner_net_income_chf`,
  `q_partner_birth_year`, `q_partner_employment_status`

**Housing & fixed charges**
- `q_housing_cost_period_chf` (double — rent OR mortgage),
  `q_housing_status` (locataire/proprietaire/…),
  `q_lamal_premium_monthly_chf` (double, health insurance actual value),
  `_coach_depenses_transport`, `_coach_depenses_telecom`,
  `_coach_depenses_electricite`, `_coach_depenses_frais_medicaux`,
  `_coach_depenses_autres`

**AVS (1st pillar)**
- `q_avs_lacunes_status`, `q_avs_years_abroad`, `q_avs_contribution_years`,
  `q_avs_arrival_year`, `q_spouse_avs_contribution_years`,
  `_coach_avs_rente_estimee`, `_coach_avs_lacunes`, `_coach_avs_ramd`,
  `_coach_avs_source`

**LPP (2nd pillar)**
- `q_avoir_lpp` (total legacy), `_coach_avoir_lpp` (scanned total),
  `_coach_avoir_lpp_oblig`, `_coach_avoir_lpp_suroblig`,
  `_coach_taux_conversion`, `_coach_taux_conversion_suroblig`,
  `_coach_salaire_assure`, `_coach_rachat_maximum`,
  `_coach_rendement_caisse`, `_coach_rachat_lpp_mensuel`,
  `_coach_lpp_source`

**3a (3rd pillar)**
- `q_3a_total`, `q_3a_accounts_count`, `q_3a_annual_contribution`,
  `q_3a_providers`, `_coach_total_3a`
- `q_3a_annual_contribution` is an explicit planned annual contribution.
  When present and positive, `CoachProfile.fromWizardAnswers` tags
  `plannedContributions.3a` as `ProfileDataSource.userInput` and stamps its
  timestamp. 3a contributions derived only from `q_savings_allocation` remain
  untagged, because they are MINT allocation plans, not user-entered
  contribution facts.

**Patrimoine & dette**
- `q_cash_total`, `q_epargne_liquide`, `q_investissements`,
  `q_investments_total`, `q_emergency_fund`, `q_debt_payments_period_chf`,
  `_coach_dettes_hypotheque`, `_coach_dettes_credit`, `_coach_dettes_leasing`,
  `_coach_dettes_autres`
- Debt key semantics are intentionally split:
  `q_debt_payments_period_chf` is a monthly cashflow payment. It must not be
  converted into synthetic capital. `_coach_dettes_credit`,
  `_coach_dettes_leasing`, and `_coach_dettes_autres` are remaining capital
  amounts. `_coach_dettes_hypotheque` is structural mortgage capital and must
  not trigger consumer-debt Safe Mode by itself. If mortgage capital and
  `q_debt_payments_period_chf` coexist, preserve both: mortgage as capital,
  debt payment as monthly cashflow.

**Fiscal**
- `_coach_tax_revenu_imposable`, `_coach_tax_fortune_imposable`,
  `_coach_tax_impot_cantonal`, `_coach_tax_impot_federal`,
  `_coach_tax_taux_marginal`, `_coach_tax_source`

**Goals & lifecycle**
- `q_target_retirement_age`, `_coach_family_change`,
  `_coach_financial_literacy_level`, `_coach_created_at`, `_coach_updated_at`,
  `_coach_data_timestamps` (dict: fieldPath → ISO timestamp)

---

## The `_SAVE_FACT_ALLOWED_KEYS` whitelist — coach-LLM canonical names

Defined in
[`services/backend/app/api/v1/endpoints/coach_chat.py:924`](../services/backend/app/api/v1/endpoints/coach_chat.py).
The LLM (Claude) is only allowed to invoke `save_fact` with these
canonical keys. The Dart-side `_mapFactKeyToAnswers` in
[`coach_profile_provider.dart`](../apps/mobile/lib/providers/coach_profile_provider.dart)
translates every LLM canonical key to one or more `q_*` / `_coach_*`
wizard keys.

**Identity / location**: `birthYear`, `dateOfBirth`, `canton`, `commune`,
`householdType`, `employmentStatus`, `has2ndPillar`, `goal`,
`targetRetirementAge`, `gender`

**Income**: `incomeNetMonthly`, `incomeGrossMonthly`, `incomeNetYearly`,
`incomeGrossYearly`, `selfEmployedNetIncome`, `employmentRate`, `annualBonus`

**LPP**: `lppInsuredSalary`, `avoirLpp`, `avoirLppObligatoire`,
`avoirLppSurobligatoire`, `lppBuybackMax`, `hasVoluntaryLpp`

**3a**: `pillar3aAnnual`, `pillar3aBalance`

**Savings / wealth / debt**: `savingsMonthly`, `totalSavings`,
`wealthEstimate`, `hasDebt`, `totalDebt`

**Spouse**: `spouseBirthYear`, `spouseIncomeNetMonthly`,
`spouseAvsContributionYears`

**AVS**: `hasAvsGaps`, `avsContributionYears`

**Safe-mapping rules.**

- `selfEmployedNetIncome` maps to
  `q_self_employed_net_income_annual_chf` plus
  `q_employment_status=independant`, and when the annual amount is positive it
  writes `q_net_income_period_chf=annual/12` with
  `q_pay_frequency=monthly`. That derived monthly value is a starting proxy,
  not proof of disposable household cashflow. During Auth/backend hydration,
  the annual fact is refreshed but an explicit divergent monthly Budget value
  is preserved. Rapport uses `q_self_employed_net_income_annual_chf` directly
  for the no-LPP 3a ceiling, not the Budget cashflow field.
- `pillar3aAnnual` maps to `q_3a_annual_contribution`; positive values also
  imply `q_has_3a=true`, while a correction to zero clears a stale
  contribution-only `q_has_3a` signal. Backend/Auth hydration treats this as
  an explicit correction, not as a fill-if-missing hint.
- On login/register hydration, `localDataClaim.wizardAnswers` is the canonical
  copy of the just-claimed local wizard state. It seeds local answers and
  prevents older flat profile fields such as `selfEmployedNetIncome` from
  re-importing stale values immediately after a local claim. Presence of the
  claim key matters even when the value is `0`; zero is a user answer, not an
  absence of data.
- `pillar3aBalance` maps to `q_3a_total`; legacy `q_total_3a` is not a
  writer target.
- `totalDebt` maps to `q_total_debt_balance_chf`. It is a remaining debt
  balance, not a monthly debt payment and not a categorized debt bucket.
- `hasDebt=true` only records that the user has consumer debt; it must not
  synthesize a debt balance.
- `wealthEstimate` is intentionally not mapped to `q_cash_total`, because
  total wealth is not liquid cash.
- `hasAvsGaps=true` is intentionally not mapped to a numeric gap estimate.
  `hasAvsGaps=false` can map to `q_avs_lacunes_status=no_gaps`.
- Spouse facts only carry spouse facts. A spouse profile can exist without
  spouse income, but backend writes reject spouse fields unless
  `householdType` is `couple`, `concubine`, or `family`.

**⚠ Trap.** Adding a new canonical key to the backend whitelist without
also adding a Dart mapping in `_mapFactKeyToAnswers` = the fact is silently
dropped on client side. Always update both files in the same PR.

---

## Anonymous-mode caveat — why fresh installs are fragile

Anonymous users (`AuthProvider.isLocalMode = true`, default-on for fresh
installs) have **no `user_id`** and therefore:

1. Backend `save_fact` handler hits the `# Hors-DB path` branch
   ([`coach_chat.py:1408-1413`](../services/backend/app/api/v1/endpoints/coach_chat.py))
   — returns `"Fait noté (hors DB)"` without persisting.
2. Backend `save_fact` is in `INTERNAL_TOOL_NAMES` — the tool_call is
   stripped from `external_calls` before reaching Flutter. Flutter's
   `applySaveFact` dispatcher only fires when **Claude does NOT call
   save_fact** (bug, see § Tool routing).
3. The **Dart regex fallback** (`fact_extraction_fallback.dart`) is the
   only reliable write path for anon users until they register.
4. Keychain writes still work (iOS entitlement fix), but if they fail,
   `AnonymousSessionService` + `flutter_secure_storage` fall back
   gracefully to SharedPreferences.

**Scan-first onboarding.** Before the fix commits in
`triage/flow-utilisateur-2026-04-20`, `updateFrom*Extraction` silently
returned if `_profile == null`, losing all scanned data for fresh users.
The fix seeds `CoachProfile.defaults()` so the extraction lands.
**Don't undo this.**

---

## Reader reference — who reads `wizard_answers_v2`

Authoritative reader: `CoachProfile.fromWizardAnswers(answers)` at
[`coach_profile.dart:2307`](../apps/mobile/lib/models/coach_profile.dart).
Everything else reads the derived `CoachProfile`, not the map directly.

**Exceptions** (grep before adding a new one):
- `AuthProvider` at line 669 reads `answers` for auth bootstrap
- `ReportPersistenceService` is the I/O layer itself

Every calculator / widget that needs profile data **must** read through
`CoachProfileProvider.profile`, never through `loadAnswers()` directly.

---

## Scan pipeline — end-to-end

```
PDF (camera / gallery / OCR paste / test fixture)
  ↓
DocumentService.extractDocumentData (backend)
  ↓ returns ExtractionResult {fields: [...], confidence, sources}
  ↓
ExtractionReviewScreen (user verifies each field)
  ↓ user taps Confirmer
  ↓
coachProvider.updateFrom{Lpp|Avs|Tax|Salary}Extraction(fields)
  ↓ seeds _profile = defaults() if null
  ↓ mutates prevoyance/patrimoine/dettes/fiscal
  ↓ writes _coach_<type>_<field> keys + _coach_updated_at
  ↓ calls ReportPersistenceService.saveAnswers(answers)  ← persistence
  ↓ CoachNarrativeService.invalidateCache(_profile)     ← stale greeting fix
  ↓ notifyListeners()
  ↓ _syncToBackend() (fire-and-forget, skipped for anon)
  ↓
/scan/impact (DocumentImpactScreen) shows delta in confidence score
```

Failure modes:
- Keychain -34018 on iOS sim without entitlements → SharedPrefs fallback
  handles it via `AnonymousSessionService` pattern.
- Scan confirm UI shows « +29 points » but save drops → fixed by seeding
  defaults + adding `hasScanData` hydration branch in `loadFromWizard`.

---

## Budget flow — end-to-end

```
Mon argent → Ton budget ce mois card → tap Commencer
  ↓
/budget (BudgetContainerScreen)
  ↓ if inputs == null → empty state CTA « Ajouter mes revenus »
  ↓ tap routes to /budget/setup
  ↓
BudgetSetupScreen (new, P0-MVP-3)
  ↓ pre-fill resources from coachProfile income and charges from coachProfile.depenses
  ↓ user types monthly net resources + 2 required charges + 0..5 optional charges
  ↓ validation blocks implausible monthly captures before persistence
  ↓ tap Enregistrer
  ↓
coachProvider.mergeAnswers({
  q_net_income_period_chf: …,
  q_housing_cost_period_chf: …,
  q_pay_frequency: 'monthly',
  q_lamal_premium_monthly_chf: …,
  _coach_depenses_transport: …,          (optional)
  _coach_depenses_telecom: …,             (optional)
  _coach_depenses_electricite: …,         (optional)
  _coach_depenses_frais_medicaux: …,      (optional)
  _coach_depenses_autres: …,              (optional)
})
  ↓ answers written via ReportPersistenceService
  ↓
budgetProvider.setInputs(direct BudgetInputs built from the entered fields)
  ↓ profile context is retained when available (debts, tax provision, style)
  ↓ BudgetService.computePlan(inputs, overrides)
  ↓ profile-derived budget_inputs_v1 duplicates are cleared; direct-input fallback stays available
  ↓
Pop back to Mon argent → BudgetSummaryCard now has data → « Il te reste Y CHF »
```

`BudgetScreen` treats the `BudgetInputs` passed by `BudgetContainerScreen` as
the local source of truth for its hero number, breakdown, and flow map. It must
not reuse a stale global `BudgetSnapshot` when the user has just saved or
restored direct budget inputs.

`MonArgentScreen` prefers a budget freshly re-derived from the current
`CoachProfile`, then `MintState.dataSpineSnapshot.budget`, then
`budget_inputs_v1` fallback data. Direct-input budgets, such as bank-import
previews that are not yet written into `wizard_answers_v2`, remain stored as
fallback data but must not mask a current Data Spine budget.

`CoachChatScreen` follows the same precedence for its silent opener. It may
hydrate `budget_inputs_v1` on cold open only when the current profile is
missing or identity-only; a material `CoachProfile` always takes precedence.

Chat fallback (« J'en parle plutôt au coach ») remains available on the
setup screen, respecting `feedback_chat_is_everything` (chat *can* do it,
but doesn't *have* to).

**Capture guard.** Budget setup rejects monthly amounts outside the local
capture range before writing `wizard_answers_v2`. The same guard is applied
when rebuilding `CoachProfile` and `BudgetInputs` so a stale simulator value
such as an appended field entry cannot keep rendering as a real monthly charge.

---

## Route registry (Phase 32 Cartographier)

147 routes with `RouteMeta{owner, category, requiresAuth, killFlag}` in
[`apps/mobile/lib/routes/route_metadata.dart`](../apps/mobile/lib/routes/route_metadata.dart).

**CLI**: `./tools/mint-routes list | grep coach` — live health query
against Sentry + FeatureFlags.

**Admin UI**: `/admin/routes` — schema viewer (does NOT show Sentry health
on mobile, iOS sandbox prevents cross-filesystem read).

**Adding a new route** — three places to update in one PR:
1. The `GoRoute` in [`app.dart`](../apps/mobile/lib/app.dart)
2. The `RouteMeta` entry in `route_metadata.dart`
3. Navigation intent tag (if user-facing) in
   [`services/navigation/screen_registry.dart`](../apps/mobile/lib/services/navigation/screen_registry.dart)

The `route_registry_parity` CI lint will fail the PR otherwise.

---

*Last updated: 2026-04-21 after MVP-PLAN-2026-04-21 P0-MVP-3 ship.
Maintenance rule: every new writer or reader of `wizard_answers_v2`
updates this doc in the same PR. Code drift without doc drift = the
trap we built this to avoid.*
