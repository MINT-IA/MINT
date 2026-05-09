# Roadmap: MINT

## Milestones

- ✅ **v1.0 MVP** — Phases 1-8 (shipped 2026-03-20)
- ✅ **v2.0 Systeme Vivant** — Phases 1-6 (shipped 2026-04-07)
- ✅ **v2.1 Stabilisation** — Phase 7 (shipped 2026-04-07)
- ✅ **v2.4 Fondation** — Phases 9-12 (shipped 2026-04-12)
- ✅ **v2.5 Transformation** — Phases 13-18 (shipped 2026-04-13)
- ✅ **v2.6 Le Coach Qui Marche** — Phases 19-26 (shipped 2026-04-13)
- 🟡 **v2.7 Coach Stabilisation + Document Digestion** — Phases 27-30 (code-complete, awaiting device gate)
- ✅ **v2.8 L'Oracle & La Boucle** — Phases 30.5-32 + decimals (shipped 2026-04-25, 5/9 phases + gaps)
- 🪦 **v2.9 Coach Visuel Hybride** — superseded 2026-05-09 by Chat-as-Verb pivot. Phases 40-43 (Marge fiscale / Hero / Scènes / Canvas) DROPPED ; design doctrine "le coach EST le produit" partially preserved in chat-as-verb Phase 96.
- 🚧 **v2.9 Chat-as-Verb Pivot** — ACTIVE 2026-05-09 — Phases 90-96 (7 phases, ~14 days critical path) — see [MILESTONE-CHAT-AS-VERB-2026-05-09.md](MILESTONE-CHAT-AS-VERB-2026-05-09.md)

<details>
<summary>Previous milestones (v1.0 → v2.7) — see MILESTONES.md + collapsed v2.5-v2.7 detail</summary>

Full phase detail for v2.5 (Phases 13-18), v2.6 (Phases 19-26), v2.7 (Phases 27-30) preserved in git history of this file (pre-2026-04-19 revisions) + `.planning/MILESTONES.md`.

</details>

---

## v2.8 L'Oracle & La Boucle — SHIPPED 2026-04-25 (with gaps)

<details>
<summary>v2.8 phase detail (collapsed — full archive in milestones/v2.8-ROADMAP.md)</summary>

5 phases shipped + 13 decimal patches :
- 30.5 Context Sanity Core ✓ · 30.6 Context Sanity Advanced ✓ · 30.7 Tools Déterministes ✓ · 31 Instrumenter ✓ · 32 Cartographier ✓
- 30.8-30.20 : tactical fixes (LAND-01, FIX-02, anonymous CTA, error mapping, accent_lint exclusions, doc extraction uplift…)

Phases unshipped (carried forward) :
- 33 Kill-switches (4 P0 flags)
- 34 Guardrails (workflow design failed, lessons learned)
- 35 Boucle Daily (automation, deferred)
- 36 Finissage E2E (spirit absorbed into v2.9 Chat-as-Verb)

Full audit: [milestones/v2.8-MILESTONE-AUDIT.md](milestones/v2.8-MILESTONE-AUDIT.md) · 28/48 reqs · 5/9 phases.

</details>

---

## v2.9 Chat-as-Verb Pivot — ACTIVE 2026-05-09

**Strategic frame:** MINT is 70% structured wiki + simulators, 30% narration. The pivot kills the chat-tab as destination, makes cards the home, turns chat into a verb invocable from card-actions ("explique / simule / rassure-moi") with 3-turn cap, citation gate on every emitted number, and DAG invalidation on stale projections. Source: [MILESTONE-CHAT-AS-VERB-2026-05-09.md](MILESTONE-CHAT-AS-VERB-2026-05-09.md) (4-expert panel synthesis 2026-05-09).

**North-star metric:** Turns/user/week DOWN, DAU UP, quarter over quarter.

**Doctrine:** the wiki is the asset. Chat is a precision tool, not a destination. Every number carries a citation chip. Narrator LLM is mathematically incapable of emitting an un-cited number.

**Phase summary (4 architecture + 3 UI, ~14 days critical path with parallel UI/architecture tracks):**

