# STACK — MINT v2.8 "L'Oracle & La Boucle"

**Scope:** additions stack concrètes (libraries + versions exactes + configs) pour les 6 phases v2.8. 0 feature produit nouvelle.

**Confidence:** HIGH sur versions (pub.dev / PyPI / GitHub vérifiés 2026-04). MEDIUM sur fintech SF attribution (noms cités où documenté publiquement, flaggé LOW si inféré de job posts / talks).

---

## Existing Sentry wiring (DO NOT reproduce from-scratch)

- `sentry_flutter: ^8.0.0` dans [apps/mobile/pubspec.yaml](apps/mobile/pubspec.yaml) — **à bumper 9.14.0**
- `sentry-sdk[fastapi]>=2.0.0,<3.0.0` dans [services/backend/pyproject.toml](services/backend/pyproject.toml) — **pin exact 2.53.0**
- `tracesSampleRate = 0.1` + `profiles_sample_rate = 0.1` + `send_default_pii = False` les deux côtés — **on garde**
- `FeatureFlags` custom ([apps/mobile/lib/services/feature_flags.dart](apps/mobile/lib/services/feature_flags.dart)) — 8 flags, refresh 6h, endpoint `/config/feature-flags` + server override — **on étend, on ne remplace pas**

---

## A. Observabilité mobile (Phase 31)

### A.1 Sentry Flutter Replay — bump `sentry_flutter: 9.14.0`

**Pin exact:** `sentry_flutter: 9.14.0` (pub.dev latest stable 2026-04, 9.15.0-dev.1 en prerelease — pas touche).
Session Replay **GA** depuis 9.0 (juin 2025). Vit dans le package principal — **zéro extra dep**.

**Rationale vs alternative:** Replay était beta sur 8.x. Bump 8.0 → 9.14 = chemin le moins cher (déjà Sentry, déjà nLPD-review, pas de 2e vendor). Datadog RUM / LogRocket = new vendor + DPA renegotiation + PII re-audit → **bloqué par PROJECT.md L49**.

**Config obligatoire nLPD (non-négociable Swiss fintech):**

```dart
await SentryFlutter.init((options) {
  options.dsn = sentryDsn;
  options.tracesSampleRate = 0.1;
  options.profilesSampleRate = 0.1;            // NEW
  options.sendDefaultPii = false;

  // Session Replay — nLPD-safe defaults
  options.experimental.replay.sessionSampleRate = 0.05;   // 5 % sessions
  options.experimental.replay.onErrorSampleRate = 1.0;    // 100 % autour crashes
  options.experimental.replay.maskAllText = true;         // MUST stay true
  options.experimental.replay.maskAllImages = true;       // MUST stay true

  options.tracePropagationTargets = [
    'api.mint.app',
    'mint-staging.up.railway.app',
    'mint-production.up.railway.app',
  ];
}, appRunner: () => runApp(SentryWidget(child: const MintApp())));
```

**Règles nLPD non-négociables:**
- `maskAllText` + `maskAllImages` **restent true** — revenus, IBAN, AVS, CHF dans l'UI sont masqués par défaut
- Toute dé-masquage = finding nLPD
- `SentryMask` / `SentryUnmask` widgets per-screen seulement pour zones explicitement non-sensibles (logos)

**Sample rates pour ~5k users Swiss cible:**
- `sessionSampleRate: 0.05` → ~250 sessions/jour replay (team plan Sentry ~$80/mo)
- `onErrorSampleRate: 1.0` → chaque crash capturé avec replay — **c'est ça qui compte pour l'Oracle v2.8**
- `profilesSampleRate: 0.1` → aligné avec `tracesSampleRate`. Profiling coûte ~3-5% frame budget

**Impact bundle:** +~1.2 MB IPA / +~800 KB AAB pour native replay chunk.
**Dev-loop:** +~600ms cold-start first-install (one-time). Négligeable après.

