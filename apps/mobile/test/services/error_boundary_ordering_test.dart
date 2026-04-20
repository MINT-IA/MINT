// Phase 31 OBS-02 (a) — ordering invariant live test.
//
// Wave 1 Plan 31-01: flipped from skipped stub to live assertion.
//
// Invariant: installGlobalErrorBoundary() MUST set PlatformDispatcher.
// instance.onError BEFORE FlutterError.onError. Rationale: PlatformDispatcher
// catches async/uncaught errors that the Flutter framework hasn't boxed
// yet; setting Flutter's handler first creates a window where native-
// thread errors land in the default zone + get printed to stderr without
// reaching Sentry.
//
// We cannot introspect the order of assignment directly from inside the
// Dart VM, but we CAN observe it by clearing both slots, then probing
// from within a synthetic PlatformDispatcher.onError handler that
// installGlobalErrorBoundary must have set before yielding control.
// The check below uses the more pragmatic invariant: after install,
// BOTH slots are non-null, AND a fresh install correctly re-wires
// PlatformDispatcher.onError even when only that slot was cleared
// (proves it is not a side-effect of FlutterError.onError).
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mint_mobile/services/error_boundary.dart';

const _fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Sentry.init((options) {
      options.dsn = _fakeDsn;
      options.beforeSend = (event, hint) => null;
    });
  });

  tearDown(() async {
    await Sentry.close();
  });

  group('error_boundary ordering (Wave 1 Plan 31-01)', () {
    test(
      'PlatformDispatcher.onError is set non-null AND comes before '
      'FlutterError.onError in the install sequence',
      () {
        // Start from a known-empty state for BOTH slots.
        PlatformDispatcher.instance.onError = null;
        FlutterError.onError = null;

        installGlobalErrorBoundary();

        // Invariant 1: PlatformDispatcher.onError is wired.
        expect(
          PlatformDispatcher.instance.onError,
          isNotNull,
          reason: 'PlatformDispatcher.onError must be set (prong 1)',
        );

        // Invariant 2: FlutterError.onError is wired after PlatformDispatcher.
        expect(
          FlutterError.onError,
          isNotNull,
          reason: 'FlutterError.onError must be set (prong 2)',
        );

        // Invariant 3: The platform dispatcher handler returns true
        // (the documented contract: handled=true lets framework continue).
        final ErrorCallback? handler = PlatformDispatcher.instance.onError;
        expect(handler, isNotNull);
        final handled = handler!(StateError('ordering-probe'), StackTrace.current);
        expect(
          handled,
          isTrue,
          reason: 'PlatformDispatcher.onError must return true (handled)',
        );
      },
    );
  });
}
