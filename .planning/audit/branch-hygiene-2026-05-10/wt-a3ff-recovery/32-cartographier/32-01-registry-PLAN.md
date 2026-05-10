---
phase: 32
plan: 1
plan_number: 01
slug: registry
type: execute
wave: 1
status: pending
depends_on: [reconcile]
files_modified:
  - apps/mobile/lib/routes/route_metadata.dart
  - apps/mobile/lib/routes/route_category.dart
  - apps/mobile/lib/routes/route_owner.dart
  - apps/mobile/test/routes/route_metadata_test.dart
requirements:
  - MAP-01
threats:
  - T-32-01
autonomous: true
must_haves:
  truths:
    - "`kRouteRegistry: Map<String, RouteMeta>` exists with exactly 147 entries, keys matching app.dart paths"
    - "Every RouteOwner enum value appears in at least one registry entry; 15 values total"
    - "`RouteCategory` has 4 values {destination, flow, tool, alias} (D-01 locked)"
    - "`/explore/retraite` owner=explore (D-01 v4 first-segment rule verified)"
    - "`kRouteRegistry` is declared `const` to enable tree-shake when no runtime consumer exists"
  artifacts:
    - path: "apps/mobile/lib/routes/route_metadata.dart"
      provides: "RouteMeta class + kRouteRegistry const Map<String, RouteMeta>"
      contains: "const Map<String, RouteMeta> kRouteRegistry = {"
    - path: "apps/mobile/lib/routes/route_category.dart"
      provides: "RouteCategory enum (4 values)"
    - path: "apps/mobile/lib/routes/route_owner.dart"
      provides: "RouteOwner enum (15 values)"
  key_links:
    - from: "apps/mobile/lib/app.dart 147 GoRoute paths"
      to: "kRouteRegistry 147 keys"
      via: "1:1 key-to-path mapping"
      pattern: "kRouteRegistry.keys.toSet() == appDartPaths.toSet()"
    - from: "RouteOwner enum values"
      to: "Phase 33 FLAG-05 11 flag-groups"
      via: "11 flag-group owners align with 11 planned flags + 4 infra owners"
      pattern: "RouteOwner.values.length == 15"
---

<objective>
Wave 1 — ship the Dart source of truth. Create `apps/mobile/lib/routes/{route_metadata,route_category,route_owner}.dart` with `RouteMeta` class, enum definitions, and `kRouteRegistry` populated with 147 entries matching Wave 0's extracted paths. Flip `apps/mobile/test/routes/route_metadata_test.dart` stubs from SKIP to passing. Tree-shake validation is deferred to Wave 4 J0 gate (manual build).

Maps to ROADMAP Success Criterion 1 (registry schema + 147 entries).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/32-cartographier/32-CONTEXT.md
@.planning/phases/32-cartographier/32-RESEARCH.md
@.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md
@apps/mobile/lib/app.dart
@CLAUDE.md

<interfaces>
<!-- D-01 locked schema — RESEARCH.md §1 lines 237-276 -->

// apps/mobile/lib/routes/route_metadata.dart
import 'route_category.dart';
import 'route_owner.dart';

class RouteMeta {
  final String path;
  final RouteCategory category;
  final RouteOwner owner;
  final bool requiresAuth;
  final String? killFlag;
  final String? description;
  final String? sentryTag;

  const RouteMeta({
    required this.path,
    required this.category,
    required this.owner,
    required this.requiresAuth,
    this.killFlag,
    this.description,
    this.sentryTag,
  });
}

// apps/mobile/lib/routes/route_category.dart
enum RouteCategory { destination, flow, tool, alias }

// apps/mobile/lib/routes/route_owner.dart
enum RouteOwner {
  retraite, famille, travail, logement, fiscalite, patrimoine, sante,
  coach, scan, budget, anonymous,
  auth, admin, system, explore,
}

