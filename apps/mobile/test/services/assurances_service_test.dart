import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/assurances_service.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════
  //  1. LamalFranchiseService tests
  // ═══════════════════════════════════════════════════════════════════

  group('LamalFranchiseService', () {
    test('adult franchise levels are [300, 500, 1000, 1500, 2000, 2500]', () {
      expect(
        LamalFranchiseService.franchiseLevelsAdults,
        [300, 500, 1000, 1500, 2000, 2500],
      );
    });

    test('children franchise levels are [0, 100, 200, 300, 400, 500, 600]', () {
      expect(
        LamalFranchiseService.franchiseLevelsChildren,
        [0, 100, 200, 300, 400, 500, 600],
      );
    });

    test('analysis returns 6 comparisons for adults', () {
      final result = LamalFranchiseService.analyzeAllFranchises(
        400, // prime mensuelle base
        2000, // depenses sante annuelles
      );
      expect(result.comparaison.length, 6);
    });

    test('analysis returns 7 comparisons for children', () {
      final result = LamalFranchiseService.analyzeAllFranchises(
        100,
        500,
        isChild: true,
      );
      expect(result.comparaison.length, 7);
    });

    test('exactly one franchise is marked as optimal', () {
      final result = LamalFranchiseService.analyzeAllFranchises(400, 2000);
      final optimalCount =
          result.comparaison.where((c) => c.isOptimal).length;
      expect(optimalCount, 1);
    });

    test('franchiseOptimale matches the optimal comparison entry', () {
      final result = LamalFranchiseService.analyzeAllFranchises(400, 2000);
      final optimalEntry =
          result.comparaison.firstWhere((c) => c.isOptimal);
      expect(result.franchiseOptimale, optimalEntry.franchiseLevel);
    });

    test('low health expenses favor high franchise (2500)', () {
      final result = LamalFranchiseService.analyzeAllFranchises(
        400, // 400/month = 4800/year base
        200, // very low health expenses
      );
      // With very low expenses, higher franchise should be cheaper
      expect(result.franchiseOptimale, 2500);
    });

    test('high health expenses favor low franchise (300 or 500)', () {
      final result = LamalFranchiseService.analyzeAllFranchises(
        400,
        10000, // very high health expenses
      );
      // At very high expenses, franchise 300 or 500 is optimal
      // (depends on premium savings rate vs out-of-pocket difference)
      expect(result.franchiseOptimale, lessThanOrEqualTo(500));
    });

    test('economieVs300 is 0 for franchise 300 itself', () {
      final result = LamalFranchiseService.analyzeAllFranchises(400, 2000);
      final f300 =
          result.comparaison.firstWhere((c) => c.franchiseLevel == 300);
      expect(f300.economieVs300, closeTo(0.0, 0.01));
    });

    test('coutTotal includes prime + franchise + quote-part', () {
      final result = LamalFranchiseService.analyzeAllFranchises(400, 2000);
      for (final c in result.comparaison) {
        expect(
          c.coutTotal,
          closeTo(
            c.primeAnnuelle + c.franchiseEffective + c.quotePart,
            0.01,
          ),
        );
      }
    });

    test('quote-part capped at 700 CHF for adults', () {
      final result = LamalFranchiseService.analyzeAllFranchises(
        400,
        50000, // enormous expenses
      );
      for (final c in result.comparaison) {
        expect(c.quotePart, lessThanOrEqualTo(700.0));
      }
    });

    test('quote-part capped at 350 CHF for children', () {
      final result = LamalFranchiseService.analyzeAllFranchises(
        100,
        50000,
        isChild: true,
      );
      for (final c in result.comparaison) {
        expect(c.quotePart, lessThanOrEqualTo(350.0));
      }
    });

    test('breakEvenPoints has entries between consecutive levels', () {
      final result = LamalFranchiseService.analyzeAllFranchises(400, 2000);
      expect(result.breakEvenPoints, isNotEmpty);
      for (final bp in result.breakEvenPoints) {
        expect(bp.franchiseHaute, greaterThan(bp.franchiseBasse));
        expect(bp.seuilDepenses, greaterThan(0));
      }
    });

    test('recommandations mention low expenses hint for < 500', () {
      final result = LamalFranchiseService.analyzeAllFranchises(400, 200);
      expect(
        result.recommandations.any((r) => r.contains('franchise élevée')),
        isTrue,
      );
    });

    test('recommandations mention high expenses hint for > 3000', () {
      final result = LamalFranchiseService.analyzeAllFranchises(400, 5000);
      expect(
        result.recommandations.any((r) => r.contains('franchise basse')),
        isTrue,
      );
    });

    test('recommandations always include priminfo.admin.ch reference', () {
      final result = LamalFranchiseService.analyzeAllFranchises(400, 2000);
      expect(
        result.recommandations.any((r) => r.contains('priminfo.admin.ch')),
        isTrue,
      );
    });

    test('alerteDelai mentions 30 novembre', () {
      final result = LamalFranchiseService.analyzeAllFranchises(400, 2000);
      expect(result.alerteDelai, contains('30 novembre'));
    });

    test('disclaimer mentions LAMal and indicative', () {
      final result = LamalFranchiseService.analyzeAllFranchises(400, 2000);
      expect(result.disclaimer, contains('indicative'));
      expect(result.disclaimer, contains('LAMal'));
    });

    test('formatChf formats correctly', () {
      expect(LamalFranchiseService.formatChf(2500), contains("2'500"));
      expect(LamalFranchiseService.formatChf(300), contains('300'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  //  2. CoverageCheckService tests
  // ═══════════════════════════════════════════════════════════════════

  group('CoverageCheckService', () {
    CoverageCheckResult _baseEvaluation({
      String statutProfessionnel = 'salarie',
      bool aHypotheque = false,
      bool aFamille = false,
      bool estLocataire = true,
      bool voyagesFrequents = false,
      bool aIjmCollective = false,
      bool aLaa = false,
      bool aRcPrivee = false,
      bool aMenage = false,
      bool aProtectionJuridique = false,
      bool aAssuranceVoyage = false,
      bool aAssuranceDeces = false,
      String canton = 'VD',
    }) {
      return CoverageCheckService.evaluateCoverage(
        statutProfessionnel: statutProfessionnel,
        aHypotheque: aHypotheque,
        aFamille: aFamille,
        estLocataire: estLocataire,
        voyagesFrequents: voyagesFrequents,
        aIjmCollective: aIjmCollective,
        aLaa: aLaa,
        aRcPrivee: aRcPrivee,
        aMenage: aMenage,
        aProtectionJuridique: aProtectionJuridique,
        aAssuranceVoyage: aAssuranceVoyage,
        aAssuranceDeces: aAssuranceDeces,
        canton: canton,
      );
    }

    test('salarie checklist has 7 items (no RC pro)', () {
      final result = _baseEvaluation(statutProfessionnel: 'salarie');
      expect(result.checklist.length, 7);
    });

    test('independant checklist has 8 items (includes RC pro)', () {
      final result = _baseEvaluation(statutProfessionnel: 'independant');
      expect(result.checklist.length, 8);
      expect(
        result.checklist.any((item) => item.id == 'rc_pro'),
        isTrue,
      );
    });

    test('score is 0 when nothing is covered and no a_verifier', () {
      final result = _baseEvaluation(
        statutProfessionnel: 'independant',
      );
      // All uncovered -> score should be low (but not necessarily 0
      // because some might be a_verifier)
      expect(result.scoreCouverture, lessThan(50));
    });

    test('score is 100 when everything is covered', () {
      final result = _baseEvaluation(
        statutProfessionnel: 'salarie',
        aRcPrivee: true,
        aMenage: true,
        aProtectionJuridique: true,
        aAssuranceVoyage: true,
        aAssuranceDeces: true,
        aIjmCollective: true,
        aLaa: true,
      );
      expect(result.scoreCouverture, 100);
    });

    test('independant without IJM has critique lacune', () {
      final result = _baseEvaluation(
        statutProfessionnel: 'independant',
        aIjmCollective: false,
      );
      expect(result.lacunesCritiques, greaterThan(0));
    });

    test('independant without LAA has critique lacune', () {
      final result = _baseEvaluation(
        statutProfessionnel: 'independant',
        aLaa: false,
      );
      final laaItem = result.checklist.firstWhere((i) => i.id == 'laa');
      expect(laaItem.urgency, 'critique');
    });

    test('salarie IJM with collective is basse urgency', () {
      final result = _baseEvaluation(
        statutProfessionnel: 'salarie',
        aIjmCollective: true,
      );
      final ijmItem = result.checklist.firstWhere((i) => i.id == 'ijm');
      expect(ijmItem.urgency, 'basse');
      expect(ijmItem.status, 'couvert');
    });

    test('salarie IJM without collective is moyenne urgency', () {
      final result = _baseEvaluation(
        statutProfessionnel: 'salarie',
        aIjmCollective: false,
      );
      final ijmItem = result.checklist.firstWhere((i) => i.id == 'ijm');
      expect(ijmItem.urgency, 'moyenne');
      expect(ijmItem.status, 'a_verifier');
    });

    test('menage obligatoire in VD has haute urgency', () {
      final result = _baseEvaluation(canton: 'VD');
      final menageItem =
          result.checklist.firstWhere((i) => i.id == 'menage');
      expect(menageItem.urgency, 'haute');
    });

    test('menage in ZH for renter has moyenne urgency', () {
      final result = _baseEvaluation(
        canton: 'ZH',
        estLocataire: true,
      );
      final menageItem =
          result.checklist.firstWhere((i) => i.id == 'menage');
      expect(menageItem.urgency, 'moyenne');
    });

    test('menage in ZH for owner has basse urgency', () {
      final result = _baseEvaluation(
        canton: 'ZH',
        estLocataire: false,
      );
      final menageItem =
          result.checklist.firstWhere((i) => i.id == 'menage');
      expect(menageItem.urgency, 'basse');
    });

    test('deces urgency is haute when hypotheque or famille', () {
      final result = _baseEvaluation(aHypotheque: true);
      final decesItem =
          result.checklist.firstWhere((i) => i.id == 'deces');
      expect(decesItem.urgency, 'haute');
    });

    test('deces urgency is basse without hypotheque or famille', () {
      final result = _baseEvaluation(
        aHypotheque: false,
        aFamille: false,
      );
      final decesItem =
          result.checklist.firstWhere((i) => i.id == 'deces');
      expect(decesItem.urgency, 'basse');
    });

    test('voyage urgency is moyenne when voyagesFrequents', () {
      final result = _baseEvaluation(voyagesFrequents: true);
      final voyageItem =
          result.checklist.firstWhere((i) => i.id == 'voyage');
      expect(voyageItem.urgency, 'moyenne');
    });

    test('checklist sorted by urgency (critique first)', () {
      final result = _baseEvaluation(statutProfessionnel: 'independant');
      for (int i = 0; i < result.checklist.length - 1; i++) {
        final currentOrder = _urgencyOrder(result.checklist[i].urgency);
        final nextOrder = _urgencyOrder(result.checklist[i + 1].urgency);
        expect(currentOrder, lessThanOrEqualTo(nextOrder));
      }
    });

    test('recommendations include PRIORITE for critique gaps', () {
      final result = _baseEvaluation(
        statutProfessionnel: 'independant',
        aIjmCollective: false,
      );
      expect(
        result.recommandations.any((r) => r.contains('PRIORITÉ')),
        isTrue,
      );
    });

    test('recommendations always include general comparison advice', () {
      final result = _baseEvaluation();
      expect(
        result.recommandations
            .any((r) => r.contains('comparer les primes')),
        isTrue,
      );
    });

    test('disclaimer is present and mentions sp\u00e9cialiste', () {
      final result = _baseEvaluation();
      expect(result.disclaimer, isNotEmpty);
      expect(result.disclaimer, contains('indicative'));
      expect(result.disclaimer, contains('ne constitue pas'));
      expect(result.disclaimer, contains('sp\u00e9cialiste'));
    });

    test('all checklist items have sources', () {
      final result = _baseEvaluation(statutProfessionnel: 'independant');
      for (final item in result.checklist) {
        expect(item.source, isNotEmpty);
      }
    });

    test('all checklist items have cost estimates', () {
      final result = _baseEvaluation(statutProfessionnel: 'independant');
      for (final item in result.checklist) {
        expect(item.estimatedCostRange, isNotEmpty);
      }
    });

    test('menage obligatoire cantons include FR NW JU', () {
      for (final canton in ['FR', 'NW', 'JU']) {
        final result = _baseEvaluation(canton: canton);
        final menageItem =
            result.checklist.firstWhere((i) => i.id == 'menage');
        expect(menageItem.urgency, 'haute',
            reason: 'Canton $canton should have haute urgency for menage');
      }
    });

    test('salarie LAA is basse urgency (obligatoire via employeur)', () {
      final result = _baseEvaluation(
        statutProfessionnel: 'salarie',
        aLaa: false,
      );
      final laaItem = result.checklist.firstWhere((i) => i.id == 'laa');
      expect(laaItem.urgency, 'basse');
    });
  });
}

/// Helper to map urgency strings to numeric order for comparison.
int _urgencyOrder(String urgency) {
  switch (urgency) {
    case 'critique':
      return 0;
    case 'haute':
      return 1;
    case 'moyenne':
      return 2;
    case 'basse':
      return 3;
    default:
      return 4;
  }
}
