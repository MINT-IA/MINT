# DATA_QUEST.md — MINT diff-not-form collection engine (Codex-executable)

> **Baseline note:** all `file:line` references target `apps/mobile/` and `services/backend/` at commit `255373b`. Those trees are **UNCHANGED on this branch** — the only commits since are additions under `docs/codex/`. Therefore every code reference below is valid at the current branch HEAD; verify against HEAD directly.

> **Status:** normative spec for the coding agent. Mechanical, deterministic, grounded in the REAL code at commit `255373b`.
> **Companions:** `DATA_LEDGER.md` (fields + provenance), `SCREEN_CONTRACTS.md` (per-screen `reads[]`), `WIRING_GRAPH.mmd` (invariants).
> **Conflict order:** `rules.md` > `CLAUDE.md` > this file. This file does not override compliance (education-not-advice; ranges + `EnhancedConfidence`; no promissory terms).

## 0. One sentence

When any surface needs data it does not have, MINT asks **only the missing or stale delta** — ranked by impact, gentle for heavy events, answerable partially — and writes it back through the single ledger write-path; stale data is **re-confirmed in one tap, never re-asked blank**.

## 1. What already exists (REUSE — do not rebuild)

| Capability | Real artefact (verified) |
|---|---|
| Typed collection block | `/data-block/:type` → `screens/onboarding/data_block_enrichment_screen.dart` (renders confidence bar + ranked enrichment prompts + cross-validation; dual mode form / `coach/chat?topic=`) |
| Impact-ranked prompts | `ConfidenceScorer.score(CoachProfile) → ProjectionConfidence{ double score, String level, List<EnrichmentPrompt> prompts, List<String> assumptions }` (`financial_core/confidence_scorer.dart:138`, class at `:43`); backend mirror `enhanced_confidence_service.py` (`rank_enrichment_prompts`) |
| Per-block score | `ConfidenceScorer` → `BlockScore` (`confidence_scorer.dart:63`) |
| Staleness | `FreshnessDecayService.needsRefresh(BiographyFact, DateTime) → bool` (weight < `0.60`); `weight()` = annual (full 12mo→floor 36mo) / volatile (full 3mo→floor 12mo) (`biography/freshness_decay_service.dart:64,91`) |
| Fact store | `BiographyRepository` (encrypted SQLite) — immutable `BiographyFact{ fieldPath, value, source, sourceDate, updatedAt, freshnessCategory }`; read via `getLatestFactForField(fieldPath)`, write via `insertFact(fact)` / `recordFact(fact)` (`biography_repository.dart:163,263,276`) |
| Write path | `CoachProfileProvider.mergeAnswers()` (`:502`) / `applySaveFact()` (`:542`) / `updateProfile()` (`:969`) — the ONLY mutators |
| Coach write allow­list | `_SAVE_FACT_ALLOWED_KEYS` (35 keys, `coach_chat.py:924`); mobile map `_mapFactKeyToAnswers` (`coach_profile_provider.dart:557`) |
| Field→screen mapping | `ScreenRegistry` + `ReadinessGate` (behaviors A–E) + `routes/route_metadata.dart` |
| Freshness i18n | keys already present: `freshnessConfirm`, `freshnessStale`, `freshnessPrefix` (`confidence_scorer.dart:747-749`) |

## 2. The `DataQuest` object (new — the orchestrator this doc specifies)

```
DataQuest {
  targetId        // screen route OR computation id that triggered the quest
  requiredFields  // List<LedgerKey> — from SCREEN_CONTRACTS.reads[target]
  caseId?         // set when part of a multi-event CASE (§5)
  goal            // CoachProfile.goal (GoalA/GoalB) — for goal-aware ranking
}
```

### 2.1 Deterministic algorithm (pseudocode — calls REAL methods)

```
List<Ask> planQuest(DataQuest q, CoachProfile profile, DateTime now):
  missing   = []
  stale     = []
  for key in q.requiredFields:
     if !profile.has(key):                                    // value absent
        missing.add(key)
     else:
        fact = BiographyRepository.getLatestFactForField(key) // provenance record (or null)
        if fact != null && FreshnessDecayService.needsRefresh(fact, now):
           stale.add(key)                                     // present but weight < 0.60
  // ONLY the delta is ever surfaced. Fields already fresh are never re-asked.
  delta = missing ++ stale
  if delta.isEmpty: return []                                 // quest satisfied → render now

  // Rank by impact, then goal-awareness. Reuse the existing ranker.
  prompts = ConfidenceScorer.score(profile).prompts          // impact-ranked
  ranked  = orderBy(delta, key => impactOf(key, prompts, q.goal))
  return ranked.map(key => Ask(
     key,
     mode:  key in stale ? AskMode.reconfirm : AskMode.collect,   // §3
     tone:  isHeavyEvent(q.targetId) ? Tone.gentle : Tone.plain,  // §4
     prior: key in stale ? profile.get(key) : null,               // show old value
  ))
```

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

