// Phase 32 MAP-01 — RouteMeta schema + enum integrity + kRouteRegistry.
//
// Baseline contract (from .planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md):
// - kRouteRegistry.length == 147
// - RouteOwner enum has 15 values (11 flag-groups + auth/admin/system/explore)
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
    test('has exactly 15 values', () {
      expect(RouteOwner.values.length, 15);
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
    test(
      'has exactly 147 entries',
      () {},
      skip: 'Plan 32-01 Task 2 populates kRouteRegistry',
    );

    test(
      'all 15 RouteOwner enum values are used at least once',
      () {},
      skip: 'Plan 32-01 Task 2 populates kRouteRegistry',
    );

    test(
      'every RouteCategory enum value has entries',
      () {},
      skip: 'Plan 32-01 Task 2 populates kRouteRegistry',
    );

    test(
      'owner ambiguity rule: /explore/retraite owner=explore (D-01 v4 first-segment)',
      () {},
      skip: 'Plan 32-01 Task 2 populates kRouteRegistry',
    );
  });
}
