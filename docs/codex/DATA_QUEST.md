# DATA_QUEST.md — MINT diff-not-form collection engine (Codex-executable)

> **Baseline note:** file:line references were originally audited against `apps/mobile/` and `services/backend/` at commit `255373b`, then corrected on this branch. Treat every reference as a HEAD contract and re-verify after code movement.

> **Status:** normative spec for the coding agent. Mechanical, deterministic, initially grounded in the REAL code at commit `255373b` and corrected against branch HEAD.
> **Companions:** `DATA_LEDGER.md` (fields + provenance), `SCREEN_CONTRACTS.md` (per-screen `reads[]`), `WIRING_GRAPH.mmd` (invariants).
> **Conflict order:** `rules.md` > `CLAUDE.md` > this file. This file does not override compliance (education-not-advice; ranges + `EnhancedConfidence`; no promissory terms).

## 0. One sentence

When any surface needs data it does not have, MINT asks **only the missing or stale delta** — ranked by impact, gentle for heavy events, answerable partially — and writes it back through the single ledger write-path; stale data is **re-confirmed in one tap, never re-asked blank**.

## 1. What already exists (REUSE — do not rebuild)

| Capability | Real artefact (verified) |
|---|---|
| Typed collection block | `/data-block/:type` → `screens/onboarding/data_block_enrichment_screen.dart` (renders confidence bar + ranked enrichment prompts + cross-validation; dual mode form / `coach/chat?topic=`; supported blocks include `revenu`, `lpp`, `avs`, `3a`, `patrimoine`, `fiscalite`, `objectifRetraite`, `compositionMenage`) |
| Impact-ranked prompts | `ConfidenceScorer.score(CoachProfile) → ProjectionConfidence{ double score, String level, List<EnrichmentPrompt> prompts, List<String> assumptions }` (`financial_core/confidence_scorer.dart:138`; `ProjectionConfidence` at `:43`, `ConfidenceScorer` at `:104`); backend mirror `enhanced_confidence_service.py` (`rank_enrichment_prompts` at `:406`) |
| Per-block score | `ConfidenceScorer` → `BlockScore` (`confidence_scorer.dart:63`) |
| Staleness | `FreshnessDecayService.needsRefresh(BiographyFact, DateTime) → bool` (weight < `0.60` at `freshness_decay_service.dart:39,254`); `weight()` = annual (full 12mo→floor 36mo at `:43,46`) / volatile (full 3mo→floor 12mo at `:50,53`), implementation at `:165-174` |
| Fact store | `BiographyRepository` (encrypted SQLite) — immutable `BiographyFact{ fieldPath, value, source, sourceDate, updatedAt, freshnessCategory }`; read via `getLatestFactForField(fieldPath)` (`biography_repository.dart:263`), write via `insertFact(fact)` (`:163`) / `recordFact(fact)` (`:276`) |
| Write path | `CoachProfileProvider.mergeAnswers()` (`:579`) / `applySaveFact()` (`:673`) / full-profile `updateProfile()` (`:1366`) — the ONLY mutators |
| Coach write allow­list | `_SAVE_FACT_ALLOWED_KEYS` (40 keys, `coach_chat.py:1071`); mobile map `_mapFactKeyToAnswers` (`coach_profile_provider.dart:871`) |
| Field→screen mapping | `apps/mobile/lib/routes/route_metadata.dart` exposes `RouteMeta` + `kRouteRegistry`; `SCREEN_CONTRACTS.md` owns `reads[]`, `entryConditions`, and `partialState` as executable documentation contracts. HEAD does **not** expose `ScreenRegistry` or `ReadinessGate` runtime classes. |
| Freshness prompt templates | private fallback labels already present: `freshnessConfirm`, `freshnessStale`, `freshnessPrefix` (`confidence_scorer.dart:747-749`). HEAD also has ARB-backed reconfirm keys `freshnessReconfirmPrompt`, `freshnessReconfirmYes`, `freshnessReconfirmUpdate`, and `freshnessReconfirmRescan` in all six `app_*.arb` files; `flutter gen-l10n` generated `S.freshnessReconfirm*`, and ARB parity is enforced. |
| P0 Data Quest planner | `apps/mobile/lib/services/data_quest/data_quest_service.dart` + import shim `data_quest/case_registry.dart`; plans `first_salary_tax`, `buy_property`, `transmit_property` from raw `wizard_answers_v2` answers so defaults in `CoachProfile.fromWizardAnswers()` do not hide missing values. Runtime consumers: `/pilier-3a`, `/hypotheque`, and `/succession` proof strips expose `next_ask`, `ask_mode`, and `ask_stage` under runtime-proof semantics. |
| P0 dossier payload | `apps/mobile/lib/services/dossier/dossier_payload_service.dart`; builds schema-checked `DossierPayload` for `first_salary_tax`, `buy_property`, `transmit_property` with every input tagged `{value, source, confidence, updated_at, source_date}` and scenario assumptions explicit. Guard: `test/services/dossier/dossier_payload_service_test.dart` validates each payload against `docs/codex/dossier_stubs/dossier_*.schema.json`. |
| Backend mortgage scenario | `services/backend/app/api/v1/endpoints/scenarios.py` handles `kind="mortgage"` via `AffordabilityService.calculate_affordability()`. It returns `missing_data` instead of placeholder outputs when `incomeGrossYearly`, `patrimoine.epargneLiquide`, or `targetPropertyValue` are absent. The P0 `stressInterestRate` assumption is not a magic constant: `docs/codex/P0_CASE_VARIABLE_REGISTRY.json` points it to `mortgage.theoretical_rate`, backed by `services/backend/app/services/regulatory/registry.py` and `mcp__mint_tools.get_swiss_constants(category="mortgage")`. Owned-property inputs (`patrimoine.propertyMarketValue`, `propertyMarketValue`) are deliberately not compatibility aliases for `buy_property`; they remain reserved for transmission/succession flows. Guard: `services/backend/tests/test_scenarios.py::test_create_mortgage_scenario_*`, included in `tools/checks/mint_lucidity_gate.sh backend-scenarios`. |
| Backend suggested actions ranker | `coach_chat.py` `_compute_suggested_actions()` is wired to `enhanced_confidence_service.rank_enrichment_prompts()`; guard: `services/backend/tests/test_suggest_actions_enrichment.py` covers basic profile, high-quality sources, and `_provenance` source store. |

