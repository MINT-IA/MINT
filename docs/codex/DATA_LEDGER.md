# DATA_LEDGER.md — MINT Canonical Data Ledger

> **G1 reality audit:** `file:line` references were re-checked against HEAD `095eeaa32` on 2026-07-07. Treat line refs as evidence snapshots, not evergreen truth. Rerun `tools/checks/tests/test_codex_spec_reality_contract.py` after changing this spec or the cited code.

> **Status:** target contract plus live gap ledger for the coding agent (Codex). Mechanical, testable, implementable.
> **Audited baseline:** commit `095eeaa32` (2026-07-07).
> **Scope:** defines THE single typed registry of every user data field MINT knows. Every screen reads/writes from this ledger and nowhere else.
> **Conflict order:** `rules.md` (tier 1) > `CLAUDE.md` (tier 2) > this file (tier 3 operational). This file does not override compliance.

---

## 0. What "the ledger" is (concretely, in existing code)

The ledger is **not new infrastructure**. It is the formalisation of the spine that already exists. Do not rebuild it.

| Layer | Existing artefact (path) | Role in the ledger |
|---|---|---|
| Canonical model | `apps/mobile/lib/models/coach_profile.dart` → `CoachProfile` (+ sub-models `PrevoyanceProfile`, `PatrimoineProfile`, `DetteProfile`, `DepensesProfile`, `ConjointProfile`, `GoalA/GoalB`) | The typed in-memory record. THE source of truth. |
| Single write path | `apps/mobile/lib/providers/coach_profile_provider.dart` → `mergeAnswers()` / `applySaveFact()` / `updateProfile()` | The ONLY mutators. No screen-local persistence. |
| Persistence | `report_persistence_service.dart` → SharedPreferences key `wizard_answers_v2`; reconstructed via `CoachProfile.fromWizardAnswers()` | Durable local store; survives restart. |
| Computed state | `apps/mobile/lib/providers/mint_state_provider.dart` → `MintUserState` (`models/mint_user_state.dart`) | Derived read-model (lifecyclePhase, archetype, budgetGap, caps, confidence, friScore). Recomputed on every profile change via `ChangeNotifierProxyProvider`. |
| Provenance (mobile) | `CoachProfile.dataSources : Map<String, ProfileDataSource>` + `CoachProfile.dataTimestamps : Map<String, DateTime>` | Per-field {source, updatedAt}. **Today partial — see §6.** |
| Backend store | `ProfileModel.data : JSON dict`, written by `save_fact` against the **35-key** allowlist `_SAVE_FACT_ALLOWED_KEYS` (`services/backend/app/api/v1/endpoints/coach_chat.py:924`) | Offline-first mirror; sync is fire-and-forget. |
| Decay | `apps/mobile/lib/services/biography/freshness_decay_service.dart` | Two-tier freshness, 0.60 refresh threshold. API is `weight(BiographyFact fact, DateTime now)` — see §5. |
| Confidence | `services/backend/app/services/confidence/enhanced_confidence_service.py` | 4-axis score; consumes source + freshness. |

**`models/profile.dart` + `ProfileProvider` are NOT part of the ledger** and are slated for deletion — but they are **not a zero-consumer dead module at `095eeaa32`**. `ProfileProvider` (`apps/mobile/lib/providers/profile_provider.dart:5`, registered in `app.dart:1425`) still has **5 live screen/widget consumers**: `simulator_3a_screen.dart:197` (`context.read<ProfileProvider>()`, legacy fallback path), `simulator_3a_screen.dart:301` (`context.watch<ProfileProvider>().profile?.hasDebt`), plus 3 widgets — `widgets/simulators/buyback_widget.dart:39`, `widgets/recommendation_card.dart:17`, `widgets/comparators/pillar3a_comparator_widget.dart:29`. Deletion is a REQUIRED but **not-yet-safe** task: these consumers MUST first be migrated to read from `CoachProfileProvider`/`MintStateProvider`, after which `ProfileProvider` + `models/profile.dart` become genuinely orphaned and can be removed. Do not extend them; do not delete them before the migration.

---

## 1. Ledger invariants (acceptance criteria — a violation is a release-blocking bug)

These restate §F of the wiring findings. CI must enforce I-1, I-3, I-6, I-7.

- **I-1 — SINGLE SOURCE.** Every screen reads the domain data it renders from the ledger (`context.watch<MintStateProvider>().state` or `CoachProfileProvider.profile`) ONLY. A screen MUST NOT read domain data from `GoRouter.extra`.
- **I-2 — extra carries only ephemera.** `GoRouter.extra` / query params may carry ids, enums, ephemeral UI selection. They MUST NOT carry the financial values a screen needs to render. (Fixes `/scan/review`, `/scan/impact`, `/rapport`, `/portfolio` dead roads — wiring findings §C; per-route contracts in §7A.)
- **I-3 — SINGLE WRITE PATH.** Every write goes through `CoachProfileProvider.mergeAnswers()` or `.applySaveFact()` (which itself calls `mergeAnswers`). No `SharedPreferences`/file/DB write of domain data from a screen or service that bypasses the provider. Simulators that write back MUST call `provider.updateProfile()` (already correct — keep it).
- **I-4 — NO ISLANDS.** Every isolated provider (`BudgetProvider`, `HouseholdProvider`, `TimelineProvider`, documents, conversations) MUST bridge into the recompute so `MintUserState` is never stale. See §7.
- **I-5 — PROJECTIONS ARE RANGED.** Every consumer that renders a projected number MUST also render a range + `EnhancedConfidence` + "à confirmer". No bare numbers. No promissory terms (CLAUDE.md §5).
- **I-6 — DIFF NOT FORM.** Collection asks only the missing/stale delta. Freshness < 0.60 ⇒ **re-confirm**, never blank re-ask. Implement on top of `data_block_enrichment_screen.dart` (≈70% built).
- **I-7 — ALLOWLIST IS THE CONTRACT.** A field is writable via the coach/backend ONLY if its key is in `_SAVE_FACT_ALLOWED_KEYS` (35 keys). Adding a coach-writable field = adding to that set + the mobile `_mapFactKeyToAnswers` switch + a row in this ledger. The backend allowlist and coach tool enum are in sync at `095eeaa32`, but the mobile path is not: **5 backend-writable keys are ineffective locally via `applySaveFact`** — see §3.8.

---

## 2. Type system & column legend

Every ledger row uses these columns.

- **key** — canonical identifier. For coach/backend-writable fields this is the exact `_SAVE_FACT_ALLOWED_KEYS` key. For mobile-only fields it is the Dart field path on `CoachProfile` (e.g. `patrimoine.epargneLiquide`). The wizard-answer key (`q_*` or `_coach_*`) is given when it differs — it is the storage key in `wizard_answers_v2`, produced by `_mapFactKeyToAnswers` and read back by `fromWizardAnswers`. **These wizard keys are transcribed verbatim from the real switch (`coach_profile_provider.dart:564-678`); do not paraphrase them.**
- **type+unit** — Dart type and unit. `CHF` = Swiss francs; `CHF/mo` = monthly; `%` = percent (stored as written, e.g. `1.5` not `0.015`, except `tauxConversion*` which are decimals); `yr` = years; ISO dates are `YYYY-MM-DD` strings on disk, `DateTime` in model.
- **domain** — owning domain: `identity`, `income`, `expenses`, `prevoyance` (AVS/LPP/3a/LP), `patrimoine`, `dettes`, `goals`, `couple`, `meta`.
- **sources** — allowed `ProfileDataSource` values for this field. See the enum definition below. A field may declare a subset; writes claiming a source outside the subset are rejected.
- **fresh** — freshness tier: `annual` / `volatile` / `static`. Maps to the `freshnessCategory` string the decay service reads (§5). Decay + 0.60 refresh threshold per `FreshnessDecayService`.
- **wconf** — default accuracy weight used by the confidence engine when the field's current source is the lowest-weight source it declares. Actual weight at runtime = weight of the field's recorded source (§6).
- **write** — write path. ALWAYS `CoachProfileProvider`. `mergeAnswers` (wizard/inline/scan), `applySaveFact` (coach tool → maps to wizard key), `updateProfile` (simulator write-back). Never screen-local.
- **consumers** — the computations/screens that read this field.

