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
//   CHF bas – haut / mois       | AVS + LPP projetées    | dérivé
//   « dès 65 ans »              | avsAgeReferenceHomme   | hypothèse (le sexe
//                               |                        | n'est jamais demandé)
//   cumulé 65→85                | milieu × 12 × années   | dérivé, nominal
//   « rendement 1,5 à 3,5 % »   | caisseReturn bas/haut  | déclaré
//   « hypothèse : carrière      | lacunes==0 et âge <    | déclaré depuis
//    complète »                 | âge de référence       | ad9843314
//
// CE QUI N'EST PAS DÉCLARÉ, ET QUE CES TESTS ÉPINGLENT
//
//   - le brut est DÉRIVÉ du net (facteur salarié), jamais saisi ;
//   - l'avoir LPP déjà accumulé est présumé NUL (`currentBalance: 0`) ;
//   - la scène ignore le statut d'emploi que la personne vient de déclarer.
//
// Ce dernier point est le plus grave et il est vérifié plus bas : le
// fournisseur écrit `q_has_pension_fund = false` pour un indépendant, en
// citant NEVER #7 — et l'écran, qui ne reçoit pas cette information, projette
// quand même un deuxième pilier. MINT sait, et l'écran ne consulte pas.

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

    testWidgets('doubler le revenu ne double pas la rente — l\'AVS est plafonnée',
        (tester) async {
      final simple = await _pump(tester, currentAge: 34, netMonthly: 6000);
      final double_ = await _pump(tester, currentAge: 34, netMonthly: 12000);

      expect(double_.low, greaterThan(simple.low),
          reason: 'plus de revenu doit donner plus de rente');
      expect(double_.low, lessThan(simple.low * 2),
          reason: 'la rente AVS est plafonnée (LAVS art. 34) : une projection '
              'qui double proportionnellement promet à un haut revenu une '
              'rente que la loi ne verse pas');
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
    test('sous le seuil, aucune composante de deuxième pilier n\'est projetée',
        () {
      final seuil = lppSeuilEntree;
      final sousLeSeuil = LppCalculator.projectToRetirement(
        currentBalance: 0,
        currentAge: 30,
        retirementAge: avsAgeReferenceHomme,
        grossAnnualSalary: seuil - 1000,
        caisseReturn: 0.02,
        conversionRate: lppTauxConversionMinDecimal,
      );

      expect(sousLeSeuil, 0,
          reason: 'LPP art. 2 al. 1 : sous le seuil d\'entrée, pas '
              'd\'assujettissement obligatoire. Projeter une rente LPP à '
              'quelqu\'un qui n\'y a pas droit invente un pilier.');
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

    test('le facteur brut/net DIFFÈRE selon le statut — et la scène ne le passe pas',
        () {
      final salarie = IncomeConverter.factorFor(isSalaried: true);
      final independant = IncomeConverter.factorFor(isSalaried: false);

      expect(salarie, isNot(equals(independant)),
          reason: 'si les deux facteurs étaient égaux, ne pas passer '
              'isSalaried serait sans conséquence — ce test dit qu\'ils ne le '
              'sont pas, donc que l\'omission a un coût chiffré');

      // La scène appelle netMonthlyToGrossAnnual SANS isSalaried, donc avec la
      // valeur par défaut « salarié ». Pour un indépendant, le brut projeté
      // est faux d'exactement cet écart.
      const net = 7250.0;
      final brutSuppose = IncomeConverter.netMonthlyToGrossAnnual(net);
      final brutReelIndependant =
          IncomeConverter.netMonthlyToGrossAnnual(net, isSalaried: false);
      expect(brutSuppose, isNot(closeTo(brutReelIndependant, 1)),
          reason: 'un indépendant à $net net/mois se voit attribuer un brut '
              'de ${brutSuppose.toStringAsFixed(0)} au lieu de '
              '${brutReelIndependant.toStringAsFixed(0)} — et toute la rente '
              'en découle');
    });

    test('le cumulé 65→85 annualise à 12 mois alors que l\'AVS en verse 13',
        () {
      // Trouvé le 2026-08-14. Celui-ci va dans l'AUTRE sens : l'écran
      // sous-estime.
      //
      // `avs13emeRenteActive` vaut true depuis 2026 (LAVS art. 34 nouveau), et
      // AvsCalculator expose une annualisation qui en tient compte. La scène,
      // elle, écrit `* 12` en dur (mint_scene_rente_trouee.dart:136) pour la
      // phrase « Cumulé entre 65 et 85 ans : environ CHF … ».
      //
      // Sur vingt ans de retraite, c'est vingt mensualités AVS absentes du
      // total présenté. Le bon calcul sépare les deux piliers :
      // part AVS × 13 + part LPP × 12 — la 13e rente ne concerne QUE l'AVS
      // vieillesse.
      expect(avs13emeRenteActive, isTrue,
          reason: 'si ce drapeau repassait à false, le « × 12 » de la scène '
              'redeviendrait juste et ce test devrait disparaître — il est '
              'attaché au régime légal, pas à une préférence');
      expect(avs13emeRenteAnneeDebut, lessThanOrEqualTo(2026),
          reason: 'la 13e rente est due pour toute projection portant sur '
              '2026 ou après, donc pour toute retraite projetée aujourd\'hui');

      final douzeMois = avsRenteMaxMensuelle * 12;
      final treizeMois = avsMaxAnnualRenteForYear(2026);
      expect(treizeMois, greaterThan(douzeMois),
          reason: 'l\'écart est exactement ce que la phrase de cumul omet : '
              '${(treizeMois - douzeMois).toStringAsFixed(0)} CHF par an au '
              'plafond, multipliés par les années de retraite affichées');
    });

    test('un indépendant au-dessus du seuil reçoit quand même une rente LPP projetée',
        () {
      // Reproduction exacte du chemin de la scène : elle ne connaît que le
      // revenu, donc elle ne peut que projeter.
      final projetee = LppCalculator.projectToRetirement(
        currentBalance: 0,
        currentAge: 34,
        retirementAge: avsAgeReferenceHomme,
        grossAnnualSalary: IncomeConverter.netMonthlyToGrossAnnual(7250),
        caisseReturn: 0.025,
        conversionRate: lppTauxConversionMinDecimal,
      );

      expect(projetee, greaterThan(0),
          reason: 'CE TEST DOCUMENTE UN DÉFAUT, PAS UN CONTRAT. Le seul '
              'garde-fou est le seuil de salaire ; l\'affiliation réelle ne '
              'joue jamais. Un indépendant pour qui MINT a écrit '
              'q_has_pension_fund=false voit malgré tout ce montant. Le jour '
              'où la scène recevra le statut d\'emploi, ce test devra être '
              'RÉÉCRIT en « vaut zéro pour un indépendant » — et sa réécriture '
              'sera la preuve que le défaut est fermé.');
    });
  });
}
