import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const mintNext3aPrivateRoute = '/mint-next/3a';

/// Process-local privacy state used only to make auto-captured technical
/// exceptions fail closed while the private financial surface is visible.
/// It contains no route, task, answer, year, or user data.
class MintPrivateFinancialTelemetryScope {
  MintPrivateFinancialTelemetryScope._();

  static bool _active = false;

  static bool get isActive => _active;

  static void setActive(bool active) => _active = active;
}

bool isMintNext3aPrivateRouteName(String? name) {
  if (name == null || name.isEmpty) return false;
  return Uri.tryParse(name)?.path == mintNext3aPrivateRoute;
}

/// Drops the private 3a route before either analytics or Sentry receives it.
/// Safe neighbours may still become the current Sentry transaction, but the
/// private route name is never passed to the SDK as route or previousRoute.
class MintPrivateRouteSentryObserver extends SentryNavigatorObserver {
  MintPrivateRouteSentryObserver({super.hub})
      : super(
          setRouteNameAsTransaction: true,
          enableAutoTransactions: hub == null,
        );

  bool _private(Route<dynamic>? route) =>
      isMintNext3aPrivateRouteName(route?.settings.name);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_private(route)) {
      MintPrivateFinancialTelemetryScope.setActive(true);
      return;
    }
    if (route.settings.name?.isNotEmpty ?? false) {
      MintPrivateFinancialTelemetryScope.setActive(false);
    }
    super.didPush(route, _private(previousRoute) ? null : previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_private(route)) {
      MintPrivateFinancialTelemetryScope.setActive(_private(previousRoute));
      return;
    }
    super.didPop(route, _private(previousRoute) ? null : previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_private(newRoute)) {
      MintPrivateFinancialTelemetryScope.setActive(true);
      return;
    }
    if (newRoute?.settings.name?.isNotEmpty ?? false) {
      MintPrivateFinancialTelemetryScope.setActive(false);
    }
    super.didReplace(
      newRoute: newRoute,
      oldRoute: _private(oldRoute) ? null : oldRoute,
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_private(route)) {
      MintPrivateFinancialTelemetryScope.setActive(_private(previousRoute));
      return;
    }
    super.didRemove(route, _private(previousRoute) ? null : previousRoute);
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (_private(topRoute)) {
      MintPrivateFinancialTelemetryScope.setActive(true);
      return;
    }
    if (topRoute.settings.name?.isNotEmpty ?? false) {
      MintPrivateFinancialTelemetryScope.setActive(false);
    }
    super.didChangeTop(
      topRoute,
      _private(previousTopRoute) ? null : previousTopRoute,
    );
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    if (_private(route)) return;
    super.didStartUserGesture(
      route,
      _private(previousRoute) ? null : previousRoute,
    );
  }
}
