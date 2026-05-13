---
phase: 31-instrumenter
plan: 01
subsystem: observability
tags: [sentry, error-boundary, breadcrumbs, sentry-trace, baggage, mobile, wave-1, obs-02, obs-04, obs-05]

# Dependency graph
requires:
  - phase: 31-instrumenter
    plan: 00
    provides: Wave 0 scaffolding (8 Flutter stubs + 3 lints + walker.sh + sentry-cli)
provides:
  - apps/mobile/lib/services/error_boundary.dart (single-source 3-prong boundary + captureSwallowedException)
  - apps/mobile/lib/services/sentry_breadcrumbs.dart (MintBreadcrumbs helper — D-03 4-level categories)
  - Sample rates flipped to D-01 Option C (prod=0.0 / staging=0.10 / dev=1.0, onErrorSampleRate=1.0)
  - D-02 Option A env-tag 3-way split via MINT_ENV dart-define
  - SentryNavigatorObserver in root GoRouter observers (beside AnalyticsRouteObserver)
  - _authHeaders() + _publicHeaders() inject sentry-trace + baggage (D-05 dual-header)
  - 3 breadcrumb surfaces wired (ComplianceGuard validate/validateAlert, CoachProfileProvider.syncFromBackend, FeatureFlags.refreshFromBackend)
  - 11 api_service bypass sites migrated to _publicHeaders() (OBS-04 coverage gap closure)
affects: [31-02, 31-03, 31-04, 35-boucle-daily, 36-finissage-e2e]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Single-source error boundary (identity-keyed reentrancy guard for exactly-once capture per thrown error)
    - D-03 4-level breadcrumb categories (outcome in CATEGORY string, NOT only in SentryLevel — enables Sentry UI `event.category:mint.compliance.guard.pass` search)
    - PII-safe breadcrumb payloads (enum/int/bool only — fuzz-tested against CHF / AVS 756. / IBAN patterns)
    - Dual-header D-05 propagation (sentry-trace primary + baggage + legacy X-MINT-Trace-Id via backend middleware)
    - @visibleForTesting accessors for private static module state (debugAuthHeaders / testOnlyRootRouterObservers)
    - flutter_secure_storage platform-channel mock in tests that touch AuthService

key-files:
  created:
    - apps/mobile/lib/services/error_boundary.dart
    - apps/mobile/lib/services/sentry_breadcrumbs.dart
  modified:
    - apps/mobile/lib/main.dart (installGlobalErrorBoundary + D-01 ternary + MINT_ENV env)
    - apps/mobile/lib/app.dart (extract _routerObservers + add SentryNavigatorObserver + @visibleForTesting accessors)
    - apps/mobile/lib/services/api_service.dart (_authHeaders + _publicHeaders + 11 bypass migrations + _injectSentryTraceHeaders shared helper + debug accessors)
    - apps/mobile/lib/services/coach/compliance_guard.dart (surface param + breadcrumb on every validate/validateAlert exit)
    - apps/mobile/lib/services/feature_flags.dart (refreshFromBackend emits success / failure breadcrumb with error_code enum)
    - apps/mobile/lib/providers/coach_profile_provider.dart (save_fact proxy breadcrumb in syncFromBackend — see deviation)
    - apps/mobile/test/services/error_boundary_test.dart (flipped live)
    - apps/mobile/test/services/error_boundary_ordering_test.dart (flipped live)
    - apps/mobile/test/services/error_boundary_single_capture_test.dart (flipped live)
    - apps/mobile/test/services/sentry_breadcrumbs_test.dart (flipped live)
    - apps/mobile/test/services/sentry_breadcrumbs_pii_test.dart (flipped live + 100-run PII fuzz)
    - apps/mobile/test/services/sentry_breadcrumbs_refresh_test.dart (flipped live)
    - apps/mobile/test/services/api_service_sentry_trace_test.dart (flipped live + secure-storage mock)
    - apps/mobile/test/app_router_observers_test.dart (flipped live via testOnlyRootRouterObservers)

