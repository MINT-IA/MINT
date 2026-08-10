import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/analytics_observer.dart';
import 'package:mint_mobile/services/observability/private_route_telemetry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Route<void> _route(String name) => MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => const SizedBox.shrink(),
    );

void main() {
  tearDown(() => MintPrivateFinancialTelemetryScope.setActive(false));

  test('classification is exact and query-safe', () {
    expect(isMintNext3aPrivateRouteName('/mint-next/3a'), isTrue);
    expect(isMintNext3aPrivateRouteName('/mint-next/3a?year=2026'), isTrue);
    expect(isMintNext3aPrivateRouteName('/mint-next/3a/detail'), isFalse);
    expect(isMintNext3aPrivateRouteName('/home'), isFalse);
  });

  test('analytics drops private route names but keeps safe routes', () {
    final seen = <String>[];
    final observer = AnalyticsRouteObserver(trackScreenView: seen.add);

    observer.didPush(_route('/home'), null);
    observer.didPush(_route('/mint-next/3a'), _route('/home'));
    observer.didReplace(
      newRoute: _route('/mint-next/3a?year=2026'),
      oldRoute: _route('/home'),
    );
    observer.didPop(_route('/mint-next/3a'), _route('/home'));

    expect(seen, everyElement(isNot(contains('mint-next'))));
    expect(seen, contains('/home'));
  });

  test('Sentry hub never receives the private route across callbacks',
      () async {
    final options = SentryOptions(
      dsn: 'https://public@example.com/1',
    );
    final hub = Hub(options);
    final observer = MintPrivateRouteSentryObserver(hub: hub);
    final home = _route('/home');
    final private = _route('/mint-next/3a?year=2026');
    final safe = _route('/settings');

    observer.didPush(home, null);
    observer.didPush(private, home);
    expect(MintPrivateFinancialTelemetryScope.isActive, isTrue);
    observer.didPop(private, home);
    expect(MintPrivateFinancialTelemetryScope.isActive, isFalse);
    observer.didReplace(newRoute: safe, oldRoute: private);
    observer.didRemove(private, safe);
    observer.didChangeTop(private, safe);
    expect(MintPrivateFinancialTelemetryScope.isActive, isTrue);
    observer.didStartUserGesture(private, safe);
    await Future<void>.delayed(Duration.zero);

    var serialized = '';
    await hub.configureScope((scope) {
      serialized = scope.breadcrumbs.map((item) => item.toJson()).join();
    });
    expect(serialized, contains('/home'));
    expect(serialized, contains('/settings'));
    expect(serialized, isNot(contains('/mint-next/3a')));
  });

  test('private scope follows replacement onto and away from the surface', () {
    final observer = MintPrivateRouteSentryObserver(
      hub: Hub(SentryOptions(dsn: 'https://public@example.com/1')),
    );
    final home = _route('/home');
    final private = _route('/mint-next/3a');

    observer.didReplace(newRoute: private, oldRoute: home);
    expect(MintPrivateFinancialTelemetryScope.isActive, isTrue);
    observer.didReplace(newRoute: home, oldRoute: private);
    expect(MintPrivateFinancialTelemetryScope.isActive, isFalse);
  });
}
