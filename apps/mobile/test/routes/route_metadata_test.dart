// Phase 32 MAP-01 — RouteMeta schema + enum integrity + kRouteRegistry.
//
// Baseline contract (from .planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md):
// - kRouteRegistry.length == 153 (was 147 in Phase 32 ; 6 routes added since,
//   count refreshed 2026-05-30 in SALVAGE-00 #682 — registered the existing
//   debt_ratio_screen route '/debt/ratio'; 2026-06-30 canonicalized
//   '/retraite/rente-vs-capital')
// - RouteOwner enum has 16 values (11 flag-groups + legacyOnboarding
//   + auth/admin/system/explore) — legacyOnboarding ajouté en bascule 4 :
//   autorité structurelle de l'interdiction du wizard legacy en préversion
// - RouteCategory enum has 4 values (destination, flow, tool, alias)
// - Owner ambiguity rule (D-01 v4): /explore/retraite -> owner=explore (first-segment-wins)
//
// Task 1 (Plan 32-01) flips the schema + enum tests green. Task 2 flips the
// registry content tests green once `kRouteRegistry` is populated.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/routes/route_category.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
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

      expect(meta.path, '/x');
      expect(meta.category, RouteCategory.flow);
      expect(meta.owner, RouteOwner.coach);
      expect(meta.requiresAuth, isTrue);
      expect(meta.killFlag, 'enableCoachChat');
      expect(meta.description, 'dev note');
      expect(meta.sentryTag, '/coach-override');
    });
  });

  group('RouteCategory enum (D-01)', () {
    test('has exactly 4 values in declared order', () {
      expect(RouteCategory.values, <RouteCategory>[
        RouteCategory.destination,
        RouteCategory.flow,
        RouteCategory.tool,
        RouteCategory.alias,
      ]);
    });
  });

  group('RouteOwner enum (D-01)', () {
    test('has exactly 16 values', () {
      expect(RouteOwner.values.length, 16);
    });

    test('includes 11 flag-group owners (Phase 33 FLAG-05)', () {
      const flagGroups = <RouteOwner>{
        RouteOwner.retraite,
        RouteOwner.famille,
        RouteOwner.travail,
        RouteOwner.logement,
        RouteOwner.fiscalite,
        RouteOwner.patrimoine,
        RouteOwner.sante,
        RouteOwner.coach,
        RouteOwner.scan,
        RouteOwner.budget,
        RouteOwner.anonymous,
      };
      expect(flagGroups.length, 11);
      expect(RouteOwner.values.toSet().containsAll(flagGroups), isTrue);
    });

    test('includes 4 infra owners', () {
      const infra = <RouteOwner>{
        RouteOwner.auth,
        RouteOwner.admin,
        RouteOwner.system,
        RouteOwner.explore,
      };
      expect(infra.length, 4);
      expect(RouteOwner.values.toSet().containsAll(infra), isTrue);
    });
  });

  group('kRouteRegistry (MAP-01)', () {
    test('has exactly 161 entries', () {
      // 147 in Phase 32 ; 14 routes added since. Refresh count when adding /
      // removing routes (intentional gate, not auto-updated).
      expect(kRouteRegistry.length, 161);
    });

    test('/mint-next/3a is the public local private-flow route', () {
      final route = kRouteRegistry['/mint-next/3a'];
      expect(route, isNotNull);
      expect(route!.category, RouteCategory.flow);
      expect(route.owner, RouteOwner.system);
      expect(route.requiresAuth, isFalse);
      expect(route.killFlag, 'enableMintNext3aProductHandoff');
    });

    test('/mint-next/domicile is the canonical domicile fact flow', () {
      final route = kRouteRegistry['/mint-next/domicile'];
      expect(route, isNotNull);
      expect(route!.category, RouteCategory.flow);
      expect(route.owner, RouteOwner.system);
      expect(route.requiresAuth, isFalse);
      expect(route.killFlag, 'enableMintNextDomicile');
    });

    test('/mint-next/etat-civil is the canonical civil-status fact flow', () {
      final route = kRouteRegistry['/mint-next/etat-civil'];
      expect(route, isNotNull);
      expect(route!.category, RouteCategory.flow);
      expect(route.owner, RouteOwner.system);
      expect(route.requiresAuth, isFalse);
      expect(route.killFlag, 'enableMintNextEtatCivil');
    });

    test('/mint-next/revenu is the canonical income fact flow', () {
      final route = kRouteRegistry['/mint-next/revenu'];
      expect(route, isNotNull);
      expect(route!.category, RouteCategory.flow);
      expect(route.owner, RouteOwner.system);
      expect(route.requiresAuth, isFalse);
      expect(route.killFlag, 'enableMintNextRevenu');
    });

    test('/mint-next/lpp-affiliation is the canonical LPP affiliation flow',
        () {
      final route = kRouteRegistry['/mint-next/lpp-affiliation'];
      expect(route, isNotNull);
      expect(route!.category, RouteCategory.flow);
      expect(route.owner, RouteOwner.system);
      expect(route.requiresAuth, isFalse);
      expect(route.killFlag, 'enableMintNextLppAffiliation');
    });

    test('/mint-next/vertical-3a is the attested 3a room surface', () {
      final route = kRouteRegistry['/mint-next/vertical-3a'];
      expect(route, isNotNull);
      expect(route!.category, RouteCategory.flow);
      expect(route.owner, RouteOwner.system);
      expect(route.requiresAuth, isFalse);
      expect(route.killFlag, 'enableMintNextVertical3a');
    });

    test('/mint-next/versements-3a is the canonical 3a payments flow', () {
      final route = kRouteRegistry['/mint-next/versements-3a'];
      expect(route, isNotNull);
      expect(route!.category, RouteCategory.flow);
      expect(route.owner, RouteOwner.system);
      expect(route.requiresAuth, isFalse);
      expect(route.killFlag, 'enableMintNextVersements3a');
    });

    test('/mint-next/housing is a separately killable public flow', () {
      final route = kRouteRegistry['/mint-next/housing'];
      expect(route, isNotNull);
      expect(route!.category, RouteCategory.flow);
      expect(route.owner, RouteOwner.system);
      expect(route.requiresAuth, isFalse);
      expect(route.killFlag, 'enableMintNextHousing');
    });

    test('every entry path matches its key', () {
      for (final entry in kRouteRegistry.entries) {
        expect(
          entry.value.path,
          entry.key,
          reason:
              'Registry key ${entry.key} does not match RouteMeta.path ${entry.value.path}',
        );
      }
    });

    test('all 16 RouteOwner enum values are used at least once', () {
      final used = kRouteRegistry.values.map((m) => m.owner).toSet();
      expect(
        used.length,
        16,
        reason: 'expected all 15 owners used, got ${used.length}: $used',
      );
      expect(used.containsAll(RouteOwner.values.toSet()), isTrue);
    });

    test('every RouteCategory enum value has entries', () {
      final used = kRouteRegistry.values.map((m) => m.category).toSet();
      expect(used.containsAll(RouteCategory.values.toSet()), isTrue,
          reason: 'expected all 4 categories used, got $used');
    });

    test(
        'owner ambiguity rule: /explore/retraite owner=explore (D-01 v4 first-segment)',
        () {
      final meta = kRouteRegistry['/explore/retraite'];
      expect(meta, isNotNull);
      expect(meta!.owner, RouteOwner.explore);
      // Sanity: not accidentally owner=retraite
      expect(meta.owner, isNot(RouteOwner.retraite));
    });

    test('/retraite standalone hub owner=retraite', () {
      final meta = kRouteRegistry['/retraite'];
      expect(meta, isNotNull);
      expect(meta!.owner, RouteOwner.retraite);
    });

    test('/retraite/rente-vs-capital is the canonical public RVC route', () {
      final meta = kRouteRegistry['/retraite/rente-vs-capital'];
      expect(meta, isNotNull);
      expect(meta!.category, RouteCategory.destination);
      expect(meta.owner, RouteOwner.retraite);
      expect(meta.requiresAuth, isFalse);
      expect(meta.killFlag, 'enableExplorerRetraite');
    });

    test('/hypotheque and /pilier-3a are onboarding first-value tools', () {
      final hypotheque = kRouteRegistry['/hypotheque'];
      final pilier3a = kRouteRegistry['/pilier-3a'];

      expect(hypotheque, isNotNull);
      expect(hypotheque!.category, RouteCategory.destination);
      expect(hypotheque.owner, RouteOwner.logement);
      expect(hypotheque.requiresAuth, isFalse);

      expect(pilier3a, isNotNull);
      expect(pilier3a!.category, RouteCategory.destination);
      expect(pilier3a.owner, RouteOwner.fiscalite);
      expect(pilier3a.requiresAuth, isFalse);
    });

    test('/rente-vs-capital is a legacy alias to canonical RVC route', () {
      final meta = kRouteRegistry['/rente-vs-capital'];
      expect(meta, isNotNull);
      expect(meta!.category, RouteCategory.alias);
      expect(meta.owner, RouteOwner.system);
      expect(meta.requiresAuth, isFalse);
      expect(meta.description, contains('/retraite/rente-vs-capital'));
    });

    test('/coach/chat owner=coach (first-segment rule)', () {
      final meta = kRouteRegistry['/coach/chat'];
      expect(meta, isNotNull);
      expect(meta!.owner, RouteOwner.coach);
    });

    test('/anonymous/chat is a retired public alias', () {
      final meta = kRouteRegistry['/anonymous/chat'];
      expect(meta, isNotNull);
      expect(meta!.category, RouteCategory.alias);
      expect(meta.requiresAuth, isFalse);
      expect(
        meta.description,
        contains('redirects to /onb'),
      );
    });

    test('/ root owner=anonymous, requiresAuth=false', () {
      final meta = kRouteRegistry['/'];
      expect(meta, isNotNull);
      expect(meta!.owner, RouteOwner.anonymous);
      expect(meta.requiresAuth, isFalse);
    });

    test('/about is public (requiresAuth=false)', () {
      final meta = kRouteRegistry['/about'];
      expect(meta, isNotNull);
      expect(meta!.requiresAuth, isFalse);
    });

    test('all /auth/* paths are public (requiresAuth=false)', () {
      final authPaths = kRouteRegistry.entries
          .where((e) => e.key.startsWith('/auth/'))
          .toList();
      expect(authPaths, isNotEmpty);
      for (final entry in authPaths) {
        expect(
          entry.value.requiresAuth,
          isFalse,
          reason:
              '${entry.key} should be public (RouteScope.public in app.dart)',
        );
        expect(entry.value.owner, RouteOwner.auth);
      }
    });
  });
}
