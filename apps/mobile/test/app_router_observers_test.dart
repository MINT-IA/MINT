// Phase 31 OBS-05 (a) — SentryNavigatorObserver in GoRouter observers live test.
//
// Wave 1 Plan 31-01: flipped from skipped stub to live assertion.
// Phase 32 J0 Task 2 hotfix (2026-04-20): added source assertion that
// `setRouteNameAsTransaction: true` is passed to the observer. Without
// this flag, Sentry issues report transaction = <file:function> instead
// of the route path, breaking D-07 contract and Phase 32 CLI
// `./tools/mint-routes health` queries. See .planning/phases/
// 32-cartographier/32-VALIDATION.md §Risks Risk 1.
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
import 'dart:io';

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

    test(
      'SentryNavigatorObserver configured with setRouteNameAsTransaction: true '
      '(Phase 32 J0 Task 2 hotfix — D-07 contract)',
      () {
        // The SDK flag is private (sentry_flutter 9.14.0
        // sentry_navigator_observer.dart:82/120). Asserting via source
        // grep — cheap regression guard. Empirical verification happens
        // on staging TestFlight by querying Sentry Issues API with
        // `transaction:<expected-route-path>` (D-11 §J0 Task 2).
        final source = File('lib/app.dart').readAsStringSync();
        expect(
          source.contains('SentryNavigatorObserver(setRouteNameAsTransaction: true)'),
          isTrue,
          reason: 'SentryNavigatorObserver MUST pass '
              'setRouteNameAsTransaction: true to bind scope.transaction '
              'to the current GoRouter path. Without this flag, Sentry '
              'issues report transaction = <file:function> instead of '
              'the route path, breaking `./tools/mint-routes health` '
              'queries (Phase 32 CLI D-07 contract).',
        );
      },
    );
  });
}
