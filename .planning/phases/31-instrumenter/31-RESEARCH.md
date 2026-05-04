# Phase 31 : Instrumenter — Research

**Researched:** 2026-04-19
**Domain:** Observabilité mobile + backend Swiss fintech — Sentry Flutter 9.14.0 Session Replay, global error boundary 3-prongs, trace_id round-trip mobile↔backend via `http: ^1.2.0` headers, GoRouter navigation observer, breadcrumbs custom, PII redaction audit nLPD, Sentry quota/budget.
**Confidence:** HIGH sur versions (vérifiées STACK.md 2026-04-19 + pub.dev + PyPI) et sur le code actuel (lu en direct). MEDIUM sur Sentry tier/pricing (doit être refetché par OBS-07 — training data stale). MEDIUM sur le comportement des proxies Railway/Cloudflare avec `sentry-trace` (doit être vérifié end-to-end par OBS-04).

---

## User Constraints (from upstream scope, pré-CONTEXT.md)

> Phase 31 n'a PAS encore de CONTEXT.md (attendu après discuss-phase). Les contraintes ci-dessous viennent de : (a) roadmap/STATE/REQUIREMENTS, (b) décisions CTX-05 déjà scellées, (c) ADR kill-policy v2.8, (d) pitfalls research déjà committés. Elles se comporteront comme des "locked decisions" pour le planner tant que le discuss-phase ne les contredit pas.

### Locked decisions (préalables scellés)

1. **OBS-01 est DÉJÀ SHIPPED** via spike CTX-05 (merge `0d86d215`). `sentry_flutter: 9.14.0` pinned dans `pubspec.yaml` L29, `SentryWidget` + `options.replay.{sessionSampleRate=0.05, onErrorSampleRate=1.0}` + `options.privacy.{maskAllText=true, maskAllImages=true}` + `options.tracePropagationTargets` narrow-list actifs dans `main.dart` L111-142. **Phase 31 commence à OBS-02**, pas OBS-01. OBS-01 = "verify only, no code change" (confirmer aucune regression depuis CTX-05).
2. **Pas de migration Dio** (STACK.md §A.4 Option 1 retenu). Les headers `sentry-trace` + `baggage` sont ajoutés manuellement sur le `http: ^1.2.0` existant. `sentry_dio` est explicitement OBS-v9-01 (deferred v2.9+).
3. **Pas d'OpenTelemetry backend**. Sentry Performance seul tracing stack (REQUIREMENTS L151, STACK.md §B.2). `opentelemetry-*` = OBS-v9-02 (deferred).
4. **Error boundary = pattern 3-prongs, PAS `runZonedGuarded`**. Requirement OBS-02 explicite. Pattern vérifié Stripe/Brex industry post-2023.
5. **nLPD masks non-négociables** : `maskAllText=true` + `maskAllImages=true` doivent rester true en prod. Toute dé-masquage per-screen = finding nLPD bloquant (A1 PITFALLS.md).
6. **OBS-06 artefact est un gate bloquant** : flip `sessionSampleRate > 0` en prod interdit tant que `.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md` pas committé avec écrans sensibles (CoachChat, DocumentScan, ExtractionReviewSheet, Onboarding, Budget) audités sur simulateur. Kill-gate ROADMAP.md L84.
7. **Auto profile L3 obligatoire** (ADR-20260419-autonomous-profile-tiered) — `tools/simulator/walker.sh` simctl gate par task UI + `gsd-ui-review` + `gsd-secure-phase` (OBS-06 PII audit) + creator-device gate Julien manuel **non-skippable**.
8. **J0 sub-livrable : `tools/simulator/walker.sh`** (ROADMAP.md L171). Primitive shell subset de Phase 35 dogfood, réutilisable par 31/32/33/34/36. Ship J0 Phase 31.
9. **Budget : 1.5 sem (≈7j solo)**. Emprunt possible **de** Phase 34 uniquement (ROADMAP.md table). Hard-cap G2 PITFALLS : 1.5 sem max, sinon cut scope.
10. **Trace_id backend existant à préserver** : `LoggingMiddleware` génère déjà un `uuid4()` par requête + header `X-Trace-Id` sortant (`services/backend/app/core/logging_config.py:85-103`). OBS-03 doit **étendre** ce flow (lire `sentry-trace` inbound, propager `sentry_event_id` dans JSON body), **sans casser** l'UUID local quand le header Sentry est absent.

### Claude's Discretion (le planner décide)

- Ordonnancement exact OBS-02 → OBS-07 à l'intérieur des 7 jours (séquentiel vs partiellement parallélisable)
- Découpage en N plans (recommandation §Primary : 3 plans en 2 waves, voir §Architecture)
- Wording exact du `error_boundary.dart` (fichier nouveau centralisé)
- Format exact du breadcrumb custom (category naming, data keys) — sera raffiné par expert panel
- Structure markdown exacte de `SENTRY_REPLAY_REDACTION_AUDIT.md` et `observability-budget.md` (tant que les gates sont couverts)
- Choix des 5 critical journeys named transactions (A6 PITFALLS) — recommandation §Architecture

### Expert panel needed BEFORE plans (cf. §Decisions needing panel review)

Six décisions structurantes attendent un panel d'experts avant lock CONTEXT.md :

1. `sessionSampleRate` production target (0.05 vs 0.10 vs adaptive vs staged cohort)
2. DSN strategy (1 project tags env vs 2 projects staging/prod séparés)
3. Event + breadcrumb naming convention (systematic schema vs free-form)
4. Quota budget ceiling (€/mois target à 5k users)
5. Trace_id propagation header (`sentry-trace` only vs `sentry-trace` + `traceparent` W3C fallback vs custom `X-MINT-Trace-Id` belt-and-suspenders)
6. PII redaction scope (mask-by-default current vs allow-list explicit vs hybride `SentryMask` wrapper autour `CustomPaint`)

### Deferred Ideas (OUT OF SCOPE Phase 31)

- Migration `http` → `dio 5.9.0` + `sentry_dio 9.14.0` → **OBS-v9-01 v2.9+**
- OpenTelemetry FastAPI instrumentation → **OBS-v9-02 v2.9+**
- Screenshot pixel diffing → **OBS-v9-03 v2.9+**, Phase 35 defer anyway
- Circuit breaker auto-off Sentry-threshold → **DIFF-01 descopable**
- Custom spans sur 4 appels LLM → **DIFF-08 descopable**
- Replay auto-tuning sampleRate selon métriques live → **DIFF-06 defer v2.9**
- Performance budget par route LCP/TTI → **DIFF-09 defer v2.9**
- Datadog RUM / LogRocket / Amplitude / PostHog / FullStory — **BANNED** (PROJECT.md L49, nLPD single-vendor)
- `runZonedGuarded` wrapper — **BANNED** (zone mismatch sentry_flutter 9.x)
- Sentry auth tokens ou DSN committés en git — jamais. `--dart-define=SENTRY_DSN=` via secrets CI only (.github/workflows/testflight.yml:213 pattern existant).

---

## Phase Requirements

| ID | Description (REQUIREMENTS.md L47-53) | Research Support |
|----|--------------------------------------|------------------|
| **OBS-01** | `sentry_flutter 9.14.0` + Session Replay + `maskAllText` + `maskAllImages` + `sessionSampleRate=0.05` + `onErrorSampleRate=1.0` | §A.1 — **DÉJÀ SHIPPED via CTX-05** — verify only task (audit main.dart L111-142 + confirm 0 regression) |
| **OBS-02** | Global error boundary 3-prongs (`FlutterError.onError` + `PlatformDispatcher.instance.onError` + `Isolate.current.addErrorListener`) — PAS `runZonedGuarded` | §A.2 — pattern exact + single-source-file discipline + ordering smoke test |
| **OBS-03** | Global exception handler FastAPI fail-loud — `trace_id` + `sentry_event_id` dans JSON body + header `X-Trace-Id` sortie, backward-compat `LoggingMiddleware` | §B.1 — extend `services/backend/app/main.py:169-180`, préserver UUID fallback du `LoggingMiddleware` |
| **OBS-04** | Trace_id round-trip mobile→backend via headers `sentry-trace` + `baggage` sur `http: ^1.2.0` | §A.4 — `ApiService._authHeaders()` intercept + real-HTTP test staging (pas mock) + proxy A4 pitfall |
| **OBS-05** | `SentryNavigatorObserver` sur GoRouter (observer existant `AnalyticsRouteObserver`) + breadcrumbs custom (ComplianceGuard, save_fact, FeatureFlags.refreshFromBackend) | §A.3 + §A.5 — 3 insertion sites identifiés + allowlist policy (A6 over-instrument pitfall) |
| **OBS-06** | Artefact `SENTRY_REPLAY_REDACTION_AUDIT.md` committed AVANT flip `sessionSampleRate>0` prod — 5 écrans sensibles audités simulateur | §A.1 + §C — protocole audit step-by-step, scope exact (5 screens + all `CustomPaint`) |
| **OBS-07** | Artefact `observability-budget.md` — Sentry tier/pricing fresh, quota replay, events/mois ~5k users, staging vs prod DSN séparés | §D — protocole fresh fetch + projection quota + DSN strategy (panel decision) |

---

## Summary

Phase 31 transforme MINT d'une app "aveugle avec Sentry 10% tracesSampleRate" en **oracle diagnostic < 60s** : crash backend → `sentry-trace` inbound → `sentry_event_id` retourné → mobile affiche `ref #abc123` → Julien click-through vers le replay Sentry lié cross-project. Les 7 REQs forment un pipeline unique "un event mobile est câblé end-to-end au backend et inversement".

Le spike CTX-05 a déjà livré OBS-01 (le plus risqué côté infra : bump SDK 8→9 + masks nLPD + SentryWidget). **Phase 31 = 6 REQs restants + 1 verify**. Le reste est du câblage discipliné — pas de bump SDK, pas de nouveau vendor, pas de feature produit.

**Primary recommendation — ordre d'exécution proposé (3 plans, 2 waves, J0 subset) :**

- **J0 (≤0.5j, shared infra)** — `tools/simulator/walker.sh` minimal primitive (boot iPhone 17 Pro, install, launch, screenshot, read Sentry `sentry-cli api` last 15 min). Livré AVANT tout code OBS — sert de gate manuel post-plan pour Phases 31-36.
- **Plan 31-00 (wave 0, ~0.5j)** — Test scaffolding + `SENTRY_PRICING_2026_04.md` fresh fetch (OBS-07 prerequisite) + 5 critical journeys decision (`.planning/research/CRITICAL_JOURNEYS.md`) + audit stub `SENTRY_REPLAY_REDACTION_AUDIT.md`.
- **Plan 31-01 (wave 1, ~3j)** — Mobile error boundary 3-prongs (OBS-02) + Sentry breadcrumbs custom + `SentryNavigatorObserver` ajout à `AnalyticsRouteObserver()` existante (OBS-05) + `ApiService` header propagation `sentry-trace` + `baggage` (OBS-04 mobile-side) + `flag-disabled` route stub (cross-phase anticipation, optional).
- **Plan 31-02 (wave 2, ~2j)** — Backend `global_exception_handler` extend (OBS-03) + `LoggingMiddleware` coordinate (ne pas overwrite `X-Trace-Id` existant) + backend-side OBS-04 real-HTTP test staging + `observability-budget.md` commit (OBS-07) + `SENTRY_REPLAY_REDACTION_AUDIT.md` walkthrough simulateur 5 screens (OBS-06).
- **Gate (~1j)** — `tools/simulator/walker.sh` creator-device walkthrough Julien manuel + flip `sessionSampleRate=0.05` en prod (post audit signed).

**Buffer compression** : 0.5j reste pour fixes imprévus (proxy Railway A4 pitfall, macOS Tahoe simctl flake E6). Si hard-cap 1.5 sem hit → descope DIFF-07 (breadcrumb custom ComplianceGuard) au strict minimum. Jamais descope OBS-06 audit (kill-gate).

---

## Standard Stack

### Core (pré-existant, on étend)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `sentry_flutter` | **9.14.0** (exact pin) | Mobile SDK + Session Replay + propagation | Déjà pinned via CTX-05 spike. Replay GA depuis 9.0 (juin 2025). Vit dans package principal, 0 extra dep. `[VERIFIED: apps/mobile/pubspec.yaml:29]` `[VERIFIED: STACK.md §A.1 pub.dev 2026-04-19]` |
| `sentry-sdk[fastapi]` | `>=2.0.0,<3.0.0` **→ tighten à `==2.53.0`** | Backend SDK + FastAPI integration | Auto-lit `sentry-trace` + `baggage` headers inbound. 0 modif code backend pour cross-project link. `[VERIFIED: services/backend/pyproject.toml:27 + STACK.md §A.4 + §B.1]` `[CITED: docs.sentry.io/platforms/python/tracing/distributed-tracing/]` |
| `http` | `^1.2.0` | HTTP client mobile | On garde — pas de migration Dio. Headers injectés manuellement dans `ApiService._authHeaders()`. `[VERIFIED: apps/mobile/pubspec.yaml:16]` |
| `go_router` | `^13.2.0` | Routing mobile | **NE PAS bumper à 14.8.1 en Phase 31** — ROADMAP Phase 33 owns le bump FLAG-02 refresh listenable. Phase 31 installe juste `SentryNavigatorObserver` à côté de `AnalyticsRouteObserver` existant. `[VERIFIED: pubspec.yaml:18 + apps/mobile/lib/app.dart:173]` |

