import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/debt_prevention_service.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════
  //  A. DebtRatioCalculator tests
  // ═══════════════════════════════════════════════════════════════════

  group('DebtRatioCalculator', () {
    test('ratio below 15% returns vert risk level', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 6000,
        chargesDetteMensuelles: 500, // 8.3%
        loyer: 1500,
      );
      expect(result.ratio, closeTo(8.33, 0.1));
      expect(result.niveau, DebtRiskLevel.vert);
    });

    test('ratio between 15% and 30% returns orange risk level', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 5000,
        chargesDetteMensuelles: 1000, // 20%
        loyer: 1200,
      );
      expect(result.ratio, closeTo(20.0, 0.1));
      expect(result.niveau, DebtRiskLevel.orange);
    });

    test('ratio at or above 30% returns rouge risk level', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 5000,
        chargesDetteMensuelles: 1500, // 30%
        loyer: 1000,
      );
      expect(result.ratio, closeTo(30.0, 0.1));
      expect(result.niveau, DebtRiskLevel.rouge);
    });

    test('zero income returns 0% ratio', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 0,
        chargesDetteMensuelles: 500,
        loyer: 1000,
      );
      expect(result.ratio, 0.0);
    });

    test('zero debt returns 0% ratio and vert level', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 6000,
        chargesDetteMensuelles: 0,
        loyer: 1500,
      );
      expect(result.ratio, 0.0);
      expect(result.niveau, DebtRiskLevel.vert);
    });

    test('minimum vital for celibataire is 1200 CHF', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 4000,
        chargesDetteMensuelles: 0,
        loyer: 1500,
        estCelibataire: true,
        nombreEnfants: 0,
      );
      expect(result.minimumVital, 1200.0);
    });

    test('minimum vital for couple is 1750 CHF', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 6000,
        chargesDetteMensuelles: 0,
        loyer: 1500,
        estCelibataire: false,
        nombreEnfants: 0,
      );
      expect(result.minimumVital, 1750.0);
    });

    test('minimum vital includes 400 CHF per child', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 6000,
        chargesDetteMensuelles: 0,
        loyer: 1500,
        estCelibataire: true,
        nombreEnfants: 3,
      );
      // 1200 + 3 * 400 = 2400
      expect(result.minimumVital, 2400.0);
    });

    test('marge disponible computed correctly', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 6000,
        chargesDetteMensuelles: 500,
        loyer: 1500,
        autresChargesFixes: 200,
      );
      // 6000 - 500 - 1500 - 200 = 3800
      expect(result.margeDisponible, closeTo(3800.0, 0.01));
    });

    test('minimum vital menace when marge < minimum vital', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 3000,
        chargesDetteMensuelles: 500,
        loyer: 1500,
        autresChargesFixes: 200,
        estCelibataire: true,
      );
      // marge = 3000 - 500 - 1500 - 200 = 800
      // minimum vital celibataire = 1200
      expect(result.minimumVitalMenace, isTrue);
    });

    test('minimum vital NOT menace when marge >= minimum vital', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 8000,
        chargesDetteMensuelles: 500,
        loyer: 1500,
        autresChargesFixes: 200,
        estCelibataire: true,
      );
      // marge = 8000 - 500 - 1500 - 200 = 5800
      expect(result.minimumVitalMenace, isFalse);
    });

    test('recommandations for vert contain 2 items', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 10000,
        chargesDetteMensuelles: 500,
        loyer: 1500,
      );
      expect(result.niveau, DebtRiskLevel.vert);
      expect(result.recommandations.length, greaterThanOrEqualTo(2));
    });

    test('recommandations for orange contain 3 items', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 5000,
        chargesDetteMensuelles: 1000,
        loyer: 1000,
      );
      expect(result.niveau, DebtRiskLevel.orange);
      expect(result.recommandations.length, greaterThanOrEqualTo(3));
    });

    test('recommandations for rouge contain reference to professional help', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 4000,
        chargesDetteMensuelles: 2000,
        loyer: 1000,
      );
      expect(result.niveau, DebtRiskLevel.rouge);
      expect(
        result.recommandations.any((r) => r.contains('aide professionnelle')),
        isTrue,
      );
    });

    test('minimum vital menace inserts ALERTE at top of recommandations', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 2500,
        chargesDetteMensuelles: 800,
        loyer: 1200,
        autresChargesFixes: 200,
        estCelibataire: true,
      );
      // marge = 2500 - 800 - 1200 - 200 = 300 < 1200
      expect(result.minimumVitalMenace, isTrue);
      expect(result.recommandations.first, contains('ALERTE'));
      expect(result.recommandations.first, contains('LP art. 93'));
    });

    test('disclaimer is present and mentions pedagogique and LP art. 93', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 5000,
        chargesDetteMensuelles: 500,
        loyer: 1500,
      );
      expect(result.disclaimer, isNotEmpty);
      expect(result.disclaimer, contains('pedagogique'));
      expect(result.disclaimer, contains('LP art. 93'));
      expect(result.disclaimer, contains('ne constitue pas'));
    });

    test('premierEclairage contains ratio value and text', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: 5000,
        chargesDetteMensuelles: 1000,
        loyer: 1200,
      );
      expect(result.premierEclairage.montant, closeTo(20.0, 0.1));
      expect(result.premierEclairage.texte, contains('Ratio dette'));
      expect(result.premierEclairage.niveau, DebtRiskLevel.orange);
    });

    test('negative inputs are clamped to 0', () {
      final result = DebtRatioCalculator.calculate(
        revenusMensuels: -1000,
        chargesDetteMensuelles: -500,
        loyer: -200,
      );
      expect(result.ratio, 0.0);
      expect(result.margeDisponible, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  //  B. RepaymentPlanner tests
  // ═══════════════════════════════════════════════════════════════════

  group('RepaymentPlanner', () {
    test('empty debt list returns 0 months for both strategies', () {
      final result = RepaymentPlanner.plan(
        dettes: [],
        budgetMensuelRemboursement: 500,
      );
      expect(result.avalanche.moisJusquaLiberation, 0);
      expect(result.bouleDeNeige.moisJusquaLiberation, 0);
      expect(result.avalanche.interetsTotaux, 0);
    });

    test('single debt is repaid correctly', () {
      final result = RepaymentPlanner.plan(
        dettes: [
          const Debt(
            nom: 'Credit conso',
            montant: 5000,
            tauxAnnuel: 0.10,
            mensualiteMin: 100,
          ),
        ],
        budgetMensuelRemboursement: 500,
      );
      // Both strategies identical for single debt
      expect(result.avalanche.moisJusquaLiberation,
          result.bouleDeNeige.moisJusquaLiberation);
      expect(result.avalanche.moisJusquaLiberation, greaterThan(0));
      expect(result.avalanche.totalPaye, greaterThan(5000));
    });

    test('avalanche strategy pays less total interest than snowball', () {
      final result = RepaymentPlanner.plan(
        dettes: [
          const Debt(
            nom: 'Credit conso',
            montant: 10000,
            tauxAnnuel: 0.15,
            mensualiteMin: 100,
          ),
          const Debt(
            nom: 'Petit credit',
            montant: 2000,
            tauxAnnuel: 0.05,
            mensualiteMin: 50,
          ),
        ],
        budgetMensuelRemboursement: 500,
      );
      expect(
        result.avalanche.interetsTotaux,
        lessThanOrEqualTo(result.bouleDeNeige.interetsTotaux),
      );
    });

    test('economieInterets is positive or zero', () {
      final result = RepaymentPlanner.plan(
        dettes: [
          const Debt(
            nom: 'A',
            montant: 5000,
            tauxAnnuel: 0.12,
            mensualiteMin: 100,
          ),
          const Debt(
            nom: 'B',
            montant: 3000,
            tauxAnnuel: 0.08,
            mensualiteMin: 50,
          ),
        ],
        budgetMensuelRemboursement: 600,
      );
      expect(result.economieInterets, greaterThanOrEqualTo(0));
    });

    test('timeline has correct number of months', () {
      final result = RepaymentPlanner.plan(
        dettes: [
          const Debt(
            nom: 'Credit',
            montant: 1000,
            tauxAnnuel: 0.10,
            mensualiteMin: 100,
          ),
        ],
        budgetMensuelRemboursement: 500,
      );
      expect(
        result.avalanche.timeline.length,
        result.avalanche.moisJusquaLiberation,
      );
    });

    test('premierEclairage has risk level based on months to liberation', () {
      // Small debt, fast repayment -> vert
      final fastResult = RepaymentPlanner.plan(
        dettes: [
          const Debt(
            nom: 'Petit',
            montant: 1000,
            tauxAnnuel: 0.05,
            mensualiteMin: 100,
          ),
        ],
        budgetMensuelRemboursement: 500,
      );
      expect(fastResult.premierEclairage.niveau, DebtRiskLevel.vert);
    });

    test('disclaimer is present and mentions pedagogique', () {
      final result = RepaymentPlanner.plan(
        dettes: [
          const Debt(
            nom: 'Credit',
            montant: 5000,
            tauxAnnuel: 0.10,
            mensualiteMin: 100,
          ),
        ],
        budgetMensuelRemboursement: 500,
      );
      expect(result.disclaimer, isNotEmpty);
      expect(result.disclaimer, contains('pedagogique'));
      expect(result.disclaimer, contains('sp\u00e9cialiste'));
    });

    test('budget lower than sum of minimums uses effective minimum', () {
      final result = RepaymentPlanner.plan(
        dettes: [
          const Debt(
            nom: 'A',
            montant: 5000,
            tauxAnnuel: 0.10,
            mensualiteMin: 200,
          ),
          const Debt(
            nom: 'B',
            montant: 3000,
            tauxAnnuel: 0.08,
            mensualiteMin: 150,
          ),
        ],
        budgetMensuelRemboursement: 100, // lower than 200+150=350
      );
      // The planner should use the sum of mins as effective budget
      expect(result.avalanche.moisJusquaLiberation, greaterThan(0));
      expect(result.avalanche.totalPaye, greaterThan(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  //  C. DebtHelpResources tests
  // ═══════════════════════════════════════════════════════════════════

  group('DebtHelpResources', () {
    test('getResources without canton returns 2 national resources', () {
      final resources = DebtHelpResources.getResources();
      expect(resources.length, 2);
      expect(resources.every((r) => r.isNational), isTrue);
    });

    test('getResources with valid canton returns 3 resources', () {
      final resources = DebtHelpResources.getResources(canton: 'GE');
      expect(resources.length, 3);
      expect(resources.last.isNational, isFalse);
    });

    test('getResources with unknown canton returns only national', () {
      final resources = DebtHelpResources.getResources(canton: 'XX');
      expect(resources.length, 2);
    });

    test('getCantonalResource returns correct resource', () {
      final resource = DebtHelpResources.getCantonalResource('VD');
      expect(resource, isNotNull);
      expect(resource!.nom, contains('Vaud'));
    });

    test('getCantonalResource with lowercase still works', () {
      final resource = DebtHelpResources.getCantonalResource('ge');
      expect(resource, isNotNull);
      expect(resource!.nom, contains('Geneve'));
    });

    test('getCantonalResource returns null for unknown canton', () {
      final resource = DebtHelpResources.getCantonalResource('XX');
      expect(resource, isNull);
    });

    test('cantons list is sorted alphabetically', () {
      final cantons = DebtHelpResources.cantons;
      expect(cantons, isNotEmpty);
      final sorted = List<String>.from(cantons)..sort();
      expect(cantons, sorted);
    });

    test('all 26 cantons have a resource', () {
      final cantons = DebtHelpResources.cantons;
      expect(cantons.length, 26);
    });

    test('national resources include Dettes Conseils Suisse', () {
      final resources = DebtHelpResources.getResources();
      expect(
        resources.any((r) => r.nom.contains('Dettes Conseils Suisse')),
        isTrue,
      );
    });

    test('national resources include Caritas', () {
      final resources = DebtHelpResources.getResources();
      expect(
        resources.any((r) => r.nom.contains('Caritas')),
        isTrue,
      );
    });

    test('national resources have telephone numbers', () {
      final resources = DebtHelpResources.getResources();
      for (final r in resources) {
        expect(r.telephone, isNotNull);
        expect(r.telephone, isNotEmpty);
      }
    });
  });
}
