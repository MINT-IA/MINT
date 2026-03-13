/// Registry of mobile-only routes and features.
///
/// Used by the web app to exclude routes that depend on native capabilities
/// (camera, local ML, push notifications, file system).
class WebFeatureGate {
  static const mobileOnlyRoutes = {
    '/document-scan',
    '/document-scan/avs-guide',
    '/documents',
    '/documents/:id',
    '/bank-import',
    '/profile/slm',
  };

  static const mobileOnlyFeatures = {
    'iap',
    'push_notifications',
    'camera_ocr',
    'slm_inference',
  };

  /// Returns `true` if the route is available on web.
  static bool isRouteAvailable(String route) =>
      !mobileOnlyRoutes.contains(route);

  /// Returns `true` if the feature is enabled on web.
  static bool isFeatureEnabled(String feature) =>
      !mobileOnlyFeatures.contains(feature);
}
