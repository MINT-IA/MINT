import 'package:mint_mobile/services/report_persistence_service.dart';

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

bool hasDossierIdentityAnswers(Map<String, dynamic> answers) {
  final dateOfBirth = answers['q_date_of_birth'];
  if (dateOfBirth is String && DateTime.tryParse(dateOfBirth) != null) {
    return true;
  }

  final birthYear = answers['q_birth_year'];
  if (birthYear is int) return true;
  if (birthYear is String && int.tryParse(birthYear) != null) return true;

  return false;
}

Future<bool> hasPostAuthDossierIdentity({
  required DateTime? localDateOfBirth,
}) async {
  if (localDateOfBirth != null) return true;
  final answers = await ReportPersistenceService.loadAnswers();
  return hasDossierIdentityAnswers(answers);
}

String resolvePostAuthDestination({
  required Uri currentUri,
  required bool hasDossierIdentity,
  String fallback = '/home',
}) {
  final redirect = resolvePostAuthRedirect(currentUri);
  final destination = redirect ?? fallback;
  if (!hasDossierIdentity && _requiresDossierIdentity(destination)) {
    return '/onb';
  }
  return destination;
}

bool _requiresDossierIdentity(String destination) {
  final path = Uri.tryParse(destination)?.path ?? destination;
  return path == '/anonymous/chat' ||
      path == '/coach/chat' ||
      path == '/home' ||
      path == '/mon-argent' ||
      path == '/rapport' ||
      path.startsWith('/explore') ||
      path.startsWith('/profile/bilan');
}

String authRouteWithRedirect(String route, Uri currentUri) {
  final redirect = resolvePostAuthRedirect(currentUri);
  if (redirect == null) return route;
  return '$route?redirect=${Uri.encodeComponent(redirect)}';
}
