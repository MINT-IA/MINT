String? authInternalRedirect(String? rawRedirect) {
  final redirect = rawRedirect?.trim();
  if (redirect == null || redirect.isEmpty) return null;
  if (!redirect.startsWith('/') || redirect.startsWith('//')) return null;
  if (redirect.contains(r'\')) return null;

  final uri = Uri.tryParse(redirect);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (!uri.path.startsWith('/')) return null;
  if (uri.path.startsWith('/auth/')) return null;

  final decodedPath = _decodePathOrNull(uri.path);
  if (decodedPath == null) return null;
  if (decodedPath.startsWith('//') || decodedPath.contains(r'\')) return null;

  return uri.toString();
}

String? _decodePathOrNull(String path) {
  try {
    return Uri.decodeComponent(path);
  } on FormatException {
    return null;
  }
}

String authInternalRedirectOrFallback(
  String? rawRedirect, {
  required String fallback,
}) {
  return authInternalRedirect(rawRedirect) ?? fallback;
}