### 2.1 `ProfileDataSource` — the ONLY mobile source enum (verified, `coach_profile.dart:36`)

The mobile enum has **exactly 5 members**. Use ONLY these names in every `sources:` cell. There is **no `scan` member**: OCR extraction writes are recorded as `estimated` at extraction time and promoted to `certificate` only after the user confirms the extracted figure (§7A `/scan/review`).

```
estimated       .25   // MINT default / unconfirmed OCR extraction
userInput       .60   // manual entry
crossValidated  .70   // manual entry + cross-check
certificate     .95   // confirmed from a scanned certificate
openBanking    1.00   // live bLink/SFTI feed
```

These weights are the accuracy-axis weights in `enhanced_confidence_service.py`. No other source token may appear in a `sources:` cell. If a row previously implied "scan(.85)", read it as: extraction → `estimated`, post-confirm → `certificate`.

### 2.2 Backend `DataSource` — the DIFFERENT backend enum, and the mandatory cross-walk

The backend uses a **separate 8-member enum** `DataSource` with **different names and weights** (`services/backend/app/services/document_parser/document_models.py:39`, weights in `DATA_SOURCE_ACCURACY:57`):

```
user_estimate              0.25
user_entry                 0.50
user_entry_cross_validated 0.70
document_scan              0.85
document_scan_verified     0.95
open_banking               1.00
institutional_api          0.95
system_estimate            0.25
```

Mobile ↔ backend are NOT the same enum and their weights differ (mobile `userInput`=.60 vs backend `user_entry`=.50). Any code that syncs mobile `dataSources` into backend `data_sources` (§6.2) MUST apply this exact cross-walk (a new module `services/backend/app/services/confidence/source_crosswalk.py`):

| mobile `ProfileDataSource` | backend `DataSource` | note |
|---|---|---|
| `estimated` | `system_estimate` | both .25 |
| `userInput` | `user_entry` | weight changes .60 → .50 by design; backend axis governs backend score |
| `crossValidated` | `user_entry_cross_validated` | both .70 |
| `certificate` | `document_scan_verified` | both .95 (a confirmed cert = verified scan) |
| `openBanking` | `open_banking` | both 1.00 |

Backend-only members `document_scan` (.85, unconfirmed OCR), `institutional_api` (.95), and `user_estimate` (.25) have **no mobile pre-image**: `document_scan`/`institutional_api` are produced only by backend document/API pipelines, and `user_estimate` (a second .25 member alongside `system_estimate`) is a backend-internal estimate tag; the mobile→backend sync maps mobile `estimated` to `system_estimate` (per the table above), never to `user_estimate`. None of the three is ever emitted by the mobile→backend sync. This table is the single source of truth for the cross-walk; §6 references it, does not restate it.

---

## 3. Ledger — coach/backend-writable fields (the 35-key allowlist)

These **35** keys are the exact contents of `_SAVE_FACT_ALLOWED_KEYS` (`coach_chat.py:924`). They are the ONLY keys the coach (`save_fact`) and backend may write. `wizard key` = the target produced by `CoachProfileProvider._mapFactKeyToAnswers`, verbatim from the real switch. Rows whose `wizard key` cell reads **⚠ NO MAPPER CASE** currently fall through `default: return const {}` and are silently dropped on mobile — §3.8 lists them as required repair work.

### 3.1 Identity / location

| key | wizard key | type+unit | domain | sources | fresh | wconf | write | consumers |
|---|---|---|---|---|---|---|---|---|
| `birthYear` | `q_birth_year` | int (year) | identity | userInput, certificate | static | .60 | applySaveFact/mergeAnswers | `age`, `archetype`, AVS/LPP projection, CapEngine (`age>=45`), lifecyclePhase |
| `dateOfBirth` | `q_date_of_birth` | String ISO date | identity | userInput, certificate | static | .60 | applySaveFact/mergeAnswers | `ageOrNull` (precise), AVS21 reference age |
| `canton` | `q_canton` | String (2-letter enum) | identity | userInput, certificate | annual | .60 | applySaveFact/mergeAnswers | `TaxCalculator`, `NetIncomeBreakdown`, budget, all fiscal screens |
| `commune` | `q_commune` | String | identity | userInput | annual | .60 | applySaveFact/mergeAnswers | communal tax multiplier, fiscal precision |
| `householdType` | `q_civil_status` | enum {single, couple, concubine, family} | identity/couple | userInput | static* | .60 | applySaveFact/mergeAnswers | `isCouple`, couple AVS plafonnement, succession, lifecyclePhase |
| `employmentStatus` | `q_employment_status` | enum {salarie, independant, retraite, employee, self_employed, retired, mixed, unemployed, student} | identity | userInput | static* | .60 | applySaveFact/mergeAnswers | `archetype` (indep w/wo LPP), LPP eligibility, SafeMode E1/E4 |
| `goal` | ⚠ NO MAPPER CASE (§3.8; target `q_goal` → `GoalA`) | enum {house, retire, emergency, invest, optimize_taxes, other} | goals | userInput | static* | .60 | applySaveFact/mergeAnswers | `GoalA`, goal-aware prioritization, Pulse hero |
| `targetRetirementAge` | `q_target_retirement_age` | int (58–70) | identity | userInput | static* | .60 | applySaveFact/mergeAnswers | `effectiveRetirementAge`, `anneesAvantRetraite`, all retirement sims |
| `gender` | `q_gender` | enum {M, F} | identity | userInput, certificate | static | .60 | applySaveFact/mergeAnswers | AVS21 transitional reference age (women 1961–63), mortality cohort |

\* `static*` = changes are **life events**, not decay. Do not auto-stale; trigger the event flow (marriage, retirement) instead.

### 3.2 Income

| key | wizard key | type+unit | domain | sources | fresh | wconf | write | consumers |
|---|---|---|---|---|---|---|---|---|
| `incomeNetMonthly` | `q_net_income_period_chf` + `q_pay_frequency='monthly'` | double CHF/mo | income | userInput, certificate, openBanking | annual | .60 | applySaveFact/mergeAnswers | budget, `resteAVivreMensuel`, SafeMode |
| `incomeNetYearly` | `q_net_income_period_chf` + `q_pay_frequency='yearly'` | double CHF/yr | income | userInput, certificate | annual | .60 | applySaveFact/mergeAnswers | tax, affordability ~33% |
| `incomeGrossMonthly` | `q_gross_salary_annual` (= value × 12) | double CHF/mo | income | userInput, certificate, openBanking | annual | .60 | applySaveFact/mergeAnswers | `salaireBrutMensuel`, `revenuBrutAnnuel`, LPP coordination, AVS RAMD |
| `incomeGrossYearly` | `q_gross_salary_annual` | double CHF/yr | income | userInput, certificate | annual | .60 | applySaveFact/mergeAnswers | `revenuBrutAnnuel`, tax tiers, LPP insured salary inference |
| `employmentRate` | `q_employment_rate` | double % (0–100) | income | userInput | annual | .60 | applySaveFact/mergeAnswers | part-time coaching, coordination-deduction alert |
| `annualBonus` | `q_annual_bonus` | double CHF/yr | income | userInput, certificate | annual | .60 | applySaveFact/mergeAnswers | `bonusPourcentage`, `revenuBrutAnnuel` |
| `selfEmployedNetIncome` | ⚠ NO MAPPER CASE (§3.8) | double CHF/yr | income | userInput, certificate | annual | .60 | applySaveFact/mergeAnswers | independant archetype, 3a max 36'288, AVS indep |

