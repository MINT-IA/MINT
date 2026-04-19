# Requirements: MINT v2.8 L'Oracle & La Boucle

**Defined:** 2026-04-19
**Core Value (v2.8):** À la fin de v2.8, toute route user-visible marche end-to-end et on le prouve mécaniquement. On sait en <60s ce qui casse (oracle). Aucun agent ne peut ignorer son contexte (guardrails pre-commit). Julien ouvre MINT 20 min sans taper un mur.

**Kill-policy:** [decisions/ADR-20260419-v2.8-kill-policy.md](../decisions/ADR-20260419-v2.8-kill-policy.md) — si un REQ table-stake n'est pas livré, la feature est KILLED via flag. Pas de v2.9 stabilisation.

**Research:** [research/SUMMARY.md](research/SUMMARY.md) (+ STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md)

---

## v2.8 Requirements

45 REQ-IDs, 6 catégories, mappés 1:1 aux 6 phases (31-36). Table-stakes only — differentiators descopables listés plus bas si budget serre.

### OBS — Observabilité / Oracle (Phase 31)

- [ ] **OBS-01**: Sentry Replay Flutter wired avec `maskAllText=true` + `maskAllImages=true` + `sessionSampleRate=0.05` + `onErrorSampleRate=1.0` (nLPD-safe defaults non-négociables, bump `sentry_flutter: 9.14.0`)
- [ ] **OBS-02**: Global error boundary 3-prongs installé (`FlutterError.onError` + `PlatformDispatcher.instance.onError` + `Isolate.current.addErrorListener`) — NE PAS utiliser `runZonedGuarded`
- [ ] **OBS-03**: Global exception handler FastAPI fail-loud — `trace_id` (read from `sentry-trace` header) + `sentry_event_id` dans JSON response + header `X-Trace-Id` sortie, backward-compatible avec `LoggingMiddleware` existant
- [ ] **OBS-04**: Trace_id round-trip mobile→backend via headers `sentry-trace` + `baggage` sur `http: ^1.2.0` existant (pas Dio migration) — cross-project link Sentry UI actif
- [ ] **OBS-05**: `SentryNavigatorObserver` sur `GoRouter` + breadcrumb custom (ComplianceGuard success/fail, save_fact tool call, FeatureFlags.refreshFromBackend outcome)
- [ ] **OBS-06**: Sentry Replay PII redaction audit artefact (`.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md`) committed AVANT flip `sessionSampleRate>0` en prod — screens sensibles énumérés (CoachChat, DocumentScan, ExtractionReviewSheet, Onboarding, Budget), masks vérifiés sur simulateur
- [ ] **OBS-07**: Sentry tier/pricing fresh fetch + quota budget documenté (staging vs prod DSN, replay quota, events/mois target ~5k users) — artefact `.planning/observability-budget.md`

### MAP — Cartographie vivante (Phase 32)

- [ ] **MAP-01**: Route registry-as-code `lib/routes/route_metadata.dart` — `kRouteRegistry: Map<String, RouteMeta>` avec 147 entrées (path, category, owner, requiresAuth, killFlag)
- [ ] **MAP-02**: `/admin/routes` dashboard dev-only (compile-time `--dart-define=ENABLE_ADMIN=1` + runtime `AdminProvider.isAllowed` via `GET /api/v1/admin/me`)
- [ ] **MAP-03**: Route health data join (registry × Sentry Issues API last 24h × FeatureFlags status × last-visited breadcrumbs) → affiché vert/jaune/rouge/dead par route
- [ ] **MAP-04**: `tools/checks/route_registry_parity.py` lint (fail CI si `GoRoute(path:)` dans app.dart vs `kRouteRegistry` drift)
- [ ] **MAP-05**: Analytics hit-counter sur 23 redirects legacy (instrumentation seulement, pas suppression — sunset DEFER v2.9+ après 30-day zero-traffic validation)

### FLAG — Kill-switches par route (Phase 33)

- [ ] **FLAG-01**: Middleware GoRouter `requireFlag(ctx, state)` via `redirect:` callback (insertion BEFORE existing auth guard à `app.dart:177-261`) — route dont `killFlag` est off → redirige vers `/flag-disabled?path=X&flag=Y`
- [ ] **FLAG-02**: `FeatureFlags` refactor → `ChangeNotifier` + `GoRouter(refreshListenable: FeatureFlags.instance)` — hot-reload live sur flip (static fields deviennent getters proxy, 0 consumer change)
- [ ] **FLAG-03**: Convergence 2 flag systems backend — route flags vivent Redis via `FlagsService.set_global()`, surface via `/config/feature-flags` existant (env-backed `FeatureFlags` pour read path seulement, PAS de 3e système)
- [ ] **FLAG-04**: Admin `/admin/flags` UI 1-clic toggle + `PATCH /admin/flags/{name}` endpoint (auth admin seulement, invalide cache immédiat, client refresh <2s)
- [ ] **FLAG-05**: Flag-group pattern déployé — `enableExplorerRetraite/Famille/Travail/Logement/Fiscalite/Patrimoine/Sante` + `enableCoachChat` + `enableScan` + `enableBudget` + `enableAnonymousFlow` (11 flags, pas 147, évite flag rot)

### GUARD — Agent Guardrails (Phase 34)

