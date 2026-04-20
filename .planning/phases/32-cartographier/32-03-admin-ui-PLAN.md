---
phase: 32
plan: 3
plan_number: 03
slug: admin-ui
type: execute
wave: 3
status: pending
depends_on: [reconcile, registry, cli]
files_modified:
  - apps/mobile/lib/screens/admin/admin_gate.dart
  - apps/mobile/lib/screens/admin/admin_shell.dart
  - apps/mobile/lib/screens/admin/routes_registry_screen.dart
  - apps/mobile/lib/services/feature_flags.dart
  - apps/mobile/lib/services/sentry_breadcrumbs.dart
  - apps/mobile/lib/app.dart
  - apps/mobile/test/screens/admin/admin_shell_gate_test.dart
  - apps/mobile/test/screens/admin/routes_registry_screen_test.dart
  - apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart
  - apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart
  - tests/tools/test_redirect_breadcrumb_coverage.py
requirements:
  - MAP-02b
  - MAP-05
threats:
  - T-32-02
  - T-32-04
autonomous: true
must_haves:
  truths:
    - "`/admin/routes` is only reachable when `bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false)` AND `FeatureFlags.isAdmin` are both true"
    - "When the gate is open, screen renders 147 routes grouped by 15 owner buckets as collapsible ExpansionTiles"
    - "Screen mount emits `mint.admin.routes.viewed` breadcrumb with aggregates-only data (route_count, feature_flags_enabled_count) — NO path, NO user context (asserted BEHAVIORALLY via captured breadcrumb, not source-grep)"
    - "Footer text points users to `./tools/mint-routes health` for live status (D-06 pure schema viewer contract)"
    - "All 43 legacy redirect call-sites (per RECONCILE-REPORT §Redirect Call-Site Inventory) emit `mint.routing.legacy_redirect.hit` breadcrumb with `{from, to}` paths only (no query params, no user id); per-site coverage is asserted via tests/tools/test_redirect_breadcrumb_coverage.py using the RECONCILE-REPORT enumeration as the contract (M-3 fix)"
    - "`MintBreadcrumbs.legacyRedirectHit` + `MintBreadcrumbs.adminRoutesViewed` added without breaking existing breadcrumb helpers"
    - "With `ENABLE_ADMIN=0`, `AdminGate.isAvailable` returns false AND no `kRouteRegistry` reference reaches the runtime code path"
    - "Admin UI files (admin_shell.dart, routes_registry_screen.dart, admin_gate.dart) are dev-only English per D-03 + D-10 carve-out; file header docstrings declare this exemption explicitly (M-1 fix — blocks Phase 34 no_hardcoded_fr.py false-positives)"
  artifacts:
    - path: "apps/mobile/lib/screens/admin/admin_gate.dart"
      provides: "Compile-time + runtime gate"
    - path: "apps/mobile/lib/screens/admin/admin_shell.dart"
      provides: "Shared AdminScaffold reused by Phase 33 /admin/flags"
    - path: "apps/mobile/lib/screens/admin/routes_registry_screen.dart"
      provides: "RoutesRegistryScreen — schema viewer UI"
    - path: "apps/mobile/lib/services/feature_flags.dart (MODIFIED)"
      provides: "FeatureFlags.isAdmin getter (new field, Phase 33 may refactor)"
    - path: "apps/mobile/lib/services/sentry_breadcrumbs.dart (MODIFIED)"
      provides: "MintBreadcrumbs.adminRoutesViewed + .legacyRedirectHit helpers"
    - path: "apps/mobile/lib/app.dart (MODIFIED)"
      provides: "`/admin/routes` route behind `if (AdminGate.isAvailable)` guard + 43 redirect call-sites emit breadcrumb (per-site count matches RECONCILE-REPORT inventory)"
    - path: "tests/tools/test_redirect_breadcrumb_coverage.py (NEW)"
      provides: "Per-site breadcrumb coverage assertion — parses app.dart and validates each of the 43 call-sites against RECONCILE-REPORT.md inventory (M-3 contract)"
  key_links:
    - from: "apps/mobile/lib/screens/admin/routes_registry_screen.dart"
      to: "apps/mobile/lib/routes/route_metadata.dart (kRouteRegistry)"
      via: "import 'package:mint_mobile/routes/route_metadata.dart'"
      pattern: "kRouteRegistry\\.(length|values|entries)"
    - from: "apps/mobile/lib/app.dart redirect callbacks (43 instances)"
      to: "MintBreadcrumbs.legacyRedirectHit(from, to)"
      via: "redirect: (ctx, state) { MintBreadcrumbs.legacyRedirectHit(...); return '/target'; }"
      pattern: "MintBreadcrumbs\\.legacyRedirectHit"
    - from: "routes_registry_screen initState"
      to: "MintBreadcrumbs.adminRoutesViewed (aggregates only)"
      via: "nLPD D-09 §4 processing record — behavioral test via beforeBreadcrumb hook"
      pattern: "mint\\.admin\\.routes\\.viewed"
    - from: "tests/tools/test_redirect_breadcrumb_coverage.py"
      to: ".planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md §Redirect Call-Site Inventory"
      via: "parses the 43-row inventory table, locates each callback in app.dart, counts MintBreadcrumbs.legacyRedirectHit calls per site, asserts match"
      pattern: "per-site expected redirect_branches matches actual source-call count"
---

<objective>
Wave 3 — ship the Flutter admin schema viewer `/admin/routes` behind a compile-time + runtime gate, wire 43 legacy redirects to emit `mint.routing.legacy_redirect.hit` breadcrumbs (per-site coverage proof, not fragile total-grep), and add the D-09 §4 admin-access processing-record breadcrumb with a behavioral Sentry hook-based test (not source-string inspection). Flip 4 Wave 0 widget test stubs green.

Maps to ROADMAP Success Criteria 3 (tree-shake admin UI), 4 (147 routes × 15 owner buckets display), 6 (43 redirect analytics). J0 smoke + tree-shake validation run in Plan 05 Wave 4.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/32-cartographier/32-CONTEXT.md
@.planning/phases/32-cartographier/32-RESEARCH.md
@.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md
@apps/mobile/lib/routes/route_metadata.dart
@apps/mobile/lib/app.dart
@apps/mobile/lib/services/sentry_breadcrumbs.dart
@apps/mobile/lib/services/feature_flags.dart
@apps/mobile/lib/theme/colors.dart
@CLAUDE.md

