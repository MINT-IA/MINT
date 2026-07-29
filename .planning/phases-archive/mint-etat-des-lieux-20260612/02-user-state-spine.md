---
phase: mint-etat-des-lieux-20260612
artifact: 02-user-state-spine
date: 2026-06-12
author: architect-review (subagent)
status: audit / état des lieux (read-only)
description: >
  Census of every user-state representation across MINT (Flutter + FastAPI),
  the compute engines that consume them, and the gap between the DECIDED
  event-log data architecture (2026-05-17 ADR) and what is actually BUILT.
  Roots the device-proven divergence (coach age 50 vs seed 48/162k ; /home RR
  28% vs /retraite 69%) in TWO concrete causes — two unsynchronised profile
  stores, and two surviving replacement-rate formulas with different
  denominators. Proposes the target canonical user-state spine, a strangler-fig
  migration, and an honest scope estimate. Challenges the founder's « c'est
  simple » framing in both directions.
---

# 02 — The User-State Spine: census, gap, target, migration

## TLDR

MINT does not have one canonical user state. It has **at least seven** user-state representations that are written and read independently, with a hand-coded ~200-line reconciliation function in the middle that nobody fully trusts. The two device-proven bugs are not random: they are the *predictable output* of this topology.

- **Bug 1 (age 50 in chat ≠ 48 everywhere else)** = the coach `save_fact` tool writes to the **backend** `profiles.data` JSON blob (`birthYear`), while every mobile screen reads `CoachProfile` built from **wizard answers in SharedPreferences**. These are two physically separate stores on two devices, reconciled only by an opportunistic, lossy merge (`_mergeFinancialFieldsFromRemote`, `coach_profile_provider.dart:268`). The seed (age 48) hydrates the mobile store; the chat fact (age 50) lands in the backend store; they never converge.
- **Bug 2 (/home 28% ≠ /retraite 69%)** = TWO surviving replacement-rate formulas with **different denominators**. `/home` (anonymous/premier-éclairage) uses `ReplacementRate.percent` ÷ **NET** monthly income; `/retraite` uses `ForecasterService.safeReplacementRate` ÷ **GROSS** annual income — *and* the two surfaces feed **different profile objects** (`MinimalProfileResult` from a 3-input seed vs `CoachProfile` → `MintUserState`). Two axes of divergence stacked.

**The decided event-log architecture (ADR 2026-05-17) is ~80% BUILT but ~0% CUTOVER.** The `fact_event` / `fact_current` tables, the `FactProjector`, the DEK envelope, the snapshot dual-write — all exist in code. But the feature flag `FF_FACT_EVENT_DUAL_WRITE` defaults **OFF**, the only caller of `FactProjector` is the gated snapshot service, and the deploy phase's cutover (PR3b/PR4/PR5, backfill, HARD-parity flip) is a wall of unchecked `[ ]` boxes. The spine the founder is asking for was *designed and scaffolded a month ago* — it was never wired to the write path.

**Honest scope: 6–9 weeks** to a real canonical spine, *not* days — and the single highest-leverage move is **surface reduction** (120 screens / 153 routes / ~40 services-with-calc), not unification.

---

## 1. CENSUS — every user-state representation

### 1.1 Mobile (Flutter)

