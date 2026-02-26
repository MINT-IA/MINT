import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

/// Unit tests for FirstJobService
///
/// Tests the first job salary analysis engine that computes:
///   - Salary breakdown (brut -> net with all Swiss social deductions)
///   - 3a eligibility and recommendations
///   - LAMal franchise comparison
///   - First job checklist
///   - Chiffre choc (employer hidden costs)
///
/// Constants verified against:
///   - AVS/AI/APG employee rate: 5.3%
///   - AANP rate: 1.3%
///   - AC rate: 1.1% (below ceiling)
///   - LPP thresholds: seuil 22'680, deduction 26'460, coord min 3'780
///   - 3a plafond with LPP: 7'258 CHF
void main() {
  // ══════════════════════════════════════════════════════════════════════
  // SALARY BREAKDOWN
  // ══════════════════════════════════════════════════════════════════════

  group('Salary breakdown - standard case', () {
    test('computes AVS at 5.3% of gross monthly', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 30,
        canton: 'ZH',
      );

      expect(result.brut, 6000.0);
      expect(result.avsAiApg, closeTo(318.0, 0.1)); // 6000 * 0.053
    });

    test('computes AC at 1.1% when annual salary below AC ceiling', () {
      // 6000 * 12 = 72'000 < 148'200
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 30,
        canton: 'ZH',
      );

      expect(result.ac, closeTo(66.0, 0.1)); // 6000 * 0.011
    });

    test('computes blended AC when annual salary above AC ceiling', () {
      // 13'000 * 12 = 156'000 > 148'200
      // AC = (148200 * 0.011 + (156000 - 148200) * 0.005) / 12
      //    = (1630.2 + 39) / 12 = 139.1
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 13000,
        age: 30,
        canton: 'ZH',
      );

      expect(result.ac, closeTo(139.1, 0.5));
    });

    test('computes AANP at 1.3% of gross', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 30,
        canton: 'ZH',
      );

      expect(result.aanp, closeTo(78.0, 0.1)); // 6000 * 0.013
    });

    test('net = brut minus all deductions', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 30,
        canton: 'ZH',
      );

      final expectedNet =
          result.brut - result.avsAiApg - result.ac - result.aanp - result.lppEmploye;
      expect(result.netEstime, closeTo(expectedNet, 0.01));
      expect(result.totalDeductions,
          closeTo(result.avsAiApg + result.ac + result.aanp + result.lppEmploye, 0.01));
    });

    test('deduction items list includes AVS, AC, AANP', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 30,
        canton: 'ZH',
      );

      final labels = result.deductionItems.map((d) => d.label).toList();
      expect(labels, contains('AVS/AI/APG'));
      expect(labels, contains('Chomage (AC)'));
      expect(labels, contains('AANP'));
    });

    test('deduction items have valid percentages and colors', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 30,
        canton: 'ZH',
      );

      for (final item in result.deductionItems) {
        expect(item.pourcentage, greaterThan(0));
        expect(item.montant, greaterThan(0));
        expect(item.color, startsWith('#'));
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // LPP DEDUCTIONS
  // ══════════════════════════════════════════════════════════════════════

  group('LPP deductions', () {
    test('no LPP for age < 25', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 5000,
        age: 22,
        canton: 'ZH',
      );

      expect(result.lppEmploye, 0.0);
      // deduction items should not include LPP
      final lppItems =
          result.deductionItems.where((d) => d.label.contains('LPP')).toList();
      expect(lppItems, isEmpty);
    });

    test('no LPP when annual salary below seuil entree (22680)', () {
      // 1800 * 12 = 21'600 < 22'680
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 1800,
        age: 30,
        canton: 'ZH',
      );

      expect(result.lppEmploye, 0.0);
    });

    test('LPP applies at age 25+ with salary above seuil', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 30,
        canton: 'ZH',
      );

      expect(result.lppEmploye, greaterThan(0));
      // deduction items should include LPP
      final lppItems =
          result.deductionItems.where((d) => d.label.contains('LPP')).toList();
      expect(lppItems.length, 1);
    });

    test('LPP uses 7% rate for age 25-34', () {
      // Annual: 6000 * 12 = 72'000
      // Coordinated: 72'000 - 26'460 = 45'540
      // Min check: max(45'540, 3'780) = 45'540
      // Max check: min(45'540, 63'540) = 45'540
      // LPP employee: (45'540 * 0.07) / 12 / 2 = 132.825
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 30,
        canton: 'ZH',
      );

      expect(result.lppEmploye, closeTo(132.825, 0.5));
    });

    test('LPP uses 10% rate for age 35-44', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 40,
        canton: 'ZH',
      );

      // (45'540 * 0.10) / 12 / 2 = 189.75
      expect(result.lppEmploye, closeTo(189.75, 0.5));
    });

    test('LPP uses 15% rate for age 45-54', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 50,
        canton: 'ZH',
      );

      // (45'540 * 0.15) / 12 / 2 = 284.625
      expect(result.lppEmploye, closeTo(284.625, 0.5));
    });

    test('LPP uses 18% rate for age 55+', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 60,
        canton: 'ZH',
      );

      // (45'540 * 0.18) / 12 / 2 = 341.55
      expect(result.lppEmploye, closeTo(341.55, 0.5));
    });

    test('LPP coordinated salary respects minimum (3780)', () {
      // Salary just above seuil: annual = 23'000 (1916.67/month)
      // Coordinated: 23'000 - 26'460 = -3'460 -> clamped to min 3'780
      // LPP employee: (3'780 * 0.07) / 12 / 2 = 11.025
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 1917,
        age: 30,
        canton: 'ZH',
      );

      // Annual = 1917 * 12 = 23'004 >= 22'680 -> LPP applies
      expect(result.lppEmploye, closeTo(11.025, 0.5));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // PART-TIME WORK (taux d'activite)
  // ══════════════════════════════════════════════════════════════════════

  group('Part-time (taux activite)', () {
    test('50% activity rate halves the annual salary for thresholds', () {
      // Brut mensuel: 5000, but 50% activity -> annual = 5000 * 12 * 0.5 = 30'000
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 5000,
        age: 30,
        canton: 'ZH',
        tauxActivite: 50.0,
      );

      // Annual = 30'000 > 22'680 -> LPP applies
      // Coordinated: 30'000 - 26'460 = 3'540 -> clamped to min 3'780
      expect(result.lppEmploye, greaterThan(0));
    });

    test('very low activity rate puts annual below LPP seuil', () {
      // Brut mensuel: 5000, 30% activity -> annual = 5000 * 12 * 0.3 = 18'000 < 22'680
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 5000,
        age: 30,
        canton: 'ZH',
        tauxActivite: 30.0,
      );

      expect(result.lppEmploye, 0.0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // 3A RECOMMENDATION
  // ══════════════════════════════════════════════════════════════════════

  group('3a recommendation', () {
    test('always eligible for 3a', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      expect(result.eligible3a, true);
    });

    test('3a plafond matches constant (7258 for salaried with LPP)', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      expect(result.plafondAnnuel3a, pilier3aPlafondAvecLpp);
      expect(result.plafondAnnuel3a, 7258.0);
    });

    test('monthly suggested 3a is plafond / 12', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      expect(result.montantMensuelSuggere3a, closeTo(7258.0 / 12, 0.01));
    });

    test('estimated tax saving is ~25% of 3a max', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      expect(result.economieFiscaleEstimee3a, closeTo(7258.0 * 0.25, 0.01));
    });

    test('3a alerte warns against insurance-linked 3a', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      expect(result.alerte3a, contains('assurance-vie'));
      expect(result.alerte3a, contains('fintech'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // LAMAL FRANCHISE
  // ══════════════════════════════════════════════════════════════════════

  group('LAMal franchise options', () {
    test('returns 6 franchise options (300 to 2500)', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      expect(result.franchiseOptions.length, 6);
      final franchises = result.franchiseOptions.map((f) => f.franchise).toList();
      expect(franchises, [300, 500, 1000, 1500, 2000, 2500]);
    });

    test('higher franchise means lower monthly premium', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      final premiums = result.franchiseOptions.map((f) => f.primeMensuelle).toList();
      // Each successive franchise should have a lower premium
      for (int i = 1; i < premiums.length; i++) {
        expect(premiums[i], lessThan(premiums[i - 1]),
            reason: 'Franchise ${result.franchiseOptions[i].franchise} should have '
                'lower premium than ${result.franchiseOptions[i - 1].franchise}');
      }
    });

    test('recommends franchise 2500 for young healthy person', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      expect(result.franchiseRecommandee, 2500);
    });

    test('annual savings vs 300 is positive', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      expect(result.economieAnnuelleVs300, greaterThan(0));
    });

    test('LAMal note mentions priminfo.admin.ch', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      expect(result.noteLamal, contains('priminfo.admin.ch'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // EMPLOYER CONTRIBUTIONS
  // ══════════════════════════════════════════════════════════════════════

  group('Employer contributions', () {
    test('employer pays matching AVS + LPP + LAA', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 30,
        canton: 'ZH',
      );

      // Employer pays at least AVS matching + LPP matching + LAA (~1.7%)
      expect(result.cotisationsEmployeur, greaterThan(result.avsAiApg));
      expect(result.cotisationsEmployeur, greaterThan(0));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CHECKLIST
  // ══════════════════════════════════════════════════════════════════════

  group('First job checklist', () {
    test('returns at least 5 checklist items', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      expect(result.checklist.length, greaterThanOrEqualTo(5));
    });

    test('checklist includes 3a, LAMal, RC, LPP, declaration', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      final joined = result.checklist.join(' ');
      expect(joined, contains('3a'));
      expect(joined, contains('LAMal'));
      expect(joined, contains('RC'));
      expect(joined, contains('LPP'));
      expect(joined, contains('fiscale'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CHIFFRE CHOC
  // ══════════════════════════════════════════════════════════════════════

  group('Chiffre choc', () {
    test('mentions employer hidden costs', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 30,
        canton: 'ZH',
      );

      expect(result.chiffreChoc, contains('employeur'));
      expect(result.chiffreChoc, contains('CHF'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // EDGE CASES
  // ══════════════════════════════════════════════════════════════════════

  group('Edge cases', () {
    test('very low salary (minimum wage territory)', () {
      // 3500/month = 42'000/year
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 3500,
        age: 25,
        canton: 'GE',
      );

      expect(result.netEstime, greaterThan(0));
      expect(result.netEstime, lessThan(3500));
      expect(result.totalDeductions, greaterThan(0));
    });

    test('very high salary (>12k/month)', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 15000,
        age: 40,
        canton: 'ZH',
      );

      expect(result.netEstime, greaterThan(0));
      expect(result.netEstime, lessThan(15000));
      // AC = blended: (148200 * 0.011 + (180000 - 148200) * 0.005) / 12
      //    = (1630.2 + 159) / 12 = 149.1
      expect(result.ac, closeTo(149.1, 0.5));
    });

    test('age exactly 25 qualifies for LPP', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 25,
        canton: 'ZH',
      );

      expect(result.lppEmploye, greaterThan(0));
    });

    test('age 24 does not qualify for LPP', () {
      final result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: 6000,
        age: 24,
        canton: 'ZH',
      );

      expect(result.lppEmploye, 0.0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // FORMAT HELPERS
  // ══════════════════════════════════════════════════════════════════════

  group('formatChf helper', () {
    test('formats with CHF prefix and Swiss apostrophes', () {
      expect(FirstJobService.formatChf(1234.0), contains('CHF'));
      expect(FirstJobService.formatChf(1234.0), contains("1'234"));
    });

    test('formats large numbers with correct separators', () {
      final formatted = FirstJobService.formatChf(123456.0);
      expect(formatted, contains("123'456"));
    });

    test('formats small numbers without separator', () {
      final formatted = FirstJobService.formatChf(500.0);
      expect(formatted, contains('500'));
    });
  });
}