<interfaces>
<!-- From apps/mobile/lib/services/sentry_breadcrumbs.dart (Phase 31 D-03 4-level naming) -->

class MintBreadcrumbs {
  MintBreadcrumbs._();

  static void complianceGuard({required bool passed, required String surface, List<String>? flaggedTerms});
  static void saveFact({required bool success, required String factKind, String? errorCode});
  static void featureFlagsRefresh({required bool success, String? errorCode, int? flagCount});

  // Phase 32 additions (this plan):
  static void legacyRedirectHit({required String from, required String to});
  static void adminRoutesViewed({required int routeCount, required int featureFlagsEnabledCount, int? snapshotAgeMinutes});
}

<!-- From apps/mobile/lib/services/feature_flags.dart (has enableAdminScreens already; add isAdmin getter) -->

class FeatureFlags {
  static bool enableAdminScreens = false;
  // ... other flags ...

  // Phase 32 addition:
  static bool get isAdmin => const bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false);
}

<!-- From apps/mobile/lib/app.dart: existing redirect shape (43 instances) -->

ScopedGoRoute(path: '/report', redirect: (_, __) => '/rapport'),

<!-- New shape for MAP-05 wiring -->
ScopedGoRoute(path: '/report', redirect: (ctx, state) {
  MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/rapport');
  return '/rapport';
}),

<!-- From apps/mobile/lib/theme/colors.dart (existing tokens) -->
// MintColors.success / warning / error / textMuted / warmWhite / surface
</interfaces>
</context>

