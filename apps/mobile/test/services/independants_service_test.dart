import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/independants_service.dart';

/// Unit tests pour IndependantsService — Sprint S18 (Independants complet)
///
/// Teste les 5 calculateurs pour independants :
///   1. calculateAvsCotisations  — bareme progressif AVS/AI/APG
///   2. calculateIjm             — assurance perte de gain (IJM)
///   3. calculate3aIndependant   — plafonds 3a independant
///   4. calculateDividendeVsSalaire — comparaison dividende vs salaire
///   5. calculateLppVolontaire   — LPP volontaire
///
/// Base legale : LAVS, OPP3, LPP, LIFD, CO
void main() {
  // ════════════════════════════════════════════════════════════
  //  1. AVS COTISATIONS
  // ════════════════════════════════════════════════════════════

  group('IndependantsService - calculateAvsCotisations', () {
    test('revenu zero retourne cotisation zero', () {
      final result = IndependantsService.calculateAvsCotisations(0);
      expect(result.revenuNet, 0);
      expect(result.tauxEffectif, 0);
      expect(result.cotisationAnnuelle, 0);
      expect(result.cotisationMensuelle, 0);
      expect(result.differenceAnnuelle, 0);
      expect(result.tranchLabel, '-');
    });

    test('revenu negatif retourne cotisation zero', () {
      final result = IndependantsService.calculateAvsCotisations(-5000);
      expect(result.cotisationAnnuelle, 0);
      expect(result.tranchLabel, '-');
    });

    test('cotisation minimale de 530 CHF/an pour tres petit revenu', () {
      // Revenu de 5000 CHF -> taux 5.371% -> 268.55 < 530 minimum
      final result = IndependantsService.calculateAvsCotisations(5000);
      expect(result.cotisationAnnuelle, 530.0);
      expect(result.cotisationMensuelle, closeTo(530.0 / 12, 0.01));
    });

    test('premiere tranche (0-10100) applique taux 5.371%', () {
      final result = IndependantsService.calculateAvsCotisations(10000);
      // 10000 * 5.371% = 537.10 > 530 minimum
      expect(result.cotisationAnnuelle, closeTo(10000 * 0.05371, 0.01));
      expect(result.tranchLabel, contains('10\'100'));
    });

    test('tranche haute (60500+) applique taux plein 10.6%', () {
      final result = IndependantsService.calculateAvsCotisations(100000);
      expect(result.cotisationAnnuelle, closeTo(100000 * 0.106, 0.01));
      expect(result.tauxEffectif, closeTo(10.6, 0.1));
    });

    test('tranche intermediaire (37800-43200) applique taux 9.002%', () {
      final result = IndependantsService.calculateAvsCotisations(40000);
      expect(result.cotisationAnnuelle, closeTo(40000 * 0.09002, 0.01));
    });

    test('cotisation salarie est toujours 5.3% du revenu', () {
      final result = IndependantsService.calculateAvsCotisations(80000);
      expect(result.cotisationSalarie, closeTo(80000 * 0.053, 0.01));
    });

    test('difference annuelle = cotisation independant - cotisation salarie', () {
      final result = IndependantsService.calculateAvsCotisations(80000);
      expect(
        result.differenceAnnuelle,
        closeTo(result.cotisationAnnuelle - result.cotisationSalarie, 0.01),
      );
    });

    test('cotisation mensuelle = cotisation annuelle / 12', () {
      final result = IndependantsService.calculateAvsCotisations(60000);
      expect(
        result.cotisationMensuelle,
        closeTo(result.cotisationAnnuelle / 12, 0.01),
      );
    });
  });

  // ════════════════════════════════════════════════════════════
  //  2. IJM (ASSURANCE PERTE DE GAIN)
  // ════════════════════════════════════════════════════════════

  group('IndependantsService - calculateIjm', () {
    test('revenu zero retourne resultat vide', () {
      final result = IndependantsService.calculateIjm(0, 30, 30);
      expect(result.couverture, 0);
      expect(result.primeMensuelle, 0);
      expect(result.ageBandLabel, '-');
    });

    test('age hors limites (<18 ou >65) retourne resultat vide', () {
      final result17 = IndependantsService.calculateIjm(5000, 17, 30);
      expect(result17.couverture, 0);
      expect(result17.ageBandLabel, '-');

      final result66 = IndependantsService.calculateIjm(5000, 66, 30);
      expect(result66.couverture, 0);
    });

    test('couverture est 80% du revenu mensuel', () {
      final result = IndependantsService.calculateIjm(8000, 35, 30);
      expect(result.couverture, closeTo(8000 * 0.80, 0.01));
    });

    test('bande d age 18-30 avec delai carence 30j', () {
      final result = IndependantsService.calculateIjm(6000, 25, 30);
      expect(result.ageBandLabel, '18-30 ans');
      expect(result.rateFor1000, 3.50);
      expect(result.isHighRisk, false);
    });

    test('bande d age 51-60 est high risk', () {
      final result = IndependantsService.calculateIjm(8000, 55, 60);
      expect(result.ageBandLabel, '51-60 ans');
      expect(result.rateFor1000, 11.50);
      expect(result.isHighRisk, true);
    });

    test('delai carence invalide => default 30j', () {
      final result = IndependantsService.calculateIjm(6000, 30, 45);
      // 45 n'est pas dans [30, 60, 90], donc default a 30
      expect(result.delaiCarence, 30);
    });

    test('perte carence = revenu journalier * delai', () {
      final result = IndependantsService.calculateIjm(6000, 30, 90);
      final revenuJournalier = 6000 / 21.75;
      expect(result.perteCarence, closeTo(revenuJournalier * 90, 0.01));
    });

    test('prime basee sur 80% du revenu assure', () {
      final result = IndependantsService.calculateIjm(10000, 40, 30);
      // Prime = (revenu * 0.80 / 1000) * rate
      final expectedPrime = (10000 * 0.80 / 1000) * 5.0; // 31-40, 30j
      expect(result.primeMensuelle, closeTo(expectedPrime, 0.01));
      expect(result.primeAnnuelle, closeTo(expectedPrime * 12, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  3. PILIER 3A INDEPENDANT
  // ════════════════════════════════════════════════════════════

  group('IndependantsService - calculate3aIndependant', () {
    test('independant sans LPP : plafond = 20% du revenu, max 36288', () {
      final result = IndependantsService.calculate3aIndependant(
        100000,
        false,
        0.30,
      );
      // 20% de 100000 = 20000 < 36288
      expect(result.plafond, closeTo(20000, 0.01));
      expect(result.affilieLpp, false);
    });

    test('independant sans LPP : plafond plafonne a 36288', () {
      final result = IndependantsService.calculate3aIndependant(
        250000,
        false,
        0.30,
      );
      // 20% de 250000 = 50000 > 36288 => plafonne
      expect(result.plafond, closeTo(36288, 0.01));
    });

    test('independant avec LPP : plafond = 7258 (petit 3a)', () {
      final result = IndependantsService.calculate3aIndependant(
        100000,
        true,
        0.30,
      );
      expect(result.plafond, closeTo(7258, 0.01));
    });

    test('economie fiscale = plafond * taux marginal', () {
      final result = IndependantsService.calculate3aIndependant(
        80000,
        false,
        0.25,
      );
      // Plafond = 16000 (20% de 80000)
      expect(result.economieFiscale, closeTo(16000 * 0.25, 0.01));
    });

    test('avantage sur salarie positif pour independant sans LPP', () {
      final result = IndependantsService.calculate3aIndependant(
        120000,
        false,
        0.30,
      );
      // Plafond indep = 24000, plafond salarie = 7258
      // Avantage = (24000 - 7258) * 0.30
      expect(result.avantageSurSalarie, greaterThan(0));
    });

    test('revenu negatif => plafond zero', () {
      final result = IndependantsService.calculate3aIndependant(
        -5000,
        false,
        0.30,
      );
      expect(result.plafond, 0);
    });

    test('plafond salarie toujours egal a 7258', () {
      final result = IndependantsService.calculate3aIndependant(
        100000,
        false,
        0.30,
      );
      expect(result.plafondSalarie, closeTo(7258, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  4. DIVIDENDE VS SALAIRE
  // ════════════════════════════════════════════════════════════

  group('IndependantsService - calculateDividendeVsSalaire', () {
    test('benefice zero retourne resultat vide', () {
      final result = IndependantsService.calculateDividendeVsSalaire(
        0,
        60,
        0.30,
      );
      expect(result.benefice, 0);
      expect(result.chargeTotal, 0);
      expect(result.sensitivity, isEmpty);
    });

    test('100% salaire => pas de dividende', () {
      final result = IndependantsService.calculateDividendeVsSalaire(
        200000,
        100,
        0.30,
      );
      expect(result.partSalaire, closeTo(200000, 0.01));
      expect(result.partDividende, closeTo(0, 0.01));
      expect(result.chargeDividende, closeTo(0, 0.01));
    });

    test('requalification risk quand salaire < 60%', () {
      final result = IndependantsService.calculateDividendeVsSalaire(
        200000,
        50,
        0.30,
      );
      expect(result.requalificationRisk, true);
    });

    test('pas de requalification risk quand salaire >= 60%', () {
      final result = IndependantsService.calculateDividendeVsSalaire(
        200000,
        60,
        0.30,
      );
      expect(result.requalificationRisk, false);
    });

    test('sensitivity contient 11 points (0% a 100%, pas de 10%)', () {
      final result = IndependantsService.calculateDividendeVsSalaire(
        200000,
        60,
        0.30,
      );
      expect(result.sensitivity.length, 11);
      expect(result.sensitivity.first.partSalairePct, 0);
      expect(result.sensitivity.last.partSalairePct, 100);
    });

    test('charge dividende = 50% taxation (participation qualifiante)', () {
      final result = IndependantsService.calculateDividendeVsSalaire(
        200000,
        0, // 100% dividende
        0.30,
      );
      // Charge dividende = 200000 * 0.50 * 0.30 = 30000
      expect(result.chargeDividende, closeTo(200000 * 0.50 * 0.30, 0.01));
    });

    test('charge salaire inclut impot + AVS (12.5%)', () {
      final result = IndependantsService.calculateDividendeVsSalaire(
        200000,
        100, // 100% salaire
        0.30,
      );
      // Charge = 200000 * 0.30 (impot) + 200000 * 0.125 (AVS)
      final expectedCharge = 200000 * 0.30 + 200000 * 0.125;
      expect(result.chargeSalaire, closeTo(expectedCharge, 0.01));
    });

    test('economie >= 0 (optimal split vs tout salaire)', () {
      final result = IndependantsService.calculateDividendeVsSalaire(
        200000,
        60,
        0.30,
      );
      expect(result.economie, greaterThanOrEqualTo(0));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  5. LPP VOLONTAIRE
  // ════════════════════════════════════════════════════════════

  group('IndependantsService - calculateLppVolontaire', () {
    test('salaire coordonne = revenu - 26460 (deduction de coordination)', () {
      final result = IndependantsService.calculateLppVolontaire(
        80000,
        40,
        0.30,
      );
      // 80000 - 26460 = 53540
      expect(result.salaireCoordonne, closeTo(53540, 0.01));
    });

    test('salaire coordonne minimum = 3780 CHF', () {
      final result = IndependantsService.calculateLppVolontaire(
        20000, // < 26460
        35,
        0.30,
      );
      expect(result.salaireCoordonne, closeTo(3780, 0.01));
    });

    test('tranche d age 25-34 : taux 7%', () {
      final result = IndependantsService.calculateLppVolontaire(
        80000,
        30,
        0.30,
      );
      expect(result.tauxBonification, 0.07);
      expect(result.ageBracketLabel, '25-34 ans');
    });

    test('tranche d age 35-44 : taux 10%', () {
      final result = IndependantsService.calculateLppVolontaire(
        80000,
        40,
        0.30,
      );
      expect(result.tauxBonification, 0.10);
      expect(result.ageBracketLabel, '35-44 ans');
    });

    test('tranche d age 45-54 : taux 15%', () {
      final result = IndependantsService.calculateLppVolontaire(
        80000,
        50,
        0.30,
      );
      expect(result.tauxBonification, 0.15);
      expect(result.ageBracketLabel, '45-54 ans');
    });

    test('tranche d age 55-65 : taux 18%', () {
      final result = IndependantsService.calculateLppVolontaire(
        80000,
        60,
        0.30,
      );
      expect(result.tauxBonification, 0.18);
      expect(result.ageBracketLabel, '55-65 ans');
    });

    test('moins de 25 ans : taux 0%', () {
      final result = IndependantsService.calculateLppVolontaire(
        80000,
        23,
        0.30,
      );
      expect(result.tauxBonification, 0.0);
      expect(result.ageBracketLabel, 'Moins de 25 ans');
      expect(result.cotisationAnnuelle, 0);
    });

    test('cotisation annuelle = salaire coordonne * taux bonification', () {
      final result = IndependantsService.calculateLppVolontaire(
        80000,
        40,
        0.30,
      );
      final expectedCotisation = result.salaireCoordonne * 0.10;
      expect(result.cotisationAnnuelle, closeTo(expectedCotisation, 0.01));
    });

    test('economie fiscale = cotisation annuelle * taux marginal', () {
      final result = IndependantsService.calculateLppVolontaire(
        80000,
        40,
        0.30,
      );
      expect(
        result.economieFiscale,
        closeTo(result.cotisationAnnuelle * 0.30, 0.01),
      );
    });

    test('projection avec LPP > projection sans LPP', () {
      final result = IndependantsService.calculateLppVolontaire(
        80000,
        40,
        0.30,
      );
      expect(result.projectionAvecLpp, greaterThan(result.projectionSansLpp));
    });

    test('salaire coordonne plafonne a 63540 CHF', () {
      final result = IndependantsService.calculateLppVolontaire(
        200000, // 200000 - 26460 = 173540 > 63540
        40,
        0.30,
      );
      expect(result.salaireCoordonne, closeTo(63540, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  group('IndependantsService - formatChf', () {
    test('formate avec apostrophe suisse', () {
      final formatted = IndependantsService.formatChf(1234567);
      expect(formatted, contains("1'234'567"));
      expect(formatted, startsWith('CHF'));
    });
  });
}