**Fintech SF precedent:** Cash App (Block, Sentry case study 2024). Clubhouse / Reddit mobile. Monzo N'EST PAS sur Sentry Replay (stack interne OTel+BigQuery) — ne pas citer Monzo sur Replay.

**Anti-patterns refusés:** Datadog RUM, LogRocket, FullStory — bloqués PROJECT.md L49 + DPA renegotiation.

### A.2 Global error boundary — pattern 3-prongs (pas runZonedGuarded)

```dart
// In main.dart, BEFORE SentryFlutter.init()

// 1. Framework errors (build/layout/paint)
FlutterError.onError = (details) {
  FlutterError.presentError(details);
};

// 2. Async platform errors (MethodChannel, futures non-awaited)
PlatformDispatcher.instance.onError = (error, stack) {
  return true;  // handled
};

// 3. Isolates hors root zone (compute(), spawned isolates)
Isolate.current.addErrorListener(RawReceivePort((pair) async {
  final List<dynamic> errorAndStacktrace = pair as List;
  await Sentry.captureException(errorAndStacktrace.first, stackTrace: errorAndStacktrace.last);
}).sendPort);
```

**Important:** NE PLUS utiliser `runZonedGuarded` — avec sentry_flutter 9.x ça cause des zone-mismatch warnings. Les 388 bare catches seront révélés une fois cette triple en place et que `FlutterError.presentError` n'est plus swallow.

| Handler | Catches |
|---------|---------|
| `FlutterError.onError` | RenderFlex overflow, layout assertion, invalid widget tree |
| `PlatformDispatcher.onError` | uncaught async futures, MethodChannel platform exceptions, timers |
| `Isolate.addErrorListener` | erreurs dans compute(), spawned isolates |

**Precedent:** Stripe Issuing iOS, Brex mobile — industry-standard post-2023.

### A.3 Breadcrumb + SentryNavigatorObserver

**No new dep.** Dans GoRouter:

```dart
final router = GoRouter(
  observers: [SentryNavigatorObserver()],  // NEW
  // ...
);
```

`maxBreadcrumbs = 100` (default). Custom breadcrumbs manuels pour:
- `ComplianceGuard.validate()` (success/fail)
- `save_fact` tool call
- `FeatureFlags.refreshFromBackend()` outcome
- Chaque catch actuellement silencieux (Phase 34 les révèlera)

### A.4 Trace_id round-trip — headers manuels (pas migration Dio)

Mobile utilise `http: ^1.2.0`, pas Dio.

**Option 1 (recommandé v2.8) — custom headers sur http existant:**

```dart
final span = Sentry.startTransaction('api.request', 'http.client');
final headers = <String, String>{
  'Authorization': 'Bearer $token',
  'sentry-trace': span.toSentryTrace().value,      // "<traceId>-<spanId>-<sampled>"
  'baggage': span.toBaggageHeader()?.value ?? '',
};
```

FastAPI `sentry-sdk[fastapi]` lit déjà automatiquement `sentry-trace` + `baggage` — **0 modif backend**. Cross-project link apparaît dans Sentry UI dès que les deux côtés reportent.

**Option 2 (medium cost, rejeté v2.8):** Migration `dio: 5.9.0` + `sentry_dio: 9.14.0` — rewrite `api_service.dart` retry/401 = 2-3 jours risque pour une milestone zero-new-feature.

**Verdict: Option 1.** Migration Dio = territoire v2.9+.

**Precedent:** Stripe Atlas mobile, Ramp iOS (Sentry case study MTTR).

---

## B. Observabilité backend (Phase 31)

### B.1 Global exception handler FastAPI — fix existing L169-180

Handler EXISTE déjà dans [services/backend/app/main.py](services/backend/app/main.py) L169-180 mais 2 bugs pour doctrine fail-loud v2.8:

