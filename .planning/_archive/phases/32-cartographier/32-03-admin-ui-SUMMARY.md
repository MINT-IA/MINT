---
phase: 32-cartographier
plan: 03
subsystem: admin-ui
tags: [flutter, admin, route-registry, breadcrumb, sentry, nlpd, tree-shake, dart, python, pytest, wave-3]

# Dependency graph
requires:
  - phase: 32-00-reconcile
    provides: "43-row Redirect Call-Site Inventory + 9-site Category 6 non-legacy exclusion list + 4 Wave 0 test stubs"
  - phase: 32-01-registry
    provides: "kRouteRegistry (147 entries) + RouteOwner (15 values) + RouteCategory (4 values) imported by RoutesRegistryScreen"
  - phase: 32-02-cli
    provides: "route_health_schema.dart (MAP-03 contract) + `./tools/mint-routes health` terminal path referenced in UI footer"
  - phase: 31-instrumenter
    provides: "MintBreadcrumbs 4-level D-03 category discipline + sentry_flutter 9.14.0 (beforeBreadcrumb hook stable)"
provides:
  - "apps/mobile/lib/screens/admin/admin_gate.dart: AdminGate.isAvailable double gate (compile-time ENABLE_ADMIN + runtime FeatureFlags.isAdmin)"
  - "apps/mobile/lib/screens/admin/admin_shell.dart: shared scaffold reused by Phase 33 /admin/flags without refactor"
  - "apps/mobile/lib/screens/admin/routes_registry_screen.dart: pure schema viewer (D-06) — 147 routes × 15 owner ExpansionTiles + CLI footer"
  - "apps/mobile/lib/services/feature_flags.dart: new `isAdmin` getter (local only, no backend call)"
  - "apps/mobile/lib/services/sentry_breadcrumbs.dart: `legacyRedirectHit({from, to})` + `adminRoutesViewed({routeCount, featureFlagsEnabledCount, snapshotAgeMinutes?})` helpers"
  - "apps/mobile/lib/app.dart: `/admin/routes` route inside `if (AdminGate.isAvailable)` compile-time conditional + 43 legacy redirects wired with MintBreadcrumbs.legacyRedirectHit"
  - "tests/tools/test_redirect_breadcrumb_coverage.py: per-site coverage pytest asserting each of the 43 callbacks emits its expected redirect_branches count"
  - "4 live Flutter tests + 1 live pytest replacing 4 Wave 0 scaffolds"
affects:
  - "32-04 (MAP-04 parity lint): admin/* routes NOT in kRouteRegistry — parity lint must exempt via first-segment KNOWN-MISSES or runtime-only match"
  - "32-05 (J0 + CI): admin-build-sanity job must scan testflight.yml/play-store.yml; tree-shake binary-grep proof deferred here"
  - "33 FLAG-05: AdminShell available for /admin/flags child; same compile-time + runtime gate already proven"
  - "34 GUARD-03 no_hardcoded_fr.py: MUST exempt lib/screens/admin/** (M-1 — file headers document the English carve-out explicitly)"
  - "35 dogfood: mint-routing analytics now emit breadcrumbs usable for traffic heatmap"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Compile-time + runtime dual gate: `const bool.fromEnvironment('ENABLE_ADMIN')` for tree-shake + `FeatureFlags.isAdmin` for runtime kill. `if (AdminGate.isAvailable) ...[ ScopedGoRoute(...) ]` in the router list makes the entire admin branch dead-code-eliminable."
    - "Behavioural Sentry testing: `Sentry.init(options.beforeBreadcrumb = (bc, hint) { captured.add(bc); return null; })` captures real Breadcrumb objects in-memory. Tests assert on `captured.single.data.keys.toSet()` with exact-set equality — not source-string inspection. Supersedes the fragile regex-over-source pattern."
    - "Per-site coverage over RECONCILE inventory (M-3): pytest parses the 43-row Redirect Call-Site Inventory and locates each callback by source path literal (wiring shifts line numbers, so line-indexing is fragile). Balanced-paren walker returns the enclosing ScopedGoRoute slice. Asserts per-site actual count == inventory redirect_branches."
    - "Dev-only English carve-out declared in file header (M-1): every admin file opens with the exact literal `// Dev-only admin surface per D-03 + D-10 (CONTEXT v4). English-only by executor discretion — no i18n/ARB keys. Phase 34 no_hardcoded_fr.py MUST exempt lib/screens/admin/**`. Gives Phase 34 GUARD-03 an explicit provenance to exempt without case-by-case debate."

