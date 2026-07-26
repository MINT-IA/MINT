import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/family_service.dart';

/// Unit tests for FamilyService — Sprint S22 (Mariage + Naissance + Concubinage)
///
/// Tests pure Dart financial calculations for Swiss family life events:
///   - Marriage fiscal comparison (penalty/bonus)
///   - Matrimonial regime simulation
///   - Survivor benefits estimation
///   - Parental leave (APG maternity/paternity)
///   - Family allocations by canton
///   - Fiscal impact of children
///   - Marriage vs concubinage comparison
///   - Inheritance tax estimation
///   - Edge cases and compliance checks
///
/// Legal references: LIFD, CC, LAPG, LAFam, LPP, LAVS
void main() {
  // ════════════════════════════════════════════════════════════
  //  MARRIAGE FISCAL COMPARISON
  // ════════════════════════════════════════════════════════════

  group('FamilyService - Marriage Fiscal Comparison', () {
    test('equal high incomes produce a marriage penalty', () {
      final result = FamilyService.compareFiscalMariage(
        revenu1: 100000,
        revenu2: 100000,
        canton: 'VD',
      );

      expect(result['isPenalite'], isTrue,
          reason: 'Equal high incomes should trigger marriage penalty');
      expect(result['difference'] as double, greaterThan(0));
      expect(result['totalCelibataires'] as double, greaterThan(0));
      expect(result['totalMarie'] as double, greaterThan(0));
    });

    test('single-earner couple gets a marriage bonus', () {
      final result = FamilyService.compareFiscalMariage(
        revenu1: 120000,
        revenu2: 0,
        canton: 'VD',
      );

      expect(result['isPenalite'], isFalse,
          reason: 'Single-earner couple should get a marriage bonus');
      expect(result['difference'] as double, lessThan(0));
    });

    test('low-income couple has correct calculations', () {
      final result = FamilyService.compareFiscalMariage(
        revenu1: 40000,
        revenu2: 30000,
        canton: 'ZH',
      );

      expect(result['revenu1'], 40000.0);
      expect(result['revenu2'], 30000.0);
      expect(result['canton'], 'ZH');
      expect(result['cantonNom'], 'Zurich');
      expect(result['totalCelibataires'], isA<double>());
      expect(result['totalMarie'], isA<double>());
    });

    test('children reduce tax burden through deductions', () {
      final resultNoKids = FamilyService.compareFiscalMariage(
        revenu1: 80000,
        revenu2: 60000,
        canton: 'GE',
        nbEnfants: 0,
      );
      final resultWithKids = FamilyService.compareFiscalMariage(
        revenu1: 80000,
        revenu2: 60000,
        canton: 'GE',
        nbEnfants: 2,
      );

      final taxNoKids = resultNoKids['totalMarie'] as double;
      final taxWithKids = resultWithKids['totalMarie'] as double;

      expect(taxWithKids, lessThan(taxNoKids),
          reason: 'Children deductions should reduce married tax');
      expect(resultWithKids['deductionEnfants'],
          2 * FamilyService.deductionParEnfant);
    });

    test('double-earner deduction applied when both have income', () {
      final result = FamilyService.compareFiscalMariage(
        revenu1: 80000,
        revenu2: 60000,
        canton: 'VD',
      );

      expect(result['deductionDoubleRevenu'], FamilyService.deductionDoubleRevenu);
    });

    test('no double-earner deduction when one income is zero', () {
      final result = FamilyService.compareFiscalMariage(
        revenu1: 80000,
        revenu2: 0,
        canton: 'VD',
      );

      expect(result['deductionDoubleRevenu'], 0.0);
    });

    test('unknown canton uses default rate', () {
      final result = FamilyService.compareFiscalMariage(
        revenu1: 80000,
        revenu2: 60000,
        canton: 'XX',
      );

      // Should not throw, uses fallback rate 0.13
      expect(result['totalCelibataires'], isA<double>());
      expect(result['totalMarie'], isA<double>());
      expect(result['cantonNom'], 'XX');
    });

    test('total deductions are correctly summed', () {
      final result = FamilyService.compareFiscalMariage(
        revenu1: 80000,
        revenu2: 60000,
        canton: 'BE',
        nbEnfants: 1,
      );

      const expectedTotal = FamilyService.deductionMarie +
          FamilyService.deductionAssuranceMarie +
          FamilyService.deductionDoubleRevenu +
          1 * FamilyService.deductionParEnfant;

      expect(result['totalDeductions'], expectedTotal);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  PARENTAL LEAVE (APG)
  // ════════════════════════════════════════════════════════════

  group('FamilyService - Parental Leave (APG)', () {
    test('maternity leave is 14 weeks / 98 days', () {
      final result = FamilyService.simulateCongeParental(
        salaireMensuel: 6000,
        isMother: true,
      );

      expect(result['dureeSemaines'], 14);
      expect(result['dureeJours'], 98);
      expect(result['type'], 'Maternite');
    });

    test('paternity leave is 2 weeks / 14 days indemnised', () {
      final result = FamilyService.simulateCongeParental(
        salaireMensuel: 6000,
        isMother: false,
      );

      expect(result['dureeSemaines'], 2);
      expect(result['joursIndemnises'], 14);
      expect(result['type'], 'Paternite');
    });

    test('APG is 80% of daily salary', () {
      // Salary: 6000/month => 72000/year => 200/day (72000/360)
      // APG: 200 * 0.80 = 160/day (under cap)
      final result = FamilyService.simulateCongeParental(
        salaireMensuel: 6000,
        isMother: true,
      );

      const dailySalary = 6000.0 * 12 / 360;
      const expectedApg = dailySalary * 0.80;

      expect(result['apgJournalier'], closeTo(expectedApg, 0.01));
      expect(result['isCapped'], isFalse);
    });

    test('APG is capped at CHF 220/day for high salaries', () {
      // Salary: 12000/month => 144000/year => 400/day
      // APG: 400 * 0.80 = 320/day => capped at 220
      final result = FamilyService.simulateCongeParental(
        salaireMensuel: 12000,
        isMother: true,
      );

      expect(result['apgJournalier'], FamilyService.apgDailyMax);
      expect(result['isCapped'], isTrue);
    });

    test('total APG for maternity at cap equals 98 x 220', () {
      final result = FamilyService.simulateCongeParental(
        salaireMensuel: 12000,
        isMother: true,
      );

      expect(result['totalApg'],
          closeTo(FamilyService.apgDailyMax * 98, 0.01));
    });

    test('salary loss is positive when salary exceeds APG', () {
      final result = FamilyService.simulateCongeParental(
        salaireMensuel: 12000,
        isMother: true,
      );

      expect(result['perteSalaire'] as double, greaterThan(0));
    });

    test('low salary has no cap and minimal loss', () {
      final result = FamilyService.simulateCongeParental(
        salaireMensuel: 3000,
        isMother: true,
      );

      expect(result['isCapped'], isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  FAMILY ALLOCATIONS
  // ════════════════════════════════════════════════════════════

  group('FamilyService - Family Allocations', () {
    test('Zug has highest allocations at CHF 330/month (OFAS 2026)', () {
      final result = FamilyService.estimateAllocations(
        canton: 'ZG',
        nbEnfants: 1,
      );

      expect(result['mensuelParEnfant'], 330.0);
      expect(result['rank'], 1);
    });

    test('Zurich has minimum allocations at CHF 215/month (OFAS 2026)', () {
      final result = FamilyService.estimateAllocations(
        canton: 'ZH',
        nbEnfants: 1,
      );

      expect(result['mensuelParEnfant'], 215.0);
    });

    test('annual total is 12x monthly for multiple children', () {
      final result = FamilyService.estimateAllocations(
        canton: 'GE',
        nbEnfants: 3,
      );

      expect(result['mensuelTotal'], 311.0 * 3);
      expect(result['annuelTotal'], 311.0 * 3 * 12);
    });

    test('ranking returns 26 cantons sorted descending', () {
      final ranking = FamilyService.getAllocationsRanking(nbEnfants: 1);

      expect(ranking.length, 26);
      expect(ranking.first['rank'], 1);
      expect(ranking.last['rank'], 26);

      // First should have highest amount
      final firstAmount = ranking.first['mensuelParEnfant'] as double;
      final lastAmount = ranking.last['mensuelParEnfant'] as double;
      expect(firstAmount, greaterThanOrEqualTo(lastAmount));
    });

    test('unknown canton defaults to CHF 215 (federal minimum)', () {
      final result = FamilyService.estimateAllocations(
        canton: 'XX',
        nbEnfants: 1,
      );

      expect(result['mensuelParEnfant'], 215.0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  FISCAL IMPACT OF CHILDREN
  // ════════════════════════════════════════════════════════════

  group('FamilyService - Fiscal Impact of Children', () {
    test('deduction per child is CHF 6800', () {
      final result = FamilyService.calculateImpactFiscalEnfant(
        revenuImposable: 80000,
        tauxMarginal: 0.20,
        nbEnfants: 1,
      );

      expect(result['deductionEnfants'], FamilyService.deductionParEnfant);
    });

    test('childcare deduction is capped at CHF 25800', () {
      final result = FamilyService.calculateImpactFiscalEnfant(
        revenuImposable: 100000,
        tauxMarginal: 0.20,
        nbEnfants: 1,
        fraisGarde: 3000, // 3000/month * 12 = 36000 > cap
      );

      expect(result['deductionGarde'], FamilyService.deductionGardeMax);
    });

    test('tax savings scale with number of children', () {
      final result1 = FamilyService.calculateImpactFiscalEnfant(
        revenuImposable: 80000,
        tauxMarginal: 0.20,
        nbEnfants: 1,
      );
      final result3 = FamilyService.calculateImpactFiscalEnfant(
        revenuImposable: 80000,
        tauxMarginal: 0.20,
        nbEnfants: 3,
      );

      final savings1 = result1['economieFiscale'] as double;
      final savings3 = result3['economieFiscale'] as double;
      expect(savings3, greaterThan(savings1));
      expect(result3['deductionEnfants'], 3 * FamilyService.deductionParEnfant);
    });

    test('zero marginal rate uses 15% default', () {
      final result = FamilyService.calculateImpactFiscalEnfant(
        revenuImposable: 80000,
        tauxMarginal: 0,
        nbEnfants: 1,
      );

      expect(result['tauxMarginal'], 0.15);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  MARRIAGE VS CONCUBINAGE COMPARISON
  // ════════════════════════════════════════════════════════════

  group('FamilyService - Marriage vs Concubinage', () {
    test('comparison returns fiscal and inheritance data', () {
      final result = FamilyService.compareMariageVsConcubinage(
        revenu1: 80000,
        revenu2: 60000,
        canton: 'VD',
      );

      expect(result, containsPair('fiscal', isA<Map<String, dynamic>>()));
      expect(result, containsPair('inheritance', isA<Map<String, dynamic>>()));
      expect(result, containsPair('inheritanceMarried', isA<Map<String, dynamic>>()));
      expect(result, containsPair('avsSurvivorRente', isA<double>()));
    });

    test('no aggregated score, no winner — the arbitration is the user\'s', () {
      // Constat B (audit conseiller) : compter des critères hétérogènes
      // (protection du·de la survivant·e, impôt annuel, héritage) à poids égal
      // et en tirer un gagnant est du pseudo-conseil — leur importance dépend
      // de la situation de chacun·e. Ce test est la garde anti-résurrection :
      // un verdict qui dort dans le résultat finit par être affiché.
      final result = FamilyService.compareMariageVsConcubinage(
        revenu1: 80000,
        revenu2: 60000,
        canton: 'VD',
      );

      expect(result.containsKey('scoreMariage'), isFalse);
      expect(result.containsKey('scoreConcubinage'), isFalse);
      expect(result.containsKey('fiscalAdvantage'), isFalse);
      // Les faits par critère restent disponibles — c'est la comparaison
      // critère par critère qui est rendue, pas un agrégat.
      expect(result['fiscal'], isA<Map<String, dynamic>>());
      expect(result['inheritance'], isA<Map<String, dynamic>>());
      expect(result['lppSurvivorFactor'], FamilyService.lppSurvivorFactor);
    });

    test('la comparaison n\'expose aucun montant d\'impôt successoral', () {
      // `patrimoine × taux` supposait que 100 % du patrimoine peut aller au·à la
      // partenaire — faux depuis la révision du 1.1.2023 (réserve des
      // descendant·e·s = 1/2, CC art. 470-471) et faux pour un bien en
      // copropriété (seule la quote-part du·de la défunt·e entre en succession).
      // Seul le TAUX cantonal survit. Garde anti-résurrection : un montant
      // dormant dans le résultat finit toujours par être affiché.
      final result = FamilyService.compareMariageVsConcubinage(
        revenu1: 80000,
        revenu2: 60000,
        canton: 'VD',
      );

      final inheritance = result['inheritance'] as Map<String, dynamic>;
      expect(inheritance.containsKey('impot'), isFalse);
      expect(inheritance.containsKey('netHerite'), isFalse);
      expect(inheritance.containsKey('patrimoine'), isFalse);
      expect(inheritance['taux'], 0.25);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  INHERITANCE TAX
  // ════════════════════════════════════════════════════════════

  group('FamilyService - Inheritance Tax', () {
    test('married partner is always exempt (all cantons)', () {
      // L'exonération vient des lois fiscales CANTONALES (il n'existe pas
      // d'impôt successoral fédéral ordinaire) — pas de CC art. 462, qui règle
      // la part successorale CIVILE du·de la conjoint·e.
      for (final canton in FamilyService.cantonNames.keys) {
        final result = FamilyService.estimateInheritanceTax(
          canton: canton,
          isMarried: true,
        );
        expect(result['taux'], 0.0,
            reason: 'Married partner should be tax-exempt in $canton');
      }
    });

    test('non-married partner falls under the cantonal third-party rate', () {
      final result = FamilyService.estimateInheritanceTax(
        canton: 'VD', // 25%
        isMarried: false,
      );

      expect(result['taux'], 0.25);
    });

    test('no inheritance tax in SZ/OW/NW even for non-married', () {
      for (final canton in ['SZ', 'OW', 'NW']) {
        final result = FamilyService.estimateInheritanceTax(
          canton: canton,
          isMarried: false,
        );

        expect(result['taux'], 0.0,
            reason: '$canton should have no inheritance tax');
      }
    });

    test('aucun montant en francs n\'est produit, quel que soit le canton', () {
      // Le service ne renvoie QUE le taux : pas d'`impot`, pas de `netHerite`,
      // pas de `patrimoine`. La base (« 100 % du patrimoine peut aller au·à la
      // partenaire ») est invérifiable, donc le montant est retiré.
      for (final canton in FamilyService.cantonNames.keys) {
        final result = FamilyService.estimateInheritanceTax(
          canton: canton,
          isMarried: false,
        );
        expect(result.keys.toSet(), {'canton', 'isMarried', 'taux'},
            reason: 'un montant dormant finit toujours par être rebranché');
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  //  EDGE CASES
  // ════════════════════════════════════════════════════════════

  group('FamilyService - Edge Cases', () {
    test('zero income produces zero tax for both scenarios', () {
      final result = FamilyService.compareFiscalMariage(
        revenu1: 0,
        revenu2: 0,
        canton: 'ZH',
      );

      expect(result['totalCelibataires'], 0.0);
      expect(result['totalMarie'], 0.0);
      expect(result['difference'], 0.0);
    });

    test('very high incomes still compute without error', () {
      final result = FamilyService.compareFiscalMariage(
        revenu1: 500000,
        revenu2: 500000,
        canton: 'ZG',
      );

      expect(result['totalCelibataires'] as double, greaterThan(0));
      expect(result['totalMarie'] as double, greaterThan(0));
    });

    test('max children (5) correctly applies deductions', () {
      final result = FamilyService.compareFiscalMariage(
        revenu1: 100000,
        revenu2: 80000,
        canton: 'VD',
        nbEnfants: 5,
      );

      expect(result['deductionEnfants'], 5 * FamilyService.deductionParEnfant);
    });

    test('formatChf formats numbers with Swiss apostrophe', () {
      expect(FamilyService.formatChf(1234), 'CHF\u00A01\'234');
      expect(FamilyService.formatChf(0), 'CHF\u00A00');
      expect(FamilyService.formatChf(1000000), 'CHF\u00A01\'000\'000');
    });

    test('sortedCantonCodes returns 26 cantons alphabetically', () {
      final codes = FamilyService.sortedCantonCodes;
      expect(codes.length, 26);
      expect(codes.first, 'AG');
      expect(codes.last, 'ZH');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  COMPLIANCE CHECKS
  // ════════════════════════════════════════════════════════════

  group('FamilyService - Compliance', () {
    test('constants match CLAUDE.md source of truth', () {
      // Deduction per child: CHF 6800 (LIFD art. 35 al. 1 let. a, ESTV 2026)
      expect(FamilyService.deductionParEnfant, 6800.0);

      // APG daily max: CHF 220 (LAPG art. 16e)
      expect(FamilyService.apgDailyMax, 220.0);

      // APG maternity: 14 weeks = 98 days
      expect(FamilyService.apgMaternityWeeks, 14);
      expect(FamilyService.apgMaternityDays, 98);

      // APG paternity: 2 weeks = 10 working days
      expect(FamilyService.apgPaternityWeeks, 2);
      expect(FamilyService.apgPaternityWorkingDays, 10);

      // APG replacement rate: 80%
      expect(FamilyService.apgReplacementRate, 0.80);
    });

    test('AVS survivor factor matches constants', () {
      // AVS survivor rente: 80% of deceased rente (LAVS art. 35)
      expect(FamilyService.avsSurvivorFactor, 0.80);
    });

    test('LPP survivor factor matches constants', () {
      // LPP survivor rente: 60% of insured rente (LPP art. 19)
      expect(FamilyService.lppSurvivorFactor, 0.60);
    });

    test('all 26 cantons have allocations defined', () {
      expect(FamilyService.allocationsMensuelles.length, 26);

      // Minimum allocation should be at least CHF 215 (LAFam art. 5, 2025)
      for (final entry in FamilyService.allocationsMensuelles.entries) {
        expect(entry.value, greaterThanOrEqualTo(215.0),
            reason: '${entry.key} allocation should be >= CHF 215 (LAFam art. 5)');
      }
    });

    test('all 26 cantons have inheritance tax rates defined', () {
      // Accessed via estimateInheritanceTax for each canton
      for (final canton in FamilyService.cantonNames.keys) {
        final result = FamilyService.estimateInheritanceTax(
          canton: canton,
          isMarried: false,
        );
        expect(result['taux'], isA<double>());
        expect(result['taux'] as double, greaterThanOrEqualTo(0.0));
        expect(result['taux'] as double, lessThanOrEqualTo(1.0));
      }
    });

    test('married insurance deduction is double the single deduction', () {
      expect(FamilyService.deductionAssuranceMarie,
          FamilyService.deductionAssuranceCelibataire * 2);
    });
  });
}
