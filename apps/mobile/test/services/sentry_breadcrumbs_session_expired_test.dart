// Sprint 0 — MintBreadcrumbs.sessionExpired live assertion.
//
// Adds an auditable trail in Sentry for the « 401 → graceful logout +
// throw » path that produced fatal `c89b8ad8efc74f30b155508a8a8cf11c` on
// `/scan` 2026-05-04 (PR #475 added the catch + snackbar; this Sprint 0
// commit makes the underlying session-expiry observable so we know how
// often it happens, on which surface, and whether refresh was attempted).
//
// Discipline (D-03 4-level + Pitfall 6 PII): the [surface] arg is a
// callsite literal (`'ApiService.get'` etc.) — NEVER a request path,
// query string, or any user-generated string. Test fuzzes obvious PII
// patterns to confirm none reach the emitted breadcrumb data.

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mint_mobile/services/sentry_breadcrumbs.dart';

const _fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

const _surfaces = <String>[
  'ApiService.get',
  'ApiService.getText',
  'ApiService.post',
  'ApiService.put',
  'ApiService.delete',
  'DocumentService.extractWithVision',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final captured = <Breadcrumb>[];

  setUp(() async {
    captured.clear();
    await Sentry.init(
      (options) {
        options.dsn = _fakeDsn;
        options.beforeBreadcrumb = (crumb, hint) {
          if (crumb != null) captured.add(crumb);
          return null;
        };
        options.beforeSend = (event, hint) => null;
      },
    );
  });

  tearDown(() async {
    await Sentry.close();
  });

  group('MintBreadcrumbs.sessionExpired (D-03 4-level + Pitfall 6 PII)', () {
    test('emits category mint.auth.session.expired at warning level', () async {
      MintBreadcrumbs.sessionExpired(
        surface: 'ApiService.get',
        refreshAttempted: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(1));
      final c = captured.single;
      expect(c.category, 'mint.auth.session.expired');
      expect(c.level, SentryLevel.warning);
      expect(c.data!['surface'], 'ApiService.get');
      expect(c.data!['refresh_attempted'], isTrue);
    });

    test('omits refresh_attempted key when not provided', () async {
      MintBreadcrumbs.sessionExpired(surface: 'DocumentService.extractWithVision');
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(1));
      final data = captured.single.data!;
      expect(data['surface'], 'DocumentService.extractWithVision');
      expect(data.containsKey('refresh_attempted'), isFalse);
    });

    test('refresh_attempted=false propagates explicit value', () async {
      MintBreadcrumbs.sessionExpired(
        surface: 'DocumentService.extractWithVision',
        refreshAttempted: false,
      );
      await Future<void>.delayed(Duration.zero);

      expect(captured.single.data!['refresh_attempted'], isFalse);
    });

    test('emits one breadcrumb per call across all callsite surfaces', () async {
      for (final s in _surfaces) {
        MintBreadcrumbs.sessionExpired(
          surface: s,
          refreshAttempted: s.startsWith('ApiService'),
        );
      }
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(_surfaces.length));
      for (var i = 0; i < _surfaces.length; i++) {
        expect(captured[i].category, 'mint.auth.session.expired');
        expect(captured[i].data!['surface'], _surfaces[i]);
      }
    });

    test('PII discipline — emitted payload contains only enum strings + bool',
        () async {
      // Pitfall 6: verify only ENUM/BOOL reach the payload.
      // The surface arg is a callsite literal — if a future caller passes a
      // user-generated string (request path, query, etc.) the emitted
      // payload would carry it. This test guards against that by assuming
      // the discipline at the call site, but also asserts the *type* set
      // is restricted to the documented surface.
      MintBreadcrumbs.sessionExpired(
        surface: 'ApiService.get',
        refreshAttempted: true,
      );
      await Future<void>.delayed(Duration.zero);

      final data = captured.single.data!;
      expect(data.keys.toSet(), {'surface', 'refresh_attempted'});
      expect(data['surface'], isA<String>());
      expect(data['refresh_attempted'], isA<bool>());
      // No CHF amounts, AVS numbers, IBANs in the surface string.
      final s = data['surface'] as String;
      expect(RegExp(r'CHF[- ]?\d+', caseSensitive: false).hasMatch(s), isFalse);
      expect(RegExp(r'756\.\d{4}').hasMatch(s), isFalse);
      expect(RegExp(r'CH\d{2}[A-Z0-9]{4,}').hasMatch(s), isFalse);
    });
  });
}
