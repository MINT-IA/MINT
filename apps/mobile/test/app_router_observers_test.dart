// Phase 31 OBS-05 (a) — SentryNavigatorObserver in GoRouter observers live test.
//
// Wave 1 Plan 31-01: flipped from skipped stub to live assertion.
//
// Patches apps/mobile/lib/app.dart observers list to add
// SentryNavigatorObserver alongside the existing AnalyticsRouteObserver.
// AnalyticsRouteObserver MUST stay (analytics pipeline continues to own
// its event stream); SentryNavigatorObserver sits BESIDE it.
//
// SentryNavigatorObserver auto-emits `navigation` breadcrumbs on
// GoRouter push/pop/replace events, giving every Sentry event a
// replay-independent route trail. Crucial when sessionSampleRate is
// 0.0 in prod (D-01 Option C).
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/services/analytics_observer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('GoRouter observers (Wave 1 Plan 31-01)', () {
    test(
      'SentryNavigatorObserver listed beside AnalyticsRouteObserver '
      'in root GoRouter observers: (OBS-05 a)',
      () {
        final observers = testOnlyRootRouterObservers;

        expect(
          observers.length >= 2,
          isTrue,
          reason: 'Expected at least 2 observers, got ${observers.length}',
        );

        final hasAnalytics = observers.any((o) => o is AnalyticsRouteObserver);
        final hasSentry = observers.any((o) => o is SentryNavigatorObserver);

        expect(
          hasAnalytics,
          isTrue,
          reason: 'AnalyticsRouteObserver must remain in observers list',
        );
        expect(
          hasSentry,
          isTrue,
          reason: 'SentryNavigatorObserver must be added beside AnalyticsRouteObserver',
        );

        // Ordering: AnalyticsRouteObserver first so analytics pipeline
        // sees push BEFORE Sentry records its breadcrumb (RESEARCH
        // Pattern 3).
        final analyticsIdx =
            observers.indexWhere((o) => o is AnalyticsRouteObserver);
        final sentryIdx =
            observers.indexWhere((o) => o is SentryNavigatorObserver);
        expect(
          analyticsIdx < sentryIdx,
          isTrue,
          reason: 'AnalyticsRouteObserver must come before SentryNavigatorObserver',
        );
      },
    );
  });
}
