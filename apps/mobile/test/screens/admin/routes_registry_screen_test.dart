// Phase 32 Plan 03 Wave 3 — live MAP-02b render test.
//
// Baseline (from RECONCILE-REPORT.md + kRouteRegistry):
// - 147 routes in kRouteRegistry
// - 15 RouteOwner buckets (11 flag-groups + anonymous/auth/admin/system/explore)
// - Flutter UI is a PURE SCHEMA VIEWER per CONTEXT v4 D-06.
// - Footer note points to CLI for live health per D-06.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/routes/route_owner.dart';
import 'package:mint_mobile/screens/admin/routes_registry_screen.dart';

void main() {
  group('RoutesRegistryScreen (MAP-02b)', () {
    testWidgets('renders 15 ExpansionTiles (one per RouteOwner)', (tester) async {
      // Tall viewport so ListView.builder materialises every owner tile
      // (default 600pt height shows only ~10 tiles in the lazy list).
      tester.view.physicalSize = const Size(800, 20000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: RoutesRegistryScreen()),
      ));
      await tester.pumpAndSettle();

      final tiles = find.byType(ExpansionTile);
      expect(tiles, findsNWidgets(RouteOwner.values.length));
      expect(RouteOwner.values.length, 15);
    });

    testWidgets('sum of route rows across all buckets == 150', (tester) async {
      // Force a large viewport so every ExpansionTile is laid out simultaneously
      // (default test surface is 800x600 which clips tiles below fold, preventing
      // taps from reaching them reliably after each expansion relayout).
      tester.view.physicalSize = const Size(800, 20000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: RoutesRegistryScreen()),
      ));
      await tester.pumpAndSettle();

      // Expand all tiles by tapping their text. Tap sequentially and settle
      // between each tap — tree changes after each expansion, so we iterate
      // by owner name (stable) rather than by Element (mutating).
      for (final owner in RouteOwner.values) {
        final titleFinder = find.textContaining('${owner.name} (');
        if (titleFinder.evaluate().isNotEmpty) {
          await tester.tap(titleFinder.first, warnIfMissed: false);
          await tester.pumpAndSettle();
        }
      }

      // ListTile is rendered per route row. ExpansionTile uses ListTile
      // internally for its own header, so filter by `dense: true` — our
      // route rows set dense explicitly, ExpansionTile headers do not.
      final rows = find.byWidgetPredicate(
        (w) => w is ListTile && w.dense == true,
        description: 'dense ListTile (route row)',
      );
      expect(
        rows,
        findsNWidgets(150),
        reason: 'registry has 150 entries; UI must render all',
      );
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