> Income keys map to a **pay-frequency-consistent pair** so `fromWizardAnswers` computes `salaireBrutMensuel` correctly (the `incomeNetMonthly/Yearly` cases set BOTH `q_net_income_period_chf` and `q_pay_frequency`; the gross cases normalise to `q_gross_salary_annual`). A write to a `Net*` key MUST NOT silently overwrite a `Gross*`-derived value of a different frequency.

### 3.3 LPP (2nd pillar)

| key | wizard key | type+unit | domain | sources | fresh | wconf | write | consumers |
|---|---|---|---|---|---|---|---|---|
| `lppInsuredSalary` | `_coach_salaire_assure` | double CHF/yr | prevoyance | certificate, userInput | annual | .95 (cert) | applySaveFact/mergeAnswers | `salaireAssure`; flips `isLppFromCertificate`; LPP rente precision |
| `avoirLpp` | `_coach_avoir_lpp` | double CHF | prevoyance | certificate, userInput, estimated | annual | .95 / .25 | applySaveFact/mergeAnswers | `avoirLppTotal`; LPP capital@65; rente projection; `archetype` indep |
| `avoirLppObligatoire` | `_coach_avoir_lpp_oblig` | double CHF | prevoyance | certificate | annual | .95 | applySaveFact/mergeAnswers | split conversion rate (6.8% oblig), flips `isLppFromCertificate` |
| `avoirLppSurobligatoire` | `_coach_avoir_lpp_suroblig` | double CHF | prevoyance | certificate | annual | .95 | applySaveFact/mergeAnswers | surobligatoire conversion rate, rente split |
| `lppBuybackMax` | `_coach_rachat_maximum` | double CHF | prevoyance | certificate, userInput | annual | .95 | applySaveFact/mergeAnswers | `rachatMaximum`, `lacuneRachatRestante`, rachat sim, tax deduction |
| `has2ndPillar` | ⚠ NO MAPPER CASE (§3.8) | bool | prevoyance | userInput | static* | .60 | applySaveFact/mergeAnswers | LPP eligibility gate, archetype indep w/wo LPP |
| `hasVoluntaryLpp` | ⚠ NO MAPPER CASE (§3.8) | bool | prevoyance | userInput | static* | .60 | applySaveFact/mergeAnswers | independant facultative caisse logic |

> **Source inference (existing, keep):** `CoachProfile._resolveDataSources` infers `certificate` for LPP fields when certificate-only signals exist (`_coach_avoir_lpp_oblig`, `_coach_salaire_assure`, `tauxConversionSuroblig`, `_coach_rachat_maximum`), else `estimated`. The ledger's per-field provenance (§6) must record the **actual** source at write time and override this inference.

### 3.4 Pillar 3a

| key | wizard key | type+unit | domain | sources | fresh | wconf | write | consumers |
|---|---|---|---|---|---|---|---|---|
| `pillar3aAnnual` | `q_3a_annual_contribution` | double CHF/yr | prevoyance | userInput, certificate, openBanking | annual | .60 | applySaveFact/mergeAnswers | 3a max gate (7'258 / 36'288), tax deduction sim, CapEngine |
| `pillar3aBalance` | `q_3a_total` | double CHF | prevoyance | certificate, openBanking, userInput | annual | .95 / 1.00 | applySaveFact/mergeAnswers | `totalEpargne3a`, retirement capital, `comptes3a` |

> 3a writes MUST respect `canContribute3a` (false for US/FATCA; conditional for frontalier permis G). A `pillar3a*` write for a US person should be accepted as data but flagged non-contributable, not silently zeroed.

### 3.5 Savings / wealth / debt

| key | wizard key | type+unit | domain | sources | fresh | wconf | write | consumers |
|---|---|---|---|---|---|---|---|---|
| `savingsMonthly` | `q_savings_monthly` | double CHF/mo | patrimoine | userInput, openBanking | annual | .60 | applySaveFact/mergeAnswers | budget gap, `capSequencePlan`, FRI score |
| `totalSavings` | `q_cash_total` | double CHF | patrimoine | userInput, certificate, openBanking | annual | .60 | applySaveFact/mergeAnswers | `patrimoine.epargneLiquide`, emergency fund (SafeMode Signal C), liquidity axis |
| `wealthEstimate` | `q_wealth_estimate` | double CHF | patrimoine | userInput, estimated | annual | .60 | applySaveFact/mergeAnswers | `PatrimoineProfile.wealthEstimate`, `totalPatrimoine` aggregate, wealth tax, net worth, absolute patrimoine previews |
| `hasDebt` | `q_has_consumer_debt` (`true` → `yes`, `false` → `no`; `false` zeroes `_coach_dettes_credit`, `_coach_dettes_leasing`, `_coach_dettes_autres`; `true` nulls them so the bool-only fallback can run) | bool | dettes | userInput | volatile | .60 | applySaveFact/mergeAnswers | SafeMode Signal A, `isInDebtCrisis` |
| `totalDebt` | `_coach_dettes_autres` + `q_has_consumer_debt` (`>0` → `yes`, `0` → `no`) | double CHF | dettes | userInput, certificate | volatile | .60 | applySaveFact/mergeAnswers | `dettes.*`, debt-to-income 0.33, net worth |

> **Status:** `totalSavings` maps to `q_cash_total`, the key actually read by `CoachProfile.fromWizardAnswers()` for `patrimoine.epargneLiquide`. `wealthEstimate` maps to `q_wealth_estimate`, read as `PatrimoineProfile.wealthEstimate` and used by `totalPatrimoine` as an aggregate total. `totalDebt` maps to the existing generic debt bucket `_coach_dettes_autres` and flips `q_has_consumer_debt` with the existing wizard `yes`/`no` format; `hasDebt=false` zeroes generic consumer debt buckets, `hasDebt=true` nulls them to re-enable the bool-only fallback, and neither path touches `_coach_dettes_hypotheque`. `totalPatrimoine` takes the higher of detailed asset sum and the broad estimate; it never adds them together. Do not reintroduce the old `q_epargne_liquide` collision.

### 3.6 Spouse (couple)

| key | wizard key | type+unit | domain | sources | fresh | wconf | write | consumers |
|---|---|---|---|---|---|---|---|---|
| `spouseBirthYear` | `q_partner_birth_year` | int (year) | couple | userInput | static | .60 | applySaveFact/mergeAnswers | `conjoint.birthYear`, couple AVS, survivor question |
| `spouseIncomeNetMonthly` | `q_partner_net_income_chf` (net → gross via existing conjoint logic) | double CHF/mo | couple | userInput | annual | .60 | applySaveFact/mergeAnswers | `revenuBrutAnnuelCouple`, couple budget, AVS plafonnement |
| `spouseAvsContributionYears` | ⚠ NO MAPPER CASE (§3.8) | int (yr) | couple | userInput, certificate | annual | .60 | applySaveFact/mergeAnswers | couple AVS rente, lacunes |

> Spouse keys feed `CoachProfile.conjoint`. Mobile `applySaveFact` accepts `spouseBirthYear` and `spouseIncomeNetMonthly` only when the current profile is `marie` or `concubinage`, to prevent creating a ghost spouse for a single user; backend allowlist membership alone is therefore not sufficient for these two mobile writes. Any `mergeAnswers` delta that sets `q_civil_status` to a non-couple status clears `q_partner_*`/`q_spouse_*` answers plus partner-income secure values before profile reconstruction. **Gap (§7):** `HouseholdProvider` is backend-only and is NOT synced down into `conjoint` — offline simulators miss the spouse. The bridge in §7 is mandatory.

### 3.7 AVS (1st pillar)

| key | wizard key | type+unit | domain | sources | fresh | wconf | write | consumers |
|---|---|---|---|---|---|---|---|---|
| `hasAvsGaps` | `q_avs_lacunes_status` (`true` → `unknown` unless a precise `arrived_late`/`lived_abroad` status already exists; `false` → `no_gaps`) | bool | prevoyance | userInput, certificate | annual | .60 | applySaveFact/mergeAnswers | `lacunesAVS` flag, AVS rente reduction warning |
| `avsContributionYears` | `q_avs_contribution_years` | int (yr) | prevoyance | certificate, userInput | annual | .95 / .60 | applySaveFact/mergeAnswers | `anneesContribuees`, AVS full-rente eligibility (44 yr), RAMD |