key-decisions:
  - D-01 Option C sample rates deployed as env-dependent ternary (prod 0.0 / staging 0.10 / dev 1.0) — verify_sentry_init presence-only regex tolerates ternary
  - D-02 MINT_ENV dart-define contract published — staging CI/TestFlight builds MUST pass --dart-define=MINT_ENV=staging or be tagged as production
  - D-03 4-level literals locked into sentry_breadcrumbs.dart AND in call sites (compliance_guard / coach_profile_provider / feature_flags) — no `tool` intermediate segment anywhere
  - D-05 trace propagation covers BOTH authenticated AND unauthenticated paths (added _publicHeaders helper — 11 bypass sites migrated)
  - save_fact breadcrumb instrumented at CoachProfileProvider.syncFromBackend proxy point because save_fact is server-side only (no mobile dispatch) — per-factKind attribution deferred to Phase 31-02

patterns-established:
  - Static `@visibleForTesting` accessors on static-state classes (ApiService, app.dart module-level finals) — preferred over making private APIs public for prod
  - beforeBreadcrumb + beforeSend callbacks with return-null drop pattern — standard way to unit-test Sentry instrumentation without network transport
  - Identity-keyed reentrancy guard (`identityHashCode` + `scheduleMicrotask` release) for exactly-once dispatch across multiple handler prongs
  - Shared `_injectSentryTraceHeaders` helper between auth + public header codepaths — single source of propagation semantics

requirements-completed: [OBS-02, OBS-04, OBS-05]

# Metrics
duration: 42min
completed: 2026-04-19
---

# Phase 31 Plan 01: Wave 1 Mobile — Error Boundary + Trace Propagation + Breadcrumbs Summary

**3 atomic commits on `feature/v2.8-phase-31-instrumenter`. 2 new lib files + 6 edits + 8 test files flipped live (15 tests green). 10 VALIDATION rows 31-01-01..10 automated green.**

## CTX31_01_COMMIT_SHA

`CTX31_01_COMMIT_SHA: ccee7fd57b2c37e3c95e51f9d97b0c69d5a03bea`

(HEAD of `feature/v2.8-phase-31-instrumenter` after plan 31-01 Task 3 ships, before plan-metadata commit.)

## MINT_ENV_DART_DEFINE Contract

`MINT_ENV_DART_DEFINE: MINT_ENV`

Phase 35 `tools/simulator/walker.sh` and future `.github/workflows/testflight.yml` / `play-store.yml` builds MUST pass `--dart-define=MINT_ENV=staging` or `--dart-define=MINT_ENV=production` at build time. Default = `production` (via `String.fromEnvironment('MINT_ENV', defaultValue: 'production')` in `apps/mobile/lib/main.dart`). Omitting the dart-define in a staging build will cause Sentry events to be tagged `production` — breaking env filtering per D-02 Option A.

## Accomplishments

- **OBS-02** — single-source 3-prong error boundary shipped
  (`error_boundary.dart`), installed in `main()` BEFORE SentryFlutter.init.
  Private reentrancy guard (identity-keyed + microtask release) enforces
  exactly-once capture across all 3 prongs. `sentry_capture_single_source.py`
  lint now catches any regression mechanically (2 whitelisted hits only).
- **OBS-04** — sentry-trace + baggage propagation live on ALL mobile HTTP
  calls. `_authHeaders()` + new `_publicHeaders()` share a single
  `_injectSentryTraceHeaders` helper. 11 bypass sites migrated
  (the revision-critical coverage gap is closed).
- **OBS-05** — `SentryNavigatorObserver()` added beside
  `AnalyticsRouteObserver()` in the root GoRouter observers list.
  3 breadcrumb surfaces wired with D-03 4-level categories:
  ComplianceGuard validate/validateAlert, FeatureFlags refreshFromBackend,
  CoachProfileProvider syncFromBackend (save_fact proxy).
- **D-01 Option C** sample rates live: `sessionSampleRate` 0.0/0.10/1.0
  via env-dependent ternary, `onErrorSampleRate` 1.0 in all envs.
- **D-02 Option A** 3-way env split via `MINT_ENV` dart-define (development
  in kDebugMode / staging via dart-define / production default).
- **10/10 VALIDATION tests green** (31-01-01 through 31-01-10 — covering
  ordering, single-capture, single-source ban static lint, sentry-trace,
  router observers, 3 breadcrumb surfaces).
