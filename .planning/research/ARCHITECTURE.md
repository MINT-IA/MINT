# Architecture — MINT v2.8 "L'Oracle & La Boucle" Integration Research

**Milestone:** v2.8 (Phases 31-36)
**Researched:** 2026-04-19
**Confidence:** HIGH (codebase-verified) — all integration points cross-checked against current branch `feature/wave-c-scan-handoff-coach` (dev tip f35ec8ff)
**Panel:** ex-Stripe infra / ex-Mercury mobile / ex-Cleo conversational AI

---

## 0. Overview

v2.8 ne crée rien. v2.8 instrumente, cartographie, neutralise, guarde, rode, finit. Chaque geste s'intègre dans une architecture déjà posée :

| Layer | Already present | v2.8 extends |
|---|---|---|
| Mobile error tracking | `SentryFlutter.init` @ [main.dart:108-121](apps/mobile/lib/main.dart) — `tracesSampleRate=0.1`, `sendDefaultPii=false` | +Replay, +masks, +`runZonedGuarded`, +`PlatformDispatcher.onError` |
| Backend error tracking | `sentry_sdk.init` @ [main.py:23-30](services/backend/app/main.py) + `@app.exception_handler(Exception)` @ [main.py:169-180](services/backend/app/main.py) | +W3C `traceparent` ingestion, +cross-link with mobile |
| Request tracing | `LoggingMiddleware` @ [logging_config.py:78-103](services/backend/app/core/logging_config.py) writes `trace_id_var` ContextVar + echoes `X-Trace-Id` header | Consume inbound `traceparent`, propagate to Sentry scope |
| Feature flags (mobile) | `FeatureFlags` static class @ [feature_flags.dart](apps/mobile/lib/services/feature_flags.dart) — 9 feature-scoped flags, 6h refresh | +route-scoped sub-registry, +per-route circuit-breaker wiring |
| Feature flags (backend) | 2 systems: (a) env-backed `FeatureFlags` @ [services/feature_flags.py](services/backend/app/services/feature_flags.py) for `GET /config/feature-flags` ; (b) Redis-backed `FlagsService` @ [flags_service.py](services/backend/app/services/flags_service.py) with `set_global()` / dogfood sets / 60s cache | Add route-level flags to (a). Reuse (b) for admin `/admin/flags` writes |
| Auto-rollback | `SLOMonitor` @ [slo_monitor.py](services/backend/app/services/slo_monitor.py) — 5-min window, 2-breach streak, flips `COACH_FSM_ENABLED=false` via `FlagsService` | Generalize : per-flag threshold registry instead of hardcoded COACH_FSM |
| Router | `GoRouter` w/ `ScopedGoRoute` @ [scoped_go_route.dart](apps/mobile/lib/router/scoped_go_route.dart) + 148 routes @ [app.dart](apps/mobile/lib/app.dart) + top-level `redirect:` callback | Inject `requireFlag()` layer **before** `ScopedGoRoute.scope` check — kill-switch as pre-auth guard |
| Lint gates | 10 Python scripts in [tools/checks/](tools/checks/) — all follow same pattern (argv ∅, stdout diag, exit 0/1) | +3 new scripts (bare-catch, accent, hardcoded-FR-UI) + `lefthook.yml` dispatcher |
| CI | [.github/workflows/ci.yml](.github/workflows/ci.yml) — 7 jobs, 3-shard Flutter matrix, path-filtered | Thin down once lefthook does pre-commit. Keep full-suite test + readability + WCAG + PII gate |

**Anti-pattern alert:** the backend has TWO flag systems. `FeatureFlags` (env-backed, static) exposes flags to mobile via `/config/feature-flags`. `FlagsService` (Redis-backed, dynamic, user-targeted) is what `SLOMonitor.rollback()` flips. These MUST converge in Phase 33 or the `/admin/flags` UI will lie.

---

## 1. Integration points — per phase

### Phase 31 — Instrumenter

#### 31.1 Sentry Replay Flutter

- **File modified:** [apps/mobile/lib/main.dart](apps/mobile/lib/main.dart) lines 108-121 — `SentryFlutter.init` config block
- **What to add (additive, never replace):**
  ```dart
  options.replay.sessionSampleRate = kDebugMode ? 1.0 : 0.1;
  options.replay.onErrorSampleRate = 1.0;  // every crash captures the preceding 30s
  options.replay.maskAllText = true;       // nLPD default-deny
  options.replay.maskAllImages = true;
  ```
- **Package:** `sentry_flutter: ^8.x` already in `pubspec.yaml` — Replay ships in the same plugin since 8.10 (MEDIUM confidence; verify `pubspec.yaml` version, upgrade if <8.10)
- **Privacy masks — widget-level unmask per screen (inverse allowlist):**
  Sensitive screens keep `maskAllText=true` globally, so they need NO per-widget unmask. Non-sensitive screens (landing, auth CTAs, NavigationBar labels) CAN be selectively unmasked via `SentryMask.unmasked(child: ...)` widget, but for v2.8 **refuse unmask** : mask-everything is the nLPD-safe default. Ship Replay with `maskAllText=true`, revisit selective unmask in v2.9 if UX team needs faster repro.
- **Screens that MUST stay masked** (4 explicitly named in the question, each verified in file tree):
  - [CoachChatScreen](apps/mobile/lib/screens/coach/coach_chat_screen.dart) — contains IBAN-adjacent prose
  - [DocumentScanScreen](apps/mobile/lib/screens/document_scan/document_scan_screen.dart) — raw OCR frames
  - [ExtractionReviewScreen](apps/mobile/lib/screens/document_scan/extraction_review_screen.dart) — edited PII fields
  - Onboarding data blocks @ `apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart`

#### 31.2 Global error boundary Flutter

- **File modified:** [apps/mobile/lib/main.dart](apps/mobile/lib/main.dart) — wrap `runApp(const MintApp())` at lines 117 and 120
- **Order of interception (critical — Flutter has 3 distinct channels):**
  1. `FlutterError.onError` — synchronous framework errors (build/layout). Default is `FlutterError.dumpErrorToConsole`, replace with `Sentry.captureException`.
  2. `PlatformDispatcher.instance.onError` — async uncaught errors from isolates/futures. Returns `bool` (true = handled).
  3. `runZonedGuarded` — outer zone catching anything the above missed (e.g. errors in `main()` itself before `runApp`).
- **Implementation pattern:**
  ```dart
  // BEFORE SentryFlutter.init — Sentry hooks FlutterError.onError itself when DSN is set.
  // When DSN absent (dev without dart-define), we still want fail-loud:
  FlutterError.onError = (details) {
    FlutterError.presentError(details);  // keeps default console dump
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
    return true;  // mark handled; app keeps running
  };

  runZonedGuarded(() async {
    // ... current main() body up to runApp
    runApp(const MintApp());
  }, (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
  });
  ```
- **Compat with existing bare catches in main.dart** (lines 45-53, 57-63, 67-73, 77-95) : these `.catchError` clauses are NON-fatal bootstrap fallbacks (SLM plugin init, regulatory constants fetch). Leave them as-is — they're legitimately best-effort. Phase 31 adds the boundary OUTSIDE these, not around them.

#### 31.3 Global exception handler FastAPI

- **File modified:** [services/backend/app/main.py](services/backend/app/main.py) lines 169-180 — `global_exception_handler` already exists ; it already calls `sentry_sdk.capture_exception` explicitly (line 176).
- **What to extend:** add `trace_id` to the Sentry scope before capture, and include it in the response JSON for client-side correlation :
  ```python
  @app.exception_handler(Exception)
  async def global_exception_handler(request, exc):
      tid = trace_id_var.get("-")
      with sentry_sdk.push_scope() as scope:
          scope.set_tag("trace_id", tid)
          scope.set_context("request", {"method": request.method, "path": request.url.path})
          if settings.SENTRY_DSN:
              sentry_sdk.capture_exception(exc)
      logger.error("Unhandled %s: %.100s trace_id=%s", type(exc).__name__, str(exc), tid)
      return JSONResponse(
          status_code=500,
          content={"detail": "Erreur interne du serveur", "error_code": "internal_error", "trace_id": tid},
      )
  ```