**Count check (must match code):** 3.1–3.7 = 9 (identity) + 7 (income) + 7 (LPP) + 2 (3a) + 5 (savings/wealth/debt) + 3 (spouse) + 2 (AVS) = **35 keys** = `len(_SAVE_FACT_ALLOWED_KEYS)`. CI test §8.1 asserts `len == 35`.

### 3.8 REQUIRED REPAIR — 5 backend-writable keys still ineffective locally (parity is still broken)

At `095eeaa32`, the mobile `_mapFactKeyToAnswers` switch handled only **24** of the 35 allowlist keys; the other **11** fell through `default: return const {}`, so `applySaveFact` returned `false` and the coach write was **silently dropped**. After the savings, wealth, 3a, identity, income, AVS, debt, and spouse birth/income repairs, **5** backend-writable keys still fall through locally.

G1 found a second gap: **7 mapped keys wrote to wizard keys that `CoachProfile.fromWizardAnswers()` did not read**, so `applySaveFact` returned `true` but the profile still did not reconstruct the intended value. `totalSavings` has since been repaired to `q_cash_total`, `wealthEstimate` to `q_wealth_estimate`, `pillar3aBalance` to `q_3a_total`, identity keys `commune`/`gender` to `q_commune`/`q_gender`, income keys `employmentRate`/`annualBonus` to `q_employment_rate`/`q_annual_bonus`, AVS keys `hasAvsGaps`/`avsContributionYears` to `q_avs_lacunes_status`/`q_avs_contribution_years` with precise AVS statuses preserved, debt keys `hasDebt`/`totalDebt` to `q_has_consumer_debt`/`_coach_dettes_autres`, and spouse keys `spouseBirthYear`/`spouseIncomeNetMonthly` to `q_partner_birth_year`/`q_partner_net_income_chf`; total remaining local ineffectiveness is now **5 backend-writable keys**.

**The 5 unmapped keys:** `goal`, `selfEmployedNetIncome`, `has2ndPillar`, `hasVoluntaryLpp`, `spouseAvsContributionYears`.

**The 0 remaining mapped-but-unread keys:** none. T-0 is complete.

**Repaired mapped keys:** `totalSavings -> q_cash_total`, which is read by `CoachProfile.fromWizardAnswers()` into `patrimoine.epargneLiquide`; `wealthEstimate -> q_wealth_estimate`, which is read into `PatrimoineProfile.wealthEstimate` and used by `totalPatrimoine` as a non-additive aggregate total; `pillar3aBalance -> q_3a_total`, which is read into `prevoyance.totalEpargne3a`; `commune -> q_commune` and `gender -> q_gender`, which are read into the identity fields on `CoachProfile`; `employmentRate -> q_employment_rate`, which is read into `CoachProfile.employmentRate` and forwarded to `CoachingProfile.tauxActivite`; `annualBonus -> q_annual_bonus`, which is converted to `bonusPourcentage` and therefore included in `revenuBrutAnnuel`; `hasAvsGaps -> q_avs_lacunes_status`, which is read into `prevoyance.lacunesAVS`; `avsContributionYears -> q_avs_contribution_years`, which is read into `prevoyance.anneesContribuees`; `hasDebt -> q_has_consumer_debt`, which is used by the `fromWizardAnswers` bool-only fallback to construct `DetteProfile.creditConsommation = salaireBrutMensuel * 12 * 0.05` when no debt amount exists; `totalDebt -> _coach_dettes_autres`, which is read into `dettes.autresDettes` and therefore `dettes.totalDettes`; `spouseBirthYear -> q_partner_birth_year`, which is read into `conjoint.birthYear`; `spouseIncomeNetMonthly -> q_partner_net_income_chf`, which is converted by existing conjoint net-to-gross logic into `conjoint.salaireBrutMensuel`.

**Task T-0 (done):** the 7 mapped-but-unread cases have been aligned to wizard keys already read by `fromWizardAnswers` or given explicit reads with tests.

| allowlist key | current mapper | read by `fromWizardAnswers` today | required direction |
|---|---|---|---|
| `commune` | `q_commune` | `q_commune` | ✅ repaired; keep profile identity read/write on `q_commune` |
| `gender` | `q_gender` | `q_gender` | ✅ repaired; keep profile identity read/write on `q_gender` |
| `employmentRate` | `q_employment_rate` | `q_employment_rate` | ✅ repaired; keep profile read/write and `toCoachingProfile().tauxActivite` on this value |
| `annualBonus` | `q_annual_bonus` | `q_annual_bonus` | ✅ repaired; keep raw CHF/year storage and convert to `bonusPourcentage` for `revenuBrutAnnuel` |
| `pillar3aBalance` | `q_3a_total` | `q_3a_total` / `_coach_total_3a` | ✅ repaired; keep mapping on `q_3a_total` |
| `totalSavings` | `q_cash_total` | `q_cash_total` | ✅ repaired; keep mapping on `q_cash_total` |
| `wealthEstimate` | `q_wealth_estimate` | `q_wealth_estimate` | ✅ repaired; aggregate for `totalPatrimoine`, never added on top of detailed assets |

**Task T-1 (mandatory):** add a `case` for each of the 5 unmapped keys to `_mapFactKeyToAnswers`, mapping to a wizard key that `fromWizardAnswers` already reads where one exists. Where no wizard key exists yet in `fromWizardAnswers`, add BOTH the mapper case AND the read.

| allowlist key | wizard key to add | `fromWizardAnswers` target field |
|---|---|---|
| `goal` | `q_main_goal` (or add alias `q_goal`) | `goalA` (GoalA.type) |
| `selfEmployedNetIncome` | `q_self_employed_income` | add/read income field used by independent archetype |
| `has2ndPillar` | `q_has_pension_fund` | LPP eligibility flag |
| `hasVoluntaryLpp` | `q_has_voluntary_lpp` | `prevoyance` facultative flag |
| `spouseAvsContributionYears` | add `q_spouse_avs_contribution_years` | `conjoint.prevoyance` AVS years |

After T-0 and T-1, `_mapFactKeyToAnswers` handles all 35 keys and every mapper target is actually read by `fromWizardAnswers`; the §8.1 parity test passes. Until both tasks land, that test is expected RED and gates the PR.

**Task T-2 (done):** `wealthEstimate` has its own wizard key (`q_wealth_estimate`) and a distinct `fromWizardAnswers` read via `PatrimoineProfile.wealthEstimate`. `totalPatrimoine` compares it with the detailed asset sum and uses the higher aggregate total, so `totalSavings` stays on `q_cash_total` without double counting.

---

## 4. Ledger — mobile-only typed fields (not coach-writable)

These exist on `CoachProfile` sub-models and are written by wizard / scan extraction / simulator write-back via `mergeAnswers`/`updateProfile`. They are **not** in the allowlist (the coach cannot set them by chat today). Listed because computations consume them and the provenance contract (§6) applies.

### 4.1 AVS / LPP detail (from certificate extraction)

