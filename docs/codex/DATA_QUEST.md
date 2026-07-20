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
> **Focused LPP regulation handoff boundary:** the autonomous technical atom at
> exact pushed SHA `6066f1c94786aa1bc4697c29b4a670b7cea3dca4` ends in six
> specialist-preparation questions. They are static,
> conditional educational prompts over one exact metadata reference, not
> `DataQuest` Asks: they collect no answer, rank no product and write no fact.
> The synthetic runtime passes 2/2 with a distinct-PID regulation-only cold
> reader and 22/22 retained logs. `fundRelationship` remains a declared,
> non-verified relationship, not a DataQuest answer or caisse attestation.
> The bounded recovery extension at exact pushed SHA
> `7cb5ea4c64e0a59d4e2f38f8f67eff7c924bd32a` keeps that boundary: the
> tuple-free `selfRegulationRecoveryReason`, opaque
> `missingDocumentReference`/`mismatchedDocumentReference` states and existing
> `/scan?type=lppPlan` CTA are recovery mechanics, never `DataQuest` Asks. Its
> tracked proof is
> `phase-37/ret-ref-01/lpp-regulation-recovery-runtime-proof-7cb5ea4c6/` at
> bundle commit `ce5a020503c9e1733a81fa01b8dc6dd79b7c01d1`. Exact pushed SHA
> `274736a50bca659579fe26f68ae4e600469e3a9a` additionally proves that the same
> fixed six questions and negative-authority caveat reach `/rapport` and the
> production report bytes without collecting a DataQuest answer, and that all
> three recovery states suppress the dossier. Its proof is
> `phase-37/ret-ref-01/lpp-regulation-dossier-pdf-runtime-proof-274736a50/`.
> PDF/dossier caveat parity is closed; activation remains
> NO-GO; RET-REF stays `ticket_only`, G1 remains open at 8.2/10 and G2/G3 are
> forbidden.

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
`legalYear`) plus the mandatory user-declared `fundRelationship`
(`currentFund`, `uncertain`, `formerOrOther`) inside `/scan/review`; it does not
ask for or infer personal LPP values, and does not verify the caisse. The
reference is autonomous from numeric LPP snapshots. After it cold-resolves,
`/retraite` may display six ordered preparation topics: buy-back, conversion,
flexible retirement, disability, survivors and divorce.

These are **questions to take to a pension fund or specialist**, not ledger
collection prompts. They have no `fieldPath`, `AskMode`, impact score, answer
control, write-back, Case transition or completion effect. Closing the sheet is
local. Exact `resolved` evidence wins and renders the handoff. With ready BND
hydration, the strict schema-3 marker `legacyMissingFundRelationship`,
`missingDocumentReference` and `mismatchedDocumentReference` render
state-specific reconfirmation copy plus the existing `/scan?type=lppPlan` CTA.
This is document reacquisition, not a blank fact question: it creates no `Ask`,
score, answer alias, Case transition or completion effect. `unavailable`,
flag-off and idle/loading/failed hydration hide both handoff and recovery. Any
future answer capture must be a separately specified typed ledger/Case slice;
it may not retrofit values into this metadata reference or recovery marker.

