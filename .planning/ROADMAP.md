# Roadmap: MINT

## Milestones

- ✅ **v1.0 MVP** — Phases 1-8 (shipped 2026-03-20)
- ✅ **v2.0 Systeme Vivant** — Phases 1-6 (shipped 2026-04-07)
- ✅ **v2.1 Stabilisation** — Phase 7 (shipped 2026-04-07)
- ✅ **v2.4 Fondation** — Phases 9-12 (shipped 2026-04-12)
- ✅ **v2.5 Transformation** — Phases 13-18 (shipped 2026-04-13)
- ✅ **v2.6 Le Coach Qui Marche** — Phases 19-26 (shipped 2026-04-13)
- 🟡 **v2.7 Coach Stabilisation + Document Digestion** — Phases 27-30 (code-complete, awaiting device gate)
- 🔵 **v2.8 L'Oracle & La Boucle** — Phases 30.5, 30.6, 30.7, 31-36 (defining)
- 🌱 **v2.9 Chat Vivant** (planted 2026-04-19) — "Le chat ne raconte plus, il montre." 3 niveaux de projection (inline insight / scene interactive / canvas plein écran) à la Claude Artifacts. Source : `.planning/handoffs/chat-vivant-2026-04-19/` (8 docs + 6 JSX + captures HTML). Estimation P50 = 3 semaines calendar solo (refactor `CoachOrchestrator` Stream + i18n 6 langues + creator-device gate). 3 frictions à trancher avant exécution : (1) scenes inline vs écrans Explorer existants → single source of truth ? (2) `Future<CoachResponse>` → `Stream<ChatMessage>` refactor touche 3 code paths orchestrator, (3) i18n ARB 6 langues ~180 entries non comptées. À réveiller après Phase 31 shippée.

<details>
<summary>Previous milestones (v1.0 → v2.7) — see MILESTONES.md + collapsed v2.5-v2.7 detail below</summary>

Full phase detail for v2.5 (Phases 13-18), v2.6 (Phases 19-26), v2.7 (Phases 27-30) preserved in git history of this file (pre-2026-04-19 revisions) + `.planning/MILESTONES.md`.

</details>

---

## v2.8 L'Oracle & La Boucle — Overview

**Goal:** Refonder le workflow de développement pour sortir de la façade-sans-câblage et du context-poisoning agent. À la fin de v2.8 : toute route user-visible marche end-to-end et on le prouve mécaniquement ; on sait en <60s ce qui casse (oracle = instrumentation + session replay + route-health board) ; aucun agent ne peut ignorer son contexte (guardrails pre-commit) ; Julien ouvre MINT 20 min sans taper un mur.

**Règle inversée non-négociable:** 0 feature nouvelle. Ce qui ne marche pas se kill (via flag) ou se répare. Compression = discipline transversale (pas une phase dédiée).

**Kill-policy:** [decisions/ADR-20260419-v2.8-kill-policy.md](../decisions/ADR-20260419-v2.8-kill-policy.md) — si un REQ table-stake n'est pas livré, la feature est killed via flag. Pas de v2.9 stabilisation.

**Total requirements:** 48 REQ-IDs across 8 catégories, mapped 1:1 to 8 phases.

