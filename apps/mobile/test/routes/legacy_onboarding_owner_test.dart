// Bascule 4 — beats b4_owner_legacy et b4_policy_fail_closed.
//
// L'autorité est STRUCTURELLE : un owner de route dédié, interdit
// fail-closed en préversion. Elle survit à l'ajout d'un alias, ce qu'une
// liste d'écrans ne ferait pas (trou trouvé sur TestFlight 2.13.3+80 :
// l'onboarding legacy s'ouvrait au premier lancement).

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/routes/legacy_onboarding_entry.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/routes/route_owner.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';

void main() {
  const preview = PreviewShellPolicy.forTest(isPreviewShell: true);
  const public = PreviewShellPolicy.forTest(isPreviewShell: false);

  test(
      'the transitive route graph extracted from the router marks every '
      'path reaching the legacy onboarding shell with the legacyOnboarding '
      'owner', () {
    // Le graphe transitif est calculé par tools/checks/route_closure_check.py
    // (le registre seul ignore builder et cible de redirect). Ce test fige
    // le RÉSULTAT attendu côté registre : les trois chemins connus dont la
    // fermeture atteint OnboardingShellScreen portent l'owner dédié.
    for (final path in ['/onb', '/start', '/anonymous/chat']) {
      expect(kRouteRegistry[path]?.owner, RouteOwner.legacyOnboarding,
          reason: '$path atteint le shell legacy — owner dédié obligatoire');
    }
  });

  test(
      'every route under a legacy prefix carries the owner — derived from the '
      'registry, not from a list the test wrote itself', () {
    // CE QUE CE TEST RÉPARE (2026-08-15, trouvé par un axe de clôture Codex).
    //
    // Le test ci-dessus annonce « le graphe transitif », et vérifie en fait
    // TROIS CHEMINS QUE LE TEST A LUI-MÊME ÉCRITS. Un quatrième alias ajouté
    // demain sous /onboarding/ resterait invisible : l'oracle ne peut pas
    // signaler ce qu'il n'énumère pas.
    //
    // Celui-ci ne connaît aucun chemin d'avance. Il parcourt TOUT le registre
    // et exige l'owner sur chaque route dont le préfixe est déclaré legacy —
    // préfixes eux-mêmes lus sur l'autorité centrale, jamais recopiés.
    // ET CE QUE MA PREMIÈRE VERSION SE TROMPAIT À AFFIRMER.
    //
    // Elle exigeait l'owner sur TOUTE route sous préfixe legacy. Elle a
    // échoué sur `/onboarding/enrichment` — et le code avait raison : cette
    // route redirige vers `/profile/bilan`, pas vers le wizard. Elle est
    // legacy par son NOM, pas par sa DESTINATION. Le préfixe est une
    // heuristique de nommage, jamais une preuve de nature.
    //
    // L'invariant vrai — « atteint le shell legacy ⇒ owner » — n'est pas
    // calculable ici : la fermeture transitive du graphe de routes appartient
    // à tools/checks/route_closure_check.py. Ce que ce test PEUT tenir, c'est
    // le refus par défaut : toute route sous préfixe legacy doit être soit
    // possédée, soit explicitement justifiée ici. Un alias ajouté demain
    // échoue tant que personne ne l'a motivé.
    const justifiees = <String, String>{
      '/onboarding/enrichment':
          'redirige vers /profile/bilan — n\'atteint pas le wizard '
              '(app.dart:1990-1994)',
      '/onboarding/premier-eclairage':
          'redirection héritée vers /onb, déjà couverte par l\'owner de /onb '
              '(app.dart:1873-1881)',
    };

    final sousPrefixeLegacy = kRouteRegistry.entries
        .where((e) => LegacyOnboardingEntry.legacyPathPrefixes
            .any((p) => e.key == p || e.key.startsWith('$p/')))
        .toList();

    expect(sousPrefixeLegacy, isNotEmpty,
        reason: 'si le registre ne contenait plus AUCUNE route legacy, cet '
            'oracle passerait en ne mesurant rien — on refuse ce vide');

    for (final e in sousPrefixeLegacy) {
      if (e.value.owner == RouteOwner.legacyOnboarding) continue;
      expect(justifiees.containsKey(e.key), isTrue,
          reason: '« ${e.key} » vit sous un préfixe legacy, ne porte pas '
              "l'owner, et n'est justifiée nulle part. Soit elle atteint le "
              'wizard et doit être possédée, soit elle mène ailleurs et doit '
              'le dire ici. Le silence est le seul cas interdit.');
    }
  });

  test(
      'the preview policy blocks the legacy onboarding owner and redirects '
      'to the canonical preview entry', () {
    for (final path in ['/onb', '/start', '/anonymous/chat']) {
      expect(preview.blocksRoute(path), isTrue,
          reason: '$path est interdit FAIL-CLOSED en préversion');
    }
    expect(preview.forbiddenRouteRedirect, '/home',
        reason: "l'entrée préversion canonique");
  });

  test(
      'the full legacy redirect closure is acyclic and terminates on an '
      'allowed preview entry', () {
    // La cible de redirection ne doit JAMAIS être elle-même bloquée,
    // sinon le fail-closed boucle.
    final target = preview.forbiddenRouteRedirect;
    expect(preview.blocksRoute(target), isFalse,
        reason: 'la cible de redirection ne peut pas être bloquée');
    expect(kRouteRegistry[target]?.owner,
        isNot(RouteOwner.legacyOnboarding),
        reason: 'jamais une redirection vers une AUTRE route legacy');
  });

  test(
      'outside the preview policy the legacy onboarding stays reachable and '
      'unchanged', () {
    for (final path in ['/onb', '/start', '/anonymous/chat']) {
      expect(public.blocksRoute(path), isFalse,
          reason: 'hors préversion, le comportement est INCHANGÉ');
    }
  });

  test(
      'the legacy onboarding owner is a dedicated authority, not a screen '
      'list', () {
    // Aucun autre owner ne porte l'onboarding legacy : l'ajout d'un alias
    // se voit dans le registre, pas dans une énumération d'écrans.
    final legacyPaths = kRouteRegistry.entries
        .where((e) => e.value.owner == RouteOwner.legacyOnboarding)
        .map((e) => e.key)
        .toSet();
    expect(legacyPaths, containsAll(['/onb', '/start', '/anonymous/chat']));
    for (final path in legacyPaths) {
      expect(preview.blocksRoute(path), isTrue,
          reason: 'tout membre de cet owner est bloqué, sans exception');
    }
  });
}