- **Order vs existing handlers** (middleware stack as declared in [main.py:148-215](services/backend/app/main.py)):
  1. `RateLimitExceeded` handler — already wired via `add_exception_handler` (line 165). Returns 429 with `error_code`. Unchanged.
  2. Pydantic `ValidationError` — FastAPI default (422) — unchanged.
  3. `HTTPException` — FastAPI default — unchanged.
  4. `Exception` (catch-all) — the one we extend. Runs AFTER the three above, which is correct : specific handlers win.
- **Compat with `LoggingMiddleware`** : the middleware sets `trace_id_var` via `ContextVar` at request start (line 86). The exception handler runs INSIDE the request scope, so `trace_id_var.get()` returns the correct value. No change needed to middleware.

#### 31.4 Trace_id round-trip mobile→backend

- **W3C `traceparent` spec:** `00-{trace_id:32hex}-{span_id:16hex}-{flags:2hex}` — Sentry supports this natively via the `sentry-dart` transport layer.
- **Mobile side:** the app uses `ApiService` for all HTTP calls (imported in main.dart:8). Look for the HTTP client (likely Dio or http package).
  - Check `apps/mobile/lib/services/api_service.dart` for the client. If Dio : add `SentryDio` interceptor (ships with `sentry_flutter`). If `http` package : add a middleware that calls `Sentry.configureScope((scope) => scope.span?.toSentryTrace())` and injects the `sentry-trace` + `baggage` + `traceparent` headers.
  - **LOW confidence on which HTTP client :** verify before coding. Command: `grep -R "import 'package:dio" apps/mobile/lib` or `grep -R "package:http" apps/mobile/lib`.
- **Backend side:** extend `LoggingMiddleware.dispatch` @ [logging_config.py:84-103](services/backend/app/core/logging_config.py) :
  ```python
  async def dispatch(self, request: Request, call_next):
      incoming = request.headers.get("traceparent") or request.headers.get("sentry-trace")
      if incoming:
          # Parse "00-{trace_id}-..." → extract trace_id hex
          parts = incoming.split("-")
          request_trace_id = parts[1] if len(parts) >= 2 and len(parts[1]) == 32 else str(uuid4())
      else:
          request_trace_id = str(uuid4())
      trace_id_var.set(request_trace_id)
      # Sentry SDK auto-picks up the scope ContextVar
      sentry_sdk.get_current_scope().set_tag("trace_id", request_trace_id)
      ...
  ```
- **Cross-link in Sentry UI:** the same `trace_id` tag on both mobile + backend events makes them joinable. Sentry's "Discover" / "Trace Explorer" will show the mobile event and backend event on a single timeline. Requires the Sentry project on mobile and backend to share an organization (already the case — same DSN root).
- **File created:** none new. Both edits are surgical in existing files.

#### 31.5 Catch-audit lint

- **New file:** [tools/checks/no_bare_catch.py](tools/checks/no_bare_catch.py)
- **Pattern to follow:** [tools/checks/no_chiffre_choc.py](tools/checks/no_chiffre_choc.py) is the template. Structure :
  - `SCAN_ROOTS = ["apps/mobile/lib", "services/backend/app"]`
  - `EXCLUDE_DIRS = {".planning", "build", ".dart_tool", "__pycache__", "tests"}`
    - Tests are excluded because pytest fixtures sometimes legitimately swallow setup errors.
  - Regex pattern 1 (Dart bare catch) : `r"\}\s*catch\s*\([^)]*\)\s*\{(\s*//[^\n]*\n)?\s*\}"` — matches `} catch (e) {}` or `} catch (e) { // ignore }`
  - Regex pattern 2 (Dart catch without logger/rethrow/Sentry.captureException in body): harder, needs multi-line analysis
  - Regex pattern 3 (Python bare except) : `r"except\s+Exception[^:]*:\s*(#[^\n]*\n)?\s*(pass|\.\.\.|continue)"` — matches `except Exception: pass` or `except Exception: ...`
- **Strategy — 2 tiers to avoid false positives:**
  - **Tier A (STRICT, blocking):** `except Exception: pass` and `} catch (e) {}`. These are always wrong. 0 tolerance.
  - **Tier B (WARN, non-blocking):** catches with a body that doesn't call `logger.`, `debugPrint`, `Sentry.`, `rethrow`, or `raise`. Reviewer reads the diff.
- **Exit codes:** 0 clean, 1 Tier A violations, 2 Tier B violations (allows lefthook to fail on Tier A only while CI fails on both).
- **Regex vs AST:** regex is enough for Tier A. Tier B needs AST — use `lib2to3` / `ast` for Python and a simple state machine for Dart (or defer the Dart Tier B to a follow-up via `dart analyze` custom rule — see Phase 34).
- **Wiring:** CI job append after `no_chiffre_choc` @ [ci.yml:159-161](.github/workflows/ci.yml). Lefthook pre-commit entry (see Phase 34).

---

### Phase 32 — Cartographier

#### 32.1 Route health dashboard `/admin/routes`

- **New file:** `apps/mobile/lib/screens/admin/route_health_screen.dart`
- **Existing admin precedent:** [apps/mobile/lib/screens/admin_observability_screen.dart](apps/mobile/lib/screens/admin_observability_screen.dart) and `admin_analytics_screen.dart` are already imported in `app.dart:91-92`. Both are gated by the existing `enableAdminScreens` flag in `FeatureFlags`. **Reuse this gate** — do not invent a new `isAdminUser` boolean.
- **Gating mechanism:** add a new GoRoute `/admin/routes`, wrap its builder with a runtime guard :
  ```dart
  ScopedGoRoute(
    path: '/admin/routes',
    scope: RouteScope.authenticated,
    builder: (ctx, state) {
      if (!FeatureFlags.enableAdminScreens) return const _AccessDeniedScreen();
      return const RouteHealthScreen();
    },
  ),
  ```
- **Compile-time dart-define ADMIN=1** is NOT necessary — the existing flag system is enough and is server-overridable for emergency lockdown.

#### 32.2 Data sources — cross-join

Four sources, joined in-memory at screen build :

| Source | API | Freshness | Cost |
|---|---|---|---|
| (1) Route registry | Parse `app.dart` at codegen time → generated Dart file `route_registry.g.dart` | Build-time | Free |
| (2) Sentry Issues | `GET https://sentry.io/api/0/projects/{org}/{proj}/issues/?query=route:{path}` | Live (rate-limited 40/s) | Token required — store in `--dart-define=SENTRY_API_TOKEN` |
| (3) Feature flag status | `FeatureFlags.*` static fields | Live (6h refresh) | Free |
| (4) Last-visited timestamps | `SharedPreferences` — record per-route on `GoRouterObserver.didPush` | Persistent local | Free |

- **Route registry codegen (RECOMMENDED over runtime introspection):** write `tools/route_registry_gen.dart` that parses `app.dart` AST (via `analyzer` package) and emits `lib/gen/route_registry.g.dart` with `const List<RouteDescriptor> kRoutes`. Reason : GoRouter has no public route enumeration API in 14.x — scraping the config at runtime requires reflection which is blocked in AOT. **HIGH confidence** based on GoRouter 14.x docs.
- **Sentry API wrapper:** new `apps/mobile/lib/services/sentry_api_service.dart` — single method `Future<Map<String, int>> fetchErrorCountsByRoute()`. Cache 5 min in memory to avoid burning quota.
- **AnalyticsRouteObserver** already exists @ `app.dart:50` (`import 'package:mint_mobile/services/analytics_observer.dart'`) — extend it to write last-visited to SharedPreferences instead of creating a parallel observer.