key-files:
  created:
    - apps/mobile/lib/screens/admin/admin_gate.dart
    - apps/mobile/lib/screens/admin/admin_shell.dart
    - apps/mobile/lib/screens/admin/routes_registry_screen.dart
    - tests/tools/test_redirect_breadcrumb_coverage.py
  modified:
    - apps/mobile/lib/services/feature_flags.dart   # + isAdmin getter
    - apps/mobile/lib/services/sentry_breadcrumbs.dart  # + legacyRedirectHit + adminRoutesViewed
    - apps/mobile/lib/app.dart  # + /admin/routes route + 43 redirect-site breadcrumb wiring
    - apps/mobile/test/screens/admin/admin_shell_gate_test.dart  # Wave 0 skip stub -> live
    - apps/mobile/test/screens/admin/routes_registry_screen_test.dart  # Wave 0 skip stub -> 3 live tests
    - apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart  # Wave 0 skip stub -> 6 live behavioural tests
    - apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart  # Wave 0 skip stub -> 3 live static guards

key-decisions:
  - "Moved MintBreadcrumbs helpers (`legacyRedirectHit` + `adminRoutesViewed`) into Task 1's commit (plan had them in Task 2 File 1). Reason: RoutesRegistryScreen initState calls `adminRoutesViewed` — without the helper present, Task 1 does not compile. Scope contract (43-site wiring) preserved in Task 2."
  - "ExpansionTile internally renders a ListTile for its header, so the naive `find.byType(ListTile)` returns 162 (147 rows + 15 headers). Filter by `dense: true` predicate to isolate route rows — our rows explicitly set `dense: true`, ExpansionTile headers do not."
  - "Tall viewport in widget tests (20000pt height) so ListView.builder materialises every owner tile. Without this, only ~10 tiles render (visible range) and the 15-count assertion fails."
  - "Per-site pytest locates callsites by source path literal, NOT by RECONCILE-REPORT line numbers. Wiring 43 arrow-form redirects into 4-line block forms shifts every downstream line; source paths are stable identifiers."
  - "Owner bucket lopsidedness (96/147 fall back to RouteOwner.system from Wave 1) shipped AS-IS. Wave 1 accepted this per its deviation log; UI shows all 15 buckets, and the `system` bucket is legitimately large. No cosmetic re-bucketing applied."

patterns-established:
  - "Behavioural breadcrumb tests via `beforeBreadcrumb` hook: captures real Breadcrumb objects emitted by MintBreadcrumbs helpers. Assertions run on the captured object's data-keys and types. Supersedes Wave 0's source-string grep approach, which was fragile to refactors (e.g., extracting `const _CAT = '...'` would break source-grep while preserving behaviour)."
  - "Per-site coverage contract over fragile `grep -c == N`: when a helper is wired at N distinct sites with different branch structures, the right assertion is per-site against an authoritative inventory — not a total count. RECONCILE-REPORT §Redirect Call-Site Inventory is the inventory; pytest parses + matches per row."
  - "Compile-time gate for dev-only UI: every `/admin/*` route is declared inside `if (AdminGate.isAvailable) ...[` so Dart dead-code-eliminates the branch (and the kRouteRegistry import graph) in prod builds. Tree-shake binary-grep verification deferred to Plan 32-05 Wave 4 J0 Task 1."

requirements-completed: [MAP-02b, MAP-05]

