import 'package:go_router/go_router.dart';
import 'route_scope.dart';

/// A [GoRoute] that carries a declarative [RouteScope].
///
/// Every route in the MINT router uses [ScopedGoRoute] instead of bare
/// [GoRoute]. The [scope] field defaults to [RouteScope.authenticated]
/// (fail-closed), so any route that forgets to declare a scope will require
/// auth by default.
///
/// The router's top-level `redirect` callback reads this field from the
/// matched route to decide whether to gate, redirect, or allow the
/// navigation.
class ScopedGoRoute extends GoRoute {
  /// The auth scope for this route.
  final RouteScope scope;

  ScopedGoRoute({
    required super.path,
    this.scope = RouteScope.authenticated,
    super.name,
    super.builder,
    super.pageBuilder,
    super.parentNavigatorKey,
    super.redirect,
    super.routes = const <RouteBase>[],
    super.onExit,
  });
}