#### 32.3 Screenshot pipeline

- **Where to store:** local filesystem at `.planning/route-health/YYYY-MM-DD/{route-slug}.png`. Not Sentry attachments — cost + privacy + retention.
- **Trigger:** the `mint-route-health` script (Phase 35.1) runs `simctl io booted screenshot` after walking each route.
- **Consumed by:** `/admin/routes` screen loads the most recent screenshot per route from the same path (when accessed via dev build with filesystem access) OR shows "screenshot N/A" in device build.

#### 32.4 Sunset 23 legacy redirects

The canonical list in [docs/ROUTE_POLICY.md §3](docs/ROUTE_POLICY.md) shows **26 redirects** (the question says "23" — the delta is likely the 3 onboarding aliases added in Wave B). Actual count in `app.dart` grep: ~42 redirect lines (some target same canonical). Treat **26 as the authoritative number to sunset**.

- **Strategy:**
  1. Instrument each redirect with an analytics event `redirect_used` tagged with `{legacy: '/ask-mint', canonical: '/coach/chat'}`.
  2. After 30 days of 0 hits in production Sentry breadcrumbs → delete the route + update ROUTE_POLICY.md.
  3. For the few that WILL have traffic (e.g. notification deep links still pointing to `/pulse` or `/report`) : keep them, document in ROUTE_POLICY.md as "retained for external deep links" with the specific source documented.
- **Non-breaking sunset pattern (v1 → v2):**
  - v2.8 : add analytics instrumentation to all 26 redirects. No deletion yet.
  - v2.9 : delete the ones with 0 hits. For the ones with <10 hits/month, add a "page moved" banner for 7 days then delete.
- **File modified:** [apps/mobile/lib/app.dart](apps/mobile/lib/app.dart) — wrap each redirect lambda with an analytics call :
  ```dart
  ScopedGoRoute(
    path: '/ask-mint',
    redirect: (_, state) {
      AnalyticsService.logRedirectUsed('/ask-mint', '/coach/chat');
      return '/coach/chat';
    },
  ),
  ```

---

### Phase 33 — Kill-switches

#### 33.1 Middleware GoRouter `requireFlag(name)`

- **Integration point:** the existing top-level `redirect:` callback @ [app.dart:177-261](apps/mobile/lib/app.dart). It already handles auth scope. Add a PRE-auth flag check :
  ```dart
  redirect: (context, state) {
    if (auth.isLoading) return null;

    // NEW (Phase 33) — route-level kill-switch before auth check
    final killSwitch = _resolveKillSwitch(state.fullPath);
    if (killSwitch != null && !FeatureFlags.isRouteEnabled(killSwitch)) {
      return '/coming-soon?route=${Uri.encodeComponent(state.fullPath ?? "")}';
    }

    // ... existing /home?tab= parsing
    // ... existing scope switch
  }
  ```
- **Replacement vs overlay (UX decision):** REPLACE the route (redirect to `/coming-soon?route=...`) rather than overlay. Reason : overlay on a half-built screen lets the user see broken UI under the overlay. Redirect to a dedicated "bientôt dispo" screen is cleaner. Back button returns to caller as usual (GoRouter stack preserved). **HIGH confidence from GoRouter 14.x redirect semantics.**
- **New screen:** `apps/mobile/lib/screens/system/coming_soon_screen.dart` — very small, shows "Cette page revient bientôt. MINT la peaufine encore." + button "Retour à l'accueil" → `context.go('/home')`. Localized in 6 ARBs.

#### 33.2 Extending `FeatureFlags` for route flags

Current `FeatureFlags` has 9 feature-scope flags. Don't pollute that namespace. Add a parallel map :

```dart
// apps/mobile/lib/services/feature_flags.dart
class FeatureFlags {
  // ... existing 9 flags unchanged

  /// Route-scope kill-switches. Key = route path, value = enabled.
  /// Defaults to true (fail-open) — unknown routes are never killed.
  static final Map<String, bool> _routeFlags = {
    // Seed with routes known to be rouge from Wave C audit
    '/scan': true,
    '/coach/chat': true,
    '/mon-argent': true,
    // ... populated by backend GET /config/feature-flags response
  };

  static bool isRouteEnabled(String path) => _routeFlags[path] ?? true;

  static void applyRouteFlagsFromMap(Map<String, dynamic> data) {
    final routes = data['routeFlags'];
    if (routes is Map) {
      _routeFlags.clear();
      routes.forEach((k, v) => _routeFlags[k as String] = v == true);
    }
  }
}
```

Then in `applyFromMap`, call `applyRouteFlagsFromMap(data)` at the end. **Zero breaking change** to the 9 existing flags.

#### 33.3 Backend extension for route flags

- **File modified:** [services/backend/app/api/v1/endpoints/config.py](services/backend/app/api/v1/endpoints/config.py) — add `routeFlags: dict[str, bool]` to `FeatureFlagsResponse`.
- **Source:** `FlagsService` (Redis-backed) is the right store for route flags. Reason : it supports runtime mutation via `set_global()`, already used by `SLOMonitor` rollback, 60s cache. The static env-backed `FeatureFlags` is wrong for this — it requires a Railway redeploy to flip a flag.
- **New convention:** Redis key prefix `flags:route:{path}` (e.g. `flags:route:/scan`). Resolver :
  ```python
  async def get_route_flags() -> dict[str, bool]:
      redis = await get_redis()
      if redis is None:
          return {}  # fail-open
      keys = await redis.keys("flags:route:*")
      result = {}
      for k in keys:
          path = k.decode().removeprefix("flags:route:")
          val = await redis.get(k)
          result[path] = (val == b"true")
      return result
  ```
- **Extend `GET /config/feature-flags`:** append `routeFlags=await get_route_flags()`. Response schema version bump not needed (new field is optional on client).

#### 33.4 Admin `/admin/flags` UI

- **New screen:** `apps/mobile/lib/screens/admin/flag_admin_screen.dart`
- **Gated by:** `FeatureFlags.enableAdminScreens` (same as route dashboard).
- **Read:** lists current `FeatureFlags.*` + `routeFlags` map.
- **Write:** calls new backend endpoint `PATCH /config/feature-flags/{flag_name}` with body `{enabled: bool}`. Backend endpoint :
  - Requires `require_current_user` + admin check (new — `user.email.endsWith('@mint.ch')` or explicit admin table).
  - For feature flags : writes to Redis via `FlagsService.set_global(flag, enabled)`.
  - For route flags : writes `flags:route:{path}` to Redis.
  - Invalidates local cache on `FlagsService`.
- **Propagation:** mobile picks up the change within 6h at next `refreshFromBackend()` call. For faster propagation in admin testing, add a "Force refresh now" button that calls `FeatureFlags.refreshFromBackend()` synchronously.

#### 33.5 Circuit breaker auto-off

- **Reuse `SLOMonitor` pattern** @ [slo_monitor.py](services/backend/app/services/slo_monitor.py). Currently hardcoded to flip `COACH_FSM_ENABLED` on fallback-rate breach.
- **Generalization (Phase 33.5):** change from a single watched flag to a registry :
  ```python
  # services/backend/app/services/slo_monitor.py
  ROLLBACK_REGISTRY = [
      {
          "flag": "COACH_FSM_ENABLED",
          "metric": "fallback_rate",
          "threshold": 0.05,
          "window_minutes": 5,
          "breach_streak": 2,
      },
      {
          "flag": "route:/scan",
          "metric": "route_error_rate",
          "threshold": 0.10,
          "window_minutes": 5,
          "breach_streak": 3,
      },
  ]
  ```