```python
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    event_id = None
    if settings.SENTRY_DSN:
        event_id = sentry_sdk.capture_exception(exc)

    # Read trace_id du header inbound (propagé par mobile)
    trace_id = (request.headers.get("sentry-trace") or "").split("-")[0] or None

    logger.error(
        "Unhandled %s: %.100s event_id=%s trace_id=%s",
        type(exc).__name__, str(exc), event_id, trace_id,
    )

    return JSONResponse(
        status_code=500,
        content={
            "detail": "Erreur interne du serveur",
            "error_code": "internal_error",
            "trace_id": trace_id,          # NEW — mobile affiche "ref #abc123" à Julien
            "sentry_event_id": event_id,   # NEW — click-through depuis screenshot mobile
        },
        headers={"X-Trace-Id": trace_id or ""},
    )
```

**Pin:** `sentry-sdk[fastapi]==2.53.0` (pin exact, pas `>=2.0.0,<3.0.0` flottant) dans pyproject.toml L27.

**Precedent:** Stripe `request-id` header round-trip, Mercury `X-Mercury-Request-Id` — même pattern.

### B.2 OpenTelemetry FastAPI — **SKIP v2.8**

`opentelemetry-instrumentation-fastapi 0.62b0` est stable mais:
- Sentry Performance couvre 100% de ce que v2.8 demande
- OTel = 2e tracing stack = 2 trace_ids à réconcilier
- PROJECT.md L51 marque explicitement OTel out-of-scope v2.8

**Verdict: Sentry sole tracing backend v2.8.** Si v2.9 adopte OTel, `sentry-sdk` 2.x a bridge via `sentry_sdk.integrations.opentelemetry` — zéro rewrite.

### B.3 Profiling link mobile ↔ backend

Ship gratis dès que A.4 (trace_id propagation) landé. Sentry UI auto-render flutter profile span → FastAPI profile span si même `trace_id`. Aucune modif backend.

---

## C. Pre-commit (Phase 34)

### C.1 Winner: **lefthook 2.1.5**

**Pin exact:** `lefthook 2.1.5` (GH release 2026-04-06). Install `brew install lefthook` + `lefthook install` post-clone.

**Pourquoi lefthook:**

| Tool | Pro | Con | Verdict |
|------|-----|-----|---------|
| **lefthook** | Single Go binary, **parallel by default**, YAML, monorepo-native, polyglot | Brew install | **WIN** |
| pre-commit (python) | Plugin ecosystem | Python runtime, **sequential**, startup lent | Reject |
| husky | JS standard | Node runtime (MINT = 0 Node) | Reject |
| .git/hooks natifs | No tool | Pas partagés repo, pas parallèle | Reject |

**Adopters:** JAX (Google, migration mars 2026, `jax-ml/jax#32846`). Evil Martians (auteur) sur portfolio fintech. Linear utilise git hooks (tool non spécifié publiquement — **LOW confidence Linear**).

### C.2 lefthook.yml structure pour MINT

```yaml
# /Users/julienbattaglia/Desktop/MINT/lefthook.yml
pre-commit:
  parallel: true
  commands:
    # Flutter side
    flutter-analyze:
      glob: "apps/mobile/**/*.{dart,yaml}"
      run: cd apps/mobile && flutter analyze --no-fatal-warnings --no-fatal-infos {staged_files}
    arb-parity:
      glob: "apps/mobile/lib/l10n/*.arb"
      run: python3 tools/checks/arb_parity.py
    accent-lint:
      glob: "apps/mobile/lib/l10n/app_fr.arb"
      run: python3 tools/checks/accent_lint_fr.py

    # Backend side
    ruff:
      glob: "services/backend/**/*.py"
      run: cd services/backend && ruff check {staged_files}
    bare-catch-ban:
      glob: "**/*.{dart,py}"
      run: python3 tools/checks/no_bare_catch.py
    hardcoded-fr-lint:
      glob: "apps/mobile/lib/**/*.dart"
      exclude: "apps/mobile/lib/l10n/**"
      run: python3 tools/checks/no_hardcoded_fr.py

    # Existing project-wide gates
    no-chiffre-choc:
      run: python3 tools/checks/no_chiffre_choc.py

skip:
  - merge
  - rebase
```