**Freshness threshold split is deliberate:** Data Quest reconfirm asks use
`FreshnessDecayService.needsRefresh()` at weight `< 0.60`; confidence enrichment
prompts in `ConfidenceScorer.scoreEnhanced()` surface earlier at decay `< 0.70`.
The former is an action-level "confirm this fact now" threshold; the latter is a
softer dashboard nudge. Do not infer that every freshness prompt must become an
inline Data Quest reconfirm ask.

## 2. The `DataQuest` object (conceptual target; P0 runtime uses `planCase`)

```
DataQuest {
  targetId        // screen route OR computation id that triggered the quest
  requiredFields  // List<LedgerKey> — from SCREEN_CONTRACTS.reads[target]
  caseId?         // set when part of a multi-event CASE (§5)
  goal            // Phase 5 target, NOT in P0 planCase(); GoalA/GoalB ranking
}
```

P0 runtime does not instantiate this class yet. The executable implementation is
`DataQuestService.planCase(caseId, answers, now, factsByLedgerKey,
includeUseful)`; it covers the same planner responsibilities for the three P0
cases without a public `DataQuest` wrapper, `targetId`, or `goal` parameter.

### 2.1 Deterministic algorithm (pseudocode — staged P0 profile adapter)

```
List<Ask> planCase(caseSpec, Map answers,
                   Map<LedgerKey, BiographyFact> factsByLedgerKey,
                   DateTime now, bool includeUseful):
  tone = caseSpec.heavyEvent ? Tone.gentle : Tone.plain

  guardAsks = buildAsks(caseSpec.guardFields, stage=guard)
  if guardAsks.isNotEmpty: return guardAsks              // EARLY RETURN

  requiredAsks = buildAsks(caseSpec.requiredFields, stage=required)
  if requiredAsks.isNotEmpty: return requiredAsks        // EARLY RETURN

  if includeUseful:
     return buildAsks(caseSpec.usefulFields, stage=useful)

  return []                                             // quest satisfied

List<Ask> buildAsks(fields, stage):
  delta = []
  for field in fields:
     value = _answerFor(field, answers)
     if value == null:
        delta.add(field as missing)
     else:
        fact = factsByLedgerKey[field.ledgerKey]
            ?? factsByLedgerKey[field.inputKey]          // profile provenance may use either key in P0
        if fact != null && FreshnessDecayService.needsRefresh(fact, now):
           delta.add(field as stale)                     // present but weight < 0.60

  // ONLY the delta for the current stage is surfaced. Fields already fresh are
  // never re-asked, and later stages are hidden until earlier stages are clear.
  ranked = orderBy(delta, field => field.priority)       // HEAD behavior
  return ranked.map(field => Ask(
     key: field.inputKey,
     stage: stage,
     mode:  field is stale ? AskMode.reconfirm
          : field.ledgerKey == null ? AskMode.scenarioAssumption
          : AskMode.collect,
     tone:  tone,
     prior: field is stale ? value : null,
  ))
```