**Phase numbering — intentional decimal inserts:**
- v2.7 terminates at Phase 30.
- Phases **30.5** (Context Sanity Core), **30.6** (Context Sanity Advanced), and **30.7** (Tools Déterministes) are decimal **inserts BEFORE standard Phase 31**, introduced post-panel-debate (4 experts: Claude Code architect / peer tools / academic / devil's advocate). Note: 30.5 was split into 30.5 + 30.6 on 2026-04-19 per expert panel Option F consensus (kill-policy reality + W3+W4 meta-recursive burn-in).
- Phases 31-36 then follow standard integer numbering.

### Build order (dependency graph)

```
  30.5 Context Sanity Core (3j, non-empruntable, foundation)
         │
         │ baseline J0 captured
         ▼
  30.6 Context Sanity Advanced (2-3j + 72h burn-in)
         │
         │ CTX-05 spike gate (go/no-go, kill-policy Modeste 1)
         ▼
  30.7 Tools Déterministes (2-3j)
         │
         ▼
  ┌──────┴──────┐
  │             │
  31            34           (parallel; lefthook skeleton from 30.5)
  Instrumenter  Guardrails   (each 1.5 sem, can borrow from the other)
  │             │
  │             │ GUARD-02 bare-catch lint ACTIVE
  │             │     (prereq for FIX-05 in Phase 36)
  │             │
  └──────┬──────┘
         │
  ┌──────┴──────┐
  │             │
  32            33           (parallel; each 1 sem, can borrow from the other)
  Cartographier Kill-switches
  │             │
  │             │ FLAG-03 convergence 2 flag systems
  │             │     (prereq for all Phase 36 kill-switches)
  └──────┬──────┘
         │
  35 Boucle Daily (1 sem)
         │
         ▼
  36 Finissage E2E (2-3 sem MINIMUM, non-empruntable)
```

### Budget summary

| Phase | Name | Budget | Borrowable | REQs | Kill gate | Auto profile |
|-------|------|--------|------------|------|-----------|--------------|
| 30.5 | Context Sanity Core | 3j | **non-empruntable** | 2 | baseline J0 gate | **L1** (+0.25j verifier) |
| 30.6 | Context Sanity Advanced | 2-3j + 72h burn-in | **non-empruntable** | 3 | CTX-05 spike go/no-go (kill-policy Modeste 1) | **L1** (+0.25j verifier) |
| 30.7 | Tools Déterministes | 2-3j (~0.5 sem) | — | 4 | — | **L1** (+0.25j verifier) |
| 31 | Instrumenter | 1.5 sem | from 34 only | 7 | OBS-06 PII audit artefact | **L3** (+1.5j walker+ui-review, walker.sh ship J0) |
| 34 | Guardrails | 1.5 sem | from 31 only | 8 | — | **L1** (+0.25j verifier) |
| 32 | Cartographier | 1 sem | from 33 only | 5 | — | **L2** (+0.75j secure+inter-layer) |
| 33 | Kill-switches | 1 sem | from 32 only | 5 | — | **L2 + L3 partial** (+1j, UI sub-tasks Level 3) |
| 35 | Boucle Daily | 1 sem | — | 5 | — | **L1** (+0.25j verifier, gsd-debug simctl extension optional) |
| **36** | **Finissage E2E** | **2-3 sem MINIMUM** | **never — non-empruntable** | **9** | 4 P0 kill flags provisioned | **L3 mandatory** (creator-device gate déjà budgété) |

**Total estimate:** 8-10 weeks solo-dev with parallelisation (31 ∥ 34, 32 ∥ 33). **+5.25j overhead** par autonomous-profile-tiered ADR (high end fourchette).

**Auto profile reference** : [`decisions/ADR-20260419-autonomous-profile-tiered.md`](../decisions/ADR-20260419-autonomous-profile-tiered.md)
- **L1** = `/gsd-execute-phase` + `gsd-verifier` 7-pass post-execute (audit-as-second-agent)
- **L2** = L1 + `gsd-secure-phase` + curl smoke staging + inter-layer contracts check
- **L3** = L2 + `tools/simulator/walker.sh` simctl gate par task UI + `gsd-ui-review` + creator-device gate Julien manuel non-skippable

---

### v2.8 Phases overview

- [x] **Phase 30.5: Context Sanity** — Fix MEMORY.md truncation + drift dashboard + CLAUDE.md restructure + UserPromptSubmit hook + spike validation go/no-go (completed 2026-04-19)
- [x] **Phase 30.6: Context Sanity (Advanced)** — CLAUDE.md refonte <150L + UserPromptSubmit hook + CTX-05 spike go/no-go (kill-policy active) (completed 2026-04-19)
- [ ] **Phase 30.7: Tools Déterministes** — MCP tools on-demand (swiss_constants / banned_terms / arb_parity) — économise ~16k tokens/session
- [x] **Phase 31: Instrumenter** — Sentry Replay Flutter 9.14.0 + global error boundary 3-prongs + trace_id round-trip mobile↔backend (completed 2026-04-19)
- [ ] **Phase 32: Cartographier** — Route registry-as-code **147 routes** (reconciled 2026-04-20) + CLI `./tools/mint-routes` live health + Flutter UI `/admin/routes` schema viewer + parity lint + analytics **43 legacy redirects** (reconciled)
- [ ] **Phase 33: Kill-switches** — Middleware GoRouter `requireFlag()` + FeatureFlags→ChangeNotifier + convergence 2 flag systems + admin UI
- [ ] **Phase 34: Agent Guardrails mécaniques** — lefthook 2.1.5 complet + 5 lints (bare-catch, hardcoded-FR, accent, ARB parity, proof-of-read) + CI thinning
- [ ] **Phase 35: Boucle Daily** — `mint-dogfood.sh` (simctl iPhone 17 Pro, 8-step scenario, ~10 min) + auto-PR threshold + pull Sentry events
- [ ] **Phase 36: Finissage E2E** — 4 P0 fixes (UUID / anonymous / save_fact / Coach tab) + 388 catches → 0 + MintShell ARB parity audit + accents 100%

### Phase Details

### Phase 30.5: Context Sanity (Core)
**Goal**: Foundation substrate phase 1/2 — MEMORY.md retrievable + agent drift measured (baseline J0). Prerequisites 30.6 (advanced: CLAUDE.md refonte, hook, spike).
**Depends on**: Nothing (foundation phase v2.8, runs first)
**Requirements**: CTX-01, CTX-02
**Success Criteria** (what must be TRUE):
  1. `MEMORY.md` core INDEX est <100 lignes et 0 "Only part was loaded" warning apparaît sur une nouvelle session ; les handoffs récents sont retrievables via `memory/topics/*.md` on-demand.
  2. Dashboard CLI `tools/agent-drift/dashboard.py` affiche 4 métriques live (drift rate, context hit rate, token cost per session, time-to-first-correct-output) et une baseline J0 est capturée avant toute refonte CLAUDE.md (pré-condition stricte de la Phase 30.6).
**Plans**: 3 plans (Wave 0 scaffolding + 2 CTX Core plans, hard-sequenced per D-12 baseline-before-refonte)
- [x] 30.5-00-PLAN.md — Wave 0 test scaffolding + A4 mtime spike + A7 claude --headless spike (shared scaffolding for both 30.5 Core and 30.6 Advanced, 20 files, 0 production code)
- [x] 30.5-01-PLAN.md — CTX-02: drift.db schema + CLI dashboard + 4 ingesters + early-ship lints + baseline J0 capture (pre-refonte, D-12 non-negotiable)
- [x] 30.5-02-PLAN.md — CTX-01: MEMORY.md split + topics/ flat + 30j GC (mtime-based, D-03, hardcoded whitelist feedback_*/project_*/user_*) + lefthook skeleton MEMORY gate only (D-04, `parallel: false` until Phase 34)

**Budget**: 3j (was 5j, split 2026-04-19 — CTX-03/04/05 moved to 30.6) — non-empruntable (foundation)
**Auto profile**: **L1** (meta/dev-tooling) — `/gsd-execute-phase` + `gsd-verifier` 7-pass post-execute (audit-as-second-agent obligatoire). Pas de simulator (rien à tester sur device). Voir [`decisions/ADR-20260419-autonomous-profile-tiered.md`](../decisions/ADR-20260419-autonomous-profile-tiered.md).

### Phase 30.6: Context Sanity (Advanced)
**Goal**: Foundation substrate phase 2/2 — CLAUDE.md restructuré + UserPromptSubmit hook + spike validation go/no-go before Phase 31. Kill-policy D-01 applies here (CTX-05 fail 2× → revert 30.6 entirely, 30.5 preserved).
**Depends on**: 30.5 Core complete + 72h burn-in observation window on 30.5 artefacts
**Requirements**: CTX-03, CTX-04, CTX-05
**Success Criteria** (what must be TRUE):
  1. CLAUDE.md core <150 lignes avec 5 critical rules bracketing TOP+BOTTOM + 10 NEVERs convertis en triplets `{bad → good → why}`.
  2. Hook `UserPromptSubmit` `mint-context-injector.js` injecte 200-400 tokens contextuels sur 5 patterns MINT avec fail-open timeout 500ms.
  3. Un spike agent sur un chunk Phase 31 (bump `sentry_flutter` 8→9) livre du code sans régression détectée dans dashboard 30.5 CTX-02, OU 2 itérations échouent → kill-policy 30.6 déclenché (rollback CTX-03 + CTX-04).
**Plans**: 3 plans
- [x] 30.6-00-PLAN.md — CTX-03: CLAUDE.md restructure <150L + 5-rule TOP+BOTTOM bracketing (D-06) + 10 triplets bad→good→why (D-07) + 3 AGENTS files (D-05) + redundancy audit (D-08) — REVERT-SAFE squash
- [x] 30.6-01-PLAN.md — CTX-04: UserPromptSubmit hook mint-context-injector.js + 5 context snippets + settings.json registration + env override MINT_NO_CONTEXT_INJECT=1 (D-13..17) + 500ms fail-open timeout — REVERT-SAFE squash
- [x] 30.6-02-PLAN.md — CTX-05: spike validation on fresh-context branch + 5-dim grid review + dashboard regression + D-01 kill-policy Modeste 1 decision gate (bump sentry_flutter 8→9.14.0 + SentryWidget + maskAll*, A1 PII Replay mitigation HIGH severity)

**Budget**: 2-3j + 72h burn-in (post-30.5 observation window) — kill-policy active
**Auto profile**: **L1** (meta/dev-tooling) — `/gsd-execute-phase` + `gsd-verifier` 7-pass post-execute. Pas de simulator. Voir [`decisions/ADR-20260419-autonomous-profile-tiered.md`](../decisions/ADR-20260419-autonomous-profile-tiered.md).

### Phase 30.7: Tools Déterministes
> **Renumbered 2026-04-19**: Was Phase 30.6 before the Context Sanity split. Now Phase 30.7 to accommodate "Context Sanity (Advanced)" as the true 30.6. REQUIREMENTS.md TOOL-01..04 moved accordingly.
**Goal**: Transformer les constantes et lints permanents de CLAUDE.md en MCP tools on-demand. Les agents invoquent `get_swiss_constants()` / `check_banned_terms()` / `validate_arb_parity()` quand pertinent au lieu de traîner 800+ tokens de règles en contexte permanent.
**Depends on**: Phase 30.6 (CLAUDE.md restructure complete before removing sections to migrate to tools)
**Requirements**: TOOL-01, TOOL-02, TOOL-03, TOOL-04
**Success Criteria** (what must be TRUE):
  1. MCP tool `get_swiss_constants(category)` retourne les constantes 2025/2026 structurées pour 5 catégories (pillar3a / lpp / avs / mortgage / tax), sourcées depuis `services/backend/app/constants/` (single source of truth déjà existant).
  2. MCP tool `check_banned_terms(text)` wrap `ComplianceGuard` backend existant et retourne `{banned_found: [...], suggestions: [...]}` on-demand.
  3. MCP tools `validate_arb_parity()` + `check_accent_patterns(text)` wrappent les lints `tools/checks/arb_parity.py` + `tools/checks/accent_lint_fr.py` de Phase 34 — les agents les appellent au lieu de charger les listes patterns en mémoire.
  4. `CLAUDE.md` core tokens -30% (suppression §5 BUSINESS RULES constantes + §6 COMPLIANCE banned terms list) ; les tools sont invoqués ≥1×/session sur tâches pertinentes (mesuré via dashboard Phase 30.5).
**Plans**: TBD
**Budget**: 2-3j (~0.5 sem)
**Auto profile**: **L1** (meta/dev-tooling) — `/gsd-execute-phase` + `gsd-verifier` 7-pass post-execute. MCP tools backend, 0 UI à tester sur simulateur. Voir [`decisions/ADR-20260419-autonomous-profile-tiered.md`](../decisions/ADR-20260419-autonomous-profile-tiered.md).

### Phase 31: Instrumenter
**Goal**: Tout ce qui casse dans l'app arrive dans Sentry en <60s avec assez de contexte pour diagnostiquer sans ouvrir l'IDE — session replay mobile, global error boundary 3-prongs, trace_id round-trip mobile↔backend, observer GoRouter, breadcrumbs custom sur les surfaces critiques (ComplianceGuard / save_fact / FeatureFlags).
**Depends on**: Phase 30.6 (CTX-05 spike gate must succeed), Phase 30.7 (tools disponibles aux agents qui coderont cette phase)
**Requirements**: OBS-01, OBS-02, OBS-03, OBS-04, OBS-05, OBS-06, OBS-07
**Success Criteria** (what must be TRUE):
  1. Tout 500 backend apparaît dans Sentry en <60s avec `trace_id` + `sentry_event_id` dans la JSON response + header `X-Trace-Id` sortie, et le mobile peut afficher "ref #abc123" cliquable.
  2. Une erreur déclenchée dans n'importe lequel des 3 chemins (build/layout, async platform, isolate) est capturée par l'error boundary 3-prongs — 0 bare catch n'échappe plus à la capture Sentry (révélation pré-Phase 36).
  3. Session Replay Flutter 9.14.0 actif avec `maskAllText=true` + `maskAllImages=true` + `sessionSampleRate=0.05` + `onErrorSampleRate=1.0` ; un click sur un event Sentry mobile ouvre le replay lié au trace_id et le replay masque 100% des écrans sensibles (CoachChat, DocumentScan, ExtractionReviewSheet, Onboarding, Budget).
  4. Un appel mobile→backend propage `sentry-trace` + `baggage` headers sur `http: ^1.2.0` existant (pas migration Dio) et le Sentry UI affiche le cross-project link automatiquement.
  5. Artefact `.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md` committed listant tous les screens sensibles auditoés sur simulateur AVANT flip de `sessionSampleRate>0` en production (gate nLPD non-négociable).
  6. Artefact `.planning/observability-budget.md` documente Sentry tier/pricing fresh, quota replay, events/mois target ~5k users, staging vs prod DSN séparés.
**Plans**: 5 plans (Wave 0 scaffolding + Wave 1 mobile + Wave 2 backend + Wave 3 PII audit + Wave 4 ops budget)
- [x] 31-00-PLAN.md — Wave 0: 17 scaffolding artefacts + sentry-cli install + walker.sh J0 + OBS-01 audit on CTX-05 output
- [x] 31-01-PLAN.md — Wave 1 mobile: OBS-02 error_boundary 3-prongs + OBS-04 sentry-trace/baggage propagation + OBS-05 SentryNavigatorObserver + MintBreadcrumbs (ComplianceGuard, save_fact, FeatureFlags) + D-01 sample rates
- [x] 31-02-PLAN.md — Wave 2 backend: OBS-03 global_exception_handler extension (trace_id + sentry_event_id + X-Trace-Id) + sentry-sdk[fastapi] 2.53.0 pin + staging real-HTTP trace round-trip test
- [x] 31-03-PLAN.md — Wave 3 PII audit: OBS-06 SENTRY_REPLAY_REDACTION_AUDIT.md kill-gate + CRITICAL_JOURNEYS.md + MintCustomPaintMask wrapper + creator-device gate Julien
- [x] 31-04-PLAN.md — Wave 4 ops budget: OBS-07 observability-budget.md + SENTRY_PRICING_2026_04 fresh fetch + sentry_quota_smoke.sh
**Budget**: 1.5 sem (peut emprunter de 34 seulement) ; **+0.5j J0 livrable `tools/simulator/walker.sh`** (subset minimal de Phase 35 dogfood, primitive shell réutilisable par 31/32/33/34/36)
**Auto profile**: **L3** (frontend/UI-touching) — Sentry Replay observable in app, error boundary triggers visibles. `/gsd-execute-phase` + walker.sh simctl gate par task UI + `gsd-verifier` 7-pass + `gsd-ui-review` + `gsd-secure-phase` (PII redaction audit OBS-06) + creator-device gate Julien manuel non-skippable. Voir [`decisions/ADR-20260419-autonomous-profile-tiered.md`](../decisions/ADR-20260419-autonomous-profile-tiered.md).

### Phase 32: Cartographier
**Goal**: Avoir une source de vérité machine-lisible pour les **147 routes** mobiles (reconciled 2026-04-20, ROADMAP estimate was 148) — chaque route a des métadonnées (owner, category, requiresAuth, killFlag). Livré en **dual affordance** : CLI `./tools/mint-routes` pour live health (Sentry × FeatureFlags × transaction.name queries) + Flutter UI `/admin/routes` comme schema viewer (registry + FeatureFlags local state, **PAS de health data côté UI** — iOS sandbox empêche cross-filesystem read du snapshot CLI, design simplifié v4 pour éviter la dépendance). Lint CI empêche les drifts code↔registry. Les **43 redirects legacy** (reconciled 2026-04-20, ROADMAP estimate was 23) sont instrumentés pour validation 30-day avant sunset v2.9.
**Depends on**: Phase 31 (Sentry Issues API + SentryNavigatorObserver auto-set `transaction.name` pour query per-route, breadcrumb_helper pour D-05 analytics). **Phase 34 indépendant** (Phase 32 ship parity lint script standalone + CI job ; Phase 34 wire lefthook hook).
**Requirements**: MAP-01, MAP-02a (CLI), MAP-02b (Flutter UI schema viewer), MAP-03, MAP-04, MAP-05
**Success Criteria** (what must be TRUE):
  1. `lib/routes/route_metadata.dart` expose `kRouteRegistry: Map<String, RouteMeta>` avec **147 entrées** (path, category ∈ {destination, flow, tool, alias}, owner ∈ enum 15 valeurs, requiresAuth, killFlag optional, description optional dev-only, sentryTag optional) — single source of truth.
  2. CLI `./tools/mint-routes {health|redirects|reconcile}` (Python argparse stdlib) lit `SENTRY_AUTH_TOKEN` via macOS Keychain (scope `project:read` + `event:read` only per nLPD D-09), query Sentry via `transaction:<path>` (batch OR-query validé J0), supporte `--json` (Phase 35 dogfood dep), `--no-color`, `MINT_ROUTES_DRY_RUN=1`, exit codes sysexits.h, redaction PII layer. Unit tests via pytest + DRY_RUN fixture.
  3. Flutter UI `/admin/routes` chargeable seulement si compile-time `--dart-define=ENABLE_ADMIN=1` ET runtime `FeatureFlags.isAdmin` local (PAS de backend endpoint — v4 kill du `/admin/me` proposé) — tree-shaken en prod IPA (verifié via `strings` sur binary = 0 occurrences de `kRouteRegistry`).
  4. Flutter UI affiche 147 routes groupées par owner (15 buckets collapsible), colonnes `path | category | owner | requiresAuth | killFlag | FeatureFlags enabled (local) | description`. **PAS de Sentry health data, PAS de snapshot JSON read.** Live health = CLI exclusif.
  5. CI fail si `tools/checks/route_registry_parity.py` détecte un `GoRoute|ScopedGoRoute(path:)` dans `app.dart` absent de `kRouteRegistry` (ou vice-versa). Ship avec `KNOWN-MISSES.md` documentant patterns regex-unparsables (multi-line, ternary, dynamic).
  6. Les **43 redirects legacy** ont un analytics hit-counter actif via Sentry breadcrumb `mint.routing.legacy_redirect.hit` (PII redacted, paths only) — CLI `./tools/mint-routes redirects` affiche compteur 30d par legacy path. Instrumentation seulement — PAS suppression v2.8, sunset DEFER v2.9+ après 30-day zero-traffic validation.
**Plans**: 6 plans (Wave 0 reconciliation + Wave 1 Dart registry + Wave 2 CLI + Wave 3 Admin UI + Wave 4 parity lint + Wave 4 CI/docs/J0 validation)
- [x] 32-00-reconcile-PLAN.md — Wave 0: empirical 147/43 grep + KNOWN-MISSES.md extraction + 11 test/fixture scaffolds
- [x] 32-01-registry-PLAN.md — Wave 1: RouteMeta + RouteCategory + RouteOwner + kRouteRegistry 147 entries (MAP-01)
- [ ] 32-02-cli-PLAN.md — Wave 2: ./tools/mint-routes CLI + Keychain + redaction + schema publication (MAP-02a + MAP-03)
- [ ] 32-03-admin-ui-PLAN.md — Wave 3: AdminGate + AdminShell + RoutesRegistryScreen + adminRoutesViewed + legacyRedirectHit x43 (MAP-02b + MAP-05)
- [ ] 32-04-parity-lint-PLAN.md — Wave 4: route_registry_parity.py + lefthook wrapper + fixtures + pytest (MAP-04)
- [ ] 32-05-ci-docs-validation-PLAN.md — Wave 4: 4 CI jobs + SETUP-MINT-ROUTES.md + walker.sh admin-routes + 6 J0 gates
**Budget**: 5.5j (~1 sem), peut emprunter de 33 seulement. v4 simplifications (Flutter UI pure schema viewer, no backend endpoint) tiennent le budget malgré ajout nLPD D-09 + VALIDATION D-11 + CI D-12.
**Auto profile**: **L2** (backend/integration) — `/gsd-execute-phase` + `gsd-verifier` 7-pass + `gsd-secure-phase` + curl smoke staging Railway + inter-layer contracts check (route registry mobile↔backend OpenAPI parity). Dashboard `/admin/routes` UI sub-task = bascule **L3 partiel** (walker.sh simctl gate sur ce livrable seul). Voir [`decisions/ADR-20260419-autonomous-profile-tiered.md`](../decisions/ADR-20260419-autonomous-profile-tiered.md).

### Phase 33: Kill-switches
**Goal**: Tout path user-visible peut être tué à chaud depuis `/admin/flags` en 1 clic sans redeploy — middleware GoRouter `requireFlag()` sur le redirect callback existant, FeatureFlags devient `ChangeNotifier` avec `refreshListenable` (hot-reload live), backend converge sur 1 seul système de flags (Redis via `FlagsService.set_global()` surface via endpoint existant), pattern flag-group pour éviter le flag rot.
**Depends on**: Phase 31 (breadcrumbs FeatureFlags.refresh pour traçabilité), Phase 32 (RouteMeta.killFlag field est le contrat), Phase 34 (lefthook en place pour protéger le refactor)
**Requirements**: FLAG-01, FLAG-02, FLAG-03, FLAG-04, FLAG-05
**Success Criteria** (what must be TRUE):
  1. Une tentative de navigation vers une route dont le killFlag est off redirige automatiquement vers `/flag-disabled?path=X&flag=Y` — testé sur au moins 3 routes (un Explorer hub, Coach, Scan).
  2. Julien flip un flag depuis `/admin/flags` 1-clic et les utilisateurs actuels sont déroutés en <2s sans restart (FeatureFlags `ChangeNotifier` + `refreshListenable` hot-reload).
  3. Backend route flags vivent dans Redis via `FlagsService.set_global()` et sont surfaced via `/config/feature-flags` existant (0 nouveau 3e système — convergence des 2 systèmes existants).
  4. 11 flags-groupes déployés (`enableExplorerRetraite/Famille/Travail/Logement/Fiscalite/Patrimoine/Sante` + `enableCoachChat` + `enableScan` + `enableBudget` + `enableAnonymousFlow`) couvrant **147 routes** (reconciled 2026-04-20) sans flag-per-route.
  5. Les 4 kill-switches P0 de Phase 36 (`enableProfileLoad` / `enableAnonymousFlow` / `enableSaveFactSync` / `enableCoachTab`) sont provisioned et testés OFF→ON→OFF AVANT que Phase 36 commence (gate non-négociable per kill-policy ADR).
**Plans**: TBD
**Budget**: 1 sem (peut emprunter de 32 seulement)
**Auto profile**: **L2 + L3 partiel** — backend Redis convergence + middleware GoRouter (L2 : `gsd-secure-phase` + curl smoke), UI sub-tasks `/admin/flags` + redirect `/flag-disabled?path=X&flag=Y` + ChangeNotifier hot-reload (L3 : walker.sh simctl gate + `gsd-ui-review` + creator-device gate Julien sur 3 routes test). Voir [`decisions/ADR-20260419-autonomous-profile-tiered.md`](../decisions/ADR-20260419-autonomous-profile-tiered.md).

### Phase 34: Agent Guardrails mécaniques
**Goal**: Aucun commit (humain ou agent) ne peut introduire une régression accent / hardcoded-FR / bare-catch / ARB drift — lefthook 2.1.5 pre-commit parallel <5s, 5 lints mécaniques actifs, `--no-verify` banni remplacé par `LEFTHOOK_BYPASS=1` grep-able, CI thinnée (gates rapides migrent vers lefthook, CI garde les heavies).
**Depends on**: Phase 30.5 (skeleton lefthook hook MEMORY.md déjà en place) — sinon parallel avec Phase 31
**Requirements**: GUARD-01, GUARD-02, GUARD-03, GUARD-04, GUARD-05, GUARD-06, GUARD-07, GUARD-08
**Success Criteria** (what must be TRUE):
  1. `lefthook install` post-clone + `lefthook.yml` pre-commit parallel complet runs <5s absolu sur M-series Mac sur un diff typique (5 Dart + 3 Python staged).
  2. Un `} catch (e) {}` Dart ou `except Exception:` Python sans log/rethrow introduit dans un fichier non-test FAIL le hook (exceptions `test/` et `async *` streams documentées) — GUARD-02 est ACTIVE avant que FIX-05 de Phase 36 commence (sinon moving target pendant la migration 388 catches).
  3. Une string FR hardcodée dans un widget Dart hors `lib/l10n/` FAIL le hook ; un accent manquant (creer, decouvrir, eclairage, securite, etc.) dans `.dart` / `.py` / `app_fr.arb` FAIL le hook ; un drift de keyset entre les 6 ARB (fr/en/de/es/it/pt) FAIL le hook.
  4. Un commit avec `LEFTHOOK_BYPASS=1` est traçable (grep-able dans shell history) ; CI post-merge re-run lefthook sur PR range et alerte si >3 bypass/semaine.
  5. Les 10 grep-style gates existants `tools/checks/*.py` sont migrés vers lefthook-first ; CI ne garde que les heavies (full test suites, readability, WCAG, PII, contracts, migrations) — CI time réduit d'environ 2 min.
**Plans**: TBD
**Budget**: 1.5 sem (peut emprunter de 31 seulement, parallèle possible avec 31)
**Auto profile**: **L1** (meta/dev-tooling) — `/gsd-execute-phase` + `gsd-verifier` 7-pass post-execute. lefthook + lints, 0 UI à tester sur simulateur. Voir [`decisions/ADR-20260419-autonomous-profile-tiered.md`](../decisions/ADR-20260419-autonomous-profile-tiered.md).

### Phase 35: Boucle Daily
**Goal**: Chaque matin, un script bash 10 min reproduit le scenario utilisateur type sur iPhone 17 Pro simulé, screenshot chaque étape, pull les événements Sentry de la dernière fenêtre, génère un report markdown, et ouvre automatiquement une PR si au moins 1 P0 ou 3 P1 sont détectés — signal-over-noise.
**Depends on**: Phase 31 (Sentry events + replay), Phase 32 (route health pour contextualiser), Phase 33 (kill-switches pour rollback rapide sur findings), Phase 34 (lefthook protège les commits dogfood auto)
**Requirements**: LOOP-01, LOOP-02, LOOP-03, LOOP-04, LOOP-05
**Success Criteria** (what must be TRUE):
  1. `tools/dogfood/mint-dogfood.sh` exécute un 8-step scenario non-attendu (landing → signup → intent → premier-éclairage → scan → coach-reply → budget → settings) sur iPhone 17 Pro via `xcrun simctl` (primary) + `idb` (accessibility tap fallback) en ~10 min.
  2. `tools/dogfood/render_report.py` génère `.planning/dogfood/YYYY-MM-DD/README.md` avec screenshots inline, Sentry events groupés par severity, et (optionnel) diff vs J-1.
  3. Sentry events des 15 dernières minutes sont pull via `sentry-cli api` pour les 2 projets (mobile + backend) avec auth `SENTRY_AUTH_TOKEN` via macOS Keychain.
  4. `gh pr create` ouvre automatiquement une PR `dogfood/YYYY-MM-DD` → `dev` UNIQUEMENT si le report contient ≥1 P0 ou ≥3 P1 (pas de spam daily, signal-over-noise).
  5. `.planning/dogfood/` fait rotation keep-30-days ; les runs >60j partent en Git LFS via `.gitattributes` (volume ~200MB/mois au rythme 10 min/jour × 8 screenshots).
**Plans**: TBD
**Budget**: 1 sem
**Auto profile**: **L1** (meta/dev-tooling) — `/gsd-execute-phase` + `gsd-verifier` 7-pass post-execute. Dogfood scripts dev-only, hérite de `tools/simulator/walker.sh` shipped Phase 31 J0. **Optionnel** (si budget tolère, sinon defer v2.9) : extension `gsd-debug` skill avec simctl tool wrapping pour permettre fix→simctl→assert→fix loop autonome (max 5 iterations, escalate Julien sinon). Voir [`decisions/ADR-20260419-autonomous-profile-tiered.md`](../decisions/ADR-20260419-autonomous-profile-tiered.md).

### Phase 36: Finissage E2E
**Goal**: Tous les P0 catalogués à l'entrée v2.8 sont soit fixés soit killed via flag — UUID profile crash / anonymous flow mort / save_fact désynchronisé / Coach tab routing stale. 388 bare catches convergent à 0 (backend 56 d'abord, mobile 332 batched 20/PR). MintShell ARB parity audit 6 langs. Accents 100%. Chaque fix ship avec un regression test qui aurait failé pré-fix. Julien ouvre MINT 20 min sans taper un mur.
**Depends on**: Phase 33 (4 kill-switches P0 provisioned per kill-policy ADR), Phase 34 (GUARD-02 bare-catch ban ACTIVE avant FIX-05 sinon moving target), Phase 35 (dogfood boucle daily valide les fixes en continu)
**Requirements**: FIX-01, FIX-02, FIX-03, FIX-04, FIX-05, FIX-06, FIX-07, FIX-08, FIX-09
**Success Criteria** (what must be TRUE):
  1. Julien ouvre MINT depuis `simctl` cold-start et teste 20 min d'affilée le scenario canonical (landing → intent anonyme → signup → coach 3 messages → scan document → budget → explore 5 hubs) sans taper un mur : 0 RSoD, 0 écran vide, 0 crash, 0 "Analyse indisponible", 0 redirect piégé.
  2. Les 4 P0 blocking bugs sont soit FIXÉS avec un regression test qui aurait failé pré-fix (FIX-01 UUID backend / FIX-02 anonymous one-line CTA / FIX-03 save_fact sync via `responseMeta.profileInvalidated` / FIX-04 Coach tab routing), soit KILLED via leur kill-switch flag respectif (`enableProfileLoad` / `enableAnonymousFlow` / `enableSaveFactSync` / `enableCoachTab`) avec décision commitée (per kill-policy ADR).
  3. `tools/checks/no_bare_catch.py` (GUARD-02) gate green sur tout le codebase : les 388 bare catches (332 mobile + 56 backend) sont tous classifiés (P0 core flows / P1 UX best-effort / P2 test mocks exemptés) et convergent à 0 sur P0+P1, migration par batch 20/PR.
  4. Les labels MintShell (`l.tabAujourdhui / l.tabMonArgent / l.tabCoach / l.tabExplorer`) sont présents dans les 6 ARB (fr/en/de/es/it/pt), sans ASCII-only residue — audit passé, PAS rewrite (les labels sont déjà i18n-wired à `apps/mobile/lib/widgets/mint_shell.dart:50-65`, MEMORY.md était stale).
  5. `tools/checks/accent_lint_fr.py` (GUARD-04) gate green sur `.dart` + `.py` + `.arb` — accents 100% FR corrects, 0 résidu ASCII.
  6. Les **43 redirects legacy** (reconciled 2026-04-20) ont leur analytics actif (via MAP-05) depuis Phase 32 ; leur sunset est DEFER v2.9+ documenté (zero-traffic 30-day validation requise, PAS suppression v2.8).
