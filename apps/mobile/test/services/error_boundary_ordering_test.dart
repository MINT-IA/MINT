// Phase 31 OBS-02 (a) — ordering invariant (Wave 0 scaffold).
//
// Invariant (Wave 1 Plan 31-01): installGlobalErrorBoundary() MUST set
// PlatformDispatcher.instance.onError BEFORE FlutterError.onError.
// Rationale: PlatformDispatcher catches async/uncaught errors that the
// Flutter framework hasn't boxed yet. Setting Flutter's handler first
// creates a window where native-thread errors land in the default
// zone + get printed to stderr without reaching Sentry.
//
// Reference: Sentry Flutter 9.x docs §configuration/options "Error
// capture". The 3-prongs error boundary (PlatformDispatcher +
// FlutterError + Isolate) rejects `runZonedGuarded` per D-A3.
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('error_boundary ordering (Wave 1 Plan 31-01)', () {
    test(
      'PlatformDispatcher.onError set BEFORE FlutterError.onError',
      () {},
      skip: 'Wave 1 impl pending — Plan 31-01 creates error_boundary.dart',
    );
  });
}
