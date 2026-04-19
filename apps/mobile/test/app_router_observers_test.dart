// Phase 31 OBS-05 (a) — SentryNavigatorObserver in GoRouter observers (Wave 0).
//
// Wave 1 Plan 31-01 patches:
//   apps/mobile/lib/app.dart:173 (observers: [AnalyticsRouteObserver(), ...])
// to ADD SentryNavigatorObserver() to the existing observers list. The
// AnalyticsRouteObserver must stay — SentryNavigatorObserver sits BESIDE
// it, not instead of it (CONTEXT.md §Integration Points).
//
// SentryNavigatorObserver automatically emits `navigation` breadcrumbs
// per GoRouter push/pop, giving Sentry events a replay-independent
// trail of the routes the user walked before the crash. This is
// crucial when sessionSampleRate is 0.0 in prod (D-01 Option C).
//
// Test contract (Wave 1):
//   - Build the root GoRouter (exported from app.dart or test-accessible
//     helper).
//   - Assert observers list contains BOTH an AnalyticsRouteObserver
//     instance AND a SentryNavigatorObserver instance.
//   - Assert both are non-null and distinct objects.
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoRouter observers (Wave 1 Plan 31-01)', () {
    test(
      'SentryNavigatorObserver listed in observers: of root GoRouter '
      'beside existing AnalyticsRouteObserver (OBS-05 a)',
      () {},
      skip: 'Wave 1 impl pending — Plan 31-01 patches app.dart observers',
    );
  });
}
