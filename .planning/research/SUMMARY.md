# SUMMARY — MINT v2.8 "L'Oracle & La Boucle"

Synthèse des 4 research files pour informer REQUIREMENTS.md et ROADMAP.md.

## 1. TL;DR

v2.8 n'est pas un milestone de features, c'est une intervention chirurgicale. MINT a perdu contact avec la réalité : **388 bare catches silencieux**, oracle absent, agents qui hallucinent, produit qu'on ne peut pas vérifier mécaniquement en <60s. Verdict panel unanime : les outils nécessaires **existent déjà en germe** (Sentry wirée, 12 gates CI, 8 flags, 52 redirect callbacks GoRouter, `tools/e2e_flow_smoke.sh`, SLOMonitor). **v2.8 = activer + assembler + fermer la boucle, pas construire from scratch.**

**La boucle inverse (ce qu'on ne fait PAS)** : 0 feature produit, 0 nouveau vendor (Datadog/LaunchDarkly/Amplitude refusés), 0 migration Dio, 0 OTel, 0 Patrol/Maestro, 0 Firebase Remote Config.

---

## 2. Stack additions (pin sheet)

Versions exactes vérifiées pub.dev / PyPI / GitHub 2026-04 — deep-dive [STACK.md](STACK.md).

| Dep | Current | v2.8 | Scope |
|-----|---------|------|-------|
| `sentry_flutter` | `^8.0.0` | **9.14.0** | mobile (Replay GA) |
| `go_router` | `^13.2.0` | **14.8.1** | mobile (refreshListenable) |
| `sentry-sdk[fastapi]` | `>=2.0.0,<3.0.0` | **==2.53.0** (pin exact) | backend |
| lefthook | — | **2.1.5** | repo (brew) |
| sentry-cli | — | **2.43.0** | dev host |
| idb-companion | — | **1.1.8** | dev host (brew fb tap) |
| fb-idb | — | **1.1.7** | dev host |

**Bundle delta:** +~1.2 MB IPA / +~800 KB AAB (Replay native chunk).
**Dev-loop:** +~600ms cold-start first-install (one-time).
**Deferred v2.9+:** sentry_dio / Dio migration, OpenTelemetry FastAPI, screenshot pixel diff.

---

## 3. Feature table stakes (must ship v2.8)

Par phase — deep-dive [FEATURES.md](FEATURES.md).

**Phase 31 Instrumenter — LOW/MED**
- Sentry Replay Flutter avec `maskAllText=true` + `maskAllImages=true` (nLPD non-négociable)
- Global error boundary 3-prongs (`FlutterError.onError` + `PlatformDispatcher.onError` + `Isolate.addErrorListener`)
- Global exception handler FastAPI fail-loud (trace_id + event_id dans response)
- `SentryNavigatorObserver` sur GoRouter
- Breadcrumb custom sur `ComplianceGuard`, `save_fact`, `FeatureFlags.refresh`
- Trace_id round-trip via headers manuels sur `http` existant (pas Dio)

**Phase 32 Cartographier — LOW**
- Route manifest codegen depuis GoRouter source (147 routes + 52 redirect callbacks)
- `/admin/routes` dashboard dev-only (compile `ENABLE_ADMIN=1` + runtime `AdminProvider.isAllowed`)
- Data join : registry × Sentry Issues API × FeatureFlags × last-visited breadcrumbs
- `tools/checks/route_registry_parity.py` lint CI

**Phase 33 Kill-switches — MED**
- Middleware GoRouter `requireFlag()` via `redirect` callback (insertion BEFORE auth guard à app.dart:177-261)
- Extension `FeatureFlags` → `ChangeNotifier` + `refreshListenable` (hot-reload sans restart)
- **Convergence 2 flag systems backend** : env-backed `FeatureFlags` (read) + Redis `FlagsService` (write) — route flags live in Redis, surface via `/config/feature-flags`
- Admin `/admin/flags` 1-clic (`PATCH /admin/flags/{name}`)
- Flag-group pattern (`enableExplorerRetraite` couvre 6 routes, évite flag rot)

**Phase 34 Agent Guardrails — MED**
- lefthook.yml pre-commit local (parallel, <5s target)
- 5 nouveaux lints Python dans `tools/checks/` : `no_bare_catch.py`, `no_hardcoded_fr.py`, `accent_lint_fr.py`, `arb_parity.py`, `proof_of_read.py`
- Ban `--no-verify` → `LEFTHOOK_BYPASS=1` grep-able
- CI thinning : les 12 gates existants deviennent lefthook-first, CI garde heavy gates seulement (full test suites, readability, WCAG, PII, contracts, migrations)

**Phase 35 Boucle Daily — MED**
- `tools/dogfood/mint-dogfood.sh` : simctl iPhone 17 Pro, 8-step scenario, ~10 min unattended
- `xcrun simctl` primary + `idb` fallback (accessibility tree queries)
- Pull Sentry events last 15 min via `sentry-cli api`
- Auto-PR si ≥1 P0 ou ≥3 P1 (pas spam)
- `tools/dogfood/render_report.py` génère `.planning/dogfood/YYYY-MM-DD.md`

**Phase 36 Finissage E2E — HIGH**
- **P0-UUID** : fix backend UUID profile crash (`services/backend/app/schemas/profile.py`)
- **P0-ANON** : one-line fix LandingScreen CTA `/coach/chat` → `/anonymous/chat`
- **P0-SAVEFACT** : backend `save_fact` tool → mobile `CoachProfile` reactive invalidation
- **P0-COACHTAB** : Coach tab routing stale fix
- **388 bare catches → 0** : classification-first + batched 20/PR, backend 56 d'abord, mobile 332 après
- **P0-MINTSHELL** : ARB parity audit 6 langues (labels DÉJÀ i18n-wired, pas rewrite — MEMORY.md était stale)
- Accents 100% (lint gate green)
- 23 redirects legacy : instrumenter analytics 32.4, sunset v2.9+ (PAS suppression v2.8)

---

## 4. Feature differentiators (descopable, ordre de sacrifice)

Si budget serre, coupe dans cet ordre — deep-dive [FEATURES.md](FEATURES.md) §J.

1. **Circuit breaker auto-off Sentry-threshold** (Phase 33 C5) — réutilise SLOMonitor mais non-critique v2.8
2. **Heatmap user paths** (Phase 32 B4) — stats agrégées, nice-to-know pas must
3. **Screenshot thumbnail refresh nightly** (Phase 32 B5) — static shots OK v2.8
4. **Proof-of-read via Agent SDK** (Phase 34 D6) — git prepare-commit-msg existe à défaut
5. **Screenshot diff J-1 vs J** (Phase 35 E7) — defer v2.9
6. **Replay auto-tuning sample rate** (Phase 35 E6) — hardcoded 0.05 OK
7. **Breadcrumb custom ComplianceGuard** (Phase 31 A7) — Sentry auto-capture suffit
8. **Custom spans sur 4 appels LLM** (Phase 31 A8) — default Sentry tracing suffit
9. **Performance budget par route** (Phase 33 C6) — LCP/TTI seulement si Flutter-web activé

---

## 5. Architecture — intégrations critiques

Deep-dive [ARCHITECTURE.md](ARCHITECTURE.md).

**3-prong error boundary (pas runZonedGuarded)** — patch [apps/mobile/lib/main.dart](apps/mobile/lib/main.dart) BEFORE `SentryFlutter.init` :

```dart
FlutterError.onError = (details) => FlutterError.presentError(details);
PlatformDispatcher.instance.onError = (error, stack) => true;
Isolate.current.addErrorListener(RawReceivePort((pair) async {
  final err = (pair as List);
  await Sentry.captureException(err.first, stackTrace: err.last);
}).sendPort);
```

**Trace_id round-trip** — headers manuels sur `http: ^1.2.0` existant (pas Dio migration) :

```dart
'sentry-trace': span.toSentryTrace().value,
'baggage': span.toBaggageHeader()?.value ?? '',
```

Backend `sentry-sdk[fastapi]` lit auto → cross-project link dans Sentry UI.

**FeatureFlags refactor** — `ChangeNotifier` + static getters proxy (0 consumer change, 1-2h) → `GoRouter(refreshListenable: FeatureFlags.instance)` déclenche redirect live sur flip.

**Findings importants du panel** :
- **MintShell labels DÉJÀ i18n-wired** ([apps/mobile/lib/widgets/mint_shell.dart:50-65](apps/mobile/lib/widgets/mint_shell.dart)) utilisent `l.tabAujourdhui`, `l.tabMonArgent`, etc. MEMORY.md était stale. **P0-MINTSHELL = audit ARB parity, pas rewrite.**
- **Anonymous flow = one-line fix** — `/anonymous/chat` + `AnonymousChatScreen` existent. Bug = LandingScreen CTA pointe `/coach/chat` (auth-gated). Bug de 10 secondes à fixer.
- **2 flag systems backend coexistent** — env-backed `FeatureFlags` (read, `/config/feature-flags`) + Redis-backed `FlagsService` (write, `set_global()`, dogfood). Phase 33 DOIT les converger : route flags vivent Redis via FlagsService, surfacent via endpoint existant. **N'INVENTE PAS UN 3E.**
- **SLOMonitor est déjà le primitive auto-rollback généralisable** — hardcode actuel `COACH_FSM_ENABLED`. Phase 33.5 = conversion vers registre `{flag, metric, threshold, window, breach_streak}`. Phase 27 devient fondation Phase 33.
- **CI a 10 grep-style gates déjà** — Phase 34 les déplace vers lefthook pre-commit (<5s feedback). CI thinning = ~2 min réduction CI time.
- **Existing `redirect:` callback à app.dart:177-261** = single insertion point Phase 33. `requireFlag()` check BEFORE existing scope switch. Zéro structural change.

---

## 6. Build order (dependency graph)

**31 → 34 → (32 ∥ 33) → 35 → 36**

- **31 d'abord** : taproot obligatoire, débloque tout le reste. Partial instrumentation (Replay sans traceparent) = 40% value + false confidence. **Tout ou rien.**
- **34 en parallèle de 31** : guardrails protègent les phases suivantes. Peut shipper avant 32/33.
- **32 ∥ 33 en parallèle** : disjoint concerns (cartographie vs kill-switch). Mais **lefthook de 34 doit être en place avant les deux**.
- **35 après 31+32+33** : dogfood a besoin oracle + carte + kill-switches.
- **36 dernier** : finissage utilise tous les outils précédents. **Budget 2-3 sem MINIMUM, non-empruntable.**

**Edge critique** : **34.1 (lefthook install) → 34.3 (bare-catch lint actif) → 36.4 (fix 388 catches)**. Sans le lint qui bloque les nouveaux catches AVANT la migration, converger à 0 = moving target (agents introduisent 3 catches pendant qu'on en fixe 5).

---

## 7. Watch Out For (top 10 pitfalls)

Deep-dive [PITFALLS.md](PITFALLS.md) — 36 pitfalls phase-specific + 4 meta.

1. **PII leak Sentry Replay** (A1) — `maskAllText` désactivé accidentellement sur un screen sensible = violation nLPD + LSFin art. 7-10. **Audit manuel PII redaction AVANT flip prod flag**, artefact `.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md` obligatoire.
2. **Déjà-vu pattern** (G1) — v2.4 "Fondation", v2.6 "Coach Qui Marche", v2.7 "Stabilisation" tous censés finir → v2.8 risque devenir prélude v2.9. **Kill-policy écrite PROJECT.md AVANT Phase 31** : "si v2.8 échoue, on kill features, on ne crée pas v2.9 stabilisation".
3. **Budget tilt vers 31-34** (G2) — dashboards séduisants, 35-36 délivrent user-visible. **Budget dur par phase, Phase 36 non-empruntable.**
4. **Dogfood fatigue** (E1) — mourir en 2 semaines sans discipline. **Hard-cap 10 min, creator-device weekly reste gold standard.**
5. **Flag rot** (C4) — 20 flags v2.8 → 100 en 6 mois → 0 jamais supprimés = nouveau code mort. **Expiration date + owner + monthly cleanup obligatoires.**
6. **Auto-migration 388 catches dangereuse** (F2) — script auto `logger.error + rethrow` casse fallback UX intentionnels. **Classification-first + batched 20/PR + flag rollback par batch.**
7. **`--no-verify` abuse** (D2) — gates théâtre si lefthook >10s. **Cible <5s absolu, monitor via post-commit hook, alerte si >3/sem → gate trop strict.**
8. **Screen board qui ment** (B1) — "last verified" stale → signal pollué. **Auto-refresh nightly, alerte si >7j, fail CI si snapshot >14j.**
9. **Scope creep "fix + add"** (G3) — user voit route jaune → demande nouvelle feature → milestone dérive. **Règle 0 feature nouvelle scellée par ADR + décision écrite.**
10. **Over-instrumentation** (A6) — si tout tracké, rien actionnable. **5-10 user journeys critiques instrumentés finement, reste default rates.**

---

## 8. Meta-decisions à sceller AVANT Phase 31

Non-négociables, à écrire dans PROJECT.md Key Decisions avant le premier commit de code :

- **Kill-policy** : "Si v2.8 exits unmet, on kill features, on ne crée pas v2.9 stabilisation." → ADR
- **Budget dur par phase** (solo-dev cadence v2.4-v2.7) :
  - Phase 31 : 1.5 sem
  - Phase 34 : 1.5 sem (parallèle 31)
  - Phase 32 : 1 sem
  - Phase 33 : 1 sem (parallèle 32)
  - Phase 35 : 1 sem
  - **Phase 36 : 2-3 sem MINIMUM, non-empruntable**
- **Sentry Replay PII redaction audit artefact obligatoire** avant flip prod flag sessionSampleRate>0
- **1 dashboard consolidé** `/admin/health` (pas 5-7 surfaces séparées) — measurement tyranny = tout mesurer ≠ tout améliorer
- **Binary-per-route flags seulement** (pas cohort/percentage, complexité inutile pour MINT solo)
- **Redirects legacy : instrumenter analytics Phase 32, sunset v2.9+ après 30-day zero-traffic validation** (PAS suppression v2.8)

---

## 9. Open questions pour roadmapper/planner

À résoudre day-1 de chaque phase (pas blocker research, mais pre-coding check) :

- **Phase 31 D1** : Sentry pricing fresh fetch (sentry.io/pricing — training data stale)
- **Phase 31 D2** : Railway/Cloudflare header propagation test — `curl -H "sentry-trace: xxx" mint-staging.up.railway.app/health` → le header survit-il ?
- **Phase 31 D3** : HTTP client exact dans [apps/mobile/lib/services/api_service.dart](apps/mobile/lib/services/api_service.dart) — `http` vs Dio vs custom (conditionne A.4 approach)
- **Phase 31 D4** : Sentry EU data residency confirmée dans org settings (nLPD bloquant)
- **Phase 32 D5** : GCS bucket vs Sentry attachments pour screenshots (decision Phase 32 day 1)
- **Phase 34 D6** : `.claude/agent-proof.json` writer existe-t-il ? Si non, Phase 34.6 ship le writer ensemble
- **Phase 36 D7** : `responseMeta.profileInvalidated` field dans canonical OpenAPI — verify avant planning P0-SAVEFACT
- **Pre-milestone** : Redirect 30-day dark period — démarrer Phase 32 entry ou Phase 31 (earlier = plus de data window Phase 36)

---

## 10. Fintech SF precedent (1 ligne par phase)

| Phase | Precedent | Source |
|-------|-----------|--------|
| 31 Replay | **Cash App / Block** Session Replay mobile | Sentry case study 2024 + Block engineering blog |
| 31 Trace_id | **Stripe Atlas mobile → API** distributed tracing, **Ramp iOS MTTR** | Sentry case studies |
| 31 Error boundary | **Stripe Issuing iOS**, **Brex mobile** | industry-standard post-2023 (MEDIUM confidence) |
| 32 Registry-as-code | **Linear** staff-email-gated debug routes | engineering talks (LOW confidence specifics) |
| 33 Home-grown flags | **Monzo `flipr`** (Go), **Stripe `flagon`** (interne) | published references |
| 34 lefthook | **JAX (Google)** migration mars 2026, **Evil Martians** | `jax-ml/jax#32846`, author portfolio |
| 34 Custom lints | **Ramp** pre-commit, **Stripe `dirtytree`** | engineering blog 2024, 2019 OSS |
| 35 Dogfood bot | **Cash App "shakebot"**, **Airbnb first-run tour**, **Linear Friday** | QCon 2023, public blogs |
| 36 Bare-catch cleanup | **Stripe** "no silent swallows" linter | engineering blog 2022 |

---

## Confidence

| Domaine | Niveau | Gap |
|---------|--------|-----|
| Stack versions | **HIGH** | Vérifiés pub.dev / PyPI / GitHub 2026-04 |
| Architecture intégrations | **HIGH** | Cross-vérifié fichier par fichier codebase réel |
| Features périmètre | **HIGH** | Chiffres codebase (147 routes, 12 gates, 388 catches, 52 redirects) |
| Pitfalls MINT-specific | **HIGH** | Grounded MEMORY.md, PROJECT.md, doctrine (no_shortcuts, facade_sans_cablage) |
| Pitfalls attribution fintech | **MEDIUM** | Practices internes HIGH, sources externes training-data based |
| Sentry pricing/quotas | **LOW** | Fresh fetch day-1 Phase 31 obligatoire |
| Railway/Cloudflare proxy behavior | **LOW** | Test curl staging avant A.4 coding |

**Overall : MEDIUM-HIGH.** Les 2 LOW sont des vérifications <30 min à faire avant tout codage sur les sujets concernés.

**Ready for roadmap.** 4 research files + SUMMARY.md disponibles. Roadmapper peut procéder à la définition des requirements et du roadmap phases 31-36.