| # | Representation | File:line | Written by | Read by | Sync mechanism |
|---|---|---|---|---|---|
| M1 | **`CoachProfile`** (god-model, 3 876 LOC, ~50 fields + 6 sub-models) | `models/coach_profile.dart:1451` | `CoachProfile.fromWizardAnswers` (`:2662`), `fromJson` (`:2465`), seeds | ~30+ call-sites, all screens, `MintStateEngine`, `DataSpineService`, `ForecasterService` | **The de-facto mobile canonical** — but rebuilt from wizard answers on every `loadFromWizard()` |
| M2 | **Wizard answers map** (`Map<String,dynamic>` keyed `q_*`) | `services/secure_wizard_store.dart`, `ReportPersistenceService.loadAnswers()` | onboarding scenes, `mergeAnswers`, `_mergeFinancialFieldsFromRemote` | source for M1 | **SharedPreferences** (NOT secure storage despite the name — `coach_profile_provider.dart:174`) |
| M3 | **`CoachProfileProvider._profile`** (reactive) | `providers/coach_profile_provider.dart:45` | `loadFromWizard`, `mergeAnswers`, `_mergeFinancialFieldsFromRemote` | UI via `context.watch` | `notifyListeners()`; persists via M2 |
| M4 | **`MinimalProfileResult`** (3-input snapshot: age/salary/canton → projections) | `models/minimal_profile_models.dart:13`, `services/minimal_profile_service.dart` | `MinimalProfileService` (backend call OR local), seed stub (`anonymous_chat_screen.dart:415`) | `/anonymous` premier-éclairage, `PremierEclairageSelector` | **NONE** — a parallel, narrower user model that never merges into M1 |
| M5 | **`CoachProfileSeed`** (E2E/walker fixture: `age 48`, `GE`, `grossMonthlySalary 13500` for `cadre_40_55_lpp_rachat`) | `services/coach/coach_profile_seeds.dart:226` | `--dart-define=MINT_E2E_ARCHETYPE` build constant | hydrates M1 in walker/widget-test builds | **build-time only** — *but device-proven to leak the 48/162k profile into a real session* |
| M6 | **`MintUserState`** (unified projection: profile + RR + cap + nudges) | `models/mint_user_state.dart:36`, `services/mint_state_engine.dart:55` | `MintStateEngine.compute(profile)` — "the ONLY place where CoachProfile + CapEngine + ConfidenceScorer..." (`:3`) | Pulse tab, coach, widgets via `MintStateProvider` | recomputed from M1 on change (`mint_state_provider.dart`) — *read-derived, not a store* |
| M7 | **`DataSpineSnapshot` / `FinancialSituation`** (trust-gated projection) | `services/data_spine/data_spine_service.dart:6` | `DataSpineService.*FromProfile(CoachProfile)` | coach context packet, money/budget screens | read-only adapter over M1; the name "spine" is **aspirational** — it stores nothing |
| M8 | legacy **`Profile`** + `ProfileProvider` | `models/profile.dart`, `providers/profile_provider.dart:5` | `api_service` | residual screens | separate from M1 — a second, older mobile profile object still alive |

### 1.2 Backend (FastAPI)

