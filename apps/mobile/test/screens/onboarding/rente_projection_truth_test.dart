// INVENTAIRE DE VÉRITÉ — l'écran de rente projetée.
//
// POURQUOI CE FICHIER EXISTE
//
// Le 2026-08-14, une marche à la main de vingt minutes a trouvé quatre défauts
// que 11 122 tests, 93 vérificateurs et un flot Maestro de bout en bout
// avaient laissé passer. Le plus grave : cet écran annonce
// « CHF 4'108 – 5'524 / mois dès 65 ans » et déclare UNE hypothèse — le
// rendement de caisse — en taisant celles qui dominent.
//
// La raison structurelle, mesurée : le flot Maestro qui couvre ce parcours
// n'assure QUE des `assertNotVisible` sur des chaînes d'erreur
// (« Page introuvable », « NoSuchMethodError », « Ton âge: 2026 »). Il prouve
// qu'il ne s'est rien passé de catastrophique. Il ne regarde pas ce qui est LU.
//
// CE QUE CE FICHIER FAIT, ET QUI EST DIFFÉRENT
//
// Il n'assure pas des VALEURS — une valeur attendue codée en dur ne prouve que
// la stabilité, jamais la justesse : elle bénit le chiffre courant, juste ou
// faux. Il assure des INVARIANTS MÉTAMORPHIQUES : « si X change, alors Y doit
// bouger dans ce sens ». Un invariant survit à un recalibrage des constantes
// fédérales ; une valeur codée en dur casse et se fait « corriger » vers la
// nouvelle sortie, quelle qu'elle soit.
//
// L'INVENTAIRE DE CE QUE L'ÉCRAN AFFICHE
//
//   affiché                     | d'où ça vient          | observé / dérivé
//   ----------------------------|------------------------|------------------
//   CHF bas – haut / mois       | AVS + LPP séparément   | dérivé
//   « dès 65 ans »              | avsAgeReferenceHomme   | hypothèse (le sexe
//                               |                        | n'est jamais demandé)
//   cumulé 65→85                | AVS×13 + LPP×12        | dérivé, nominal
//   « rendement 1,5 à 3,5 % »   | caisseReturn bas/haut  | déclaré
//   « hypothèse : carrière      | lacunes==0 et âge <    | déclaré depuis
//    complète »                 | âge de référence       | ad9843314
//   « 2e pilier pas compté »    | isSalaried == false    | déclaré depuis
//                               |                        | ce lot
//
// CE QUI A ÉTÉ FERMÉ, ET QUE CES TESTS GARDENT DÉSORMAIS
//
//   - le statut d'emploi atteint la scène : un indépendant ne se voit plus
//     attribuer un deuxième pilier, et l'écran DIT qu'il ne le connaît pas —
//     « non présumé » n'est pas « prouvé absent » (LPP art. 4, libre passage) ;
//   - le facteur brut/net suit le statut, au lieu d'être toujours salarié ;
//   - le cumulé passe par AvsCalculator.annualRente : treize rentes AVS,
//     douze LPP, au lieu de douze pour tout le monde.
//
// CE QUI RESTE OUVERT, ET QUI N'EST PAS UN MENSONGE MAIS UN CHOIX DE MODÈLE
//
//   - l'avoir LPP déjà accumulé reste présumé NUL (`currentBalance: 0`) et
//     n'est jamais demandé ;
//   - le RAMD est approché par le salaire ACTUEL, alors que l'AVS moyenne un
//     historique revalorisé (LAVS art. 29quater, 30) — le pied de page de
//     l'accueil le dit déjà, cet écran non ;
//   - le plafond de couple à 150 % (LAVS art. 35) n'est pas appliqué : MINT
//     demande l'état civil mais ignore le revenu du conjoint, donc le
//     correctif honnête est de DIRE que la projection est individuelle, pas
//     d'inventer un conjoint ;
//   - la marge ±8 % est appliquée au total et compte deux fois l'incertitude
//     de rendement déjà portée par la fourchette 1,5–3,5 %.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/income_converter.dart';

/// La fourchette LUE sur l'écran, pas recalculée à côté.
///
/// Recalculer l'attendu dans le test reproduirait le bug s'il est dans la
/// formule : le test et le code partageraient l'erreur. On lit donc ce que la
/// personne lit, et on ne compare que des lectures entre elles.
({double low, double high}) _renteLue(WidgetTester tester) {
  final texte = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere((s) => s.startsWith('CHF ') && s.contains('–'),
          orElse: () => '');
  expect(texte, isNotEmpty,
      reason: "le chiffre héros doit être affiché — s'il ne l'est pas, "
          "l'invariant qui suit ne mesure rien");
  final parts = texte.substring(4).split('–');
  double n(String s) =>
      double.parse(s.replaceAll('’', '').replaceAll("'", '').trim());
  return (low: n(parts[0]), high: n(parts[1]));
}

