import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/pillar_3a_deep_service.dart';

/// Unit tests pour Pillar 3a Deep Service — Sprint S16 (3a Deep)
///
/// Teste les 3 simulateurs pedagogiques :
///   A. StaggeredWithdrawalSimulator — retrait echelonne multi-comptes
///   B. RealReturnCalculator         — rendement reel avec taux marginal
///   C. ProviderComparator           — comparateur fintech/banque/assurance
///
/// Base legale : OPP3, LIFD art. 38 (imposition retrait capital prevoyance)
void main() {
  // ════════════════════════════════════════════════════════════
  //  A. RETRAIT ECHELONNE
  // ════════════════════════════════════════════════════════════

  group('StaggeredWithdrawalSimulator - impot progressif', () {
    test('impot retrait en bloc applique brackets progressifs', () {
      // 200'000 CHF a ZH (taux base 6.5%)
      // Tranche 0-100k : 100000 * 0.065 * 1.0 = 6500
      // Tranche 100k-200k : 100000 * 0.065 * 1.15 = 7475
      // Total = 13975
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 200000,
        nbComptes: 1,
        canton: 'ZH',
        revenuImposable: 80000,
        ageRetraitDebut: 64,
        ageRetraitFin: 65,
      );
      expect(result.impotBloc, closeTo(13975, 1.0));
    });

    test('retrait echelonne reduit l impot total', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 300000,
        nbComptes: 3,
        canton: 'VD',
        revenuImposable: 80000,
        ageRetraitDebut: 62,
        ageRetraitFin: 65,
      );
      expect(result.economie, greaterThan(0));
      expect(result.impotEchelonne, lessThan(result.impotBloc));
    });

    test('plan annuel a le bon nombre d entrees', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 250000,
        nbComptes: 5,
        canton: 'GE',
        revenuImposable: 90000,
        ageRetraitDebut: 60,
        ageRetraitFin: 65,
      );
      expect(result.planAnnuel.length, 5);
      // Chaque retrait = 50000
      for (final plan in result.planAnnuel) {
        expect(plan.montantRetire, closeTo(50000, 0.01));
      }
    });

    test('nombre de comptes limites par duree echelonnement', () {
      // ageDebut=64, ageFin=65 => duree = 2 ans
      // 5 comptes demandes mais max 2 possibles
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 200000,
        nbComptes: 5,
        canton: 'ZH',
        revenuImposable: 80000,
        ageRetraitDebut: 64,
        ageRetraitFin: 65,
      );
      expect(result.planAnnuel.length, 2);
    });

    test('nombre optimal de comptes maximise l economie', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 400000,
        nbComptes: 5,
        canton: 'VD',
        revenuImposable: 100000,
        ageRetraitDebut: 60,
        ageRetraitFin: 65,
      );
      expect(result.nbComptesOptimal, greaterThanOrEqualTo(1));
      expect(result.nbComptesOptimal, lessThanOrEqualTo(5));
    });

    test('canton ZG a un taux plus bas que VD', () {
      final resultZG = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 200000,
        nbComptes: 1,
        canton: 'ZG',
        revenuImposable: 80000,
        ageRetraitDebut: 64,
        ageRetraitFin: 65,
      );
      final resultVD = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 200000,
        nbComptes: 1,
        canton: 'VD',
        revenuImposable: 80000,
        ageRetraitDebut: 64,
        ageRetraitFin: 65,
      );
      expect(resultZG.impotBloc, lessThan(resultVD.impotBloc));
    });

    test('avoir zero retourne impot zero', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 0,
        nbComptes: 3,
        canton: 'ZH',
        revenuImposable: 80000,
        ageRetraitDebut: 62,
        ageRetraitFin: 65,
      );
      expect(result.impotBloc, 0);
      expect(result.impotEchelonne, 0);
    });

    test('disclaimer present et mentionne specialiste', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 200000,
        nbComptes: 3,
        canton: 'ZH',
        revenuImposable: 80000,
        ageRetraitDebut: 62,
        ageRetraitFin: 65,
      );
      expect(result.disclaimer, contains('specialiste'));
      expect(result.disclaimer, contains('OPP3'));
    });

    test('chiffre choc positif quand economie > 0', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 300000,
        nbComptes: 3,
        canton: 'VD',
        revenuImposable: 80000,
        ageRetraitDebut: 62,
        ageRetraitFin: 65,
      );
      expect(result.chiffreChoc.isPositive, true);
      expect(result.chiffreChoc.montant, greaterThan(0));
    });
  });

  group('StaggeredWithdrawalSimulator - brackets progressifs detailles', () {
    test('montant > 500k applique bracket 500k-1M (mult 1.50)', () {
      // 600000 CHF a ZH (6.5%)
      // 0-100k : 100000 * 0.065 * 1.0  = 6500
      // 100k-200k: 100000 * 0.065 * 1.15 = 7475
      // 200k-500k: 300000 * 0.065 * 1.30 = 25350
      // 500k-600k: 100000 * 0.065 * 1.50 = 9750
      // Total = 49075
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 600000,
        nbComptes: 1,
        canton: 'ZH',
        revenuImposable: 80000,
        ageRetraitDebut: 65,
        ageRetraitFin: 65,
      );
      expect(result.impotBloc, closeTo(49075, 1.0));
    });

    test('montant net = montant retire - impot estime', () {
      final result = StaggeredWithdrawalSimulator.simulate(
        avoirTotal: 150000,
        nbComptes: 3,
        canton: 'BE',
        revenuImposable: 70000,
        ageRetraitDebut: 62,
        ageRetraitFin: 65,
      );
      for (final plan in result.planAnnuel) {
        expect(
          plan.montantNet,
          closeTo(plan.montantRetire - plan.impotEstime, 0.01),
        );
      }
    });

    test('liste des cantons contient 26 cantons', () {
      expect(StaggeredWithdrawalSimulator.cantons.length, 26);
      expect(StaggeredWithdrawalSimulator.cantons, contains('ZH'));
      expect(StaggeredWithdrawalSimulator.cantons, contains('GE'));
      expect(StaggeredWithdrawalSimulator.cantons, contains('TI'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  B. RENDEMENT REEL
  // ════════════════════════════════════════════════════════════

  group('RealReturnCalculator', () {
    test('capital final 3a > total des versements (rendement positif)', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.045,
        fraisGestion: 0.0039,
        dureeAnnees: 20,
      );
      expect(result.capitalFinal3a, greaterThan(result.totalVersements));
    });

    test('economie fiscale totale = versement * taux marginal * duree', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 10,
      );
      expect(
        result.economieFiscaleTotale,
        closeTo(7258 * 0.30 * 10, 0.01),
      );
    });

    test('gain vs epargne positif (3a + fiscal > epargne classique)', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 20,
      );
      expect(result.gainVsEpargne, greaterThan(0));
    });

    test('rendement reel > rendement nominal (inclut avantage fiscal)', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.35,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 25,
      );
      expect(result.rendementReel, greaterThan(result.rendementNominal));
    });

    test('capital epargne classique utilise taux 1.5%', () {
      // Pour 1 annee : capital = versement * (1 + 0.015)
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 10000,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 1,
      );
      expect(
        result.capitalFinalEpargne,
        closeTo(10000 * 1.015, 0.01),
      );
    });

    test('total versements = versement annuel * duree', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 15,
      );
      expect(result.totalVersements, closeTo(7258 * 15, 0.01));
    });

    test('disclaimer mentionne OPP3 et specialiste', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 10,
      );
      expect(result.disclaimer, contains('OPP3'));
      expect(result.disclaimer, contains('specialiste'));
    });

    test('chiffre choc positif quand gain vs epargne > 0', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 7258,
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 20,
      );
      expect(result.chiffreChoc.isPositive, true);
    });

    test('versement plafonne a 36288 (plafond sans LPP)', () {
      final result = RealReturnCalculator.calculate(
        versementAnnuel: 50000, // > 36288
        tauxMarginal: 0.30,
        rendementBrut: 0.04,
        fraisGestion: 0.004,
        dureeAnnees: 10,
      );
      // Total versements = 36288 * 10
      expect(result.totalVersements, closeTo(36288 * 10, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  C. COMPARATEUR PROVIDERS
  // ════════════════════════════════════════════════════════════

  group('ProviderComparator', () {
    test('compare retourne 5 providers', () {
      final result = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.equilibre,
      );
      expect(result.providers.length, 5);
    });

    test('fintech a un rendement superieur a banque classique', () {
      final result = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.equilibre,
      );
      final finpension = result.providers.firstWhere(
        (p) => p.provider.nom == 'Finpension',
      );
      final banque = result.providers.firstWhere(
        (p) => p.provider.type == 'banque',
      );
      expect(finpension.capitalFinal, greaterThan(banque.capitalFinal));
    });

    test('assurance 3a a un warning pour les jeunes (< 35 ans)', () {
      final result = ProviderComparator.compare(
        age: 28,
        versementAnnuel: 7258,
        duree: 30,
        profilRisque: ProfilRisque.equilibre,
      );
      final assurance = result.providers.firstWhere(
        (p) => p.provider.type == 'assurance',
      );
      expect(assurance.hasWarning, true);
      expect(assurance.warningMessage, isNotNull);
    });

    test('pas de warning assurance pour les 35+ ans', () {
      final result = ProviderComparator.compare(
        age: 40,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.equilibre,
      );
      final assurance = result.providers.firstWhere(
        (p) => p.provider.type == 'assurance',
      );
      expect(assurance.hasWarning, false);
    });

    test('difference max > 0 entre meilleur et pire provider', () {
      final result = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 25,
        profilRisque: ProfilRisque.dynamique,
      );
      expect(result.differenceMax, greaterThan(0));
    });

    test('profil prudent a un rendement inferieur a dynamique', () {
      final prudent = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.prudent,
      );
      final dynamique = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.dynamique,
      );
      // Finpension capital should be higher in dynamique
      final finpPrudent = prudent.providers.firstWhere(
        (p) => p.provider.nom == 'Finpension',
      );
      final finpDynamique = dynamique.providers.firstWhere(
        (p) => p.provider.nom == 'Finpension',
      );
      expect(
        finpDynamique.capitalFinal,
        greaterThan(finpPrudent.capitalFinal),
      );
    });

    test('disclaimer mentionne MINT n est pas intermediaire', () {
      final result = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.equilibre,
      );
      expect(result.disclaimer, contains('MINT'));
      expect(result.disclaimer, contains('specialiste'));
    });

    test('assurance a badge WARNING', () {
      final result = ProviderComparator.compare(
        age: 30,
        versementAnnuel: 7258,
        duree: 20,
        profilRisque: ProfilRisque.equilibre,
      );
      final assurance = result.providers.firstWhere(
        (p) => p.provider.type == 'assurance',
      );
      expect(assurance.badge, 'WARNING');
    });
  });
}
