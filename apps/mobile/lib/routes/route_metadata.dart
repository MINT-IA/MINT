// ────────────────────────────────────────────────────────────
//  RouteMeta + kRouteRegistry — Phase 32 MAP-01 (D-01 locked v4)
// ────────────────────────────────────────────────────────────
//
// Source of truth for the 147 mobile routes declared in
// `apps/mobile/lib/app.dart`. Consumed by:
//
//   - `tools/mint-routes` CLI (Python, Plan 32-02 Wave 2)
//   - `/admin/routes` Flutter schema viewer (Plan 32-03 Wave 3)
//   - `tools/checks/route_registry_parity.py` (Plan 32-04 Wave 4)
//
// Tree-shake contract (D-11 Task 1, validated in Plan 32-05 Wave 4 J0):
//   When `--dart-define=ENABLE_ADMIN=0` (prod default), the only runtime
//   consumer (`AdminShell`) is compile-time eliminated, detaching
//   `kRouteRegistry`. Empirical gate: `strings Runner | grep -c
//   kRouteRegistry` MUST return 0.
//
// Owner ambiguity rule (D-01 v4): first path segment wins. See
// `route_owner.dart` header for worked examples.

import 'route_category.dart';
import 'route_owner.dart';

/// Declarative metadata for a single GoRoute-matched path.
///
/// One `RouteMeta` per entry in [kRouteRegistry]. All fields are `final`
/// so instances are `const`-constructible (tree-shake precondition).
class RouteMeta {
  /// The GoRoute path string. MUST match the `path:` literal in
  /// `apps/mobile/lib/app.dart`. Nested child routes are stored as
  /// fully-composed paths (e.g. `/profile/bilan` — not just `bilan`).
  final String path;

  /// Taxonomy slot. See [RouteCategory].
  final RouteCategory category;

  /// Ownership bucket. See [RouteOwner] and the first-segment-wins rule.
  final RouteOwner owner;

  /// Whether navigating here requires a logged-in session. Mirrors the
  /// route's `RouteScope` in `app.dart`:
  ///   `RouteScope.public` / `RouteScope.onboarding` -> `false`
  ///   `RouteScope.authenticated` (default)          -> `true`
  ///
  /// Anonymous-local-mode users are handled orthogonally by
  /// `AuthProvider.isLocalMode`; this flag is the declarative baseline.
  final bool requiresAuth;

  /// Optional kill-flag name. When non-null, references a
  /// `FeatureFlags.<name>` field consumed by Phase 33 FLAG-01
  /// `requireFlag()` middleware to gate access at runtime.
  final String? killFlag;

  /// Optional dev-only description. Tree-shake contract (D-11 Task 1)
  /// requires this string to NOT ship to production binaries — never
  /// read from non-admin code paths.
  final String? description;

  /// Optional Sentry `transaction.name` override. When null, CLI
  /// queries (`tools/mint-routes`) use [path] verbatim — the Sentry
  /// Flutter SDK auto-sets `transaction.name` to the route path via
  /// `SentryNavigatorObserver` (Phase 31, `app.dart:184`).
  final String? sentryTag;

  const RouteMeta({
    required this.path,
    required this.category,
    required this.owner,
    required this.requiresAuth,
    this.killFlag,
    this.description,
    this.sentryTag,
  });
}

// `kRouteRegistry` is declared in Plan 32-01 Task 2 to keep the
// schema diff reviewable independently from the 147-entry data diff.
