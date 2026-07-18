# DATA_QUEST.md — MINT diff-not-form collection engine (Codex-executable)

> **G1 reality audit:** `file:line` references were re-checked against HEAD `095eeaa32` on 2026-07-07. Treat line refs as evidence snapshots, not evergreen truth. Rerun `tools/checks/tests/test_codex_spec_reality_contract.py` after changing this spec or the cited code.

> **Status:** target contract for the coding agent. Mechanical, deterministic, with live gaps called out against the REAL code at commit `095eeaa32`.
> **Companions:** `DATA_LEDGER.md` (fields + provenance), `SCREEN_CONTRACTS.md` (per-screen `reads[]`), `WIRING_GRAPH.mmd` (invariants).
> **Conflict order:** `rules.md` > `CLAUDE.md` > this file. This file does not override compliance (education-not-advice; ranges + `EnhancedConfidence`; no promissory terms).
>
> **Focused RET-REF-01 reuse snapshot:** the bounded fiscal-reference delta is
> code-GREEN at exact pushed SHA `cdc786782` (2026-07-17). It reuses the existing
> ConfidenceScorer/DataBlock prompt and does not implement the missing generic
> DataQuest orchestrator, promote the ticket, close G1 or authorize G2/G3.
>
> **Focused LPP regulation handoff boundary:** the production code vertical at
> `deb199c7f` ends in six specialist-preparation questions. They are static,
> conditional educational prompts over one exact metadata reference, not
> `DataQuest` Asks: they collect no answer, rank no product and write no fact.
> Runtime/activation remain NO-GO.

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
| Coach write allow­list | `_SAVE_FACT_ALLOWED_KEYS` (36 keys, `coach_chat.py:924`); mobile map `_mapFactKeyToAnswers` (`coach_profile_provider.dart:557`) |
| Field→screen mapping | `ScreenRegistry` + `ReadinessGate` (behaviors A–E) + `routes/route_metadata.dart` |
| Freshness i18n | keys already present: `freshnessConfirm`, `freshnessStale`, `freshnessPrefix` (`confidence_scorer.dart:747-749`) |
| Fiscal specialist-reference delta | `ConfidenceScorer.score` reuses `EnrichmentPrompt.taxDocument` (`tax.document.review`, `fiscal.assessedBaseline`, category `fiscalite`). Exact coherent reference suppresses it; every non-exact state keeps it in `/data-block/fiscalite`, whose fiscal CTA routes to `/fiscal` (`cdc786782`). |

For this focused fiscal delta, `latestTaxDecisionReference` is metadata derived
from the unique `_coach_tax_snapshots_v1` authority after exact provenance
validation. `ConfidenceScorer` keeps the existing latest-completeness query
status-only and uses the public precise selector for tax year, subject, canton
and exact snapshot identity. Missing, ineligible, future, mismatched or
same-rank-conflicted evidence therefore yields the existing Ask; an exact
coherent reference yields no tax-document Ask. `legalYear == taxYear` records
provenance and is not an annual TTL. This reuse adds no `DataQuest` service,
Case, storage key, backend mirror or financial calculation, so Q-2 below remains
an honest gap.

## 2. The `DataQuest` object (new — the orchestrator this doc specifies)

```
DataQuest {
  targetId        // screen route OR computation id that triggered the quest
  requiredFields  // List<LedgerKey> — from SCREEN_CONTRACTS.reads[target]
  caseId?         // set when part of a multi-event CASE (§5)
  goal            // CoachProfile.goal (GoalA/GoalB) — for goal-aware ranking
}
```

### 2.1 Deterministic algorithm (pseudocode — calls REAL instance methods)