# Metrics
duration: 11min
completed: 2026-04-20
---

# Phase 32 Plan 03: Admin UI Summary

**`/admin/routes` schema viewer shipped behind compile-time + runtime double gate (D-10). 43 legacy redirects emit `mint.routing.legacy_redirect.hit` breadcrumbs with path-only aggregates (nLPD D-09 §2). Admin mount emits `mint.admin.routes.viewed` aggregates-only processing record (nLPD Art. 12 / D-09 §4). All 4 Wave 0 Flutter stubs + 1 new pytest live. 31/31 Flutter tests + 3/3 pytest green.**

## Admin UI surface overview

**Gate chain:**
1. Compile-time: `--dart-define=ENABLE_ADMIN=1` sets `AdminGate._compileTimeEnabled = true`. Default `false` in prod → Dart dead-code-eliminates the whole `if (AdminGate.isAvailable) ...[` branch in app.dart, detaching `kRouteRegistry` from the runtime graph (T-32-04 mitigation, empirical binary-grep proof in Plan 32-05 Wave 4 J0 Task 1).
2. Runtime: `FeatureFlags.isAdmin` getter returns `const bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false)` locally — no backend `/admin/me` call (D-10 kill). Phase 33 may refactor to ChangeNotifier-based gate when multi-user admin is needed.

Both gates must be true → `AdminGate.isAvailable == true` → `/admin/routes` mounts.

**Screen structure:**
- `AdminShell` (shared scaffold, AppBar "MINT Admin", `MintColors.warmWhite` background, SafeArea body). Phase 33 reuses this for `/admin/flags`.
- `RoutesRegistryScreen` (StatefulWidget): initState groups `kRouteRegistry` by `RouteOwner` (15 buckets), counts enabled FeatureFlags static fields (aggregate), emits `mint.admin.routes.viewed` breadcrumb with aggregates-only data.
- Body: `ListView.builder(itemCount: RouteOwner.values.length)` → one `ExpansionTile` per owner → children are dense `ListTile` rows `{path, category, owner, [killFlag], auth|public}`. `Semantics(label: ...)` on each bucket header (a11y, D-08).
- Footer: `Live health status: use \`./tools/mint-routes health\` terminal.\nThis screen shows static schema + local FeatureFlags state only.` — D-06 contract that live health is CLI-exclusive.

**English carve-out (M-1) explicitly declared in every admin file's header:**

```
// Dev-only admin surface per D-03 + D-10 (CONTEXT v4).
// English-only by executor discretion — no i18n/ARB keys.
// Phase 34 no_hardcoded_fr.py MUST exempt lib/screens/admin/**
// (TODO: add exemption when Phase 34 plan ships lint-config.yaml).
```

This is the provenance Phase 34 `no_hardcoded_fr.py` (GUARD-03) needs to exempt the admin tree safely.

## MintBreadcrumbs surface

Two new static helpers, parameter discipline enforces the nLPD D-09 contract at the compile surface:

```dart
// Phase 32 D-09 §4 — admin access processing record (nLPD Art. 12).
static void adminRoutesViewed({
  required int routeCount,
  required int featureFlagsEnabledCount,
  int? snapshotAgeMinutes,
});
// category: 'mint.admin.routes.viewed' | level: info | data: int/int? only

// Phase 32 MAP-05 — legacy redirect analytics.
static void legacyRedirectHit({
  required String from,
  required String to,
});
// category: 'mint.routing.legacy_redirect.hit' | level: info | data: {from, to}
```

Parameter-surface discipline: `adminRoutesViewed` accepts only int/int? — a maintainer cannot pass a String (compile error). `legacyRedirectHit` accepts only `String from`/`String to` — callers must pass `state.uri.path` (NOT `state.uri.toString()`, asserted by `legacy_redirect_breadcrumb_test.dart` regex guard).

## 43-redirect wiring proof

