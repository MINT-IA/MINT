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
- 🪦 **v2.9 Chat-as-Verb Pivot** — KILLED 2026-05-16 — see [decisions/2026-05-16-phase-96-killed.md](decisions/2026-05-16-phase-96-killed.md). Foundation phases (91/93.5/94/95) preserved as **v2.9 Lucidité Foundation** ; kill-tab + cards-home destination doctrine dropped. Direction restored : chat reste la porte d'entrée, tab Coach reste, widgets explorables inline ("Coach didactique vivant").
- ◆ **v2.10 Lucidité Engine** — code-shipped on dev 2026-05-17, pending operational gates — Phase **mint-calc-engine-v1** closed 20/20 plans across W1-W4 (109 commits on `dev`, suite 7264, zero regression). Per CLAUDE.md §9.5 (0-TRUST 4-stage shipping pipeline) the phase is Stage 1 of 4 — cannot claim ✅ SHIPPED without Julien G2 device sign-off + 7 deferred operational gates (see [`phases/mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md`](phases/mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md) § Deferred). See [decisions/2026-05-16-calc-engine-matrix.md](decisions/2026-05-16-calc-engine-matrix.md) for the full 4-problem framing.
- 📋 **v2.11 Data Architecture v1 — Trust & Compliance Foundation** — initiated 2026-05-17 — see [decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md](decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md). Phase **mint-data-architecture-v1-01-calc-engine-canonical** opens the milestone — resolves the upstream calc-engine ownership conflict (mobile-canonical vs backend-canonical) that gates the event-log + projection migration (deferred Phase 02) and the coach-extractor guardrails (deferred Phase 03). Phases 02 + 03 will be declared in ROADMAP only after this phase's outcome is locked.
- 🚧 **Active GSD: Core Journey Truth / Prod Ready** — opened 2026-06-01 on branch `qa/salvage-profile-truth-20260601` — convergence phase, not feature phase. Goal: one narrow beta-quality story with one user truth, coherent navigation, reduced duplicate surfaces, current/cited Coach claims, and Maestro-proofed journeys. Source of truth: [`phases/mint-prod-ready-core-journey-truth-20260601/CONTEXT.md`](phases/mint-prod-ready-core-journey-truth-20260601/CONTEXT.md), [`PLAN.md`](phases/mint-prod-ready-core-journey-truth-20260601/PLAN.md), [`CORE-JOURNEY-TRUTH-MAP.md`](phases/mint-prod-ready-core-journey-truth-20260601/CORE-JOURNEY-TRUTH-MAP.md), [`JOURNEY-TRUTH-MATRIX.md`](phases/mint-prod-ready-core-journey-truth-20260601/JOURNEY-TRUTH-MATRIX.md), [`BUG-TRACKER.md`](phases/mint-prod-ready-core-journey-truth-20260601/BUG-TRACKER.md). Anti-drift guard: `python3 tools/checks/cjt_context_guard.py`.

  **Quality governance goals added 2026-06-04.** This GSD now has three
  explicit operating gates in addition to product journey proof:
  1. **No drift** — every session starts from the active CJT roadmap, matrix,
     bug tracker, and context guard; no chat-only priority list may outrank
     those files.
  2. **Quality ratchet** — each wave must either close a tracked row, improve a
     proof level, or reduce documented debt; progress is measured in the
     matrix, not in narrative confidence.
  3. **No new untracked debt** — every commit records a debt delta. Accepted
     debt must have an ID, owner/scope, severity, evidence, and next proof.

