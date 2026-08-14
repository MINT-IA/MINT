// Bascule 4 — beat b4_reset_to_landing.
//
// « Le reset local B2 renvoie à la LANDING, jamais à /start ni /onb. »
// (product/mint_next/storyboard/first_open.storyboard.json)
//
// POURQUOI CE BEAT EXISTE, ET POURQUOI IL EST ARRIVÉ APRÈS COUP
//
// Le cadrage de la bascule 4 note noir sur blanc que le reçu de la bascule 2
// affirme « retour entrée onboarding (état zéro légitime) » — et que B4 rend
// cette phrase FAUSSE. Le comportement du code était déjà correct
// (`privacy_center_screen.dart:107` fait `context.go('/')`), mais rien ne
// l'empêchait de redevenir faux : aucun test ne tenait la destination.
//
// Ce fichier tient la destination. Il ne teste pas un widget mais l'INVARIANT
// de routage qui la rend vraie — une assertion sur le widget casserait au
// premier refactor de l'écran sans rien dire du contrat ; une assertion sur
// le registre et la politique survit au refactor et casse quand la vérité
// change.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/screens/profile/privacy_center_screen.dart';
import 'package:mint_mobile/routes/route_owner.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';

void main() {
  const preview = PreviewShellPolicy.forTest(isPreviewShell: true);

  test(
      'after a local reset the app returns to the landing and never to a '
      'legacy onboarding route', () {
    // La destination du reset, LUE SUR L'ÉCRAN qui l'emploie — pas
    // recopiée à côté. Une constante recopiée dans le test laisserait passer
    // exactement la régression que ce beat existe pour interdire : quelqu'un
    // change `context.go(...)` dans l'écran, le test reste vert, et le reçu
    // B2 redevient vrai en silence.
    const destination = PrivacyCenterScreen.resetDestination;

    // 1. Elle existe au registre. Une destination absente du registre
    //    échapperait à toute politique — le trou exact que B4 ferme.
    expect(kRouteRegistry.containsKey(destination), isTrue,
        reason: 'une destination hors registre échappe à la politique de '
            'coque, donc à toute garantie');

    // 2. Elle n'appartient PAS à l'onboarding legacy.
    expect(kRouteRegistry[destination]!.owner,
        isNot(RouteOwner.legacyOnboarding),
        reason: 'renvoyer le reset vers une route legacy rouvrirait le '
            "couloir que la bascule 4 vient de fermer");

    // 3. Et la préversion ne la bloque pas : une destination de reset
    //    interdite laisserait la personne nulle part.
    expect(preview.blocksRoute(destination), isFalse,
        reason: 'le reset doit atterrir quelque part — une destination '
            'bloquée transformerait « repartir à zéro » en cul-de-sac');

    // 4. Les deux routes que le reçu B2 citait à tort restent, elles,
    //    interdites. C'est la phrase que B4 rend fausse, tenue par un test.
    for (final legacy in ['/start', '/onb']) {
      expect(preview.blocksRoute(legacy), isTrue,
          reason: '$legacy était la destination annoncée par le reçu B2 ; '
              'elle est désormais interdite, et ce test empêche qu\'on l\'y '
              'ramène sans s\'en apercevoir');
    }
  });

  test(
      'the landing is reachable without any prior local mode — a reset that '
      'required the state it just cleared would be a trap', () {
    // Le reset efface le mode local. Si la landing exigeait ce mode pour
    // s'afficher, la personne se retrouverait devant un écran qui refuse de
    // la recevoir juste après qu'elle a demandé à repartir de zéro.
    final meta = kRouteRegistry['/']!;
    expect(meta.requiresAuth, isFalse,
        reason: 'la landing suit immédiatement un effacement : exiger une '
            'session serait exiger ce qu\'on vient de supprimer');
  });
}