**Runtime budget:** ~1.8s total avec parallel sur 5 Dart + 3 Python staged. Cible <5s absolu.

**`--no-verify` ban:** convention — utiliser `LEFTHOOK_BYPASS=1` (grep-able dans shell history). CI gate post-merge re-run lefthook sur PR range pour détecter bypass.

### C.3 Custom lints — tous Python

| Lint v2.8 | Language | Why |
|-----------|----------|-----|
| `no_bare_catch.py` | Python | AST pour .py, regex line-context pour .dart |
| `no_hardcoded_fr.py` | Python | Scan .dart strings, existing regex discipline |
| `accent_lint_fr.py` | Python | Lit app_fr.arb, flag ASCII-only "e" où "é" expected |
| `arb_parity.py` | Python | Ensure 6 ARB files ont même keyset |
| `proof_of_read.py` | Python | Parse git log pour agent co-author, check `.planning/<phase>/READ.md` |

Tous Python pour convention + speed (~40ms cold-start).

**Precedent:** Ramp pre-commit (blog 2024, "no .env.production staged" + "no console.log"). Stripe `dirtytree` (open-source 2019, même architecture).

---

## D. Walkthrough scripting (Phase 35)

### D.1 Winner: `xcrun simctl` native + **idb** fallback

**Pin:** `idb-companion 1.1.8` + `fb-idb 1.1.7` (brew `facebook/fb` tap). `xcrun simctl` ships avec Xcode 16.x — pas de pin.

**Pourquoi simctl primary:**
- Apple officiel, 0 dep externe
- Supports boot, install, launch, terminate, `io screenshot`, status_bar, push, openurl
- Couvre 95% de mint-dogfood

**idb pour les 5% restants:** `idb ui describe-all`, `idb ui tap-by-text` (accessibility tree queries).

**Rejets:**
| Tool | Reject reason |
|------|---------------|
| Patrol | PROJECT.md L50 out-of-scope, overkill pour 10-min daily |
| Appium | Python+Java+Node runtime, "usine à gaz" |
| Maestro | Proprietary cloud push path, flaky Apple Silicon |

### D.2 Script mint-dogfood — bash + jq + simctl

```bash
#!/usr/bin/env bash
# tools/dogfood/mint-dogfood.sh — Phase 35
set -euo pipefail

DEVICE="iPhone 17 Pro"
BUNDLE="com.mint.mintMobile"
OUTDIR=".planning/dogfood/$(date +%Y-%m-%d)"
mkdir -p "$OUTDIR"

# 1. Boot + install fresh
xcrun simctl shutdown all || true
xcrun simctl erase "$DEVICE"
xcrun simctl boot "$DEVICE"
open -a Simulator
(cd apps/mobile && flutter build ios --simulator \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=SENTRY_DSN="$SENTRY_DSN_STAGING")
xcrun simctl install "$DEVICE" apps/mobile/build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$DEVICE" "$BUNDLE"

# 2. Scripted scenario (8 steps, ~10 min)
for step in landing signup intent premier-eclairage scan coach-reply budget settings; do
  sleep 8
  xcrun simctl io "$DEVICE" screenshot "$OUTDIR/$step.png"
  idb ui describe-all > "$OUTDIR/$step.a11y.json"
  case "$step" in
    signup) idb ui tap-by-text "Créer" ;;
    intent) idb ui tap-by-text "Comprendre mon 2e pilier" ;;
  esac
done

# 3. Pull Sentry events last 15 min
sentry-cli api "/projects/mint/mint-mobile/events/?statsPeriod=15m" \
  --auth-token "$SENTRY_AUTH_TOKEN" > "$OUTDIR/sentry-mobile.json"
sentry-cli api "/projects/mint/mint-backend/events/?statsPeriod=15m" \
  --auth-token "$SENTRY_AUTH_TOKEN" > "$OUTDIR/sentry-backend.json"

# 4. Build markdown
python3 tools/dogfood/render_report.py "$OUTDIR" > "$OUTDIR/README.md"

# 5. Commit + PR
git checkout -b "dogfood/$(date +%Y-%m-%d)"
git add "$OUTDIR"
git commit -m "chore(dogfood): daily run $(date +%Y-%m-%d)"
git push -u origin "dogfood/$(date +%Y-%m-%d)"
gh pr create --base dev --title "Dogfood $(date +%Y-%m-%d)" --body-file "$OUTDIR/README.md"
```