**Plans**: TBD
**Budget**: **2-3 sem MINIMUM, non-empruntable** (per kill-policy ADR)
**Auto profile**: **L3 mandatory** — 4 P0 fixes UI-visible + creator-device gate Julien 20 min cold-start déjà spec'd dans Success Criteria #1. `/gsd-execute-phase` + walker.sh simctl gate par batch fix + `gsd-verifier` 7-pass + `gsd-ui-review` + `gsd-secure-phase` (compliance touched par bare-catch migration) + creator-device gate Julien manuel non-skippable. **NOT autonomous** — c'est le sign-off final v2.8. Voir [`decisions/ADR-20260419-autonomous-profile-tiered.md`](../decisions/ADR-20260419-autonomous-profile-tiered.md).

## Progress

**Execution Order:**
Phases execute in dependency order: 30.5 → 30.6 → 30.7 → (31 ∥ 34) → (32 ∥ 33) → 35 → 36.
Parallel windows: 31∥34 (disjoint concerns: instrumentation vs lints) ; 32∥33 (disjoint: cartographie vs kill-switches).
Device gate (Julien simctl cold-start) mandatory for Phase 36 sign-off.
Kill-policy ADR gate: every Phase 36 P0 REQ must either ship with regression test OR be killed via its flag at milestone close.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 30.5. Context Sanity | v2.8 | 0/6 | Plans ready | — |
| 30.6. Context Sanity Advanced | v2.8 | 0/3 | Not started | — |
| 30.7. Tools Déterministes | v2.8 | 0/0 | Not started | — |
| 31. Instrumenter | v2.8 | 0/5 | Plans ready | — |
| 32. Cartographier | v2.8 | 0/0 | Not started | — |
| 33. Kill-switches | v2.8 | 0/0 | Not started | — |
| 34. Agent Guardrails mécaniques | v2.8 | 0/0 | Not started | — |
| 35. Boucle Daily | v2.8 | 0/0 | Not started | — |
| 36. Finissage E2E | v2.8 | 0/0 | Not started | — |

## Kill-policy reference

Every Phase 36 P0 REQ (FIX-01..04) has a kill-switch flag provisioned in Phase 33 BEFORE Phase 36 begins. At v2.8 close, if a requirement is not verifiably met (green lint + device-walkthrough signed by Julien + regression test landed), the corresponding flag is set `false` in production. A "v2.9 stabilisation milestone" is not a valid successor — stabilisation becomes transversal discipline. See [decisions/ADR-20260419-v2.8-kill-policy.md](../decisions/ADR-20260419-v2.8-kill-policy.md).

---
*Roadmap created: 2026-04-12*
*Last updated: 2026-04-19 — v2.8 L'Oracle & La Boucle roadmap created post-panel-debate (8 phases, 48 REQ mapped 1:1). Phase 30.5 split into Core + Advanced on 2026-04-19 (expert panel Option F); Tools Déterministes renumbered 30.6 → 30.7. Build order 30.5 → 30.6 → 30.7 → (31∥34) → (32∥33) → 35 → 36.*
