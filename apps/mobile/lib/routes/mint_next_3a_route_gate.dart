final class MintNext3aRouteIntent {
  const MintNext3aRouteIntent._();

  static const taskManagement = MintNext3aRouteIntent._();
}

String? mintNext3aRouteRedirect({
  required bool flagEnabled,
  required Object? extra,
}) {
  if (flagEnabled || identical(extra, MintNext3aRouteIntent.taskManagement)) {
    return null;
  }
  return '/home';
}