- **PII fuzz 100 runs** across 10 factKind enum values — 0 CHF / 756.AVS /
  IBAN patterns leaked through breadcrumb payloads.

## Task Commits

Each task committed atomically on `feature/v2.8-phase-31-instrumenter`:

1. **Task 1: error_boundary.dart + sentry_breadcrumbs.dart + 3 surface wiring + 6 tests green** — `fe48d361` (feat)
2. **Task 2: installGlobalErrorBoundary in main.dart + D-01 sample rates ternary + SentryNavigatorObserver in app.dart + router observer test green** — `809d9613` (feat)
3. **Task 3: _authHeaders + _publicHeaders + 11 bypass migrations + sentry-trace test green** — `ccee7fd5` (feat)

_This SUMMARY lands in a final plan-metadata commit (see §Final Commit)._

## Files Created/Modified

### Created (2 lib files)

- `apps/mobile/lib/services/error_boundary.dart` — 116 lines. Exports
  `installGlobalErrorBoundary()` + `captureSwallowedException(...,
  surface)`. Sets PlatformDispatcher.onError first, FlutterError.onError
  second, Isolate.current.addErrorListener third. Private `_capture()`
  helper with `_inflight` identity-keyed guard + `scheduleMicrotask`
  release. File-level header documents single-source discipline.
- `apps/mobile/lib/services/sentry_breadcrumbs.dart` — 122 lines.
  `MintBreadcrumbs` static class with 3 methods. All data keys ENUM /
  INT / BOOL only (Pitfall 6 / nLPD A1 mitigation enforced at the API
  surface).

### Modified (6 lib files + 8 test files)

**Lib:**
- `apps/mobile/lib/main.dart` — added `installGlobalErrorBoundary()`
  call at line 34 (after `WidgetsFlutterBinding.ensureInitialized()`,
  before SentryFlutter.init at line 159). Replaced single-value
  `sessionSampleRate = 0.05` with env-dependent ternary (lines 142-149).
  Bound `options.environment` to `String.fromEnvironment('MINT_ENV',
  defaultValue: 'production')`.
- `apps/mobile/lib/app.dart` — extracted observers to module-level
  `_routerObservers`, added `SentryNavigatorObserver()` beside
  `AnalyticsRouteObserver()`. Added `@visibleForTesting`
  `testOnlyRootRouter` + `testOnlyRootRouterObservers` accessors.
- `apps/mobile/lib/services/api_service.dart` — extended `_authHeaders()`
  with D-05 propagation. Added `_publicHeaders()` helper. Migrated 11
  bypass sites (`248, 455, 480, 501, 519, 540, 592, 613, 633, 653, 1305`
  post-patch line numbers). Added `@visibleForTesting` `debugAuthHeaders()`
  + `debugPublicHeaders()`.
- `apps/mobile/lib/services/coach/compliance_guard.dart` — added optional
  `surface` param (default `'coach_reply'` / `'alert'`) on validate()
  and validateAlert(). Added breadcrumb emission on every exit path
  (empty-input + main exit). Only `flagged_count` leaked from
  `bannedTermsFound` — raw term strings never reach Sentry.
- `apps/mobile/lib/services/feature_flags.dart` — split the swallow-all
  `catch (_)` into typed branches: `on TimeoutException` →
  `error_code: 'network_timeout'`, `on FormatException` →
  `'parse_error'`, `on ApiException` (offline) → `'offline'`, else
  `'unknown'`. Success branch emits `flag_count: data.length`.
- `apps/mobile/lib/providers/coach_profile_provider.dart` — emits
  save_fact proxy breadcrumb in `syncFromBackend()` with
  `factKind: 'profile_sync'`. Failure branch maps exception type to
  enum code (offline / api_error / unknown).

**Tests** (all 8 stubs flipped from `skip:` to live):
- error_boundary_test (3 tests) — install + FlutterError.onError + swallow path
- error_boundary_ordering (1 test) — ordering + handled=true
- error_boundary_single_capture (1 test) — exactly-once across prongs
- sentry_breadcrumbs (2 tests) — pass/fail + PII flagged_count discipline
- sentry_breadcrumbs_pii (3 tests) — success/error + 100-run PII fuzz
- sentry_breadcrumbs_refresh (2 tests) — success/failure + `failure` literal
- api_service_sentry_trace (2 tests) — 32+16 hex format on BOTH codepaths
- app_router_observers (1 test) — both observers present + correct order

