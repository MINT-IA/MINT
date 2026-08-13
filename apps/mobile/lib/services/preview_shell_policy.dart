import 'package:flutter/foundation.dart';

import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/routes/route_owner.dart';

/// Bascule 1 — politique centrale de la coque préversion.
///
/// Contrat : `product/mint_next/storyboard/preview_shell.storyboard.json`.
/// UNIQUE point de vérité dérivé du define compile-time : aucun écran ne lit
/// le define directement (guard commit-gate anti-dispersion). Les écrans
/// consomment des propriétés sémantiques ; hors préversion, chaque propriété
/// restitue strictement le comportement actuel.
class PreviewShellPolicy {
  const PreviewShellPolicy._(this.isPreviewShell);

  /// Seule occurrence autorisée du define dans `lib/` (guard).
  static const bool previewDefine = bool.fromEnvironment('MINT_NEXT_PREVIEW');

  static const PreviewShellPolicy _fromDefine =
      PreviewShellPolicy._(previewDefine);

  /// Seam de test — jamais lu en release.
  @visibleForTesting
  static PreviewShellPolicy? debugOverride;

  static PreviewShellPolicy get instance =>
      kReleaseMode ? _fromDefine : (debugOverride ?? _fromDefine);

  @visibleForTesting
  const PreviewShellPolicy.forTest({required bool isPreviewShell})
      : this._(isPreviewShell);

  final bool isPreviewShell;

  // ── Destinations de la coque ──
  bool get showCoachTab => !isPreviewShell;
  bool get showExplorerTab => !isPreviewShell;

  // ── Surfaces d'Aujourd'hui ──
  bool get showLegacyTodayCards => !isPreviewShell;

  // ── Surfaces de Ma situation ──
  bool get showLegacyBudgetHero => !isPreviewShell;
  bool get showLegacyCoachWhisper => !isPreviewShell;
  bool get showLegacySituationMaps => !isPreviewShell;
  bool get showLegacySectionSelector => !isPreviewShell;

  /// Enforcement AU POINT DE DESTINATION : toute route possédée par le coach
  /// ou l'explorer est fail-closed en préversion — les alias owner:system
  /// qui y redirigent héritent du blocage via leur cible gardée.
  bool blocksRoute(String path) {
    if (!isPreviewShell) return false;
    final meta = kRouteRegistry[path];
    if (meta == null) return false;
    return meta.owner == RouteOwner.coach ||
        meta.owner == RouteOwner.explore ||
        // Bascule 4 — l'onboarding legacy est interdit FAIL-CLOSED : la
        // première ouverture ne doit jamais y tomber (trou trouvé sur
        // TestFlight 2.13.3+80).
        meta.owner == RouteOwner.legacyOnboarding;
  }

  /// Redirection déterministe des destinations interdites.
  String get forbiddenRouteRedirect => '/home';

  /// Params de coque (/home?screen=coach|explore) neutralisés au même
  /// point de destination — testable isolément.
  String? redirectForShellParams(Map<String, String> queryParameters) {
    if (!isPreviewShell) return null;
    final screen = queryParameters['screen'];
    if (screen == 'coach' || screen == 'explore') {
      return forbiddenRouteRedirect;
    }
    return null;
  }
}