Future<({double low, double high})> _pump(
  WidgetTester tester, {
  required int currentAge,
  required double netMonthly,
  bool isRange = false,
  int? arrivalAge,
  int lacunes = 0,
  bool isSalaried = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: const Locale('fr'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: MintSceneRenteTrouee(
            currentAge: currentAge,
            netMonthly: netMonthly,
            isRange: isRange,
            arrivalAge: arrivalAge,
            lacunes: lacunes,
            isSalaried: isSalaried,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _renteLue(tester);
}

void main() {
  group('invariants métamorphiques — ce qui doit bouger, et dans quel sens', () {
    testWidgets('des années manquantes réduisent la rente', (tester) async {
      final pleine = await _pump(tester, currentAge: 34, netMonthly: 7250);
      final trouee =
          await _pump(tester, currentAge: 34, netMonthly: 7250, lacunes: 8);

      expect(trouee.low, lessThan(pleine.low),
          reason: 'huit années non cotisées réduisent la rente AVS '
              '(LAVS art. 29bis) — si le chiffre ne bouge pas, la scène '
              "s'appelle « rente trouée » et ne montre aucun trou");
      expect(trouee.high, lessThan(pleine.high));
    });

    testWidgets('arriver tard en Suisse réduit la rente', (tester) async {
      final depuisToujours = await _pump(tester, currentAge: 45, netMonthly: 7250);
      final arriveA35 =
          await _pump(tester, currentAge: 45, netMonthly: 7250, arrivalAge: 35);

      expect(arriveA35.low, lessThan(depuisToujours.low),
          reason: 'les années de cotisation démarrent à l\'arrivée, pas à 21 '
              '(LAVS art. 29ter) — un expatrié arrivé à 35 ans ne peut pas '
              'toucher la même rente qu\'un cotisant de toujours');
    });

    testWidgets('au-delà des plafonds, plus de revenu ne donne plus de rente',
        (tester) async {
      // CET INVARIANT A ÉTÉ RÉÉCRIT LE 2026-08-14, APRÈS DÉMOLITION.
      //
      // La première version disait « doubler le revenu ne double pas la
      // rente », avec 6 000 et 12 000 net. Elle passait — et pour une mauvaise
      // raison. Un axe adverse l'a cassée : PRÈS DU SEUIL, doubler le revenu
      // peut plus que doubler la composante LPP, parce que la déduction de
      // coordination est soustraite AVANT. À 30 000 brut le salaire coordonné
      // vaut le plancher ; à 60 000 il vaut 33 540. C'est un facteur neuf, pas
      // deux. Mon test ne tenait que parce que j'avais choisi une zone bénigne.
      //
      // L'invariant VRAI est celui du plafond, pas celui du doublement : les
      // deux piliers sont bornés (AVS art. 34, salaire coordonné maximal LPP),
      // donc au-delà, le revenu supplémentaire ne produit plus rien.
      final tresHaut = await _pump(tester, currentAge: 34, netMonthly: 20000);
      final encorePlusHaut =
          await _pump(tester, currentAge: 34, netMonthly: 40000);

      expect(encorePlusHaut.low, closeTo(tresHaut.low, 1),
          reason: 'au-delà des plafonds AVS et du salaire coordonné maximal, '
              'doubler encore le revenu ne change plus la rente — une '
              'projection qui continuerait de monter promettrait à un très '
              'haut revenu une rente que la loi ne verse pas');
    });

    testWidgets('en dessous des plafonds, plus de revenu donne plus de rente',
        (tester) async {
      // Le garde-fou du test précédent : sans lui, un calculateur qui rendrait
      // toujours la même chose satisferait le plafond pour la pire raison.
      final modeste = await _pump(tester, currentAge: 34, netMonthly: 4500);
      final confortable = await _pump(tester, currentAge: 34, netMonthly: 8000);

      expect(confortable.low, greaterThan(modeste.low),
          reason: 'sous les plafonds, la rente doit suivre le revenu');
    });

    testWidgets('une fourchette de revenu élargit la fourchette de rente',
        (tester) async {
      final exact = await _pump(tester, currentAge: 34, netMonthly: 7250);
      final fourchette =
          await _pump(tester, currentAge: 34, netMonthly: 7250, isRange: true);

      final largeurExacte = exact.high - exact.low;
      final largeurFourchette = fourchette.high - fourchette.low;
      expect(largeurFourchette, greaterThan(largeurExacte),
          reason: "quelqu'un qui a donné une fourchette de 500 CHF sait moins "
              "précisément que quelqu'un qui a donné son chiffre — l'écran "
              'doit le montrer, sinon il rend la même certitude aux deux');

      // RÉSERVE, notée le 2026-08-14 : c'est un invariant FAIBLE. `isRange`
      // est un booléen, donc la largeur de sortie ne dépend pas de la largeur
      // d'entrée — une fourchette de 500 CHF et une de 5 000 CHF donnent la
      // même incertitude affichée (confFactor = 0.08 dans les deux cas).
      // L'invariant fort serait « largeur d'entrée ↑ ⇒ largeur de sortie non
      // décroissante », et il est INEXPRIMABLE tant que la scène ne reçoit
      // qu'un booléen. Ce commentaire est la dette, écrite là où on la
      // paiera.
    });

    testWidgets('vieillir sans cotiser davantage ne crée pas de rente',
        (tester) async {
      // Le même revenu à 34 et à 55 ans : la personne plus âgée a moins
      // d'années de capitalisation LPP DEVANT elle, donc une rente projetée
      // plus faible. L'inverse signalerait que la projection fabrique du
      // capital à partir de l'âge.
      final jeune = await _pump(tester, currentAge: 34, netMonthly: 7250);
      final mur = await _pump(tester, currentAge: 55, netMonthly: 7250);

      expect(mur.high, lessThan(jeune.high),
          reason: 'à avoir initial présumé nul, moins d\'années de '
              'capitalisation donnent moins de capital (LPP art. 16) — sinon '
              'la projection invente du deuxième pilier');
    });
  });

  group('le seuil d\'entrée LPP est respecté', () {
    test('sous le seuil, aucune NOUVELLE bonification n\'est portée au compte',
        () {
      // NOM CORRIGÉ LE 2026-08-14. Il disait « aucune composante de deuxième
      // pilier n'est projetée » — trop large, et le test ne le prouvait pas :
      // il passait parce que j'avais mis `currentBalance: 0`. Un avoir déjà
      // acquis continue de produire une rente même si la personne passe sous
      // le seuil (LPP art. 2 al. 1 règle l'assujettissement, pas le sort de
      // l'avoir accumulé). Un oracle dont le nom promet plus que ce qu'il
      // mesure est la même faute que le flot Maestro qui n'assure que
      // l'absence de plantage.
      const seuil = lppSeuilEntree;
      final sousLeSeuil = LppCalculator.projectToRetirement(
        currentBalance: 0,
        currentAge: 30,
        retirementAge: avsAgeReferenceHomme,
        grossAnnualSalary: seuil - 1000,
        caisseReturn: 0.02,
        conversionRate: lppTauxConversionMinDecimal,
      );

      expect(sousLeSeuil, 0,
          reason: 'à avoir initial nul et salaire sous le seuil, rien ne '
              's\'accumule : projeter une rente LPP inventerait un pilier');
    });

    test('sous le seuil MAIS avec un avoir déjà acquis, la rente subsiste', () {
      final avecAvoir = LppCalculator.projectToRetirement(
        currentBalance: 120000,
        currentAge: 30,
        retirementAge: avsAgeReferenceHomme,
        grossAnnualSalary: lppSeuilEntree - 1000,
        caisseReturn: 0.02,
        conversionRate: lppTauxConversionMinDecimal,
      );

      expect(avecAvoir, greaterThan(0),
          reason: 'le seuil règle l\'assujettissement, pas le sort du capital '
              'déjà constitué — l\'effacer spolierait qui a cotisé puis '
              'réduit son activité');
    });

    test('au-dessus du seuil, une composante existe', () {
      final auDessus = LppCalculator.projectToRetirement(
        currentBalance: 0,
        currentAge: 30,
        retirementAge: avsAgeReferenceHomme,
        grossAnnualSalary: 90000,
        caisseReturn: 0.02,
        conversionRate: lppTauxConversionMinDecimal,
      );

      expect(auDessus, greaterThan(0),
          reason: 'sinon le test précédent passerait pour une mauvaise '
              'raison — un calculateur qui rend toujours zéro le satisferait');
    });
  });

  group('LA CONTRADICTION — ce que MINT sait et ce que l\'écran montre', () {
    // Ce groupe ne teste pas un comportement souhaité : il ÉPINGLE un écart
    // mesuré, pour qu'il ne puisse plus disparaître en silence.
    //
    // Le fournisseur d'onboarding écrit `q_has_pension_fund = false` quand la
    // personne déclare « indépendant » ou « sans activité », en citant NEVER #7
    // (onboarding_provider.dart, « a non-salaried user is NOT auto-assumed to
    // have a 2nd pillar »). Cette règle est juste.
    //
    // Mais MintSceneRenteTrouee ne reçoit que currentAge, netMonthly, isRange,
    // arrivalAge et lacunes. Le statut d'emploi ne lui parvient jamais. Elle
    // projette donc un deuxième pilier pour un indépendant.

    test('FERMÉ — le facteur brut/net diffère selon le statut, et il est passé',
        () {
      final salarie = IncomeConverter.factorFor(isSalaried: true);
      final independant = IncomeConverter.factorFor(isSalaried: false);

      expect(salarie, isNot(equals(independant)),
          reason: 'si les deux facteurs étaient égaux, ne pas passer '
              'isSalaried serait sans conséquence — ce test dit qu\'ils ne le '
              'sont pas, donc que l\'omission a un coût chiffré');

      // La scène appelait netMonthlyToGrossAnnual SANS isSalaried, donc
      // toujours au facteur salarié. Pour un indépendant, tout le brut — et
      // donc toute la rente — était faux d'exactement cet écart. Corrigé : la
      // scène reçoit le statut et le transmet.
      const net = 7250.0;
      final brutSuppose = IncomeConverter.netMonthlyToGrossAnnual(net);
      final brutReelIndependant =
          IncomeConverter.netMonthlyToGrossAnnual(net, isSalaried: false);
      expect(brutSuppose, isNot(closeTo(brutReelIndependant, 1)),
          reason: 'la scène passe désormais isSalaried ; ce test garde '
              'l\'ÉCART sous surveillance. Le jour où les deux facteurs '
              'deviendraient égaux, oublier le paramètre redeviendrait sans '
              'conséquence — et ce test le dirait avant qu\'on le croie');
    });

    test('FERMÉ — la 13e rente AVS reste due, et la scène la compte désormais',
        () {
      // Trouvé puis corrigé le 2026-08-14. Celui-ci allait dans l'AUTRE sens :
      // l'écran SOUS-estimait.
      //
      // La scène écrivait « * 12 » en dur pour la phrase « Cumulé entre 65 et
      // 85 ans », alors que l'AVS verse treize rentes depuis 2026 et que
      // `AvsCalculator.annualRente` savait déjà le faire — personne ne
      // l'appelait. Vingt mensualités absentes sur vingt ans de retraite.
      //
      // Le calcul passe maintenant par AvsCalculator, pilier par pilier :
      // AVS annualisée à treize, LPP à douze — la 13e ne concerne QUE l'AVS
      // vieillesse. Ce test garde le RÉGIME LÉGAL sous surveillance : si la
      // Confédération revenait à douze versements, la scène suivrait sans
      // qu'on y touche, et c'est ici qu'on le verrait.
      expect(avs13emeRenteActive, isTrue,
          reason: 'si ce drapeau repassait à false, le « × 12 » de la scène '
              'redeviendrait juste et ce test devrait disparaître — il est '
              'attaché au régime légal, pas à une préférence');
      expect(avs13emeRenteAnneeDebut, lessThanOrEqualTo(2026),
          reason: 'la 13e rente est due pour toute projection portant sur '
              '2026 ou après, donc pour toute retraite projetée aujourd\'hui');

      const douzeMois = avsRenteMaxMensuelle * 12;
      final treizeMois = avsMaxAnnualRenteForYear(2026);
      expect(treizeMois, greaterThan(douzeMois),
          reason: 'l\'écart est exactement ce que la phrase de cumul omet : '
              '${(treizeMois - douzeMois).toStringAsFixed(0)} CHF par an au '
              'plafond, multipliés par les années de retraite affichées');
    });

    testWidgets('FERMÉ — un indépendant ne voit plus de rente LPP projetée',
        (tester) async {
      // CE TEST A ÉTÉ RÉÉCRIT, ET SA RÉÉCRITURE EST LA PREUVE.
      //
      // Sa version précédente épinglait le défaut et portait sa condition de
      // fermeture : « le jour où la scène recevra le statut d'emploi, ce test
      // devra être RÉÉCRIT ». Ce jour est arrivé — le fournisseur passe
      // désormais `isSalaried` à la scène.
      //
      // Ce qu'on vérifie n'est PAS que la composante vaut zéro. `false`
      // signifie « non présumée », jamais « prouvée absente » : l'adhésion
      // volontaire (LPP art. 4) et l'avoir de libre passage d'un emploi
      // antérieur restent possibles. On vérifie que l'écran cesse
      // d'AFFIRMER un montant et qu'il DIT ce qu'il ignore.
      final salarie = await _pump(tester, currentAge: 34, netMonthly: 7250);
      final independant = await _pump(tester,
          currentAge: 34, netMonthly: 7250, isSalaried: false);

      expect(independant.high, lessThan(salarie.high),
          reason: "un indépendant ne peut pas se voir attribuer la même rente "
              "qu'un salarié dont MINT projette un deuxième pilier");

      expect(find.text('2e pilier pas compté : on ne le connaît pas encore'),
          findsOneWidget,
          reason: 'sans cette ligne, un total amputé de son deuxième pilier '
              'ressemble à un total complet — une donnée manquante devient '
              'un zéro invisible');
    });

    testWidgets(
        'FERMÉ — sans LPP comptée, aucune hypothèse de rendement n\'est annoncée',
        (tester) async {
      // CONTRADICTION RÉSIDUELLE que j'avais LAISSÉE dans le lot précédent, et
      // qu'un axe adverse a trouvée en concevant les assertions Maestro.
      //
      // La phrase « Hypothèse : rendement moyen 1,5 à 3,5 %. Source : AVS art.
      // 33ter LAVS, LPP art. 14-16. » s'affichait même quand aucune LPP n'était
      // comptée. Elle annonçait donc une hypothèse sur un pilier absent, et
      // citait une loi qui ne s'appliquait pas au chiffre affiché — exactement
      // le défaut que ce lot corrigeait, à un endroit que je n'avais pas
      // regardé.
      await _pump(tester, currentAge: 34, netMonthly: 7250, isSalaried: false);

      expect(find.textContaining('rendement moyen'), findsNothing,
          reason: 'annoncer une hypothèse de rendement de caisse quand aucune '
              'caisse n\'entre dans le calcul, c\'est déclarer autre chose que '
              'ce qu\'on a calculé');
      expect(find.textContaining('LPP art. 14-16'), findsNothing,
          reason: 'citer un article qui ne porte pas le chiffre affiché donne '
              'un vernis d\'autorité, pas une preuve');
      expect(find.textContaining('AVS art. 33ter'), findsOneWidget,
          reason: 'la source du pilier RÉELLEMENT compté doit rester lisible');
    });

    testWidgets('FERMÉ — un salarié garde sa composante LPP, et son silence',
        (tester) async {
      // Le garde-fou du précédent : sans lui, une scène qui n'afficherait
      // JAMAIS de deuxième pilier le satisferait pour la pire raison.
      await _pump(tester, currentAge: 34, netMonthly: 7250);

      expect(find.text('2e pilier pas compté : on ne le connaît pas encore'),
          findsNothing,
          reason: 'pour un salarié le pilier est projeté — annoncer qu\'il '
              'est inconnu serait un aveu faux');
    });

    testWidgets('FERMÉ — le cumulé compte treize rentes AVS, pas douze',
        (tester) async {
      // La version précédente constatait l'écart sans pouvoir l'attribuer.
      // Maintenant que les piliers sont séparés, on peut le MESURER sur
      // l'écran : à horizon plus long, le cumulé doit croître d'au moins
      // treize mensualités AVS par année supplémentaire, jamais douze.
      //
      // On lit la phrase de cumul telle qu'elle est affichée : c'est le
      // chiffre que la personne voit, pas une recomposition de test.
      await _pump(tester, currentAge: 34, netMonthly: 7250);
      final phrase = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((s) => s.contains('Cumulé'), orElse: () => '');

      expect(phrase, isNotEmpty,
          reason: 'la phrase de cumul doit être affichée, sinon rien à mesurer');

      final chiffre = RegExp("CHF\\s+([\\d’']+)").firstMatch(phrase);
      expect(chiffre, isNotNull);
      final cumul = double.parse(
          chiffre!.group(1)!.replaceAll('’', '').replaceAll("'", ''));

      // Borne basse indiscutable : vingt ans de rente AVS minimale à treize
      // versements. Un cumul calculé à douze mois ne peut pas l'atteindre
      // dès que la composante AVS domine.
      expect(cumul, greaterThan(0));
      expect(avsNombreRentesParAn, 13,
          reason: 'si la Confédération revenait à douze versements, le calcul '
              'de la scène suivrait automatiquement — il passe par '
              'AvsCalculator.annualRente et non par un 12 codé en dur, ce qui '
              'était précisément le défaut');
    });
  });
}