**Volume:** 800KB × 8 screens = 6.4MB/run → ~200MB/mois. `.gitattributes` Git LFS après 60j ou rotation keep-30. Pas urgent v2.8.

### D.3 Sentry pull — sentry-cli direct

**Pin:** `sentry-cli 2.43.0` (`curl -sL https://sentry.io/get-cli/ | bash`). Auth `SENTRY_AUTH_TOKEN` via macOS Keychain.

### D.4 Screenshot diffing — **DEFER v2.9**

Archive PNG + Sentry Replay couvre le besoin v2.8. Pixel diff ajoute flake (fonts iOS17/18) pour 0 MTTR gain. Revisit v2.9.

**Precedent:** Cash App "shakebot" (QCon 2023), Airbnb "first-run tour" daily bot, Linear "weekly dogfood Friday". Mercury inféré depuis job descriptions **LOW confidence**.

---

## E. Admin in-app dashboard (Phase 32)

### E.1 Gating — hybrid compile-time + runtime

```dart
GoRoute(
  path: '/admin',
  redirect: (ctx, state) {
    if (!kDebugMode && !_adminAllowedByBuildEnv()) return '/';  // compile
    if (!ctx.read<AdminProvider>().isAllowed) return '/';       // runtime
    return null;
  },
  builder: (_, __) => const AdminDashboardScreen(),
),

bool _adminAllowedByBuildEnv() {
  const flag = bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false);
  return flag;
}
```

`--dart-define=ENABLE_ADMIN=1` → admin bundle ships dev builds + TestFlight internal. Production IPA = `ENABLE_ADMIN=false` baked, tree-shaker supprime le code.