**Critical note:** Per doctrine feedback (CLAUDE.md + MEMORY.md sont LA condition de stabilité/performance MINT), les REQ GUARD-09/10/11 sont traités avec la même rigueur que les REQ OBS de la Phase 31. Ce sont des REQ tier-1, pas des chores doc.

- [ ] **GUARD-01**: lefthook 2.1.5 installed (brew) + `lefthook.yml` pre-commit parallel — target <5s absolu sur M-series Mac, scope changed-files only via glob filters
- [ ] **GUARD-02**: `tools/checks/no_bare_catch.py` — refuse `} catch (e) {}` Dart + `except Exception:` Python sans log/rethrow, exempte `test/` + streams `async *`
- [ ] **GUARD-03**: `tools/checks/no_hardcoded_fr.py` — scan Dart widgets pour strings FR hors `AppLocalizations`, exclut `lib/l10n/`
- [ ] **GUARD-04**: `tools/checks/accent_lint_fr.py` — ASCII-only flag sur `app_fr.arb` (patterns : creer, decouvrir, eclairage, securite, liberer, preter, realiser, deja, recu, elaborer, regler)
- [ ] **GUARD-05**: `tools/checks/arb_parity.py` — 6 ARB files (fr, en, de, es, it, pt) mêmes keyset, fail CI si drift
- [ ] **GUARD-06**: `tools/checks/proof_of_read.py` — agent co-author commits doivent avoir `.planning/<phase>/READ.md` mentionnant les fichiers modifiés (fallback si GUARD-11 indispo)
- [ ] **GUARD-07**: `--no-verify` ban → `LEFTHOOK_BYPASS=1` convention (grep-able shell history) + CI post-merge audit re-run lefthook sur PR range + alerte si >3 bypass/semaine
- [ ] **GUARD-08**: CI thinning — les 10 grep-style gates existants `tools/checks/*.py` deviennent lefthook-first, CI garde heavy gates only (full test suites, readability, WCAG, PII, contracts, migrations)
- [ ] **GUARD-09**: **Expert-panel refonte CLAUDE.md** — 4 experts convoqués (ex-Anthropic prompt engineer, ex-Stripe dev-experience, ex-Cursor agent-context architect, ex-Linear documentation lead). Output : structure-par-rôle (quickref 20-30 lignes par agent-type : flutter-dev / backend-dev / swiss-brain / team-lead), sections détaillées @-référencées, anti-patterns spécialisés par type de tâche, target ~150 lignes core. Mesure : réduction tokens/tâche ≥40%, 0 redondance, conflict resolution linéaire (pas 11 docs).
- [ ] **GUARD-10**: **Expert-panel refonte MEMORY.md** — même panel + ex-Chroma memory systems lead. Output : TTL structurel (feedback permanent / project_state 30j auto-archive vers `.claude/memory/archive/YYYY-MM/`), lefthook hook enforce <200 lignes HARD, catégorisation stricte (user/feedback/project/reference seulement, pas mélange), garbage-collect script `tools/memory/gc.py`. Mesure : MEMORY.md toujours <200 lignes, 0 entrée stale >30j, charge initiale agent réduite ≥50%.
- [ ] **GUARD-11**: **Pre-task context-sheet injecteur** (Claude Agent SDK `PreToolUse` hook ou git-side fallback) — à chaque spawn d'agent, injecte un context-sheet minimal spécifique à la tâche : (a) fichiers obligatoires à lire avant tout tool use, (b) anti-patterns pertinents seulement (filtrés par type de tâche), (c) proof-of-read question AST-based à laquelle l'agent doit répondre avant commit. Si Agent SDK hook indispo sur version Julien, fallback git prepare-commit-msg (GUARD-06). Mesure : 0 commit agent sans proof-of-read valide, accent lint 0 régression sur 30j.

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
- [ ] **FIX-08**: 23 redirects legacy — analytics instrumentés (MAP-05, Phase 32), sunset DEFER v2.9+ (PAS suppression v2.8, zero-traffic validation d'abord)
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
- **DEL-v9-01**: Suppression des 23 redirects legacy après 30-day zero-traffic validation

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

| Requirement | Phase | Kill flag | Status |
|-------------|-------|-----------|--------|
| OBS-01..07 | 31 | (OBS-06 gate) | Pending |
| MAP-01..05 | 32 | MAP-02: `enableAdminScreens` | Pending |
| FLAG-01..05 | 33 | FLAG-04: `enableAdminScreens` | Pending |
| GUARD-01..11 | 34 | — | Pending |
| LOOP-01..05 | 35 | — | Pending |
| FIX-01 | 36 | `enableProfileLoad` | Pending |
| FIX-02 | 36 | `enableAnonymousFlow` | Pending |
| FIX-03 | 36 | `enableSaveFactSync` | Pending |
| FIX-04 | 36 | `enableCoachTab` | Pending |
| FIX-05 | 36 | cross-cutting | Pending |
| FIX-06 | 36 | — | Pending |
| FIX-07 | 36 | enforced GUARD-04 | Pending |
| FIX-08 | 36 | defer v2.9+ | Pending |
| FIX-09 | 36 | — | Pending |

**v2.8 Coverage:**
- 45 REQ total, 45 mapped, 0 unmapped ✓
- Phase 36 kill-switches provisioned: 4/4 P0 flags ✓

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
*Last updated: 2026-04-19 — v2.8 L'Oracle & La Boucle requirements defined post-research*
