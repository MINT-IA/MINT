// ────────────────────────────────────────────────────────────
//  RACHAT ÉCHELONNÉ — fenêtre art. 79b al. 3 LPP (beads MINT_nosync-a6e)
//
//  Le flux LIVE /rachat-lpp créditait economieAnnuelle pour CHAQUE tranche
//  du plan sans modéliser la reprise fiscale : un retrait en CAPITAL dans
//  les 3 ans qui suivent un rachat entraîne la reprise de la déduction par
//  l'AFC (ATF 142 II 399). La logique correcte existait (fix -okl,
//  LppBuybackAdvancedSimulator) mais son widget n'était instancié nulle
//  part — l'utilisateur réel ne la voyait jamais.
//
//  Convention temporelle IDENTIQUE à -okl (vérifiée arithmétiquement par
//  le panel -a6e : délai effectif -okl = 65 − ageTranche, retrait au 65e
//  anniversaire) : reprise ssi délai < 3 ; un rachat à exactement 3 ans
//  est AUTORISÉ (art. 79b al. 3 : « avant l'échéance d'un délai de trois
//  ans »). La version initiale ajoutait +1 et sous-avertissait la tranche
//  la plus risquée — attrapé par le panel adversarial.
// ────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart';

RachatEchelonneResult _run({int age = 60, int horizon = 5}) =>
    RachatEchelonneSimulator.compare(
      avoirActuel: 300000,
      rachatMax: 100000,
      revenuImposable: 140000,
      canton: 'VD',
      civilStatus: 'single',
      horizon: horizon,
      age: age,
    );

void main() {
  group('fenêtre 79b al. 3 — scénario retrait capital à 65 ans', () {
    test('tranches à moins de 3 ans du retrait -> fenetre79b, économie reprise',
        () {
      // Âge 60, horizon 5 : tranches versées à 60,61,62,63,64.
      // Délais vs 65e anniversaire : 5,4,3,2,1 -> les tranches versées à
      // 63 (délai 2) et 64 (délai 1) sont reprises ; 62 (délai 3) passe
      // (délai échu = autorisé).
      final r = _run();
      expect(r.yearlyPlan.length, 5);
      expect(
        r.yearlyPlan.map((y) => y.fenetre79b).toList(),
        [false, false, false, true, true],
        reason: 'délai = 65 - ageTranche ; reprise ssi < 3, '
            'exactement 3 ans = autorisé (convention -okl vérifiée)',
      );
      expect(r.tranchesEnFenetre, 2);
    });

    test('économie conditionnelle = total moins les tranches en fenêtre', () {
      final r = _run();
      final reprises = r.yearlyPlan
          .where((y) => y.fenetre79b)
          .fold<double>(0, (s, y) => s + y.economieFiscale);
      expect(reprises, greaterThan(0),
          reason: 'le scénario contient des tranches reprises');
      expect(
        r.economieEchelonneSiCapital,
        closeTo(r.economieEchelonneTotal - reprises, 0.01),
      );
      expect(r.economieEchelonneSiCapital, lessThan(r.economieEchelonneTotal));
    });

    test('plan entièrement hors fenêtre -> aucun marquage, totaux égaux', () {
      // Âge 40, horizon 5 : dernière tranche à 44, délai 21 ans.
      final r = _run(age: 40);
      expect(r.yearlyPlan.any((y) => y.fenetre79b), isFalse);
      expect(r.tranchesEnFenetre, 0);
      expect(
        r.economieEchelonneSiCapital,
        closeTo(r.economieEchelonneTotal, 0.01),
      );
      expect(r.blocEnFenetre, isFalse);
      expect(r.economieBlocSiCapital, closeTo(r.economieBlocTotal, 0.01));
    });

    test('plan traversant la retraite -> tranches post-65 reprises aussi', () {
      // Âge 63, horizon 5 : tranches à 63,64,65,66,67 — délais 2,1,0,-1,-2 :
      // toutes en fenêtre (un rachat après le retrait n'existe plus).
      final r = _run(age: 63);
      expect(
        r.yearlyPlan.map((y) => y.fenetre79b).toList(),
        [true, true, true, true, true],
      );
      expect(r.tranchesEnFenetre, 5);
      expect(r.economieEchelonneSiCapital, closeTo(0, 0.01));
    });

    test('symétrie bloc : le rachat en bloc à 63 ans est repris aussi', () {
      // Panel -a6e point 2 : sans economieBlocSiCapital, la carte bloc
      // gardait son économie pleine pendant que l'étalé était marqué —
      // présentation incomplète = orientation de fait.
      final r = _run(age: 63);
      expect(r.blocEnFenetre, isTrue,
          reason: 'bloc versé année 1 à 63 ans : délai 2 < 3');
      expect(r.economieBlocSiCapital, 0.0);

      final r62 = _run(age: 62);
      expect(r62.blocEnFenetre, isFalse,
          reason: 'bloc à 62 ans : délai 3, échu -> autorisé');
      expect(r62.economieBlocSiCapital, closeTo(r62.economieBlocTotal, 0.01));
    });

    test('âge >= 65 : scénario capital à 65 ans sans objet, aucun marquage',
        () {
      // Panel -a6e point 3 : à 66-70 ans, afficher « si retrait à 65 ans »
      // daterait le scénario dans le passé — factuellement impossible.
      final r = _run(age: 67);
      expect(r.yearlyPlan.any((y) => y.fenetre79b), isFalse);
      expect(r.tranchesEnFenetre, 0);
      expect(r.blocEnFenetre, isFalse);
      expect(
        r.economieEchelonneSiCapital,
        closeTo(r.economieEchelonneTotal, 0.01),
      );
    });
  });
}
