// Phase 31 OBS-02 (b) — single-capture invariant (Wave 0 scaffold).
//
// Invariant (Wave 1 Plan 31-01): for a given thrown error, Sentry.captureException
// is called EXACTLY ONCE — not zero (silent drop) and not twice (double log
// if both PlatformDispatcher and FlutterError catch the same exception).
//
// The Wave 1 implementation must dedupe via a reentrancy guard or by
// choosing a single capture path (current leading design: all prongs
// forward to a single private _capture() helper that invokes
// Sentry.captureException).
//
// Paired with the static ban in tools/checks/sentry_capture_single_source.py
// which forbids Sentry.captureException outside error_boundary.dart —
// together they enforce "one boundary, one capture per error".
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('error_boundary single capture (Wave 1 Plan 31-01)', () {
    test(
      'Sentry.captureException called exactly once per FlutterError',
      () {},
      skip: 'Wave 1 impl pending — Plan 31-01 creates error_boundary.dart',
    );
  });
}