All 43 legacy redirects enumerated in RECONCILE-REPORT §Redirect Call-Site Inventory converted from arrow-form to block-form, each emitting exactly 1 `MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '<target>')`. Per-site coverage asserted by pytest:

```
$ python3 -m pytest tests/tools/test_redirect_breadcrumb_coverage.py -q
...                                                                      [100%]
3 passed in 0.01s
```

- `test_reconcile_report_lists_43_redirect_sites` — inventory shape: exactly 43 rows.
- `test_per_site_breadcrumb_coverage_matches_inventory` — per-site: actual count == inventory `redirect_branches` for every row.
- `test_total_emissions_equals_inventory_sum` — total: `grep -c "MintBreadcrumbs.legacyRedirectHit" apps/mobile/lib/app.dart == 43 == Σ redirect_branches`.

The 9 block-form Category 6 redirects (lines 194, 870, 908, 916, 922, 1134, 1141, 1148, 1163 in pre-wave app.dart) are intentionally left alone — they are scope guards, FeatureFlag gates, and param-passing, NOT legacy redirects.

## Widget + behavioural + pytest coverage summary

| Test file                                                         | Tests | Status |
|-------------------------------------------------------------------|-------|--------|
| `test/screens/admin/admin_shell_gate_test.dart`                   | 1     | pass   |
| `test/screens/admin/routes_registry_screen_test.dart`             | 3     | pass   |
| `test/screens/admin/routes_registry_breadcrumb_test.dart`         | 6     | pass   |
| `test/routes/legacy_redirect_breadcrumb_test.dart`                | 3     | pass   |
| `tests/tools/test_redirect_breadcrumb_coverage.py`                | 3     | pass   |
| **Wave 3 subtotal**                                               | **16** | **all green** |
| `test/routes/route_metadata_test.dart` (Wave 1 regression)        | 12    | pass   |
| `test/routes/route_meta_json_test.dart` (Wave 2 regression)       | 2     | pass   |
| `test/services/sentry_breadcrumbs_test.dart` (Phase 31 regression)| 2     | pass   |
| `test/services/sentry_breadcrumbs_refresh_test.dart`              | 2     | pass   |
| `test/app_router_observers_test.dart` (OBS-05 regression)         | 1     | pass   |
| **Regression subtotal**                                           | **19** | **all green** |

`flutter analyze lib/screens/admin/ lib/services/feature_flags.dart lib/services/sentry_breadcrumbs.dart lib/app.dart test/screens/admin/ test/routes/legacy_redirect_breadcrumb_test.dart`: **0 issues**.

## Task Commits

Each task committed atomically on `feature/v2.8-phase-32-cartographier`:

1. **Task 1: AdminGate + AdminShell + RoutesRegistryScreen + FeatureFlags.isAdmin + /admin/routes route + MintBreadcrumbs helpers (dependency pre-land)** — `1639c3f0` (feat)
2. **Task 2: Wire 43 legacy redirects + behavioural breadcrumb test + per-site coverage pytest** — `95c21137` (feat)

_Plan metadata commit follows this SUMMARY._

## Decisions Made

- **M-1 English carve-out declared inline in every admin file header** — prevents Phase 34 `no_hardcoded_fr.py` false positives without requiring a global lint-config allowlist entry. Future maintainers see the exemption provenance in the file itself.
- **M-2 behavioural breadcrumb test via `Sentry.init(beforeBreadcrumb: ...)` hook** — captures real `Breadcrumb` objects, asserts `data.keys.toSet() == equals({...})` with exact-set match. A maintainer refactoring to `const _CAT = '...'` or adding extra keys would break the behavioural contract and fail the test — which is the right failure mode.
- **M-3 per-site coverage pytest over RECONCILE inventory** — not a `grep -c == 43` brittle check. Parses the 43-row inventory, locates each callback in app.dart by source path literal, and asserts per-site actual count == inventory `redirect_branches`. The contract is the inventory, not a magic number.
- **Pre-land MintBreadcrumbs helpers in Task 1's commit** — plan structured `legacyRedirectHit` + `adminRoutesViewed` as Task 2 File 1, but `RoutesRegistryScreen.initState` calls `adminRoutesViewed`. Without the helper present, Task 1 does not compile. Documented as a Rule 3 blocking-issue auto-fix in Task 1's commit body.
- **Per-site pytest indexes by source path, not by line number** — wiring 43 arrow-form redirects into 4-line block forms shifts every downstream line. `_extract_callback_body_by_source()` walks from `ScopedGoRoute(...` to the matching balanced paren, handling both single-line and block-form declarations.
- **Widget-test viewport trick (800x20000)** — ListView.builder is lazy, only materialising visible items. To assert "15 ExpansionTiles render" and "147 rows after expand-all", the test sets a tall physical size so the whole list lays out simultaneously. `addTearDown` resets the view to prevent cross-test pollution.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Pre-landed MintBreadcrumbs helpers in Task 1's commit**