| key (field path) | type+unit | domain | sources | fresh | wconf | write | consumers |
|---|---|---|---|---|---|---|---|
| `prevoyance.renteAVSEstimeeMensuelle` | double CHF/mo | prevoyance | certificate, estimated | annual | .95 | mergeAnswers (scan) | AVS rente display, SafeMode E1 retiree |
| `prevoyance.ramd` | double CHF | prevoyance | certificate | annual | .95 | mergeAnswers (scan) | AVS rente exact computation |
| `prevoyance.lacunesAVS` | int yr | prevoyance | certificate | annual | .95 | mergeAnswers (scan) | AVS reduction, gap-fill prompt |
| `prevoyance.bonificationsEducatives` | int yr | prevoyance | certificate | annual | .95 | mergeAnswers (scan) | AVS bonifications LAVS art.29sexies |
| `prevoyance.salaireAssure` | double CHF/yr | prevoyance | certificate | annual | .95 | mergeAnswers (scan) | LPP rente; `isLppFromCertificate` |
| `prevoyance.tauxConversion` | double decimal (≥0.068) | prevoyance | certificate, estimated | annual | .95 | mergeAnswers (scan) | LPP rente@65 |
| `prevoyance.tauxConversionSuroblig` | double decimal | prevoyance | certificate | annual | .95 | mergeAnswers (scan) | surobligatoire rente |
| `prevoyance.bonificationRate` | double % | prevoyance | certificate | annual | .95 | mergeAnswers (scan) | LPP accumulation; `isLppFromCertificate` |
| `prevoyance.projectedRenteLpp` | double CHF/yr | prevoyance | certificate | annual | .95 | mergeAnswers (scan) | LPP rente display (cert-provided, not computed) |
| `prevoyance.projectedCapital65` | double CHF | prevoyance | certificate | annual | .95 | mergeAnswers (scan) | capital@65 display |
| `prevoyance.disabilityCoverage` | double CHF | prevoyance | certificate | annual | .95 | mergeAnswers (scan) | invalidité coverage card |
| `prevoyance.deathCoverage` | double CHF | prevoyance | certificate | annual | .95 | mergeAnswers (scan) | survivor / death coverage card |
| `prevoyance.rachatEffectue` | double CHF | prevoyance | userInput, certificate | annual | .60 | mergeAnswers | `lacuneRachatRestante` |
| `prevoyance.dateRachats` | List\<DateTime\> | prevoyance | userInput, certificate | static | .60 | mergeAnswers | LPP art.79b 3-yr blocking, capital withdrawal eligibility |
| `prevoyance.comptes3a[]` | List\<Compte3a{provider,solde,rendementEstime}\> | prevoyance | userInput, openBanking, certificate | annual | .60 | mergeAnswers | `rendementMoyen3a`, 3a per-account view |
| `prevoyance.librePassage[]` | List\<LibrePassageCompte{institution,solde,dateOuverture}\> | prevoyance | userInput, certificate | annual | .60 | mergeAnswers | `totalLibrePassage`, retirement capital |

### 4.2 Patrimoine / housing (incl. simulator write-back)

| key (field path) | type+unit | domain | sources | fresh | wconf | write | consumers |
|---|---|---|---|---|---|---|---|
| `patrimoine.epargneLiquide` | double CHF | patrimoine | userInput, openBanking | annual | .60 | mergeAnswers / updateProfile | liquidity axis, emergency fund |
| `patrimoine.investissements` | double CHF | patrimoine | userInput, openBanking | annual | .60 | mergeAnswers / updateProfile | net worth, investment view |
| `patrimoine.wealthEstimate` | double CHF | patrimoine | userInput, estimated | annual | .60 | applySaveFact/mergeAnswers | `totalPatrimoine` aggregate total, wealth tax, net worth |
| `patrimoine.deviseInvestissements` | enum {chf,usd,eur} | patrimoine | userInput | static | .60 | mergeAnswers | FX exposure, US person PFIC flag |
| `patrimoine.propertyMarketValue` | double CHF | patrimoine | userInput, estimated | annual | .60 | mergeAnswers / updateProfile | `immobilierNet`, LTV, valeur locative |
| `patrimoine.mortgageBalance` | double CHF | dettes/patrimoine | userInput, certificate | volatile | .60 | mergeAnswers / updateProfile | `loanToValue`, renewal shock, SafeMode |
| `patrimoine.mortgageRate` | double % | dettes/patrimoine | userInput, certificate | volatile | .60 | mergeAnswers / updateProfile | mortgage cost, renewal sim |
| `patrimoine.monthlyRent` | double CHF/mo | expenses/patrimoine | userInput | volatile | .60 | mergeAnswers | rent-vs-buy, budget |
| `patrimoine.mortgageCapacity` | double CHF | patrimoine | estimated (calc) | volatile | .25 | updateProfile (`/hypotheque`) | affordability sim write-back (CAL-03) |
| `patrimoine.estimatedMonthlyPayment` | double CHF/mo | patrimoine | estimated (calc) | volatile | .25 | updateProfile (`/hypotheque`) | affordability sim write-back (CAL-03) |

> **Ratio denominator rule:** `totalPatrimoine` is now the higher of detailed asset sum and `wealthEstimate`. Ratios that divide a known detailed component by a total MUST use `patrimoine.detailedAssetTotal`, not the broad aggregate estimate. Fixed consumers in this slice: FRI concentration and FinancialFitness investment ratio.
>
> **Absolute total rule:** Consumers that display an absolute patrimoine total while also adding explicit LPP/3a values MUST compare `detailedAssetTotal + explicit pillars` with `wealthEstimate` and use the higher value. They MUST NOT compute `wealthEstimate + LPP + 3a`. Fixed consumers in this slice: streak/milestones and Pulse `FocusSelector` patrimoine aperçu.

### 4.3 Dettes detail (S45 enrichment)

| key (field path) | type+unit | domain | sources | fresh | wconf | write | consumers |
|---|---|---|---|---|---|---|---|
| `dettes.creditConsommation` | double CHF | dettes | userInput, certificate | volatile | .60 | mergeAnswers | `detteConsommation`, SafeMode Signal A |
| `dettes.leasing` | double CHF | dettes | userInput | volatile | .60 | mergeAnswers | `detteConsommation`, SafeMode |
| `dettes.hypotheque` | double CHF | dettes | userInput, certificate | volatile | .60 | mergeAnswers | `detteStructurelle`, `interetsHypothecairesAnnuels` |
| `dettes.autresDettes` | double CHF | dettes | userInput | volatile | .60 | mergeAnswers | SafeMode Signal A |
| `dettes.taux{Hypotheque,CreditConso,Leasing}` | double % | dettes | userInput, certificate | volatile | .60 | mergeAnswers | `tauxMaxConsommation`, interest cost |
| `dettes.mensualite{Hypotheque,CreditConso,Leasing}` | double CHF/mo | dettes | userInput | volatile | .60 | mergeAnswers | `totalMensualite`, debt-to-income 0.33 |
| `dettes.echeance{Hypotheque,CreditConso,Leasing}` | DateTime | dettes | userInput, certificate | static | .60 | mergeAnswers | renewal shock timing, payoff date |
| `dettes.rangHypotheque` | int {1,2} | dettes | userInput | static | .60 | mergeAnswers | mortgage rank logic |
| `dettes.amortissementIndirect` | bool | dettes | userInput | static | .60 | mergeAnswers | 3a-linked amortisation, tax |

### 4.4 Expenses

| key (field path) | type+unit | domain | sources | fresh | wconf | write | consumers |
|---|---|---|---|---|---|---|---|
| `depenses.loyer` | double CHF/mo | expenses | userInput | volatile | .60 | mergeAnswers | budget, `resteAVivreMensuel` |
| `depenses.assuranceMaladie` | double CHF/mo | expenses | userInput, certificate | annual | .60 | mergeAnswers | budget, LAMal |
| `depenses.{electricite,transport,telecom,fraisMedicaux,autresDepensesFixes}` | double? CHF/mo | expenses | userInput | volatile | .60 | mergeAnswers | `totalMensuel`, budget gap |

> `depenses.*` field paths are NOT allowlist keys and have NO `_mapFactKeyToAnswers` case. The BudgetProvider bridge (§7) therefore writes them via the **field-path payload shape** defined in §7B, not via a `q_*` mapping.

### 4.5 Couple detail (`conjoint.*`) and goals/meta