- [x] **Phase 90: MVP-DESIGN-LINTS-V1** ✓ shipped 2026-05-09 (PR #543) — 5 design-system lints + baselines + lefthook + CI
- [ ] **Phase 91: MVP-EXTRACTOR-V2** — Split single coach LLM into 2 distinct roles (extractor + narrator) ; 2 prompts, 2 guardrails, 2 budgets
- [ ] **Phase 92: MVP-FONTS-TOKENS-V2** — Land Supreme + Gambarino + Menthe-vive ; drop GoogleFonts.*
- [ ] **Phase 93: MVP-CTA-UNIFICATION-V1** — `MintCTA.{primary,secondary,tertiary,destructive}` replacing 9+ ad-hoc primitives + 10 ElevatedButton outliers
- [ ] **Phase 94: MVP-CITATION-GATE** — Post-process parser ; narrator output rejected if any number/legal claim is un-cited
- [ ] **Phase 95: MVP-DAG-INVALIDATION** — `inputs_hash` + `superseded_by` on every projection ; calculator refuses stale cache
- [ ] **Phase 96: MVP-CHAT-AS-VERB** — Kill chat-tab ; card-actions intent bar ; 3-turn cap ; source-card context propagation

### 5-gate exit contract per phase

| Gate | Description |
|---|---|
| G1 | Maestro flow under `tools/simulator/flows/maestro-perfect-set/` reproducing user-visible behavior (PASS) |
| G2 | Device verify by Julien on TestFlight OR Claude-via-Maestro on booted sim |
| G3 | dev CI green (flutter analyze, flutter test, pytest -q, schemathesis on touched routes) |
| G4 | Regression suite green (Flutter ≥229 model tests + new perimeter tests; backend ≥6047 + new) |
| G5 | LSFin banned-terms lint + accent_lint_fr.py + ARB parity (6 locales) |

### Phase Details

### Phase 90: MVP-DESIGN-LINTS-V1
**Goal**: Foundation phase. Stop the bleeding on design tokens before any UI sweep — block new violations, baseline existing. Fail-soft mode: lints emit warnings on baseline files, fail on new files.
**Depends on**: Nothing (foundation phase, runs first)
**Requirements**: LINT-01 prefer_mint_color_token, LINT-02 prefer_mint_text_style, LINT-03 prefer_mint_radius, LINT-04 prefer_mint_fonts, LINT-05 prefer_mint_cta
**Success Criteria** (what must be TRUE):
  1. 5 lints (`tools/checks/prefer_mint_*.py`) registered in `lefthook.yml` pre-commit + `.github/workflows/design-lints.yml` CI workflow.
  2. Per-lint baseline files (`tools/checks/baselines/*.txt`) capturing existing violations ; baseline files exempted from blocking.
  3. New violations introduced after baseline date FAIL the lint (exit 1) ; existing violations WARN (exit 0).
**Plans**: 1 plan (Wave 0 + scaffolding + 5 lint impls + tests + baselines + CI wiring)
- [x] PLAN.md — 5 lints + baselines + lefthook + design-lints.yml workflow + 12 unit tests under `tools/checks/tests/` (shipped PR #543, commit `a7d10bbe`)

**Budget**: 2d (shipped on time)
**Auto profile**: **L1** (meta/dev-tooling) — `/gsd-execute-phase` + `gsd-plan-checker` + `gsd-verifier`. Pas de simulator (lints CLI-only).

### Phase 91: MVP-EXTRACTOR-V2
**Goal**: Split the single coach LLM into 2 distinct roles. Today one Sonnet 4.5 call serves extraction (R3-R4 save_fact + save_insight), narration (R5), and tool routing (R6) — competing optimization targets in the same context window. Phase 91 separates extractor (fatter Sonnet, JSON-only, capture-focused) from narrator (thin Haiku/Sonnet with strict prompt, delivery-only, reduced tool list). Resolves « LLM does both jobs poorly » bottleneck. Unblocks Phase 94 (CITATION-GATE) and Phase 96 (CHAT-AS-VERB).
**Depends on**: Phase 90 (lints baseline established before backend touches)
**Requirements**: EXTR-01 extractor runs before narrator, EXTR-02 JSON-only output, EXTR-03 narrator prompt has no extraction directives, EXTR-04 narrator tool-set excludes save_fact/save_insight, EXTR-05 regex floor + LLM augment merge, EXTR-06 cost regression bounded ≤+30% post-mitigations, EXTR-07 Maestro flow `flow_extractor_captures_age_canton.yaml` PASS
**Success Criteria** (what must be TRUE):
  1. New `app/services/coach/llm_extractor.py` module (`run_llm_extractor`) returns Pydantic `ExtractorOutput(facts, intents)` with `source_quote` substring check ; second-failure returns empty list (non-fatal degradation to regex floor).
  2. `coach_chat.py` Step 1.4 calls regex extractor STAGE 1, then `run_llm_extractor` STAGE 2, merges (regex floor wins), persists to `ProfileModel.data` BEFORE `_run_agent_loop` invokes narrator.
  3. Narrator's `stripped_tools` list does NOT contain `save_fact` or `save_insight` ; narrator system prompt does NOT contain « EXTRACTION DE PROFIL » block.
  4. Maestro flow `tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml` PASSES on booted sim — sending « j'ai 80k de salaire à Lausanne » results in profile state with `incomeGrossYearly=80000` AND `canton='VD'` post-message.
  5. Per-turn cost regression ≤+30% post-mitigations (cache + skip-on-empty + Haiku narrator if eval passes Stage 3 ≥95% Sonnet pass-rate).
**Plans**: TBD (planning starts after CONTEXT.md committed)

**Budget**: 3d
**Auto profile**: **L2** (backend + LLM orchestration) — full GSD chain ; mandatory Stage 3 eval gate (50-fixture narrator eval) before Phase 91 closes ; mandatory Maestro G1 flow before merge.

### Phase 91.5: VAGUE-A2-MOBILE-REFACTOR
**Goal**: Mobile-side rename + CapMemoryStore in-place migration sprint. Independent of Phase 91 (different worktree, different branch, files INTERDITS list enforces collision avoidance). Acts as the merge-back gate for the parallel Vague A.2 sprint already specced in `handoff/`.
**Depends on**: nothing (parallel to Phase 91). PROMPT 3 chat vivant remains HOLD until Phase 91 mergée sur `dev` (handoff §2 line 20).
**Requirements**: VA2-01 path+query matcher in `findByRouteStatic`, VA2-02 IntentRouter rename batch (`first_job` → `life_event_first_job`, `debt_check` → `debt_risk_check`, `intentChipBilan` → `arbitrage_bilan`), VA2-03 CapMemoryStore in-place migration for legacy accounts, VA2-04 ARB parity post-relabel, VA2-05 unit + golden tests pass.
**Worktree**: `~/Desktop/MINT.brand-refondation.nosync`
**Branch**: `feat/mint-v2-refondation`
**Spec source** (authoritative — DO NOT duplicate): `handoff/NEXT_SESSION.md`, `handoff/CADRAGE.md`, `handoff/audit/05-plan.md`, `handoff/PROGRESS.md` (live log)
**Success Criteria** (what must be TRUE at merge-back):
  1. `apps/mobile/lib/services/coach/intent_router.dart` + call-sites: `first_job` renamed to `life_event_first_job`, `debt_check` to `debt_risk_check`, `intentChipBilan` to `arbitrage_bilan`. Grep on old names returns 0 matches across `apps/mobile/lib/` and `apps/mobile/test/`.
  2. `apps/mobile/lib/services/navigation/screen_registry.dart` `findByRouteStatic` matches path AND query (T-A1).
  3. `apps/mobile/lib/services/cap_memory_store.dart` migrates legacy account schema in-place ; legacy data preserved per T-A.2.3.
  4. ARB parity check (`validate_arb_parity` MCP or `tools/checks/...`) passes 6 locales post-relabel.
  5. Files INTERDITS untouched (`coach_orchestrator.dart`, `coach_chat_screen.dart`, anything `extractor*` / `chat_*_extractor*`) — verified by `git diff --name-only feat/mint-v2-refondation main`.
  6. `flutter analyze && flutter test` GREEN on `feat/mint-v2-refondation` ; squash-PR to `dev` opened with body referencing `handoff/audit/05-plan.md` and ticking each T-Ax delivered.
**Plans**: 91.5-00-PLAN.md (wrapper — task detail lives in `handoff/audit/05-plan.md`)

**Budget**: ~26h (per handoff §3, do NOT exceed)
**Auto profile**: **Parallel sprint, GSD-tracked** — code authored in the refondation worktree by a separate Claude session reading `handoff/NEXT_SESSION.md`. This phase exists in `.planning/` to:
  - register the workstream in ROADMAP / `/gsd-progress` / `/gsd-stats`
  - host the merge-back VERIFICATION.md when `feat/mint-v2-refondation` lands on `dev`
  - apply the 5-gate exit contract (mémoire `feedback_perimeter_5_gates`) at gate-time
The PLAN here does NOT duplicate `handoff/audit/05-plan.md` — it indexes it. Single source of truth stays in `handoff/`.

### Phase 92: MVP-FONTS-TOKENS-V2
**Goal**: Replace GoogleFonts.* runtime dependency with bundled Fontshare licensed fonts (Supreme + Gambarino) + Menthe-vive accent color. Resolves font CSS render-blocking on cold launch + Fontshare ToS for App Store republication. Existing STUB at `.planning/decisions/2026-05-08-perimeter-mvp-fonts-tokens-v2/STUB.md` to absorb.
**Depends on**: Phase 90 (lint LINT-04 prefer_mint_fonts must be active before sweep)
**Requirements**: FONTS-01 Supreme bundled, FONTS-02 Gambarino bundled, FONTS-03 GoogleFonts removal, FONTS-04 Menthe-vive token added, FONTS-05 license review gate
**Success Criteria** (what must be TRUE):
  1. 0 occurrences of `GoogleFonts.` in `apps/mobile/lib/` (verified by `grep -rn "GoogleFonts\." apps/mobile/lib/ | wc -l == 0`).  *Note: Phase 92 only swaps the landing hero; full sweep deferred to MVP-GOOGLEFONTS-PURGE-V1 per CONTEXT D-92.E. LINT-04 from Phase 90 blocks new GoogleFonts uses.*
  2. Supreme + Gambarino .otf files committed under `apps/mobile/assets/fonts/` ; pubspec.yaml `flutter.fonts` registers both with weight ramps.
  3. `MintTextStyle` and `MintColors` updated to reference Supreme as default sans-serif and Gambarino-italic for display ; Menthe-vive added to `lib/theme/colors.dart` with semantic token name.
  4. License review gate: Fontshare ToS for App Store republication validated by Julien (signed-off in PR description) ; fallback `GoogleFonts.inter` + Gambarino-only italic display documented as escape hatch.
**Requirements (planned)**: FONT-01 (.otf bundled + pubspec), FONT-02 (mentheVive tokens), FONT-03 (Gambarino + Supreme MintTextStyles), FONT-04 (dark palette + ThemeData.dark), FONT-05 (sample landing hero + G1 sim), FONT-06 (Fontshare LICENSE files), FONT-07 (golden re-baseline scoped to landing per D-92.A), FONT-08 (analyze + test green; lint baseline preserved). Note: ROADMAP previously listed FONTS-01..05 — Phase 92 plans use FONT-XX (without S) for consistency with CONTEXT.md.
**Plans**: 3 plans
- [ ] 92-01-PLAN.md — Wave 1, autonomous — Font asset bundling (Fontshare .otf download + LICENSE files + pubspec.yaml fonts: block + flutter pub get)
- [ ] 92-02-PLAN.md — Wave 2, autonomous — Theme tokens (MintColors.mentheVive + 5 dark palette tokens + 5 new MintTextStyles using bundled families + ThemeData.dark factory + theme unit tests)
- [ ] 92-03-PLAN.md — Wave 3, NOT autonomous (Julien G2 checkpoint) — Sample landing hero swap + landing golden baseline + G1 sim screenshot + G2 device sign-off + 5-gate close-out SUMMARY

**Budget**: 3d
**Auto profile**: **L1** (UI tokens, mechanical sweep) — `/gsd-execute-phase` ; lints catch regressions ; Maestro G1 flow renders Hero with new fonts.

### Phase 93: MVP-CTA-UNIFICATION-V1
**Goal**: Replace 9+ ad-hoc CTA primitives + 10 ElevatedButton outliers with `MintCTA.{primary,secondary,tertiary,destructive}` factory. ~80 sweep sites. Pre-flight categorization Day 1 — if >100 unique signatures, scope-cut to top-3 surfaces (Pulse / Chat input / Onboarding final CTA).
**Depends on**: Phase 90 (lint LINT-05 prefer_mint_cta must be active)
**Requirements**: CTA-01 4 variants implemented, CTA-02 ≥80 sweep sites migrated, CTA-03 lint baseline preserved
**Success Criteria** (what must be TRUE):
  1. `apps/mobile/lib/theme/components/mint_cta.dart` exposes `MintCTA.primary`, `MintCTA.secondary`, `MintCTA.tertiary`, `MintCTA.destructive` factories with consistent paddings/elevations/typography per `docs/DESIGN_SYSTEM.md`.
  2. ≥80 call sites migrated from ad-hoc `ElevatedButton` / custom `_PillButton` / `_GlassCTA` etc. to `MintCTA.*`.
  3. `tools/checks/prefer_mint_cta.py` baseline NOT regressed ; LINT-05 pass on touched files.
  4. Maestro flow `flow_cta_pulse_onboarding_render.yaml` validates CTA visual parity on Pulse + Onboarding final screen.
**Plans**: TBD

**Budget**: 4d (optimistic ; pre-flight categorization Day 1 gates scope)
**Auto profile**: **L1** (UI sweep, mechanical) — heavy mechanical sweep + visual diff via Maestro.

### Phase 94: MVP-CITATION-GATE
**Goal**: Post-process parser on narrator output. Narrator output rejected if ANY number or legal claim is emitted without a `[citation:source_id]` reference. Closes the « ChatGPT clone » fear mechanically — narrator is structurally incapable of un-cited numbers. Hard-cap retries at 1, fall back to templated « je n'ai pas la donnée » on retry failure.
**Depends on**: Phase 91 (extractor + narrator split must exist before citation parser hooks into narrator output stage)
**Requirements**: GATE-01 number detection regex, GATE-02 citation source registry, GATE-03 retry-or-fallback flow, GATE-04 banned-claim list
**Success Criteria** (what must be TRUE):
  1. New `app/services/coach/citation_parser.py` parses narrator output, detects every CHF amount / percentage / legal article / regulatory constant ; rejects emission if no `[citation:profile|reasoning|tool_call_id|adr|spec]` is adjacent.
  2. Narrator response retry-once on rejection with explicit reprompt « cite ton chiffre ou ne l'émets pas » ; second failure returns templated « je n'ai pas cette donnée pour l'instant » with no number.
  3. 50-fixture eval pack (`tests/fixtures/citation_gate_eval_50.jsonl`) passes ≥95% on Sonnet narrator and ≥90% on Haiku narrator.
  4. Maestro flow `flow_narrator_refuses_uncited_numbers.yaml` PASSES — sends a profile-empty user with chat « combien je gagne ? » and asserts the response does NOT contain a fabricated CHF number.
**Plans**: TBD

**Budget**: 3d
**Auto profile**: **L2** (backend + LLM eval gate) — Stage 3 eval mandatory before merge.

### Phase 95: MVP-DAG-INVALIDATION
**Goal**: Add `inputs_hash` + `superseded_by` on every projection (LPP, AVS, 3a, marge fiscale). Calculator refuses stale cache when input hash differs from current profile hash. Closes silent stale-projection bug (user updates salary in onboarding ; old LPP projection card shows old number for 3 days).
**Depends on**: Phase 94 (citation gate must reference projection IDs ; staleness propagates upward)
**Requirements**: DAG-01 inputs_hash on every projection, DAG-02 superseded_by chain, DAG-03 staleness=high flag, DAG-04 additive migration (hash nullable for backward compat)
**Success Criteria** (what must be TRUE):
  1. `apps/mobile/lib/services/financial_core/` projection models gain `inputs_hash: String` + `superseded_by: ProjectionId?` fields ; backend `services/backend/app/models/projection.py` mirrors.
  2. Calculator wrappers compute hash on read ; if hash mismatch with current profile hash → return last-known-good with `staleness: high` flag (UI surfaces « valeur peut-être obsolète » badge).
  3. Migration is additive : `inputs_hash` is nullable ; existing profiles compute hash lazily on first read ; zero forced recomputation.
  4. Test: `tests/test_projection_dag_invalidation.py` covers (a) fresh hash → no staleness, (b) profile salary changes → projection hash mismatch → staleness=high, (c) recompute resets hash chain.
**Plans**: TBD

**Budget**: 4d
**Auto profile**: **L2** (backend + Flutter financial_core) — additive migration ; full pytest + flutter test ; Maestro flow on profile-edit → projection-card-staleness flow.

### Phase 96: MVP-CHAT-AS-VERB
**Goal**: Kill chat-tab as destination. Cards become the home. Tap « explique / simule / rassure-moi » on any card opens a 3-turn coached overlay grounded in that card's facts. Source-card context propagates to extractor + narrator. Hard 3-turn cap with feature flag default-on ; monitor `chat_overflow_turn_4` metric for adversarial walkback.
**Depends on**: Phase 95 (DAG-INVALIDATION must guarantee fresh projections before chat surfaces them)
**Requirements**: VERB-01 intent bar on cards, VERB-02 3-turn cap, VERB-03 source-card context propagation, VERB-04 chat-tab kill behind flag, VERB-05 chat_overflow_turn_4 metric, VERB-06 walkback path
**Success Criteria** (what must be TRUE):
  1. Card components (LPP, AVS, 3a, marge fiscale, hero) gain `MintCardActionBar` widget with 3 verbs (explique / simule / rassure-moi) ; tap opens `MintChatOverlay` modal in place.
  2. `MintChatOverlay` propagates source card facts to backend `coach_chat` request as `source_card_id` + `source_card_facts` body fields ; backend reads and primes narrator system prompt with card snapshot.
  3. 3-turn cap enforced server-side ; turn 4 returns templated « je vais m'arrêter là — ouvre la simulation pour creuser » with deep-link to Explorer scene.
  4. Chat-tab in main nav hidden behind feature flag `CHAT_TAB_VISIBLE=false` (default-on for kill) ; flag-off for emergency walkback.
  5. Sentry metric `chat_overflow_turn_4` fires on every cap-hit ; alert fires if rate >40% of sessions over 7 days (walkback signal).
  6. Maestro flow `flow_card_action_intent_bar.yaml` validates LPP card → tap « explique » → 3-turn flow → cap → deep-link to Explorer.
**Plans**: TBD

**Budget**: 5d
**Auto profile**: **L2** (cross-stack: Flutter UI + backend chat + flag rollout) — full GSD chain ; Maestro G1 + creator-device G2 + soak metric (7-day) before flag-on in prod.

### Cross-cutting concerns

- **Maestro flow library** : 7 new flows (one per phase) under `tools/simulator/flows/maestro-perfect-set/`. Indexed.
- **ARB sweep** : ~132 ARB additions across 6 locales (CTA + chat-as-verb intents + citation-gate error strings). One parity check per PR.
- **Banned-terms / accent / LSFin** : pre-commit hook already wired (lefthook) ; narrator output additionally validated at runtime by CITATION-GATE parser.
- **Performance budget** : cold launch ≤2.5s at W3 + W4 close ; agent loop ≤30s on EXTRACTOR-V2 + CITATION-GATE eval suite.
- **Backward compat** : DAG-INVALIDATION is additive (hash nullable) ; existing profiles compute hash lazily ; zero forced recomputation.

### Risks (per memory feedback_design_panel_before_push)

1. CTA sweep slips beyond 4d (80 sites optimistic). Mitigation: pre-flight categorization Day 1.
2. CITATION-GATE retry loop blows token budget. Mitigation: hard-cap retries at 1, templated fallback.
3. DAG-INVALIDATION breaks profiles. Mitigation: additive migration, nullable hash.
4. CHAT-AS-VERB user revolt. Mitigation: feature flag default-on, monitor `chat_overflow_turn_4`.
5. FONTS license. Mitigation: Fontshare ToS review gate before W1 merge.
6. Adversarial counter-thesis « chat IS the product ». Mitigation: 3-turn cap is the hypothesis being tested ; walkback path baked in.

---
*Last updated: 2026-05-09 — v2.8 closed at 5/9 + 13 decimals ; v2.9 Coach Visuel Hybride superseded ; v2.9 Chat-as-Verb Pivot ACTIVE with Phases 90-96. Phase 90 shipped (PR #543) ; Phase 91 RESEARCH.md done, awaiting CONTEXT.md.*
