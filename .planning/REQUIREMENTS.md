# Requirements: MINT v2.8 L'Oracle & La Boucle

**Defined:** 2026-04-19
**Core Value (v2.8):** À la fin de v2.8, toute route user-visible marche end-to-end et on le prouve mécaniquement. On sait en <60s ce qui casse (oracle). Aucun agent ne peut ignorer son contexte (guardrails pre-commit). Julien ouvre MINT 20 min sans taper un mur.

**Kill-policy:** [decisions/ADR-20260419-v2.8-kill-policy.md](../decisions/ADR-20260419-v2.8-kill-policy.md) — si un REQ table-stake n'est pas livré, la feature est KILLED via flag. Pas de v2.9 stabilisation.

**Research:** [research/SUMMARY.md](research/SUMMARY.md) (+ STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md)

---

## v2.8 Requirements

**48 REQ-IDs, 8 catégories, mappés 1:1 aux 8 phases (30.5, 30.6, 31, 32, 33, 34, 35, 36).** Table-stakes only — differentiators descopables listés plus bas.

**Phase debate resolved** : Panel expert (4 agents — Claude Code architect / peer tools engineer / academic researcher / devil's advocate) a débattu GUARD-09/10/11. Synthèse :
- **Convergence** : MEMORY.md truncation = bug runtime P0 confirmé (226L > limite 200, cause racine accents oubliés). Lints mécaniques ROI > refonte éditoriale. AST proof-of-read = theater.
- **Divergence résolue** : Context Sanity scope splitté en 30.5 Core (3j, CTX-01/02) + 30.6 Advanced (2-3j + 72h burn-in, CTX-03/04/05, kill-policy) post panel 2026-04-19, ajout Phase 30.7 Tools Déterministes (insight Panel C), hook `UserPromptSubmit` ciblé (Panel A) remplace proof-of-read AST.
- Artefacts débat : [phase-30.5-context-foundation/PANEL-{A,B,C,D}-*.md](phase-30.5-context-foundation/)

### CTX Core — Context Sanity Core (Phase 30.5, 3 jours, non-empruntable)

Foundation non-négociable phase 1/2 — capture baseline J0 metrics avant toute refonte. Sans docs agent-lisibles + métriques de drift, toutes les phases suivantes seront codées à l'aveugle.

- [x] **CTX-01**: Fix P0 bug runtime MEMORY.md truncation — split INDEX `MEMORY.md` (<100 lignes, pointeurs vers topics seulement) + `memory/topics/*.md` retrieval on-demand, move Wave C handoff + autres project_session vers topic files, lefthook hook enforce INDEX <100 lignes HARD (exempt entrées <7j pour préserver handoffs actifs). J1 matin, 2h. Mesure : 0 "Only part was loaded" warning sur nouvelles sessions.
- [x] **CTX-02**: Instrumentation métriques drift — 4 métriques mesurables : (a) drift rate = % commits agent avec régression accent/hardcoded-FR/bare-catch détectée post-hoc, (b) context hit rate = % règles pertinentes lues avant 1er tool_use (proxy via breadcrumb Sentry), (c) token cost per session (tracked via Anthropic API usage), (d) time-to-first-correct-output. Dashboard CLI `tools/agent-drift/dashboard.py` + baseline J0 avant refonte. J1-J2, 1j. Mesure : 4 métriques live, baseline capturée.

### CTX Advanced — Context Sanity Advanced (Phase 30.6, 2-3 jours + 72h burn-in, non-empruntable)

Foundation non-négociable phase 2/2 — refonte + hook + spike validation. Kill-policy D-01 active : si CTX-05 spike fail 2× calendar-day, rollback 30.6 entirely (Modeste 1 fallback, 30.5 artifacts preserved).

- [x] **CTX-03**: CLAUDE.md restructure — split 4 fichiers : `CLAUDE.md` (quickref ~100L, routing par rôle) + `docs/AGENTS/flutter.md` + `docs/AGENTS/backend.md` + `docs/AGENTS/swiss-brain.md`. Règles critiques (banned terms, accents, retirement framing, financial_core reuse) placées en TOP + BOTTOM du quickref (fix lost-in-the-middle Liu 2024). Remplacer 10 principaux NEVER par triplets `{bad → good → why}` (fix "don't think of elephant" Min 2022, -15-25pts recall évité). Audit redondance CLAUDE.md §5-7 vs skills `mint-*`. J2-J3, 1j. Mesure : tokens chargés/session -40%, 0 redondance skills.
- [x] **CTX-04**: `UserPromptSubmit` hook ciblé 5 patterns MINT — inject 200-400 tokens par prompt si pattern détecté dans user message : (1) fichier `.arb` édité → inject ARB parity reminder, (2) fichier .dart dans screens/ → inject i18n + accent reminder, (3) mention "calcul|calculator" → inject financial_core reuse reminder, (4) mention "commit" → inject commit hygiene reminder, (5) nouveau fichier .dart → inject existing-code-check reminder. Fallback pattern léger + timeout 500ms fail-open, pas AST proof-of-read (rejeté Panel A + D comme theater). J3-J4, 1j. Mesure : drift -45 à -55% (baseline Panel A).
- [x] **CTX-05**: Spike validation go/no-go Phase 31 — 1 agent code chunk simple Phase 31 (bump `sentry_flutter` 8→9 + wire SentryWidget + maskAllText options dans main.dart). Mesure sur dashboard CTX-02 : accents oubliés ? financial_core réinventé ? NEVER banned terms violé ? Si drift détecté, itère CLAUDE.md (CTX-03) et relance spike. Si 2 itérations échouent, déclenche kill-policy Modeste 1 sur 30.6 (rollback CTX-03 + CTX-04, garde CTX-01 + CTX-02 + early lints). J5, 1j. Mesure : spike agent livre code sans régression détectée, sinon itère.

### TOOL — Tools Déterministes (Phase 30.7, 2-3 jours)

Insight Panel C : les constantes financières + règles compliance gaspillent ~400 tokens/turn dans CLAUDE.md. Les transformer en MCP tools `on-demand` économise 16k tokens/session × N sessions = gain massif cumulé.

- [ ] **TOOL-01**: MCP tool `get_swiss_constants(category)` — catégories : pillar3a / lpp / avs / mortgage / tax. Retourne constantes 2025/2026 structurées (ex: `{pillar3a_salarie_lpp: 7258, pillar3a_independant_no_lpp: 36288}`). Source : `services/backend/app/constants/` (déjà single source of truth). Supprime les constantes hardcodées de CLAUDE.md §5 BUSINESS RULES (gain ~400 tokens/turn).
- [ ] **TOOL-02**: MCP tool `check_banned_terms(text)` — wrap `ComplianceGuard` backend existant (déjà déployé Phase 29, sous-utilisé). Retourne `{banned_found: ["garanti", "optimal"], suggestions: ["pourrait", "envisager"]}` on-demand.
- [ ] **TOOL-03**: MCP tool `validate_arb_parity()` + `check_accent_patterns(text)` — wrap les lints `tools/checks/arb_parity.py` + `tools/checks/accent_lint_fr.py` (Phase 34) en MCP tools. Agent appelle on-demand au lieu de charger les listes patterns en mémoire permanente.
- [ ] **TOOL-04**: CLAUDE.md hook les 3 tools — remplace les sections §5 BUSINESS RULES (constantes) + §6 COMPLIANCE (banned terms list) par pointeurs "use `get_swiss_constants()` tool". Supprime ~800 tokens cumulés de CLAUDE.md core. Mesure : tokens core CLAUDE.md -30%, tools invoqués ≥1×/session sur tâches pertinentes.

### OBS — Observabilité / Oracle (Phase 31)

- [x] **OBS-01**: Sentry Replay Flutter wired avec `maskAllText=true` + `maskAllImages=true` + `sessionSampleRate=0.05` + `onErrorSampleRate=1.0` (nLPD-safe defaults non-négociables, bump `sentry_flutter: 9.14.0`)
- [x] **OBS-02**: Global error boundary 3-prongs installé (`FlutterError.onError` + `PlatformDispatcher.instance.onError` + `Isolate.current.addErrorListener`) — NE PAS utiliser `runZonedGuarded`
- [x] **OBS-03**: Global exception handler FastAPI fail-loud — `trace_id` (read from `sentry-trace` header) + `sentry_event_id` dans JSON response + header `X-Trace-Id` sortie, backward-compatible avec `LoggingMiddleware` existant
- [x] **OBS-04**: Trace_id round-trip mobile→backend via headers `sentry-trace` + `baggage` sur `http: ^1.2.0` existant (pas Dio migration) — cross-project link Sentry UI actif
- [x] **OBS-05**: `SentryNavigatorObserver` sur `GoRouter` + breadcrumb custom (ComplianceGuard success/fail, save_fact tool call, FeatureFlags.refreshFromBackend outcome)
- [x] **OBS-06**: Sentry Replay PII redaction audit artefact (`.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md`) committed AVANT flip `sessionSampleRate>0` en prod — screens sensibles énumérés (CoachChat, DocumentScan, ExtractionReviewSheet, Onboarding, Budget), masks vérifiés sur simulateur
- [x] **OBS-07**: Sentry tier/pricing fresh fetch + quota budget documenté (staging vs prod DSN, replay quota, events/mois target ~5k users) — artefact `.planning/observability-budget.md`

### MAP — Cartographie vivante (Phase 32)

- [x] **MAP-01**: Route registry-as-code `lib/routes/route_metadata.dart` — `kRouteRegistry: Map<String, RouteMeta>` avec 147 entrées (path, category, owner, requiresAuth, killFlag)
- [x] **MAP-02a**: CLI `./tools/mint-routes {health|redirects|reconcile}` (Python argparse stdlib, Keychain auth `SENTRY_AUTH_TOKEN` scope `project:read`+`event:read`, Sentry `transaction:<path>` query with batch OR optimization J0 validated, sysexits.h exit codes, `--json` mode for Phase 35 dogfood, `--no-color` + `NO_COLOR` env, `MINT_ROUTES_DRY_RUN=1` fixture, PII redaction layer per nLPD D-09)
- [x] **MAP-02b**: Flutter UI `/admin/routes` **pure schema viewer** dev-only (compile-time `--dart-define=ENABLE_ADMIN=1` + runtime `FeatureFlags.isAdmin` local check — **PAS de backend endpoint `/admin/me`** per v4 D-10). Displays 147 routes grouped by owner (15 buckets), columns `path | category | owner | requiresAuth | killFlag | FF enabled | description`. **NO Sentry health data, NO snapshot JSON read** (iOS sandbox limitation, v4 architectural simplification). Live health = CLI exclusive.
- [x] **MAP-03**: Route health data join **CLI EXCLUSIVE** (registry × Sentry Issues API last 24h via `transaction:<path>` query × FeatureFlags status × last-visited breadcrumbs) → affiché vert/jaune/rouge/dead par route dans le terminal CLI. Flutter UI schema viewer n'affiche PAS le health status.
- [x] **MAP-04**: `tools/checks/route_registry_parity.py` lint standalone (fail CI si `GoRoute|ScopedGoRoute(path:)` dans app.dart vs `kRouteRegistry` drift) + `KNOWN-MISSES.md` documentant patterns regex-unparsables (multi-line, ternary, dynamic builders). CI job wired Phase 32 D-12. Lefthook hook wiring = Phase 34 scope.
- [x] **MAP-05**: Analytics hit-counter sur **43 redirects legacy** (reconciled 2026-04-20, ROADMAP estimate was 23) via Sentry breadcrumb `mint.routing.legacy_redirect.hit` (paths only, no query params, PII redacted per D-09). Instrumentation seulement, pas suppression — sunset DEFER v2.9+ après 30-day zero-traffic validation.

### FLAG — Kill-switches par route (Phase 33)

- [ ] **FLAG-01**: Middleware GoRouter `requireFlag(ctx, state)` via `redirect:` callback (insertion BEFORE existing auth guard à `app.dart:177-261`) — route dont `killFlag` est off → redirige vers `/flag-disabled?path=X&flag=Y`
- [ ] **FLAG-02**: `FeatureFlags` refactor → `ChangeNotifier` + `GoRouter(refreshListenable: FeatureFlags.instance)` — hot-reload live sur flip (static fields deviennent getters proxy, 0 consumer change)
- [ ] **FLAG-03**: Convergence 2 flag systems backend — route flags vivent Redis via `FlagsService.set_global()`, surface via `/config/feature-flags` existant (env-backed `FeatureFlags` pour read path seulement, PAS de 3e système)
- [ ] **FLAG-04**: Admin `/admin/flags` UI 1-clic toggle + `PATCH /admin/flags/{name}` endpoint (auth admin seulement, invalide cache immédiat, client refresh <2s)
- [ ] **FLAG-05**: Flag-group pattern déployé — `enableExplorerRetraite/Famille/Travail/Logement/Fiscalite/Patrimoine/Sante` + `enableCoachChat` + `enableScan` + `enableBudget` + `enableAnonymousFlow` (11 flags, pas 147, évite flag rot)

### GUARD — Agent Guardrails mécaniques (Phase 34)

**Note post-panel** : GUARD-09/10/11 (doc refonte + proof-of-read AST) hoistés vers Phase 30.5 CTX-* suite au débat panel. Phase 34 garde les 8 guards mécaniques (lints + CI thinning) — c'est le VRAI gardien long-terme selon Panel B + D (ROI mesurable, pas theater).

- [ ] **GUARD-01**: lefthook 2.1.5 installed (brew) + `lefthook.yml` pre-commit parallel complet — target <5s absolu sur M-series Mac, scope changed-files only via glob filters. (Note : minimal lefthook installation déjà faite Phase 30.5 CTX-01 pour MEMORY.md gate. Phase 34 = full config avec tous les gates.)
- [ ] **GUARD-02**: `tools/checks/no_bare_catch.py` — refuse `} catch (e) {}` Dart + `except Exception:` Python sans log/rethrow, exempte `test/` + streams `async *`
- [ ] **GUARD-03**: `tools/checks/no_hardcoded_fr.py` — scan Dart widgets pour strings FR hors `AppLocalizations`, exclut `lib/l10n/`
- [ ] **GUARD-04**: `tools/checks/accent_lint_fr.py` — ASCII-only flag sur `app_fr.arb` + `.dart` + `.py` (patterns : creer, decouvrir, eclairage, securite, liberer, preter, realiser, deja, recu, elaborer, regler)
- [ ] **GUARD-05**: `tools/checks/arb_parity.py` — 6 ARB files (fr, en, de, es, it, pt) mêmes keyset, fail CI si drift
- [ ] **GUARD-06**: `tools/checks/proof_of_read.py` — fallback léger (pas AST) — agent co-author commits doivent référencer `.planning/<phase>/READ.md` listant fichiers modifiés (complémentaire à CTX-04 UserPromptSubmit hook)
- [ ] **GUARD-07**: `--no-verify` ban → `LEFTHOOK_BYPASS=1` convention (grep-able shell history) + CI post-merge audit re-run lefthook sur PR range + alerte si >3 bypass/semaine
- [ ] **GUARD-08**: CI thinning — les 10 grep-style gates existants `tools/checks/*.py` deviennent lefthook-first, CI garde heavy gates only (full test suites, readability, WCAG, PII, contracts, migrations)

### LOOP — Boucle Daily (Phase 35)

- [ ] **LOOP-01**: `tools/dogfood/mint-dogfood.sh` — bash script `xcrun simctl` (iPhone 17 Pro primary) + `idb` fallback pour accessibility taps, 8-step scenario (landing → signup → intent → premier-éclairage → scan → coach-reply → budget → settings), ~10 min unattended
- [ ] **LOOP-02**: `tools/dogfood/render_report.py` — génère `.planning/dogfood/YYYY-MM-DD/README.md` avec screenshots inline, Sentry events groupés par severity, diff vs J-1 (optionnel)
- [ ] **LOOP-03**: Pull Sentry events last 15 min via `sentry-cli api` (mobile + backend projects) + auth `SENTRY_AUTH_TOKEN` macOS Keychain
- [ ] **LOOP-04**: Auto-PR threshold — `gh pr create` seulement si ≥1 P0 ou ≥3 P1 dans le report (pas spam, signal-over-noise)
- [ ] **LOOP-05**: `.planning/dogfood/` rotation keep-30-days + gitattributes LFS après 60j (~200MB/mois au rythme 10 min/jour × 8 screenshots)

### FIX — Finissage E2E (Phase 36) — les P0 réels

Chaque FIX provisionné avec kill-switch flag AVANT Phase 36 (per kill-policy ADR).

- [ ] **FIX-01** (kill: `enableProfileLoad`): P0 UUID profile crash fix — `services/backend/app/schemas/profile.py` UUID validation, rolling deploy staging-first, regression test backend
- [ ] **FIX-02** (kill: `enableAnonymousFlow`): P0 Anonymous flow one-line fix — `apps/mobile/lib/screens/landing_screen.dart` CTA cible `/anonymous/chat` (pas `/coach/chat` auth-gated), regression test Flutter
- [ ] **FIX-03** (kill: `enableSaveFactSync`): P0 save_fact sync backend→mobile — `responseMeta.profileInvalidated` field dans canonical OpenAPI, `CoachProfile` reactive invalidation, regression test Flutter
- [ ] **FIX-04** (kill: `enableCoachTab`): P0 Coach tab routing stable — navigation state fix, regression test Flutter
- [ ] **FIX-05**: 388 bare catches → 0 — classification-first (P0 : core flows / P1 : UX best-effort / P2 : test mocks exemptés), backend 56 d'abord (pattern simple), mobile 332 batched 20/PR, `tools/checks/no_bare_catch.py` (GUARD-02) empêche régression pendant migration
- [ ] **FIX-06**: MintShell ARB parity 6 langs audit — labels `l.tabAujourdhui / l.tabMonArgent / l.tabCoach / l.tabExplorer` DÉJÀ i18n-wired ([apps/mobile/lib/widgets/mint_shell.dart:50-65](apps/mobile/lib/widgets/mint_shell.dart)), audit seulement : clés présentes dans fr/en/de/es/it/pt, pas de ASCII-only residue (pas rewrite, MEMORY.md était stale)
- [ ] **FIX-07**: Accents 100% — `tools/checks/accent_lint_fr.py` (GUARD-04) gate green sur `.dart` + `.py` + `.arb`
- [ ] **FIX-08**: **43 redirects legacy** (reconciled 2026-04-20, ROADMAP estimate was 23) — analytics instrumentés (MAP-05, Phase 32), sunset DEFER v2.9+ (PAS suppression v2.8, zero-traffic validation d'abord)
- [ ] **FIX-09**: Regression test par P0 fix — chaque FIX-01 à FIX-05 ship avec test qui aurait failé pre-fix (empêche régression future, enforcé par code review)

---

## Differentiators (Out of Scope v2.8, descopable order)

Si budget serre, coupe dans cet ordre — cf. [research/FEATURES.md](research/FEATURES.md) §J.

- **DIFF-01**: Circuit breaker auto-off Sentry-threshold (Phase 33 extension SLOMonitor)
- **DIFF-02**: Heatmap user paths (Phase 32)
- **DIFF-03**: Screenshot thumbnail refresh nightly (Phase 32)
- **DIFF-04**: Proof-of-read via Claude Agent SDK `PreToolUse` hook (si indispo, fallback GUARD-06)
- **DIFF-05**: Screenshot diff J-1 vs J (Phase 35) — defer v2.9
- **DIFF-06**: Replay auto-tuning sampleRate (Phase 35)
- **DIFF-07**: Breadcrumb custom ComplianceGuard / save_fact / FeatureFlags (partie OBS-05)
- **DIFF-08**: Custom spans sur 4 appels LLM (Phase 31)
- **DIFF-09**: Performance budget par route LCP/TTI (Phase 33)

## v2.9+ Requirements (explicitly deferred)

Tracked but NOT in current roadmap :

### La Confiance (proposition originale v2.8 "La Confiance", déplacée v2.9+)
- **CONF-01**: Privacy Nutrition Label (Apple-style)
- **CONF-02**: Data Vault user-facing (access + export + delete)
- **CONF-03**: Trust Mode toggle (shadow vs primary data sources)
- **CONF-04**: Graduation Protocol v1 (MINT se rend inutile concept par concept)

### Observability deep
- **OBS-v9-01**: Migration `http` → `dio: 5.9.0` + `sentry_dio: 9.14.0`
- **OBS-v9-02**: OpenTelemetry FastAPI instrumentation
- **OBS-v9-03**: Screenshot pixel diffing

### Effective deletion
- **DEL-v9-01**: Suppression des **43 redirects legacy** (reconciled 2026-04-20) après 30-day zero-traffic validation

## Out of Scope (v2.8 explicit refusal)

| Feature | Reason |
|---------|--------|
| **Any new user-facing feature** | Règle "0 feature nouvelle" scellée par [kill-policy ADR](../decisions/ADR-20260419-v2.8-kill-policy.md) |
| Datadog RUM / Amplitude / PostHog / FullStory / LogRocket | PROJECT.md L49 — Sentry single vendor |
| LaunchDarkly / Statsig / Unleash / Firebase Remote Config | PROJECT.md L48 — étendre FeatureFlags custom |
| Patrol / Appium / Maestro | PROJECT.md L50 — simctl + idb suffit |
| Husky / pre-commit (python) | Sequential, slow, polyglot-hostile — lefthook only |
| `runZonedGuarded` wrapper | Zone mismatch sentry_flutter 9.x |
| sentry_dio migration | Rewrite ApiService, v2.9+ |
| OpenTelemetry backend | Sentry Performance couvre, v2.9+ |
| In-app screenshot archive | Sentry Replay + simctl externe mieux |
| `--no-verify` commits | `LEFTHOOK_BYPASS=1` seul autorisé |
| Cohort/percentage flags | Binary-per-route only, pas cohort mgmt |
| Suppression redirects legacy | Analytics first (MAP-05), sunset v2.9+ |
| Monte Carlo UI / withdrawal sequencing UI / tornado sensitivity | Reporté v2.9+ |
| Premium gate wiring (Stripe/RevenueCat) | v2.9+ |
| Privacy Nutrition Label + Data Vault + Trust Mode + Graduation Protocol v1 | Déplacé v2.9+ |

---

## v2.8 Traceability

Every v2.8 REQ is mapped to exactly one phase. Status is `Pending, Phase X assigned` until phase planning kicks off, at which point `/gsd-plan-phase X` flips status to `Planning`, then `In Progress`, then `Complete` after verifier sign-off.

| Requirement | Phase | Kill flag | Status |
|-------------|-------|-----------|--------|
| CTX-01 | **30.5** | — | Pending, Phase 30.5 assigned |
| CTX-02 | **30.5** | — | Pending, Phase 30.5 assigned |
| CTX-03 | **30.6** | — | Pending, Phase 30.6 assigned (moved from 30.5 per 2026-04-19 split) |
| CTX-04 | **30.6** | — | Pending, Phase 30.6 assigned (moved from 30.5 per 2026-04-19 split) |
| CTX-05 | **30.6** | spike gate go/no-go | Pending, Phase 30.6 assigned (moved from 30.5 per 2026-04-19 split) |
| TOOL-01 | **30.7** | — | Pending, Phase 30.7 assigned (renumbered 30.6 → 30.7 per 2026-04-19 split) |
| TOOL-02 | **30.7** | — | Pending, Phase 30.7 assigned (renumbered 30.6 → 30.7 per 2026-04-19 split) |
| TOOL-03 | **30.7** | — | Pending, Phase 30.7 assigned (renumbered 30.6 → 30.7 per 2026-04-19 split) |
| TOOL-04 | **30.7** | — | Pending, Phase 30.7 assigned (renumbered 30.6 → 30.7 per 2026-04-19 split) |
| OBS-01 | 31 | — | Complete 2026-04-19 (Plan 31-01) |
| OBS-02 | 31 | — | Complete 2026-04-19 (Plan 31-01) |
| OBS-03 | 31 | — | Complete 2026-04-19 (Plan 31-02) |
| OBS-04 | 31 | — | Complete 2026-04-19 (Plan 31-01 + 31-02) |
| OBS-05 | 31 | — | Complete 2026-04-19 (Plan 31-01) |
| OBS-06 | 31 | PII audit gate | Complete 2026-04-19 (Plan 31-03, automated pre-creator-device pass) |
| OBS-07 | 31 | — | Complete 2026-04-19 (Plan 31-04) |
| MAP-01 | 32 | — | Pending, Phase 32 assigned |
| MAP-02 | 32 | `enableAdminScreens` | Pending, Phase 32 assigned |
| MAP-03 | 32 | — | Pending, Phase 32 assigned |
| MAP-04 | 32 | — | Pending, Phase 32 assigned |
| MAP-05 | 32 | — | Pending, Phase 32 assigned |
| FLAG-01 | 33 | — | Pending, Phase 33 assigned |
| FLAG-02 | 33 | — | Pending, Phase 33 assigned |
| FLAG-03 | 33 | — | Pending, Phase 33 assigned |
| FLAG-04 | 33 | `enableAdminScreens` | Pending, Phase 33 assigned |
| FLAG-05 | 33 | — | Pending, Phase 33 assigned |
| GUARD-01 | 34 | — | Pending, Phase 34 assigned |
| GUARD-02 | 34 | prereq FIX-05 Phase 36 | Pending, Phase 34 assigned |
| GUARD-03 | 34 | — | Pending, Phase 34 assigned |
| GUARD-04 | 34 | prereq FIX-07 Phase 36 | Pending, Phase 34 assigned |
| GUARD-05 | 34 | — | Pending, Phase 34 assigned |
| GUARD-06 | 34 | — | Pending, Phase 34 assigned |
| GUARD-07 | 34 | — | Pending, Phase 34 assigned |
| GUARD-08 | 34 | — | Pending, Phase 34 assigned |
| LOOP-01 | 35 | — | Pending, Phase 35 assigned |
| LOOP-02 | 35 | — | Pending, Phase 35 assigned |
| LOOP-03 | 35 | — | Pending, Phase 35 assigned |
| LOOP-04 | 35 | — | Pending, Phase 35 assigned |
| LOOP-05 | 35 | — | Pending, Phase 35 assigned |
| FIX-01 | 36 | `enableProfileLoad` | Pending, Phase 36 assigned |
| FIX-02 | 36 | `enableAnonymousFlow` | Pending, Phase 36 assigned |
| FIX-03 | 36 | `enableSaveFactSync` | Pending, Phase 36 assigned |
| FIX-04 | 36 | `enableCoachTab` | Pending, Phase 36 assigned |
| FIX-05 | 36 | cross-cutting (guarded by GUARD-02) | Pending, Phase 36 assigned |
| FIX-06 | 36 | — | Pending, Phase 36 assigned |
| FIX-07 | 36 | enforced by GUARD-04 | Pending, Phase 36 assigned |
| FIX-08 | 36 | defer v2.9+ | Pending, Phase 36 assigned |
| FIX-09 | 36 | — | Pending, Phase 36 assigned |

**v2.8 Coverage:**
- **48 REQ total**, **48 mapped to exactly one phase**, **0 unmapped** ✓
- Category totals: CTX=5 + TOOL=4 + OBS=7 + MAP=5 + FLAG=5 + GUARD=8 + LOOP=5 + FIX=9 = **48** ✓
- Phases: 30.5 (5j) + 30.6 (2-3j) + 31 (1.5sem) + 32 (1sem) + 33 (1sem) + 34 (1.5sem ∥ 31) + 35 (1sem) + 36 (2-3sem NON-empruntable)
- Budget total estimé: 8-10 semaines solo-dev (parallélisation 31∥34, 32∥33)
- Phase 36 kill-switches provisioned: 4/4 P0 flags ✓ (`enableProfileLoad`, `enableAnonymousFlow`, `enableSaveFactSync`, `enableCoachTab`)
- Phase 30.5 spike validation go/no-go (CTX-05) gate Phase 31 start

**Note on count:** Earlier draft of this document stated "50 REQ-IDs" in the §v2.8 Requirements header — corrected to **48** after per-REQ enumeration audit. Category breakdown (CTX=5, TOOL=4, OBS=7, MAP=5, FLAG=5, GUARD=8, LOOP=5, FIX=9) sums to 48, matching the expanded traceability table above.

---

## Historical Requirements (shipped milestones)

### v2.7 Coach Stabilisation + Document Digestion

**Defined:** 2026-04-14 · **Status:** Code-complete, awaiting GATE-01/02 device walkthrough

| REQ | Phase | Status |
|-----|-------|--------|
| STAB-01..05 | 27 | ✓ Complete |
| DOC-01..08 | 28 | ✓ Complete |
| PRIV-01..08 | 29 | ✓ Complete |
| GATE-03, GATE-04 | 30-01 | ✓ Complete |
| GATE-01, GATE-02 | 30-02 | ~ Code ready, device walkthrough pending |

25/25 requirements code-complete. Details archived in [milestones/v2.7-phases/](milestones/v2.7-phases/) (was `.planning/phases/` before v2.8 archive).

### v2.5 Transformation

**Defined:** 2026-04-12 · **Status:** ✓ Shipped 2026-04-13

| Category | REQs | Status |
|----------|------|--------|
| Anonymous Hook & Auth Bridge | ANON-01..06 | ✓ Complete |
| Commitment Devices | CMIT-01..06 | ✓ Complete |
| Coach Intelligence | INTL-01..04 | ✓ Complete |
| Couple Mode Dissymetrique | COUP-01..04 | ✓ Complete |
| Cleo Loop Navigation | LOOP-01..03 | ✓ Complete |
| Living Timeline | TIME-01..05 | ✓ Complete |

28/28 requirements shipped.

### Previous milestones (v1.0, v2.0, v2.1, v2.4, v2.6)

See [MILESTONES.md](MILESTONES.md) for accomplishments summary.

---
*Requirements defined: 2026-04-12 (v2.5), 2026-04-14 (v2.7), 2026-04-19 (v2.8)*
*Last updated: 2026-04-19 — v2.8 L'Oracle & La Boucle requirements defined post-research ; traceability expanded per-REQ, count corrected 50→48*