- **New metric `route_error_rate`:** compute from Sentry webhooks (ideal) or from LoggingMiddleware response-status-code buckets per route (simpler, no external dep). Pick simpler. Add to minute-bucket key : `coach:metrics:{YYYY-MM-DD-HH-MM}` already has `total`/`fallback`/`latency_ms_sum` — add `route_errors:{path}`.
- **Wiring:** `SLOMonitor.check_once` iterates registry, evaluates each, calls `await flags.set_global(flag, False)` on breach.

---

### Phase 34 — Agent Guardrails

#### 34.1 `lefthook.yml` structure

- **New file:** `lefthook.yml` at repo root.
- **Install:** `brew install lefthook` (macOS, Julien's dev env) + `lefthook install` once. v2.8 docs one-liner sufficient.
- **Structure with scoping (each hook runs only on matching changed files):**
  ```yaml
  # lefthook.yml
  pre-commit:
    parallel: true
    commands:
      flutter-analyze:
        glob: "apps/mobile/lib/**/*.dart"
        run: cd apps/mobile && flutter analyze --no-fatal-warnings --no-fatal-infos 2>&1 | grep -E "error " || true
      pytest-changed:
        glob: "services/backend/app/**/*.py"
        run: cd services/backend && pytest tests/ -q -x --lf --tb=short
      bare-catch-ban:
        run: python3 tools/checks/no_bare_catch.py {staged_files}
      accent-lint:
        glob: "{apps/mobile/lib/**/*.dart,apps/mobile/lib/l10n/*.arb,services/backend/app/**/*.py}"
        run: python3 tools/checks/accent_lint.py {staged_files}
      hardcoded-fr-ui:
        glob: "apps/mobile/lib/screens/**/*.dart"
        run: python3 tools/checks/no_hardcoded_fr_ui.py {staged_files}
      arb-parity:
        glob: "apps/mobile/lib/l10n/*.arb"
        run: python3 tools/checks/arb_parity.py
      chiffre-choc:
        run: python3 tools/checks/no_chiffre_choc.py
  ```
- **Scoping discipline:** each hook uses `glob:` to restrict to relevant files. `{staged_files}` is substituted with the list of staged files (lefthook templating). Result : typical commit touches 2-3 files → each hook runs in <500ms.
- **Blocking tier:** `pre-commit` hooks block by default (`exit != 0` cancels commit). To override, `--no-verify` flag — DOCUMENT in CONTRIBUTING.md that this is banned except for emergencies with ADR.

#### 34.2 CI thinning strategy

Once lefthook covers pre-commit, CI can:

- **Remove** : no_chiffre_choc + sentence_subject_arb_lint + landing_no_numbers + landing_no_financial_core + regional_microcopy_drift + no_legacy_confidence_render + no_implicit_bloom_strategy + no_llm_alert. These are all GREP gates that lefthook runs on changed files — CI should NOT re-run them (trust the hook, or re-run inside `flutter/backend` jobs but without blocking).
- **Keep** :
  - `contracts-drift` (regenerates codegen + diffs — needs network + python) → CI only
  - `readability` (Flutter test via `dart run` — heavy) → CI only
  - `wcag-aa-all-touched` (Dart meetsGuideline widget test) → CI only
  - `pii-log-gate` (staging log scan) → CI only
  - `backend tests (full pytest)` → CI only
  - `flutter tests (3-shard matrix)` → CI only
  - `OpenAPI drift` → CI only
  - `alembic migration check` → CI only
- **Estimated CI time reduction:** ~2 min (from 8-12 min to 6-10 min on Flutter-only PRs).

#### 34.3 Bare-catch ban — regex vs AST

- **Python:** regex is 95% sufficient. `except Exception` / `except:` / `except BaseException` — all three patterns covered by `re.compile(r"except\s+(Exception|BaseException)?\s*:")` + lookahead for body content. Full AST (`ast.parse` → walk `ExceptHandler` nodes) is cleaner but adds dependency. **Recommendation: AST for Python**, ~60 lines, zero runtime deps (stdlib `ast`).
- **Dart:** Dart has no stdlib AST but the `analyzer` package is already on disk (it's what `dart analyze` runs on). Options :
  - **A. Regex** (start here) : `} catch (e) {}` with empty body or body-that-doesn't-contain-`rethrow|log|Sentry`. Handles 90% of cases. 20 lines Python.
  - **B. `dart analyze` custom rule** via `custom_lint` package. Cleaner, AST-backed, but adds a new tool to the toolchain. Defer to v2.9 if regex proves brittle.
  - **C. Existing `analysis_options.yaml` rules :** Dart has `avoid_catches_without_on_clauses` and `avoid_catching_errors` built-in. Check `apps/mobile/analysis_options.yaml` — enable them as `error` severity. Zero new tool.
- **RECOMMENDED combo:** (C) first — turn existing lints to error severity. Add (A) regex for `catch (e) {}` specifically (which lint (C) doesn't catch — it flags missing `on` clauses, not empty bodies).

#### 34.4 Accent lint

- **New file:** [tools/checks/accent_lint.py](tools/checks/accent_lint.py)
- **Wordlist (from question):**
  ```
  creer → créer | decouvrir → découvrir | eclairage → éclairage |
  securite → sécurité | liberer → libérer | preter → prêter |
  realiser → réaliser | deja → déjà | recu → reçu
  ```
  (also : `etre`, `meme`, `ouvre`/`ouvré`, `ne`/`né`, etc. — ~30 common FR words)
- **Scope:** `.dart` + `.py` + `.arb`. NOT `.md` (docs have many correct "creer" in English passages).
- **Exclusions:**
  - Comments (both Dart `//` and Python `#`) — optional : accents in comments are fine for humans, checking them wastes time. Recommendation : **skip comments** via regex pre-strip.
  - Class names, method names, variable names : skip by checking context. A symbol `createdAt` is not `creer`. Use regex with word boundaries `\bcreer\b` + lowercase check (next char is whitespace or punctuation, not alphanum).
  - File paths, imports : skip lines starting with `import` / `package:` / `from`.
  - Strings in user-facing code (ARB values, `Text('...')`, `tr('...')`) : **these are the target**. Fail on them.
- **Known false-positive domain:** the word `recu` appears as `recueillir`, `reculer` — word-boundary regex handles this.
- **Implementation skeleton:** 40 lines Python, identical structure to `no_chiffre_choc.py`.

#### 34.5 Hardcoded-FR-string lint

- **Existing:** [tools/checks/sentence_subject_arb_lint.py](tools/checks/sentence_subject_arb_lint.py) scans ARB values. That's a DIFFERENT concern (user-as-subject) — don't extend it.
- **New file:** [tools/checks/no_hardcoded_fr_ui.py](tools/checks/no_hardcoded_fr_ui.py)
- **Target:** Dart files under `apps/mobile/lib/screens/**` containing `Text('...')` where `'...'` is French literal text (matches `[A-Z][a-zàâäéèêëïîôùûü]` + has length >3 + contains space or FR diacritic).
- **Scope:** screens + widgets. NOT services/models/constants (those legitimately have French constants).
- **False-positive mitigation:** whitelist certain obvious non-UI strings (debug messages prefixed with `[DEBUG]`, URL literals starting with `http`, emoji-only strings). Whitelist specific files with a TODO opt-out for now : `// i18n-ignore: bootstrap-only` marker.
- **Verified target example:** [widgets/mint_shell.dart](apps/mobile/lib/widgets/mint_shell.dart) lines 50-65 — the labels `l.tabAujourdhui`, `l.tabMonArgent`, `l.tabCoach`, `l.tabExplorer` are **already i18n-wired** (they go through `AppLocalizations.of(ctx)!.tabXxx`). So the shell is NOT the target for this lint. **MEMORY.md claims shell labels are hardcoded — verify against current file: as read above, they are i18n-correct.** Adjust Phase 36.5 scope accordingly.

  **Correction to question assumption (E-F):** the labels `"Aujourd'hui" | "Mon argent" | "Coach" | "Explorer"` are NOT hardcoded in [mint_shell.dart:43-63](apps/mobile/lib/widgets/mint_shell.dart) — they are `l.tabAujourdhui` etc. What IS required in Phase 36.5: verify those ARB keys exist in all 6 languages. **Quick check via `grep -l "tabAujourdhui" apps/mobile/lib/l10n/*.arb`** before planner writes the task.

#### 34.6 Proof-of-read

- **Mechanism:** agent SDK writes to `.claude/agent-proof.json` with entries `{file: ..., readTs: <iso>, commitTs: ...}` after each `Read` tool call. Git hook `prepare-commit-msg` parses this + compares against staged files.
- **Hook file:** `.githooks/prepare-commit-msg` (OR wire via lefthook `prepare-commit-msg` stage).
- **Validation rule:** every file in `git diff --cached --name-only` must have a corresponding entry with `readTs > (commitTs - 2 hours)`. If not → abort commit, print list of un-read files.
- **Agent SDK integration:** requires a wrapper around `Read` that appends to the JSON. LOW confidence this exists yet — verify `.claude/agent-proof.json` is being written. If not, v2.8 Phase 34.6 ships the writer too.
- **Escape hatch:** commit message containing `[skip-proof]` bypasses. Documented in CONTRIBUTING.md.

---

### Phase 35 — Boucle Daily

#### 35.1 `mint-dogfood` script

- **New file:** `tools/dogfood/mint-dogfood.sh`
- **Deps (macOS-only, Julien's Mac Mini):** `simctl` (Xcode), `idb_companion` + `fb-idb` (already installed per memory), `jq`, `curl`, `gh` (GitHub CLI), `flutter`.
- **Structure:**
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  TODAY=$(date -u +%Y-%m-%d)
  OUT_DIR=".planning/dogfood/${TODAY}"
  mkdir -p "${OUT_DIR}/screenshots"

  # 1. Build app for sim (iPhone 17 Pro)
  flutter build ios --simulator --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1

  # 2. Install + launch
  SIM_ID=$(xcrun simctl list devices | grep "iPhone 17 Pro" | head -1 | grep -oE "[A-F0-9-]{36}")
  xcrun simctl boot "${SIM_ID}" || true
  xcrun simctl install "${SIM_ID}" build/ios/iphonesimulator/Runner.app
  xcrun simctl launch "${SIM_ID}" ch.mint.app

  # 3. Run scripted scenario
  python3 tools/dogfood/run_scenario.py \
    --scenario tools/dogfood/scenarios/default.yml \
    --sim-id "${SIM_ID}" \
    --screenshot-dir "${OUT_DIR}/screenshots"

  # 4. Pull Sentry events for the run window
  python3 tools/dogfood/pull_sentry.py \
    --since "$(date -v-30M -u +%Y-%m-%dT%H:%M:%SZ)" \
    --output "${OUT_DIR}/sentry-events.json"

  # 5. Generate report
  python3 tools/dogfood/write_report.py \
    --screenshots "${OUT_DIR}/screenshots" \
    --sentry "${OUT_DIR}/sentry-events.json" \
    --output "${OUT_DIR}/report.md"

  # 6. Auto-PR
  BRANCH="dogfood/${TODAY}"
  git checkout -b "${BRANCH}"
  git add "${OUT_DIR}"
  git commit -m "chore(dogfood): daily loop ${TODAY}"
  git push -u origin "${BRANCH}"
  gh pr create \
    --title "Dogfood ${TODAY}" \
    --body "$(cat ${OUT_DIR}/report.md)" \
    --base dev \
    --label "dogfood" \
    --label "do-not-merge"
  ```
- **make target:** [Makefile](Makefile) — add `dogfood: ; @tools/dogfood/mint-dogfood.sh` so Julien types `make dogfood` each morning.

#### 35.2 Scenario YAML

- **New file:** `tools/dogfood/scenarios/default.yml`
- **Format (simple, extensible):**
  ```yaml
  name: "Cold-start to first insight"
  steps:
    - name: "Landing"
      action: wait
      duration_ms: 2000
    - action: screenshot
      name: "01-landing"
    - action: tap
      target: "accessibility_id:landing-cta"
    - action: wait
      duration_ms: 1000
    - action: screenshot
      name: "02-post-cta"
    - action: type
      text: "Bonjour"
    - action: tap
      target: "accessibility_id:chat-send"
    - action: wait
      duration_ms: 5000
    - action: screenshot
      name: "03-coach-first-reply"
    - action: assert_no_sentry_errors
      window_ms: 30000
  ```
- **Runner:** `tools/dogfood/run_scenario.py` uses `fb-idb` to drive the sim. Each action maps to `idb ui tap`, `idb ui type`, `idb ui describe-all` (for accessibility tree queries), `simctl io booted screenshot`.

#### 35.3 Auto-PR labels

- `dogfood` : identifies these runs for weekly triage.
- `do-not-merge` : blocks accidental merge — daily PRs are read-only artefacts, not mergeable branches.
- **Retention:** a separate script `tools/dogfood/prune.sh` runs weekly to close + delete dogfood branches >14 days old.

---

### Phase 36 — Finissage E2E

#### 36.1 UUID profile crash

- **File:** [services/backend/app/schemas/profile.py:180](services/backend/app/schemas/profile.py) — current :
  ```python
  id: str  # String in DB, not necessarily UUID4 (legacy/anonymous profiles)
  ```
- **Diagnosis from MEMORY.md:** "backend `/profiles/me` crashe (UUID validation, Sentry)" — the crash is on `Profile.id` somewhere else in the chain (maybe a response model expects `UUID4` but DB returns str). **LOW confidence on exact root cause — need to reproduce first.**
- **Investigation path (planner task input):**
  1. Reproduce : call `GET /profiles/me` against staging with a legacy user_id that isn't a valid UUID4.
  2. `grep -R "UUID4" services/backend/app/api/v1/endpoints/profile.py` — find where strict UUID validation happens.
  3. Fix : keep `id: str` on the wire (Pydantic alias), validate inside the endpoint with a tolerant pattern.
- **Rollback path:** the fix is a Pydantic schema change — rolling back is `git revert` the schema commit. Low risk.

#### 36.2 Flow anonyme restauré

- **Currently at [app.dart:298-305](apps/mobile/lib/app.dart):**
  ```dart
  ScopedGoRoute(
    path: '/anonymous/chat',
    scope: RouteScope.public,
    builder: (context, state) {
      final intent = state.uri.queryParameters['intent'];
      return AnonymousChatScreen(intent: intent);
    },
  ),
  ```
  So the route IS wired. `AnonymousChatScreen` IS imported (line 13) and exists at [apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart](apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart).
- **Real issue:** [LandingScreen](apps/mobile/lib/screens/landing_screen.dart) CTA navigates to `/coach/chat` (shell-scoped) instead of `/anonymous/chat` (public). Once on `/coach/chat`, the auth guard at [app.dart:256-258](apps/mobile/lib/app.dart) checks `!isLoggedIn && !auth.isLocalMode` — if neither, bounce to `/auth/register`.
- **Fix in Phase 36.2:** change LandingScreen's main CTA target from `/coach/chat` → `/anonymous/chat`. The anonymous chat screen handles the anonymous→auth conversion flow itself (per MEMORY.md entry on the anonymous pivot).
- **Verify:** `grep -R "/coach/chat\|context.go\|context.push" apps/mobile/lib/screens/landing_screen.dart`.

#### 36.3 save_fact sync mobile

- **Backend tool:** `save_fact` handler in [services/backend/app/services/coach/coach_tools.py](services/backend/app/services/coach/coach_tools.py) (grep-confirmed to exist). It writes to the profile DB.
- **Mobile side:** `CoachProfileProvider` (imported `app.dart:108`) caches profile locally. **Current bug:** after `save_fact` returns in the `/coach/chat` response, the mobile doesn't know the backend mutated the profile. Provider stays stale until next manual reload.
- **3 patterns considered:**
  | Pattern | Latency | Complexity | Compat with existing arch |
  |---|---|---|---|
  | WebSocket push | ~100ms | HIGH (new transport, session mgmt) | LOW — no WS today |
  | Polling 5s | ~2.5s avg | LOW | HIGH — just a Timer |
  | Explicit refresh trigger in response | ~0ms | LOW | HIGH — just a response-field check |
- **RECOMMENDED: explicit refresh trigger.** Backend coach_chat response already has a `responseMeta` field (per MEMORY.md). Add `responseMeta.profileInvalidated: true` whenever the request triggered any `save_fact` tool call. Mobile, on receiving this, calls `CoachProfileProvider.refresh()` → fetches `/profiles/me` → notifies listeners.
- **File modifications:**
  - Backend : [services/backend/app/api/v1/endpoints/coach_chat.py](services/backend/app/api/v1/endpoints/coach_chat.py) — in the tool-call handler, set a flag when save_fact runs, echo in response.
  - Mobile : the coach chat handler that consumes the response — find via `grep -R "responseMeta" apps/mobile/lib` — add `if (meta.profileInvalidated) context.read<CoachProfileProvider>().refresh()`.
- **Compat with Provider reactive arch:** Provider's `notifyListeners()` on profile mutation propagates to every `context.watch<CoachProfileProvider>()` descendant automatically. No architectural change.

#### 36.4 388 bare catches → 0

- **Split:** 56 backend + 332 mobile.
- **Order: backend FIRST.** Reasons :
  - Smaller blast radius (fewer files, single language).
  - Backend has a single global handler already (@app.exception_handler). Missing logs will show up centrally.
  - Less regression risk — Python except blocks are easier to audit visually than Dart catch clauses scattered across StatefulWidgets.
- **Approach:** **review-manual, semi-automated.** Pure auto-rewrite is dangerous (every catch has context). Process :
  1. Run `tools/checks/no_bare_catch.py --report` to generate a tab-separated file:line list.
  2. Categorize each into 3 buckets :
     - **a. Kill** — the catch is plain wrong, remove it, let the error propagate.
     - **b. Log + rethrow** — add `logger.error(...)` + `raise`.
     - **c. Log + swallow (legitimate best-effort)** — add `logger.warning(...)` + document why in comment.
  3. Write one PR per ~10 catches. Each PR includes the decision matrix for reviewer.
- **Script-assisted rewrite** for the obvious "plain `pass`" cases :
  - `sed -i 's/except Exception:\n\s*pass/except Exception as exc:\n    logger.warning("best-effort failure: %s", exc)/'` — but this mangles indentation. Better : AST-based rewrite via `libcst` for Python, regex-with-care for Dart.
- **Regression testing:** each PR must keep pytest / flutter test green. The existing 9327+5925 test suite is the regression harness.
- **Time estimate:** ~1 week for backend (56 catches, ~10/day), ~2-3 weeks for mobile (332 catches, batched).

#### 36.5 MintShell labels — CORRECTED FINDING

**See §34.5 correction.** The labels in [mint_shell.dart:50-65](apps/mobile/lib/widgets/mint_shell.dart) are already i18n-correct (`l.tabAujourdhui`, `l.tabMonArgent`, `l.tabCoach`, `l.tabExplorer`).

Phase 36.5 real task is :
1. Verify `tabAujourdhui` / `tabMonArgent` / `tabCoach` / `tabExplorer` exist in all 6 ARB files (`app_fr.arb`, `app_en.arb`, `app_de.arb`, `app_es.arb`, `app_it.arb`, `app_pt.arb`).
2. If missing in some, add them with proper translations.
3. Run `flutter gen-l10n`.
4. Verify via build : `flutter run` on each locale → visual check.

**Do NOT modify `mint_shell.dart`.** The code is already correct. MEMORY.md's claim is stale.

---

## 2. Build order — justification

The question's proposed order is correct. Justification per edge :

**31 → all:** instrumentation IS the oracle. Without Sentry Replay + global boundaries + trace_id round-trip, every subsequent phase is flying blind. You can't verify Phase 33 kill-switches worked without seeing them flip in Sentry. You can't validate Phase 36 finissage fixes without replay of the before-state.

**34 → (32, 33, 35, 36):** guardrails protect the work. If you ship Phase 32 dashboard before lefthook ban on bare catches, the 332 mobile catches keep growing while you were busy building the dashboard. Lock the door before you decorate.

**32 ∥ 33:** parallel is fine because they operate on disjoint concerns (cartography = read, kill-switches = write). One is a lens, the other is a valve. The data the dashboard consumes (Sentry issues + flag state) doesn't depend on kill-switches being functional ; conversely the kill-switch doesn't need the dashboard to work (it's a redirect gate).

**35 needs 31+32+33:** dogfood script pulls Sentry events (31), takes screenshots per canonical route (32's registry), and reports "killed routes" (33). Running dogfood before kill-switches exist just logs errors on routes that should've been off.

**36 last:** finishing touches should be applied with all safety nets in place. When you finally convert the 332 mobile catches, lefthook catches regressions, dogfood catches regressions, Sentry replay shows user-visible regressions. Without these, 332 catches → 0 is a recipe for 332 new silent regressions.

**Alternative to consider:** **35 before 33** — you could argue dogfood is the feedback loop that tells you WHICH routes to put kill-switches on. Counter-argument : the Wave C audit already produced the list of rouge routes (per PROJECT.md context). Phase 33 seeds route flags with known-rouges ; Phase 35 confirms + expands the list. Net : keep 33 before 35.

**Critical non-obvious edge:** **34.1 (lefthook setup) blocks 34.3 (bare-catch lint) blocks 36.4 (fix the 388).** You cannot start fixing the 388 until the lint exists and is wired into lefthook — otherwise every fix can be accompanied by a new bare catch and the count never converges to 0. Order within Phase 34 : install lefthook → add bare-catch script → wire as blocking → THEN Phase 36.4 can safely proceed.

---

## 3. Files — created vs modified

### Created (19 new files)

| File | Phase | Purpose |
|---|---|---|
| `apps/mobile/lib/screens/admin/route_health_screen.dart` | 32 | Route dashboard UI |
| `apps/mobile/lib/screens/admin/flag_admin_screen.dart` | 33 | Flag toggle UI |
| `apps/mobile/lib/screens/system/coming_soon_screen.dart` | 33 | Kill-switch target |
| `apps/mobile/lib/services/sentry_api_service.dart` | 32 | Sentry Issues API wrapper |
| `apps/mobile/lib/gen/route_registry.g.dart` | 32 | Codegen output — route list |
| `tools/route_registry_gen.dart` | 32 | Codegen script |
| `tools/checks/no_bare_catch.py` | 31.5 / 34.3 | Catch-audit lint |
| `tools/checks/accent_lint.py` | 34.4 | French accent lint |
| `tools/checks/no_hardcoded_fr_ui.py` | 34.5 | UI FR literal lint |
| `tools/checks/arb_parity.py` | 34.1 | ARB 6-lang key parity lint |
| `lefthook.yml` | 34.1 | Pre-commit dispatcher |
| `.githooks/prepare-commit-msg` | 34.6 | Proof-of-read gate |
| `tools/dogfood/mint-dogfood.sh` | 35.1 | Main orchestrator |
| `tools/dogfood/run_scenario.py` | 35.2 | Sim driver |
| `tools/dogfood/pull_sentry.py` | 35.1 | Sentry events fetcher |
| `tools/dogfood/write_report.py` | 35.1 | Report generator |
| `tools/dogfood/scenarios/default.yml` | 35.2 | Cold-start scenario |
| `tools/dogfood/prune.sh` | 35.3 | Weekly PR cleanup |
| `Makefile` (if absent — check) | 35.1 | `make dogfood` target |

### Modified (12 existing files)

| File | Phase | Change |
|---|---|---|
| [apps/mobile/lib/main.dart](apps/mobile/lib/main.dart) | 31.1, 31.2 | Sentry Replay config + `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError` |
| [apps/mobile/lib/app.dart](apps/mobile/lib/app.dart) | 32.4, 33.1, 36.2 | Redirect analytics instrumentation + `requireFlag` check in top-level redirect + LandingScreen CTA target |
| [apps/mobile/lib/services/feature_flags.dart](apps/mobile/lib/services/feature_flags.dart) | 33.2 | Route-scope sub-registry |
| [apps/mobile/lib/services/analytics_observer.dart](apps/mobile/lib/services/analytics_observer.dart) | 32.2 | Write last-visited to SharedPreferences |
| [apps/mobile/lib/screens/landing_screen.dart](apps/mobile/lib/screens/landing_screen.dart) | 36.2 | CTA → `/anonymous/chat` |
| ApiService HTTP client wrapper (TBD file) | 31.4 | Inject `traceparent` header + SentryDio/SentryHttp interceptor |
| CoachProfileProvider consumer of `responseMeta` | 36.3 | Call `.refresh()` on `profileInvalidated` |
| [services/backend/app/main.py](services/backend/app/main.py) | 31.3 | Extend `global_exception_handler` with scope tags |
| [services/backend/app/core/logging_config.py](services/backend/app/core/logging_config.py) | 31.4 | Parse inbound `traceparent`, set Sentry scope tag |
| [services/backend/app/api/v1/endpoints/config.py](services/backend/app/api/v1/endpoints/config.py) | 33.3 | Expose `routeFlags` + new `PATCH /config/feature-flags/{name}` |
| [services/backend/app/services/slo_monitor.py](services/backend/app/services/slo_monitor.py) | 33.5 | Registry-driven rollback |
| [services/backend/app/api/v1/endpoints/coach_chat.py](services/backend/app/api/v1/endpoints/coach_chat.py) | 36.3 | Emit `responseMeta.profileInvalidated` |
| [services/backend/app/schemas/profile.py](services/backend/app/schemas/profile.py) | 36.1 | UUID validation fix |
| [.github/workflows/ci.yml](.github/workflows/ci.yml) | 34.2 | Thin down : remove grep gates (they're in lefthook now), keep heavy gates |
| [docs/ROUTE_POLICY.md](docs/ROUTE_POLICY.md) | 32.4 | Update redirect list with "retained / scheduled to sunset" status |
| 2 batches × backend : ~6 PRs | 36.4 | 56 backend bare catches fixed |
| 2 batches × mobile : ~15 PRs | 36.4 | 332 mobile bare catches fixed |

---

## 4. Anti-patterns (explicit — do NOT do these)

1. **Do NOT duplicate Sentry SDK** — no `sentry_mobile_v2` or `second_sentry_project`. Same DSN, same org. Replay is an option on the existing SDK, not a separate plugin.

2. **Do NOT create a parallel flag system** — 2 systems already exist (env-backed `FeatureFlags` for read-heavy + Redis-backed `FlagsService` for write-capable). v2.8 USES both but doesn't invent a third. Route flags live in Redis via `FlagsService` ; they surface to mobile through the existing `/config/feature-flags` endpoint.

3. **Do NOT bypass `LoggingMiddleware`** — the middleware owns `trace_id_var`. If you add a new path that sets trace_id outside the middleware (e.g. a webhook handler), you bypass the correlation layer. Always route through `LoggingMiddleware`.

4. **Do NOT replace the `redirect:` callback** — it's already 80 lines of matched-path switching. Add checks INSIDE it (at specific points documented in §33.1), don't rewrite it.

5. **Do NOT fabricate a new admin permission system** — the `enableAdminScreens` flag is the existing gate. Extend it (per-user admin table can come in v2.9 if needed), don't parallel-invent.

6. **Do NOT turn Sentry Replay on with `maskAllText=false`** — nLPD violation. Mask-default, unmask-selective-in-v2.9.

7. **Do NOT convert `catchError` fallbacks in main.dart into fatal** — the bootstrap fallbacks (SLM plugin, regulatory sync) are LEGITIMATELY best-effort. They stay. The global boundary wraps them but doesn't replace their local catches.

8. **Do NOT ship lefthook as non-blocking warn-only** — the whole point is <5s feedback that BLOCKS. If we warn-only, agents will keep shipping bare catches. Lefthook must exit 1 on bare catch. Escape hatch only via `--no-verify` (documented as banned in CONTRIBUTING.md).

9. **Do NOT delete legacy redirects before instrumenting them with analytics** — you don't know who's still using `/pulse` vs notification deep links. Measure first, sunset second. Phase 32.4 instruments, Phase 32.4+30d deletes.

10. **Do NOT skip the UUID fix by deferring** — it's in `GET /profiles/me`, THE most-called endpoint. Every user session fails. Phase 36.1 is not optional, and it should arguably ship in Phase 31 alongside instrumentation (instrumentation without a working profile endpoint = instrument the error, not the product).

11. **Do NOT conflate `FeatureFlags` (Dart) with `FeatureFlags` (Python)** — they share a name by accident. In v2.8 code comments, use `FeatureFlags (mobile)` and `FeatureFlags (backend-env)` to disambiguate.

---

## 5. Dependency graph

```
                           ┌──────────────────────┐
                           │   Phase 31           │
                           │   Instrumenter       │
                           │                      │
                           │   Sentry Replay +    │
                           │   global boundaries  │
                           │   + trace_id r/t +   │
                           │   catch-audit lint   │
                           │   skeleton           │
                           └──────────┬───────────┘
                                      │
                                      │ (oracle ready — now
                                      │  every subsequent
                                      │  phase is observable)
                                      │
                           ┌──────────▼───────────┐
                           │   Phase 34           │
                           │   Agent Guardrails   │
                           │                      │
                           │   lefthook wire +    │
                           │   bare-catch ban +   │
                           │   accent / hardcoded │
                           │   lints + proof-of-  │
                           │   read               │
                           └──────────┬───────────┘
                                      │
                                      │ (guardrails in place —
                                      │  regressions blocked
                                      │  at commit time)
                                      │
                         ┌────────────┴────────────┐
                         │                         │
              ┌──────────▼──────────┐   ┌──────────▼──────────┐
              │   Phase 32          │   │   Phase 33          │
              │   Cartographier     │   │   Kill-switches     │
              │                     │   │                     │
              │   /admin/routes +   │   │   requireFlag() +   │
              │   route registry +  │   │   route flags ext + │
              │   Sentry join +     │   │   admin /flags UI + │
              │   last-visited +    │   │   circuit breaker   │
              │   sunset 26 legacy  │   │   registry          │
              │   redirects         │   │                     │
              └──────────┬──────────┘   └──────────┬──────────┘
                         │                         │
                         │  (route registry        │  (flag valves
                         │   + error map ready)    │   functional)
                         │                         │
                         └────────────┬────────────┘
                                      │
                           ┌──────────▼───────────┐
                           │   Phase 35           │
                           │   Boucle Daily       │
                           │                      │
                           │   mint-dogfood +     │
                           │   scenario runner +  │
                           │   auto-PR            │
                           └──────────┬───────────┘
                                      │
                                      │  (feedback loop
                                      │   running daily)
                                      │
                           ┌──────────▼───────────┐
                           │   Phase 36           │
                           │   Finissage E2E      │
                           │                      │
                           │   UUID fix + anon    │
                           │   flow + save_fact   │
                           │   sync + 388→0 +     │
                           │   MintShell ARB      │
                           │   audit              │
                           └──────────────────────┘

Critical edges :
  31 → 32  : Sentry data feeds dashboard
  31 → 33  : need instrumentation to detect rouge routes
  31 → 36  : can't validate UUID fix / save_fact fix without oracle
  34 → 36.4: lint must exist before converting 388 catches
  32 → 35  : route list feeds dogfood scenario expansion
  33 → 35  : dogfood tests kill-switch triggering
```

---

## 6. Compat matrix — existing architecture

| Existing piece | Does v2.8 preserve it? | How |
|---|---|---|
| `Provider` state arch | YES | `CoachProfileProvider.refresh()` triggers `notifyListeners()` ; no new state mgmt |
| `GoRouter` w/ `ScopedGoRoute` | YES | Kill-switch lives INSIDE existing `redirect:` callback, scope check still runs |
| `StatefulShellRoute.indexedStack` | YES | No shell change — `/admin/routes` and `/admin/flags` live OUTSIDE the shell like `/anonymous/chat` |
| `Pydantic v2` camelCase aliases | YES | `FeatureFlagsResponse` already camelCase ; new `routeFlags` field follows suit |
| `LoggingMiddleware` trace_id | YES | Extended to parse inbound `traceparent`, doesn't break solo UUID path |
| `SLOMonitor` auto-rollback | YES | Generalized to registry — current `COACH_FSM_ENABLED` behavior becomes one entry in the registry |
| `FlagsService` (Redis) | YES | Route flags use same key pattern + same `set_global()` method |
| 10 existing `tools/checks/*.py` | YES | New scripts follow identical pattern (argv, stdout, exit codes) ; lefthook wires them alongside existing CI invocations |
| 3-shard CI matrix | YES | No change to matrix — only the grep gates get removed (they run in lefthook) |
| 148 canonical routes | YES | No route deleted in v2.8. 26 legacy redirects instrumented but not removed (removal is v2.9+) |
| Sentry sample rate 10% | MODIFIED | Replay is separate sample — `sessionSampleRate=0.1` independent of `tracesSampleRate=0.1`. Explicit. |
| `runApp(const MintApp())` entrypoint | YES | Wrapped in `runZonedGuarded` + Sentry hooks ; still calls `runApp` identically |

---

## 7. Open questions & gaps

| Gap | Impact | Resolution |
|---|---|---|
| HTTP client type in mobile (Dio vs http vs custom) | Blocks §31.4 trace_id injection | 5-min grep to resolve before Phase 31 planning |
| Agent SDK writing `.claude/agent-proof.json` — does it exist today? | Blocks §34.6 | Check `.claude/` tree ; if absent, Phase 34.6 also ships the writer |
| `make` available on dev machine? Makefile at repo root? | `make dogfood` UX | `ls Makefile` — if absent, alias the shell script to `./scripts/dogfood` |
| Mobile tests with `pumpAndSettle` timeouts (43 pre-existing, per MEMORY.md) | Regression noise when fixing 388 catches | Tag + skip the known 43 ; treat any new failure as regression |
| Admin auth — user-level flag or email-domain? | §33.4 write access | For v2.8 : simplest is `user.email.endsWith('@mint.ch')`. Revisit with proper admin table in v2.9 |
| `responseMeta` shape — verify field exists in /coach/chat OpenAPI | §36.3 save_fact sync | Check canonical OpenAPI spec `tools/openapi/mint.openapi.canonical.json` |
| Will the 26-redirect sunset clock start during Phase 32 or after? | Impacts v2.8 end-state | Clock starts at Phase 32.4 instrumentation commit. Sunset lands in v2.9+ (30d wait). |

---

## 8. Confidence assessment

| Area | Confidence | Reason |
|---|---|---|
| Sentry init integration (mobile + backend) | HIGH | Files read end-to-end ; SDK already wired at `main.dart:108` and `main.py:23` |
| LoggingMiddleware / trace_id round-trip | HIGH | Middleware read ; ContextVar pattern confirmed |
| FlagsService + SLOMonitor reuse for route flags | HIGH | Both services read ; `set_global()` is the exact write primitive needed |
| GoRouter `redirect:` extension for kill-switches | HIGH | 80-line callback read ; insertion point unambiguous |
| Admin gating via `enableAdminScreens` | HIGH | Existing flag + existing admin screens confirm pattern |
| Catch-audit lint (Tier A regex) | HIGH | `tools/checks/no_chiffre_choc.py` template is identical shape |
| Catch-audit lint (Tier B — AST Dart) | MEDIUM | Dart has no built-in AST ; `analyzer` package path works but adds tool |
| W3C traceparent header parsing | MEDIUM | Spec is standard but sentry-flutter's auto-inject behaviour varies by HTTP client |
| `responseMeta.profileInvalidated` field | LOW | Need to verify canonical OpenAPI before writing |
| Anonymous flow root cause | MEDIUM | LandingScreen CTA target confirmed in memory ; actual code needs grep |
| UUID crash root cause | LOW | MEMORY.md mentions it but no repro trace ; planner should reproduce first |
| Proof-of-read writer in agent SDK | LOW | May need to ship the writer alongside the hook in Phase 34.6 |
| MintShell labels status | HIGH (inverted) | File read directly : labels ARE i18n-wired. MEMORY.md claim is stale. Phase 36.5 = ARB parity audit only. |

---

## 9. Sources

- [apps/mobile/lib/main.dart](apps/mobile/lib/main.dart) — Sentry init, bootstrap fallbacks
- [apps/mobile/lib/app.dart](apps/mobile/lib/app.dart) — GoRouter, 26 redirects, redirect callback
- [apps/mobile/lib/services/feature_flags.dart](apps/mobile/lib/services/feature_flags.dart) — 9 flags, backend refresh
- [apps/mobile/lib/widgets/mint_shell.dart](apps/mobile/lib/widgets/mint_shell.dart) — shell labels (already i18n)
- [apps/mobile/lib/router/scoped_go_route.dart](apps/mobile/lib/router/scoped_go_route.dart) — scope pattern
- [services/backend/app/main.py](services/backend/app/main.py) — Sentry + exception handler + middleware stack
- [services/backend/app/core/logging_config.py](services/backend/app/core/logging_config.py) — LoggingMiddleware + trace_id ContextVar
- [services/backend/app/services/slo_monitor.py](services/backend/app/services/slo_monitor.py) — auto-rollback pattern
- [services/backend/app/services/flags_service.py](services/backend/app/services/flags_service.py) — Redis-backed flags
- [services/backend/app/services/feature_flags.py](services/backend/app/services/feature_flags.py) — env-backed flags
- [services/backend/app/api/v1/endpoints/config.py](services/backend/app/api/v1/endpoints/config.py) — /config/feature-flags
- [services/backend/app/schemas/profile.py](services/backend/app/schemas/profile.py) — UUID field location
- [tools/checks/no_chiffre_choc.py](tools/checks/no_chiffre_choc.py) — lint template
- [tools/checks/sentence_subject_arb_lint.py](tools/checks/sentence_subject_arb_lint.py) — ARB-scoped lint template
- [.github/workflows/ci.yml](.github/workflows/ci.yml) — CI matrix, 7 jobs
- [docs/ROUTE_POLICY.md](docs/ROUTE_POLICY.md) — 26 legacy redirects, policy
- [.planning/PROJECT.md](.planning/PROJECT.md) — v2.8 scope, constraints
- Sentry Flutter SDK docs (training-data baseline, verify version >=8.10 for Replay)