**Total:** 15 test assertions green (10 VALIDATION test IDs 31-01-01..10).

## Decisions Made

1. **Save_fact proxy instrumentation at CoachProfileProvider.syncFromBackend()** — plan spec pointed to `coach_orchestrator.dart`, but code analysis shows save_fact is 100% server-side (services/backend/app/api/v1/endpoints/coach_chat.py:1342). Mobile has NO dispatch point. Best-available proxy is the sync that reifies server effects into the local profile (called after every chat exchange). Coarse factKind `'profile_sync'` — per-field attribution deferred to Phase 31-02 (backend can echo `facts_saved: [...]` on /profiles/me response).
2. **Extracted observers list to module-level `_routerObservers`** — was needed to expose a test accessor. Introspecting `router.configuration.observers` is not supported by go_router 13.2.5 public API; the builder's observers field is `@visibleForTesting`. Module-level final keeps the same runtime shape with zero additional allocation.
3. **Identity-keyed `_inflight` guard + `scheduleMicrotask` release** for single-capture. Chose identity over equality because two distinct `StateError('same')` must both report; only reentrant dispatch of the SAME thrown object dedupes. Microtask release ensures legitimate re-throws of the same object (rare) still report.
4. **Test harness via `Sentry.init` + fake DSN + `beforeSend: (e, h) => null` + `beforeBreadcrumb: (c, h) { captured.add(c); return null; }`** — standard pattern from sentry_flutter 9.14 test suite. Captures in memory, drops before transport. No network. Easier than `Sentry.bindClient(MockSentryClient())` which requires a full client stub.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] save_fact wiring relocated from coach_orchestrator.dart to coach_profile_provider.dart**
- **Found during:** Task 1 wiring pass.
- **Issue:** Plan instructed wiring in `coach_orchestrator.dart` post-save_fact tool dispatch. Code inspection proved save_fact has ZERO mobile dispatch — it runs exclusively in the backend coach_chat endpoint. Orchestrator only sees `toolCalls` for `route_to_screen` + `generate_document`; no save_fact mirror.
- **Fix:** Instrumented at `CoachProfileProvider.syncFromBackend()` (mobile's explicit post-chat sync that is the only signal a server-side save_fact has taken effect). Emits coarse `factKind: 'profile_sync'`. Documented deferred per-field attribution → Phase 31-02.
- **Files modified:** `apps/mobile/lib/providers/coach_profile_provider.dart` instead of coach_orchestrator.dart.
- **Verification:** sentry_breadcrumbs_pii_test covers both success + error paths of MintBreadcrumbs.saveFact.
- **Committed in:** `fe48d361` (Task 1 commit).

**2. [Rule 3 - Blocking] `beforeBreadcrumb` callback signature was positional, not named** (pre-commit fix)
- **Found during:** Task 1 test execution (compile error).
- **Issue:** Initial stub syntax used `(crumb, {hint})` but sentry 9.14 typedef is `Breadcrumb? Function(Breadcrumb?, Hint)` — positional `Hint`.
- **Fix:** Changed 3 test files to `(crumb, hint)` positional.
- **Files modified:** sentry_breadcrumbs_test, sentry_breadcrumbs_pii_test, sentry_breadcrumbs_refresh_test.
- **Committed in:** `fe48d361`.

**3. [Rule 3 - Blocking] `@visibleForTesting` triggered unnecessary-import warning**
- **Found during:** Task 2 `flutter analyze` on app.dart.
- **Issue:** Imported `package:flutter/foundation.dart show visibleForTesting` but `material.dart` already re-exports it.
- **Fix:** Removed redundant import; `@visibleForTesting` resolves via existing `material.dart`.
- **Files modified:** apps/mobile/lib/app.dart.
- **Committed in:** `809d9613`.

**4. [Rule 3 - Blocking] Bypass count post-migration initially 3, not the target 2**
- **Found during:** Task 3 grep invariant check after migration.
- **Issue:** The string `'Content-Type': 'application/json'` appeared in my doc comment on `_publicHeaders` (explaining the invariant), which matched the grep.
- **Fix:** Rephrased doc comment to avoid the literal (moved to prose: "only two definitions of the Content-Type literal remain in this file").
- **Files modified:** apps/mobile/lib/services/api_service.dart.
- **Verification:** `grep -c "'Content-Type': 'application/json'" api_service.dart` → 2 (the two helper bodies, no extras).
- **Committed in:** `ccee7fd5`.

**5. [Rule 3 - Blocking] flutter_secure_storage MissingPluginException in sentry-trace test**
- **Found during:** Task 3 first test run.
- **Issue:** `_authHeaders()` calls `AuthService.getToken()` → `FlutterSecureStorage().read(...)` which has no platform implementation in pure-Dart test environment.
- **Fix:** Added in-memory mock for `plugins.it_nomads.com/flutter_secure_storage` channel via `setMockMethodCallHandler`, pattern lifted from `test/auth/auth_service_test.dart`.
- **Files modified:** apps/mobile/test/services/api_service_sentry_trace_test.dart.
- **Verification:** Test runs green in ~2s.
- **Committed in:** `ccee7fd5`.

### Auto-added Critical Functionality

**6. [Rule 2 - Missing Critical] Typed-exception branches in FeatureFlags.refreshFromBackend()**
- **Found during:** Task 1 wiring of feature_flags breadcrumb.
- **Issue:** Original code had a single `catch (_)` swallow. The plan specified breadcrumb must differentiate `network_timeout` / `parse_error` / etc. To emit a meaningful `error_code` enum we need typed branches.
- **Fix:** Split into `on TimeoutException` + `on FormatException` + `on ApiException` (isOffline) + catch-all. Each emits the breadcrumb with the correct enum. Original swallow semantics preserved (no rethrow, values kept on failure).
- **Files modified:** apps/mobile/lib/services/feature_flags.dart.
- **Scope justification:** Directly in scope — the plan requires `error_code: 'network_timeout'` on timeout, which cannot be produced by a blanket catch.
- **Committed in:** `fe48d361`.

---

**Total deviations:** 6 (1 architectural reroute, 4 blocking plumbing, 1 missing-critical).
**Impact on plan:** All deviations preserved plan intent. The architectural reroute (save_fact → syncFromBackend proxy) is documented with a deferred action for Phase 31-02 (backend echo for per-field attribution).

## Issues Encountered

- **2 pre-existing warnings in coach_profile_provider.dart** (L199 `unnecessary_type_check`, L255 `dead_null_aware_expression`). Out-of-scope per deviation_rules scope boundary — deferred to `.planning/phases/31-instrumenter/deferred-items.md` if needed.
- **GoRouter 13.2.5 has no public observers getter** — resolved by extracting list to top-level `_routerObservers` and exposing via `@visibleForTesting`.
- **save_fact has no mobile dispatch** — recognized and handled via proxy at syncFromBackend. Phase 31-02 will add backend response field for fine-grained attribution.

## User Setup Required

None. All automation is in-code. Downstream phases will need:
- **Staging builds MUST pass `--dart-define=MINT_ENV=staging`** — else events tag as `production` (breaks D-02 filtering).
- `SENTRY_AUTH_TOKEN` still pending from Phase 31-00 operator setup (non-blocking for Wave 1 mobile; blocks Wave 4 quota probe).

## A1–A10 Assumptions Flipped

From 31-RESEARCH.md §Assumptions Log:
- **A5** (`_authHeaders()` can inject sentry-trace without breaking existing 20+ call sites) → **VERIFIED**: `flutter analyze` on api_service.dart returns 0 issues; all 11 bypass sites migrated, public + auth codepaths share a single helper.
- **A6** (`SentryNavigatorObserver()` cohabits cleanly with `AnalyticsRouteObserver()`) → **VERIFIED**: router observers test asserts both present, both distinct instances, AnalyticsRouteObserver precedes SentryNavigatorObserver (analytics pipeline owns event stream; Sentry records breadcrumb).
- **A8** (`beforeBreadcrumb` callback can drop breadcrumbs before scope-add for unit testing) → **VERIFIED**: pattern captures in memory, zero network.

Remaining assumptions (A1–A4, A7, A9, A10) gate Wave 2+ (backend handler, quota probe).

## Next Phase Readiness

**Wave 2 (Plan 31-02 backend OBS-03) unblocked:**
- `trace_round_trip_test.sh` now exercises the REAL codepath (auth/login goes through `_publicHeaders()` post-migration, not bypass). Plan 31-02 will tighten presence→equality once backend echoes inbound `sentry-trace`.
- Per-factKind save_fact attribution can be wired after Phase 31-02 adds `facts_saved: [...]` response field.

**Wave 3 (Plan 31-03 PII audit) unblocked:**
- Error-only Replay is safe to enable on staging (`MINT_ENV=staging` → `sessionSampleRate = 0.10`) for OBS-06 audit. `onErrorSampleRate = 1.0` means every crash carries its replay — exactly what the 5 sensitive-screen audit needs to record.

**Wave 4 (Plan 31-04 ops budget):**
- `observability-budget.md` can be populated once `SENTRY_AUTH_TOKEN` is set by operator.

**Blockers / concerns for next plan:**
- Phase 31-02 must add `/_test/inject_error` backend endpoint (Open Question #4 from 31-00).
- Phase 31-02 must add `facts_saved: [...]` to /profiles/me response to replace the `profile_sync` coarse factKind with per-field attribution.
- `--dart-define=MINT_ENV=staging` MUST propagate into walker.sh + testflight.yml + play-store.yml CI workflows (Phase 35 scope).

## Self-Check

**Files exist on disk:**
- `apps/mobile/lib/services/error_boundary.dart` — FOUND
- `apps/mobile/lib/services/sentry_breadcrumbs.dart` — FOUND
- `apps/mobile/lib/main.dart` — MODIFIED (installGlobalErrorBoundary at L34, D-01 ternary at L142-149)
- `apps/mobile/lib/app.dart` — MODIFIED (_routerObservers L170-182, testOnly* accessors after L1165)
- `apps/mobile/lib/services/api_service.dart` — MODIFIED (_authHeaders / _publicHeaders / 11 migrations / debug accessors)
- `apps/mobile/lib/services/coach/compliance_guard.dart` — MODIFIED (surface param + breadcrumbs)
- `apps/mobile/lib/services/feature_flags.dart` — MODIFIED (typed catch branches + breadcrumbs)
- `apps/mobile/lib/providers/coach_profile_provider.dart` — MODIFIED (save_fact proxy breadcrumb)
- 8 test files — all FOUND + flipped live.

**Commits exist in git log:**
- `fe48d361` — FOUND (Task 1)
- `809d9613` — FOUND (Task 2)
- `ccee7fd5` — FOUND (Task 3)

**Verify commands re-run at SUMMARY creation time:**
- `flutter analyze` on all 7 modified lib files + 8 test files → 0 new issues (2 pre-existing warnings in coach_profile_provider.dart out-of-scope)
- `python3 tools/checks/sentry_capture_single_source.py` → OK, 2 whitelisted hits, 0 violations across 656 .dart files
- `python3 tools/checks/verify_sentry_init.py` → 8/8 invariants green
- `grep -c "'Content-Type': 'application/json'" apps/mobile/lib/services/api_service.dart` → 2
- `grep -c "_publicHeaders" apps/mobile/lib/services/api_service.dart` → 15 (1 doc + 1 def + 1 test accessor + 11 call sites + 1 forward ref)
- `grep -E "'mint\\.compliance\\.guard\\.(pass|fail)'" apps/mobile/lib/services/sentry_breadcrumbs.dart` → both present
- `grep -E "'mint\\.coach\\.save_fact\\.(success|error)'" apps/mobile/lib/services/sentry_breadcrumbs.dart` → both present
- `grep -E "'mint\\.feature_flags\\.refresh\\.(success|failure)'" apps/mobile/lib/services/sentry_breadcrumbs.dart` → both present
- `grep -E "'mint\\.coach\\.tool\\.save_fact'" apps/mobile/lib/services/sentry_breadcrumbs.dart` → exit 1 (no matches — rejected form absent)
- 15 tests (10 VALIDATION IDs) all PASS via `flutter test ... --reporter compact`

## Self-Check: PASSED

---

*Phase: 31-instrumenter*
*Completed: 2026-04-19*
