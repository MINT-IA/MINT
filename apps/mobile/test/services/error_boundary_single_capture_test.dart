// Phase 31 OBS-02 (b) — single-capture invariant live test.
//
// Wave 1 Plan 31-01: flipped from skipped stub to live assertion.
//
// Invariant: for a given thrown error identity, Sentry.captureException
// is called EXACTLY ONCE — not zero (silent drop) and not twice
// (double log if multiple prongs catch the same exception).
//
// Verified via a Sentry `beforeSend` callback that counts how many
// SentryEvent objects are about to be dispatched. The boundary's private
// reentrancy guard (keyed on identityHashCode) MUST dedupe within the
// same microtask so the count is exactly 1.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mint_mobile/services/error_boundary.dart';

const _fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dispatched = <SentryEvent>[];

  setUp(() async {
    dispatched.clear();
    await Sentry.init((options) {
      options.dsn = _fakeDsn;
      options.beforeSend = (event, hint) {
        dispatched.add(event);
        return null; // drop — no network
      };
    });
  });

  tearDown(() async {
    await Sentry.close();
  });

  group('error_boundary single capture (Wave 1 Plan 31-01)', () {
    test(
      'Sentry.captureException called exactly once per FlutterError',
      () async {
        // Start fresh.
        PlatformDispatcher.instance.onError = null;
        FlutterError.onError = null;

        installGlobalErrorBoundary();

        final err = StateError('single-capture');
        final stack = StackTrace.current;

        // Invoke FlutterError path.
        FlutterError.onError?.call(FlutterErrorDetails(
          exception: err,
          stack: stack,
          library: 'single_capture_test',
        ));
        // Invoke PlatformDispatcher path with the SAME error identity
        // — reentrancy guard must dedupe it.
        PlatformDispatcher.instance.onError?.call(err, stack);

        // Allow the async capture path to resolve.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          dispatched.length,
          1,
          reason: 'expected exactly 1 Sentry event, got ${dispatched.length}',
        );
      },
    );
  });
}