- **Oui** → `CoachProfileProvider.updateProfile(key: same value)` → resets `updatedAt=now` (freshness back to 1.0). No re-entry.
- **Mettre à jour** → collect flow for that one key.
- Use existing i18n keys `freshnessConfirm` / `freshnessStale` (`confidence_scorer.dart:747`).

## 4. Heavy events get a conversational quest, not a form wall

`isHeavyEvent(targetId)` = targetId in { `/divorce`, `/life-event/deces-proche`, `/succession`, `/invalidite`, `/debt/*` }.
For these: the quest runs **inside the coach conversation** (`Tone.gentle`), reassurance first, one Ask per turn, no auto-advance, dignified exit loses nothing (partial answer persists). For light events (`/first-job`, simulators) the `/data-block/:type` form is fine.

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
Case resolution reuses `ReadinessGate` behaviors A–E to decide when enough is known to render each sub-result.

## 6. Write-back (single path — enforces WIRING I-3)

```
onAnswer(key, value, source):
   assert key in DATA_LEDGER                       // I-7 of DATA_LEDGER
   if source is coach-originated:
       assert key in _SAVE_FACT_ALLOWED_KEYS       // 35-key contract
       CoachProfileProvider.applySaveFact(key, value)   // maps via _mapFactKeyToAnswers
   else:
       CoachProfileProvider.mergeAnswers({ wizardKeyFor(key): value })
   // record provenance (the missing-30%, §7) — append an immutable fact:
   BiographyRepository.recordFact(BiographyFact(
       fieldPath: key, value: value, source: source,
       sourceDate: now, updatedAt: now,
   ))                                              // recordFact delegates to insertFact
   // recompute is automatic via ChangeNotifierProxyProvider (app.dart:1466)
```
No screen writes SharedPreferences / `ProfileModel.data` directly.

## 7. The missing 30% to BUILD (with target files)

| # | Gap | Build target |
|---|---|---|
| Q-1 | Per-field provenance `{source, sourceDate, updatedAt}` not durable end-to-end | add `dataSources`/`dataTimestamps` write in `coach_profile_provider.dart` mergeAnswers; mirror to backend `ProfileModel` (add per-field `field_meta` JSON) in `coach_chat.py` save_fact |
| Q-2 | `DataQuest`/`Case` orchestrator does not exist | new `apps/mobile/lib/services/data_quest/data_quest_service.dart` implementing §2–§5 |
| Q-3 | `/data-block/:type` has no delta/before-after UI, no reconfirm | extend `data_block_enrichment_screen.dart` with `AskMode.reconfirm` widget (§3) |
| Q-4 | Backend `suggest_actions` is hardcoded, not the ranker | wire `suggest_actions` → `enhanced_confidence_service.rank_enrichment_prompts()` |
| Q-5 | Goal-aware ranking absent (ranker is generic) | add `impactOf(key, prompts, goal)` weighting in `confidence_scorer.dart` |
| Q-6 | No `Case` registry mapping events→guardQuests | new `data_quest/case_registry.dart`; seed with `transmit_property`, `divorce`, `retirement` |

## 8. Acceptance criteria (Codex/CI must verify)

- **DQ-1** A screen with all `reads[]` fresh triggers **zero** Asks (planQuest returns []).
- **DQ-2** A screen missing k fields surfaces exactly k Asks, ordered by `ConfidenceScorer` impact; never a blocking wall (partialState renders).
- **DQ-3** A field with `needsRefresh==true` produces an `AskMode.reconfirm` (1-tap), never a blank field.
- **DQ-4** Every write goes through `CoachProfileProvider` (grep: no other writer of `wizard_answers_v2`).
- **DQ-5** `transmit_property` Case runs the retirement-affordability guardQuest before rendering any gift result.
- **DQ-6** Every rendered projection carries range + `EnhancedConfidence` (compliance).