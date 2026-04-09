/// Declarative scope for every route in the MINT router.
///
/// Used by [ScopedGoRoute] to encode auth requirements at definition time
/// rather than relying on a runtime prefix whitelist.
///
/// Default is [authenticated] (fail-closed): any route that forgets to set
/// a scope is treated as requiring authentication.
enum RouteScope {
  /// Publicly accessible without any auth (landing, legal pages, auth flows).
  public,

  /// Onboarding flow — accessible only when onboarding is incomplete.
  onboarding,

  /// Requires auth (signed-in or local anonymous). This is the default.
  authenticated,
}