| key (field path) | type+unit | domain | sources | fresh | wconf | write | consumers |
|---|---|---|---|---|---|---|---|
| `conjoint.{firstName,birthYear,dateOfBirth,gender}` | mixed | couple | userInput | static | .60 | mergeAnswers (+ Household bridge §7) | couple AVS, survivor |
| `conjoint.salaireBrutMensuel` | double CHF/mo | couple | userInput | annual | .60 | mergeAnswers | `revenuBrutAnnuelCouple` |
| `conjoint.prevoyance` | PrevoyanceProfile | couple | userInput, certificate | annual | .60 | mergeAnswers | couple retirement, survivor LPP |
| `conjoint.patrimoine` | PatrimoineProfile | couple | userInput | annual | .60 | mergeAnswers | couple liquidity |
| `conjoint.{nationality,isFatcaResident,canContribute3a,arrivalAge}` | mixed | couple | userInput | static | .60 | mergeAnswers | couple archetype, FATCA 3a block |
| `conjoint.invitationLevel` | enum {declared,invited,linked} | couple | userInput | static | .60 | mergeAnswers | couple data-sharing confidence |
| `goalA` | GoalA{type,targetDate,targetAmount,label} | goals | userInput | static* | .60 | mergeAnswers | goal-aware prioritization, Pulse, timeline |
| `goalsB[]` | List\<GoalB\> | goals | userInput | static* | .60 | mergeAnswers | secondary goals view |
| `plannedContributions[]` | List\<PlannedMonthlyContribution\> | goals | userInput | volatile | .60 | mergeAnswers | `total3aMensuel`, cap plan, check-in |
| `checkIns[]` | List\<MonthlyCheckIn\> | meta | userInput | n/a (event log) | n/a | mergeAnswers | streak, FRI history |
| `arrivalAge` | int yr | identity | userInput, certificate | static | .60 | mergeAnswers | `archetype` (expat vs native), LPP since-25 |
| `residencePermit` | String {B,C,L,G,Swiss} | identity | userInput, certificate | static* | .60 | mergeAnswers | `isCrossBorder`, frontalier, expat |
| `nationality` | String ISO-2 | identity | userInput, certificate | static | .60 | mergeAnswers | `archetype`, FATCA, 3a eligibility |
| `nombreEnfants` | int | identity/couple | userInput | static* | .60 | mergeAnswers | allocations, AVS bonifs, succession |
| `financialLiteracyLevel` | enum {beginner,intermediate,advanced} | meta | userInput | static* | .60 | mergeAnswers | scaffolding adaptivity (dignity principle) |
| `primaryFocus` | String `{cat}_{subcat}` | meta | userInput | static* | .60 | mergeAnswers | Pulse hero, goal contextualization |
| `initialProjectionSnapshot` | Map | meta | computed | n/a | n/a | updateProfile | before/after delta UI (§5 delta engine) |

> **Codex note:** fields in §4 that the coach SHOULD be able to capture by chat (e.g. `dettes.creditConsommation`, `depenses.loyer`, `patrimoine.investissements`) are candidates to promote into `_SAVE_FACT_ALLOWED_KEYS`. Promotion is a 3-file change (§1 I-7) gated by DPO/compliance review — do NOT promote silently.

---

## 5. The 30% missing — diff/delta engine (build on existing scaffolding)

Reuse `data_block_enrichment_screen.dart` (`/data-block/:type`), `rank_enrichment_prompts()`, `freshness_decay_service.dart`. Do NOT rebuild.

### 5.1 The freshness bridge (required — the API takes a `BiographyFact`, not a field path)

`FreshnessDecayService.weight()` has ONE signature: `static double weight(BiographyFact fact, DateTime now)`. There is **no** field-path or `dataTimestamps`-map overload. A ledger field path is NOT directly acceptable. Two distinct freshness systems exist and must not be conflated: (a) `BiographyRepository` immutable facts (which carry `updatedAt` + `freshnessCategory`), and (b) `CoachProfile.dataTimestamps`/`dataSourceDates` provenance maps.

**Task T-3 (mandatory):** add an adapter `FreshnessDecayService.weightForField(String fieldPath, CoachProfile profile, DateTime now)` that resolves a field path to freshness inputs WITHOUT inventing a new decay model:

1. Look up the latest `BiographyFact` for the path via the existing `BiographyRepository.getLatestFactForField(fieldPath)`. If found, return `weight(fact, now)`.
2. Fallback when no BiographyFact exists: synthesise a transient `BiographyFact` with
   - `updatedAt = profile.dataTimestamps[fieldPath]` (if absent ⇒ treat as maximally stale ⇒ weight = floor 0.30),
   - `freshnessCategory =` the ledger `fresh` column for that path, mapped: `annual`→`'annual'`, `volatile`→`'volatile'`, `static`→ return `1.0` (static fields never decay; skip the weight call),
   then return `weight(synthetic, now)`.

The ledger `fresh` column (§3/§4) IS the authoritative `freshnessCategory` source for the fallback. Provide a `const Map<String,String> kFieldFreshnessCategory` generated from the ledger (one entry per field path) so the adapter never guesses.

### 5.2 Delta-engine capability table

| Capability | Where it goes | Mechanical rule |
|---|---|---|
| Per-field provenance | §6 | `{source, sourceDate, updatedAt}` per field (mobile maps + backend). |
| Stale → re-confirm | `data_block_enrichment_screen.dart` | If `FreshnessDecayService.weightForField(path, profile, now) < 0.60` ⇒ show "On a noté X (il y a N mois) — toujours juste ?" with [Confirmer]/[Corriger] (all strings via `AppLocalizations`). Confirm ⇒ `mergeAnswers` same value, new `updatedAt` (resets decay). NEVER blank the field. |
| Diff not form | data-block + collection flows | Only render inputs for fields where value is null OR `weightForField < 0.60`. Skip fields already fresh. (I-6) |
| Before/after delta | new widget in data-block | Snapshot `MintUserState` before write into `initialProjectionSnapshot`; after `mergeAnswers` resolves, diff `budgetGap`/`confidenceScore`/projection vs snapshot; render Δ. |
| Goal-aware prioritization | `suggest_actions` (backend, `coach_chat.py:~900`) | Replace the hardcoded if-chains (currently `if data.get(...)` blocks) with `rank_enrichment_prompts()`, then re-weight by `goal`/`primaryFocus` (e.g. goal=house ⇒ boost mortgage/affordability fields). |
| Smart stage-2 sequencing | after `minimal_profile_service` | After the 3-field bootstrap (age/grossSalary/canton), sequence next asks by `rank_enrichment_prompts()` effective impact, not fixed order. |
| Multi-event "case" | new orchestration over ledger | A life event pulls its linked sub-collections (e.g. divorce ⇒ couple + patrimoine + dettes + goals) as one diff session. |

---

## 6. Per-field provenance contract `{source, sourceDate, updatedAt}` (the missing piece)

Today (wiring findings §B-4): mobile has `dataSources` (source only) + `dataTimestamps` (updatedAt only); backend `ProfileModel` has ONE `updated_at` for the whole profile. **Missing: `sourceDate` (when the underlying document was issued, ≠ when MINT confirmed it) and durable backend per-field provenance.** `FreshnessDecayService.weight()` explicitly uses `updatedAt`, not `sourceDate` — keep that; `sourceDate` is for display ("certificat LPP 2024") and for AVS/LPP/tax barème-year tagging.

### 6.1 Mobile — extend `CoachProfile`

```
// EXISTING (keep):
final Map<String, ProfileDataSource> dataSources;   // field path -> source
final Map<String, DateTime>          dataTimestamps; // field path -> updatedAt (when MINT set it)

// ADD:
final Map<String, DateTime?>         dataSourceDates; // field path -> sourceDate (document issue date), nullable
```

- **Key convention:** the same field path already used by `dataSources` (e.g. `prevoyance.avoirLppTotal`, `patrimoine.epargneLiquide`, top-level keys like `salaireBrutMensuel`).
- **Write rule (I-3):** every `mergeAnswers`/`applySaveFact` that sets a field MUST, in the same call, set `dataSources[path]`, `dataTimestamps[path] = now`, and `dataSourceDates[path]` (= the document date when source ∈ {certificate, openBanking}, else null). Add this to `fromWizardAnswers` reconstruction + the `copyWith` used by the provider.
- Serialize all three maps into `wizard_answers_v2` so they survive restart.

