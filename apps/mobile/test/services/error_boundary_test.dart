// Phase 31 OBS-02 (a,b) — global error boundary scaffolding (Wave 0).
//
// Wave 1 Plan 31-01 implements:
//   apps/mobile/lib/services/error_boundary.dart
//     void installGlobalErrorBoundary();
//     Future<void> captureSwallowedException(
//       Object error, StackTrace stack, {String? surface});
//
// These tests are intentionally skipped until Plan 31-01 ships the file;
// they declare the contract so the Wave 1 implementer flips `skip:` to
// run them green. NO import of error_boundary.dart here — it does not
// exist yet and an import would fail `flutter analyze`.
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('error_boundary (Wave 1 Plan 31-01)', () {
    test(
      'installGlobalErrorBoundary wires PlatformDispatcher.onError',
      () {},
      skip: 'Wave 1 impl pending — Plan 31-01 creates error_boundary.dart',
    );

    test(
      'FlutterError.onError captured by boundary and routed to Sentry',
      () {},
      skip: 'Wave 1 impl pending — Plan 31-01 creates error_boundary.dart',
    );
  });
}