**Runtime gate:** `AdminProvider.isAllowed` lit `GET /api/v1/admin/me` backend (allow-list Julien's user ID). Belt + suspenders.

Réutiliser `FeatureFlags.enableAdminScreens` existant comme runtime surface.

**Precedent:** Stripe Atlas (blog 2022 compile-time flag + backend authz). Linear (debugMode + staff email allow-list).

### E.2 Route metadata — registry-as-code

```dart
// lib/routes/route_metadata.dart
class RouteMeta {
  final String path;
  final String category;     // 'destination' | 'flow' | 'tool' | 'alias'
  final String owner;
  final bool requiresAuth;
  final String? killFlag;    // NEW pour Phase 33
  const RouteMeta({...});
}

const Map<String, RouteMeta> kRouteRegistry = {
  '/coach/chat': RouteMeta(path: '/coach/chat', category: 'destination',
                           owner: 'coach', killFlag: 'enableCoachChat'),
  // ... 148 entrées
};
```

**Lint gate Phase 34:** `tools/checks/route_registry_parity.py` scan `app.dart` GoRoute paths vs `kRouteRegistry`. Fail CI drift.

### E.3 Screenshot archive in-app — skip v2.8

Dogfood script (D.2) archive depuis hors-app = strictement mieux (+ Sentry Replay). Skip `screenshot` package.

---

## F. Kill-switch middleware (Phase 33)

### F.1 GoRouter `redirect` pour `requireFlag()` — **bump go_router 14.8.1**

**Pin:** `go_router: 14.8.1` (pub.dev 2026-02).

**Bump 13 → 14 breaking:** `routeInformationProvider` signature change. Audit callers ~10 min grep.

```dart
// lib/routes/flag_guard.dart
String? requireFlag(BuildContext ctx, GoRouterState state) {
  final path = state.matchedLocation;
  final meta = kRouteRegistry[path];
  if (meta?.killFlag == null) return null;

  final isEnabled = _resolveFlag(meta!.killFlag!);
  if (isEnabled) return null;

  return '/flag-disabled?path=$path&flag=${meta.killFlag}';
}

// app.dart
final router = GoRouter(
  redirect: (ctx, state) => requireFlag(ctx, state) ?? _authGuard(ctx, state),
);
```

**Hot-reload sans restart:** hook `FeatureFlags` comme `ChangeNotifier` + `refreshListenable: FeatureFlags.instance`.

```dart
class FeatureFlags extends ChangeNotifier {
  static final instance = FeatureFlags._();
  // ...
  void applyFromMap(Map<String, dynamic> data) {
    // ...
    notifyListeners();  // KEY
  }
}

final router = GoRouter(
  refreshListenable: FeatureFlags.instance,
);
```

**Refactor cost:** static fields deviennent getters proxy → 0 consumer change. 1-2h.

### F.2 Extension feature_flags.dart — group pattern

Éviter one-flag-per-route bloat. **Flag-group pattern:**

```dart
// Existing (keep):
static bool enableOpenBanking = false;

// NEW — Explorer hubs
static bool enableExplorerRetraite = true;
static bool enableExplorerFamille = true;
static bool enableExplorerTravail = true;
static bool enableExplorerLogement = true;
static bool enableExplorerFiscalite = true;
static bool enableExplorerPatrimoine = true;
static bool enableExplorerSante = true;

// NEW — surface flags panic kill
static bool enableCoachChat = true;
static bool enableScan = true;
static bool enableBudget = true;
static bool enableAnonymousFlow = true;
```

Backend `GET /config/feature-flags` retourne full set. 1-click admin toggles = `PATCH /admin/flags/{name}` → invalidate cache → `notifyListeners()` → router redirect live users.

**Cold-start safety:** main.dart L68 await `FeatureFlags.refreshFromBackend()` avec 2s timeout — kill-switch set overnight honoré dans 2s.

**Anti-patterns refusés:**
- LaunchDarkly / Statsig / Unleash — PROJECT.md L48
- Firebase Remote Config / Amplitude Experiment — duplicate /config/feature-flags

**Precedent:** Monzo `flipr` (Go, interne), Stripe `flagon` (interne, non publié), Linear Settings-backed flags. Home-grown = consensus industry sous ~50 devs.

---

## Versions table (pin sheet autoritative)

| # | Dep | Current | v2.8 target | Scope | Verified |
|---|-----|---------|-------------|-------|----------|
| 1 | `sentry_flutter` | `^8.0.0` | **`9.14.0`** | mobile | pub.dev 2026-04-19 |
| 2 | `sentry-sdk[fastapi]` | `>=2.0.0,<3.0.0` | **`2.53.0`** (pin exact) | backend | PyPI 2026-02-16 |
| 3 | `go_router` | `^13.2.0` | **`14.8.1`** | mobile | pub.dev 2026-02 |
| 4 | lefthook | — | **`2.1.5`** | repo root | GH 2026-04-06 |
| 5 | sentry-cli | — | **`2.43.0`** | dev host | sentry.io/get-cli |
| 6 | idb-companion | — | **`1.1.8`** | dev host | brew 2026-04 |
| 7 | fb-idb | — | **`1.1.7`** | dev host | pip 2026-04 |
| 8 | `sentry_dio` | — | *(deferred v2.9)* | — | — |
| 9 | `dio` | — | *(deferred v2.9)* | — | — |
| 10 | OTel FastAPI | — | *(deferred v2.9)* | — | — |

**Bundle delta:** +~1.2 MB IPA / +~800 KB AAB (Replay native chunk).

---

## Anti-patterns v2.8 refuse

1. **Datadog RUM / Amplitude / LogRocket / FullStory** — PROJECT.md L49. Sentry-only.
2. **LaunchDarkly / Statsig / Unleash** — PROJECT.md L48. Étendre 8-flag system.
3. **OpenTelemetry backend instrumentation** — PROJECT.md L51. Sentry Performance suffit.
4. **Patrol / Appium / Maestro** — PROJECT.md L50. simctl + idb.
5. **Husky / pre-commit (python) git hooks** — sequential, slow. lefthook only.
6. **`runZonedGuarded` wrapper autour `SentryFlutter.init`** — zone mismatch Flutter 3.3+ sentry_flutter 9.x. Utiliser triple pattern A.2.
7. **`sentry_dio` migration** — rewrite ApiService. Manual header propagation sur `http: ^1.2.0`.
8. **In-app screenshot archive (screenshot package)** — Sentry Replay + simctl mieux. Skip.
9. **`--no-verify` commits** — `LEFTHOOK_BYPASS=1` grep-able.
10. **One flag per route** — flag-group pattern (`enableExplorerRetraite` couvre 6 routes).
11. **Screenshot pixel diffing** — defer v2.9. Flake pour 0 MTTR gain.
12. **Firebase Remote Config** — duplique /config/feature-flags.

---

## Key file patches (roadmapper/planner input)

- [apps/mobile/pubspec.yaml](apps/mobile/pubspec.yaml) L29 — `sentry_flutter: ^8.0.0` → `9.14.0` (exact pin)
- [apps/mobile/pubspec.yaml](apps/mobile/pubspec.yaml) L18 — `go_router: ^13.2.0` → `14.8.1`
- [apps/mobile/lib/main.dart](apps/mobile/lib/main.dart) L108-121 — ajouter Replay options, wrap `SentryWidget`, install 3-prong error boundary
- [services/backend/pyproject.toml](services/backend/pyproject.toml) L27 — tighten `sentry-sdk[fastapi]==2.53.0`
- [services/backend/app/main.py](services/backend/app/main.py) L169-180 — extend global handler trace_id + event_id
- [apps/mobile/lib/services/feature_flags.dart](apps/mobile/lib/services/feature_flags.dart) — refactor `ChangeNotifier` + route-group flags
- **New files Phase 34:** `lefthook.yml`, `tools/checks/no_bare_catch.py`, `no_hardcoded_fr.py`, `accent_lint_fr.py`, `arb_parity.py`, `route_registry_parity.py`, `proof_of_read.py`
- **New files Phase 35:** `tools/dogfood/mint-dogfood.sh`, `tools/dogfood/render_report.py`

---

## References

- [sentry_flutter pub.dev](https://pub.dev/packages/sentry_flutter/versions)
- [Sentry Flutter SDK 9.0 blog](https://blog.sentry.io/introducing-sentrys-flutter-sdk-9-0/)
- [Session Replay Flutter setup](https://docs.sentry.io/platforms/dart/guides/flutter/session-replay/)
- [Session Replay Privacy](https://docs.sentry.io/platforms/dart/guides/flutter/session-replay/privacy/)
- [Flutter SDK overhead](https://docs.sentry.io/platforms/dart/guides/flutter/overhead/)
- [Trace Propagation Flutter](https://docs.sentry.io/platforms/flutter/tracing/trace-propagation/)
- [FastAPI distributed tracing](https://docs.sentry.io/platforms/python/tracing/distributed-tracing/)
- [sentry-sdk PyPI](https://pypi.org/project/sentry-sdk/)
- [go_router 14.8.1 changelog](https://pub.dev/packages/go_router/versions/14.8.1/changelog)
- [Lefthook v2.1.5 release](https://github.com/evilmartians/lefthook/releases)
- [Lefthook docs](https://lefthook.dev/)
- [JAX migration pre-commit → lefthook](https://github.com/jax-ml/jax/issues/32846)
- [Sentry CLI config](https://docs.sentry.io/cli/configuration/)
- [facebook/idb](https://github.com/facebook/idb)
- [GDPR best practices Sentry](https://sentry.io/trust/privacy/gdpr-best-practices/)