| # | Representation | File:line | Written by | Read by | Sync mechanism |
|---|---|---|---|---|---|
| B1 | **`ProfileModel.data`** (JSON blob, flat dict: `birthYear`, `incomeGrossYearly`, `avoirLpp`…) | `models/profile_model.py:31` | `POST/PATCH /profiles`, **coach `save_fact`** (`coach_chat.py:3140`) | `GET /profiles/me`, coach context builder | **THE backend canonical** — a `MutableDict` JSON column, no schema enforcement beyond `_SAVE_FACT_ALLOWED_KEYS` |
| B2 | **`CoachInsightRecord`** (LLM-inferred "concern" rows) | `models/coach_insight.py` | coach `save_insight` tool | system-prompt memory block (`coach_chat.py:_build_insight_memory_block`) | append rows; **compliance gap flagged in ADR finding #3** (no consent category, not in `export_user_data`) |
| B3 | **`fact_event`** (append-only event log, partitioned, DEK-encrypted) | `models/fact_event.py:51` | `FactProjector.project_event` — **only called by gated snapshot service** | snapshot service (flag-gated) | **BUILT, NOT WIRED** — `FF_FACT_EVENT_DUAL_WRITE=False` default (`feature_flags.py:56`) |
| B4 | **`fact_current`** (denormalised read-side, UPSERT last-writer-wins) | `models/fact_current.py` | `FactProjector` (same gated path) | read path behind `FEATURE_FLAG_FACT_CURRENT_READ` | **BUILT, NOT WIRED** |
| B5 | **`SnapshotModel`** (projection outputs) | `models/snapshot.py` | snapshot service | dashboard/audit | dual-writes to B3 *only when flag ON*; **carries no `constants_version_hash`** (ADR finding #4) |
| B6 | **`HouseholdModel`, `EarmarkModel`, `ScenarioModel`, `CommitmentModel`, `BankingConsent`, `DocumentMemory`** | `models/{household,earmark,scenario,commitment,banking_consent,document_memory}.py` | dedicated endpoints | dedicated services | **siloed per-feature** — none feed B1 or each other |

### 1.3 The reconciliation seam (where divergence is manufactured)

`_mergeFinancialFieldsFromRemote` (`coach_profile_provider.dart:268`, ~200 LOC with `_mapFactKeyToAnswers`) is the *only* bridge from B1 → M1. It maps backend camelCase fact keys → wizard `q_*` keys, then merges with a tangle of "authoritative" / "claim" precedence rules (`:296`–`:340`). It is best-effort, runs only on certain auth-hydration paths (`coach_profile_provider.dart:164`), and has no transactional guarantee that B1 and M1 ever fully agree. **This function is the architectural location of Bug 1.**

---

## 2. COMPUTE ENGINES — who consumes the state

### 2.1 Canonical L1 (financial_core, mobile) — 20 calculators

`apps/mobile/lib/services/financial_core/` (20 `.dart` files): `avs_calculator`, `lpp_calculator`, `tax_calculator`, `pillar3a_room_calculator`, `cross_pillar_calculator`, `replacement_rate`, `housing_cost_calculator`, `fri_calculator`, `arbitrage_engine`, `couple_optimizer`, `monte_carlo_service`, `withdrawal_sequencing_service`, `tornado_sensitivity_service`, `confidence_scorer`, `bayesian_enricher`, etc. The mint-illogism-fixes phase did real work here — most `_calculate*` logic is now centralised.

### 2.2 SURVIVING non-canonical computations (what still bypasses)

The illogism phase routed *formulas* to financial_core, but left **duplicate orchestrators with divergent contracts**:

1. **`ForecasterService.safeReplacementRate`** (`forecaster_service.dart:1046`) — a SECOND replacement-rate owner. Divides `annualRetirementIncome / annualCurrentIncome` (**GROSS annual**), clamps `[0, 200]`, floors at `< 12000`. **Different scale, different denominator, different clamping** from canonical `ReplacementRate.percent` (`replacement_rate.dart:34`), which divides by **NET monthly** and is unbounded-above. Both are alive; `/retraite` uses the former, `/home` uses the latter. **This is the architectural root of Bug 2.**
2. **`MinimalProfileService`** (`minimal_profile_service.dart`) — a parallel projection engine for the 3-input flow. It *does* call canonical `ReplacementRate.fraction` (`:186`) — good — but feeds it a **NET** denominator and a **separate `MinimalProfileResult` input object** (M4), so its output is on a different basis than the `MintUserState` path even when the formula matches.
3. **`RetirementProjectionService`** and **`RetirementService`** — both produce `tauxRemplacement`; `retirement_projection_service.dart:227` delegates to `ForecasterService.safeReplacementRate`, while `mint_state_engine.dart:195` falls back to `retirementResult.tauxRemplacement`. Two retirement engines, one delegating to the gross-basis formula, one to its own.
4. **`MintStateEngine`** (`mint_state_engine.dart:167`) — uses `ForecasterService.project(...).tauxRemplacementBase` (gross basis) as the *primary* `MintUserState.replacementRate`, with `RetirementService` as fallback. So the "unified" state object itself is on the gross basis, diverging from anything that reads `MinimalProfileResult`.

**Net:** the surviving divergence is *not* duplicated arithmetic — it is **duplicated profile inputs feeding the same/similar calculators on incompatible bases (net vs gross, monthly vs annual, MinimalProfileResult vs CoachProfile).** Unifying the formulas (illogism's win) did not fix this because the inputs were never unified.

---

## 3. DECIDED vs BUILT — the event-log gap

**Decided (ADR `2026-05-17-data-architecture-event-log-vs-bitemporal.md`):** append-only `fact_event` log + denormalised `fact_current` projection + per-user DEK crypto-shred envelope. Source types: `pdf | bank_api | lpp_api | user_input | coach_inference | legal_pdf`. Status header: *"Decided (calc-engine portion) ; Proposed (event-log + coach-extractor)."*

**Built:**
- ✅ `fact_event` ORM with append-only invariant + HASH partitioning (`models/fact_event.py`)
- ✅ `fact_current` ORM with idempotent UPSERT / last-writer-wins (`models/fact_current.py`)
- ✅ `FactProjector` service (`services/projector/fact_projector.py`)
- ✅ DEK envelope wire shape (`models/encryption/encrypted_value.py`)
- ✅ migration chain `p98_fact_event_projection`, counters, drift sampler cron

**NOT built / NOT cutover (the gap):**
- ❌ **No production write path uses the event log.** `grep` for `FactProjector` callers returns only `snapshots/snapshot_service.py` — itself gated. The real write path (`coach_chat.py:3140` `save_fact`) writes the **JSON blob B1** and does **not** dual-write to `fact_event`.
- ❌ `FF_FACT_EVENT_DUAL_WRITE` defaults **False** in dev/staging/prod (`feature_flags.py:56,116`).
- ❌ `FEATURE_FLAG_FACT_CURRENT_READ` never flipped — reads still hit B1.
- ❌ The deploy phase VALIDATION (`mint-data-architecture-v1-02-deploy-VALIDATION.md`) is a wall of unchecked boxes: cutover PR3b/PR4/PR5, backfill idempotency, projection_diff zero-diff sign-off, HARD-mode parity flip, 7-day drift window, Maestro G1 sweep, Julien G2 — **all `[ ]`**.
- ❌ Mobile never touches the event log at all. The mobile spine remains M1 (wizard-derived `CoachProfile`).

**Verdict:** the decided architecture is *scaffolded but not the source of truth for a single live field.* The org built the warehouse and never moved in. This is the single most important fact for planning: **the spine is not greenfield — it is a stalled cutover.**

---

## 4. TARGET SPINE — proposed architecture

The founder's requirement — *"ces quelques données primordiales doivent être enregistrées, gérées dans la base de données par utilisateur"* — is exactly the ADR's event-log shape, finished and made canonical. Concretely:

```
              ┌─────────────────── WRITE SOURCES ───────────────────┐
  onboarding wizard │ coach save_fact │ document extraction │ manual edit │ (future) bank/LPP API
              └──────────────────────────┬──────────────────────────┘
                                         │  all writes → ONE endpoint
                                         ▼
                          POST /facts  (FactProjector.project_event)
                                         │
                       ┌─────────────────┴─────────────────┐
                       ▼                                     ▼
              fact_event (append-only,                fact_current (denormalised,
              DEK-encrypted, source-tagged,           last-writer-wins by valid_from,
              valid_from, confidence)                 index-only read)
                                         │
                                         ▼  GET /profiles/me reads fact_current → canonical dict
                       ┌─────────────────┴──────────────────┐
                       ▼                                      ▼
               MOBILE: CoachProfile.fromCanonical()    L2-L4 backend calculators
               (hydrate from /facts, NOT wizard prefs)  (comparer/éclairer/invariants)
                       │
                       ▼  ONE projection
               MintUserState (single RR owner, single basis)
                       │
                       ▼
               every surface (home, retraite, coach, budget) reads MintUserState
```

**Invariants the target must enforce:**
1. **One write endpoint.** Every fact — wizard, `save_fact`, document, manual — goes through `POST /facts` → `FactProjector`. Kill the direct `profiles.data[key] = ...` write in `coach_chat.py:3140`.
2. **One read shape.** `GET /profiles/me` projects `fact_current` into the canonical dict. Mobile `CoachProfile.fromCanonical()` replaces `fromWizardAnswers` as the hydration path; wizard answers become *just another write source*, not a parallel store.
3. **One replacement-rate owner, one basis.** Delete `ForecasterService.safeReplacementRate`; everything routes through `ReplacementRate.percent` with a **single documented denominator** (recommend NET monthly, the more honest "what you actually live on"). Pick the basis once, in CLAUDE.md.
4. **One profile object per platform.** Kill `MinimalProfileResult` as a separate model — make the 3-input flow produce a *partial* `CoachProfile`, not a sibling type. Kill legacy `Profile` (M8).
5. **Sync contract:** mobile holds a local cache of the canonical dict keyed by `(user_id, fact_version)`; on auth + on `save_fact` ack, it re-pulls `/profiles/me` and overwrites the cache. Last-writer-wins by `valid_from`, exactly as `fact_current` already implements. No more hand-coded `_mergeFinancialFieldsFromRemote` — the server is authoritative, the client mirrors.

---

## 5. MIGRATION — strangler-fig, honest scope

Per CLAUDE.md D-11 strangler-fig. Sequenced to keep the app shippable at every step:

**Phase A — Finish the stalled cutover (backend) — ~2 weeks.**
- Resolve the dual-head alembic blocker (DEFERRED-02-01-A) — 1 PR.
- Wire `save_fact` (`coach_chat.py:3140`) to dual-write through `FactProjector` behind `FF_FACT_EVENT_DUAL_WRITE`. Flip ON in staging.
- Backfill existing `profiles.data` blobs → `fact_event` (one event per key, `source=user_input`, `valid_from=updated_at`). Run `projection_diff` until zero-diff (the ADR's gate).
- Flip `FEATURE_FLAG_FACT_CURRENT_READ` ON; `GET /profiles/me` reads `fact_current`. **B1 becomes a shadow, then dead.**

**Phase B — Collapse mobile to one hydration path — ~2 weeks.**
- Add `CoachProfile.fromCanonical(Map)` reading the `/profiles/me` projection.
- Make onboarding wizard write via `POST /facts` instead of (or in addition to, transitionally) SharedPreferences. Wizard answers stop being a store.
- **Delete `_mergeFinancialFieldsFromRemote`** once server is authoritative. This removes ~200 LOC of the most error-prone code in the repo and *directly kills Bug 1*.
- Retire seed-leak: `CoachProfileSeeds` must hard-fail to null in non-E2E builds (it claims to via `kReleaseMode` — verify the device-proven leak path; the 48/162k bleed suggests a gap).

**Phase C — One replacement-rate basis + kill `MinimalProfileResult` — ~1 week.**
- Delete `ForecasterService.safeReplacementRate`; route `RetirementProjectionService`, `MintStateEngine`, `RetirementService` through canonical `ReplacementRate.percent`. **Kills Bug 2.**
- Fold `MinimalProfileResult` into a partial `CoachProfile`; `/home` and `/retraite` read the *same* `MintUserState.replacementRate`.

**Phase D — Surface reduction (see §6) — ~1–2 weeks, parallelisable.**

**Phase E — Compliance close (ADR findings #3/#4) — ~3 days.**
- `CoachInsightRecord` → add consent category, export, deletion.
- `SnapshotModel` → add `constants_version_hash` for the LSFin advice audit trail.

**What to KILL:** `_mergeFinancialFieldsFromRemote`; `ForecasterService.safeReplacementRate`; `MinimalProfileResult` as a type; legacy `Profile`/`ProfileProvider` (M8); direct `profiles.data[key]=` writes; SharedPreferences as a profile store.

**Honest total: 6–9 weeks** with one engineer, assuming the stalled cutover's tests still pass (they may have bit-rotted — the deferred-items list shows pre-existing failures). Phase A alone is 2 weeks because backfill + zero-diff + flag flips on live data is unforgiving.

---

## 6. CHALLENGE THE FOUNDER'S FRAMING (mandatory)

**Where « c'est simple » under-estimates:**

1. **"These few primordial data points" is the trap.** The data points are simple (age, salary, canton, LPP, 3a, household). The *write topology* is not. There are **5 write sources** (wizard, save_fact, document extraction, manual edit, future bank API) landing in **2 physical stores on 2 devices**. "Save them in the DB per user" is one sentence; making *every surface read the same value* is a 200-LOC reconciliation function the team already wrote once and got wrong. The hard part was never storage — it's *single-writer discipline* and *cache coherence*. That is weeks, not days.
2. **The replacement-rate bug is not a calculator bug, it's a definitional one.** 28% vs 69% is partly a *net-vs-gross denominator choice* that no one ever decided once. Even with a perfect canonical store, if two surfaces pick different denominators you get two numbers. The founder must make **one product decision** (net or gross basis) before any code unifies — and accept that the "right" number may *feel* worse than the flattering one currently shown on one screen.
3. **The event log won't save you if it's not the write path.** The org already *decided and built* this spine a month ago (ADR + `fact_event` + `FactProjector`). It didn't fix anything because the cutover never landed. "Just use the database" risks repeating that: scaffolding without cutover. The discipline is finishing the flip, not designing a new table.

**Where the codebase is closer than he thinks:**

1. **The spine is 80% built.** `fact_event`, `fact_current`, `FactProjector`, DEK envelope, partitioning, drift sampler — all exist and have tests. This is a *cutover*, not a *build*. That genuinely compresses Phase A risk.
2. **Most formulas are already canonical.** mint-illogism-fixes did the unglamorous work — `financial_core` is the real single source for arithmetic. The remaining divergence is *inputs and one rogue RR wrapper*, not 57 duplicated formulas.

**The uncomfortable counter-proposal: CUT, don't unify.** 120 screens / 153 routes / ~40 services-with-calc is the real disease. Unifying state *across 120 surfaces* is a Sisyphean coherence problem — every new screen re-opens the divergence. **Surface reduction is the cheaper architecture.** If `/home` and `/retraite` both show a replacement rate, ask whether *both screens should exist*, not just whether they agree. A MINT with ~15 surfaces reading one `MintUserState` is more defensible — and more shippable — than a MINT with 120 surfaces all wired to a perfect spine. The founder is asking "how do I synchronise 120 windows onto one truth?" The better question is "why do I have 120 windows?" Recommend a parallel **surface-reduction pass** (Phase D) that deletes redundant projection screens *before* the spine work hardens around them — otherwise the spine inherits the surface sprawl as permanent maintenance cost.

---

## Counter-arguments & data gaps (wiki-lint required)

**Counter-arguments:**
- *"Two stores is fine if the merge is correct."* True in theory; the merge is **not** correct (Bug 1 is device-proven) and is the single most complex function in the mobile provider layer. Correct-merge is *more* expensive to maintain than single-writer.
- *"The event-log cutover is risky on live data — maybe B1 JSON blob is good enough."* Defensible for a pre-launch app with ~0 prod users (the deploy phase itself cites a "0-user-prod premise"). If launch is far, you *could* skip the event log and just make B1 the single canonical store with one mobile read path — cheaper (drop Phase A's backfill complexity), at the cost of losing the source-tagging / bitemporal audit trail the ADR wanted for the future bank/LPP API. This is a real fork the founder should decide: **full event-log spine vs. "one JSON blob, one read path" minimal spine.** The minimal spine kills both bugs in ~3 weeks; the full spine is the 6–9 week number.
- *"Surface reduction is out of scope for a state-spine task."* It is the *cause*, not a tangent. Declining to cut surfaces is a valid product call, but it converts the spine from a one-time fix into a permanent coherence tax.

**Data gaps (what this audit did NOT verify):**
- The exact runtime path by which the `cadre_40_55_lpp_rachat` seed (age 48) leaked into a *non-E2E* session was not reproduced — `CoachProfileSeeds` claims a `kReleaseMode` guard; the device proof contradicts it. Needs a focused repro before Phase B trusts the guard.
- Whether the stalled cutover's backfill scripts still run green against current staging schema (alembic dual-head + bit-rot risk) was not executed — scope estimate for Phase A assumes they need ~2 days of repair.
- The precise net-vs-gross numerator/denominator each device screen used in the proven 28%/69% session was inferred from the formula owners, not captured from the live session logs. The *mechanism* (two formulas, two bases, two inputs) is proven from code; the exact arithmetic per screen was not re-derived from the device run.
- Backend `B6` siloed models (household/earmark/scenario) were censused by name only, not for whether they *also* duplicate profile fields — a deeper pass may find more divergence sources.
