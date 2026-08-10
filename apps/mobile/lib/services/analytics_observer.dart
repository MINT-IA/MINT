import 'package:flutter/material.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/observability/private_route_telemetry.dart';

/// NavigatorObserver that automatically tracks screen views
///
/// Usage:
/// Add to GoRouter observers:
/// ```dart
/// final _router = GoRouter(
///   observers: [AnalyticsRouteObserver()],
///   ...
/// );
/// ```
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver({void Function(String)? trackScreenView})
      : _track = trackScreenView ?? AnalyticsService().trackScreenView;

  final void Function(String) _track;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackScreenView(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _trackScreenView(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _trackScreenView(newRoute);
    }
  }

  void _trackScreenView(Route<dynamic> route) {
    // Get route name from settings
    final routeName = route.settings.name;
    if (routeName != null &&
        routeName.isNotEmpty &&
        !isMintNext3aPrivateRouteName(routeName)) {
      _track(routeName);
    }
  }
}
