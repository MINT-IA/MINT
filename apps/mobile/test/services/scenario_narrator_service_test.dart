import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/scenario_narrator_service.dart';

/// Tests for ScenarioNarratorService (Sprint S37).
///
/// Validates 3-scenario narration, compliance fields (disclaimer, sources),
/// CHF formatting, and educational tone.
void main() {
  group('ScenarioNarratorService.narrate — structure', () {
    test('returns exactly 3 scenarios', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      expect(result.scenarios.length, 3);
    });

    test('scenarios are in order: prudent, base, optimiste', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      expect(result.scenarios[0].label, contains('prudent'));
      expect(result.scenarios[1].label, contains('reference'));
      expect(result.scenarios[2].label, contains('favorable'));
    });

    test('return assumptions match expected rates', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      expect(result.scenarios[0].annualReturnPct, 1.0);
      expect(result.scenarios[1].annualReturnPct, 4.5);
      expect(result.scenarios[2].annualReturnPct, 7.0);
    });

    test('capital and monthly values are preserved', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      expect(result.scenarios[0].capitalFinal, 500000);
      expect(result.scenarios[0].monthlyIncome, 2500);
      expect(result.scenarios[1].capitalFinal, 800000);
      expect(result.scenarios[2].monthlyIncome, 6000);
    });
  });

  group('ScenarioNarratorService.narrate — narratives', () {
    test('each narrative mentions the return assumption', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      expect(result.scenarios[0].narrative, contains('1%'));
      expect(result.scenarios[1].narrative, contains('4.5%'));
      expect(result.scenarios[2].narrative, contains('7%'));
    });

    test('each narrative mentions uncertainty', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      for (final scenario in result.scenarios) {
        // Each narrative must mention uncertainty / unpredictability
        final hasUncertainty = scenario.narrative.contains('incertitude') ||
            scenario.narrative.contains('estimations') ||
            scenario.narrative.contains('dependront') ||
            scenario.narrative.contains('exactitude');
        expect(hasUncertainty, true,
            reason:
                '${scenario.label} narrative must mention uncertainty (compliance)');
      }
    });

    test('narratives include firstName', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
        firstName: 'Julien',
      );

      for (final scenario in result.scenarios) {
        expect(scenario.narrative, contains('Julien'));
      }
    });

    test('default firstName is "utilisateur"', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      for (final scenario in result.scenarios) {
        expect(scenario.narrative, contains('utilisateur'));
      }
    });

    test('narratives contain formatted CHF amounts', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      // 500000 → 500'000, 2500 → 2'500
      expect(result.scenarios[0].narrative, contains("500'000"));
      expect(result.scenarios[0].narrative, contains("2'500"));
      // 1200000 → 1'200'000
      expect(result.scenarios[2].narrative, contains("1'200'000"));
    });
  });

  group('ScenarioNarratorService.narrate — compliance fields', () {
    test('disclaimer mentions LSFin', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      expect(result.disclaimer, contains('LSFin'));
    });

    test('disclaimer mentions educational purpose', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      expect(result.disclaimer, contains('educatif'));
      expect(result.disclaimer, contains('conseil'));
    });

    test('sources include LAVS, LPP, OPP3', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      expect(result.sources.any((s) => s.contains('LAVS')), true);
      expect(result.sources.any((s) => s.contains('LPP')), true);
      expect(result.sources.any((s) => s.contains('OPP3')), true);
    });

    test('disclaimer uses inclusive language (specialiste)', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      expect(result.disclaimer, contains('specialiste'));
    });

    test('narratives do NOT contain banned terms', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500000,
        prudentMonthly: 2500,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      const bannedTerms = [
        'garanti',
        'certain',
        'sans risque',
        'optimal',
        'meilleur',
        'parfait',
      ];

      for (final scenario in result.scenarios) {
        for (final term in bannedTerms) {
          expect(scenario.narrative.toLowerCase().contains(term), false,
              reason:
                  '${scenario.label} must not contain banned term "$term"');
        }
      }
    });
  });

  group('ScenarioNarratorService — CHF formatting', () {
    test('formats large numbers with apostrophe grouping', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 1250000,
        prudentMonthly: 5833,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      expect(result.scenarios[0].narrative, contains("1'250'000"));
      expect(result.scenarios[0].narrative, contains("5'833"));
    });

    test('formats small numbers without apostrophe', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 500,
        prudentMonthly: 100,
        baseCapital: 800,
        baseMonthly: 200,
        optimisteCapital: 1000,
        optimisteMonthly: 300,
      );

      expect(result.scenarios[0].narrative, contains('500'));
      expect(result.scenarios[0].narrative, contains('100'));
    });

    test('handles zero values gracefully', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 0,
        prudentMonthly: 0,
        baseCapital: 0,
        baseMonthly: 0,
        optimisteCapital: 0,
        optimisteMonthly: 0,
      );

      // Should not crash
      expect(result.scenarios.length, 3);
      for (final scenario in result.scenarios) {
        expect(scenario.narrative.isNotEmpty, true);
      }
    });
  });

  group('ScenarioNarratorService — edge cases', () {
    test('negative capital is formatted correctly', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: -50000,
        prudentMonthly: 0,
        baseCapital: 800000,
        baseMonthly: 4000,
        optimisteCapital: 1200000,
        optimisteMonthly: 6000,
      );

      // Should handle negative values without crashing
      expect(result.scenarios[0].narrative.isNotEmpty, true);
      expect(result.scenarios[0].capitalFinal, -50000);
    });

    test('very large values are formatted correctly', () {
      final result = ScenarioNarratorService.narrate(
        prudentCapital: 10000000,
        prudentMonthly: 50000,
        baseCapital: 15000000,
        baseMonthly: 75000,
        optimisteCapital: 25000000,
        optimisteMonthly: 125000,
      );

      expect(result.scenarios[0].narrative, contains("10'000'000"));
    });
  });
}
