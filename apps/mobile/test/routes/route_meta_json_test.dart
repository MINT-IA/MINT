// Phase 32 Wave 0 stub — MAP-01 JSON shape stability + schemaVersion:1 contract.
// Implementation: Plan 32-01 Wave 1 + Plan 32-02 Wave 2 (schema publication).
//
// Wave 1 ships the registry; Wave 2 publishes lib/routes/route_health_schema.dart
// defining kRouteHealthSchemaVersion == 1 (byte-stable contract Phase 35 dogfood
// consumes). Bump schemaVersion only on breaking shape change.
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteHealthJsonContract (MAP-03)', () {
    test('kRouteHealthSchemaVersion == 1 (byte-stable across builds)', () {
      // Will import kRouteHealthSchemaVersion from
      // apps/mobile/lib/routes/route_health_schema.dart and assert == 1.
    }, skip: 'Plan 32-02 Wave 2 publishes route_health_schema.dart');

    test('emitted JSON matches documented contract example', () {
      // Will compare RouteMeta.toJson() output byte-exact against a golden
      // fixture (tests/tools/fixtures/route_meta_golden.json at Wave 2).
    }, skip: 'Plan 32-02 Wave 2');
  });
}