`_answerFor(field, answers)` must preserve the code's `allowZero` semantics:
zero is a valid answer for fields where 0 is meaningful (`avoirLpp`,
`pillar3aBalance`, `parentLiquidAssets`, `mortgageBalance`, `heirsCount`);
fields without `allowZero` require a positive number (`value > 0`).

For transaction-only assumptions that are not durable ledger facts
(`cashPaidByRecipient`, `mortgageAssumedByRecipient`, `recipientRelationship`,
`retainedRight`, `avancementHoirie`), the P0 planner exposes
`AskMode.scenarioAssumption` when `includeUseful=true`. These asks must be
labelled as scenario assumptions with source/confidence in dossier output; they
must not become silent calculator defaults.

Phase 4 may replace `factsByLedgerKey` with direct
`BiographyRepository.getLatestFactForField(key)` reads, but that is not the
current runtime contract.

For fields marked `requiresCompleteFact`, a present answer-map value is not
enough to satisfy the field when no dated `BiographyFact` exists. This is
intentional for aggregates such as `parentAnnualLivingCosts`: a partial period
amount without `q_housing_cost_frequency`/source timestamp stays in
`AskMode.reconfirm` until the dossier/profile bridge emits a complete stamped
fact. Guard:
`data_quest_service_test.dart::transmit_property reconfirms partial living-cost
answer without dated fact`.

### 2.2 Rendering rule (partial-graceful — NEVER a wall)

- The target screen renders **immediately** with whatever is known, using its `partialState` (SCREEN_CONTRACTS) — result shown as a **range + `EnhancedConfidence`** (compliance I-5). No "complete to continue" gate.
- Outstanding `Ask`s appear as **inline, dismissible prompts** ("pour préciser : …"), ordered by rank, at most **one primary Ask visible at a time** (north-star: one true thing).
- Each answered `Ask` → write-back (§6) → recompute → the range tightens visibly. This is the payoff loop.

## 3. Stale = re-confirm, not re-ask (`AskMode.reconfirm`)

When `FreshnessDecayService.needsRefresh(fact, now)` is true, the Ask is a **1-tap confirmation**, not a blank field:

```
"On avait noté {label} à {prior} ({sourceDate}). Toujours d'accord ?"
   [ Oui, toujours ]   [ Mettre à jour ]   [ Rescanner ]
```

- **Oui** → `CoachProfileProvider.mergeAnswers({wizardKeyFor(key): prior})` with provenance `{updatedAt: now}` → resets freshness to 1.0. `updateProfile()` is only for full-profile replacement; do not construct a partial `CoachProfile` for one reconfirmed field.
- **Mettre à jour** → collect flow for that one key.
- **Rescanner** → route to `/scan?type=<dataBlockType>` from the current
  `/data-block/:type` context, preserving the block type alias rules already
  used by `data_block_enrichment_screen.dart`. The scan/review flow remains the
  only path that can turn a new document into ledger writes.
- Use these ARB-backed i18n keys in all six languages before rendering any
  user-facing reconfirm UI: `freshnessReconfirmPrompt`,
  `freshnessReconfirmYes`, `freshnessReconfirmUpdate`,
  `freshnessReconfirmRescan`. They are modelled on the existing private
  fallback labels `freshnessConfirm` / `freshnessStale`
  (`confidence_scorer.dart:747`). Hardcoded French prose in this widget is a
  spec violation.

Phase 2 reconfirm activation is deliberately conservative: a value is
reconfirmed only when profile provenance carries a usable `sourceDate` or
`updatedAt` and the derived `BiographyFact` is stale. Legacy answers without
persisted provenance are treated as known values, not false-stale values; a
Phase 4 migration/backfill must decide how to date and reconfirm them.

