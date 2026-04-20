// Phase 32 MAP-03 — JSON contract stability tests.
//
// Wave 2 (Plan 32-02) publishes `lib/routes/route_health_schema.dart` with
// `kRouteHealthSchemaVersion = 1`. This file pins the version to 1 so any
// unintentional bump breaks the build before it ships.
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/routes/route_health_schema.dart';

void main() {
  group('RouteHealthJsonContract (MAP-03)', () {
    test('kRouteHealthSchemaVersion == 1 (Phase 32 stable contract)', () {
      expect(kRouteHealthSchemaVersion, 1);
    });

    test('schema file declares RouteHealthJsonContract class', () {
      // Compile-time proof only — if this test compiles, the class exists.
      const contract = RouteHealthJsonContract;
      expect(contract, isA<Type>());
    });
  });
}