- **Found during:** Task 1 flutter analyze (after creating `routes_registry_screen.dart`)
- **Issue:** The plan structures the two new MintBreadcrumbs helpers (`legacyRedirectHit` + `adminRoutesViewed`) as Task 2 File 1. But `RoutesRegistryScreen.initState` calls `MintBreadcrumbs.adminRoutesViewed(...)` on Task 1. Without the helper present, Task 1's code does not compile — `flutter analyze` reports "undefined method 'adminRoutesViewed' on MintBreadcrumbs".
- **Fix:** Added both helpers to `lib/services/sentry_breadcrumbs.dart` in Task 1's commit. Task 2 still owns the 43-site wiring at call-sites + the behavioural tests + the pytest coverage. Scope contract preserved; compile-time dependency respected.
- **Files modified:** `lib/services/sentry_breadcrumbs.dart`
- **Committed in:** `1639c3f0`

**2. [Rule 1 — Bug] Widget test `find.byType(ListTile)` counts include ExpansionTile headers**

- **Found during:** Task 1 first test run (`sum of route rows across all buckets == 147` reports 162)
- **Issue:** `ExpansionTile` internally renders a `ListTile` for its header. Naive `find.byType(ListTile)` after expanding all 15 tiles returns 147 rows + 15 headers = 162. The test would false-fail on a correct implementation.
- **Fix:** Filter with `find.byWidgetPredicate((w) => w is ListTile && w.dense == true)`. Our route rows explicitly set `dense: true`; ExpansionTile headers do not. Count reduces to exactly 147.
- **Files modified:** `apps/mobile/test/screens/admin/routes_registry_screen_test.dart`
- **Committed in:** `1639c3f0`

**3. [Rule 1 — Bug] Pytest line-number index fails after wiring shifts every line**