<threat_model>
[ASVS L1]
| ID | Threat | Likelihood | Impact | Mitigation | Test |
|----|--------|-----------|--------|-----------|------|
| T-32-04 | Admin UI ships in prod IPA — schema + dev-only descriptions visible to anyone who signs a prod build, violating D-11 + D-03 tree-shake contract | MEDIUM (accidental YAML edit in testflight.yml/play-store.yml) | HIGH (147 internal route names + any dev-only descriptions leak) | (a) Compile-time gate `bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false)` — branch dead-code-eliminated when false. (b) Runtime gate `FeatureFlags.isAdmin` (second layer). (c) Admin route declaration wrapped in `if (AdminGate.isAvailable) ...[ ScopedGoRoute(...) ]`. (d) CI job `admin-build-sanity` (Plan 05) scans prod workflows for `--dart-define=ENABLE_ADMIN=1`. (e) D-11 Task 1 (Plan 05) empirically verifies `strings Runner \| grep -c kRouteRegistry == 0`. | Widget test `admin_shell_gate_test.dart` (gate false-path) + Plan 05 Wave 4 J0 Task 1 tree-shake |
| T-32-02 | PII leakage via admin breadcrumb — `mint.admin.routes.viewed` could include user session data or route-specific context if helper is misused | LOW (this helper is the only one; reviewers check call-site) | MEDIUM (nLPD Art. 12 violation — processing record must be aggregates only) | `MintBreadcrumbs.adminRoutesViewed` parameter surface ALLOWS only `routeCount`, `featureFlagsEnabledCount`, `snapshotAgeMinutes` (int?) — no String fields, no user context reachable. **Behavioral test** (M-2 fix): a `beforeBreadcrumb` capture hook wired into `SentryFlutter.init` intercepts the actual emitted breadcrumb; assertions run on the captured `Breadcrumb` object (exact data-keys set, integer types, negative test that string PII in route params does NOT appear in data). | `routes_registry_breadcrumb_test.dart` (beforeBreadcrumb hook — captures real Breadcrumb object, asserts exact data keys `{route_count, feature_flags_enabled_count, snapshot_age_minutes}`, forbids `user.id`/`email`/path literals) |
</threat_model>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: AdminGate + FeatureFlags.isAdmin + AdminShell + RoutesRegistryScreen + admin route in app.dart</name>
  <files>apps/mobile/lib/screens/admin/admin_gate.dart, apps/mobile/lib/screens/admin/admin_shell.dart, apps/mobile/lib/screens/admin/routes_registry_screen.dart, apps/mobile/lib/services/feature_flags.dart, apps/mobile/lib/app.dart, apps/mobile/test/screens/admin/admin_shell_gate_test.dart, apps/mobile/test/screens/admin/routes_registry_screen_test.dart</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-RESEARCH.md §3 Flutter UI /admin/routes (lines 476-620)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-CONTEXT.md §D-03, D-06, D-08, D-10 (gate + screen + quality)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/app.dart lines 140-260 (router structure, insertion point: after /explore/* before redirects block; `_rootNavigatorKey` at 143)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/feature_flags.dart (existing surface; `enableAdminScreens` at line 80)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/routes/route_metadata.dart (kRouteRegistry + enums)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/theme/colors.dart (MintColors tokens)
  </read_first>
  <behavior>
    - Test 1: `AdminGate.isAvailable` returns false when ENABLE_ADMIN is unset (default).
    - Test 2: With `bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false) == true` (simulated via FeatureFlags override in test), `AdminGate.isAvailable == true`.
    - Test 3: `RoutesRegistryScreen` builds without error when wrapped in `MaterialApp` + mocked registry.
    - Test 4: Screen renders exactly 15 `ExpansionTile` widgets (one per RouteOwner).
    - Test 5: Sum of route rows across all ExpansionTiles == 147.
    - Test 6: Empty-state text shows when registry is empty (simulated via `_registryForTesting` override or substituting a const empty map).
    - Test 7: Footer text contains the literal substring `./tools/mint-routes health` pointing users to the CLI.
  </behavior>
  <action>
    **M-1 fix — dev-only English carve-out.** CLAUDE.md NEVER #1 mandates i18n for all user-facing strings. Admin UI is English-only (hardcoded) by executor discretion under D-03 + D-10 (dev-only surface, ENABLE_ADMIN=0 in prod tree-shakes the whole tree). Phase 34 `no_hardcoded_fr.py` (GUARD-03) MUST exempt `lib/screens/admin/**`. Every admin surface file MUST declare this exemption in its file header docstring so reviewers and future audits have explicit provenance.

    **File 1 — `apps/mobile/lib/screens/admin/admin_gate.dart`:**
    ```dart
    // Dev-only admin surface per D-03 + D-10 (CONTEXT v4).
    // English-only by executor discretion — no i18n/ARB keys.
    // Phase 34 no_hardcoded_fr.py MUST exempt lib/screens/admin/**
    // (TODO: add exemption when Phase 34 plan ships lint-config.yaml).

    /// Phase 32 D-03 + D-10 — AdminGate compile-time + runtime check.
    ///
    /// `/admin/*` routes are ONLY mounted when:
    ///   1. Compile-time: `flutter build ... --dart-define=ENABLE_ADMIN=1` (default 0 = prod).
    ///   2. Runtime: `FeatureFlags.isAdmin` returns true.
    ///
    /// Both gates are LOCAL — no backend `/admin/me` endpoint (D-10 v4).
    /// Phase 33 may add an admin backend endpoint if multi-user admin is needed.
    library;

    import 'package:mint_mobile/services/feature_flags.dart';

    class AdminGate {
      AdminGate._();

      /// Compile-time branch — dead-code-eliminated when false.
      /// Visible to reviewers as `const`, enabling Dart's tree-shake.
      static const bool _compileTimeEnabled =
          bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false);

      /// Both gates must be true. Runtime FeatureFlags.isAdmin is the
      /// second line; compile-time is the tree-shake guarantee.
      static bool get isAvailable => _compileTimeEnabled && FeatureFlags.isAdmin;
    }
    ```

    **File 2 — `apps/mobile/lib/services/feature_flags.dart`** — ADD `isAdmin` getter. Insert immediately after the `enableAdminScreens` field (around line 80-82). Preserve all existing code, do not modify other fields:
    ```dart
    // Phase 32 D-10 — local-only gate for /admin/*.
    // Combined with compile-time ENABLE_ADMIN=1 via AdminGate.
    // NO backend call (D-10 v4 kills proposed /api/v1/admin/me).
    //
    // Phase 32: equals compile-time flag (hardcoded true when ENABLE_ADMIN=1).
    // Phase 33 may refactor FeatureFlags to ChangeNotifier — `isAdmin`
    // would then become an instance-level getter.
    static bool get isAdmin =>
        const bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false);
    ```

    **File 3 — `apps/mobile/lib/screens/admin/admin_shell.dart`:**
    ```dart
    // Dev-only admin surface per D-03 + D-10 (CONTEXT v4).
    // English-only by executor discretion — no i18n/ARB keys.
    // Phase 34 no_hardcoded_fr.py MUST exempt lib/screens/admin/**
    // (TODO: add exemption when Phase 34 plan ships lint-config.yaml).

    /// Phase 32 D-03 — AdminShell shared scaffold. Phase 33 adds /admin/flags
    /// as a second child; NO refactor needed.
    library;

    import 'package:flutter/material.dart';
    import 'package:mint_mobile/theme/colors.dart';

    class AdminShell extends StatelessWidget {
      final Widget child;
      const AdminShell({super.key, required this.child});

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          backgroundColor: MintColors.warmWhite,
          appBar: AppBar(
            // Dev-only English per D-03 + D-10 file header.
            title: const Text('MINT Admin'),
            backgroundColor: MintColors.surface,
            foregroundColor: MintColors.primary,
          ),
          body: SafeArea(child: child),
        );
      }
    }
    ```

    **File 4 — `apps/mobile/lib/screens/admin/routes_registry_screen.dart`:**
    ```dart
    // Dev-only admin surface per D-03 + D-10 (CONTEXT v4).
    // English-only by executor discretion — no i18n/ARB keys.
    // Phase 34 no_hardcoded_fr.py MUST exempt lib/screens/admin/**
    // (TODO: add exemption when Phase 34 plan ships lint-config.yaml).

    /// Phase 32 MAP-02b — pure schema viewer for the 147-entry registry.
    ///
    /// **Contract (D-06 v4):**
    /// - Data source: `kRouteRegistry` (static const) + local FeatureFlags read.
    /// - NO Sentry live health (use `./tools/mint-routes health` terminal).
    /// - NO snapshot JSON read (iOS sandbox makes cross-filesystem share unreliable).
    /// - NO backend call (D-10 local gates only).
    ///
    /// **Access log (D-09 §4):** mount emits `mint.admin.routes.viewed`
    /// breadcrumb with aggregates only (route_count, feature_flags_enabled_count).
    library;

    import 'package:flutter/material.dart';
    import 'package:mint_mobile/routes/route_metadata.dart';
    import 'package:mint_mobile/routes/route_owner.dart';
    import 'package:mint_mobile/services/feature_flags.dart';
    import 'package:mint_mobile/services/sentry_breadcrumbs.dart';
    import 'package:mint_mobile/theme/colors.dart';

    class RoutesRegistryScreen extends StatefulWidget {
      const RoutesRegistryScreen({super.key});

      @override
      State<RoutesRegistryScreen> createState() => _RoutesRegistryScreenState();
    }

    class _RoutesRegistryScreenState extends State<RoutesRegistryScreen> {
      late final Map<RouteOwner, List<RouteMeta>> _grouped;
      late final int _enabledFlagCount;

      @override
      void initState() {
        super.initState();
        _grouped = _groupByOwner(kRouteRegistry);
        _enabledFlagCount = _countEnabledFlags();
        // D-09 §4 — aggregates only, no PII, no path.
        MintBreadcrumbs.adminRoutesViewed(
          routeCount: kRouteRegistry.length,
          featureFlagsEnabledCount: _enabledFlagCount,
          snapshotAgeMinutes: null, // N/A: schema viewer has no snapshot
        );
      }

      Map<RouteOwner, List<RouteMeta>> _groupByOwner(Map<String, RouteMeta> src) {
        final out = <RouteOwner, List<RouteMeta>>{};
        for (final meta in src.values) {
          out.putIfAbsent(meta.owner, () => []).add(meta);
        }
        for (final list in out.values) {
          list.sort((a, b) => a.path.compareTo(b.path));
        }
        return out;
      }

      /// Count boolean flags currently true in FeatureFlags. Uses only
      /// declared static fields — no reflection.
      int _countEnabledFlags() {
        int n = 0;
        if (FeatureFlags.enableAdminScreens) n++;
        // Extend as Phase 33 flags land; for Phase 32 one counter is fine
        // as aggregate — the exact number is not an API contract.
        return n;
      }

      @override
      Widget build(BuildContext context) {
        if (kRouteRegistry.isEmpty) {
          return const Center(
            child: Text(
              'Registry not generated. Run tools/mint-routes reconcile.',
            ),
          );
        }
        final owners = RouteOwner.values;
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: owners.length,
                itemBuilder: (ctx, i) {
                  final owner = owners[i];
                  final routes = _grouped[owner] ?? const [];
                  return ExpansionTile(
                    title: Semantics(
                      label:
                          'Routes owned by ${owner.name}, ${routes.length} entries',
                      child: Text('${owner.name} (${routes.length})'),
                    ),
                    children: routes.map(_buildRow).toList(growable: false),
                  );
                },
              ),
            ),
            _Footer(),
          ],
        );
      }

      Widget _buildRow(RouteMeta meta) {
        return ListTile(
          dense: true,
          title: Text(meta.path),
          subtitle: Text(
            '${meta.category.name} | ${meta.owner.name}'
            '${meta.killFlag != null ? " | kill:${meta.killFlag}" : ""}'
            '${meta.requiresAuth ? " | auth" : " | public"}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: meta.killFlag != null
              ? Icon(Icons.lock_outline,
                  size: 16, color: MintColors.textMuted)
              : null,
        );
      }
    }

    class _Footer extends StatelessWidget {
      @override
      Widget build(BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Live health status: use `./tools/mint-routes health` terminal.\n'
            'This screen shows static schema + local FeatureFlags state only.',
            style: TextStyle(
              fontSize: 11,
              color: MintColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }
    }
    ```

    **File 5 — `apps/mobile/lib/app.dart`** — insertion in routes list. Locate the end of Explorer subtree (grep `path: '/explore'`) and just BEFORE the `// ── Redirects` block or the first `ScopedGoRoute(path: '/dashboard', redirect:`, add:
    ```dart
    // ─────────── Phase 32 MAP-02b — /admin/routes (dev-only, tree-shaken) ───────────
    // Compile-time ENABLE_ADMIN=0 default -> Dart dead-code eliminates this branch
    // entirely (D-11 Task 1 empirically verifies via `strings Runner | grep`).
    if (AdminGate.isAvailable) ...[
      ScopedGoRoute(
        path: '/admin/routes',
        parentNavigatorKey: _rootNavigatorKey,
        scope: RouteScope.authenticated,
        builder: (context, state) => const AdminShell(
          child: RoutesRegistryScreen(),
        ),
      ),
      // Phase 33 adds /admin/flags here using the same AdminShell.
    ],
    ```

    Add imports at top of `app.dart` (if not already present):
    ```dart
    import 'package:mint_mobile/screens/admin/admin_gate.dart';
    import 'package:mint_mobile/screens/admin/admin_shell.dart';
    import 'package:mint_mobile/screens/admin/routes_registry_screen.dart';
    ```

    **File 6 — Flip `apps/mobile/test/screens/admin/admin_shell_gate_test.dart`:**
    ```dart
    import 'package:flutter_test/flutter_test.dart';
    import 'package:mint_mobile/screens/admin/admin_gate.dart';

    void main() {
      group('AdminGate (MAP-02b, D-10)', () {
        test('isAvailable is false when ENABLE_ADMIN is unset (prod default)', () {
          // In test runs, `--dart-define=ENABLE_ADMIN=1` is NOT passed, so
          // `const bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false)`
          // returns false. `AdminGate.isAvailable` is therefore false.
          expect(AdminGate.isAvailable, isFalse);
        });
      });
    }
    ```

    (Note: a test simulating ENABLE_ADMIN=1 requires running `flutter test --dart-define=ENABLE_ADMIN=1 test/screens/admin/admin_shell_gate_test.dart`; document but do not add a second test since `bool.fromEnvironment` constants can't be overridden at test runtime in a single invocation.)

    **File 7 — Flip `apps/mobile/test/screens/admin/routes_registry_screen_test.dart`:**
    ```dart
    import 'package:flutter/material.dart';
    import 'package:flutter_test/flutter_test.dart';
    import 'package:mint_mobile/routes/route_metadata.dart';
    import 'package:mint_mobile/routes/route_owner.dart';
    import 'package:mint_mobile/screens/admin/routes_registry_screen.dart';

    void main() {
      group('RoutesRegistryScreen (MAP-02b)', () {
        testWidgets('renders 15 ExpansionTiles (one per RouteOwner)', (tester) async {
          await tester.pumpWidget(const MaterialApp(
            home: Scaffold(body: RoutesRegistryScreen()),
          ));
          await tester.pumpAndSettle();

          final tiles = find.byType(ExpansionTile);
          expect(tiles, findsNWidgets(RouteOwner.values.length));
          expect(RouteOwner.values.length, 15);
        });

        testWidgets('sum of route rows across all buckets == 147', (tester) async {
          await tester.pumpWidget(const MaterialApp(
            home: Scaffold(body: RoutesRegistryScreen()),
          ));
          await tester.pumpAndSettle();
          // Expand all tiles
          for (final tile in find.byType(ExpansionTile).evaluate()) {
            await tester.tap(find.byWidget(tile.widget));
          }
          await tester.pumpAndSettle();
          // ListTile is rendered per route row
          final rows = find.byType(ListTile);
          expect(rows, findsNWidgets(147),
              reason: 'registry has 147 entries; UI must render all');
        });

        testWidgets('footer points to CLI for live health', (tester) async {
          await tester.pumpWidget(const MaterialApp(
            home: Scaffold(body: RoutesRegistryScreen()),
          ));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('./tools/mint-routes health'),
            findsOneWidget,
          );
        });
      });
    }
    ```

    Run:
    - `cd apps/mobile && flutter test test/screens/admin/admin_shell_gate_test.dart` — 1 test green.
    - `cd apps/mobile && flutter test test/screens/admin/routes_registry_screen_test.dart` — 3 tests green.
    - `cd apps/mobile && flutter analyze lib/screens/admin lib/services/feature_flags.dart lib/routes/` — 0 errors.

    Commit: `feat(32-03): AdminGate + AdminShell + RoutesRegistryScreen + FeatureFlags.isAdmin`.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter analyze lib/screens/admin lib/services/feature_flags.dart 2>&1 | tail -5 && flutter test test/screens/admin/admin_shell_gate_test.dart test/screens/admin/routes_registry_screen_test.dart --reporter=compact 2>&1 | tail -10</automated>
  </verify>
  <acceptance_criteria>
    - `apps/mobile/lib/screens/admin/admin_gate.dart` exists AND contains `bool.fromEnvironment('ENABLE_ADMIN'` AND `FeatureFlags.isAdmin`
    - `apps/mobile/lib/screens/admin/admin_shell.dart` exists AND exports `class AdminShell extends StatelessWidget`
    - `apps/mobile/lib/screens/admin/routes_registry_screen.dart` exists AND imports `kRouteRegistry`
    - **M-1 fix**: `admin_gate.dart`, `admin_shell.dart`, and `routes_registry_screen.dart` EACH contain the literal file-header substring `Dev-only admin surface per D-03 + D-10` (grep-asserted)
    - `apps/mobile/lib/services/feature_flags.dart` contains `static bool get isAdmin` getter
    - `apps/mobile/lib/app.dart` contains `if (AdminGate.isAvailable) ...[` wrapping `path: '/admin/routes'`
    - `flutter analyze lib/screens/admin lib/services/feature_flags.dart` reports 0 errors
    - `flutter test test/screens/admin/admin_shell_gate_test.dart test/screens/admin/routes_registry_screen_test.dart` passes with 4 tests green
    - Screen renders 15 ExpansionTiles and 147 ListTile rows when expanded
    - Footer contains exact substring `./tools/mint-routes health`
  </acceptance_criteria>
  <done>Admin schema viewer shipped behind double gate. File headers declare the D-03+D-10 English carve-out explicitly (M-1). Widget tests prove gate + render + footer. Tree-shake proof lives in Plan 05 Wave 4 (requires real build).</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: MintBreadcrumbs.adminRoutesViewed + MintBreadcrumbs.legacyRedirectHit + wire 43 redirect call-sites + per-site coverage test</name>
  <files>apps/mobile/lib/services/sentry_breadcrumbs.dart, apps/mobile/lib/app.dart, apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart, apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart, tests/tools/test_redirect_breadcrumb_coverage.py</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/sentry_breadcrumbs.dart (current state — 3 helpers, 4-level D-03 naming established)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-CONTEXT.md §D-05 (redirect breadcrumb shape) + §D-09 §4 (admin-access breadcrumb contract)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-RESEARCH.md §6 nLPD controls (lines 718-740), §Must-knows §8 (redirect call-site modification pattern, lines 948-956)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/app.dart (43 redirect call-sites — grep `redirect:\s*\(_,\s*_?_?\)`)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md §Redirect Call-Site Inventory (43 enumerated sites with line + redirect_branches per site — THIS IS THE TEST CONTRACT)
  </read_first>
  <behavior>
    - Test 1 (behavioral, M-2 fix): `SentryFlutter.init` with a `beforeBreadcrumb` hook captures the real `Breadcrumb` emitted by `MintBreadcrumbs.adminRoutesViewed(routeCount: 147, featureFlagsEnabledCount: 2, snapshotAgeMinutes: null)`. Exactly 1 breadcrumb is captured. `category == 'mint.admin.routes.viewed'`.
    - Test 2 (behavioral): captured breadcrumb `data.keys` is EXACTLY `{'route_count', 'feature_flags_enabled_count'}` when `snapshotAgeMinutes == null` (omitted) — no more, no less.
    - Test 3 (behavioral): with `snapshotAgeMinutes: 42`, `data.keys` is EXACTLY `{'route_count', 'feature_flags_enabled_count', 'snapshot_age_minutes'}`; `data['route_count'] == 147` (int, not String); `data['snapshot_age_minutes'] == 42` (int).
    - Test 4 (negative/hostile, M-2 fix): no call-path reaches `adminRoutesViewed` with any string containing `@`, user id, or route-literal. Asserted by parameter-surface contract — the helper accepts ONLY int/int?, so string PII is a compile error. This is verified structurally (compile) rather than at runtime, but also asserted via a negative assertion that captured `data` values are NEVER of type `String`.
    - Test 5 (behavioral): `MintBreadcrumbs.legacyRedirectHit(from: '/report', to: '/rapport')` captures a breadcrumb with category `mint.routing.legacy_redirect.hit` and data `{from: '/report', to: '/rapport'}` (exact 2-key set).
    - Test 6 (anti-leak): calling `legacyRedirectHit` with `state.uri.toString()` is forbidden — static source grep asserts no `state.uri.toString()` inside any `legacyRedirectHit(...)` argument in `app.dart`.
    - Test 7 (M-3 fix — per-site coverage): the new pytest `tests/tools/test_redirect_breadcrumb_coverage.py` parses the RECONCILE-REPORT.md inventory table, parses each of the 43 callbacks in `app.dart`, and asserts `count_of(MintBreadcrumbs.legacyRedirectHit calls inside site N's callback body) == RECONCILE-REPORT.redirect_branches[N]` for every N in [1..43]. The sum matches the inventory's `Totals.Total redirect_branches` field.
  </behavior>
  <action>
    **M-2 fix — behavioral breadcrumb test using Sentry beforeBreadcrumb hook.** The prior Wave 0 stub used source-string grep which is brittle: refactoring to `const _CAT = 'mint.admin.routes.viewed'` would break the test while preserving behavior; conversely, injecting PII into `data` would pass. The real nLPD D-09 §4 contract is about the emitted `Breadcrumb` object. Use `SentryFlutter.init(options: SentryFlutterOptions()..beforeBreadcrumb = (bc, hint) { _captured.add(bc); return null; })` in a `setUpAll` so every test captures the real object.

    **M-3 fix — per-site breadcrumb coverage.** A rigid `grep -c "MintBreadcrumbs.legacyRedirectHit" == 43` assertion breaks the moment any redirect callback has a multi-branch body (e.g., the `/profile` → `/profile/bilan` site has a null pass-through branch). The correct contract is per-site: each call-site emits 1 breadcrumb per redirect-taking branch, 0 per null pass-through. Plan 00 Wave 0 publishes the 43-row inventory; this test parses that inventory and validates each site's callback body against its expected `redirect_branches` count.

    **File 1 — Extend `apps/mobile/lib/services/sentry_breadcrumbs.dart`** — append 2 new static helpers. Preserve all existing methods:
    ```dart
    // Append inside `class MintBreadcrumbs {` before the closing brace:

    /// Phase 32 MAP-05 — legacy redirect hit breadcrumb.
    ///
    /// category = `mint.routing.legacy_redirect.hit`
    /// level    = info
    /// data     = { 'from': String, 'to': String }
    ///
    /// nLPD D-09: [from] and [to] are path-only (no query string, no
    /// user id). Callers MUST pass `state.uri.path` (which excludes query
    /// by go_router contract) — NOT `state.uri.toString()`.
    static void legacyRedirectHit({
      required String from,
      required String to,
    }) {
      Sentry.addBreadcrumb(Breadcrumb(
        category: 'mint.routing.legacy_redirect.hit',
        level: SentryLevel.info,
        data: <String, dynamic>{
          'from': from,
          'to': to,
        },
      ));
    }

    /// Phase 32 D-09 §4 — admin tool access processing record (nLPD Art. 12).
    ///
    /// category = `mint.admin.routes.viewed`
    /// level    = info
    /// data     = { 'route_count': int, 'feature_flags_enabled_count': int,
    ///              'snapshot_age_minutes': int? }
    ///
    /// **Aggregates only.** MUST NOT contain: user identifiers, route paths,
    /// query params, email, IP, or any other PII. The parameter surface
    /// here is int/int? — reviewers can verify no String field reaches Sentry.
    static void adminRoutesViewed({
      required int routeCount,
      required int featureFlagsEnabledCount,
      int? snapshotAgeMinutes,
    }) {
      Sentry.addBreadcrumb(Breadcrumb(
        category: 'mint.admin.routes.viewed',
        level: SentryLevel.info,
        data: <String, dynamic>{
          'route_count': routeCount,
          'feature_flags_enabled_count': featureFlagsEnabledCount,
          if (snapshotAgeMinutes != null) 'snapshot_age_minutes': snapshotAgeMinutes,
        },
      ));
    }
    ```

    **File 2 — Wire 43 redirect call-sites in `apps/mobile/lib/app.dart`:**

    For EACH `ScopedGoRoute(path: 'X', redirect: (_, __) => 'Y')` call-site, transform to:
    ```dart
    ScopedGoRoute(
      path: 'X',
      redirect: (_, state) {
        MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: 'Y');
        return 'Y';
      },
    ),
    ```

    Procedure:
    1. Add import at top of app.dart if missing: `import 'package:mint_mobile/services/sentry_breadcrumbs.dart';` (grep first to check — Phase 31 likely already added it).
    2. Open `.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md` §Redirect Call-Site Inventory — this is the authoritative 43-row list with expected `redirect_branches` per site.
    3. For EACH row in the inventory: edit the callback body so that the number of `MintBreadcrumbs.legacyRedirectHit(...)` calls equals the row's `redirect_branches` count (each redirect-taking return emits once; `return null;` branches emit zero).
    4. For multi-branch sites (e.g., profile at app.dart:906-912 per CONTEXT v4 — `redirect_branches=1, null_pass_through=1`):
       ```dart
       redirect: (_, state) {
         if (state.uri.path == '/profile') {
           MintBreadcrumbs.legacyRedirectHit(from: '/profile', to: '/profile/bilan');
           return '/profile/bilan';
         }
         return null; // pass-through for sub-routes — NO breadcrumb
       }
       ```
    5. Verify per-site counts by running `tests/tools/test_redirect_breadcrumb_coverage.py` (File 5 below) — not a bare `grep -c == 43`.
    6. For the loose total check: `grep -c "MintBreadcrumbs.legacyRedirectHit" apps/mobile/lib/app.dart` returns >= 43 (equal to the inventory's `Totals.Total redirect_branches` sum).

    **File 3 — Flip `apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart` to BEHAVIORAL (M-2 fix):**
    ```dart
    // Behavioral D-09 §4 test using Sentry beforeBreadcrumb capture hook.
    // Captures real Breadcrumb objects emitted by MintBreadcrumbs.* helpers.
    // Supersedes the Wave 0 stub's source-string inspection approach.

    import 'package:flutter_test/flutter_test.dart';
    import 'package:sentry_flutter/sentry_flutter.dart';
    import 'package:mint_mobile/services/sentry_breadcrumbs.dart';

    void main() {
      final List<Breadcrumb> captured = <Breadcrumb>[];

      setUpAll(() async {
        TestWidgetsFlutterBinding.ensureInitialized();
        await SentryFlutter.init((options) {
          options.dsn = '';                  // no network in tests
          options.autoAppStart = false;
          options.attachStacktrace = false;
          options.beforeBreadcrumb = (bc, hint) {
            captured.add(bc);
            return bc; // keep the breadcrumb; returning null would drop it
          };
        });
      });

      setUp(() {
        captured.clear();
      });

      group('MintBreadcrumbs.adminRoutesViewed (D-09 §4) — behavioral', () {
        test('emits exactly 1 breadcrumb with category mint.admin.routes.viewed', () {
          MintBreadcrumbs.adminRoutesViewed(
            routeCount: 147,
            featureFlagsEnabledCount: 2,
            snapshotAgeMinutes: null,
          );
          expect(captured.length, 1);
          expect(captured.single.category, 'mint.admin.routes.viewed');
        });

        test('data keys are EXACTLY {route_count, feature_flags_enabled_count} when snapshotAgeMinutes is null', () {
          MintBreadcrumbs.adminRoutesViewed(
            routeCount: 147,
            featureFlagsEnabledCount: 2,
            snapshotAgeMinutes: null,
          );
          final data = captured.single.data ?? <String, dynamic>{};
          expect(
            data.keys.toSet(),
            equals(<String>{'route_count', 'feature_flags_enabled_count'}),
            reason: 'exact key set — no PII, no extras, no missing',
          );
          expect(data['route_count'], 147);
          expect(data['route_count'], isA<int>());
          expect(data['feature_flags_enabled_count'], 2);
          expect(data['feature_flags_enabled_count'], isA<int>());
        });

        test('data keys include snapshot_age_minutes only when provided', () {
          MintBreadcrumbs.adminRoutesViewed(
            routeCount: 147,
            featureFlagsEnabledCount: 2,
            snapshotAgeMinutes: 42,
          );
          final data = captured.single.data ?? <String, dynamic>{};
          expect(
            data.keys.toSet(),
            equals(<String>{
              'route_count',
              'feature_flags_enabled_count',
              'snapshot_age_minutes',
            }),
          );
          expect(data['snapshot_age_minutes'], 42);
          expect(data['snapshot_age_minutes'], isA<int>());
        });

        test('no data value is a String (structural anti-PII)', () {
          MintBreadcrumbs.adminRoutesViewed(
            routeCount: 147,
            featureFlagsEnabledCount: 2,
            snapshotAgeMinutes: 42,
          );
          final data = captured.single.data ?? <String, dynamic>{};
          for (final v in data.values) {
            expect(v, isNot(isA<String>()),
                reason: 'aggregates are int only — String values forbid PII leakage');
          }
        });
      });

      group('MintBreadcrumbs.legacyRedirectHit (MAP-05) — behavioral', () {
        test('emits 1 breadcrumb with category mint.routing.legacy_redirect.hit', () {
          MintBreadcrumbs.legacyRedirectHit(from: '/report', to: '/rapport');
          expect(captured.length, 1);
          expect(captured.single.category, 'mint.routing.legacy_redirect.hit');
        });

        test('data keys are EXACTLY {from, to}', () {
          MintBreadcrumbs.legacyRedirectHit(from: '/report', to: '/rapport');
          final data = captured.single.data ?? <String, dynamic>{};
          expect(data.keys.toSet(), equals(<String>{'from', 'to'}));
          expect(data['from'], '/report');
          expect(data['to'], '/rapport');
        });
      });
    }
    ```

    **File 4 — Flip `apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart`** (keep as lightweight static assertions for helper presence + anti-leak query-string check; the loose "==43" check is removed — real per-site coverage moved to File 5):
    ```dart
    import 'dart:io';
    import 'package:flutter_test/flutter_test.dart';

    void main() {
      group('legacyRedirectHit wiring (MAP-05) — static guards', () {
        test('MintBreadcrumbs.legacyRedirectHit helper declared', () {
          final src = File('lib/services/sentry_breadcrumbs.dart').readAsStringSync();
          expect(src.contains('static void legacyRedirectHit'), isTrue);
          expect(src.contains("category: 'mint.routing.legacy_redirect.hit'"), isTrue);
        });

        test('breadcrumb data uses state.uri.path — never state.uri.toString()', () {
          final src = File('lib/app.dart').readAsStringSync();
          // Every MintBreadcrumbs.legacyRedirectHit call must use state.uri.path (not .toString())
          final badPattern = RegExp(r'legacyRedirectHit\([^)]*state\.uri\.toString\(\)');
          expect(badPattern.hasMatch(src), isFalse,
              reason: 'Using .toString() leaks query params — must use state.uri.path');
        });

        test('app.dart wires at least 43 legacyRedirectHit calls (inventory sum)', () {
          // Per-site coverage is asserted by
          // tests/tools/test_redirect_breadcrumb_coverage.py using the
          // RECONCILE-REPORT inventory. This test is the loose lower bound
          // (sum across all sites of redirect_branches >= 43, since no site
          // has zero redirect-taking branches).
          final src = File('lib/app.dart').readAsStringSync();
          final count = 'MintBreadcrumbs.legacyRedirectHit'.allMatches(src).length;
          expect(count, greaterThanOrEqualTo(43),
              reason: 'Wave 0 reconciled 43 redirects; every one emits breadcrumb at least once');
        });
      });
    }
    ```

    **File 5 — NEW `tests/tools/test_redirect_breadcrumb_coverage.py` (M-3 fix — per-site coverage):**
    ```python
    """Phase 32 Wave 3 — per-call-site breadcrumb coverage test.

    Parses .planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md §Redirect
    Call-Site Inventory and validates each of the 43 redirect callbacks in
    apps/mobile/lib/app.dart emits the expected number of
    MintBreadcrumbs.legacyRedirectHit calls per the inventory's redirect_branches
    column.

    Supersedes the fragile `grep -c == 43` total assertion (M-3 checker finding).
    """
    from __future__ import annotations

    import re
    from pathlib import Path
    from typing import Any, Dict, List

    import pytest

    REPO_ROOT = Path(__file__).resolve().parents[2]
    RECONCILE = REPO_ROOT / ".planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md"
    APP_DART = REPO_ROOT / "apps/mobile/lib/app.dart"


    def _parse_inventory() -> List[Dict[str, Any]]:
        """Parse RECONCILE-REPORT.md §Redirect Call-Site Inventory table.

        Returns list of 43 dicts, each with: site_no, line, source, targets,
        redirect_branches, null_pass_through.
        """
        if not RECONCILE.exists():
            pytest.skip("RECONCILE-REPORT.md not yet produced (Plan 00 Wave 0 artifact)")
        text = RECONCILE.read_text()
        # Find the §Redirect Call-Site Inventory section, then the pipe table.
        sec = re.search(
            r"##\s+Redirect Call-Site Inventory.*?(?=\n##\s)",
            text,
            flags=re.DOTALL,
        )
        if not sec:
            pytest.fail("Section '## Redirect Call-Site Inventory' not found")
        rows_src = sec.group(0)
        # Inventory table rows look like: | 1 | 284 | /report | /rapport | 1 | 0 | ...
        row_re = re.compile(
            r"\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|"
        )
        rows: List[Dict[str, Any]] = []
        for m in row_re.finditer(rows_src):
            rows.append({
                "site_no": int(m.group(1)),
                "line": int(m.group(2)),
                "source": m.group(3).strip(),
                "targets": m.group(4).strip(),
                "redirect_branches": int(m.group(5)),
                "null_pass_through": int(m.group(6)),
            })
        return rows


    def _extract_callback_body(src: str, line_no: int) -> str:
        """Extract the callback body starting at approx `line_no`, bounded by
        balanced braces/parens. Returns the smallest self-contained slice that
        contains the redirect callback.
        """
        lines = src.splitlines()
        # Start a few lines before the reported line to catch the `redirect: (…) {`.
        start = max(0, line_no - 3)
        # Walk forward until brace balance returns to zero at least once after open.
        depth = 0
        opened = False
        slice_lines: List[str] = []
        for i in range(start, min(len(lines), line_no + 40)):
            slice_lines.append(lines[i])
            for ch in lines[i]:
                if ch == "{":
                    depth += 1
                    opened = True
                elif ch == "}":
                    depth -= 1
                    if opened and depth == 0:
                        return "\n".join(slice_lines)
            # Arrow form: `redirect: (_, __) => '/target',` — single-line, no braces.
            if "redirect:" in lines[i] and "=>" in lines[i] and "{" not in lines[i]:
                return lines[i]
        return "\n".join(slice_lines)


    def test_reconcile_report_lists_43_redirect_sites():
        rows = _parse_inventory()
        assert len(rows) == 43, (
            f"RECONCILE-REPORT inventory should enumerate exactly 43 sites, got {len(rows)}"
        )


    def test_per_site_breadcrumb_coverage_matches_inventory():
        rows = _parse_inventory()
        src = APP_DART.read_text()

        breadcrumb_re = re.compile(r"MintBreadcrumbs\.legacyRedirectHit\s*\(")
        failures: List[str] = []

        for row in rows:
            body = _extract_callback_body(src, row["line"])
            actual = len(breadcrumb_re.findall(body))
            expected = row["redirect_branches"]
            if actual != expected:
                failures.append(
                    f"site #{row['site_no']} (line {row['line']}, source={row['source']}): "
                    f"expected {expected} MintBreadcrumbs.legacyRedirectHit call(s), got {actual}"
                )

        assert not failures, "Per-site breadcrumb coverage mismatch:\n  " + "\n  ".join(failures)


    def test_total_emissions_equals_inventory_sum():
        """Cross-check: global count matches the sum of redirect_branches.

        Tighter than the Wave 0 loose `>=43` check because it ties the concrete
        number to the inventory's authoritative sum.
        """
        rows = _parse_inventory()
        expected_sum = sum(r["redirect_branches"] for r in rows)
        src = APP_DART.read_text()
        actual = len(re.findall(r"MintBreadcrumbs\.legacyRedirectHit\s*\(", src))
        assert actual == expected_sum, (
            f"Total breadcrumb source-call count {actual} != RECONCILE inventory sum {expected_sum}"
        )
    ```

    Run:
    - `cd apps/mobile && flutter test test/screens/admin/routes_registry_breadcrumb_test.dart test/routes/legacy_redirect_breadcrumb_test.dart` — all behavioral + static tests green.
    - `cd /Users/julienbattaglia/Desktop/MINT && python3 -m pytest tests/tools/test_redirect_breadcrumb_coverage.py -q` — 3 tests green.
    - `cd apps/mobile && flutter analyze lib/services/sentry_breadcrumbs.dart lib/app.dart` — 0 errors.
    - Full Flutter suite regression smoke: `cd apps/mobile && flutter test test/routes/ test/screens/admin/` — all green.

    Commit: `feat(32-03): adminRoutesViewed + legacyRedirectHit breadcrumbs + 43-site wiring + behavioral + per-site coverage tests`.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT && python3 -m pytest tests/tools/test_redirect_breadcrumb_coverage.py -q 2>&1 | tail -10 && (cd apps/mobile && flutter test test/screens/admin/routes_registry_breadcrumb_test.dart test/routes/legacy_redirect_breadcrumb_test.dart --reporter=compact 2>&1 | tail -10)</automated>
  </verify>
  <acceptance_criteria>
    - `apps/mobile/lib/services/sentry_breadcrumbs.dart` contains `static void legacyRedirectHit` AND `static void adminRoutesViewed`
    - Literal strings `'mint.routing.legacy_redirect.hit'` AND `'mint.admin.routes.viewed'` present in `sentry_breadcrumbs.dart`
    - `grep -c "MintBreadcrumbs.legacyRedirectHit" apps/mobile/lib/app.dart` returns >= 43 (equal to RECONCILE-REPORT `Totals.Total redirect_branches` sum)
    - `grep "state.uri.toString" apps/mobile/lib/app.dart` returns nothing inside a `legacyRedirectHit(...)` argument (query-param leak blocked)
    - **M-2 fix**: `flutter test test/screens/admin/routes_registry_breadcrumb_test.dart` passes and uses `SentryFlutter.init` + `beforeBreadcrumb` hook (behavioral) — NOT source-grep. Test file contains `beforeBreadcrumb` and does NOT contain `readAsStringSync` for sentry_breadcrumbs.dart inspection.
    - **M-3 fix**: `tests/tools/test_redirect_breadcrumb_coverage.py` passes 3 tests; per-site breadcrumb count matches RECONCILE-REPORT inventory `redirect_branches` value for every one of the 43 sites.
    - `flutter test test/routes/legacy_redirect_breadcrumb_test.dart` passes (3 static-guard tests)
    - `flutter analyze lib/services/sentry_breadcrumbs.dart lib/app.dart` reports 0 errors
    - Running the full suite (`flutter test`) shows no regression from breadcrumb additions
  </acceptance_criteria>
  <done>All 43 legacy redirect call-sites emit analytics breadcrumbs per their per-site redirect_branches count (M-3). Admin access log emits aggregates-only processing record, asserted BEHAVIORALLY via Sentry beforeBreadcrumb hook (M-2). Six Wave 0 widget test stubs flipped green plus 1 new pytest file for per-site coverage.</done>
</task>

</tasks>

<verification>
End-of-plan gate (must be green before Wave 4 starts):
- Flutter widget tests for admin shell/screen + breadcrumb helpers all green (behavioral, not source-grep).
- Per-site breadcrumb coverage proven by `tests/tools/test_redirect_breadcrumb_coverage.py` — every one of the 43 RECONCILE-REPORT sites has the expected `redirect_branches` number of MintBreadcrumbs.legacyRedirectHit calls in its callback body.
- `flutter analyze` 0 errors across all touched files.
- No query-param leakage in breadcrumb data (regex test enforces).
- Admin UI files declare the D-03+D-10 English carve-out in their file headers (M-1).
- Full Flutter suite regression smoke: no pre-existing tests broken by breadcrumb additions.

Two commits recommended: one per task for clean review. Branch `feature/v2.8-phase-32-cartographier`.
</verification>

<success_criteria>
- `/admin/routes` schema viewer ships behind compile-time + runtime gate (T-32-04 mitigated via double gate + Plan 05 J0 tree-shake verification)
- 147 routes × 15 owner buckets rendered correctly (widget test counts enforce)
- Admin mount emits aggregates-only breadcrumb asserted behaviorally via Sentry beforeBreadcrumb hook (T-32-02 mitigated — M-2 fix)
- 43 legacy redirects emit path-only breadcrumbs per their per-site branch structure (nLPD D-09 §2 path-not-full-URI discipline; M-3 coverage contract)
- Phase 33 can reuse `AdminShell` without refactor (D-03 contract preserved)
- Admin English carve-out is explicit in every file header — Phase 34 no_hardcoded_fr.py can exempt `lib/screens/admin/**` safely (M-1 fix)
</success_criteria>

<output>
After completion, create `.planning/phases/32-cartographier/32-03-SUMMARY.md` with:
- Admin UI surface overview (gate chain + screen structure + English carve-out declaration)
- MintBreadcrumbs surface (2 new helpers + parameter discipline)
- 43-redirect wiring proof (per-site coverage result from `test_redirect_breadcrumb_coverage.py`)
- Widget + behavioral + pytest coverage summary
- Commit SHA
- Wave 4 unblock: J0 smoke + tree-shake verification can run
- Cross-phase dependency flag for Phase 34: `lib/screens/admin/**` must be exempt from `no_hardcoded_fr.py`
</output>
</content>