### Phase: mint-illogism-fixes
**Goal**: Fermer les 5 causes racines des 44 illogismes confirmés (matrice [`reports/MATRIX-illogismes-2026-06-09.md`](reports/MATRIX-illogismes-2026-06-09.md), 8 archétypes, vérifiés par agent adverse, + annexe device D1-D12) : W1 **source unique** — router avoir LPP / taux de conversion / taux de remplacement / plafond 3a vers `financial_core` (canonique L1), supprimer les implémentations inline divergentes (~27 findings DIVERGENT, p.ex. `coach_profile.dart:3577` vs `minimal_profile_service.dart:196`, écarts +15% à +105%) ; W2 **vérité d'archétype à l'onboarding** — questions statut emploi + état civil + lacunes AVS, gates divorcé (pas de LPP estimée), frontalier (3a gated quasi-résident), FATCA global (pas point-defense) (~10 ILLOGICAL_FOR_ARCHETYPE) ; W3 **discipline estimé-vs-connu (SOT §5)** — tags « estimé », Confidence Gate <50 appliqué, suppression des défauts fiction `rente_vs_capital_screen.dart:62-66`, jamais de hero depuis un estimateur ; W4 **corrections de domaine** — split divorce sur part-mariage seulement (CC art. 122), gapFactor AVS jeune/retour, suggestion 3a plafonnée au plafond légal ; W5 **UX/a11y** — ILLOG-02 arbre AX vide RvC (P1), CTA mort tableau retraite, conjoint fictif `mariage_screen`, clés brutes a11y.
**Status**: 📋 Planned — opened 2026-06-11 under milestone Core Journey Truth / Prod Ready (la matrice EST du journey-truth).
**Depends on**: `reports/MATRIX-illogismes-2026-06-09.md` (contrat d'entrée) ; flows de régression `tools/simulator/flows/regression/bug__ILLOG0{1,2}*.yaml` (OPEN-RED, doivent passer GREEN) ; coexiste avec `mint-data-architecture-v1-02-deploy` (pas de chevauchement schéma — cette phase est calcul mobile + UX onboarding).
**Acceptance**: chaque ligne de matrice fermée = oracle de reproduction re-run vert + device-proof sim (0-TRUST §9) ; flows ILLOG01/02 GREEN ; aucun claim sans citation.
**Plans**: 17 plans (14 vagues d'exécution — séquentiel sur les hotspots minimal_profile_service + ARB, parallèle waves 7/8/12)
Plans:
- [x] mint-illogism-fixes-01-w1-lpp-avoir-canonical-PLAN.md — avoir LPP → LppCalculator (+ squelette parité Wave 0)
- [x] mint-illogism-fixes-02-w1-lpp-rente-conversion-PLAN.md — rente LPP → adjustedConversionRate partout (+ impact rachat)
- [x] mint-illogism-fixes-03-w1-replacement-rate-net-PLAN.md — taux de remplacement NET unique + base nette NetIncomeBreakdown
- [x] mint-illogism-fixes-04-w1-plafond-3a-net-base-PLAN.md — plafond 3a indépendant sur revenu NET (OPP3 art.7 al.2)
- [x] mint-illogism-fixes-05-w1-3a-tax-saving-married-PLAN.md — économie 3a isMarried/children + device-proof W1
- [x] mint-illogism-fixes-06-w2-onboarding-archetype-questions-PLAN.md — questions statut emploi / état civil / lacunes AVS
- [x] mint-illogism-fixes-07-w2-lpp-zero-divorce-gates-PLAN.md — prédicat LPP=0 unifié + gate divorcé
- [x] mint-illogism-fixes-08-w2-3a-eligibility-fatca-global-PLAN.md — FATCA gate global GoRouter + 3a quasi-résident
- [x] mint-illogism-fixes-09-w5-illog02-rvc-semantics-PLAN.md — ILLOG-02 arbre AX RvC (débloque le gate Maestro d'ILLOG-01)
- [x] mint-illogism-fixes-10-w3-rvc-fiction-defaults-PLAN.md — défauts fiction RvC tués + flow ILLOG01 GREEN
- [x] mint-illogism-fixes-11-w3-confidence-gate-estime-tags-PLAN.md — Confidence Gate <50 + hero 3 états + source de confiance unique
- [x] mint-illogism-fixes-12-w4-divorce-split-mariage-PLAN.md — split divorce borné à la part-mariage (CC art.122)
- [x] mint-illogism-fixes-13-w4-avs-gapfactor-PLAN.md — gapFactor AVS plumbé + scène rente_trouee honnête
- [x] mint-illogism-fixes-14-w4-3a-suggestion-cap-PLAN.md — suggestion 3a plafonnée au plafond légal restant
- [x] mint-illogism-fixes-15-w4-affordability-unify-lcc-PLAN.md — revenu de ménage unifié + citation LCC corrigée
- [ ] mint-illogism-fixes-16-w5-cta-dashboard-truth-PLAN.md — tableau retraite sur la source /home + CTA vivant
- [ ] mint-illogism-fixes-17-w5-surfaces-honnetes-strings-PLAN.md — what-if mariage étiqueté + labels a11y + i18n + clôture device D1-D12

### Phase: mint-calc-engine-v1
**Goal**: Make MINT's ~57 already-shipped Swiss financial calculators (LLM-)discoverable, real-profile-grounded, architecturally findable, and DAG-reactive. Build the lucidité engine (L1 chiffrer / L2 comparer / L3 éclairer / L4 invariants) on top of the existing calc surface. Does NOT add new calculators in v1 — the surface already exists (per [decisions/2026-05-16-calc-engine-matrix.md](decisions/2026-05-16-calc-engine-matrix.md), 57 ✅ + 4 ⚠️ + 3 ❌ truly absent).
**Status**: ◆ code-shipped on dev 2026-05-17, pending operational gates — 20/20 plans landed across 4 waves on `dev` (109 commits, backend suite **7264 passed** zero regression). Phase is Stage 1 of 4 per CLAUDE.md §9.5 — cannot claim ✅ SHIPPED without **G2 Julien device sign-off** + 7 deferred operational gates (staging env-flip · Railway cron activation · Railway metrics scraping · endpoint metric fanout · Flutter 45-field drift fix incl. dead-COUP-04 · FR description tone review · S12-API consolidation). See [`phases/mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md`](phases/mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md) + [`phases/mint-calc-engine-v1/mint-calc-engine-v1-VERIFICATION-REPORT.html`](phases/mint-calc-engine-v1/mint-calc-engine-v1-VERIFICATION-REPORT.html).
**Depends on**: Wave 1c-A3 (held — see decisions/2026-05-16-calc-engine-matrix.md §"Sequencing"). Phase 96 KILLED — replaces that doctrine slot. Plan 01 cherry-picks A3 envelope `_response.py` if not yet merged to dev.
**Requirements**: D-CE-01, D-CE-02, D-CE-03, D-CE-04, D-CE-05, D-CE-06, D-CE-07, D-CE-08, D-CE-09, D-CE-10, D-CE-11, D-CE-12, D-CE-13, D-CE-14, D-CE-15, D-CE-16, D-CE-17, D-CE-18, D-CE-19, D-CE-20 + Concerns A/B/C/D/E/F + Findings 3/4/5/6
**Plans**: 20 plans (W1: 6, W2: 5, W3: 5, W4: 4)
Plans:
- [x] mint-calc-engine-v1-01-w1-shared-helpers-PLAN.md — shared `_resolve_defaults` + `get_profile_filled` + `raise_incomplete_as_422` + A3 envelope cherry-pick + `client_with_blank_profile` fixture
- [x] mint-calc-engine-v1-02-w1-priority1-endpoints-PLAN.md — Priority-1 sev-3 endpoint grounding (allocation_annuelle + affordability + rachat_echelonne) ; sev-3 null-canton crash class closed (T-mint-calc-02-03) ; Rule-2 auto-add of Depends(require_current_user) on mortgage + lpp_deep routes ; 12 cumulative from_profile markers ; 6958 backend tests green (+11)
- [x] mint-calc-engine-v1-03-w1-priority2-endpoints-PLAN.md — Priority-2 endpoint grounding (wealth_tax/estimate + life-events/succession/simulate + family/concubinage/succession + arbitrage/location-vs-propriete) ; silent-wrong-tax sev-3 class structurally closed via Required-to-Optional widening ; Rule-2 auto-add of Depends(require_current_user) on 3 previously-anonymous routes ; 16 cumulative from_profile markers (12 Plan 02 + 4 Plan 03) ; 6970 backend tests green (+12) ; cumulative W0 closure 4 sev-3 + 3 sev-2 endpoints
- [x] mint-calc-engine-v1-04-w1-lucidity-payloads-PLAN.md — L1/L2/L3/L4 typed payloads + L4 wedge endpoint (Finding 5)
- [x] mint-calc-engine-v1-05-w1-calc-registry-PLAN.md — AST scanner generator + `_registry.py` AUTO-GENERATED (63 calcs across 12 domains + 146 REVERSE_DEP_MAP fields, 25 canton-dependent) + 13 contract tests + Q2 resolved CI-only ; D-CE-09 Strangler-fig honored (zero physical moves) ; D-CE-14 reverse-dep map seed ships as side product (kills two birds per Override #5) ; 7002 backend tests green (+13 vs Plan 04 baseline 6989)
- [x] mint-calc-engine-v1-06-w1-sev2-batch-grounding-PLAN.md — W1 wave-close batch grounding (4 batches × ~5 endpoints = 19 endpoints grounded ; cumulative W1 closure = 26 endpoints with `Depends(get_profile_filled)`) ; `services/backend/tests/test_blank_profile_422_contract.py` 28 cases (26 parametrized + 2 regression guards) ; Slowapi `_route_limits` cross-pollution discovered & fixed via `monkeypatch.setattr` (no more `importlib.reload` of endpoint modules) ; 7030 backend tests green (+28 vs Plan 05 baseline 7002, zero regressions). MCP engram save deferred for 6th consecutive plan despite merge bc07d915 — tools registered as MCP server but NOT exposed in executor agent callable function list.
- [x] mint-calc-engine-v1-07-w2-tool-registry-adapter-PLAN.md — ToolRegistryAdapter Protocol + 3 concrete adapters + factory
- [x] mint-calc-engine-v1-08-w2-bundles-PLAN.md — IndependentTaxBundle + SuccessionDivorceBundle (9 bundles total)
- [x] mint-calc-engine-v1-09-w2-tool-description-rewrite-PLAN.md — Concern A rubric lint + ≥35 FR description rewrites + Tool Search round-trip + Maestro G1 (NOT autonomous — Julien G2 checkpoint)
- [x] mint-calc-engine-v1-10-w2-coach-tool-response-v2-PLAN.md — CoachToolResponse V2 with `latency_tier` (Parallel Change V1→V2 per D-CE-19)
- [x] mint-calc-engine-v1-11-w2-deprecation-shims-PLAN.md — independant_service.py + frontalier_service.py root shims (D-CE-10)
- [x] mint-calc-engine-v1-12-w3-composite-index-migration-PLAN.md — Alembic p110 composite partial index (autocommit_block) — Finding 3 critical gap
- [x] mint-calc-engine-v1-13-w3-cache-reader-writer-singleflight-PLAN.md — Cache reader + writer + AsyncSingleflight + get_or_compute (Concern E)
- [x] mint-calc-engine-v1-14-w3-reverse-dep-map-PLAN.md — REVERSE_DEP_MAP regenerated alongside REGISTRY (D-CE-14 «kills two birds»)
- [x] mint-calc-engine-v1-15-w3-pre-compute-background-tasks-PLAN.md — `precompute_after_fact_save` BackgroundTasks + SLI precision/recall tests
- [x] mint-calc-engine-v1-16-w3-gc-job-PLAN.md — Daily GC job (Railway cron) for superseded scenarios (Finding 4) — `purge_superseded_scenarios(db, max_age_days=30, dry_run=False)` + `scripts/run_gc.py` standalone runner + `railway.cron.json` (cronSchedule `0 3 * * *`, schema-validated against `backboard.railway.app/railway.schema.json`) ; 6 new tests, 7189 backend tests green (+6 vs Plan 15 baseline 7183, zero regressions) ; **Railway cron service activation DEFERRED to Julien GO** — declaration committed to repo as `services/backend/railway.cron.json` ; Julien creates the Railway service + points Config-as-code Path to that file. W3 wave-close code-side complete (Plans 12+13+14+15+16 all landed). Finding 4 closed structurally.
- [x] mint-calc-engine-v1-17-w4-metrics-counters-PLAN.md — Prometheus counters + `/metrics` + `inputs_provenance` schema — NOT autonomous (Open Q1 prometheus-vs-sentry decision)
- [x] mint-calc-engine-v1-18-w4-banned-verb-lint-runtime-gate-PLAN.md — 11 paraphrase verbs lint extension + runtime gate with NFKC + zero-width — NOT autonomous (Open Q5 placement decision)
- [x] mint-calc-engine-v1-19-w4-profile-safe-fields-parity-PLAN.md — Flutter↔server parity lint + lefthook wiring (Concern C)
- [x] mint-calc-engine-v1-20-w4-wave-close-engram-doctrine-PLAN.md — Phase close: VERIFICATION-REPORT.html (541 lines, phase-level rollup + 5-gate exit panel + per-wave + cumulative metrics + critical discoveries + 8 deferred items + engram doctrine roll-up + lessons learned) + SUMMARY.md (per-D-CE-XX + per-Concern + per-Finding disposition) + ROADMAP/STATE updates + phase-level engram observation (Concern F compounding observable ≥10 prior_finding_refs) + G3 ✓ commit sha trail (109 commits) + G4 ✓ backend suite 7264 zero regression + G5 ✓ lints exit 0 + G1 skipped cleanly (no sim booted, standard caveat) + G2 explicitly DEFERRED to Julien per `autonomous: false` plan. **Phase status: ◆ code-shipped on dev, pending operational gates** — NOT ✓ SHIPPED.

**Canonical refs**:
- `.planning/decisions/2026-05-16-calc-engine-matrix.md` — 11-category matrix + hypothesis C audit plan + 4-level lucidité framework
- `.planning/decisions/2026-05-16-phase-96-killed.md` — doctrine pivot context
- `.planning/decisions/2026-05-14-phase-7-ship-or-pause.md` — Option C Coach didactique vivant decision
- `.planning/decisions/2026-05-16-calc-engine-v1-panel-synthesis.md` — 20 D-CE-XX verdicts table + 11 overrides + 6 critical findings
- `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md` — locked decisions source-of-truth
- `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md` — HOW-to-implement code patterns
- `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md` — Nyquist verify map per task ID
- `.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md` — 49/57 hypothesis C confirmed + 12 sev-3 + 23 sev-2
- `services/backend/app/services/arbitrage/allocation_annuelle.py` — the joint optimiser that already exists
- `services/backend/app/api/v1/endpoints/arbitrage.py:163-213` — hypothesis C evidence surface
- `CLAUDE.md` §1 + §3.5 + §9
- `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-CONTEXT.md` — missing-fields handshake doctrine (calc-engine-v1 generalizes it)


### Phase: mint-data-architecture-v1-01-calc-engine-canonical
**Goal**: Resolve the upstream `apps/mobile/lib/services/financial_core/` vs `services/backend/app/services/` calc-engine ownership conflict (CLAUDE.md triplet #3 ↔ docs/AGENTS/backend.md:39). Pick a canonical home for ~10 279 LOC mobile calculators + 76 backend services + auto-generated `_registry.py` bridge, and define the sync mechanism in the other direction. This is upstream of every detail in the panel-converged data-layer shape (event-log + projection + DEK envelope) per [decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md §"Calc-engine integration (deferred to GSD discuss-phase 1)"](decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md). Does NOT migrate fact storage (that is deferred Phase 02). Does NOT change coach extraction (that is deferred Phase 03).
**Status**: 📋 5 plans created 2026-05-17 (4 waves) — ready for /gsd-execute-phase.
**Plans**: 5 plans (W1: 1, W2: 1, W3: 2 parallel, W4: 1)
**Depends on**: `mint-calc-engine-v1` Stage 1 close (code-shipped on dev 2026-05-17). Phase 0 hot-fix `hotfix/compliance-2026-05-17` (coach_insights consent + SnapshotModel.constants_version_hash + DEK shred wiring) merges in parallel per the ADR — separate from GSD and out of scope here.
**Blocks**: deferred Phase 02 (event-log + projection schema migration), deferred Phase 03 (coach-extractor LLM + guardrails). The panel ADR explicitly assumed backend-canonical for the downstream shape; if mobile-canonical wins, the ADR's downstream phases require revision before being declared.
**Open questions to resolve in CONTEXT.md**:
- Canonical home (mobile-canonical vs backend-canonical vs split-with-explicit-arbiter) and rationale grounded in offline-first, LSFin advice-audit, archetype routing, and Maestro UAT constraints.
- Sync mechanism direction and surface (mobile-canonical ⇒ how backend ingests/projects ; backend-canonical ⇒ how mobile fetches projections + handles offline).
- Migration path for today's 10 279 LOC mobile + 76 backend services + `_registry.py` bridge (strangler-fig preserving `_registry.py` doctrine per D-CE-09 vs big-bang).
- LSFin advice-audit consequences per ownership choice — where `constants_version_hash` lives, where audit-record provenance is computed.
- Reconciliation with `mint-calc-engine-v1` shipped work — what stays, what gets re-homed.

**Open questions disposition**: All 5 resolved in `.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/mint-data-architecture-v1-01-calc-engine-CONTEXT.md` §<decisions> (D-01..D-16 locked).

Plans:
- [x] 01-01-PLAN.md — Wave 1, autonomous — Pre-flight bundle-size validation (D-14, 100 KB ceiling) + 3 telemetry counters declared in app/core/metrics.py (D-13 implication, CONTEXT §"What this discussion did NOT address")
- [x] 01-02-PLAN.md — Wave 2, autonomous — Doctrine rewrite + ADR flip in SAME PR per D-04 : CLAUDE.md §1 + TOP rule #4 + §5 NEVER #3 + BOTTOM rule 4 + docs/AGENTS/backend.md line 39 + docs/AGENTS/flutter.md + .claude/skills/mint-{flutter,backend}-dev/SKILL.md (NEW) + .planning/decisions/2026-05-17-... status: Proposed → Decided (calc-engine portion only)
- [x] 01-03-PLAN.md — Wave 3, autonomous — Backend sync endpoints `GET /v1/regulatory/constants/version` + `GET /v1/regulatory/constants/snapshot` (D-15) + ETag header + OpenAPI canonical regen
- [x] 01-04-PLAN.md — Wave 4, autonomous — `tools/codegen/regulatory_constants_to_dart.py` (D-08 + D-16) + `tools/codegen/doctrinal_constants_to_dart.py` (D-13) + 2 committed .g.dart files + lefthook 2 soft-warn hooks + `.github/workflows/regulatory-codegen.yml` with staging-down SOFT-WARN fall-back path
- [x] 01-05-PLAN.md — Wave 3 (parallel to 03), autonomous — Parity lint extension `tools/checks/profile_safe_fields_parity.py --check-constants` (D-12) in SOFT-WARN mode + lefthook hook ; Phase 02 first-migration PR promotes to HARD per D-12

**Canonical refs**:
- `.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md` — panel-converged shape, the 9 explicit data gaps (§"What does this source not address?"), and the calc-engine-canonical re-litigation triggers
- `.planning/decisions/2026-05-06-personal-financial-wiki-v3-candidate.md` — superseded wiki framing (historical context)
- `.planning/decisions/2026-05-16-calc-engine-matrix.md` — 11-category matrix + 4-level lucidité framework (the mint-calc-engine-v1 upstream)
- `.planning/decisions/2026-05-16-calc-engine-v1-panel-synthesis.md` — D-CE-09 strangler-fig + D-CE-10 deprecation-shims + D-CE-14 reverse-dep map (locked doctrine to honour)
- `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md` — locked decisions from the prior phase
- `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md` — what shipped + 8 deferred items + Concern C parity lint
- `apps/mobile/lib/services/financial_core/` — ~10 279 LOC mobile calculator surface (today's source-of-truth per CLAUDE.md triplet #3)
- `apps/mobile/lib/services/financial_core/lpp_calculator.dart` — hardcoded `static const` drift surface (`safeWithdrawalRate`, `survivorSpouseRate`)
- `services/backend/app/services/` — 76 backend services (today's source-of-truth per docs/AGENTS/backend.md:39 — the conflict)
- `services/backend/app/services/regulatory/registry.py` — backend `RegulatoryParameter` with `effective_from/to`
- `services/backend/app/services/calc/_registry.py` (auto-generated) — `mint-calc-engine-v1` Plan 05 strangler-fig bridge (D-CE-09)
- `services/backend/app/models/coach_insight.py` — `CoachInsightRecord` (Pattern D today, downstream compliance gap)
- `services/backend/app/models/snapshot.py` — projection storage (no `constants_version_hash` today)
- `services/backend/app/services/dek_vault.py` — crypto-shred mechanism (downstream-only; informational here)
- `CLAUDE.md` §1 + §5 D-07 NEVER #3 — current mobile-canonical declaration
- `docs/AGENTS/backend.md:39` — current backend-canonical declaration (the conflict)
- `tools/checks/profile_safe_fields_parity.py` — Concern C Flutter↔server parity lint (W4 Plan 19) — partial bridge of the gap today
- engram obs #150 (event-log decision) + #151 (panel compliance findings)

### Phase: mint-data-architecture-v1-02-event-log-projection
**Goal**: Migrate user-facts storage from `SnapshotModel` (cached projection keyed on inputs_hash) to event-log (`fact_event` append-only) + projection (`fact_current` denormalised) + DEK envelope per-user (Railway-native KMS). Extends `projection_audit_record` for mobile L1 session audit (closes Phase 01 D-05 LSFin audit-trail gap discovered by architect-review obs #176). Includes 4 Phase 01 carry-over security gaps + Phase 02 W0 prereqs (S12 API consolidation PR-1 + Flutter drift PR-A2 + Postgres migration test harness + 2 prevention lints).
**Status**: ◆ SUBSTRATE CODE-SHIPPED ON DEV 2026-05-19 — operational cutover (PR-3b/PR-4/PR-5 + Task 2a operational gate + Plan 02-04 autonomous tasks) split to follow-on phase `mint-data-architecture-v1-02-deploy`. 4 squash PRs landed on dev (#653 dc28f974, #657 d8c97dd1, #656 979e45f4, #655 40afcaba) + dev-CI consent-caplog hotfix in PR #658. Substrate close-out artifacts shipped via PR (this milestone close). 33 D-XX distributed across 4 plans : 22 ✅ shipped, 11 ⏸ split to Phase 02-deploy.
**Plans**: 4 plans — substrate-side complete on dev as code ; operational cutover split.

Plans:
- [x] mint-data-architecture-v1-02-event-log-01-prereqs-lints-harness-PLAN.md — W0 prereqs bundle (SHIPPED 2026-05-18 per `mint-data-architecture-v1-02-event-log-01-prereqs-lints-harness-SUMMARY.md`, squash `dc28f974` PR #653).
- [x] mint-data-architecture-v1-02-event-log-02-event-log-core-canary-PLAN.md — W1 event-log core + canary (BACKEND COMPLETE 2026-05-19 ; Mobile L1 device-side wiring DEFERRED to Phase 02-deploy ; squash `d8c97dd1` PR #657 ; D-25 + D-34 GREEN on SQLite).
- [~] mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md — W2-W3 6-PR sequence **CODE-PARTIAL** : PR-0 + PR-1 + PR-2 + iter-2 A10/B14/B18 + PR-3a code shipped via squash `979e45f4` PR #656 ; **PR-3b read-cutover + PR-4 FF removal + PR-5 SnapshotModel drop + Task 2a operational gate SPLIT to Phase 02-deploy** (gated on staging+prod alembic chains catching up to dev — both currently behind by 7+ and dozens of revs respectively ; staging-Postgres has 0 snapshots and no fact_event table, prod at `29_05_magic_link_tokens` head per `railway ssh` evidence 2026-05-19).
- [~] mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks-PLAN.md — W4 close-out: substrate close-out artifacts (VERIFICATION-REPORT.html + SUMMARY.md + STATE/ROADMAP/PROJECT updates + Phase 02-deploy CONTEXT.md bootstrap) SHIPPED 2026-05-19. **Task 1 (D-09 alias + D-10 dead-fields) + Task 2 (Q6 CI mechanical fixes) + Task 3 (declared_counters_must_fire HARD gate) + Task 4 (3 forward-deferred runbooks) SPLIT to Phase 02-deploy as autonomous follow-up PRs.**

**Depends on**: `mint-data-architecture-v1-01-calc-engine-canonical` ✓ shipped 2026-05-17 (sha `a21bc8d0`) + Hotfix B/C ✓ shipped via squash `cf6d259a` + Postgres BOOLEAN DEFAULT fix `fe52ba31`.
**Blocks**: deferred Phase 03 (coach-extractor LLM + guardrails — requires `fact_event(source_type='coach_inference')` schema from this phase).
**Open questions disposition**: 7 panel-debated questions all resolved in [decisions/2026-05-18-phase02-event-log-projection-panel-synthesis.md](decisions/2026-05-18-phase02-event-log-projection-panel-synthesis.md) (5-specialist consensus + 3 Julien-locked calls). CONTEXT.md encodes each as D-01..D-33. All 33 decisions are distributed across the 4 plans with zero gaps and zero double-counts (frontmatter `decisions:` field is the audit anchor).
**Canonical refs**:
- `.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md` — upstream « what shape » ADR (panel-converged)
- `.planning/decisions/2026-05-18-phase02-event-log-projection-panel-synthesis.md` — THIS phase's « how + when + trade-offs » lockdown (single canonical source)
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-CONTEXT.md` — 33 D-XX locked
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-RESEARCH.md` — implementation primitives (sha `055ca9e3`, 1451 lines, HIGH confidence)
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-VALIDATION.md` — Nyquist validation map (per-task verify commands + Wave 0 requirements + sampling cadence)
- `.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/mint-data-architecture-v1-01-calc-engine-CONTEXT.md` — upstream Phase 01 16 D-XX decisions (split-with-arbiter L1 mobile / L2-L4 backend)
- `.planning/phases/mint-calc-engine-v1/deferred-items.md` § S12-API-consolidation — load-bearing W0 prereq
- `services/backend/app/models/snapshot.py` — current `SnapshotModel` shape (migration source — dropped in Plan 02-03 PR-5)
- `services/backend/app/models/projection_audit_record.py` — Hotfix B shipped append-only audit table (extend with `source` discriminator + `app_version` + `observed_at` + `anonymous_session_id` for D-MOB-03 in Plan 02-02)
- `services/backend/app/models/audit_event.py` — Hotfix C `user_id_hash` (HMAC-pepper migration in Plan 02-02 W1 per obs #175)
- `services/backend/app/services/encryption/key_vault.py` — existing 2-backend KMS facade (logical-id pattern fits Q2 Railway-native, wired in Plan 02-02)
- `services/backend/app/services/regulatory/registry.py` — RegulatoryParameter source for `subject_type='regulatory'` event-log dual-write
- `apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart` — Phase 01 codegen output (mobile L1 audit reads `regulatoryConstantsVersionHash`)
- `services/backend/app/services/independants/` (S18) + `services/backend/app/services/expat/frontalier_service.py` (S23) — S12 façade-delegate-to-granular pattern (obs #183 + Julien promote IJM/LAA to S18 in Plan 02-01)
- `services/backend/app/api/v1/endpoints/coach_chat.py:957-1015` — `_PROFILE_SAFE_FIELDS` Stage-0 + D-MOB-01 drift inventory (Flutter-side emission gap closed in Plan 02-01 PR-A2 + Plan 02-04 PR-A3)
- `.github/workflows/regulatory-codegen.yml` — Q6 CI staging-down policy (extend with STAGING-MALFORMED status + scheduled-only aging writes + HARD label override in Plan 02-04)
- engram obs #163 (Phase 01 CONTEXT) · #174 (db-architect Q1+Q4+Q5) · #175 (security Q2+Q3+Q7 + STRIDE + HMAC-pepper) · #176 (architect-review integrated + mobile L1 audit gap discovery) · #178 (devops Q6 + 8-item PR-readiness + 6 new counters) · #182 (Q6 Railway-native scraping decided) · #183 (S12 design) · #186 (Flutter D-MOB design) · #187 (QA panel predicted Postgres bug) · #188 (Postgres BOOLEAN DEFAULT bug + fix) · #233 (substrate code-only on dev — operational deploy split 2026-05-19)

### Phase: mint-data-architecture-v1-02-deploy
**Goal**: Apply the Phase 02 substrate (fact_event + fact_current + DEK envelope + parity audit tables p118/p119 + projection_diff drift gate) to **staging then production** databases. Execute Plan 02-03 operational cutover (Task 2a staging gate + PR-3b read-cutover atomic + PR-4 FF removal + PR-5 SnapshotModel drop) and Plan 02-04 autonomous tasks (Q6 CI mechanical fixes + declared_counters_must_fire HARD gate + 3 forward-deferred runbooks). Includes alembic chain audit (prod at `29_05_magic_link_tokens` head, staging at `p112_audit_event_user_hash` head — both behind dev `p119_phase02_parity_cont` by 7+ to dozens of revs), staging-first migration apply with smoke, prod migration apply, 7-day continuous_drift_sampler soak window, Mobile L1 device-side wiring (DEFERRED-02-02-D/E/F + sqflite_sqlcipher + iOS entitlement isolated PR), and the 5 sec/arch FLAGs from QA panel (sec FLAG-2 + sec FLAG-4 + sec FLAG-5 + arch FLAG-2 + arch FLAG-3).
**Status**: 📋 OPEN 2026-05-19 — 4 PLAN.md authored 2026-05-19 (this session). RESEARCH + VALIDATION shipped. Wave 0 (Plan 01) prerequisite work + Wave 1 (Plan 02) staging operational + Wave 2 (Plan 03) PR-3b/PR-4/PR-5 cutover + Wave 3 (Plan 04 Tasks 1-9) close-out + Wave 4 (Plan 04 Tasks 10-11) prod migration apply + final 5-gate panel. Plans `autonomous: false` per Julien-checkpoint design — 7 CHECKPOINTS total across the phase. Operational-substrate gap discovery (engram obs #233) is the load-bearing premise.
**Plans**: 4 plans, 25 tasks total, 7 Julien CHECKPOINTS, 5 waves (W0 → W4).

Plans:
- [ ] mint-data-architecture-v1-02-deploy-01-alembic-chain-audit-PLAN.md — Wave 0 : alembic chain audit déterministe via `ScriptDirectory.walk_revisions` (14 revs prod→dev, 1 merge node `p98_merge_p86_eclairage`) + 2 baseline pg_dumps (staging + production) + 4-PR cleanup (PR A2 D-27 EXACT-EQUALITY idempotency + PR A3 JSONB cast/rollback/pepper tests + PR B observability infra : drift counter declaration + alembic_partition_safety_lint + caplog lefthook rule + railway_pg_dump.sh + conftest health-check + KMS naming audit). 4 tasks, autonomous: true. **Note 2026-05-20** : ORM-orphan safety net (`p122_orm_orphan_safety_net` creating `document_embeddings` + `document_audit_logs`) was extracted out of this plan and shipped as standalone hotfix PR (no users, no prod traffic — Wave 0 panel rigor is overkill per `project_no_real_prod_yet`). Plan-01 retains the original 4-PR cleanup scope ; the hotfix migration chains off `p119_phase02_parity_cont` directly, so Wave 0 PR A2 must chain off `p122` when it ships (not `p120` as previously locked).
- [ ] mint-data-architecture-v1-02-deploy-02-staging-migration-apply-PLAN.md — Wave 1 : staging state pre-flight probe (alembic head=p119 confirmed) + Task 2a operational sequence (FF=on staging + backfill x2 vacuous-idempotency + projection_diff full audit + counter snapshot) + Julien CHECKPOINT sign-off. 3 tasks (1 CHECKPOINT), autonomous: false.
- [ ] mint-data-architecture-v1-02-deploy-03-cutover-PR3b-PR4-PR5-PLAN.md — Wave 2 : continuous_drift_sampler cron activation + PR-3b atomic trio (read-cutover + D-12 HARD parity-lint + 7th gate pg_dump) + PR-4 FF removal + DeprecationWarning + no_ff_fact_event_dual_write HARD lefthook + PR-5 SnapshotModel drop (alembic `p121_drop_snapshot_legacy`, NOT p117 per locked decision avoiding p120 collision) + decommission runbook. 7 tasks (3 Julien CHECKPOINTS), autonomous: false.
- [ ] mint-data-architecture-v1-02-deploy-04-plan-02-04-tasks-PLAN.md — Wave 3 + Wave 4 : Plan 02-04 Task 1-4 (D-09 + D-10 + Q6 CI + declared_counters HARD + 3 runbooks + sentry-alert-config + branch-protection-config) + Mobile L1 device wiring (sub-PR A4a Dart-only + sub-PR A4b ISOLATED iOS entitlement per memory `feedback_ios_entitlements_block_testflight`) + 5 sec/arch FLAGs (sec FLAG-2/4/5 + arch FLAG-3 ; arch FLAG-2 UUID7 doc-only Phase 03) + DEFERRED-02-01-A merge check + PR D polish absorbed (sec FLAG-1 EXCLUDED per locked decision) + Wave 4 prod migration apply + final 5-gate panel close-out + VERIFICATION-REPORT.html + SUMMARY.md + ROADMAP/STATE flip. 11 tasks (2 critical Julien CHECKPOINTS — Mobile L1 design panel + final close-out), autonomous: false.

**Depends on**: `mint-data-architecture-v1-02-event-log-projection` ◆ substrate code-shipped on dev 2026-05-19.
**Blocks**: deferred Phase 03 (coach-extractor LLM + guardrails — requires fact_event substrate to be DEPLOYED, not just on dev).
**Canonical refs**:
- `.planning/phases/mint-data-architecture-v1-02-deploy/CONTEXT.md` — phase bootstrap (created 2026-05-19)
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-projection-SUMMARY.md` — Phase 02 substrate close-out narrative (what's done + what's split)
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-projection-VERIFICATION-REPORT.html` — substrate verification (5-gate panel)
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/deferred-items.md` — Plan 02-01/02-02 deferred items absorbed by this phase
- engram obs #233 — operational-substrate-gap finding (load-bearing premise)



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
- [x] **Phase 91: MVP-EXTRACTOR-V2** — Split single coach LLM into 2 distinct roles (extractor + narrator) ; 2 prompts, 2 guardrails, 2 budgets (completed 2026-05-09)
- [ ] **Phase 92: MVP-FONTS-TOKENS-V2** — Land Supreme + Gambarino + Menthe-vive ; drop GoogleFonts.* ; consume `docs/brand/MINT v2.html` + `docs/brand/MINT-brand.html` as design source
- [ ] **Phase 92.5: MVP-CALC-RIGOR-FOUNDATIONS** *(inserted 2026-05-10 per ADR calc-first ; scope-cut 2026-05-10 per CONTEXT D-02)* — Mobile↔Backend differential CI on 80–100 fixtures (existing parity surface) + Hypothesis property tests (8 invariants) + ESTV oracle pin (50 tax vectors) ; G6 calc-correctness gate added to PERIMETERS ; full 200-fixture coverage deferred to backlog 999.4
- [ ] **Phase 93: MVP-CTA-UNIFICATION-V1** — `MintCTA.{primary,secondary,tertiary,destructive}` replacing 9+ ad-hoc primitives + 10 ElevatedButton outliers
- [x] **Phase 93.5: MVP-SKILL-BUNDLE-COMPILER** *(inserted 2026-05-10 per Anthropic financial-services audit)* — Compile-time skill bundles (`pillar3a-optimizer`, `lpp-projector`, `tax-explainer`, `mortgage-stressor`, `compliance-narrator`, `life-event-router`) → single narrator prompt + tool allowlist + citation allowlist ; NOT runtime multi-agent (completed 2026-05-10)
- [x] **Phase 94: MVP-CITATION-GATE** — Closed-world numeric vocabulary (placeholders `{{cite:<key>}}` + post-hoc substitute) + CalcTrace propagated to widgets + `AI_MODEL_REGISTRY.md` + LSFin disclaimer systemic ; ADR calc-first N1 (completed 2026-05-10)
- [x] **Phase 95: MVP-DAG-INVALIDATION** — `inputs_hash` + `superseded_by` on every projection + `GroundingPack` JSON emitted by DAG (Pareto front + Sobol indices + what-ifs precomputed + credible intervals) ; ADR calc-first N2 (completed 2026-05-10)
- 🪦 **Phase 96: MVP-CHAT-AS-VERB — KILLED 2026-05-16** — kill-tab + cards-home doctrine dropped per [decisions/2026-05-16-phase-96-killed.md](decisions/2026-05-16-phase-96-killed.md). PAUSED 2026-05-14, KILLED 2026-05-16 (founder-signed risk veto). PRESERVED : `NarrativeSleeve {hook, caption, next_step, metaphor}` linter from 96-03 survives as a framing-agnostic discipline ; intent-bar UI scaffolding from 96-01 becomes vestigial pending re-evaluation. Direction restored : chat is porte d'entrée, tab Coach stays, widgets explorables inline (Coach didactique vivant).

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

### Phase 92.5: MVP-CALC-RIGOR-FOUNDATIONS *(inserted 2026-05-10)*
**Goal**: Make « calc engine = source of truth » a credible claim with mechanical CI gates per ADR `2026-05-09-calc-first-llm-illumination.md` N3 (Expert 7 production reliability synthesis). Three independent grounding axes that block silent regressions before they reach narrator output.
**Depends on**: Phase 92 (theme tokens stable so Mobile↔Backend differential focuses on calc, not theme drift)
**Requirements**: CALC-01 Mobile↔Backend differential harness, CALC-02 Hypothesis property test suite, CALC-03 ESTV oracle pin, CALC-04 G6 calc-correctness gate added to PERIMETERS.md
**Success Criteria** (what must be TRUE):
  1. `services/backend/tests/test_calc_diff_harness.py` drives `apps/mobile/tools/calc_harness/main.dart` (compiled via `dart compile exe`) over 80–100 fixtures (existing parity surface only) sourced from `services/backend/tests/fixtures/calc_diff_v1.jsonl` ; tolerance per axis: rentes ±1 CHF, canton tax ±5 CHF, small ratios ±0.05 ; any divergence blocks merge. Full 200-fixture coverage including AVS rente projection + LPP retirement projection deferred to backlog 999.4 (Phase 92.6) per CONTEXT 92.5 D-01/D-03 (no Python parity exists today for the 3 locked Dart projection methods).
  2. `services/backend/tests/test_property_invariants.py` uses `hypothesis` ≥6.111 to assert 8 invariants on `AvsCalculator`, `LppCalculator.projectToRetirement`, `TaxCalculator.capitalWithdrawalTax`: (a) bounds (no negative rentes), (b) monotonicity (higher salary → higher LPP), (c) couple cap (RAMD respected), (d) anticipation sign (anticipation reduction is negative), (e-h) rounding consistency Mobile vs Backend.
  3. `services/backend/tests/fixtures/estv_oracle_2025.jsonl` captures 50 (input_profile, expected_tax) vectors from `swisstaxcalculator.estv.admin.ch` ; `pytest tests/test_estv_oracle.py` matches MINT computed against ESTV expected within tolerance ; staleness flag per ADR-20260223-unified-financial-engine.md.
  4. PERIMETERS.md gains 6th mechanical gate « G6 calc-correctness » alongside existing G1-G5 ; orchestrator's `verify_phase_goal` step calls G6 for any phase touching `financial_core/` or `services/backend/app/services/`.
**Plans**: TBD (3 plans projected: 92.5-01 differential harness + 92.5-02 property suite + 92.5-03 ESTV oracle)

**Budget**: 5d
**Auto profile**: **L2** (backend Python + Dart cross-compilation) — `cd services/backend && pytest tests/test_property_invariants.py tests/test_estv_oracle.py` + Mobile harness via `dart compile exe` ; G6 gate added to STATE machine.

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

### Phase 93.5: MVP-SKILL-BUNDLE-COMPILER *(inserted 2026-05-10)*
**Goal**: Adopt the Anthropic financial-services agent template's *patterns* (not the runtime topology) per audit `.planning/audit/codebase-audit-2026-05-10/anthropic-financial-services-agents.md`. Restructure narrator prompts as compile-time skill bundles (Tax / Pillar3 / Mortgage / Compliance / Life-Event-Router) emitting one narrator prompt + tool allowlist + citation allowlist. NOT runtime multi-agent (ROI negative pre-TestFlight: +30-60% tokens, +2-4s p50 latency, ×4 prompt-eng surface).
**Depends on**: Phase 92.5 (calc-rigor must be in place — bundles emit citation_allowlist consumed by Phase 94)
**Requirements**: BUNDLE-01 6 named bundles in `services/backend/app/services/coach/bundles/`, BUNDLE-02 compiler emits prompt + tool allowlist + citation allowlist, BUNDLE-03 wiring into `coach_chat.py` `build_narrator_system_prompt`, BUNDLE-04 deprecation of monolithic `_NARRATOR_BASE_SYSTEM_PROMPT`
**Success Criteria** (what must be TRUE):
  1. `services/backend/app/services/coach/bundles/` exposes 6 modules: `pillar3a_optimizer.py`, `lpp_projector.py`, `tax_explainer.py`, `mortgage_stressor.py`, `compliance_narrator.py`, `life_event_router.py` ; each declares `prompt_fragment: str`, `allowed_tools: list[str]`, `citation_allowlist: list[str]`.
  2. `services/backend/app/services/coach/bundle_compiler.py` reads detected user intent (from extractor's life_event field) and composes a single narrator prompt + filtered tool list + citation allowlist for `coach_chat.py:build_narrator_system_prompt`.
  3. Narrator prompt size per request ≤8k tokens (vs current monolithic ~30k) ; cost regression ≤−40% per turn measured on 50-fixture eval pack.
  4. Phase 94 CITATION-GATE consumes `citation_allowlist` from compiled bundles to validate narrator output (closed-world numeric vocabulary).
**Plans**: TBD (4 plans projected: 93.5-01 bundle module scaffold + 93.5-02 compiler + 93.5-03 coach_chat wiring + 93.5-04 50-fixture eval)

**Budget**: 6d (Expert C estimate ~+400 LOC, 1-2 weeks ; conservative 6d for solo founder timing)
**Auto profile**: **L2** (backend prompt-eng + LLM eval) — Stage 3 eval after compiler in place ; cost+latency telemetry on staging before merge.

### Phase 94: MVP-CITATION-GATE
**Goal**: Post-process parser on narrator output. Narrator output rejected if ANY number or legal claim is emitted without a `{{cite:<key>}}` placeholder (per CONTEXT D-01 — the legacy `[citation:source_id]` wording is superseded). Closes the « ChatGPT clone » fear mechanically — narrator is structurally incapable of un-cited numbers. Hard-cap retries at 1, fall back to templated « je n'ai pas la donnée » on retry failure.
**Depends on**: Phase 91 (extractor + narrator split must exist before citation parser hooks into narrator output stage), Phase 93.5 (bundle compiler emits `citation_allowlist` consumed by gate per D-07)
**Requirements**: GATE-01 number detection regex, GATE-02 citation source registry, GATE-03 retry-or-fallback flow, GATE-04 banned-claim list
**Success Criteria** (what must be TRUE):
  1. New `app/services/coach/citation_parser.py` parses narrator output, detects every CHF amount / percentage / legal article / regulatory constant ; rejects emission if no `{{cite:<key>}}` placeholder (resolving to `profile|reasoning|tool_call_id|adr|spec` source kinds) is adjacent.
  2. Narrator response retry-once on rejection with explicit reprompt « cite ton chiffre ou ne l'émets pas » ; second failure returns templated « je n'ai pas cette donnée pour l'instant » with no number.
  3. 50-fixture eval pack (`tests/fixtures/citation_gate_eval_50.jsonl`) passes ≥95% on Sonnet narrator and ≥90% on Haiku narrator.
  4. Maestro flow `flow_narrator_refuses_uncited_numbers.yaml` PASSES — sends a profile-empty user with chat « combien je gagne ? » and asserts the response does NOT contain a fabricated CHF number.
**Plans**: 3 plans (Wave 0 scaffold → Wave 1 wiring → Wave 2 eval+proposal)
- [x] 94-01-PLAN.md — Wave 0, autonomous — citation_parser.py + citation_registry.py + COACH_CITATION_GATE_ENABLED flag + 6 test files (number-detection, meta-helpers port, registry contract, performance, byte-identity flag-OFF, config) ; eval_narrator.py refactor to re-import meta-helpers (single source of truth, D-03) — **shipped 2026-05-10 (commits 033b8445 / 668df0de / 2a729c3d, 106 tests, 6372/6266 backend baseline, see 94-01-SUMMARY.md)**
- [x] 94-02-PLAN.md — Wave 1, autonomous — fattened gate() body (D-08/D-09/D-10/D-12/D-13 verbatim FR strings) + `_run_narrator_with_gate()` wrapper at coach_chat.py:3264-3373 + bundle integration (D-07) + Sentry breadcrumbs (D-18) + 6 new test files (retry, fallback, banned-claims, bundle-intersect, global-registry-fallback, telemetry)
- [x] 94-03-PLAN.md — Wave 2, NOT autonomous (Julien GO/NO-GO checkpoint) — eval_narrator --gate={on,off} flag + 50-fixture pack (D-14) + Maestro G1 flow (D-16) + Stage 3 live eval (Sonnet ≥95% / Haiku ≥90% per D-15) + 94-03-EVAL-RESULTS.md + 94-03-FLAG-FLIP-PROPOSAL.md (D-21 sunset)

**Budget**: 3d
**Auto profile**: **L2** (backend + LLM eval gate) — Stage 3 eval mandatory before merge.

### Phase 94.1: Wave 4 narrator-prompt fattening — citation registry + {{cite:<key>}} grammar instructions (Phase 94 prod-flip unblocker) (INSERTED) — CLOSED 2026-05-10 AT FAIL

**Goal:** Teach the narrator the `{{cite:<key>}}` grammar + the 18-key registry vocabulary so Stage 3 gate-correct rates lift from Sonnet 6% / Haiku 14% to ≥95% / ≥90%.
**Result:** PARTIALLY LANDED — Sonnet 6% → 20% (+233%), Haiku 14% → 20% (+43%). Signal concentrated in `valid_citation` category (Sonnet 1/20 → 9/20, Haiku 6/20 → 10/20). Thresholds NOT MET. Disposition unchanged : NO-GO + PARTIAL.
**Depends on:** Phase 94 (NO-GO + PARTIAL disposition + CITATION_REGISTRY 18-key baseline).
**Plans:** 1/1 plans complete

Plans:
- [x] 94.1-01-PLAN.md — narrator-prompt fattening Path C (Hybrid) — SUMMARY at `.planning/phases/94.1-wave-4-.../94.1-SUMMARY.md` ; EVAL-DELTA at `.planning/phases/94.1-wave-4-.../94.1-EVAL-DELTA.md`. 12 new tests + 6448 backend pytest + 2 live eval JSONs. Verdict FAIL per plan-defined interpretation rules ; orchestrator owns GO/NO-GO on 94.2.

### Phase 95: MVP-DAG-INVALIDATION
**Goal**: Add `inputs_hash` + `superseded_by` on every projection (LPP, AVS, 3a, marge fiscale). Calculator refuses stale cache when input hash differs from current profile hash. Closes silent stale-projection bug (user updates salary in onboarding ; old LPP projection card shows old number for 3 days).
**Depends on**: Phase 94 (citation gate must reference projection IDs ; staleness propagates upward)
**Requirements**: DAG-01 inputs_hash on every projection, DAG-02 superseded_by chain, DAG-03 staleness=high flag, DAG-04 additive migration (hash nullable for backward compat)
**Success Criteria** (what must be TRUE):
  1. `apps/mobile/lib/services/financial_core/` projection models gain `inputs_hash: String` + `superseded_by: ProjectionId?` fields ; backend `services/backend/app/models/projection.py` mirrors.
  2. Calculator wrappers compute hash on read ; if hash mismatch with current profile hash → return last-known-good with `staleness: high` flag (UI surfaces « valeur peut-être obsolète » badge).
  3. Migration is additive : `inputs_hash` is nullable ; existing profiles compute hash lazily on first read ; zero forced recomputation.
  4. Test: `tests/test_projection_dag_invalidation.py` covers (a) fresh hash → no staleness, (b) profile salary changes → projection hash mismatch → staleness=high, (c) recompute resets hash chain.

> **Phase split note (2026-05-11 — planner-revision iteration 1):** SC#1 + SC#2 are **partial-delivery in Phase 95**. Phase 95 ships the BACKEND half : `ScenarioModel` extended with `inputs_hash` + `superseded_by` columns + `services/backend/app/services/coach/staleness.py` production rule + `ProjectionGroundingPack` Pydantic contract + the pure-Python compute modules (pareto / sensitivity / bootstrap_ci). The **DART half** — `apps/mobile/lib/services/financial_core/` projection-model field additions + calculator-wrapper read-path integration emitting `staleness_iso = "high"` on `GroundingPackEntry` — is **deferred to Phase 96 W2** (consumer wiring + UI badges). SC#4(c) « recompute resets hash chain » test ships in Phase 95 Plan 95-01 Task 5 (`test_recompute_resets_hash_chain`). Pattern : same `phase_complete_with_deferred` precedent as Phase 94 NO-GO + PARTIAL.

**Plans**: 2 plans
- [x] 95-01-PLAN.md — Wave 1, autonomous — Hash chain (rfc8785 + Decimal quantize) + UUID7 (uuid_utils backport for Railway py3.12) + additive alembic migration on `scenarios` (DAG-01..DAG-04) + 50-fixture Python↔Dart parity gate (Path A pure-Dart harness sidesteps Phase 92.7 cascade) + new PII fixture lint
- [x] 95-02-PLAN.md — Wave 2, autonomous (depends on 95-01) — ProjectionGroundingPack Pydantic v2 rewrite + 3-point Pareto scalarisation + ±10% what_ifs + numpy bootstrap CIs (200 iter) + `_substitute_placeholders` D-09 double-lookup with Sentry breadcrumb + coach_chat.py pack= threading + LSFin `--lsfin-annotation` rule in banned_terms_python.py

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
**Plans**: 3 plans
- [x] 96-01-PLAN.md — Wave 1 Flutter UI scaffold (chatTabVisible flag + MintCardActionBar 48dp animated row + MintChatOverlay scaffold + SerializedCardContext Dart mirror + 3 ARB keys × 6 locales + toml dep + 2 example card screens wired) [VERB-01, VERB-04]
- [x] 96-02-PLAN.md — Wave 2 Backend schemas + 3-turn cap (SerializedCardContext + NarrativeSleeve Pydantic v2 + CoachChatRequest/Response additive extensions + turn_cap.py in-memory counter + narrator <source_card> block + Sentry chat_overflow_turn_4) [VERB-02, VERB-03, VERB-05]
- [x] 96-03-PLAN.md — Wave 3 cross-stack close-out (NarrativeSleeve hook digit-free linter ReDoS-safe + Dart+Python metaphor_lookup + metaphors.toml v1 bootstrap + Maestro G1 flow_card_action_intent_bar.yaml + walkback test + G2 Julien sim checkpoint) [VERB-06]

**Budget**: 5d
**Auto profile**: **L2** (cross-stack: Flutter UI + backend chat + flag rollout) — full GSD chain ; Maestro G1 + creator-device G2 + soak metric (7-day) before flag-on in prod.

### Backlog 999.x — calc-first ADR scope-trimmed (await 2nd revue post-TestFlight)

- **999.1: HMM regime-switching Monte Carlo + CVaR + BVG mortality** — Expert 1 quant-actuarial synthesis ; replaces iid-Gaussian MC in `monte_carlo_service.dart:222-225` with 2-regime HMM + BVG 2020 mortality + CVaR output ; 5 SST-flavoured stress scenarios. 4-6 weeks isolated.
- **999.2: Pareto NSGA-II multi-objective optimisation** — Expert 4 ML-arbitrage synthesis ; replace terminal-value scalar with multi-objective optimisation across (revenu_médian, ruin_prob, bequest, tax_drag) via pymoo. 1-2 weeks coupled with GroundingPack but livrable séparément.
- **999.3: `mint-wiring-verifier` full Claude Code dev-time agent** — *Conditional*. Cheap version `mint-wiring-check` skill ships pre-Phase-94 (this week) as the preempt. Build the FULL agent only IF, post Phase 94 CITATION-GATE merged and post 4 weeks of `mint-wiring-check` skill in production, ≥3 incidents of post-merge revert/hotfix PRs are root-caused to "façade-code: file/class created but never imported by any consumer". Trigger metric : grep `git log --grep="revert.*facade\|hotfix.*facade"` over last 4 weeks. Scope if triggered : agent invokable as sub-agent OR pre-commit lefthook gate OR Claude Code skill, doing the 4-level wiring check (N1 file exists → N2 no stub/TODO → N3 import + appel chez ≥1 consumer → N4 sim describe-all contains trace). 1-2 weeks isolated. Architecture audit-compatible per `.planning/audit/codebase-audit-2026-05-10/anthropic-financial-services-agents.md` §142 (dev-time, not runtime).
- **999.4: Phase 92.6 — Backend calc-parity scaffold** — *Conditional on Phase 94 CITATION-GATE proving Backend must compute (e.g., for citation_allowlist generation that requires server-side numbers).* Python port of the 3 locked Dart calculator methods : `AvsCalculator.computeMonthlyRente` (~265 LOC), `LppCalculator.projectToRetirement` (~470 LOC), `RetirementTaxCalculator.capitalWithdrawalTax` projection wrapper (~490 LOC) ≈ 1227 LOC total. Once delivered, `services/backend/tests/fixtures/calc_diff_v1.jsonl` extends from 80–100 fixtures to 200, covering AVS rente + LPP retirement projection axes. Trigger : post-TestFlight OR Phase 94 §3 CalcTrace requires backend-computed numbers. Scope : 4-6d isolated. Source : ADR `2026-05-09-calc-first-llm-illumination.md` N3 + CONTEXT 92.5 D-03.
- **999.5: Phase 94.2 — Narrator-prompt iter 2 (intent-driven key grouping)** — *Conditional on prod-flip path being reactivated.* Phase 94.1 (closed 2026-05-10 at FAIL) lifted Sonnet gate-correct 6% → 20% and Haiku 14% → 20% via the citation-grammar fragment ; thresholds (95% / 90%) NOT MET. Iter 2 primary hypothesis : H1 — replace the flat 18-bullet citation-key list with intent-driven key grouping (project only the keys relevant to the user's classified intent set per `_classify_user_intent` at `coach_chat.py:944-963`), reducing the noise floor that drives model attention drift. Full H1-H5 hypothesis list at `.planning/phases/94.1-wave-4-narrator-prompt-fattening-citation-registry-cite-key-/94.1-EVAL-DELTA.md` §"Root cause hypotheses for 94.2". Parallel diagnostic upgrade : record `first_call_verdict` alongside `gate_verdict` in eval_narrator output (today's scoring records post-retry FALLBACK, which understates the true single-call rate ≈48%/44%). Trigger : reactivated when the 4-week staging soak D-21 path becomes the critical path again OR Phase 96 NarrativeSleeve linter surfaces additional prompt-grammar gaps. Scope : ~2d isolated. Source : `94.1-EVAL-DELTA.md` §"Root cause hypotheses for 94.2" + `94.1-SUMMARY.md`.

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

### Phase 97: MVP-PARFAIT-MAESTRO-FULL-POWER — Maestro-driven on-device ground-truth + reachability + 8-archetype matrix + CI gates

**Goal:** [To be planned]
**Requirements**: TBD
**Depends on:** Phase 96
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 97 to break down)

### Phase 1: MINT production-readiness audit: identify top blockers to first usable beta (Sentry remainders, 18 life events coverage, 8 archetypes, watchdog perf, TestFlight infra, iOS keychain entitlement, i18n hardcoded strings) and output a prioritized roadmap addendum with sub-phases

**Goal:** Audit-meta phase. The audit itself was executed via 6-agent expert panel synthesis 2026-05-20 (PM + architect + QA + business + AI engineer + security). Output is `01-CONTEXT.md` (panel-locked scope/bar/method/sequencing) + `01-RESEARCH.md` (10 deliverables, codebase recipes, baseline counts) + `01-VALIDATION.md` (per-finding-class Nyquist matrix) + 10 sub-phase decomposition (§8). Phase 01 itself ships no code ; each sub-phase 01.1 → 01.10 is its own GSD phase per CONTEXT §12.
**Requirements**: TBD — derived per sub-phase. Audit identifies 4 P0 hot items (P0-1 archetype HARD GATE silent-fallback ; P0-2 banned-term 6-locale extension ; P0-3 DSAR fact_event manifest ; P0-4 forced tool-invocation merge-blocker) + 5 P1 line items.
**Depends on:** Phase 0 (icon shipped via PR #663 ; staging post-icon-merge prerequisite for 01.1).
**Plans:** Audit-meta only — no Plans land at this level. Sub-phases 01.1 → 01.10 each have their own PLAN.md stack.

Sub-phases (per CONTEXT §8) :
- [ ] 01.1 — Walkthrough-first grounding (T-shirt M, user-flow) — **active, see Phase 01.1 below**
- [ ] 01.2 — /gsd-map-codebase refresh (5 mappers) (T-shirt XL, method)
- [ ] 01.3 — L1/L2 boundary integrity audit (T-shirt L, architecture)
- [ ] 01.4 — Coach-runtime audit + trust monitor + replay corpus (T-shirt XL, AI/coach)
- [ ] 01.5 — Archetype HARD GATE fix (T-shirt M, security, P0-1)
- [ ] 01.6 — Semantic banned-term sweep + ARB cleanup (T-shirt M, compliance, P0-2)
- [ ] 01.7 — DSAR fact_event manifest fix (T-shirt S, privacy, P0-3)
- [ ] 01.8 — Maestro assertion-grammar refactor (T-shirt M, QA)
- [ ] 01.9 — `_to-MINT 4` design alignment audit (T-shirt M, UX, P1-4)
- [ ] 01.10 — Maestro sweep × 2 archetypes + adversarial coach probes (T-shirt L, QA)

**Critical path** : 01.1 → (01.5 + 01.6 + 01.7) ∥ → (01.2 + 01.3 + 01.4 + 01.9) ∥ → (01.8 + 01.10) → next milestone planning.

**Canonical refs** :
- `.planning/phases/01-mint-production-readiness-audit-identify-top-blockers-to-fir/01-CONTEXT.md` — panel-locked decisions, scope/bar/method/sequencing, 10 sub-phase decomposition
- `.planning/phases/01-mint-production-readiness-audit-identify-top-blockers-to-fir/01-RESEARCH.md` — 10 deliverables, code recipes, baseline counts, Sentry inventory, Maestro flow templates
- `.planning/phases/01-mint-production-readiness-audit-identify-top-blockers-to-fir/01-VALIDATION.md` — per-finding-class Nyquist matrix, wave 0 gaps per sub-phase
- `.planning/decisions/2026-05-20-audit-01-bar-and-scope.md` — companion ADR
- `.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md` — L1/L2 boundary doctrine ADR

### Phase 1.1: Walkthrough-first grounding — Maestro sweep on staging post-icon-merge + Julien observations
**Goal**: Run the onboarding → first-insight hero flow (marge fiscale 3a annuelle) end-to-end on a booted iPhone 17 Pro sim against Railway staging (post-PR #663 icon merge). Capture observed blockers via Maestro flow + idb ui describe-all + Julien observations. Output a `01.1-OBSERVATIONS.md` that grounds the rest of the audit in reality, NOT abstract grep. This is the **PRE-AUDIT** per CONTEXT §8 row 01.1 — verifies the bar (CONTEXT §1 Q-02 « ≥1 cited number within 3 turns ») is reachable on a real device before the architecture/coach-runtime/i18n sub-phases spend effort on assumed code shapes.
**Requirements**: REQ-AUDIT-01 (hero flow reachable end-to-end on staging post-icon-merge), REQ-AUDIT-08 (Maestro 3-tier assertion grammar — grounded-values / non-crash / exploratory), REQ-AUDIT-10 (Maestro 2-archetype sweep — swiss_native first, swiss_native_couple deferred to 01.10)
**Depends on:** Phase 1 (CONTEXT locked) ; PR #663 (icon menthe) merged + staging auto-deploy succeeded ; sim iPhone 17 Pro bootable ; Maestro CLI available at `~/.maestro/bin/maestro` ; `~/.sentryclirc` authenticated.
**Plans:** 3 plans (W1: 1 pre-conditions, W2: 1 hero-flow design + dry-run, W3: 1 execute + observe + Julien G2)

Plans:
- [ ] 01.1-01-PLAN.md — Pre-condition verification (PR #663 merge + staging /health + sim bootable + Maestro CLI + sentry-cli + pgvector ≥ 100 docs + citation_parser deployed + plafond 3a constants served) → `01.1-PRECONDITIONS.md` with 8 ✓/✗/HALT verdict blocks
- [x] 01.1-02-PLAN.md — Hero-flow Maestro YAML design + dry-run on sim (no live staging) → `tools/simulator/flows/maestro-perfect-set/flow_hero_marge_fiscale_3a.yaml` + `01.1-DRYRUN-TRACE.md`
- [ ] 01.1-03-PLAN.md — Execute hero flow on staging + 11-class finding triage + 10-trigger re-litigation verdict + Julien G2 observation pass (autonomous: false) → `01.1-OBSERVATIONS.md` + `01.1-RELITIGATION-VERDICT.md` + `screenshots/walkthrough/01.1-hero/`

**T-shirt:** M (CONTEXT §8 row 01.1) — single-flow Maestro design + execution + observation write-up. ~1-2 day.

**Canonical refs**:
- `.planning/phases/01-mint-production-readiness-audit-identify-top-blockers-to-fir/01-CONTEXT.md` §1 (bar) + §3 (method) + §8 (row 01.1)
- `.planning/phases/01-mint-production-readiness-audit-identify-top-blockers-to-fir/01-RESEARCH.md` §1 Maestro inventory + §6 hero-flow template + §16 Validation (Maestro flow finding-class)
- `.planning/phases/01.1-walkthrough-first-grounding/01.1-CONTEXT.md` — sub-phase CONTEXT (inherits Phase 01)
- `tools/simulator/flows/maestro-perfect-set/` — existing Maestro flow inventory
- `tools/simulator/walker.sh` — sim driver

### Phase mint-data-spine-plan-vivant-v1: Mint Data Spine + Plan Vivant v1

**Goal:** Create a typed mobile data spine that derives `FinancialSituation`, `BudgetSnapshot`, `PillarPosition`, `ProjectionSnapshot`, `Plan`, and `Trajectory` from the existing `wizard_answers_v2 -> CoachProfile` path, then prove one budget/situation vertical slice with tests and Maestro.
**Requirements**: REQ-DSP-01 canonical typed spine, REQ-DSP-02 budget cashflow snapshot, REQ-DSP-03 Swiss pillar position, REQ-DSP-04 structured coach context, REQ-DSP-05 Maestro persistence proof
**Depends on:** `docs/superpowers/specs/2026-05-23-mint-data-spine-plan-vivant-v1-design.md`; existing `docs/data-flow.md`; existing `apps/mobile/lib/services/budget_living_engine.dart`; existing `apps/mobile/lib/models/budget_snapshot.dart`
**Plans:** 5 plans (W1 data spine, W2 budget/pillars, W3 coach context, W4 chat packet wiring, W5 visible UI + Maestro proof)

Plans:
- [x] mint-data-spine-plan-vivant-v1-01-data-spine-snapshot-PLAN.md — typed `DataSpineSnapshot` + `FinancialSituation` + `PillarPosition` derivation and tests
- [x] mint-data-spine-plan-vivant-v1-02-budget-trajectory-plan-PLAN.md — stabilize budget cashflow, projection summary, plan/trajectory derivation
- [x] mint-data-spine-plan-vivant-v1-03-coach-context-PLAN.md — structured coach context packet generated from the spine, with no LLM-owned facts
- [x] mint-data-spine-plan-vivant-v1-04-ui-maestro-proof-PLAN.md — wire `CoachContextPacket` through mobile chat payloads, `/coach/chat`, `/rag/query`, backend sanitizers, and RAG prompt grounding
- [ ] mint-data-spine-plan-vivant-v1-05-visible-maestro-proof-PLAN.md — add a visible packet-backed coach explanation/card and Maestro proof flow for persistence/relaunch/chat explanation

---
*Last updated: 2026-05-21 — Phase 01.1 walkthrough-first-grounding PLANNED (3 plans, W1→W2→W3, Wave 3 autonomous:false with Julien G2 checkpoint ; REQ-AUDIT-01/08/10 locked). Previous: 2026-05-21 — Phase 01 audit-meta opened with panel-synthesized CONTEXT/RESEARCH/VALIDATION ; Phase 01.1 inserted as first executable sub-phase per CONTEXT §8 + §12 directive.*