- **Found during:** Task 2 first pytest run (`test_per_site_breadcrumb_coverage_matches_inventory` reports 24 site failures)
- **Issue:** RECONCILE-REPORT line numbers are pinned to app.dart SHA b7a88cc8. Wiring 43 arrow-form `(_, __) => '/x'` redirects into 4-line block forms shifts every downstream line in app.dart. The pytest's `_extract_callback_body(src, line_no)` walks lines from the inventory's stored line number — after wiring, those lines point elsewhere (or to the next-but-wrong callback).
- **Fix:** Rewrote `_extract_callback_body_by_source(src, source_path)` to locate each callback by the source path literal (`path: '/x'`). Walks backward to the enclosing `ScopedGoRoute(`, then forward to the matching balanced paren. Source paths are stable identifiers; line numbers are not. Also stripped the descriptive suffixes the inventory adds to some rows (e.g., `` /onboarding/quick` (parent L1089) ``) before matching.
- **Files modified:** `tests/tools/test_redirect_breadcrumb_coverage.py`
- **Committed in:** `95c21137`

**4. [Rule 3 — Blocking] ListView.builder lazy materialisation clipped 5 of 15 owner tiles**

- **Found during:** Task 1 first test run (`renders 15 ExpansionTiles` reports 10)
- **Issue:** `ListView.builder` only materialises items in the visible range. Default Flutter test surface is 800x600, which fits ~10 owner tiles. The 15-count assertion failed despite correct source code.
- **Fix:** Set `tester.view.physicalSize = Size(800, 20000)` so the whole list lays out simultaneously. `addTearDown` resets the view to prevent pollution of later tests.
- **Files modified:** `apps/mobile/test/screens/admin/routes_registry_screen_test.dart`
- **Committed in:** `1639c3f0`

**5. [Rule 3 — Blocking] Unused-import warning during Task 1 intermediate state**

- **Found during:** Task 1 flutter analyze after I had speculatively added `sentry_breadcrumbs.dart` import to app.dart before the 43-site wiring landed
- **Issue:** `flutter analyze` reported `warning • Unused import: 'package:mint_mobile/services/sentry_breadcrumbs.dart' • lib/app.dart:147:8 • unused_import`. Hook-policy would either fail the commit or force an import shuffle.
- **Fix:** Removed the import in Task 1's final state; re-added it at the top of Task 2's edits just before wiring the first call-site (where the reference becomes live).
- **Files modified:** `apps/mobile/lib/app.dart` (intermediate state)
- **Committed in:** clean state shipped in `1639c3f0` and `95c21137`

---

**Total deviations:** 5 auto-fixed (2 bugs, 3 blocking). No architectural changes. No user permission required.

## Issues Encountered

- **lefthook retention WARNING (non-blocking):** `MEMORY.md` at 167 lines (target <100). Same warning across Phases 31, 32-00, 32-01, 32-02, 32-03. Not a D-02 failure gate.
- **Non-blocking git identity warning:** same as prior plans. Co-Author trailer correctly carries Claude signature.
- **Flaky golden PNGs in working tree** (unstaged): pre-existing drift in `test/goldens/failures/*.png` from prior sessions; not touched by Wave 3; not staged.

## Authentication Gates

None during this plan. Admin gate is local-only (compile-time + `FeatureFlags.isAdmin` static getter). No `SENTRY_AUTH_TOKEN` needed for Wave 3 scope (CLI uses it, but CLI not exercised here). No backend endpoint.

## User Setup Required

For dev-mode usage of `/admin/routes`:

```bash
# Build the mobile app with ENABLE_ADMIN=1 (dev only — never in prod workflows)
cd apps/mobile && flutter run --dart-define=ENABLE_ADMIN=1
# Then navigate to /admin/routes in the running app.
```

Default prod builds (ENABLE_ADMIN=0) mount nothing — route returns 404, registry absent from IPA.

## Known Stubs

None. Every admin surface renders real data:
- `AdminGate.isAvailable` — real `bool.fromEnvironment` + `FeatureFlags.isAdmin` getter.
- `RoutesRegistryScreen` — reads real `kRouteRegistry` (147 entries from Plan 32-01).
- `MintBreadcrumbs.adminRoutesViewed` / `legacyRedirectHit` — emit real `Breadcrumb` objects via `Sentry.addBreadcrumb`.
- Footer text is a real CLI pointer, not a placeholder.

## Threat Flags

None new. Plan stays within declared threat surface:
- **T-32-02 (PII leak)** — mitigated structurally by helper parameter surface (int/int? for admin, String path-only for redirect) + behavioural test asserting `isA<int>` on all admin data values + source-grep regression guard forbidding `state.uri.toString()` inside `legacyRedirectHit(...)`.
- **T-32-04 (admin UI in prod IPA)** — mitigated by compile-time gate `if (AdminGate.isAvailable) ...[`. Empirical tree-shake binary-grep proof deferred to Plan 32-05 Wave 4 J0 Task 1.

No new network endpoints. No new file I/O. No schema changes at trust boundaries.

## Next Phase Readiness

**Plan 32-04 (Wave 4 parity lint) unblocked.** Consumes:
- `kRouteRegistry` from Plan 32-01 (147 entries).
- `/admin/routes` path exists in `app.dart` but NOT in `kRouteRegistry` (it's a dev-only compile-time-conditional route). Parity lint must either (a) exempt it via KNOWN-MISSES first-segment rule or (b) detect the `if (AdminGate.isAvailable)` guard in its regex preprocessor. Recommend (a) for minimum complexity.

**Plan 32-05 (Wave 5 CI + J0 gates) unblocked.** Consumes:
- `admin-build-sanity` CI job scans `testflight.yml`/`play-store.yml` for `--dart-define=ENABLE_ADMIN=1` in prod build steps.
- Tree-shake empirical proof: `flutter build ios --simulator --release --no-codesign --dart-define=ENABLE_ADMIN=0` → `strings Runner | grep -c kRouteRegistry == 0`.

**Phase 33 (Kill-switches) unblocked.** Consumes:
- `AdminShell` reusable for `/admin/flags` child — no refactor.
- `FeatureFlags.isAdmin` getter already exists — Phase 33 may refactor to ChangeNotifier instance-level when multi-flag dashboard lands.

**Phase 34 (Guardrails) dependency flagged:** `no_hardcoded_fr.py` (GUARD-03) MUST exempt `lib/screens/admin/**`. Every admin file declares this in its header docstring. Recommend Phase 34 plan ships a `lint-config.yaml` with an explicit `no_hardcoded_fr_exempt_prefixes: [lib/screens/admin/]` entry.

**Phase 35 (Boucle daily) forward-unblock.** `mint.routing.legacy_redirect.hit` breadcrumbs now emitted on every legacy redirect → dogfood CLI can surface per-path hit counts and prioritise sunset candidates.

**No blockers. No concerns.**

## Cross-phase dependency flag for Phase 34

`lib/screens/admin/**` MUST be exempt from `no_hardcoded_fr.py`. File headers declare this explicitly. Phase 34 plan should include this exemption in its lint-config ship.

## Self-Check: PASSED

File existence + commit existence verified:

- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/admin/admin_gate.dart` — FOUND
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/admin/admin_shell.dart` — FOUND
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/admin/routes_registry_screen.dart` — FOUND
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/feature_flags.dart` — MODIFIED (contains `static bool get isAdmin`)
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/sentry_breadcrumbs.dart` — MODIFIED (contains `legacyRedirectHit` + `adminRoutesViewed`)
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/app.dart` — MODIFIED (contains `if (AdminGate.isAvailable)` + 43 `MintBreadcrumbs.legacyRedirectHit` invocations)
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/test/screens/admin/admin_shell_gate_test.dart` — MODIFIED (live)
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/test/screens/admin/routes_registry_screen_test.dart` — MODIFIED (live)
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart` — MODIFIED (live behavioural)
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart` — MODIFIED (live static guards)
- `/Users/julienbattaglia/Desktop/MINT/tests/tools/test_redirect_breadcrumb_coverage.py` — FOUND
- Commit `1639c3f0` (Task 1) — FOUND
- Commit `95c21137` (Task 2) — FOUND
- `flutter analyze lib/screens/admin/ lib/services/feature_flags.dart lib/services/sentry_breadcrumbs.dart lib/app.dart test/screens/admin/ test/routes/legacy_redirect_breadcrumb_test.dart`: 0 issues — VERIFIED
- `flutter test test/routes/ test/screens/admin/`: 31/31 passed — VERIFIED
- `python3 -m pytest tests/tools/test_redirect_breadcrumb_coverage.py -q`: 3/3 passed — VERIFIED
- `grep -c "MintBreadcrumbs.legacyRedirectHit" apps/mobile/lib/app.dart`: 43 — VERIFIED
- `grep -cE "redirect:\s*\(_,\s*_?_?\)" apps/mobile/lib/app.dart`: 0 — VERIFIED (all arrow-form redirects converted)

---

*Phase: 32-cartographier*
*Plan: 03-admin-ui*
*Completed: 2026-04-20*