The exact pushed runtime SHA
`6066f1c94786aa1bc4697c29b4a670b7cea3dca4` proves the regulation-only writer
and distinct-PID cold reader, then preserves the reference through numeric LPP
addition and replacement. The minimized sanitized proof is tracked at
`.planning/runtime-evidence/phase-37/ret-ref-01/lpp-regulation-runtime-proof-6066f1c94/`;
the complete 22/22-log runtime and P0/P1=0 audit archives remain local excluded
provenance. This runtime changes neither DataQuest scope nor activation.
At exact pushed SHA `7cb5ea4c64e0a59d4e2f38f8f67eff7c924bd32a`, the same native
suite remains 2/2 with distinct PIDs while the cold reader empties the BND,
classifies `missingDocumentReference`, proves the neutral recovery card/body/
CTA and emitted scan route, then restores, reloads and compares the original
BND before numeric continuation. The retained-output contract remains 22/22
and production-default Maestro passes before/after. The minimized proof is
tracked at
`.planning/runtime-evidence/phase-37/ret-ref-01/lpp-regulation-recovery-runtime-proof-7cb5ea4c6/`
by bundle commit `ce5a020503c9e1733a81fa01b8dc6dd79b7c01d1`. This closes only
the visible legacy/missing/mismatch recovery debt. At exact pushed SHA
`274736a50bca659579fe26f68ae4e600469e3a9a`, resolved dossier/PDF parity and
three-state dossier suppression pass through the real production composition;
the minimized proof is
`.planning/runtime-evidence/phase-37/ret-ref-01/lpp-regulation-dossier-pdf-runtime-proof-274736a50/`.
PDF/dossier caveat parity is closed. Activation and other RET-REF work remain
separate and are not new DataQuest
Asks; RET-REF remains `ticket_only`, G1 stays open at 8.2/10 and G2/G3 stay
forbidden.

### 7.3 G1-SUCCESSION-01 — bounded estate-reference Case (live; runtime accepted)

This is a real progressive collector with accepted production runtime at pushed
`32aed9f99c87f2aab738d8860b117fc3a3a7ce5e`, not evidence that the generic Q-2
`DataQuest` service or Q-6 global Case registry now exists. Its bounded Case
contract is:

| Case field | exact contract |
|---|---|
| `caseId` | `succession_reference_confirmation` |
| route | `/succession`, inside `SuccessionEvidenceQuest` |
| activation | local compile flag `MINT_TEST_SUCCESSION_EVIDENCE_COLLECTION`; default false and absent from backend `applyFromMap` |
| minimum variables | confirmed `q_civil_status`; current marriage/LPart arrangement only when applicable; exact four `_coach_estate_evidence_v1.estateInstruments` slots explicitly present or absent |
| useful variables | prior-union state for the specialist question; present-slot `sourceDate` and `legalYear` metadata |
| blocking guard | ambiguous civil status → `/data-block/composition_menage?inputKey=q_civil_status&returnUri=/succession`; invalid root → reload/support only |
| non-blocking enrichment | one applicable arrangement question, then one exact instrument slot at a time; no property, heir, share, reserve or distribution conclusion |
| target screen | `/succession`; no PDF/dossier section is unlocked by this survey |
| accepted runtime | flag-off/flag-on Maestro plus `civil_guard_seed`, `native_present`, `absent_write` and distinct-process `cold_read`; exact bundle `.planning/runtime-evidence/phase-37/succession-01/runtime-32aed9f99c87-20260720T060411Z/` |

The next-question order is deterministic and local to this Case:

1. unresolved civil status;
2. current marriage or LPart arrangement, if applicable, with no preselection;
3. the first `stale` slot in enum order;
4. otherwise the first `unknown` slot in enum order;
5. editable terminal review after all four are explicitly present/absent.

A stale slot is the exact §3 reconfirm pattern: show the prior state/date/year
or prior absence confirmation before offering same-metadata reconfirmation.
Unknown never means absent. Present requires civil date plus explicit legal
year; absent requires a deliberate user action. Each action calls the dedicated
typed CAS writer rather than `mergeAnswers`, because this is a strict authority
root. Save success is awaited before the acknowledgement/next control appears;
persistence failure retains the same Ask; CAS conflict reloads the provider and
does not retry a stale id. Dismiss/auto-advance is intentionally absent for this
heavy event; each durable answer is followed by an explicit next gesture.

The payoff is deliberately narrow: known facts become reviewable and reusable,
and stale declarations become reconfirmable. “Survey recorded” never means
complete estate composition, verified instrument content/effect, legal advice,
specialist-ready handoff or dossier readiness. No file picker, filename/path,
raw bytes, OCR output or free-form legal content belongs to this Case. Both flag
states, civil guard/return, explicit absent and present input, kill/relaunch
cold continuation and the representative screenshots are accepted in the exact
bundle above. The flag remains default-off; this bounded Case does not create a
global registry or authorize G2/G3.

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