<!-- Publication shape -->
const Map<String, RouteMeta> kRouteRegistry = {
  '/': RouteMeta(
    path: '/',
    category: RouteCategory.destination,
    owner: RouteOwner.anonymous,
    requiresAuth: false,
  ),
  // ... 146 more
};
</interfaces>
</context>

<threat_model>
[ASVS L1]
| ID | Threat | Likelihood | Impact | Mitigation | Test |
|----|--------|-----------|--------|-----------|------|
| T-32-01 | Tree-shake leak — `kRouteRegistry` (147 entries × path + description dev-only strings) ships in prod IPA, bloating binary and leaking internal schema + dev-only descriptions | MEDIUM | LOW (dev-only schema, no PII; but policy violation of D-11) | Declare `kRouteRegistry` as top-level `const Map<>`. ONLY consumer is `AdminShell` (Plan 03) guarded by compile-time `bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false)` branch. No global import path chain. Wave 4 Task J0-01 empirically verifies `strings build/.../Runner \| grep -c kRouteRegistry == 0`. | Plan 05 Wave 4 J0 Task 1 (`flutter build ios --dart-define=ENABLE_ADMIN=0` + `strings \| grep`) |
</threat_model>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create RouteMeta class + RouteCategory + RouteOwner enums</name>
  <files>apps/mobile/lib/routes/route_category.dart, apps/mobile/lib/routes/route_owner.dart, apps/mobile/lib/routes/route_metadata.dart</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-CONTEXT.md §D-01 (locked schema)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-RESEARCH.md §1 Route registry schema (lines 237-307)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/test/routes/route_metadata_test.dart (Wave 0 stubs — will flip from skip)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/theme/colors.dart (existing file-header convention for `library;` + imports)
  </read_first>
  <behavior>
    - Test 1: `RouteMeta` constructor accepts all 7 named params (3 required, 4 optional) and exposes them as `final` fields.
    - Test 2: `RouteMeta` is `const`-constructible (compiler accepts `const RouteMeta(path: '/', ...)` in test literal).
    - Test 3: `RouteCategory.values.length == 4` and values are `[destination, flow, tool, alias]` in declaration order.
    - Test 4: `RouteOwner.values.length == 15` and includes 11 flag-group owners (retraite, famille, travail, logement, fiscalite, patrimoine, sante, coach, scan, budget, anonymous) + 4 infra (auth, admin, system, explore).
  </behavior>
  <action>
    **File 1 — `apps/mobile/lib/routes/route_category.dart`:**
    ```dart
    /// Phase 32 MAP-01 — route category taxonomy (D-01 locked v4).
    ///
    /// - `destination`: terminal screen the user lands on (/home, /coach).
    /// - `flow`: multi-step sequence (/auth/register, /scan/capture).
    /// - `tool`: utility/admin surface (/admin/routes, /debug/*).
    /// - `alias`: pure redirect target (/report -> /rapport).
    library;

    enum RouteCategory {
      destination,
      flow,
      tool,
      alias,
    }
    ```

    **File 2 — `apps/mobile/lib/routes/route_owner.dart`:**
    ```dart
    /// Phase 32 MAP-01 — route ownership taxonomy (D-01 v4).
    ///
    /// 11 flag-group owners align 1:1 with Phase 33 FLAG-05 kill-switches:
    ///   retraite, famille, travail, logement, fiscalite, patrimoine, sante,
    ///   coach, scan, budget, anonymous.
    /// 4 infra owners have no kill-flag (always available):
    ///   auth, admin, system, explore.
    ///
    /// **Ambiguity rule (D-01 v4):** first path segment wins.
    ///   `/explore/retraite` -> owner=explore (NOT retraite).
    ///   `/coach/chat/from-budget` -> owner=coach (NOT budget).
    library;

    enum RouteOwner {
      // 11 flag-group owners (Phase 33 FLAG-05)
      retraite,
      famille,
      travail,
      logement,
      fiscalite,
      patrimoine,
      sante,
      coach,
      scan,
      budget,
      anonymous,
      // 4 infra owners (no kill-flag, always available)
      auth,
      admin,
      system,
      explore,
    }
    ```

    **File 3 — `apps/mobile/lib/routes/route_metadata.dart`** (ONLY the class + imports + file doctring; `kRouteRegistry` const Map lands in Task 2 to keep diffs reviewable):
    ```dart
    /// Phase 32 MAP-01 — `RouteMeta` class + `kRouteRegistry` const Map.
    ///
    /// **Source of truth for 147 mobile routes.** Consumed by:
    /// - `tools/mint-routes` CLI (Python, via `reconcile` subcommand grep)
    /// - `/admin/routes` Flutter schema viewer (Plan 32-03, tree-shaken prod)
    /// - `tools/checks/route_registry_parity.py` (Plan 32-04 lint, fails CI on drift)
    ///
    /// **Tree-shake contract (D-11 Task 1 Wave 4 validates):**
    /// When `--dart-define=ENABLE_ADMIN=0` (prod default), the only consumer
    /// `AdminShell` is compile-time eliminated, detaching `kRouteRegistry`.
    /// `strings Runner \| grep -c kRouteRegistry` MUST return 0.
    ///
    /// **Owner ambiguity (D-01 v4):** first path segment wins. See
    /// `route_owner.dart` for the rule + examples.
    library;

    import 'route_category.dart';
    import 'route_owner.dart';

    class RouteMeta {
      /// The GoRoute path string. MUST match `app.dart` exactly.
      /// Sub-routes are stored as composed paths (e.g., `/profile/bilan`).
      final String path;

      /// Taxonomy slot — see `route_category.dart`.
      final RouteCategory category;

      /// Ownership bucket — see `route_owner.dart`.
      final RouteOwner owner;

      /// Whether navigating here requires a logged-in session.
      /// Anonymous-local-mode users may or may not satisfy this — callers
      /// check `AuthProvider.isLocalMode` separately per `app.dart:273`.
      final bool requiresAuth;

      /// Optional kill-flag name — references `FeatureFlags.<name>` key,
      /// consumed by Phase 33 FLAG-01 `requireFlag()` middleware.
      final String? killFlag;

      /// Optional dev-only description. Tree-shake contract requires this
      /// string to NOT ship to prod (D-11 Task 1).
      final String? description;

      /// Optional Sentry `transaction.name` override. When null, CLI
      /// queries use `path` verbatim (SDK auto-sets transaction.name to
      /// route path per Phase 31 `app.dart:184` wiring).
      final String? sentryTag;

      const RouteMeta({
        required this.path,
        required this.category,
        required this.owner,
        required this.requiresAuth,
        this.killFlag,
        this.description,
        this.sentryTag,
      });
    }

    // kRouteRegistry declared in Task 2 (keeps this task's diff <200 LOC for review).
    ```

    **Flip test file `apps/mobile/test/routes/route_metadata_test.dart`** from Wave 0 skip stubs to real assertions:
    ```dart
    import 'package:flutter_test/flutter_test.dart';
    import 'package:mint_mobile/routes/route_metadata.dart';
    import 'package:mint_mobile/routes/route_category.dart';
    import 'package:mint_mobile/routes/route_owner.dart';

    void main() {
      group('RouteMeta schema (MAP-01 D-01)', () {
        test('RouteMeta is const-constructible with minimal required fields', () {
          const meta = RouteMeta(
            path: '/test',
            category: RouteCategory.destination,
            owner: RouteOwner.system,
            requiresAuth: false,
          );
          expect(meta.path, '/test');
          expect(meta.category, RouteCategory.destination);
          expect(meta.owner, RouteOwner.system);
          expect(meta.requiresAuth, isFalse);
          expect(meta.killFlag, isNull);
          expect(meta.description, isNull);
          expect(meta.sentryTag, isNull);
        });

        test('RouteMeta exposes all 7 fields as final', () {
          const meta = RouteMeta(
            path: '/x',
            category: RouteCategory.flow,
            owner: RouteOwner.coach,
            requiresAuth: true,
            killFlag: 'enableCoachChat',
            description: 'dev note',
            sentryTag: '/coach-override',
          );
          expect(meta.killFlag, 'enableCoachChat');
          expect(meta.description, 'dev note');
          expect(meta.sentryTag, '/coach-override');
        });
      });

      group('RouteCategory enum (D-01)', () {
        test('has exactly 4 values in declared order', () {
          expect(RouteCategory.values, [
            RouteCategory.destination,
            RouteCategory.flow,
            RouteCategory.tool,
            RouteCategory.alias,
          ]);
        });
      });

      group('RouteOwner enum (D-01)', () {
        test('has exactly 15 values', () {
          expect(RouteOwner.values.length, 15);
        });

        test('includes 11 flag-group owners (Phase 33 FLAG-05)', () {
          const flagGroups = {
            RouteOwner.retraite, RouteOwner.famille, RouteOwner.travail,
            RouteOwner.logement, RouteOwner.fiscalite, RouteOwner.patrimoine,
            RouteOwner.sante, RouteOwner.coach, RouteOwner.scan,
            RouteOwner.budget, RouteOwner.anonymous,
          };
          expect(flagGroups.length, 11);
          expect(RouteOwner.values.toSet().containsAll(flagGroups), isTrue);
        });

        test('includes 4 infra owners', () {
          const infra = {
            RouteOwner.auth, RouteOwner.admin,
            RouteOwner.system, RouteOwner.explore,
          };
          expect(infra.length, 4);
          expect(RouteOwner.values.toSet().containsAll(infra), isTrue);
        });
      });
    }
    ```

    Run: `cd apps/mobile && flutter test test/routes/route_metadata_test.dart` — must pass 5 green, 0 skipped among the tests rewritten above. (kRouteRegistry count test still SKIP until Task 2 lands.)

    Naming note (per CLAUDE.md accent discipline): file docstrings are technical English; no FR strings touched.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter test test/routes/route_metadata_test.dart --reporter=compact 2>&1 | tail -10</automated>
  </verify>
  <acceptance_criteria>
    - `apps/mobile/lib/routes/route_category.dart` exists AND `grep -c "enum RouteCategory" apps/mobile/lib/routes/route_category.dart` returns 1
    - `apps/mobile/lib/routes/route_owner.dart` exists AND `grep -c "  retraite,\|  anonymous,\|  admin," apps/mobile/lib/routes/route_owner.dart` returns ≥3
    - `apps/mobile/lib/routes/route_metadata.dart` exists AND contains `class RouteMeta {` AND `const RouteMeta({`
    - `flutter test test/routes/route_metadata_test.dart` exits 0 with at least 5 tests passing (schema/enum tests) — kRouteRegistry size test may still skip
    - `flutter analyze apps/mobile/lib/routes/ apps/mobile/test/routes/route_metadata_test.dart` reports 0 errors
  </acceptance_criteria>
  <done>Schema + enums published. Task 2 can populate kRouteRegistry.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Populate kRouteRegistry with 147 entries + flip registry-size test green</name>
  <files>apps/mobile/lib/routes/route_metadata.dart, apps/mobile/test/routes/route_metadata_test.dart</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/routes/route_metadata.dart (Task 1 state — class defined, registry TODO)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md (147 extracted paths — source of truth)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/app.dart (cross-check scope: `RouteScope.public` -> requiresAuth=false; `RouteScope.authenticated` or default -> requiresAuth=true)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/feature_flags.dart (Phase 33 kill-flag field names: enableCoachChat, enableScan, enableBudget, enableAnonymousFlow, enableExplorerRetraite/Famille/Travail/Logement/Fiscalite/Patrimoine/Sante — assign per FLAG-05)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-CONTEXT.md §D-01 owner ambiguity rule
  </read_first>
  <behavior>
    - Test 1: `kRouteRegistry.length == 147`.
    - Test 2: `kRouteRegistry.keys.toSet()` == set of paths extracted in Task 1 report (cross-check via fixture embedded in test, or read from a companion generated `.dart` file).
    - Test 3: Every `RouteOwner` enum value appears in ≥1 entry (15 distinct owners used).
    - Test 4: `/explore/retraite` has `owner == RouteOwner.explore` (D-01 v4 first-segment rule).
    - Test 5: `/retraite` (hub entry) has `owner == RouteOwner.retraite`.
    - Test 6: `/coach/chat/from-budget` (if present in app.dart) has `owner == RouteOwner.coach`.
    - Test 7: Every entry's `path` field equals the map key.
    - Test 8: Every entry with `requiresAuth=false` maps to a route declared `RouteScope.public` or `RouteScope.onboarding` in app.dart (spot-check 10 entries programmatically via cross-reference list).
  </behavior>
  <action>
    Append to `apps/mobile/lib/routes/route_metadata.dart` (after the `RouteMeta` class):

    ```dart
    /// D-01 locked: 147 entries, 1:1 with `apps/mobile/lib/app.dart` paths as of
    /// Wave 0 reconciliation (see `.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md`).
    ///
    /// Maintenance contract: ANY added/removed `GoRoute`/`ScopedGoRoute` in
    /// `app.dart` MUST be mirrored here. Parity lint
    /// (`tools/checks/route_registry_parity.py`) enforces on every push via CI.
    ///
    /// Kill-flag assignments align with Phase 33 FLAG-05 11-group taxonomy:
    /// enableCoachChat / enableScan / enableBudget / enableAnonymousFlow /
    /// enableExplorerRetraite / enableExplorerFamille / enableExplorerTravail /
    /// enableExplorerLogement / enableExplorerFiscalite / enableExplorerPatrimoine /
    /// enableExplorerSante. Infra owners (auth, admin, system, explore root)
    /// have no kill-flag — they are always reachable.
    const Map<String, RouteMeta> kRouteRegistry = <String, RouteMeta>{
      // Root / landing
      '/': RouteMeta(
        path: '/',
        category: RouteCategory.destination,
        owner: RouteOwner.anonymous,
        requiresAuth: false,
      ),

      // Auth flows (public scope)
      '/auth/login': RouteMeta(
        path: '/auth/login',
        category: RouteCategory.flow,
        owner: RouteOwner.auth,
        requiresAuth: false,
      ),
      '/auth/register': RouteMeta(
        path: '/auth/register',
        category: RouteCategory.flow,
        owner: RouteOwner.auth,
        requiresAuth: false,
      ),
      // ... 144 more entries following the same pattern ...

      // Example — first-segment rule (D-01 v4):
      // '/explore/retraite' has owner=explore (NOT retraite) because
      // Explorer hub wraps the whole /explore/* subtree.
      '/explore/retraite': RouteMeta(
        path: '/explore/retraite',
        category: RouteCategory.destination,
        owner: RouteOwner.explore,
        requiresAuth: true,
        killFlag: 'enableExplorerRetraite',
        description: 'Retirement domain entry under Explorer hub',
      ),

      // But the standalone retraite hub IS owner=retraite:
      '/retraite': RouteMeta(
        path: '/retraite',
        category: RouteCategory.destination,
        owner: RouteOwner.retraite,
        requiresAuth: true,
        killFlag: 'enableExplorerRetraite',
        description: 'Retirement scenarios hub',
      ),
    };
    ```

    **Populating the 147 entries:**

    1. Read the extracted path list from `.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md`.
    2. For each path, determine:
       - `path`: verbatim from the list.
       - `category`: infer from path shape:
         - Starts with `/auth/` or `/onboarding` -> `flow`.
         - Is a redirect target (checked via grep `redirect: (_, __) => '${path}'` in app.dart) -> NOT a separate entry (the redirects map to existing paths; still include the source path as `alias`).
         - `/admin/*`, `/debug/*`, `/test-*` -> `tool`.
         - Everything else -> `destination`.
       - `owner`: D-01 first-segment wins.
         - `/coach/*` -> coach; `/scan/*` -> scan; `/budget/*` -> budget; `/explore/*` -> explore.
         - `/auth/*` -> auth; `/admin/*` -> admin.
         - Standalone hubs `/retraite`, `/pilier-3a` -> retraite, fiscalite.
         - `/anonymous/*` -> anonymous.
         - `/` (root) -> anonymous (landing is public).
         - Everything that doesn't fit -> system.
       - `requiresAuth`: scan app.dart for the route's `RouteScope`. Public/onboarding -> false; authenticated -> true.
       - `killFlag`: map per FLAG-05:
         - coach owner -> `enableCoachChat` (only for /coach/chat and descendants; hub /coach may be null).
         - scan -> `enableScan`.
         - budget -> `enableBudget`.
         - anonymous -> `enableAnonymousFlow`.
         - explore + single-segment domain (e.g., /explore/retraite) -> `enableExplorerRetraite`/Famille/Travail/Logement/Fiscalite/Patrimoine/Sante.
         - auth/admin/system/explore root -> null (infra always-on).
       - `description`: short dev-only sentence; optional. ONLY add when it aids reviewers (e.g., "Magic link landing", "Legacy alias for /rapport"). Keep under 80 chars.
       - `sentryTag`: null for all Phase 32 entries (SDK auto-sets transaction.name = path).

    3. Use a helper script to validate keys match extracted paths before shipping:
       ```bash
       python3 -c "
       import re
       src = open('apps/mobile/lib/routes/route_metadata.dart').read()
       keys = sorted(set(re.findall(r\"^  '([^']+)':\s*RouteMeta\", src, re.MULTILINE)))
       extracted = [l.strip() for l in open('.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md').read().splitlines() if l.strip().startswith('/')]
       # Allow report section markers; normalize
       extracted_set = sorted(set(p for p in extracted if p.startswith('/') and ' ' not in p))
       diff_missing = set(extracted_set) - set(keys)
       diff_extra = set(keys) - set(extracted_set)
       print(f'Registry keys: {len(keys)}')
       print(f'Extracted paths: {len(extracted_set)}')
       print(f'Missing from registry: {sorted(diff_missing)[:10]}')
       print(f'Extra in registry: {sorted(diff_extra)[:10]}')
       assert len(keys) == 147, f'expected 147, got {len(keys)}'
       assert not diff_missing, f'registry missing {len(diff_missing)} paths'
       assert not diff_extra, f'registry has {len(diff_extra)} ghost paths'
       print('OK 147 entries, 1:1 with app.dart')
       "
       ```

    **Flip registry-size tests to green** in `apps/mobile/test/routes/route_metadata_test.dart`:
    ```dart
    // Append to existing test main():
    group('kRouteRegistry content (MAP-01)', () {
      test('has exactly 147 entries', () {
        expect(kRouteRegistry.length, 147);
      });

      test('every entry path matches its key', () {
        for (final entry in kRouteRegistry.entries) {
          expect(entry.key, entry.value.path,
              reason: 'Registry key ${entry.key} does not match RouteMeta.path ${entry.value.path}');
        }
      });

      test('every RouteOwner enum value is used at least once', () {
        final usedOwners = kRouteRegistry.values.map((m) => m.owner).toSet();
        expect(usedOwners.length, 15,
            reason: 'expected all 15 owners used, got ${usedOwners.length}: $usedOwners');
      });

      test('D-01 v4 first-segment rule: /explore/retraite owner=explore', () {
        final meta = kRouteRegistry['/explore/retraite'];
        expect(meta, isNotNull);
        expect(meta!.owner, RouteOwner.explore);
      });

      test('/retraite standalone hub owner=retraite', () {
        final meta = kRouteRegistry['/retraite'];
        expect(meta, isNotNull);
        expect(meta!.owner, RouteOwner.retraite);
      });
    });
    ```

    Run `cd apps/mobile && flutter test test/routes/route_metadata_test.dart` — ALL tests green (0 skipped for the schema/registry tests). JSON stability stub stays skipped (Plan 32-02 Wave 2 territory).

    Git discipline: commit on `feature/v2.8-phase-32-cartographier` branch. Single commit `feat(32): Wave 1 kRouteRegistry 147 entries + enums`. Do NOT merge to dev — PR gate per CLAUDE.md feedback_clean_push_protocol.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter test test/routes/route_metadata_test.dart --reporter=compact 2>&1 | tail -15 && cd /Users/julienbattaglia/Desktop/MINT && python3 -c "import re; src=open('apps/mobile/lib/routes/route_metadata.dart').read(); keys=set(re.findall(r\"^  '([^']+)':\s*RouteMeta\", src, re.MULTILINE)); assert len(keys)==147, f'expected 147, got {len(keys)}'; print('OK 147 entries')"</automated>
  </verify>
  <acceptance_criteria>
    - `apps/mobile/lib/routes/route_metadata.dart` contains exactly 147 `: RouteMeta(` occurrences at map key position (verified by regex count)
    - `kRouteRegistry.keys.toSet()` is bijective with the extracted path set from Wave 0 RECONCILE-REPORT
    - `flutter test test/routes/route_metadata_test.dart` exits 0 with ≥9 tests passing (all except JSON stability which waits for Plan 02)
    - `flutter analyze apps/mobile/lib/routes/` reports 0 errors
    - All 15 `RouteOwner` values are used in at least one entry
    - `/explore/retraite` owner is `RouteOwner.explore` (not retraite)
    - Every entry is declared `const` (verified: `grep -c "    RouteMeta(" apps/mobile/lib/routes/route_metadata.dart` matches entry count)
  </acceptance_criteria>
  <done>Registry populated, 147 entries, all tests green. `app.dart` routes now have a machine-readable twin.</done>