## 4. Heavy events get a conversational quest, not a form wall

HEAD runtime does not expose an `isHeavyEvent(targetId)` function. The live
pattern is a per-case flag: `DataQuestCaseSpec.heavyEvent == true` produces
`DataQuestTone.gentle` in `DataQuestService.planCase()`. P0 currently uses that
flag for `transmit_property`; future Q-6 cases such as divorce, décès proche,
invalidité, and debt must use the same flag pattern when their case specs land.

For heavy events: the quest runs **inside the coach conversation**
(`Tone.gentle`), reassurance first, one Ask per turn, no auto-advance,
dignified exit loses nothing (partial answer persists). For light events
(`/first-job`, simulators) the `/data-block/:type` form is fine.

## 5. The multi-event `CASE` (new — the entanglement fix)

A life event is rarely one event. A `CASE` groups linked quests so a locally-correct answer is never globally wrong.

```
Case {
  rootEvent      // e.g. "transmit_property"
  quests[]       // ordered DataQuests
  guardQuests[]  // MUST run before the root can conclude
}
```

Example — `transmit_property`:
- `guardQuests` = [ retirement-affordability quest ] → *before* modelling a gift, the quest for the parents' own retirement gap runs (reads `avoirLpp`, `pillar3aBalance`, `targetRetirementAge`). If giving breaks their funding, MINT surfaces that **first**.
- `quests` = [ property value+mortgage, matrimonial regime, heirs count/relationship, canton ].
Case resolution in HEAD is implemented by `DataQuestCaseSpec.guardFields` →
`requiredFields` → `usefulFields` staged early-return. It does not call a
`ReadinessGate` runtime API.

`P0_CASE_VARIABLE_REGISTRY.json.minimum_variables` is an acceptance shorthand
for the case's required `input_key` aliases. It is not a canonical ledger-key
list. Automation that needs ledger paths must read `variables[].ledger_key`.

## 6. Write-back (single path — enforces WIRING I-3)

**Phase 2–3 authority:** runtime freshness is backed by
`CoachProfile.dataSources`, `CoachProfile.dataTimestamps`, and
`CoachProfile.dataSourceDates`, all stamped by
`CoachProfileProvider.mergeAnswers()`. `/succession` converts that profile
metadata into `BiographyFact` inputs for `DataQuestService.planCase()`.

**Phase 4 integration:** `BiographyRepository.recordFact()` remains the durable
immutable fact graph target. Do not claim repository-backed Data Quest until
`mergeAnswers()` also records DATA_LEDGER writes there, or until this spec is
revised with a deliberate replacement architecture.

```
onAnswer(key, value, source):
   assert key in DATA_LEDGER                       // CI gate: test_codex_ledger_parity.py
   if source is coach-originated:
       assert key in _SAVE_FACT_ALLOWED_KEYS       // 40-key contract
       CoachProfileProvider.applySaveFact(key, value)   // maps via _mapFactKeyToAnswers
   else:
       CoachProfileProvider.mergeAnswers({ wizardKeyFor(key): value })
   // Phase 2-3: stamp CoachProfile metadata for runtime freshness.
   /*
   PHASE 4 — NOT ACTIVE IN CURRENT RUNTIME.
   Once DATA_LEDGER writes are repository-backed, append an immutable fact:
   BiographyRepository.recordFact(BiographyFact(
       fieldPath: key, value: value, source: source,
       sourceDate: now, updatedAt: now,
   ))                                              // recordFact delegates to insertFact
   END PHASE 4.
   */
   // recompute is automatic via mergeAnswers() -> notifyListeners().
   // MintStateProvider specifically recomputes via app.dart:2114-2126.
```
No screen writes SharedPreferences / `ProfileModel.data` directly.

## 7. The missing 30% to BUILD (with target files)

