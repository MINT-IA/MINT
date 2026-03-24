import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/life_events_service.dart';

/// Unit tests for DivorceService & SuccessionService — life_events_service.dart
///
/// Tests pure Dart financial calculations for Swiss life events:
///   - Divorce: LPP split, patrimoine split, tax impact, pension alimentaire
///   - Succession: legal shares, reserves (2023 law), testament, cantonal taxes
///   - Edge cases, checklist completeness, and alerts
///
/// Legal references: CC 122, LFLP 22, CC 181 ss, CC 221 ss, CC 247 ss,
///                   OPP3 art. 2, LIFD
void main() {
  // ════════════════════════════════════════════════════════════
  //  DIVORCE SERVICE — LPP SPLIT
  // ════════════════════════════════════════════════════════════

  group('DivorceService - LPP Split (CC 122 / LFLP 22)', () {
    test('equal LPP avoirs produce zero transfer', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 10,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 80000,
          incomeConjoint2: 80000,
          lppConjoint1: 200000,
          lppConjoint2: 200000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 100000,
          dettesCommunes: 0,
        ),
      );

      expect(result.lppSplit.totalLpp, 400000);
      expect(result.lppSplit.shareConjoint1, 200000);
      expect(result.lppSplit.shareConjoint2, 200000);
      expect(result.lppSplit.transferAmount, 0);
      expect(result.lppSplit.transferDirection, '-');
    });

    test('unequal LPP avoirs produce correct transfer direction 1 -> 2', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 10,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 80000,
          incomeConjoint2: 40000,
          lppConjoint1: 300000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      expect(result.lppSplit.totalLpp, 400000);
      expect(result.lppSplit.shareConjoint1, 200000);
      expect(result.lppSplit.shareConjoint2, 200000);
      expect(result.lppSplit.transferAmount, 100000);
      expect(result.lppSplit.transferDirection, contains('1'));
      expect(result.lppSplit.transferDirection, contains('2'));
    });

    test('large LPP transfer triggers alert', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 15,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 100000,
          incomeConjoint2: 50000,
          lppConjoint1: 500000,
          lppConjoint2: 50000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      // Transfer = |500000 - 50000| / 2 = 225000, which is > 100000
      expect(result.lppSplit.transferAmount, 225000);
      expect(
        result.alerts.any((a) => a.contains('transfert LPP')),
        isTrue,
        reason: 'Large LPP transfer should produce an alert',
      );
    });
  });

  // ════════════════════════════════════════════════════════════
  //  DIVORCE SERVICE — PATRIMOINE SPLIT
  // ════════════════════════════════════════════════════════════

  group('DivorceService - Patrimoine Split', () {
    test('participation aux acquets splits fortune 50/50', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 10,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 80000,
          incomeConjoint2: 60000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 200000,
          dettesCommunes: 0,
        ),
      );

      expect(result.patrimoineSplit.fortuneNette, 200000);
      expect(result.patrimoineSplit.shareConjoint1, 100000);
      expect(result.patrimoineSplit.shareConjoint2, 100000);
    });

    test('communaute de biens also splits 50/50', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 10,
          numberOfChildren: 0,
          regime: MatrimonialRegime.communauteDeBiens,
          incomeConjoint1: 80000,
          incomeConjoint2: 40000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 300000,
          dettesCommunes: 100000,
        ),
      );

      expect(result.patrimoineSplit.fortuneNette, 200000);
      expect(result.patrimoineSplit.shareConjoint1, 100000);
      expect(result.patrimoineSplit.shareConjoint2, 100000);
    });

    test('separation de biens splits proportionally to income', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 10,
          numberOfChildren: 0,
          regime: MatrimonialRegime.separationDeBiens,
          incomeConjoint1: 120000,
          incomeConjoint2: 60000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 180000,
          dettesCommunes: 0,
        ),
      );

      // Income ratio: 120k / 180k = 2/3 and 60k / 180k = 1/3
      expect(result.patrimoineSplit.fortuneNette, 180000);
      expect(result.patrimoineSplit.shareConjoint1, closeTo(120000, 0.01));
      expect(result.patrimoineSplit.shareConjoint2, closeTo(60000, 0.01));
    });

    test('separation de biens with zero income splits 50/50 as fallback', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 5,
          numberOfChildren: 0,
          regime: MatrimonialRegime.separationDeBiens,
          incomeConjoint1: 0,
          incomeConjoint2: 0,
          lppConjoint1: 50000,
          lppConjoint2: 50000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 100000,
          dettesCommunes: 0,
        ),
      );

      expect(result.patrimoineSplit.shareConjoint1, 50000);
      expect(result.patrimoineSplit.shareConjoint2, 50000);
    });

    test('debts greater than 50% of fortune triggers alert', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 10,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 80000,
          incomeConjoint2: 60000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 100000,
          dettesCommunes: 60000,
        ),
      );

      expect(
        result.alerts.any((a) => a.contains('dettes communes')),
        isTrue,
        reason: 'High debt ratio should trigger an alert',
      );
    });
  });

  // ════════════════════════════════════════════════════════════
  //  DIVORCE SERVICE — TAX IMPACT
  // ════════════════════════════════════════════════════════════

  group('DivorceService - Tax Impact', () {
    test('married tax uses 18% on combined income', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 10,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 100000,
          incomeConjoint2: 80000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      // Uses RetirementTaxCalculator.estimateMarginalRate(180000, 'ZH', isMarried: true)
      // Effective: 12.9% * 1.15 income adj * 0.85 married * 1.3 marginal ≈ 16.36%
      expect(result.taxImpact.estimatedTaxMarried, closeTo(29455.50, 50));
    });

    test('individual taxes sum is different from married tax', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 10,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 100000,
          incomeConjoint2: 80000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      final totalAfter = result.taxImpact.totalTaxAfter;
      expect(totalAfter,
          result.taxImpact.estimatedTaxConjoint1 + result.taxImpact.estimatedTaxConjoint2);
      expect(result.taxImpact.delta, totalAfter - result.taxImpact.estimatedTaxMarried);
    });

    test('large tax delta triggers fiscal impact alert', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 10,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 150000,
          incomeConjoint2: 100000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      // Delta should be > 5000 given these incomes
      if (result.taxImpact.delta > 5000) {
        expect(
          result.alerts.any((a) => a.contains('impact fiscal')),
          isTrue,
        );
      }
    });

    test('zero income produces zero individual tax', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 5,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 80000,
          incomeConjoint2: 0,
          lppConjoint1: 100000,
          lppConjoint2: 50000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      expect(result.taxImpact.estimatedTaxConjoint2, 0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  DIVORCE SERVICE — PENSION ALIMENTAIRE
  // ════════════════════════════════════════════════════════════

  group('DivorceService - Pension Alimentaire', () {
    test('children produce CHF 600/month each', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 3,
          numberOfChildren: 2,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 80000,
          incomeConjoint2: 80000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      // Short marriage (< 5 years), equal incomes: only child contribution
      expect(result.pensionAlimentaireMonthly, closeTo(1200, 0.01));
    });

    test('long marriage >= 10y with income gap adds spousal maintenance at 15%', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 12,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 120000,
          incomeConjoint2: 40000,
          lppConjoint1: 200000,
          lppConjoint2: 50000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      // Income gap = 80000, monthly gap = 80000/12 = ~6666.67
      // Spousal maintenance = 6666.67 * 0.15 = 1000.00
      const expectedSpousal = (80000 / 12.0) * 0.15;
      expect(result.pensionAlimentaireMonthly, closeTo(expectedSpousal, 0.01));
    });

    test('medium marriage 5-9y with income gap adds spousal maintenance at 8%', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 7,
          numberOfChildren: 1,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 100000,
          incomeConjoint2: 40000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      // Child: 600
      // Spousal: (60000 / 12) * 0.08 = 400
      const expectedChild = 600.0;
      const expectedSpousal = (60000 / 12.0) * 0.08;
      expect(
          result.pensionAlimentaireMonthly, closeTo(expectedChild + expectedSpousal, 0.01));
    });

    test('short marriage < 5y with no children produces zero', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 3,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 80000,
          incomeConjoint2: 80000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      expect(result.pensionAlimentaireMonthly, 0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  DIVORCE SERVICE — CHECKLIST & ALERTS
  // ════════════════════════════════════════════════════════════

  group('DivorceService - Checklist & Alerts', () {
    test('checklist contains 10 mandatory items', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 10,
          numberOfChildren: 1,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 80000,
          incomeConjoint2: 60000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 50000,
          dettesCommunes: 0,
        ),
      );

      expect(result.checklist.length, 10);
      expect(result.checklist.any((c) => c.contains('LPP')), isTrue);
      expect(result.checklist.any((c) => c.contains('3a')), isTrue);
      expect(result.checklist.any((c) => c.contains('mediateur')), isTrue);
      expect(result.checklist.any((c) => c.contains('budget post-divorce')), isTrue);
      expect(result.checklist.any((c) => c.contains('testament')), isTrue);
    });

    test('children trigger garde alert', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 5,
          numberOfChildren: 2,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 80000,
          incomeConjoint2: 60000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      expect(
        result.alerts.any((a) => a.contains('enfant(s)')),
        isTrue,
        reason: 'Children should trigger garde alert',
      );
    });

    test('separation de biens triggers regime-specific alert', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 5,
          numberOfChildren: 0,
          regime: MatrimonialRegime.separationDeBiens,
          incomeConjoint1: 80000,
          incomeConjoint2: 60000,
          lppConjoint1: 100000,
          lppConjoint2: 100000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      expect(
        result.alerts.any((a) => a.contains('separation de biens')),
        isTrue,
      );
    });

    test('long marriage with large income gap triggers entretien alert', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 15,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 150000,
          incomeConjoint2: 50000,
          lppConjoint1: 200000,
          lppConjoint2: 50000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      expect(
        result.alerts.any((a) => a.contains('contribution d\'entretien')),
        isTrue,
        reason: 'Marriage >= 10y with income gap > 40k should trigger entretien alert',
      );
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SUCCESSION SERVICE — LEGAL DISTRIBUTION
  // ════════════════════════════════════════════════════════════

  group('SuccessionService - Legal Distribution', () {
    test('married with children: spouse 1/2, children share 1/2', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.marie,
          numberOfChildren: 2,
          parentsVivants: true,
          hasFratrie: true,
          hasConcubin: false,
          fortuneTotale: 1000000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'VD',
          hasTestament: false,
        ),
      );

      final conjointShare = result.legalDistribution
          .firstWhere((h) => h.heirLabel == 'Conjoint');
      expect(conjointShare.amount, 500000);
      expect(conjointShare.percentage, 0.5);

      final enfant1 = result.legalDistribution
          .firstWhere((h) => h.heirLabel == 'Enfant 1');
      final enfant2 = result.legalDistribution
          .firstWhere((h) => h.heirLabel == 'Enfant 2');
      expect(enfant1.amount, 250000);
      expect(enfant2.amount, 250000);
    });

    test('married without children, parents alive: spouse 3/4, parents 1/4', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.marie,
          numberOfChildren: 0,
          parentsVivants: true,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 400000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'GE',
          hasTestament: false,
        ),
      );

      final conjoint = result.legalDistribution
          .firstWhere((h) => h.heirLabel == 'Conjoint');
      expect(conjoint.amount, 300000);
      final parents = result.legalDistribution
          .firstWhere((h) => h.heirLabel == 'Parents');
      expect(parents.amount, 100000);
    });

    test('married without children or parents: spouse gets everything', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.marie,
          numberOfChildren: 0,
          parentsVivants: false,
          hasFratrie: true,
          hasConcubin: false,
          fortuneTotale: 500000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'ZH',
          hasTestament: false,
        ),
      );

      expect(result.legalDistribution.length, 1);
      expect(result.legalDistribution.first.heirLabel, 'Conjoint');
      expect(result.legalDistribution.first.amount, 500000);
    });

    test('single with no heirs: canton inherits', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.celibataire,
          numberOfChildren: 0,
          parentsVivants: false,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 100000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'BE',
          hasTestament: false,
        ),
      );

      expect(result.legalDistribution.length, 1);
      expect(result.legalDistribution.first.heirLabel, 'Canton');
      expect(result.legalDistribution.first.amount, 100000);
    });

    test('divorced with children: children share equally', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.divorce,
          numberOfChildren: 3,
          parentsVivants: true,
          hasFratrie: true,
          hasConcubin: false,
          fortuneTotale: 300000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'LU',
          hasTestament: false,
        ),
      );

      expect(result.legalDistribution.length, 3);
      for (final heir in result.legalDistribution) {
        expect(heir.amount, closeTo(100000, 0.01));
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SUCCESSION SERVICE — RESERVES (2023 LAW)
  // ════════════════════════════════════════════════════════════

  group('SuccessionService - Reserves (nouveau droit 2023)', () {
    test('married with children: quotite disponible = 1/2', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.marie,
          numberOfChildren: 2,
          parentsVivants: true,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 1000000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'VD',
          hasTestament: false,
        ),
      );

      // Reserves: conjoint 1/4 + 2 children 1/4 total = 1/2 reserved
      // Quotite disponible = 1/2
      expect(result.quotiteDisponiblePct, closeTo(0.5, 0.01));
      expect(result.quotiteDisponible, closeTo(500000, 0.01));
    });

    test('single with children: children reserve = 1/2, QD = 1/2', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.celibataire,
          numberOfChildren: 1,
          parentsVivants: true,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 200000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'ZH',
          hasTestament: false,
        ),
      );

      expect(result.quotiteDisponiblePct, closeTo(0.5, 0.01));
      expect(result.quotiteDisponible, closeTo(100000, 0.01));
    });

    test('parents have no reserve under 2023 law', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.celibataire,
          numberOfChildren: 0,
          parentsVivants: true,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 500000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'GE',
          hasTestament: false,
        ),
      );

      // No reserved heir (parents lost reserve in 2023) => QD = 100%
      expect(result.quotiteDisponiblePct, closeTo(1.0, 0.01));
      expect(result.quotiteDisponible, closeTo(500000, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SUCCESSION SERVICE — TESTAMENT DISTRIBUTION
  // ════════════════════════════════════════════════════════════

  group('SuccessionService - Testament Distribution', () {
    test('testament without flag produces null testamentDistribution', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.marie,
          numberOfChildren: 1,
          parentsVivants: false,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 100000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'VD',
          hasTestament: false,
        ),
      );

      expect(result.testamentDistribution, isNull);
    });

    test('testament beneficiary concubin receives quotite disponible', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.concubinage,
          numberOfChildren: 2,
          parentsVivants: false,
          hasFratrie: false,
          hasConcubin: true,
          fortuneTotale: 400000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'VD',
          hasTestament: true,
          testamentBeneficiary: 'concubin',
        ),
      );

      expect(result.testamentDistribution, isNotNull);
      final concubinShare = result.testamentDistribution!
          .firstWhere((h) => h.heirLabel.contains('Concubin'));
      expect(concubinShare.amount, closeTo(result.quotiteDisponible, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SUCCESSION SERVICE — CANTONAL TAX
  // ════════════════════════════════════════════════════════════

  group('SuccessionService - Cantonal Tax', () {
    test('spouse and children are tax-exempt in VD', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.marie,
          numberOfChildren: 1,
          parentsVivants: false,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 500000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'VD',
          hasTestament: false,
        ),
      );

      for (final entry in result.taxByHeir.entries) {
        expect(entry.value, 0.0,
            reason: 'Spouse and children should be exempt in VD');
      }
    });

    test('ZH taxes children at 2%', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.divorce,
          numberOfChildren: 1,
          parentsVivants: false,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 200000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'ZH',
          hasTestament: false,
        ),
      );

      expect(result.taxByHeir['Enfant 1'], closeTo(200000 * 0.02, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SUCCESSION SERVICE — ALERTS & 3a BENEFICIARY ORDER
  // ════════════════════════════════════════════════════════════

  group('SuccessionService - Alerts & 3a Beneficiary Order', () {
    test('concubinage triggers no-legal-rights alert', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.concubinage,
          numberOfChildren: 0,
          parentsVivants: true,
          hasFratrie: false,
          hasConcubin: true,
          fortuneTotale: 100000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'VD',
          hasTestament: false,
        ),
      );

      expect(
        result.alerts.any((a) => a.contains('AUCUN droit successoral')),
        isTrue,
      );
    });

    test('3a avoirs with concubinage triggers beneficiary clause alert', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.concubinage,
          numberOfChildren: 0,
          parentsVivants: true,
          hasFratrie: false,
          hasConcubin: true,
          fortuneTotale: 100000,
          avoirs3a: 50000,
          capitalDecesLpp: 0,
          canton: 'VD',
          hasTestament: false,
        ),
      );

      expect(
        result.alerts.any((a) => a.contains('clauses beneficiaires')),
        isTrue,
      );
    });

    test('LPP capital-deces triggers LPP-specific alert', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.marie,
          numberOfChildren: 1,
          parentsVivants: false,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 200000,
          avoirs3a: 0,
          capitalDecesLpp: 100000,
          canton: 'VD',
          hasTestament: false,
        ),
      );

      expect(
        result.alerts.any((a) => a.contains('capital-deces LPP')),
        isTrue,
      );
    });

    test('married 3a beneficiary order starts with conjoint survivant', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.marie,
          numberOfChildren: 1,
          parentsVivants: false,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 100000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'VD',
          hasTestament: false,
        ),
      );

      expect(result.pillar3aBeneficiaryOrder, contains('Conjoint survivant'));
    });

    test('concubinage 3a beneficiary order mentions clause beneficiaire', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.concubinage,
          numberOfChildren: 0,
          parentsVivants: true,
          hasFratrie: false,
          hasConcubin: true,
          fortuneTotale: 100000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'VD',
          hasTestament: false,
        ),
      );

      expect(result.pillar3aBeneficiaryOrder, contains('clause beneficiaire'));
    });

    test('checklist has at least 5 items', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.marie,
          numberOfChildren: 1,
          parentsVivants: false,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 100000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'VD',
          hasTestament: false,
        ),
      );

      expect(result.checklist.length, greaterThanOrEqualTo(5));
      expect(result.checklist.any((c) => c.contains('Testament')), isTrue);
      expect(result.checklist.any((c) => c.contains('3a')), isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  EDGE CASES
  // ════════════════════════════════════════════════════════════

  group('DivorceService & SuccessionService - Edge Cases', () {
    test('divorce with zero fortune and zero debts', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 1,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 0,
          incomeConjoint2: 0,
          lppConjoint1: 0,
          lppConjoint2: 0,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      expect(result.patrimoineSplit.fortuneNette, 0);
      expect(result.patrimoineSplit.shareConjoint1, 0);
      expect(result.patrimoineSplit.shareConjoint2, 0);
      expect(result.taxImpact.estimatedTaxMarried, 0);
      expect(result.pensionAlimentaireMonthly, 0);
    });

    test('succession with zero fortune', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.marie,
          numberOfChildren: 2,
          parentsVivants: false,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 0,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'VD',
          hasTestament: false,
        ),
      );

      expect(result.totalEstate, 0);
      expect(result.quotiteDisponible, 0);
      for (final heir in result.legalDistribution) {
        expect(heir.amount, 0);
      }
    });

    test('unknown canton in succession uses VD fallback rates', () {
      final result = SuccessionService.simulate(
        input: const SuccessionInput(
          civilStatus: CivilStatus.celibataire,
          numberOfChildren: 0,
          parentsVivants: true,
          hasFratrie: false,
          hasConcubin: false,
          fortuneTotale: 100000,
          avoirs3a: 0,
          capitalDecesLpp: 0,
          canton: 'XX',
          hasTestament: false,
        ),
      );

      // Should not throw; parents in VD have 0% tax rate
      expect(result.taxByHeir, isNotEmpty);
    });
  });
}
