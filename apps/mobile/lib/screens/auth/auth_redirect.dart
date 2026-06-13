String? resolvePostAuthRedirect(Uri uri) {
  final redirect = uri.queryParameters['redirect'];
  if (redirect == null || redirect.isEmpty) return null;

  late final String decoded;
  try {
    decoded = redirect.contains('%') ? Uri.decodeComponent(redirect) : redirect;
  } on Object {
    return null;
  }

  final target = Uri.tryParse(decoded);
  if (!decoded.startsWith('/') ||
      decoded.startsWith('//') ||
      decoded.contains(r'\') ||
      decoded.contains(RegExp(r'[\x00-\x1F\x7F]')) ||
      target == null ||
      target.hasScheme ||
      target.hasAuthority) {
    return null;
  }
  return decoded;
}

String authRouteWithRedirect(String route, Uri currentUri) {
  final redirect = resolvePostAuthRedirect(currentUri);
  if (redirect == null) return route;
  return '$route?redirect=${Uri.encodeComponent(redirect)}';
}