### Supporting (nouveau, Phase 31)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `sentry-cli` | **2.43.0** | OBS-07 Sentry usage/pricing fresh pull + J0 walker.sh pull events last 15 min | `curl -sL https://sentry.io/get-cli/ \| bash`. Auth `SENTRY_AUTH_TOKEN` via macOS Keychain. `[VERIFIED: STACK.md §D.3]` `[CITED: docs.sentry.io/cli/configuration/]` |
| `xcrun simctl` | Xcode 16.x ships with macOS | J0 `walker.sh` boot/install/launch/screenshot | Apple officiel, 0 dep. Documenté `feedback_ios_build_macos_tahoe.md` — NEVER `flutter clean`, NEVER delete `Podfile.lock`. `[VERIFIED: STACK.md §D.1]` |

**Installation commands (J0 + plans):**

```bash
# J0 — walker.sh primitive (mandatory)
brew install sentry-cli@2.43.0     # idempotent, 40MB binary
# xcrun simctl already present (Xcode required for iOS dev)

# Mobile — already wired
# sentry_flutter 9.14.0 already in pubspec (CTX-05 spike)
cd apps/mobile && flutter pub get && cd ios && pod install --repo-update
# NEVER flutter clean, NEVER delete Podfile.lock (feedback_ios_build_macos_tahoe)

# Backend — tighten pin in Plan 31-02
cd services/backend && python3 -m pip install -e .
# After pyproject.toml: sentry-sdk[fastapi]==2.53.0 (pin exact)
```

**Version verification (must run in Plan 31-00) :**

```bash
# Freshly verify versions before committing plans
curl -s https://pub.dev/api/packages/sentry_flutter | python3 -c "import json,sys;d=json.load(sys.stdin);print('sentry_flutter latest:',d['latest']['version'])"
curl -s https://pypi.org/pypi/sentry-sdk/json | python3 -c "import json,sys;d=json.load(sys.stdin);print('sentry-sdk latest:',d['info']['version'])"
```

STACK.md 2026-04-19 a vérifié `sentry_flutter 9.14.0` et `sentry-sdk 2.53.0` — refresh au Plan 31-00 recommandé (± 1 patch).

### Alternatives Considered

