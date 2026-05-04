// Phase 32 Plan 03 Wave 3 — D-09 §4 behavioural breadcrumb test.
//
// Supersedes Wave 0 source-string stub. Captures real Breadcrumb objects
// via Sentry `beforeBreadcrumb` hook (M-2 fix).
//
// Contract (nLPD Art. 12 processing record, D-09 §4):
//   - category = 'mint.admin.routes.viewed'
//   - data keys = {route_count, feature_flags_enabled_count,
//                  snapshot_age_minutes?} — aggregates only, no PII
//
// Also verifies the paired MAP-05 helper MintBreadcrumbs.legacyRedirectHit
// emits the expected {from, to} shape with category
// 'mint.routing.legacy_redirect.hit'.
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mint_mobile/services/sentry_breadcrumbs.dart';

const _fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final captured = <Breadcrumb>[];

  setUp(() async {
    captured.clear();
    await Sentry.init((options) {
      options.dsn = _fakeDsn;
      options.beforeBreadcrumb = (crumb, hint) {
        if (crumb != null) captured.add(crumb);
        return null; // drop — we just capture for assertions
      };
      // Belt+suspenders: never transport events in tests.
      options.beforeSend = (event, hint) => null;
    });
  });

  tearDown(() async {
    await Sentry.close();
  });

  group('MintBreadcrumbs.adminRoutesViewed (D-09 §4) — behavioural', () {
    test('emits exactly 1 breadcrumb with category mint.admin.routes.viewed', () async {
      MintBreadcrumbs.adminRoutesViewed(
        routeCount: 147,
        featureFlagsEnabledCount: 2,
        snapshotAgeMinutes: null,
      );
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(1));
      expect(captured.single.category, 'mint.admin.routes.viewed');
      expect(captured.single.level, SentryLevel.info);
    });

    test('data keys are EXACTLY {route_count, feature_flags_enabled_count} when snapshotAgeMinutes is null', () async {
      MintBreadcrumbs.adminRoutesViewed(
        routeCount: 147,
        featureFlagsEnabledCount: 2,
        snapshotAgeMinutes: null,
      );
      await Future<void>.delayed(Duration.zero);

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

    test('data keys include snapshot_age_minutes only when provided', () async {
      MintBreadcrumbs.adminRoutesViewed(
        routeCount: 147,
        featureFlagsEnabledCount: 2,
        snapshotAgeMinutes: 42,
      );
      await Future<void>.delayed(Duration.zero);

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

    test('no data value is a String (structural anti-PII)', () async {
      MintBreadcrumbs.adminRoutesViewed(
        routeCount: 147,
        featureFlagsEnabledCount: 2,
        snapshotAgeMinutes: 42,
      );
      await Future<void>.delayed(Duration.zero);

      final data = captured.single.data ?? <String, dynamic>{};
      for (final v in data.values) {
        expect(v, isNot(isA<String>()),
            reason: 'aggregates are int only — String values forbid PII leakage');
      }
    });
  });

  group('MintBreadcrumbs.legacyRedirectHit (MAP-05) — behavioural', () {
    test('emits 1 breadcrumb with category mint.routing.legacy_redirect.hit', () async {
      MintBreadcrumbs.legacyRedirectHit(from: '/report', to: '/rapport');
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(1));
      expect(captured.single.category, 'mint.routing.legacy_redirect.hit');
      expect(captured.single.level, SentryLevel.info);
    });

    test('data keys are EXACTLY {from, to}', () async {
      MintBreadcrumbs.legacyRedirectHit(from: '/report', to: '/rapport');
      await Future<void>.delayed(Duration.zero);

      final data = captured.single.data ?? <String, dynamic>{};
      expect(data.keys.toSet(), equals(<String>{'from', 'to'}));
      expect(data['from'], '/report');
      expect(data['to'], '/rapport');
    });
  });
}
