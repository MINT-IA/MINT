// Bascule 4 — entrée CANONIQUE unique vers (ou hors de) l'onboarding.
//
// Contrat : product/mint_next/storyboard/first_open.storyboard.json.
// Aucun écran ne navigue plus littéralement vers /onb, /start ou un alias
// /onboarding/* : ils passent tous par ici, ce qui rend l'intention
// explicite AU POINT D'APPEL et non seulement au redirect global.
//
// En préversion, le wizard legacy n'existe pas : l'appel active le mode
// local puis ouvre la coque du jumeau. Hors préversion, le comportement
// legacy est strictement inchangé.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';

class LegacyOnboardingEntry {
  const LegacyOnboardingEntry._();

  /// Destination legacy historique (hors préversion uniquement).
  /// Les autres fichiers la RÉFÉRENCENT au lieu de la réécrire : un
  /// littéral dispersé échappe au checker de fermeture (review T1 #2).
  static const String legacyPath = '/onb';

  /// Alias legacy DÉRIVÉ du registre plutôt que redéclaré : le registre
  /// est la source de vérité des chemins, le dupliquer ici créerait une
  /// seconde déclaration à maintenir.
  static final String premierEclairagePath = kRouteRegistry.keys.firstWhere(
    (path) => path.startsWith('/onboarding/premier-'),
  );

  /// Alias historique dont la fermeture atteint le wizard.
  static const String anonymousChatPath = '/anonymous/chat';

  /// Préfixes des alias legacy — pour les gates qui raisonnent par
  /// préfixe plutôt que par chemin exact.
  static const List<String> legacyPathPrefixes = ['/onb', '/onboarding'];

  /// Entrée canonique de la préversion — la coque du jumeau.
  static const String previewPath = '/home';

  /// Ouvre le parcours d'entrée : wizard legacy hors préversion, coque du
  /// jumeau en préversion (après activation EXPLICITE du mode local).
  ///
  /// Retourne `true` si la navigation a eu lieu — une activation de mode
  /// local qui échoue ne navigue JAMAIS.
  static Future<bool> open(BuildContext context) async {
    if (!PreviewShellPolicy.instance.isPreviewShell) {
      context.go(legacyPath);
      return true;
    }
    final auth = context.read<AuthProvider>();
    try {
      await auth.enableLocalMode();
    } catch (_) {
      // Activation échouée : rester où l'on est plutôt qu'ouvrir une
      // coque sans mode local durable (état à moitié vrai).
      return false;
    }
    if (!context.mounted) return false;
    if (!auth.authLifecycle.allowsMainNavigation) return false;
    context.go(previewPath);
    return true;
  }
}