| # | Gap | Build target |
|---|---|---|
| Q-1 | Per-field provenance `{source, sourceDate, updatedAt}` exists in `CoachProfile` metadata for mobile runtime freshness and backend `save_fact` mirrors canonical facts to `ProfileModel.data['_provenance']` | decide in Phase 4 whether `BiographyRepository.recordFact()` becomes additive evidence or the canonical fact graph; until then, mobile `CoachProfile` metadata and backend `_provenance` are the runtime sources |
| Q-2 | `DataQuest`/`Case` P0 pure planner exists, and `/succession` passes profile metadata as `BiographyFact` freshness context; repository-backed orchestration is still Phase 4 | extend `apps/mobile/lib/services/data_quest/data_quest_service.dart` from current pure planner/profile adapter to async BiographyRepository-backed orchestration if the repository remains canonical |
| Q-3 | `/data-block/:type` has no delta/before-after UI, no reconfirm | i18n precondition is now met: `freshnessReconfirm*` and Data Block revenue keys exist in all six `.arb` files and generated `S` classes; next build target is the `AskMode.reconfirm` widget (§3). Guard: `tools/checks/tests/test_data_quest_i18n_preconditions.py` fails today if keys disappear or if Data Block revenue hardcodes French labels. Once a non-planner reconfirm widget lands, the same test file also enforces ARB-backed reconfirm labels and forbids `updateProfile()` in that UI. |
| Q-4 | Backend `suggest_actions` ranker wiring is done | keep `services/backend/tests/test_suggest_actions_enrichment.py` in the backend gate so `_compute_suggested_actions()` continues to match `enhanced_confidence_service.rank_enrichment_prompts()` and reads `_provenance` metadata |
| Q-5 | Goal-aware ranking absent (ranker is generic) | add `impactOf(key, prompts, goal)` weighting in `confidence_scorer.dart` |
| Q-6 | P0 `Case` registry exists for `first_salary_tax`, `buy_property`, `transmit_property`; broader heavy-event registry is still missing | extend `data_quest/case_registry.dart` beyond P0 with `divorce`, `retirement`, `invalidite`, and debt cases after Phase 2 acceptance. Registry tiers are `blocking_guard_questions` → Dart `guardFields`, `required_questions` → Dart `requiredFields`, and `enrichment_questions` → Dart `usefulFields`; tests must preserve this 1:1 mapping. |
| Q-7 | Legacy wizard answers without `_coach_data_timestamps` cannot be safely stale-classified | Phase 4 gate must include either a timestamp/source-date backfill migration, or an explicit product guard that treats legacy answers as fresh until migration and never shows false reconfirm prompts |
| Q-8 | `/rapport` now builds and exports the three P0 typed dossiers, but its main narrative cards still come from `FinancialReportService` | Future product work can make the whole report dossier-first; current contract is visible P0 dossier section + typed PDF export with explicit `next_questions` gaps. Widget/gate proof covers all three dossier cards/CTAs; Maestro runtime interaction remains scoped to `transmit_property`. |

## 8. Acceptance criteria (Codex/CI must verify)

- **DQ-1** A screen with all `reads[]` fresh triggers **zero** Asks (planQuest returns []).
- **DQ-2** A screen missing k fields in the **current stage** surfaces exactly
  k Asks, ordered by `DataQuestFieldSpec.priority` at HEAD. Later stages are
  hidden until earlier guard/required stages are clear. Q-5 later upgrades
  within-stage ordering to `ConfidenceScorer` impact + goal-aware ranking. It
  is never a blocking wall (partialState renders).
- **DQ-3** Planner layer: a field with `needsRefresh==true` produces an `AskMode.reconfirm`, never a blank collect ask (`data_quest_service_test.dart`). UI rendering of the 1-tap "Oui / Mettre à jour / Rescanner" widget remains Q-3 in §7.
- **DQ-4** Every write goes through `CoachProfileProvider` /
  `ReportPersistenceService`; `tools/checks/tests/test_no_bypass_persistence.py`
  scans `apps/mobile/lib/**` so no other production writer can persist
  `wizard_answers_v2`, `q_*`, `_coach_*`, `fp:*`, or ledger path keys directly.
  The `mobile-scenarios` gate runs this check because Data Quest acceptance
  depends on the single write path.
- **DQ-5** `transmit_property` Case runs the retirement-affordability guardQuest before rendering any gift result.
- **DQ-6** Every rendered projection carries range + `EnhancedConfidence` (compliance).
- **DQ-7** Every P0 dossier payload validates against its JSON schema and every input/assumption carries source+confidence metadata (`test/services/dossier/dossier_payload_service_test.dart`).
- **DQ-8** `/rapport` renders visible P0 dossier cards and exports a typed dossier PDF through `report_dossier_<case>_export_cta` (`test/screens/report_route_screen_test.dart`).