</task>

</tasks>

<verification>
End-of-plan gate (must be green before Wave 2 starts):
- `flutter test test/routes/route_metadata_test.dart` — all schema + enum + registry tests green (JSON stability may still skip).
- `flutter analyze apps/mobile/lib/routes/` — 0 errors, 0 warnings.
- 147-entry count verified mechanically via regex count script.
- Every downstream consumer (Plan 02 CLI, Plan 03 UI, Plan 04 parity lint) can now `import 'package:mint_mobile/routes/route_metadata.dart'` and use `kRouteRegistry`.

Single commit: `feat(32): Wave 1 kRouteRegistry 147 entries + RouteMeta/Category/Owner schema`.
</verification>

<success_criteria>
- Registry exists with exactly 147 entries, 1:1 with `app.dart` paths (Wave 4 parity lint enforces no drift)
- D-01 owner ambiguity rule implemented and tested (first-segment wins, with explicit test for `/explore/retraite`)
- All 15 RouteOwner enum values exercised (no dead enum values)
- All Phase 33 FLAG-05 kill-flag names appear as killFlag values where applicable (Phase 33 can consume immediately)
- Tree-shake contract preparation complete (no runtime reference to `kRouteRegistry` from non-admin code yet — Plan 03 will guard the only consumer)
</success_criteria>

<output>
After completion, create `.planning/phases/32-cartographier/32-01-SUMMARY.md` with:
- 147-entry confirmation
- Owner distribution counts (per-owner entry counts)
- Kill-flag assignments (owner -> flag mapping)
- Commit SHA
- Wave 2 unblock: CLI can import schema via package path
</output>