### 6.2 Backend — extend `ProfileModel`

Add sibling provenance maps alongside `data` (single `updated_at` stays for coarse sync):

```
data:          dict            # existing field values
data_sources:  dict[str, str]  # ADD: allowlist key -> backend DataSource name (see §2.2 cross-walk)
data_updated:  dict[str, str]  # ADD: allowlist key -> ISO8601 (when set)
data_source_dt: dict[str, str] # ADD: allowlist key -> ISO8601 document date (nullable)
```

- In `save_fact` (`coach_chat.py` ~1337): on every accepted write, also set `data_sources[key]` (translate the incoming mobile `ProfileDataSource` name to a backend `DataSource` name via `source_crosswalk.py`, §2.2), `data_updated[key]=now`, `data_source_dt[key]` (from the tool's optional `source_date` arg; null otherwise). Keys are the allowlist keys.
- PII redaction (PRIV-07) unchanged — provenance maps hold no raw values, only key→source/date, so they are safe to log.

### 6.3 Confidence engine wiring (already consumes source + freshness)

`enhanced_confidence_service.py` accuracy axis weights by source; freshness axis wants per-field dates. Once 6.1/6.2 land:

- **Accuracy axis:** feed backend `data_sources[key]` (already backend `DataSource` names via the §2.2 cross-walk) directly into `DATA_SOURCE_ACCURACY`. Do NOT feed raw mobile `ProfileDataSource` names — they are not keys of `DATA_SOURCE_ACCURACY` and `userInput`(.60) ≠ `user_entry`(.50). The cross-walk is the ONLY bridge; there is no second mapping.
- **Freshness axis:** feed `data_updated[key]` (backend) / `dataTimestamps[path]` (mobile) into the freshness computation per field via the §5.1 adapter, replacing profile-global `updated_at`. No new axis is added.

---

## 7. Island bridges (I-4) — make `MintUserState` never stale

`MintStateProvider.recompute()` already fires on `CoachProfileProvider` change via `ChangeNotifierProxyProvider`. The islands below mutate state WITHOUT routing through `CoachProfileProvider`, so the recompute never sees them. Fix: each island must write through the provider (preferred) OR notify it.

### 7A. Dead-road route contracts (I-2 / wiring findings §C) — required to remove the bare `Center(Text(...))`

The doc must give the per-route reads/writes/emptyState/partialState/errorState/routesOut that §F invariant 2 requires. Bind each to `route_metadata.dart` (owner/category/killFlag) + `ReadinessGate`. All state strings via `AppLocalizations`. **No `Scaffold(body: Center(Text('Document non disponible')))` may remain** (`app.dart:909`, `:924`).

| route (app.dart) | extra (ephemeral only) | reads[] (from ledger) | writes[] | entryConditions | emptyState (CTA + i18n key) | partialState | errorState (CTA + i18n key) | routesOut[] |
|---|---|---|---|---|---|---|---|---|
| `/scan/review` (~902) | `documentId : String` ONLY | `TimelineProvider.documentById(documentId)` → extracted facts; `CoachProfileProvider.profile` for current values | on confirm: `applySaveFact`/`mergeAnswers` per extracted fact, source `certificate`, `dataSourceDates[path]=doc.issueDate` | `documentId` resolves to a stored document with extracted facts | doc id unresolved (deep-link/restart/GC): show `l10n.scanReviewEmptyTitle` + `l10n.scanReviewEmptyBody`, CTA `l10n.scanReviewRescan` → `/scan` | some fields extracted, some low-confidence: render extracted, mark rest "à confirmer" | extraction failed / parse error: `l10n.scanErrorTitle` + CTA `l10n.scanRetry` → `/scan` | `/scan/impact?documentId=…`, `/rapport`, `/home` |
| `/scan/impact` (~924) | `documentId : String` ONLY | `CoachProfileProvider.profile` + `MintStateProvider.state` before/after; `initialProjectionSnapshot` | none (read-only delta view) | a confirmed `/scan/review` write happened for `documentId` | no snapshot/doc: `l10n.impactEmptyTitle` + CTA `l10n.impactBackHome` → `/home` | partial confidence: show Δ with confidence band + "à confirmer" | compute error: `l10n.impactErrorTitle` + CTA → `/home` | `/rapport`, `/home`, `/data-block/:type` |
| `/rapport` (~depends on `extra: wizardAnswers`) | NOTHING domain — remove `wizardAnswers` from extra | `CoachProfileProvider.profile` (rebuild via `ReportPersistenceService` fallback) + `MintStateProvider.state` | none | profile loaded OR persistence fallback available | still loading: skeleton, not blank | fallback slow/partial: skeleton + `l10n.reportLoading` | fallback fails: `l10n.reportUnavailableTitle` + CTA `l10n.reportRetry` (re-trigger load) → stays; secondary CTA → `/home` | `/scan`, `/data-block/:type`, `/home` |
| `/tools` (~1185) | `category : ActionCategory` (enum) | `MintStateProvider.state` for goal/context | none | always resolvable | n/a (route always renders a tools index) | n/a | n/a | resolve the specific tool by `category` instead of blanket `/coach/chat`; investment/other → dedicated tool screen, not a dead-end |
| `/portfolio` (~1189) | query params preserved | `CoachProfileProvider.profile.patrimoine` | none | always | empty patrimoine: `l10n.portfolioEmpty` + CTA → `/data-block/patrimoine` | partial | error → `/home` | `/data-block/patrimoine`, `/home` |

**Removal recipe for `app.dart:909/924`:** replace `state.extra == null → Center(Text('Document non disponible'))` with: read `documentId` from `state.pathParameters`/query, resolve via `TimelineProvider`; on null resolution render the `emptyState` row above (i18n title/body + recovery CTA), never a bare `Center(Text)`.

### 7B. Provider bridges

`depenses.*`, `conjoint.*` and other §4 field paths are NOT allowlist keys and have NO `_mapFactKeyToAnswers` case. Bridges that need to write them use the **field-path payload shape**: `mergeAnswers` accepts, in addition to `q_*` wizard keys, entries whose key is a **dotted CoachProfile field path** (prefix `fp:` to disambiguate), which `mergeAnswers` routes to the sub-model setter and records provenance for. **Task T-4 (mandatory):** extend `mergeAnswers` to accept `{'fp:depenses.loyer': 1800, ...}` entries (route by path, set value, set `dataSources`/`dataTimestamps`/`dataSourceDates`), and add a **re-entrancy guard** (`bool _mergingFromBridge`) so a bridge-triggered `notifyListeners()` → recompute cannot loop back into the same bridge.

| Island | Path (authoritative store) | Problem | Fix (mechanical) |
|---|---|---|---|
| `BudgetProvider` | `apps/mobile/lib/providers/budget/budget_provider.dart` (the provider); ancillary `domain/budget/budget_service.dart` (pure calc), `data/budget/budget_local_store.dart` (cache), `budget_living_engine.dart` (derivation) | overrides don't trigger recompute → `MintUserState.budgetGap` stale on Pulse/home | On budget override commit, call `CoachProfileProvider.mergeAnswers({'fp:depenses.loyer': v, 'fp:depenses.assuranceMaladie': v, ...})` (field-path shape, §7B) so the change flows into `CoachProfile.depenses` and recompute fires. **Authoritative store after the fix = `CoachProfile.depenses` via the provider.** `budget_local_store.dart` is DEMOTED to a non-authoritative UI cache: it may cache for fast paint but MUST NOT be the source other screens read, and MUST be re-hydrated from `CoachProfile.depenses` on load. Remove any code path where a screen reads budget domain values from `budget_local_store` instead of the ledger. |
| `HouseholdProvider` | backend-only spouse data | not synced into `CoachProfile.conjoint` → offline sims miss spouse | On household fetch/edit, first complete the spouse key still listed in §3.8 T-1 (`spouseAvsContributionYears`), then bridge it plus `conjoint.*` field-path entries through `mergeAnswers`. `spouseBirthYear` and `spouseIncomeNetMonthly` already bridge through existing wizard keys. |
| `TimelineProvider` | 4 re-fetched services | conversations (`_chat_conversation_index`) + documents (`_uploaded_documents`) in separate SharedPreferences keys, not in profile | Keep these as separate stores (not domain financial data), but surface their derived facts (e.g. a scanned LPP cert) into the ledger via `mergeAnswers`/`applySaveFact` at extraction time. Timeline reads ledger for the financial dimension; references docs/threads by id only. |
| Documents / Conversations | separate SP keys | not merged into profile | Same as above: the *extracted facts* go through `applySaveFact`; the raw documents/threads stay in their own stores (not part of the ledger, referenced by id only — never via `GoRouter.extra`, I-2). |

---

## 8. CI / test gates (make the invariants enforceable)

Each gate names exact symbols/modules so it is mechanically buildable.

### 8.1 Allowlist parity (I-7) — new test `test_ledger_parity.py`

- **8.1a** `assert len(_SAVE_FACT_ALLOWED_KEYS) == 35` (import from `app.api.v1.endpoints.coach_chat`).
- **8.1b** Parse the mobile switch: extract the set of `case '<key>':` labels in `_mapFactKeyToAnswers` (`coach_profile_provider.dart`, between `Map<String, dynamic> _mapFactKeyToAnswers` and its closing `default:`). `assert mapped_keys == _SAVE_FACT_ALLOWED_KEYS`. **On the frozen baseline `mapped_keys` has 24 entries; this assertion is RED until §3.8 T-1 lands and is the gate that proves T-1 done.**
- **8.1c** Parse §3 of this file: the set of `key` cells (excluding §4). `assert ledger_keys == _SAVE_FACT_ALLOWED_KEYS`.
- **Do NOT reuse `test_allowlist_count_is_exactly_eight`** — that test targets the DIFFERENT purpose-tagging allowlist `ALLOWED_FACT_KEYS` (`services/backend/app/services/privacy/fact_key_allowlist.py`, **8** entries), not `_SAVE_FACT_ALLOWED_KEYS`. Keep it as-is for its own purpose.

### 8.2 No extra-as-data (I-1/I-2) — lint `no_domain_from_extra`

- **Enumerated screen list:** every file under `apps/mobile/lib/screens/**` plus route builders in `app.dart`.
- **Rule:** flag any expression reading `GoRouter.state.extra`, `state.extra`, or `GoRouterState.of(context).extra` that is then cast to / accessed as a **domain type** — defined as: `CoachProfile`, any `*Profile` sub-model, `MintUserState`, `Map<String,dynamic>` named `*answers*`/`*wizard*`, or any field listed in §3/§4 (field-path or allowlist key). Reading `extra` as `String`/`int`/`enum`/an id-typed value is allowed.
- **Concrete tool:** a `custom_lint` rule (package `custom_lint`) or a repo `analyzer` plugin; ships with a unit fixture list of the current offenders (`/scan/review`, `/scan/impact`, `/rapport`) that must be zero after §7A.

### 8.3 Single write path (I-3) — grep gate `no_bypass_persistence`

- Fail if any file OUTSIDE `report_persistence_service.dart` and `coach_profile_provider.dart` contains `SharedPreferences.getInstance()` writing a domain key (`setString`/`setDouble`/… on a key matching a §3/§4 path or `wizard_answers_v2`). `budget_local_store.dart` allowed ONLY as non-authoritative cache (§7B) — it must not write `wizard_answers_v2`.
- Simulators must use `updateProfile`; grep asserts no simulator screen calls `SharedPreferences` directly.

### 8.4 No blank dead-ends (I-2/§7A) — structural test `no_dead_end_routes`

Not a bare string match. The gate has two parts:
- **8.4a** Every route in `route_metadata.dart` MUST declare non-null `emptyState`, `partialState`, `errorState` handlers (add these fields to `route_metadata.dart` if absent). Test asserts each of the 5 §7A routes has all three, each returning a widget whose subtree contains at least one `AppLocalizations`-sourced string AND at least one navigating CTA (`context.go`/`context.push`).
- **8.4b** Regression guard: assert the French literal `Document non disponible` no longer appears anywhere under `app.dart` (grep ⇒ zero hits). This is a narrow regression check on the KNOWN dead-ends, not the whole gate — 8.4a is the real gate. It does NOT flag legitimate centered-text screens because it targets one specific dead-end literal, not the `Center(Text(...))` shape.

### 8.5 Provenance set on write (§6) — unit test

After any `mergeAnswers`/`applySaveFact`/field-path write, the affected field paths MUST exist in `dataSources` AND `dataTimestamps` (and `dataSourceDates` present, possibly null). Test drives one write per §3 key + a sample of §4 paths.

### 8.6 Cross-walk correctness (§2.2) — unit test `test_source_crosswalk.py`

Assert `source_crosswalk.py` maps every mobile `ProfileDataSource` member to the backend `DataSource` per the §2.2 table, and that each backend target is a key of `DATA_SOURCE_ACCURACY`. Assert `certificate → document_scan_verified` and `userInput → user_entry` explicitly.

### 8.7 Freshness adapter (§5.1) — unit tests

- `weightForField` returns 1.0 for `static` fields regardless of age.
- With no BiographyFact and no `dataTimestamps[path]` ⇒ returns floor 0.30.
- `annual`: full@≤12mo → 0.30@≥36mo; `volatile`: full@≤3mo → 0.30@≥12mo; `needsRefresh` true below 0.60 (extend existing `FreshnessDecayService` tests; constants `_floor=0.3`, `_refreshThreshold=0.60`).

### 8.8 Ranged projections (I-5)

Test: every projection widget renders a range + `EnhancedConfidence`; `ComplianceGuard` blocks banned terms.

---

## 9. End-to-end write/read flow (the only legal path)

```mermaid
flowchart TD
  subgraph Inputs["Write sources (all converge on the provider)"]
    W[Wizard q_* answers]
    C[Coach save_fact tool]
    S[Scan / OCR extraction]
    SIM[Simulators]
    B[BudgetProvider override]
    H[HouseholdProvider spouse]
  end

  C -->|canonical allowlist key| AF[CoachProfileProvider.applySaveFact]
  AF -->|_mapFactKeyToAnswers → q_* / _coach_*| MA
  W --> MA[CoachProfileProvider.mergeAnswers]
  S --> MA
  B -->|bridge: fp:depenses.* payload| MA
  H -->|bridge: spouse keys + fp:conjoint.*| MA
  SIM --> UP[CoachProfileProvider.updateProfile]

  MA --> PERS[(report_persistence_service<br/>wizard_answers_v2 SP)]
  UP --> PERS
  MA -. set .-> PROV[dataSources + dataTimestamps + dataSourceDates]
  PERS --> RC[CoachProfile.fromWizardAnswers]
  RC --> CP[(CoachProfile = THE ledger)]
  CP --> PROX[ChangeNotifierProxyProvider]
  PROX --> MS[MintStateProvider.recompute -> MintUserState]

  MS --> SCREENS[Every screen: context.watch MintStateProvider .state]
  CP --> SCREENS

  MA -.->|fire-and-forget + §2.2 crosswalk| BE[(Backend ProfileModel.data<br/>+ data_sources/data_updated/data_source_dt)]

  X[GoRouter.extra] -. ids / enums / ephemeral selection ONLY .-> SCREENS
  X -. NEVER domain data .-x SCREENS
```

**Reading rule:** a screen NEVER reaches into `PERS`, `BE`, or `X` for domain data. It reads `CP`/`MS`. That is the ledger.