```
List<Ask> planQuest(DataQuest q, CoachProfile profile, DateTime now):
  missing   = []
  stale     = []
  for key in q.requiredFields:
     if !profile.has(key):                                    // value absent
        missing.add(key)
     else:
        fact = await biographyRepo.getLatestFactForField(key) // provenance record (or null)
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
       assert key in _SAVE_FACT_ALLOWED_KEYS       // 36-key contract
       CoachProfileProvider.applySaveFact(key, value)   // maps via _mapFactKeyToAnswers
   else:
       CoachProfileProvider.mergeAnswers({ wizardKeyFor(key): value })
   // record provenance (the missing-30%, §7) — append an immutable fact:
      await biographyRepo.recordFact(BiographyFact(
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
| Q-2 | `DataQuest`/`Case` orchestrator does not exist at `095eeaa32` | new `apps/mobile/lib/services/data_quest/data_quest_service.dart` implementing §2–§5 |
| Q-3 | `/data-block/:type` has no delta/before-after UI, no reconfirm | extend `data_block_enrichment_screen.dart` with `AskMode.reconfirm` widget (§3) |
| Q-4 | Backend `suggest_actions` is hardcoded, not the ranker | wire `suggest_actions` → `enhanced_confidence_service.rank_enrichment_prompts()` |
| Q-5 | Goal-aware prompt ranking is live for mobile `ConfidenceScorer.score()` visible prompts and `scoreEnhanced()` axis prompts: prompts carry `fieldPath`, and sorting uses goal-aware effective impact without changing displayed impact points | Keep `confidence_scorer_test.dart` coverage for `GoalAType.achatImmo` vs `GoalAType.retraite` on both visible prompts and enhanced axis prompts, and keep `tools/checks/tests/test_data_quest_goal_aware_ranking_contract.py` so the scorer cannot silently fall back to generic impact-only ordering. Backend/global `EnhancedConfidenceService.rank_enrichment_prompts()` remains generic unless a later phase makes it goal-aware too. |
| Q-6 | No `Case` registry mapping events→guardQuests | new `data_quest/case_registry.dart`; seed with `transmit_property`, `divorce`, `retirement` |

### 7.1 G1-BND-02A — progressive partner-LPP quest

This G1-only Case implements the represented-authorization contract in
`decisions/ADR-20260715-g1-bnd02a-partner-accountability.md`, the non-publishable
notice requirements in `docs/legal/partner_lpp_notice_contract_v1.md`, and the
focused journey `docs/codex/PARTNER_LPP_ACCOUNTABILITY_FLOW.mmd`.

- `manualPartner` is offered only for an existing local
  `CoachProfile.conjoint`; account creation/linking, household membership and
  invitation remain optional and never authorize the path.
- The only current accountability kind is
  `acting_user_partner_authorization_declaration`. It records the authenticated
  acting user's one-shot declaration, never direct partner consent.
- Ask/order is fixed and progressive: current versioned notice + account-free
  rights → explicit declaration/auth → preallocated owner/receipt ids and
  strict-secure `pending` binding → permission/picker → minimized
  `partner_accountability_receipts` receipt after local file choice → review of
  canonical facts → exact-owner root save/binding activation → visible
  `RetirementDashboardScreen` recompute.
- `direct_partner_confirmation` is a distinct, optional future receipt and is
  deferred until it has a real public caller and rights flow; no placeholder
  CTA, route or service is allowed.
- Missing/stale legal facts block before picker. Offline, unverifiable,
  expired, revoked, erased or owner-mismatched status excludes receipt-bound
  certificate facts and renders `partial+ask`, never cached GREEN or CHF 0.
  Recovery retries status or restarts at the current notice; an independent
  manual `userInput` fact is restored first, otherwise ask only the next
  highest-impact pension/capital fact. Never ask for the quarantined caisse
  return rate.

### 7.2 G1-RET-REF-01 — LPP regulation specialist handoff is not a quest

The exact plan review collects only authority metadata (`sourceDate`,
`legalYear`) inside `/scan/review`; it does not ask for or infer personal LPP
values. After the accepted reference cold-resolves, `/retraite` may display six
ordered preparation topics: buy-back, conversion, flexible retirement,
disability, survivors and divorce.

These are **questions to take to a pension fund or specialist**, not ledger
collection prompts. They have no `fieldPath`, `AskMode`, impact score, answer
control, write-back, Case transition or completion effect. Closing the sheet is
local. Missing/flag-off/tuple-drift authority hides the entire handoff rather
than turning its text into a generic DataQuest. Any future answer capture must
be a separately specified typed ledger/Case slice; it may not retrofit values
into this metadata reference.

## 8. Acceptance criteria (Codex/CI must verify)

- **DQ-1** A screen with all `reads[]` fresh triggers **zero** Asks (planQuest returns []).
- **DQ-2** A screen missing k fields surfaces exactly k Asks; mobile
  confidence enrichment prompts rendered from `ConfidenceScorer.score().prompts`
  use impact plus `GoalAType` ordering, while DataQuest case asks remain
  ordered by the case registry until a later phase connects those rankers.
  It is never a blocking wall
  (partialState renders).
- **DQ-3** A field with `needsRefresh==true` produces an `AskMode.reconfirm` (1-tap), never a blank field.
- **DQ-4** Every write goes through `CoachProfileProvider` (grep: no other writer of `wizard_answers_v2`).
- **DQ-5** `transmit_property` Case runs the retirement-affordability guardQuest before rendering any gift result.
- **DQ-6** Every rendered projection carries range + `EnhancedConfidence` (compliance).