| Instead of | Could Use | Rejection Reason |
|------------|-----------|------------------|
| Manual `sentry-trace` headers | `sentry_dio 9.14.0` + `dio 5.9.0` migration | Rewrite `ApiService` retry/401 = 2-3j risque zero-value sur milestone "0 feature nouvelle". Defer v2.9+ (OBS-v9-01). STACK.md §A.4 Option 2 rejeté. |
| `SentryNavigatorObserver` seul | Replace `AnalyticsRouteObserver` | Casserait analytics existante. Solution : **add à côté** dans `observers: [AnalyticsRouteObserver(), SentryNavigatorObserver()]`. Les deux cohabitent (chacun son rôle). |
| Manual breadcrumbs partout | Sentry auto-instrumentation only | Auto-instrumentation ne connaît pas `ComplianceGuard` / `save_fact` / `FeatureFlags.refresh` — ce sont des surfaces **métier** critiques. Custom breadcrumbs sur allowlist = signal, pas bruit (A6 pitfall). |
| `sentry-trace` only | + `traceparent` W3C fallback + `X-MINT-Trace-Id` custom | A4 pitfall — Railway edge/Cloudflare peuvent strip. Belt-and-suspenders recommandé mais CHOIX DE PANEL (voir §Decisions #5). |
| `mask_all_text=False` per-screen | Default-deny + `SentryUnmask` chirurgical | A1 critical — toute dé-masquage = finding nLPD. Seule exception acceptable : logos non-sensibles dans un `SentryUnmask` boundary documenté. |

---

## Architecture Patterns

### Recommended project structure (additions Phase 31)

```
# Mobile
apps/mobile/lib/
  services/
    error_boundary.dart               # NEW — OBS-02 single entry for Sentry.captureException
    sentry_breadcrumbs.dart           # NEW — OBS-05 central breadcrumb helper (3 call sites)
    api_service.dart                  # EDIT — OBS-04 inject sentry-trace + baggage in _authHeaders()
  main.dart                           # EDIT — wire error_boundary BEFORE SentryFlutter.init()
  app.dart                            # EDIT L173 — add SentryNavigatorObserver to observers list

# Backend
services/backend/
  app/main.py                         # EDIT L169-180 — extend global_exception_handler
  app/core/logging_config.py          # EDIT — respect sentry-trace inbound avant generate uuid4
  pyproject.toml                      # EDIT L27 — tighten sentry-sdk[fastapi]==2.53.0

# Planning / artefacts (governance)
.planning/research/
  SENTRY_PRICING_2026_04.md           # NEW (OBS-07 prereq) — fresh fetch pricing page
  SENTRY_REPLAY_REDACTION_AUDIT.md    # NEW (OBS-06 kill gate) — 5 screens × masked verified
  CRITICAL_JOURNEYS.md                # NEW (A6 mitigation) — 5 named transactions allowlist
  TRACE_PROPAGATION_TEST.md           # NEW (A4 mitigation) — real curl staging proof
.planning/
  observability-budget.md             # NEW (OBS-07) — tier/quota/events/DSN strategy

# Tooling (J0 livrable)
tools/simulator/
  walker.sh                           # NEW J0 — simctl boot/install/launch/screenshot + sentry-cli pull
  README.md                           # NEW — how to operate, macOS Tahoe caveats
tools/checks/
  sentry_capture_single_source.py     # NEW — grep ban on Sentry.captureException outside error_boundary.dart (A3 mitigation)
```

### Pattern 1 — Single-source error boundary (OBS-02, A3 mitigation)

**What:** Exactement UN fichier wire les 3 handlers Sentry. Tout autre code qui capture une exception doit passer par ce fichier (pas d'appel direct à `Sentry.captureException` ailleurs).

**When to use:** Toujours. C'est la discipline qui empêche le double-logging (A3) et qui rend les 388 bare catches (Phase 36) migrable-en-batch sans casser l'instrumentation.

**Example:**

```dart
// apps/mobile/lib/services/error_boundary.dart
// Source: pattern STACK.md §A.2 + A3 PITFALLS.md single-source discipline

import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Install 3-prong global error boundary BEFORE SentryFlutter.init().
///
/// Contract:
/// - PlatformDispatcher.onError MUST be set before FlutterError.onError
///   (Flutter 3.3+ — sentry_flutter 9.x zone-mismatch otherwise)
/// - All captures go through this file — no Sentry.captureException elsewhere
///   (enforced by tools/checks/sentry_capture_single_source.py)
void installGlobalErrorBoundary() {
  // 1. Async platform errors (MethodChannel, uncaught futures, timers)
  //    — set FIRST per Flutter 3.3+ ordering requirement
  PlatformDispatcher.instance.onError = (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
    return true; // handled — framework may continue
  };

  // 2. Framework errors (build/layout/paint/RenderFlex)
  FlutterError.onError = (details) {
    FlutterError.presentError(details); // red screen in debug
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };

  // 3. Spawned isolates (compute(), async generators)
  Isolate.current.addErrorListener(RawReceivePort((pair) async {
    final errorAndStack = pair as List<dynamic>;
    await Sentry.captureException(
      errorAndStack.first,
      stackTrace: errorAndStack.last,
    );
  }).sendPort);
}

/// Single allowed swallow path — used by MintErrorScreen/fallback widgets
/// that render "something broke" surface to user. Event tagged to audit.
Future<void> captureSwallowedException(Object error, StackTrace stack, {String? surface}) {
  return Sentry.captureException(error, stackTrace: stack, withScope: (scope) {
    scope.setTag('swallowed', 'true');
    if (surface != null) scope.setTag('surface', surface);
  });
}
```

Wiring dans `main.dart` (après `WidgetsFlutterBinding.ensureInitialized()`, AVANT `SentryFlutter.init`) :

```dart
// apps/mobile/lib/main.dart — EDIT
WidgetsFlutterBinding.ensureInitialized();
installGlobalErrorBoundary(); // NEW — OBS-02, MUST be before SentryFlutter.init
// ... existing pre-init wiring ...
await SentryFlutter.init((options) { /* existing CTX-05 config */ },
                         appRunner: () => runApp(SentryWidget(child: const MintApp())));
```

### Pattern 2 — Manual header propagation via `http` (OBS-04, A4 mitigation)

**What:** Intercept `_authHeaders()` dans `ApiService` pour injecter `sentry-trace` + `baggage`. Chaque appel mobile→backend wrap par `Sentry.startTransaction(...)` pour que le span carrie un trace_id.

**When to use:** Toutes les méthodes HTTP publiques de `ApiService` (get / post / put / patch / delete). Env 20+ call sites, mais un seul endroit à patcher (`_authHeaders()`).

**Example:**

```dart
// apps/mobile/lib/services/api_service.dart — EDIT around L175
// Source: STACK.md §A.4 Option 1 — manual propagation, no Dio migration

import 'package:sentry_flutter/sentry_flutter.dart';

// Existing:
static Future<Map<String, String>> _authHeaders() async {
  final token = await AuthService.getToken();
  final headers = <String, String>{
    'Content-Type': 'application/json',
  };
  if (token != null) {
    headers['Authorization'] = 'Bearer $token';
  }

  // NEW — OBS-04 propagation
  // Span created for each request; ApiService caller unaware of Sentry.
  // Span.finish() happens implicitly via garbage collection OR caller
  // can wrap the request in its own transaction for nested spans.
  final span = Sentry.getSpan() ?? Sentry.startTransaction('api.request', 'http.client');
  final sentryTrace = span.toSentryTrace();
  final baggage = span.toBaggageHeader();
  headers['sentry-trace'] = sentryTrace.value; // "<traceId>-<spanId>-<sampled>"
  if (baggage != null) headers['baggage'] = baggage.value;

  return headers;
}
```

**Proxy test obligatoire (A4 mitigation)** — livrable `.planning/research/TRACE_PROPAGATION_TEST.md` :

```bash
# Verify in Plan 31-02 against staging (not localhost mock)
curl -i -X POST https://mint-staging.up.railway.app/api/v1/health \
  -H "Content-Type: application/json" \
  -H "sentry-trace: 12345678901234567890123456789012-1234567890123456-1" \
  -H "baggage: sentry-trace_id=12345678901234567890123456789012"

# Expected in response headers:
#   X-Trace-Id: 12345678901234567890123456789012   # NEW — Phase 31
#   (or new UUID if sentry-trace inbound was absent)
# AND in Sentry UI: backend transaction linked to trace_id 12345... cross-project
```

### Pattern 3 — `SentryNavigatorObserver` add, not replace (OBS-05)

**What:** `AnalyticsRouteObserver` est déjà dans la liste `observers:` de `GoRouter` (`app.dart:173`). On **ajoute** `SentryNavigatorObserver()` à côté — les deux cohabitent, chacun son rôle (analytics event stream vs breadcrumb Sentry).

**Example:**

```dart
// apps/mobile/lib/app.dart — EDIT L173
final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  observers: [
    AnalyticsRouteObserver(),        // EXISTING — analytics pipeline
    SentryNavigatorObserver(),       // NEW — OBS-05, auto-breadcrumbs on route push/pop
  ],
  initialLocation: '/',
  refreshListenable: _authNotifier,
  // ... rest unchanged ...
);
```

### Pattern 4 — Custom breadcrumb helper (OBS-05, 3 surface sites)

**What:** Helper centralisé pour les 3 surfaces business critiques. Category naming **systematic** (voir §Decisions #3 pour lock par panel).

**Example (skeleton — wording exact = panel review):**

```dart
// apps/mobile/lib/services/sentry_breadcrumbs.dart — NEW
// Source: STACK.md §A.3 + REQUIREMENTS OBS-05

import 'package:sentry_flutter/sentry_flutter.dart';

class MintBreadcrumbs {
  // ComplianceGuard validate result — 1 category, 2 outcomes
  static void complianceGuard({required bool passed, required String surface, List<String>? flaggedTerms}) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: 'mint.compliance.guard',
      level: passed ? SentryLevel.info : SentryLevel.warning,
      data: {
        'passed': passed,
        'surface': surface, // 'coach_reply' | 'premier_eclairage' | ...
        if (flaggedTerms != null) 'flagged_count': flaggedTerms.length,
        // NEVER include user content — PII risk (A1)
      },
    ));
  }

  // save_fact tool call — coach LLM tool
  static void saveFact({required bool success, required String factKind, String? errorCode}) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: 'mint.coach.tool.save_fact',
      level: success ? SentryLevel.info : SentryLevel.error,
      data: {
        'success': success,
        'fact_kind': factKind, // 'income' | 'housing' | 'family' — enum only, no values
        if (errorCode != null) 'error_code': errorCode,
      },
    ));
  }

  // FeatureFlags refresh outcome
  static void featureFlagsRefresh({required bool success, String? errorCode, int? flagCount}) {
    Sentry.addBreadcrumb(Breadcrumb(
      category: 'mint.feature_flags.refresh',
      level: success ? SentryLevel.info : SentryLevel.warning,
      data: {
        'success': success,
        if (errorCode != null) 'error_code': errorCode,
        if (flagCount != null) 'flag_count': flagCount,
      },
    ));
  }
}
```

**Call sites (à identifier dans Plan 31-01)** :
- `apps/mobile/lib/services/compliance_guard.dart` (méthode `validate()` — both pass + fail branches)
- `apps/mobile/lib/services/coach/coach_orchestrator.dart` (tool call `save_fact` — post-execution)
- `apps/mobile/lib/services/feature_flags.dart` (méthode `refreshFromBackend()` — success + catch)

### Pattern 5 — Backend global handler extension (OBS-03)

**What:** Étendre le handler existant `services/backend/app/main.py:169-180` pour lire `sentry-trace` inbound, propager `sentry_event_id` dans JSON body, et surfacer `X-Trace-Id` sortant. **Préserver backward compat** avec `LoggingMiddleware` existant (`services/backend/app/core/logging_config.py:85-103`) qui génère déjà un `uuid4()` + header `X-Trace-Id`.

**Key insight** : le `trace_id` lu du header `sentry-trace` (32-hex) est sémantiquement différent du `uuid4()` local de `LoggingMiddleware` (UUID v4). Il faut décider **lequel gagne** (voir §Decisions #5). Proposition par défaut : `sentry-trace` inbound remplace le UUID middleware pour ce cycle de requête (via `contextvars.ContextVar`).

**Example (cohabitation avec LoggingMiddleware) :**

```python
# services/backend/app/main.py — EDIT L169-180
# Source: STACK.md §B.1 + logging_config.py:85-103 existing pattern

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    # 1. Read inbound trace_id (Sentry-generated by mobile) — OBS-03 NEW
    raw_sentry_trace = request.headers.get("sentry-trace") or ""
    inbound_trace_id = raw_sentry_trace.split("-")[0] if "-" in raw_sentry_trace else None

    # 2. Fall back to LoggingMiddleware-generated UUID if no inbound
    from app.core.logging_config import trace_id_var
    trace_id = inbound_trace_id or trace_id_var.get("-")

    # 3. Capture in Sentry — backend SDK auto-joins via sentry-trace parsing
    event_id = None
    if settings.SENTRY_DSN:
        event_id = sentry_sdk.capture_exception(exc)

    # 4. Structured log (PII-safe — type name + truncated msg only, per FIX-077 existing)
    logger.error(
        "Unhandled %s: %.100s event_id=%s trace_id=%s",
        type(exc).__name__, str(exc), event_id, trace_id,
    )

    # 5. Fail-loud JSON body + sortie header
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Erreur interne du serveur",
            "error_code": "internal_error",
            "trace_id": trace_id,              # NEW — mobile affiche "ref #abc123"
            "sentry_event_id": event_id,       # NEW — click-through screenshot mobile
        },
        headers={"X-Trace-Id": trace_id or ""},  # NEW — complète LoggingMiddleware flow
    )
```

**Backward compat avec `LoggingMiddleware`** : le middleware fait `response.headers["X-Trace-Id"] = request_trace_id` (L102). Le handler 500 l'écrase avec le même `trace_id` — même valeur dans ~95% des cas (inbound seulement sur requêtes coach/chat/LLM qui wrap manuellement). Pas de conflit. Test à ajouter : `test_global_handler_preserves_logging_middleware_trace_id`.

### Anti-Patterns to Avoid (Phase 31-specific)

- **`runZonedGuarded` wrapper** — zone mismatch sentry_flutter 9.x. BANNED.
- **Direct `Sentry.captureException` outside `error_boundary.dart`** — enforce par `tools/checks/sentry_capture_single_source.py` (lefthook Phase 34).
- **Dé-masquage per-screen `SentryUnmask`** — nLPD finding. Seule exception : logos documentés.
- **`flutter clean` pendant build spike** — `feedback_ios_build_macos_tahoe.md`. BANNED.
- **`--dart-define=SENTRY_DSN=...` hardcodé dans commit** — doit passer via GitHub secret + `.github/workflows/*.yml` injection (pattern existant testflight.yml L202-213).
- **1 `sessionSampleRate>0` en prod sans `SENTRY_REPLAY_REDACTION_AUDIT.md`** — nLPD kill gate. BANNED sans artefact signé.
- **Named transactions créées à la volée** — chaque nouvelle transaction requires justification PR commit message `instrument: <journey_name>` (A6 mitigation).
- **Instrumentation de chaque `onTap` ou `provider_rebuild`** — signal drowned in noise (A6). Auto-instrumentation SDK seule pour UI events.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Error boundary 3-prongs | Custom Zone wrapper ou runZonedGuarded | `PlatformDispatcher.onError` + `FlutterError.onError` + `Isolate.addErrorListener` (Flutter SDK + dart:isolate) | sentry_flutter 9.x explicite reject runZonedGuarded (zone mismatch). 3-prongs = industry standard post-2023. `[CITED: STACK.md §A.2 + docs.sentry.io/platforms/dart/guides/flutter/]` |
| Trace_id generation mobile | UUID custom | `Sentry.startTransaction().toSentryTrace()` | SDK génère le 32-hex format compatible W3C subset (first segment) et backend SDK sait le lire auto. Éviter re-implem. `[CITED: docs.sentry.io/platforms/flutter/tracing/trace-propagation/]` |
| Backend cross-project link | Manually add trace_id to Sentry scope | `sentry-sdk[fastapi]` auto-reads `sentry-trace` + `baggage` | 0 modif backend code — la FastAPI integration parse les headers au request start. `[CITED: docs.sentry.io/platforms/python/tracing/distributed-tracing/]` |
| Breadcrumb navigation | Custom NavigatorObserver | `SentryNavigatorObserver()` | Maintained par Sentry, add to existing observers list. `[VERIFIED: sentry_flutter 9.x exports SentryNavigatorObserver]` |
| PII redaction CustomPaint | Custom WidgetsBinding.drawImage tap | `SentryMask` widget wrapper around `CustomPaint` | Official Sentry widget, mark tree branch as redacted. `[CITED: docs.sentry.io/platforms/dart/guides/flutter/session-replay/privacy/]` |
| Sentry quota monitoring | Custom scraper | `sentry-cli api /organizations/{org}/stats_v2/` | Official CLI 2.43.0, auth via env token. `[CITED: docs.sentry.io/cli/configuration/]` |
| Simulator automation | Custom Xcode Instruments scripting | `xcrun simctl` (Apple-bundled) + `sentry-cli api` | STACK.md §D.1 — simctl + idb fallback couvre 95%. Pas Patrol/Appium/Maestro (PROJECT.md L50). |

**Key insight:** Phase 31 est à 95% du **câblage discipliné** entre des SDK/outils officiels qui existent déjà. Le risque n'est pas technique, c'est la **façade-sans-câblage** : écrire `error_boundary.dart` sans vérifier qu'il ship effectivement capture une exception end-to-end via un test device (A3 pitfall). D'où le J0 livrable `tools/simulator/walker.sh` — permet de *prouver* le câblage avant de déclarer une REQ complete.

---

## Runtime State Inventory

> Phase 31 n'est **ni un rename ni un refactor**. Principalement du NEW code (error_boundary.dart, sentry_breadcrumbs.dart, 4 artefacts markdown) + des extensions in-place (ApiService._authHeaders(), global_exception_handler, pyproject.toml pin). Inventaire inclus pour cover A4 pitfall (proxy state) + OBS-07 DSN strategy.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| **Stored data** | **None relevant to Phase 31.** Sentry events/replay vivent sur Sentry SaaS (EU region, voir §Decisions #2). Pas de migration de DB locale. `drift.db` (CTX-02) et `memory/*.md` (CTX-01) hors scope. | Aucun |
| **Live service config** | **Sentry org settings** (server-side PII scrubbers, EU data residency, member allowlist) doivent être vérifiés AVANT flip prod `sessionSampleRate>0` (A1 mitigation step 4+5). Ces settings vivent dans Sentry UI, PAS dans git. **GitHub Actions secrets** `SENTRY_DSN_MOBILE` (déjà présent testflight.yml:202 + play-store.yml:122), `SENTRY_AUTH_TOKEN` (nouveau — pour OBS-07 fresh pull + J0 walker.sh + Phase 35 dogfood). | (1) Vérifier/screenshot les Sentry org settings dans `SENTRY_REPLAY_REDACTION_AUDIT.md` §4-5. (2) Ajouter `SENTRY_AUTH_TOKEN` à GitHub secrets + macOS Keychain dev host. |
| **OS-registered state** | **iOS simulator** (iPhone 17 Pro) state — walker.sh primitive doit `simctl shutdown all; simctl erase <uuid>; simctl boot <uuid>` pour état clean entre runs (E6 pitfall). macOS Tahoe quirks documentés `feedback_ios_build_macos_tahoe.md`. | Ship `tools/simulator/README.md` listant `simctl list devices` output attendu + workaround macOS Tahoe (NEVER flutter clean). |
| **Secrets/env vars** | `SENTRY_DSN` (existant backend Railway env var, 2 environnements staging + prod — voir §Decisions #2 pour single-project-with-env-tag vs two-projects decision). `SENTRY_DSN_MOBILE` (GitHub secret CI-only, injecté `--dart-define` pattern testflight.yml:213). **Nouveau** `SENTRY_AUTH_TOKEN` pour OBS-07 + J0. Pas de renommage, pas de rotation. | Plan 31-02 : (1) Documenter les 3 secrets dans `observability-budget.md` §DSN strategy. (2) Setup `SENTRY_AUTH_TOKEN` (~5 min : Sentry UI → Settings → Auth Tokens → scope `org:read project:read event:read`). |
| **Build artifacts** | **iOS Podfile.lock** — sentry_flutter 9.14.0 + Cocoapods déjà résolu post-CTX-05. Si bump patch 9.14.1 pendant Phase 31 → `cd ios && pod install --repo-update`, JAMAIS `rm Podfile.lock`. **Flutter lockfile** `.flutter-plugins-dependencies` — auto-regenerated, committer si diff post pub get. | Doctrine `feedback_ios_build_macos_tahoe.md` applicable ; pas d'action proactive requise tant que pubspec pas re-bumped. |

**Critical cross-session state to watch:**

- **Sentry billing cycle** — OBS-07 fresh fetch doit se faire AU MÊME MOMENT que la décision tier (panel #4). Pricing Sentry peut bouger en cours de Phase 31 ; documenter la date de fetch dans `SENTRY_PRICING_2026_04.md` + screenshot.
- **CI secrets propagation delay** — ajout d'un nouveau GitHub secret (`SENTRY_AUTH_TOKEN`) ne propage pas instant aux workflows en cours d'exécution. Pushed avant toute PR qui dépend de lui (OBS-07 quota pull).
- **Sentry project ID vs DSN** — DSN embed project ID. Si panel #2 décide 2 projets (staging + prod séparés), les workflows CI doivent fournir 2 secrets (ou 1 secret généré dynamiquement par environnement). Ce décision bloque Plan 31-02.

---

## Common Pitfalls (Phase 31-specific)

### Pitfall 1 — Sentry Replay PII leak via `CustomPaint` (A1 critical, nLPD kill-gate)

**What goes wrong:** `maskAllText=true` + `maskAllImages=true` ne couvrent PAS `CustomPaint` — et MINT utilise `CustomPaint` pour TOUS les charts (bars, rings, arbitrage side-by-side, retraite projections). Revenu 5'200 CHF rendu sur un CustomPaint → replay capture le pixel → Sentry reçoit PII lisible.
**Why it happens:** Sentry Replay Flutter supporte text tree + image tree, mais CustomPaint = canvas opaque. PITFALLS.md A1 §2 explicite.
**How to avoid:**
- Wrap *chaque* `CustomPaint` dans un `SentryMask(child: CustomPaint(...))` par défaut.
- Allowlist `SentryUnmask` **seulement** pour chrome non-sensible (logos MINT, spacers, dividers) avec commit message justifiant chaque cas.
- OBS-06 audit : `.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md` énumère chaque `CustomPaint` × statut "masked / unmasked justifié".
- Server-side PII scrubbers Sentry org settings (regex `CHF-\d+`, `756\.\d{4}\.\d{4}\.\d{2}` AVS, IBAN pattern) = belt + suspenders.
- **Flip `sessionSampleRate>0` en prod INTERDIT** tant que audit non signé commit.
**Warning signs:** Un dev review un replay staging sur laptop et LIT un nombre → same number exit device in prod. STOP.

### Pitfall 2 — Double-logging ou swallow silencieux (A3)

**What goes wrong:** `FlutterError.onError` → Sentry + un `catch { Sentry.captureException(e) }` existant → 2 events / erreur, quota × 2. Ou pire : refacto ajoute `catch (e) { logger.error(e) }` sans `rethrow` → erreur silenced in prod.
**Why it happens:** 388 bare catches actuels (Phase 36 target). Phase 31 instrumente AVANT que Phase 36 migre. Si on inverse, instrumentation capture du codebase avec black holes existants.
**How to avoid:**
- `error_boundary.dart` = seule source Sentry.captureException autorisée. Enforcé par `tools/checks/sentry_capture_single_source.py` grep (lefthook Phase 34).
- `captureSwallowedException(...)` avec tag `swallowed=true` = seule exception autorisée (fallback UI widgets "something broke").
- Ordering test : Dart unit qui mock `PlatformDispatcher.onError` + `FlutterError.onError`, vérifie ordre d'install + capture once + 0 swallow silencieux.
- **Phase 31 n'ajoute aucun nouveau bare catch** — explicite dans Plan 31-01 DoD.
**Warning signs:** Sentry inbound montre même erreur 2× dans 50ms avec différent stack mais même transaction_id → double-log en place.

### Pitfall 3 — Trace_id stripped by Railway / Cloudflare proxy (A4)

**What goes wrong:** Mobile envoie `sentry-trace: <32-hex>-<16-hex>-01`. Railway edge OR Cloudflare tier devant strip ou rename les headers non-standard. Backend ne voit rien → fresh `uuid4()` → mobile + backend events pas liés dans Sentry UI.
**Why it happens:** `sentry-trace` n'est PAS W3C standard (juste un subset du 1er champ). Proxies peuvent whitelist uniquement `traceparent`.
**How to avoid:**
- **Real-HTTP test staging (pas mock)** : `pytest` hit staging avec header `sentry-trace`, assert backend logs same trace_id. Commit output curl verbatim dans `TRACE_PROPAGATION_TEST.md` (A4 mitigation).
- **Fallback custom header** `X-MINT-Trace-Id` en parallèle du `sentry-trace` (voir §Decisions #5 — PANEL DECISION). Non-standard name = proxies savent pas strip.
- Optionnellement ajouter `traceparent` W3C en plus (panel decision).
- Breadcrumb structuré côté MINT log : `logger.info("coach_chat_send", trace_id=X)` — grep fallback si Sentry linking cassé.
**Warning signs:** Sentry Performance view montre mobile transaction `coach_chat_send` sans backend transaction linked. Bug Julien demande de chercher 2 projets Sentry par timestamp.

### Pitfall 4 — Sentry quota explosion after Replay flip (A2)

**What goes wrong:** `sessionSampleRate=0.05` sur 5k MAU = ~250 sessions replay/jour = ~7.5k/mois. Business plan ~500/mois inclus. Overage pricing silencieusement. Solo dev voit sur invoice.
**Why it happens:** Training data Sentry pricing = stale. Pricing change sans notice. `sessionSampleRate` seul ne suffit pas — il faut `replaysOnErrorSampleRate=1.0` (crash-driven) qui est non-sampled et peut exploser sur flaky period.
**How to avoid:**
- **OBS-07 fresh fetch MANDATORY** avant lock budget — `WebFetch https://sentry.io/pricing/` + screenshot + commit `.planning/research/SENTRY_PRICING_2026_04.md`.
- **Opt-in cohort** phase 1 : `sessionSampleRate=0.05` sur cohort `{internal, staging}` uniquement. Expand à prod `{prod}` seulement post audit OBS-06.
- **Spend-cap Sentry org** : 2× expected monthly, PAS unlimited.
- **Quota alarm** : cron/dogfood pull `sentry-cli api /organizations/{org}/stats_v2/?field=sum(quantity)` — alerte >70% avant J20 mois.
**Warning signs:** Sentry usage page >60% consumed avant J15 mois. Email billing alert.

### Pitfall 5 — `sentry_event_id` fuit dans user-facing message (compliance + UX)

**What goes wrong:** OBS-03 retourne `sentry_event_id` dans JSON body. Mobile UI l'affiche directement à l'utilisateur comme "ref #abc123...". Si l'ID contient des lettres qui forment un mot (improbable mais pas zero avec 32-hex), ou si format ressemble à "error code interne" effrayant → anti-shame doctrine violée.
**Why it happens:** `sentry_event_id` est un 32-hex UUID. Pas lisible, pas user-friendly.
**How to avoid:**
- Mobile UI affiche **les 8 premiers chars du `trace_id`** préfixés par "ref #" (ex: `ref #a1b2c3d4`). Tap → copie full trace_id dans clipboard pour support.
- Message d'erreur reste user-friendly : "Un souci est survenu. Si ça persiste, partage `ref #a1b2c3d4` avec Mint."
- **NE JAMAIS afficher** "Sentry event ID" ou "internal error code" — vocabulaire interne. Anti-shame doctrine MEMORY.md.
**Warning signs:** UI mockup montre "Error: abc123-def456-..." à la place de "ref #abc123".

### Pitfall 6 — Breadcrumb data fuit PII (A1 secondaire)

**What goes wrong:** `MintBreadcrumbs.complianceGuard(..., flaggedTerms: ['garanti', 'optimal'])` — si `flaggedTerms` contient des fragments de contenu user ("votre salaire est garanti par"...) → breadcrumb data contient PII. Breadcrumbs sont attachés à chaque event Sentry → leak.
**Why it happens:** Breadcrumbs sont `Map<String, dynamic>` — très facile d'y mettre du contenu user par réflexe.
**How to avoid:**
- **Doctrine dans `sentry_breadcrumbs.dart` header comment** : data keys acceptées = enum/int/bool SEULEMENT. Pas de string user-generated.
- Pour ComplianceGuard : `flagged_count: int` (pas `flagged_terms: List<String>`).
- Pour save_fact : `fact_kind: 'income' | 'housing' | ...` enum (pas `fact_value`).
- Unit test `sentry_breadcrumbs_pii_test.dart` : fuzz 100 breadcrumbs → assert data ne contient aucun pattern CHF-\d+, 756\.\d{4}, IBAN.
- `beforeBreadcrumb` callback dans `SentryFlutter.init` = dernière défense : filter out keys matchant `/salary|income|iban|avs/i`.
**Warning signs:** Review `sentry_breadcrumbs.dart` PR trouve un `data: {'message': userMsg}` → STOP, refactor en enum/count.

### Pitfall 7 — Over-instrumentation → signal drowned (A6)

**What goes wrong:** Chaque `onTap`, chaque provider rebuild, chaque API call devient un breadcrumb/event. 10M events/semaine. Julien ouvre Sentry, voit un mur, ferme.
**Why it happens:** Facilité d'ajouter `Sentry.addBreadcrumb(...)` partout + auto-instrumentation ajoute déjà beaucoup.
**How to avoid:**
- **5 critical journeys** lockées day 1 (`.planning/research/CRITICAL_JOURNEYS.md`) :
  1. `anonymous_onboarding` (landing → felt-state → coach MSG1 → premier éclairage)
  2. `coach_turn` (user → backend → LLM → tool → response)
  3. `document_upload` (camera/PDF → Vision → DUR → render)
  4. `scan_handoff_to_profile` (confirm chip → profile merged)
  5. `tab_nav_core_loop` (Aujourd'hui ↔ Coach ↔ Explorer)
- **Instrumentation manuelle seulement** sur ces 5 journeys. Tout le reste = Sentry auto-instrumentation (fine-grained non-named, low signal mais not noise-gen).
- **Lefthook rule Phase 34** : nouvelle `Sentry.startTransaction(name:)` avec `name` absent de `CRITICAL_JOURNEYS.md` require commit message `instrument: <journey>`.
- Consolidation dashboard Phase 32/33 (`/admin/health` G4 mitigation) — pas 7 surfaces séparées.
**Warning signs:** Sentry dashboard montre >1000 transaction names uniques OR top-10 by count = `provider_rebuild`/`route_push` (low-value) OR Julien dit "j'ai Sentry ouvert mais je regarde plus".

### Pitfall 8 — macOS Tahoe simctl flakiness cassant J0 walker.sh (E6)

**What goes wrong:** `simctl boot` freeze, `idb_companion` socket reset, walker.sh hang → creator-device gate bloqué, Plan 31-02 slip.
**Why it happens:** macOS Tahoe iOS build quirks déjà documentés `feedback_ios_build_macos_tahoe.md`. simctl + idb fragile à combinaison Xcode/simulator version.
**How to avoid:**
- **Hard timeout partout** : chaque `simctl` command wrap `timeout 30s`. Abort + report si step exceeds.
- **Clean state between runs** : `simctl shutdown all; simctl erase <sim_id>; simctl boot <sim_id>` — fresh sim chaque run.
- **NEVER `flutter clean`** pendant build. NEVER `rm Podfile.lock`.
- `tools/simulator/README.md` liste known-bad combos macOS × Xcode × simulator version (living doc).
- **Fallback creator-device manual** : si walker.sh flake 2 jours consécutifs → skip automation, Julien physique iPhone pour OBS-06 audit.
**Warning signs:** `walker.sh` runtime >5 min (budget 2 min). simctl processes accumulating dans `ps`. idb_companion log = socket reset errors.

### Pitfall 9 — Backend handler ne préserve pas LoggingMiddleware existant

**What goes wrong:** OBS-03 extend `global_exception_handler` mais overwrite le `X-Trace-Id` set par `LoggingMiddleware` (`logging_config.py:102`) avec une empty string quand `sentry-trace` inbound absent.
**Why it happens:** Naive implementation : `headers={"X-Trace-Id": trace_id or ""}` avec `trace_id=None` → header empty → middleware trace_id perdu.
**How to avoid:**
- Handler lit `trace_id_var.get("-")` depuis `contextvars` (déjà set par LoggingMiddleware) AVANT de décider fallback.
- Fallback priority : `inbound_sentry_trace` > `trace_id_var.get()` > `""` (dernier recours).
- Unit test : `test_global_handler_preserves_logging_middleware_trace_id` — assert header non-empty même quand inbound absent.
**Warning signs:** Requêtes sans `sentry-trace` header → réponse `X-Trace-Id:` empty. Test existant `LoggingMiddleware` cassé.

### Pitfall 10 — J0 walker.sh livré mais jamais exécuté par planner (façade-sans-câblage)

**What goes wrong:** `tools/simulator/walker.sh` committed avec README, mais aucun task Plan 31-01/02 ne l'invoque pour **prouver** qu'un event test round-trip. Phase 31 ship "verdict vert" sans jamais tester end-to-end.
**Why it happens:** Primitive shipped, consumer not wired. Doctrine #1 `feedback_facade_sans_cablage.md`.
**How to avoid:**
- **walker.sh DoD** : Plan 31-00 must include `bash tools/simulator/walker.sh --smoke-test-inject-error` qui déclenche un exception mobile staging → attend 60s → pull Sentry → assert event retrieved AVEC `sentry_event_id` present in response body AND backend transaction linked.
- **Gate script** `tools/simulator/walker.sh --gate-phase-31` = pre-verify DoD script invoqué par `/gsd-verify-phase`.
**Warning signs:** Phase 31 verify pass mais personne n'a cliqué "show replay" dans Sentry UI ever.

---

## Code Examples

### Example 1 — Mobile error boundary wiring (OBS-02)

Voir §Architecture Patterns — Pattern 1. Fichier `apps/mobile/lib/services/error_boundary.dart` single-source. Wire `installGlobalErrorBoundary()` dans `main.dart` AVANT `SentryFlutter.init(...)`.

Source: STACK.md §A.2 + A3 PITFALLS.md + `[CITED: docs.sentry.io/platforms/flutter/configuration/options/]`.

### Example 2 — Trace_id propagation header (OBS-04 mobile side)

Voir §Architecture Patterns — Pattern 2. Edit `apps/mobile/lib/services/api_service.dart:_authHeaders()`.

Source: STACK.md §A.4 Option 1 + `[CITED: docs.sentry.io/platforms/flutter/tracing/trace-propagation/]`.

### Example 3 — Backend global handler extension (OBS-03)

Voir §Architecture Patterns — Pattern 5. Edit `services/backend/app/main.py:169-180`. Préserve `LoggingMiddleware` existing.

Source: STACK.md §B.1 + `services/backend/app/core/logging_config.py:85-103` existing + `[CITED: docs.sentry.io/platforms/python/tracing/distributed-tracing/]`.

### Example 4 — `walker.sh` primitive J0 skeleton

```bash
#!/usr/bin/env bash
# tools/simulator/walker.sh — J0 primitive
# Subset of Phase 35 mint-dogfood.sh — 4 ops: boot, install, screenshot, sentry-pull
# Usage: walker.sh [--smoke-test-inject-error|--gate-phase-31|--quick-screenshot]
set -euo pipefail

DEVICE="${MINT_WALKER_DEVICE:-iPhone 17 Pro}"
BUNDLE="com.mint.mintMobile"
MODE="${1:---quick-screenshot}"
OUTDIR=".planning/walker/$(date +%Y-%m-%d-%H%M%S)"
mkdir -p "$OUTDIR"

# 1. Boot iPhone 17 Pro fresh
timeout 30s xcrun simctl shutdown all || true
timeout 30s xcrun simctl erase "$DEVICE" || true
timeout 30s xcrun simctl boot "$DEVICE"
open -a Simulator

# 2. Install + launch (staging always — feedback_app_targets_staging_always)
(cd apps/mobile && flutter build ios --simulator \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=SENTRY_DSN="$SENTRY_DSN_STAGING")
timeout 60s xcrun simctl install "$DEVICE" apps/mobile/build/ios/iphonesimulator/Runner.app
timeout 30s xcrun simctl launch "$DEVICE" "$BUNDLE"

sleep 5
timeout 10s xcrun simctl io "$DEVICE" screenshot "$OUTDIR/launch.png"

# 3. Mode dispatch
case "$MODE" in
  --smoke-test-inject-error)
    # Trigger a known staging error endpoint, wait 60s, pull Sentry
    curl -s -X POST https://mint-staging.up.railway.app/api/v1/_test/inject_error \
      -H "sentry-trace: $(openssl rand -hex 16)-$(openssl rand -hex 8)-1" \
      || true
    sleep 60
    sentry-cli api "/projects/mint/mint-backend/events/?statsPeriod=15m" \
      --auth-token "$SENTRY_AUTH_TOKEN" > "$OUTDIR/sentry-events.json"
    # Assert at least one event matches injected trace_id
    python3 tools/simulator/assert_event_round_trip.py "$OUTDIR/sentry-events.json"
    ;;
  --gate-phase-31)
    # Mini-suite: OBS-02 error boundary + OBS-04 round-trip + OBS-05 breadcrumb
    bash "$0" --smoke-test-inject-error
    # Additional checks Phase 31 specific...
    ;;
  --quick-screenshot)
    : # Already done above
    ;;
esac

echo "walker.sh: done → $OUTDIR"
```

Source: STACK.md §D.2 adapted + E6 PITFALLS.md timeouts + `feedback_ios_build_macos_tahoe.md` doctrine.

### Example 5 — `observability-budget.md` skeleton (OBS-07)

```markdown
# MINT v2.8 — Observability Budget

**Fetched:** 2026-04-XX (replace with real fetch date in Plan 31-02)
**Source:** https://sentry.io/pricing/ screenshot committed as `SENTRY_PRICING_2026_04.md`
**Target users:** ~5 000 MAU at v2.8 ship

## Sentry tier decision
- **Plan:** Business Tier ($80/mo) — rationale: Replay 500/mo included, cross-project linking, EU data residency
- **EU region:** mandatory (Swiss fintech, nLPD) — verified via Sentry org settings screenshot
- **Spend cap:** 2× monthly baseline = $160/mo — prevents silent overage

## DSN strategy (PANEL DECISION — see §Decisions #2)
- **Option A (chosen):** 1 Sentry project with `environment: staging|production` tag — single dashboard, single alert policy, separation via filter
- **Option B (alternative):** 2 separate projects (mint-staging, mint-production) — hard separation, 2× alerts to manage
- Decision recorded in `decisions/ADR-2026XXXX-sentry-dsn-strategy.md`

## Quota projection (5 000 MAU × monthly)
| Product | Sample rate | Volume | Quota | Overage cost |
|---------|-------------|--------|-------|--------------|
| Errors | 100% (crash) | ~2k/mo | Unlimited (Business) | $0 |
| Transactions (perf) | `tracesSampleRate=0.1` | ~50k/mo | 100k included | $0 |
| Replay (session) | `sessionSampleRate=0.05` | ~7.5k/mo | 500 included | ~$210 overage ← risk |
| Replay (on-error) | `onErrorSampleRate=1.0` | ~2k/mo | (Same replay quota) | Included in above |
| Profiling | `profilesSampleRate=0.1` | ~50k/mo | 100k included | $0 |

**Replay overage risk:** 7.5k projected > 500 included × ($0.30 overage replay). **PANEL DECISION #1** locks `sessionSampleRate` — 0.05 too high for 5k MAU, recommend 0.02 or cohort-gated.

## Sample rate reference
- `sessionSampleRate`: see Panel #1 decision (locked CONTEXT.md)
- `onErrorSampleRate`: `1.0` (crash-capture, non-negotiable)
- `maskAllText` / `maskAllImages`: `true` (nLPD, A1 kill-gate)
- `tracesSampleRate`: `0.1` (unchanged from existing, STACK.md)
- `profilesSampleRate`: `0.1` (aligned with traces, <5% frame budget impact)

## Alerting
- Monthly Sentry usage fetched by `tools/dogfood/mint-dogfood.sh` (Phase 35) — alert >70% quota before J20
- Day-5 calendar reminder Julien manual check
- Spend-cap auto-stops at $160 ceiling

## Revisit triggers
- MAU >10 000 → re-evaluate tier + sample rates
- >3 overage months → descope Replay to onErrorSampleRate only
- A1 critical found (PII leak) → flip sessionSampleRate=0 temporarily + audit
```

Source: STACK.md §A.1 sample rate rationale + A2 PITFALLS.md quota discipline + OBS-07 REQUIREMENTS.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact Phase 31 |
|--------------|------------------|--------------|-----------------|
| `runZonedGuarded(() => runApp(...), Sentry.captureException)` | 3-prong (`PlatformDispatcher.onError` + `FlutterError.onError` + `Isolate.addErrorListener`) | sentry_flutter 8.x → 9.x (juin 2025) | OBS-02 MUST use 3-prong. Legacy `runZonedGuarded` causes zone mismatch. |
| `sentry_flutter.options.experimental.replay.maskAllText` | `sentry_flutter.options.privacy.maskAllText` (+ `options.replay.*` owns sample rates only) | sentry_flutter 9.0 GA (juin 2025) | CTX-05 spike learning — `privacy.*` owns masks (not `experimental.replay.*`). Already correct in main.dart post-spike. |
| `SentryHttpClient` wrapper | Manual `span.toSentryTrace()` + `span.toBaggageHeader()` on `http: ^1.2.0` | sentry_flutter 9.x (no HTTP wrapper for `package:http`) | OBS-04 pattern STACK.md §A.4. `sentry_dio` exists for Dio but we don't migrate. |
| `options.tracePropagationTargets = .* (default)` | Narrow list `['api.mint.app', 'mint-staging.up.railway.app', 'mint-production.up.railway.app']` | Privacy + security best practice (leak to 3rd parties) | CTX-05 already applied. Phase 31 preserve. |
| Static `List<String>` assignment | `..clear()..addAll([...])` mutation pattern | sentry_flutter 9.14.0 API (`tracePropagationTargets` is `final List<String>`) | CTX-05 learning documented STATE.md. Pattern to preserve. |
| `send_default_pii=True` for rich context | `send_default_pii=False` + manual scope enrichment | nLPD + GDPR best practice | Already `False` in main.dart + backend main.py. Non-négociable. |

**Deprecated / no-touch Phase 31:**
- `SentryNavigatorObserver` monolithic replacement → use alongside `AnalyticsRouteObserver` (Pattern 3).
- `sentry-sdk[fastapi]` auto-instrumentation detects FastAPI routes — **0 manual decoration needed** for backend traces (STACK.md §B.1 + `[CITED: docs.sentry.io/platforms/python/integrations/fastapi/]`).

---

## Assumptions Log

> All claims tagged `[ASSUMED]` below. Discuss-phase + expert panel should verify before lock CONTEXT.md.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `sentry-sdk[fastapi] 2.53.0` auto-reads `sentry-trace` + `baggage` headers on every FastAPI request without explicit middleware | §B.1 + Stack table | Medium — if auto-integration misses, OBS-04 cross-project link breaks. Mitigation: `TRACE_PROPAGATION_TEST.md` real-HTTP test staging catches it in Plan 31-02. |
| A2 | Railway Cloudflare front-end does NOT strip `sentry-trace` header | §A.4 + Pitfall 3 | High — A4 pitfall exactly. Mitigation: real-HTTP test staging curl + optional `X-MINT-Trace-Id` fallback (panel decision #5). |
| A3 | Sentry pricing page will still list "Team $26/mo" + "Business $80/mo" at Phase 31 execution date | §D + observability-budget skeleton | Medium — Sentry changes pricing without notice. Mitigation: OBS-07 fresh fetch + screenshot commit. |
| A4 | `sessionSampleRate=0.05` + `onErrorSampleRate=1.0` combined quota fit Business tier for 5k MAU | Observability-budget table | Medium — projection ~7.5k replay/mo vs 500 included. Panel #1 + #4 must decide real sample rate. |
| A5 | `SentryNavigatorObserver()` + `AnalyticsRouteObserver()` in same `observers:` list don't conflict | §Architecture Pattern 3 | Low — both are `NavigatorObserver` subclasses, framework supports multiple. Verify by Plan 31-01 `app.dart` smoke test. |
| A6 | `http: ^1.2.0` package passes `headers` param from `.get(uri, headers: ...)` without normalizing/lowercasing non-standard header names like `sentry-trace` | §A.4 Pattern 2 | Low — `package:http` delegates to platform HTTP client which preserves header names. Verify by integration test in Plan 31-01. |
| A7 | `SENTRY_AUTH_TOKEN` scope `org:read project:read event:read` sufficient for OBS-07 quota pull + J0 walker.sh events pull | §Runtime State Inventory | Low — Sentry docs confirm these scopes cover `stats_v2/` + `events/` endpoints `[CITED: docs.sentry.io/api/auth/]`. Verify at secret creation. |
| A8 | Existing `AnalyticsRouteObserver` in `app.dart:173` is a `NavigatorObserver` subclass (not a custom hook) | §Architecture Pattern 3 | Low — class name suggests standard NavigatorObserver. Verify by reading `apps/mobile/lib/services/analytics_observer.dart` in Plan 31-00. |
| A9 | `options.privacy.maskAllText=true` + `options.privacy.maskAllImages=true` defaults propagate to Session Replay video capture (not just text field input masking) | §A.1 + Pitfall 1 | **HIGH — nLPD critical** — if only input masking, CustomPaint content visible. Mitigation: OBS-06 audit simulator step-by-step verification per screen. A1 kill-gate stands. |
| A10 | Phase 31 doesn't need `go_router` bump to 14.8.1 (STACK.md §F.1) — Phase 33 FLAG-02 owns that bump | §Standard Stack go_router row | Medium — if SentryNavigatorObserver requires go_router ≥14 for some API, Phase 31 blocks. Verify in Plan 31-00 `pub get` + smoke test. Fallback: Phase 31 includes go_router bump, Phase 33 inherits. |

**If an [ASSUMED] becomes [VERIFIED] during a plan, update this table + append status column.** 10 assumptions total — all should reach [VERIFIED] or [REFUTED] by end of Plan 31-02.

---

## Open Questions

1. **Cohort rollout strategy for Replay flip**
   - What we know: A2 pitfall recommends opt-in cohort (internal/staging first, expand to prod post audit). OBS-06 artefact is flip gate for prod.
   - What's unclear: **how** the cohort gate is implemented. Via FeatureFlags `sentry_replay_enabled_prod: bool` backend-controlled? Via dart-define at build time? Runtime check of user email allowlist?
   - Recommendation: FeatureFlags-backed cohort flag `sentryReplayEnabledForThisUser` — coordinate with Phase 33 FLAG-05. Default `false`, Julien flip to `true` post-OBS-06 sign.

2. **5 critical journeys — wording + exact transaction names**
   - What we know: A6 pitfall + STACK.md + REQUIREMENTS all reference "5 critical journeys". Recommendation provided in §Architecture Pattern 4 + Pitfall 7.
   - What's unclear: exact transaction name schema (panel decision #3). E.g., `mint.anonymous_onboarding` vs `anonymous_onboarding.flow` vs `flow.onboarding.anonymous`.
   - Recommendation: lock via panel before Plan 31-01 (breadcrumb categories AND transaction names share the schema).

3. **`traceparent` W3C support on mobile**
   - What we know: STACK.md §A.4 + requirements use `sentry-trace` only. W3C `traceparent` is the true cross-vendor standard.
   - What's unclear: does `Sentry.startTransaction(...)` Flutter 9.14.0 also emit a `traceparent` compatible header? OR we manually add it alongside?
   - Recommendation: Panel decision #5. If panel picks `sentry-trace` only, accept A4 proxy risk + mitigate via `X-MINT-Trace-Id` custom. If panel adds `traceparent`, extend Pattern 2 with 2nd header.

4. **Backend `/test/inject_error` endpoint — needed for J0 walker.sh smoke**
   - What we know: Pitfall 10 example 4 references `curl -X POST /api/v1/_test/inject_error`. This endpoint doesn't exist in backend.
   - What's unclear: ship this endpoint or rely on existing error conditions (e.g., malformed JWT on `/coach/chat`)?
   - Recommendation: ship a minimal `/test/inject_error` gated `--dart-define=ENABLE_TEST_ENDPOINTS=1` (staging only, never prod). Plan 31-00 scaffolding. Fallback: invalid payload on `/coach/chat` (existing).

5. **Pitch on retry behavior after error boundary capture**
   - What we know: OBS-02 3-prong + `captureException` + optional `rethrow`. Retry logic (auto-refresh token L197-229 existing, 401 retry L240-245 existing) is untouched.
   - What's unclear: if `PlatformDispatcher.onError` returns `true` (handled), does it swallow the error from the caller's perspective? Does retry logic still fire?
   - Recommendation: Verify in Plan 31-01 integration test: force a 401 on first call → assert `_tryRefreshToken` still runs → assert retry call succeeds → assert Sentry captured ONE event (not two). Document in `TRACE_PROPAGATION_TEST.md`.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `sentry_flutter` | OBS-01..05 mobile | ✓ | 9.14.0 (pinned CTX-05) | — |
| `sentry-sdk[fastapi]` | OBS-03 backend | ✓ | `>=2.0.0,<3.0.0` (needs tighten 2.53.0 Plan 31-02) | — |
| `sentry-cli` | OBS-07 + J0 walker.sh | ✗ | — | Install via `brew` (Plan 31-00 setup) |
| `xcrun simctl` | J0 walker.sh + OBS-06 audit | ✓ (assume Xcode 16.x on dev host) | (ship w/ Xcode) | Manual iPhone physique si simctl flake E6 |
| `SENTRY_DSN_MOBILE` GitHub secret | CI builds Replay in TestFlight/Play | ✓ | (existing `.github/workflows/testflight.yml:202`) | — |
| `SENTRY_DSN` backend Railway env var | OBS-03 + backend Sentry init | ✓ (staging + prod) | (existing) | Panel decision #2 may add 2nd DSN |
| `SENTRY_AUTH_TOKEN` for CLI/CI pulls | OBS-07 + walker.sh + Phase 35 dogfood | ✗ | — | Create via Sentry UI (Plan 31-00), store GH secret + macOS Keychain |
| `flutter_doc_scanner` (VisionKit) | OBS-06 audit DocumentScan screen | ✓ | `^0.0.13` (pubspec L38) | — |
| `http: ^1.2.0` | OBS-04 mobile | ✓ | `^1.2.0` (pubspec L16) | — |
| `go_router: ^13.2.0` | OBS-05 observers list | ✓ | `^13.2.0` (pubspec L18) | If SentryNavigatorObserver needs go_router≥14, Phase 31 bumps too (A10 risk) |
| Staging backend `mint-staging.up.railway.app` | OBS-04 A4 real-HTTP test + J0 walker | ✓ (healthchecked daily) | — | Localhost `uvicorn app.main:app --reload` pour dev-only |

**Missing dependencies with no fallback:**
- None.

**Missing dependencies with fallback:**
- `sentry-cli` — install by brew. Blocking only at Plan 31-02.
- `SENTRY_AUTH_TOKEN` — creation 5-minute step. Blocking at Plan 31-02.
- Additional Sentry project (si panel #2 pick option B 2-projects) — creation 10-minute step. Blocking at Plan 31-02.

---

## Validation Architecture

> `workflow.nyquist_validation` assumed enabled (v2.8 default). Validation per REQ below.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | **Flutter:** `flutter_test` (SDK) + `integration_test` (SDK) — `pubspec.yaml:62-63`. **Backend:** `pytest` 7.x — `services/backend/pytest.ini` existing. **Shell:** `bash` + `tools/simulator/walker.sh` + `sentry-cli api` JSON assertions via `python3 tools/simulator/assert_event_round_trip.py`. |
| Config file | Mobile: `apps/mobile/test/` + new `apps/mobile/integration_test/`. Backend: `services/backend/tests/` existing + new `services/backend/tests/test_global_exception_handler.py`. |
| Quick run command | `cd apps/mobile && flutter test test/services/error_boundary_test.dart test/services/sentry_breadcrumbs_test.dart test/services/api_service_sentry_trace_test.dart -r compact && cd ../../services/backend && python3 -m pytest tests/test_global_exception_handler.py -q` |
| Full suite command | `cd apps/mobile && flutter test && cd ../../services/backend && python3 -m pytest tests/ -q && bash tools/simulator/walker.sh --gate-phase-31` |
| Estimated runtime | ~45s mobile + ~30s backend + ~3min walker.sh = ~5 min full |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| **OBS-01** | `sentry_flutter 9.14.0` pinned + `SentryWidget` wrap + `maskAllText/Images=true` + sample rates set | audit (unit) | `python3 tools/checks/verify_sentry_init.py` (grep main.dart for pins) | ❌ Wave 0 |
| **OBS-02** (a) | `installGlobalErrorBoundary()` sets `PlatformDispatcher.onError` BEFORE `FlutterError.onError` | unit | `flutter test test/services/error_boundary_ordering_test.dart -x` | ❌ Wave 0 |
| **OBS-02** (b) | `Sentry.captureException` called exactly once per FlutterError | unit | `flutter test test/services/error_boundary_single_capture_test.dart -x` | ❌ Wave 0 |
| **OBS-02** (c) | Ban on direct `Sentry.captureException` outside error_boundary.dart | static | `python3 tools/checks/sentry_capture_single_source.py` | ❌ Wave 0 |
| **OBS-03** (a) | Global handler returns `trace_id` + `sentry_event_id` in 500 JSON body | unit | `pytest services/backend/tests/test_global_exception_handler.py::test_returns_trace_id -x` | ❌ Wave 0 |
| **OBS-03** (b) | Global handler preserves `X-Trace-Id` header from LoggingMiddleware when no inbound sentry-trace | unit | `pytest services/backend/tests/test_global_exception_handler.py::test_preserves_logging_middleware_trace_id -x` | ❌ Wave 0 |
| **OBS-03** (c) | Global handler reads inbound `sentry-trace` and uses that trace_id | unit | `pytest services/backend/tests/test_global_exception_handler.py::test_reads_inbound_sentry_trace -x` | ❌ Wave 0 |
| **OBS-04** (a) | `_authHeaders()` returns `sentry-trace` + `baggage` headers when Sentry span active | unit | `flutter test test/services/api_service_sentry_trace_test.dart -x` | ❌ Wave 0 |
| **OBS-04** (b) | Real-HTTP staging round-trip: inject trace_id mobile → assert backend response has matching `X-Trace-Id` | integration (real-HTTP) | `bash tools/simulator/trace_round_trip_test.sh` | ❌ Wave 0 |
| **OBS-04** (c) | Sentry UI cross-project link verified visually | **manual-only** | see Manual-Only §OBS-04 | n/a |
| **OBS-05** (a) | `SentryNavigatorObserver` listed in `observers:` of root `GoRouter` | unit | `flutter test test/app_router_observers_test.dart -x` | ❌ Wave 0 |
| **OBS-05** (b) | `MintBreadcrumbs.complianceGuard()` emits breadcrumb with correct category + non-PII data | unit | `flutter test test/services/sentry_breadcrumbs_test.dart -x` | ❌ Wave 0 |
| **OBS-05** (c) | `MintBreadcrumbs.saveFact()` emits breadcrumb with `fact_kind` enum only (no value) | unit | `flutter test test/services/sentry_breadcrumbs_pii_test.dart -x` | ❌ Wave 0 |
| **OBS-05** (d) | `MintBreadcrumbs.featureFlagsRefresh()` emits breadcrumb on refresh success + failure paths | unit | `flutter test test/services/sentry_breadcrumbs_refresh_test.dart -x` | ❌ Wave 0 |
| **OBS-06** | Redaction audit artefact committed with 5 screens × masked verified | artefact-exists | `test -s .planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md && python3 tools/checks/audit_artefact_shape.py SENTRY_REPLAY_REDACTION_AUDIT` | ❌ Wave 0 |
| **OBS-06** (walkthrough) | Each screen audited on simulator, screenshot + mask state recorded | **manual-only** | see Manual-Only §OBS-06 | n/a |
| **OBS-07** (a) | Observability budget artefact committed with pricing fetch date + projection table | artefact-exists | `test -s .planning/observability-budget.md && test -s .planning/research/SENTRY_PRICING_2026_04.md` | ❌ Wave 0 |
| **OBS-07** (b) | `sentry-cli api /organizations/mint/stats_v2/` returns valid JSON with current usage | integration | `bash tools/simulator/sentry_quota_smoke.sh` | ❌ Wave 0 |
| **Gate J0** | walker.sh boot → install → screenshot → pull Sentry events in <3 min | integration | `timeout 180s bash tools/simulator/walker.sh --smoke-test-inject-error` | ❌ Wave 0 |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

### Sampling Rate

- **Per task commit** (<30s): `flutter test test/services/error_boundary_test.dart test/services/sentry_breadcrumbs_test.dart test/services/api_service_sentry_trace_test.dart -r compact` (scoped per Plan 31-01/02 changed files)
- **Per wave merge** (<5 min): Full suite command above + `bash tools/simulator/walker.sh --gate-phase-31`
- **Phase gate** (non-skippable): Full suite green + `tools/simulator/walker.sh --gate-phase-31` green + Julien creator-device walkthrough 10-min manual (`SENTRY_REPLAY_REDACTION_AUDIT.md` signed) + `gsd-secure-phase` pass on OBS-06 PII audit.

### Wave 0 Gaps

- [ ] `apps/mobile/test/services/error_boundary_test.dart` — covers OBS-02 (a, b)
- [ ] `apps/mobile/test/services/error_boundary_ordering_test.dart` — covers OBS-02 (a)
- [ ] `apps/mobile/test/services/error_boundary_single_capture_test.dart` — covers OBS-02 (b)
- [ ] `apps/mobile/test/services/sentry_breadcrumbs_test.dart` — covers OBS-05 (b)
- [ ] `apps/mobile/test/services/sentry_breadcrumbs_pii_test.dart` — covers OBS-05 (c)
- [ ] `apps/mobile/test/services/sentry_breadcrumbs_refresh_test.dart` — covers OBS-05 (d)
- [ ] `apps/mobile/test/services/api_service_sentry_trace_test.dart` — covers OBS-04 (a)
- [ ] `apps/mobile/test/app_router_observers_test.dart` — covers OBS-05 (a)
- [ ] `services/backend/tests/test_global_exception_handler.py` — covers OBS-03 (a, b, c)
- [ ] `tools/checks/verify_sentry_init.py` — covers OBS-01 audit
- [ ] `tools/checks/sentry_capture_single_source.py` — covers OBS-02 (c)
- [ ] `tools/checks/audit_artefact_shape.py` — covers OBS-06 + OBS-07 artefact shape
- [ ] `tools/simulator/walker.sh` — J0 livrable
- [ ] `tools/simulator/assert_event_round_trip.py` — covers walker smoke
- [ ] `tools/simulator/trace_round_trip_test.sh` — covers OBS-04 (b)
- [ ] `tools/simulator/sentry_quota_smoke.sh` — covers OBS-07 (b)
- [ ] `apps/mobile/integration_test/` directory if absent — hosts real-HTTP tests
- [ ] Framework install: `brew install sentry-cli` — blocking dep at Plan 31-00

**Manual-Only Verifications**

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Sentry UI cross-project link visible (mobile → backend in same trace) | OBS-04 (c) | Sentry rendering lives server-side, no API-level assertion matches UX | 1. Trigger error from walker.sh with known trace_id. 2. Open `https://sentry.io/organizations/mint/issues/` within 60s. 3. Click the event. 4. Verify "Trace" panel shows linked backend transaction. Screenshot + commit in `SENTRY_REPLAY_REDACTION_AUDIT.md` §A4-visual. |
| 5 sensitive screens masked on simulator Replay | OBS-06 walkthrough | Requires visual inspection frame-by-frame of replay on real Sentry UI | 1. Flip `sessionSampleRate=0.05` on staging. 2. Walker.sh record session exercising (CoachChat, DocumentScan, ExtractionReviewSheet, Onboarding, Budget). 3. Open replay in Sentry. 4. Pause on each frame rendering a CHF/IBAN/AVS number. 5. Verify black box overlay visible. Record screenshot per screen. Commit artefact. |
| creator-device walkthrough Julien iPhone physique 10 min cold-start | Phase 31 gate (L3 profile) | simctl ≠ real device (E5 pitfall); APNs/Face ID/camera must be exercised | 1. Build staging IPA + install iPhone 17 Pro Julien. 2. Kill app. 3. Cold-start timer. 4. Execute 5 critical journeys (A6). 5. Inject 1 fake error via dev menu. 6. Within 60s open Sentry UI → verify event + replay present + cross-project linked. 7. Screenshot + commit `.planning/phases/31-instrumenter/DEVICE_WALKTHROUGH.md`. |

### Validation Sign-Off

- [ ] All tasks have `<automated>` verify OR Wave 0 dependency OR Manual-Only entry
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (Manual-Only items gated per-wave, not per-task)
- [ ] Wave 0 covers all 17 scaffolding items above
- [ ] No watch-mode flags (flutter test / pytest / bash — all one-shot)
- [ ] Feedback latency <60s per-commit, <5min per-wave
- [ ] `nyquist_compliant: true` set in frontmatter after Wave 0 complete

**Approval:** pending — awaits lock CONTEXT.md post panel on 6 decisions below.

---

## Security Domain

> `security_enforcement` enabled (v2.8 default). OBS-06 PII audit IS a security gate. OBS-03 handler must not leak PII in error response body. Breadcrumb helpers must enforce enum-only data.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (Phase 33 owns auth-related flag changes) | — |
| V3 Session Management | no (Phase 31 touches error capture, not sessions) | — |
| V4 Access Control | partial (OBS-07 Sentry org DSN/auth token access control) | GitHub secret + Sentry org RBAC allowlist Julien |
| V5 Input Validation | partial (OBS-03 handler must not echo user input in error body) | JSON body = fixed schema, no `str(exc)` full echo (FIX-077 pattern L171 existing) |
| V6 Cryptography | no | — |
| V7 Error Handling & Logging | **yes (core of Phase 31)** | (a) `send_default_pii=False` both sides (b) `maskAllText/Images=true` mobile (c) PII scrubbers Sentry org server-side (d) logger truncation `%.100s` (e) breadcrumb data enum-only |
| V8 Data Protection | **yes (Replay = video data)** | (a) EU data residency Sentry (b) `sessionSampleRate=0.05` low volume (c) PII scrubbers (d) OBS-06 audit kill-gate |
| V9 Communication | partial (trace headers over TLS) | HTTPS enforced (no plain HTTP). `tracePropagationTargets` narrow to MINT backends only (existing CTX-05). |
| V10 Malicious Code | no | — |
| V11 Business Logic | no | — |
| V12 Files & Resources | no | — |
| V13 API | partial (trace_id surface in JSON body = new public contract) | OpenAPI update `tools/openapi/mint.openapi.canonical.json` + `SOT.md` for `trace_id` + `sentry_event_id` fields |
| V14 Configuration | **yes** | Env var discipline — `SENTRY_DSN` + `SENTRY_AUTH_TOKEN` never in git, only CI secrets + Railway env. `.env` patterns excluded. |

### Known Threat Patterns for Sentry Flutter + FastAPI stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| PII video leak via Session Replay (revenus/IBAN on chart) | **Information Disclosure** | `maskAllText/Images=true` + `SentryMask` wrap `CustomPaint` + EU residency + server-side scrubbers + OBS-06 audit kill-gate |
| PII string leak via breadcrumb data | Information Disclosure | Enum-only data keys + `beforeBreadcrumb` filter + `sentry_breadcrumbs_pii_test.dart` fuzz |
| PII leak via exception message in log | Information Disclosure | `str(exc)[:100]` truncation (FIX-077 existing) + PIILogFilter (`privacy.log_filter` existing) + structured JSON log only |
| Trace_id prediction / forgery (attacker fakes trace_id to pivot | Tampering / Spoofing | Trace_id generated by Sentry SDK with crypto-random, 32-hex. Backend accepts as opaque identifier (no trust assertion). No authorization based on trace_id. |
| DSN leak (Sentry events posted by attacker) | Spoofing + Repudiation | Public DSN by design (client-side SDK) — mitigation = Sentry org `beforeSend` server-side rules + quota cap. Accept. |
| Sentry auth token leak (attacker reads all MINT events + replays) | Information Disclosure | Token scope `org:read project:read event:read` (no write), stored GH secret + macOS Keychain only, rotated annually, revoked on dev exit. |
| Third-party proxy logs `sentry-trace` header (observability leaks to Railway/Cloudflare telemetry) | Information Disclosure | Trace_id is non-PII (opaque ID) — acceptable surface. Documented `SENTRY_REPLAY_REDACTION_AUDIT.md` §Data flow. |
| Breadcrumb pollution with user content by agent dev (Future) | Information Disclosure | PR gate `tools/checks/sentry_breadcrumbs_pii_lint.py` (Phase 34 GUARD-* extension) — blocks `data: {'message': ...}` patterns. |

---

## Decisions Needing Panel Review

> 6 décisions structurantes à locker via panel expert AVANT Plan 31-01/02. Le planner consomme CONTEXT.md post-panel, pas ce RESEARCH.md directement pour ces choix.

### Decision #1 — Production `sessionSampleRate` target

**Context:** OBS-01 ship a déjà landé `sessionSampleRate=0.05` (5%) en defaults. Sentry Replay quota = expensive (Business tier inclut 500 replays/mois, 5k MAU × 5% ≈ 7.5k projection → overage ~$210/mois). nLPD compliance + anti-shame doctrine requires conservative PII exposure. Crash context (A3) capturé par `onErrorSampleRate=1.0` couvre le vrai besoin diagnostic ("l'Oracle").

**Options:**

| Option | `sessionSampleRate` | Quota impact (5k MAU) | Diagnostic value | Legal / nLPD |
|--------|---------------------|------------------------|-------------------|--------------|
| **A. Conservatif** | `0.02` (2%) | ~3k/mo (dans Business incl.) | Faible — replay ambient rare | Minimal surface |
| **B. Actuel / CTX-05 default** | `0.05` (5%) | ~7.5k/mo (overage $210) | Moyen — replay dispo sur échantillon | Moyenne surface |
| **C. Error-driven only** | `0.0` + `onErrorSampleRate=1.0` | ~2k/mo (crashes only) | Haut — chaque crash a son replay, pas de volume sain perdu | Minimale surface (crash = bug signal explicite) |
| **D. Staged cohort** | `{internal=1.0, staging=0.2, prod=0.02}` via FeatureFlags | ~3k/mo prod + variables pré-prod | Haute dev-loop, moyen prod | Moyen — cohort gate PII (users internal consentent) |
| **E. Adaptive (DIFF-06 defer)** | Dynamic per Sentry usage % | Cap fixe | Haute | Variable |

**Tradeoffs:**

- Option A/C = minimiser coût + surface PII mais perdre "ambient replay" (bugs UX soft qui n'émettent pas d'exception Sentry).
- Option B = status quo CTX-05 mais dette quota.
- Option D = meilleur rapport signal/coût — **recommandation par défaut**.
- Option E = complexité additionnelle, defer v2.9.

**Tentative default (subject to panel):** **Option C** (`sessionSampleRate=0.0` + `onErrorSampleRate=1.0`) — "Replay is a crash-context tool, not an ambient observer." Aligné avec Core Value v2.8 ("on sait en <60s ce qui casse"). Si panel privilégie dev-loop diagnostic, bascule Option D avec `{prod: 0.02}`. **Option B = ne PAS ship en prod tel quel** (overage + PII surface > valeur).

### Decision #2 — Sentry DSN strategy

**Context:** Backend utilise actuellement une seule `SENTRY_DSN` env var, différente sur Railway staging vs prod (`SENTRY_DSN` est différente mais le Sentry project cible peut être le même avec un tag `environment`). Mobile utilise `SENTRY_DSN_MOBILE` GitHub secret (1 DSN, injected at build time — envoie tout au même projet). Les builds TestFlight internal vs prod AppStore sont tous instrumentés vers la même DSN. 2 options possibles pour la phase 31.

**Options:**

| Option | Description | Alerts | Dashboard | Complexity |
|--------|-------------|--------|-----------|------------|
| **A. 1 project, env tag** | 1 Sentry project "mint", `environment: staging|production` tag, filter par env dans UI | 1 policy + env filter | 1 dashboard avec switch env | Simple — status quo backend |
| **B. 2 projects séparés** | Sentry project "mint-staging" + "mint-production", 2 DSNs différentes | 2 policies indépendantes (peut être plus strict sur prod) | 2 dashboards (parfois utile) | Double config : 2 secrets CI, 2 Sentry projects, 2 alert rules |

**Tradeoffs:**

- Option A : moins de setup, échantillonnage unifié, cross-project link mobile→backend marche naturellement (même trace_id voyage dans 1 project). Inconvénient : les erreurs prod et staging se mélangent dans la vue default, besoin discipline filter.
- Option B : séparation nette, alerting prod plus tight sans noise staging, mais double la charge maintenance. Cross-project link mobile→backend reste OK (les DSNs vivent dans la même Sentry org). Doubler GitHub secrets et Railway env vars.

**Tentative default (subject to panel):** **Option A** — 1 project with env tag. Justifications : (a) solo dev team, complexity budget bas (G2 pitfall), (b) cross-project link mobile→backend via `sentry-trace` OPÈRE sur DSN-aware projects — un seul project simplifie le mental model, (c) filter UI Sentry est mature et un tag `environment` suffit pour isoler alerts prod vs staging. **Option B si panel estime que prod noise / staging noise cross-contamine dashboards.**

### Decision #3 — Event naming convention + breadcrumb categories

**Context:** REQUIREMENTS OBS-05 mentionne "breadcrumb custom (ComplianceGuard success/fail, save_fact tool call, FeatureFlags.refreshFromBackend outcome)". A6 pitfall exige 5 named transactions pour les 5 critical journeys. Sans schema systematic, on se retrouve avec `mint.compliance.guard.pass` + `user_clicked_compliance` + `complianceGuardValidateTrue` — unsearchable, unparsable.

**Options:**

| Option | Schema | Exemple |
|--------|--------|---------|
| **A. Hierarchical reverse-dns** | `mint.<surface>.<action>.<outcome>` | `mint.compliance.guard.pass`, `mint.coach.tool.save_fact.success` |
| **B. Journey.flow** | `<journey>.<step>.<outcome>` | `coach_turn.compliance_guard.pass`, `anonymous_onboarding.intent.captured` |
| **C. Flat noun_verb** | `<noun>_<verb>` (convention Anthropic docs) | `compliance_guard_passed`, `save_fact_called` |
| **D. Free-form (status quo)** | Whatever dev writes | `ComplianceGuard passed`, `saveFact` |

**Tradeoffs:**

- Option A : hiérarchique, Sentry UI groupe naturellement par `mint.compliance.*`. Verbeux mais self-documenting.
- Option B : centré journey (cohérent avec §A6 5 critical journeys). Moins verbeux mais cross-journey events (ComplianceGuard tourne sur plusieurs journeys) difficile à nommer.
- Option C : Anthropic/OpenAI telemetry convention. Court + grep-able. Perd la hiérarchie implicite.
- Option D : rejet — façade-sans-câblage sur la nomenclature.

**Tentative default (subject to panel):** **Option A** hierarchical reverse-dns. Categories breadcrumb : `mint.compliance.guard`, `mint.coach.tool.save_fact`, `mint.feature_flags.refresh`. Named transactions : `mint.journey.anonymous_onboarding`, `mint.journey.coach_turn`, `mint.journey.document_upload`, `mint.journey.scan_handoff_to_profile`, `mint.journey.tab_nav_core_loop`. Justif : Sentry UI grouping natif + self-documenting + compatible lefthook rule `instrument: <journey>` enforceable. **Option C si panel privilégie brevity**.

### Decision #4 — Quota budget ceiling

**Context:** Sentry Business tier $80/mo baseline. 5k MAU target v2.8. Replay overage $0.30/replay, transactions overage ~$0.00015/transaction, errors unlimited on Business. Option #1 retenue impacte directement quota replay.

**Options:**

| Option | Hard cap | Soft alert | Action if exceeded |
|--------|----------|------------|---------------------|
| **A. Strict $100/mo** | $100 | 70% at J20 | Auto-stop Replay via feature flag, email Julien |
| **B. Moderate $160/mo** (2× Business baseline) | $160 | 70% + 85% | Manual review + descope decision |
| **C. Loose $250/mo** (3×) | $250 | 80% + 95% | Notify only, no auto-stop |
| **D. No hard cap** | ∞ | 70% notify | Review monthly, accept overage |

**Tradeoffs:**

- Option A : discipline hard, mais auto-stop Replay = perte diagnostique soudaine (peut cacher un P0 juste quand on en a le + besoin).
- Option B : standard Sentry pricing discipline (2× = allowance). Recommandé par A2 pitfall.
- Option C : lax, solo dev pas vigilant.
- Option D : tolère tout, mais mène à G2 budget overrun pattern.

**Tentative default (subject to panel):** **Option B ($160/mo ceiling)** — A2 PITFALLS.md standard. Alert 70% au J20 + 85% cap soft (notify, propose descope). Hard-stop $160 via Sentry spend-cap setting. Justif : solo dev team, auto-stop trop agressif (Option A), laxisme risque G2 (Option D). Panel peut descoper → Option A si ship en prod conservatif (cohérent avec Option C Decision #1). **Option D rejeté par doctrine no-shortcuts.**

### Decision #5 — Trace_id propagation header strategy

**Context:** 3 headers candidats :
- `sentry-trace` : Sentry natif, SDK auto-generate + auto-parse, non-W3C (subset)
- `traceparent` (W3C Trace Context standard) : standard cross-vendor, auto-parsé par OpenTelemetry / Datadog / etc.
- `X-MINT-Trace-Id` custom : non-standard name, proxies strip less likely

A4 PITFALLS.md warns Railway/Cloudflare may strip `sentry-trace`. STACK.md §A.4 recommande `sentry-trace` seul. Opentelemetry = defer v2.9.

**Options:**

| Option | Headers mobile → backend | Redundancy | Proxy survival | Complexity |
|--------|-----------------------|------------|----------------|------------|
| **A. `sentry-trace` only** | `sentry-trace` + `baggage` | 0 | Risk A4 if proxy strips | Simple (STACK.md default) |
| **B. `sentry-trace` + `X-MINT-Trace-Id`** | 2 headers (Sentry natif + custom fallback) | 1 | Custom less likely stripped | Simple — 1 extra header |
| **C. `sentry-trace` + `traceparent`** | 2 headers (Sentry + W3C) | 1 | `traceparent` = standard, proxies less likely strip | Needs manual `traceparent` build côté mobile (Flutter SDK may or may not emit it) |
| **D. All 3** | `sentry-trace` + `baggage` + `traceparent` + `X-MINT-Trace-Id` | 2 | Robust | Verbose + maintenance double |

**Tradeoffs:**

- Option A : simple, mais ne survit pas A4 pitfall si proxy strip.
- Option B : custom header "belt + suspenders" cheap. Backend `global_exception_handler` lit `sentry-trace` FIRST then `X-MINT-Trace-Id` fallback. Simple parser.
- Option C : W3C compliance future-proof (prép OpenTelemetry v2.9+). Mais Sentry Flutter 9.14.0 n'émet pas `traceparent` par défaut, requires manual build (à VERIFIER).
- Option D : maintenance overhead.

**Tentative default (subject to panel):** **Option B** (`sentry-trace` + `X-MINT-Trace-Id`) — belt + suspenders cheap, addresses A4 mitigation step 2 verbatim. Backend handler reads `sentry-trace` first (preserves Sentry auto-cross-project link), falls back to `X-MINT-Trace-Id` for proxy-survival. Simple parser. **Option C si panel vise prép OTel v2.9** mais requires verification Sentry SDK emits traceparent.

### Decision #6 — PII redaction scope policy

**Context:** Current CTX-05 install : `maskAllText=true` + `maskAllImages=true` (defaults Sentry 9.14.0). Pitfall A1 / 1 : CustomPaint n'est PAS couvert. MINT utilise CustomPaint pour TOUS charts. Default-deny par wrap de chaque CustomPaint vs allowlist explicite de screens OK-to-mask-less.

**Options:**

| Option | Policy | Protection | Maintenance | Risk |
|--------|--------|------------|-------------|------|
| **A. Status quo (text+image masks only)** | Rely on `maskAllText/Images` defaults only | Moyen — CustomPaint non-masked → fuite chart numérique | Nul | **HIGH — A1 kill-gate** |
| **B. Default-deny CustomPaint wrap** | Wrap every `CustomPaint` in `SentryMask` by default | Haute — rien fuite via CustomPaint | Moyenne (audit chaque CustomPaint call site) | Low |
| **C. Allowlist explicit screens** | Liste explicite des 5 screens sensibles + `SentryMask` only there | Moyen — nouveaux écrans non-audited fuite | Variable (liste à maintenir) | Moyen — regression si nouveau écran oublie |
| **D. Hybrid** | Default-deny CustomPaint + explicit allowlist non-sensible (`SentryUnmask` on logos/chrome only) | Haute — default secure + opt-in visible | Moyenne | Low |

**Tradeoffs:**

- Option A : facile mais viole nLPD — A1 pitfall réel.
- Option B : sécurise mais peut masquer des charts légitimement user-facing (mais Replay = debug, on ne perd rien vital).
- Option C : moins de code wraps mais chaque nouvel écran = décision oubliable.
- Option D : compromis "default secure with audit escape hatch". Recommandé.

**Tentative default (subject to panel):** **Option D hybrid** — default-deny : chaque `CustomPaint` dans `lib/` wrap `SentryMask` par défaut (lint `tools/checks/custom_paint_sentry_mask.py` Phase 34 GUARD-* extension) ; `SentryUnmask` autorisé uniquement avec commit message `unmask: <surface> reason="<pourquoi-pas-pii>"` review-ready. OBS-06 audit enforce. Justif : aligné A1 mitigation step 1+2+3 (default-deny + allowlist boundary + prod flag gated) ; matches no-shortcuts doctrine. **Option C viable si panel préfère lighter maintenance + strict screen audit cadence.**

---

## Sources

### Primary (HIGH confidence)

- [Sentry Flutter SDK docs — Session Replay setup](https://docs.sentry.io/platforms/dart/guides/flutter/session-replay/) — masks, sample rates
- [Sentry Flutter — Session Replay Privacy](https://docs.sentry.io/platforms/dart/guides/flutter/session-replay/privacy/) — `maskAllText`, `maskAllImages`, `SentryMask`, `SentryUnmask`
- [Sentry Flutter — Trace Propagation](https://docs.sentry.io/platforms/flutter/tracing/trace-propagation/) — `sentry-trace`, `baggage`, `toSentryTrace()`, `toBaggageHeader()`
- [FastAPI distributed tracing](https://docs.sentry.io/platforms/python/tracing/distributed-tracing/) — auto-read inbound headers
- [Sentry SDK Python + FastAPI integration](https://docs.sentry.io/platforms/python/integrations/fastapi/) — auto-instrumentation
- [Sentry CLI](https://docs.sentry.io/cli/configuration/) — API pulls + auth token scopes
- `.planning/research/STACK.md` (2026-04-19) — pins vérifiés pub.dev + PyPI
- `.planning/research/PITFALLS.md` (2026-04-19) — A1..A6 Phase 31 owned, mitigation steps
- `apps/mobile/lib/main.dart:111-142` (post-CTX-05) — current wired state
- `apps/mobile/lib/app.dart:171-176` — current GoRouter observers list
- `services/backend/app/main.py:169-180` — current global_exception_handler
- `services/backend/app/core/logging_config.py:85-103` — existing LoggingMiddleware X-Trace-Id flow
- `decisions/ADR-20260419-autonomous-profile-tiered.md` — L3 profile mandatory for Phase 31
- `decisions/ADR-20260419-v2.8-kill-policy.md` — OBS-06 artefact gate

### Secondary (MEDIUM confidence — cross-verified)

- STACK.md §A.1 — Cash App (Block) Sentry case study 2024 public reference
- STACK.md §A.2 — Stripe / Brex mobile industry pattern 3-prong (post-2023)
- STACK.md §A.4 — Stripe Atlas + Ramp iOS Sentry case study MTTR (training data)
- `feedback_ios_build_macos_tahoe.md` — MINT doctrine on simctl + Podfile.lock
- `feedback_app_targets_staging_always.md` — API_BASE_URL discipline
- `feedback_facade_sans_cablage.md` — doctrine #1 applied to Phase 31 gate criteria
- `feedback_audit_methodology.md` — inter-layer contract check (mobile↔backend trace_id round-trip)

### Tertiary (LOW confidence — flagged for verification)

- Sentry Replay 500/mo Business quota — **OBS-07 fresh fetch mandatory** before Plan 31-02
- Sentry pricing $80/mo Business — **OBS-07 fresh fetch mandatory**
- Railway edge behavior on `sentry-trace` header strip — **OBS-04 real-HTTP test mandatory** (A4)
- Cloudflare tier behavior on custom headers — **OBS-04 real-HTTP test mandatory**
- `SentryNavigatorObserver` + multiple observers compatibility — **Plan 31-01 smoke test**
- `sentry_flutter 9.14.0` + `go_router 13.2.0` compatibility — **Plan 31-00 `pub get` smoke**

---

## Metadata

**Confidence breakdown:**
- Standard stack : HIGH — pins verified CTX-05 spike + STACK.md 2026-04-19 + pub.dev/PyPI
- Architecture patterns : HIGH — patterns cross-reference Sentry docs + existing codebase
- Pitfalls (A1..A4 critical + 10 Phase-specific) : HIGH — inherited from PITFALLS.md + new Phase-31 specific
- Decision #1..6 tradeoffs : MEDIUM — tentative defaults based on MINT doctrine + best practice, panel locks
- Validation architecture : HIGH — test scaffolding covers all 7 REQs + 3 manual-only + J0 gate
- Sentry pricing numbers : **LOW — must fresh-fetch Plan 31-00** (A3 assumption)
- Railway/Cloudflare proxy behavior : **LOW — must real-HTTP test Plan 31-02** (A2 assumption)

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (30 days for stable Sentry SDK + backend docs) — re-verify Sentry tier/pricing at any plan boundary if invoice data suggests drift.

---

## RESEARCH COMPLETE

**Phase:** 31 - Instrumenter
**Confidence:** HIGH (technical patterns) + MEDIUM (Sentry tier/pricing — requires OBS-07 fresh fetch) + MEDIUM (proxy behavior — requires OBS-04 real-HTTP test staging)

### Key Findings

- **OBS-01 déjà shipped via CTX-05 spike** (`sentry_flutter 9.14.0` pinned, SentryWidget + masks nLPD actifs dans `main.dart:111-142`). Phase 31 démarre à OBS-02, pas OBS-01.
- **Error boundary single-source discipline mandatory** (`error_boundary.dart` unique point Sentry.captureException) — prévient A3 double-logging + prépare Phase 36 FIX-05 migration 388 bare catches.
- **Backend `global_exception_handler` doit cohabiter avec `LoggingMiddleware`** (déjà génère UUID + `X-Trace-Id`) — fallback priority `sentry-trace` > `trace_id_var` > `""`.
- **A1 PII Replay = nLPD kill-gate critique** — CustomPaint NON couvert par `maskAllText/Images`. OBS-06 audit mandatory avant `sessionSampleRate>0` prod. Default-deny policy recommandée (§Decision #6).
- **J0 livrable `tools/simulator/walker.sh`** = primitive partagée Phases 31-36 — à ship AVANT tout REQ OBS-* pour prover end-to-end câblage (anti-façade discipline).
- **6 décisions structurantes attendent panel** — sessionSampleRate target + DSN strategy + naming convention + quota budget + header strategy + PII redaction scope. Tentative defaults documentés mais CONTEXT.md pas lockable avant panel.

### Files Created

`.planning/phases/31-instrumenter/31-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | Versions CTX-05-verified + STACK.md 2026-04-19 fresh |
| Architecture patterns | HIGH | 5 patterns cross-ref Sentry docs + existing MINT codebase |
| Pitfalls (10 Phase-31 specific) | HIGH | Built on PITFALLS.md A1..A6 + fresh Phase-31 specifics |
| Validation architecture | HIGH | 7 REQs × 18 tests + 3 manual-only + J0 walker gate |
| Decision tentatives | MEDIUM | Defaults justifiés mais panel requis pour lock |
| Sentry tier/pricing | **LOW** | Training-stale, OBS-07 fresh fetch mandatory |
| Proxy behavior A4 | **LOW** | OBS-04 real-HTTP test staging mandatory |

### Open Questions (surfaced to discuss-phase)

1. Cohort rollout strategy for Replay flip (FeatureFlags-backed recommandé) — coordinate Phase 33 FLAG-05
2. 5 critical journeys — exact wording + transaction names (panel #3)
3. `traceparent` W3C support Sentry Flutter 9.14.0 (needs verification for panel #5 option C)
4. Backend `/test/inject_error` staging-only endpoint — ship or rely on invalid JWT pattern
5. Retry behavior after error boundary capture (integration test Plan 31-01)

### 6 Panel Decisions Awaiting Lock

1. **sessionSampleRate production target** — 0.0 error-only (tentative) / 0.02 / 0.05 status-quo / cohort-staged / adaptive
2. **DSN strategy** — 1 project env-tag (tentative) / 2 projects séparés
3. **Naming convention** — `mint.<surface>.<action>.<outcome>` hierarchical (tentative) / journey.flow / flat noun_verb / free-form
4. **Quota budget ceiling** — $100 strict / $160 moderate (tentative) / $250 loose / no cap
5. **Trace_id headers** — `sentry-trace` only / + `X-MINT-Trace-Id` (tentative) / + `traceparent` W3C / all 3
6. **PII redaction scope** — text+image only / default-deny CustomPaint / allowlist 5 screens / hybrid (tentative)

### Ready for Next Step

Research complete. Next : convene expert panel on the 6 decisions above, then `/gsd-discuss-phase 31` produces CONTEXT.md locking tentative choices (or overriding). `/gsd-plan-phase 31` then emits 3 plans (31-00 Wave 0 scaffolding + 31-01 mobile + 31-02 backend) consuming CONTEXT.md + this RESEARCH.md.
