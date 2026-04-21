// Phase 31 OBS-04 (a) — trace_id propagation in _authHeaders live test.
//
// Wave 1 Plan 31-01: flipped from skipped stub to live assertion.
//
// D-05 LOCKED (CONTEXT.md §Implementation Decisions): the primary
// propagation header is `sentry-trace` (Sentry OTLP-compatible) plus
// `baggage` (W3C standard). Legacy `X-MINT-Trace-Id` continues via
// backend LoggingMiddleware — dual-header zero-regression approach.
// No Dio migration (D-A4 rejected — http ^1.2.0 stays, manual header
// injection only).
//
// Expected behaviour (tested here):
//   - _authHeaders() always returns `sentry-trace` with 32+16 hex format
//   - _publicHeaders() has the SAME propagation (covers the 11 bypass
//     sites migrated in this plan — auth/login, auth/register, etc.).
//   - existing `Content-Type` + `X-App-Version` headers preserved.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

// sentry-trace format: <32-hex traceId>-<16-hex spanId>[-sampled]
final _sentryTracePattern =
    RegExp(r'^[0-9a-f]{32}-[0-9a-f]{16}(-[01])?$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // In-memory mock for flutter_secure_storage platform channel — required
  // because _authHeaders() calls AuthService.getToken() which reads from
  // SecureStorage. Pattern mirrored from test/auth/auth_service_test.dart.
  final Map<String, String> mockStorage = {};

  setUp(() async {
    mockStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            if (value != null) mockStorage[key] = value;
            return null;
          case 'read':
            final key = call.arguments['key'] as String;
            return mockStorage[key];
          case 'delete':
            final key = call.arguments['key'] as String;
            mockStorage.remove(key);
            return null;
          case 'deleteAll':
            mockStorage.clear();
            return null;
          default:
            return null;
        }
      },
    );
    await Sentry.init((options) {
      options.dsn = _fakeDsn;
      options.tracesSampleRate = 1.0; // ensure span is created
      options.beforeSend = (event, hint) => null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
    await Sentry.close();
  });

  group('ApiService._authHeaders sentry-trace (OBS-04 a)', () {
    test(
      '_authHeaders returns sentry-trace matching 32-hex + 16-hex '
      'format AND preserves existing headers',
      () async {
        final tx = Sentry.startTransaction('test.op', 'http.client');
        try {
          final headers = await ApiService.debugAuthHeaders();

          expect(headers['Content-Type'], 'application/json');
          expect(headers['X-App-Version'], isNotNull);
          expect(headers.containsKey('sentry-trace'), isTrue);
          expect(
            _sentryTracePattern.hasMatch(headers['sentry-trace']!),
            isTrue,
            reason:
                'sentry-trace header does not match 32+16 hex format: '
                '${headers['sentry-trace']}',
          );
        } finally {
          await tx.finish();
        }
      },
    );

    test(
      '_publicHeaders (unauthenticated path) also injects sentry-trace — '
      'OBS-04 coverage gap closure across 11 migrated bypass sites',
      () {
        final tx = Sentry.startTransaction('test.op', 'http.client');
        try {
          final headers = ApiService.debugPublicHeaders();

          expect(headers['Content-Type'], 'application/json');
          expect(headers['X-App-Version'], isNotNull);
          // Crucially: NO Authorization header (unauth path by design).
          expect(headers.containsKey('Authorization'), isFalse);
          expect(headers.containsKey('sentry-trace'), isTrue);
          expect(
            _sentryTracePattern.hasMatch(headers['sentry-trace']!),
            isTrue,
          );
        } finally {
          tx.finish();
        }
      },
    );
  });
}
