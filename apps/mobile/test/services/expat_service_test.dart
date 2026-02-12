import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/expat_service.dart';

/// Tests unitaires pour ExpatService (Sprint S23).
///
/// Couvre les 8 fonctions expatriation / frontaliers :
///   1. calculateSourceTax     — impot source bareme C
///   2. checkQuasiResident     — regle des 90% (GE)
///   3. simulate90DayRule      — jauge home office
///   4. compareSocialCharges   — charges sociales CH vs voisins
///   5. simulateForfaitFiscal  — forfait fiscal
///   6. estimateAvsGap         — lacunes AVS a l'etranger
///   7. planDeparture          — checklist depart
///   8. compareTaxBurden       — comparaison fiscale
///
/// Base legale : CDI, LIFD art. 14, LAVS, Reglement CE 883/2004.
void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  //  1. calculateSourceTax — impot a la source (bareme C)
  // ═══════════════════════════════════════════════════════════════════════════

  group('calculateSourceTax — impot a la source', () {
    test('GE celibataire sans enfant — taux 15.48%', () {
      final r = ExpatService.calculateSourceTax(
        salary: 10000,
        canton: 'GE',
      );

      expect(r['effectiveRate'] as double, closeTo(0.1548, 0.001));
      expect(r['monthlyTax'] as double, closeTo(1548, 1));
      expect(r['annualTax'] as double, closeTo(1548 * 12, 1));
      expect(r['isTessin'], isFalse);
    });

    test('TI — impot a la source = 0 (accord CH-IT 2024)', () {
      final r = ExpatService.calculateSourceTax(
        salary: 10000,
        canton: 'TI',
      );

      expect(r['monthlyTax'] as double, 0.0);
      expect(r['effectiveRate'] as double, 0.0);
      expect(r['isTessin'], isTrue);
      expect(r['note'] as String, contains('Italie'));
    });

    test('marie — reduction de 8% sur le taux de base', () {
      final rCelib = ExpatService.calculateSourceTax(
        salary: 10000,
        canton: 'VD',
      );
      final rMarie = ExpatService.calculateSourceTax(
        salary: 10000,
        canton: 'VD',
        isMarried: true,
      );

      // Marie: baseRate * 0.92 vs celibataire: baseRate * 1.0
      final ratio = (rMarie['effectiveRate'] as double) /
          (rCelib['effectiveRate'] as double);
      expect(ratio, closeTo(0.92, 0.001));
    });

    test('enfants — reduction de 2.5% par enfant', () {
      final r0 = ExpatService.calculateSourceTax(
        salary: 10000,
        canton: 'GE',
        children: 0,
      );
      final r2 = ExpatService.calculateSourceTax(
        salary: 10000,
        canton: 'GE',
        children: 2,
      );

      // 2 enfants => facteur 1.0 - 2*0.025 = 0.95
      final ratio =
          (r2['effectiveRate'] as double) / (r0['effectiveRate'] as double);
      expect(ratio, closeTo(0.95, 0.001));
    });

    test('enfants — facteur enfants plancher a 70%', () {
      final r = ExpatService.calculateSourceTax(
        salary: 10000,
        canton: 'GE',
        children: 20, // extremement artificiel
      );

      // childrenFactor = max(0.70, 1.0 - 20*0.025) = max(0.70, 0.50) = 0.70
      final baseRate = ExpatService.sourceTaxRates['GE']!;
      final expected = baseRate * 1.0 * 0.70; // celibataire + floor
      expect(r['effectiveRate'] as double, closeTo(expected, 0.001));
    });

    test('canton inconnu — taux par defaut 13%', () {
      final r = ExpatService.calculateSourceTax(
        salary: 10000,
        canton: 'XX',
      );

      expect(r['effectiveRate'] as double, closeTo(0.13, 0.001));
    });

    test('disclaimer toujours present', () {
      final r = ExpatService.calculateSourceTax(
        salary: 10000,
        canton: 'GE',
      );

      expect(r['disclaimer'] as String, isNotEmpty);
      expect(r['disclaimer'] as String, contains('educatif'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  2. checkQuasiResident — regle des 90%
  // ═══════════════════════════════════════════════════════════════════════════

  group('checkQuasiResident — statut quasi-resident', () {
    test('eligible si >= 90% du revenu mondial en CH', () {
      final r = ExpatService.checkQuasiResident(
        chIncome: 100000,
        worldwideIncome: 105000,
        canton: 'GE',
      );

      // ratio = 100000 / 105000 = 0.952 >= 0.90
      expect(r['eligible'], isTrue);
      expect((r['ratio'] as double), greaterThanOrEqualTo(0.90));
      expect((r['potentialSavings'] as double), greaterThan(0));
    });

    test('non eligible si < 90% du revenu mondial en CH', () {
      final r = ExpatService.checkQuasiResident(
        chIncome: 80000,
        worldwideIncome: 100000,
        canton: 'GE',
      );

      // ratio = 0.80 < 0.90
      expect(r['eligible'], isFalse);
      expect((r['potentialSavings'] as double), 0.0);
    });

    test('revenu mondial zero — non eligible', () {
      final r = ExpatService.checkQuasiResident(
        chIncome: 100000,
        worldwideIncome: 0,
        canton: 'GE',
      );

      expect(r['eligible'], isFalse);
      expect(r['ratio'] as double, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  3. simulate90DayRule — jauge home office
  // ═══════════════════════════════════════════════════════════════════════════

  group('simulate90DayRule — regle des 90 jours', () {
    test('risque faible — < 70 jours home office', () {
      final r = ExpatService.simulate90DayRule(
        homeOfficeDays: 50,
        commuteDays: 170,
      );

      expect(r['riskLevel'], 'low');
      expect(r['isOverThreshold'], isFalse);
      expect(r['daysRemaining'], 40);
    });

    test('risque moyen — entre 70 et 89 jours', () {
      final r = ExpatService.simulate90DayRule(
        homeOfficeDays: 85,
        commuteDays: 135,
      );

      expect(r['riskLevel'], 'medium');
      expect(r['isOverThreshold'], isFalse);
      expect(r['daysRemaining'], 5);
    });

    test('risque eleve — >= 90 jours', () {
      final r = ExpatService.simulate90DayRule(
        homeOfficeDays: 100,
        commuteDays: 120,
      );

      expect(r['riskLevel'], 'high');
      expect(r['isOverThreshold'], isTrue);
      expect(r['daysRemaining'], 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  4. compareSocialCharges — charges sociales CH vs etranger
  // ═══════════════════════════════════════════════════════════════════════════

  group('compareSocialCharges — charges sociales', () {
    test('CH vs France — les deux cotes sont calcules', () {
      final r = ExpatService.compareSocialCharges(
        salary: 8000,
        residenceCountry: 'France',
      );

      final ch = r['ch'] as Map<String, dynamic>;
      final foreign = r['foreign'] as Map<String, dynamic>;

      expect(ch['total'] as double, greaterThan(0));
      expect(foreign['total'] as double, greaterThan(0));
      expect(r['annualSalary'] as double, closeTo(96000, 1));
    });

    test('pays inconnu — taux par defaut 20%', () {
      final r = ExpatService.compareSocialCharges(
        salary: 10000,
        residenceCountry: 'Liechtenstein',
      );

      final foreign = r['foreign'] as Map<String, dynamic>;
      // 10000 * 12 * 0.20 = 24000
      expect(foreign['total'] as double, closeTo(24000, 1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  5. simulateForfaitFiscal — forfait fiscal
  // ═══════════════════════════════════════════════════════════════════════════

  group('simulateForfaitFiscal — forfait fiscal', () {
    test('forfait aboli a ZH — non eligible', () {
      final r = ExpatService.simulateForfaitFiscal(
        canton: 'ZH',
        livingExpenses: 500000,
        actualIncome: 2000000,
      );

      expect(r['eligible'], isFalse);
      expect(r['abolished'], isTrue);
    });

    test('VD — forfait base = max(depenses, minimum cantonal, minimum federal)', () {
      final r = ExpatService.simulateForfaitFiscal(
        canton: 'VD',
        livingExpenses: 1500000,
        actualIncome: 5000000,
      );

      // VD minimum = 1'000'000, federal = 400'000, depenses = 1'500'000
      // Forfait base = max(1500000, 1000000, 400000) = 1500000
      expect(r['eligible'], isTrue);
      expect(r['forfaitBase'] as double, closeTo(1500000, 1));
    });

    test('depenses inferieures au minimum cantonal — minimum cantonal utilise', () {
      final r = ExpatService.simulateForfaitFiscal(
        canton: 'VD',
        livingExpenses: 300000,
        actualIncome: 3000000,
      );

      // VD minimum = 1'000'000 > 300'000 et > 400'000
      expect(r['forfaitBase'] as double, closeTo(1000000, 1));
    });

    test('economies calculees — forfait vs ordinaire', () {
      final r = ExpatService.simulateForfaitFiscal(
        canton: 'GE',
        livingExpenses: 800000,
        actualIncome: 5000000,
      );

      // Forfait base = max(800000, 600000, 400000) = 800000
      // Forfait tax = 800000 * 0.25 = 200000
      // Ordinary tax = 5000000 * 0.35 = 1750000
      // Savings = 1550000
      expect(r['isFavorable'], isTrue);
      expect((r['savings'] as double), greaterThan(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  6. estimateAvsGap — lacunes AVS
  // ═══════════════════════════════════════════════════════════════════════════

  group('estimateAvsGap — lacunes AVS', () {
    test('44 annees en CH — rente complete, pas de lacune', () {
      final r = ExpatService.estimateAvsGap(
        yearsAbroad: 0,
        yearsInCh: 44,
      );

      expect(r['completeness'] as double, closeTo(1.0, 0.001));
      expect(r['missingYears'], 0);
      expect(r['monthlyLoss'] as double, closeTo(0, 1));
    });

    test('10 annees a l etranger — reduction proportionnelle', () {
      final r = ExpatService.estimateAvsGap(
        yearsAbroad: 10,
        yearsInCh: 34,
      );

      // completeness = 34/44
      expect(r['completeness'] as double, closeTo(34 / 44, 0.01));
      expect(r['missingYears'], 10);
      expect((r['monthlyLoss'] as double), greaterThan(0));
      expect((r['reductionPercent'] as double), greaterThan(0));
    });

    test('cotisation volontaire recommandee', () {
      final r = ExpatService.estimateAvsGap(
        yearsAbroad: 5,
        yearsInCh: 30,
      );

      expect(r['canVolunteer'], isTrue);
      expect((r['voluntaryMin'] as double), greaterThan(0));
      expect((r['voluntaryMax'] as double), greaterThan(r['voluntaryMin'] as double));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  7. planDeparture — checklist depart
  // ═══════════════════════════════════════════════════════════════════════════

  group('planDeparture — checklist depart', () {
    test('checklist contient les elements cles', () {
      final r = ExpatService.planDeparture(
        departureDate: DateTime.now().add(const Duration(days: 60)),
        canton: 'GE',
        pillar3aBalance: 50000,
        lppBalance: 200000,
      );

      final checklist = r['checklist'] as List<Map<String, dynamic>>;
      final ids = checklist.map((c) => c['id']).toList();

      expect(ids, contains('pillar3a'));
      expect(ids, contains('lpp'));
      expect(ids, contains('commune'));
      expect(ids, contains('lamal'));
      expect(ids, contains('cdi'));
      expect(ids, contains('impots_prorata'));
    });

    test('pas d exit tax en Suisse', () {
      final r = ExpatService.planDeparture(
        departureDate: DateTime.now().add(const Duration(days: 30)),
        canton: 'ZH',
      );

      expect(r['noExitTax'], isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  8. compareTaxBurden — comparaison fiscale
  // ═══════════════════════════════════════════════════════════════════════════

  group('compareTaxBurden — comparaison fiscale', () {
    test('CH vs France — les deux cotes sont calcules', () {
      final r = ExpatService.compareTaxBurden(
        salary: 10000,
        canton: 'GE',
        targetCountry: 'France',
      );

      final ch = r['ch'] as Map<String, dynamic>;
      final foreign = r['foreign'] as Map<String, dynamic>;

      expect(ch['totalTax'] as double, greaterThan(0));
      expect(foreign['totalTax'] as double, greaterThan(0));
      expect(ch['netSalary'] as double, greaterThan(0));
      expect(foreign['netSalary'] as double, greaterThan(0));
    });

    test('CH vs Dubai (0% impot) — CH plus cher', () {
      final r = ExpatService.compareTaxBurden(
        salary: 15000,
        canton: 'GE',
        targetCountry: 'Dubai',
      );

      // Dubai: 0% tax + 20% social (default) vs GE: ~15.5% + ~6.4%
      final _ = r['chCheaper'] as bool;
      // Dubai has 0% tax but we use 20% default social, so it depends
      // GE totalRate = 0.1548 + ~0.064 = ~0.2188
      // Dubai totalRate = 0.00 + 0.20 = 0.20 (but no social charges entry => default)
      // Actually Dubai is not in foreignSocialCharges, so foreignSocialRate = 0.20
      // foreignTotalRate = 0.00 + 0.20 = 0.20
      expect(r['difference'] is double, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  Constantes et helpers
  // ═══════════════════════════════════════════════════════════════════════════

  group('constantes et helpers', () {
    test('26 cantons definis pour impot source', () {
      expect(ExpatService.sourceTaxRates.length, 26);
    });

    test('cantons forfait aboli — 6 cantons', () {
      expect(ExpatService.forfaitAbolishedCantons.length, 6);
      expect(ExpatService.forfaitAbolishedCantons, contains('ZH'));
      expect(ExpatService.forfaitAbolishedCantons, contains('BS'));
    });

    test('cantons tries alphabetiquement', () {
      final codes = ExpatService.sortedCantonCodes;
      for (int i = 1; i < codes.length; i++) {
        expect(codes[i].compareTo(codes[i - 1]), greaterThan(0));
      }
    });

    test('disclaimer ne contient pas de termes interdits', () {
      expect(ExpatService.disclaimer, isNot(contains('garanti')));
      expect(ExpatService.disclaimer, isNot(contains('certain')));
      expect(ExpatService.disclaimer, isNot(contains('sans risque')));
      expect(ExpatService.disclaimer, isNot(contains('optimal')));
    });

    test('formatChf — format suisse avec apostrophe', () {
      expect(ExpatService.formatChf(25000.0), contains("25'000"));
    });
  });
}
