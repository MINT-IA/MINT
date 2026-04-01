import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_core/monte_carlo_service.dart';

void main() {
  // ════════════════════════════════════════════════════════════
  //  1. LppCalculator.adjustedConversionRate
  // ════════════════════════════════════════════════════════════

  group('LppCalculator.adjustedConversionRate', () {
    const baseRate = 0.068; // LPP minimum legal (6.8%)
    const reduction = lppEarlyRetirementRateReduction; // 0.002

    test('retirementAge 65 (standard) returns baseRate unchanged', () async {
      final rate = LppCalculator.adjustedConversionRate(
        baseRate: baseRate,
        retirementAge: 65,
      );
      expect(rate, equals(baseRate));
    });

    test('retirementAge 63 returns baseRate - 2 * reductionPerYear', () async {
      final rate = LppCalculator.adjustedConversionRate(
        baseRate: baseRate,
        retirementAge: 63,
      );
      // 0.068 - 2 * 0.002 = 0.064
      expect(rate, closeTo(0.064, 1e-10));
    });

    test('retirementAge 58 returns clamped rate (>= 0.03)', () async {
      final rate = LppCalculator.adjustedConversionRate(
        baseRate: baseRate,
        retirementAge: 58,
      );
      // 0.068 - 7 * 0.002 = 0.068 - 0.014 = 0.054
      // 0.054 is above 0.03, so no clamping
      expect(rate, closeTo(0.054, 1e-10));
      expect(rate, greaterThanOrEqualTo(0.03));
    });

    test('retirementAge 67 (late retirement) returns baseRate', () async {
      final rate = LppCalculator.adjustedConversionRate(
        baseRate: baseRate,
        retirementAge: 67,
      );
      // >= referenceAge (65), no reduction applied
      expect(rate, equals(baseRate));
    });

    test('retirementAge 70 (very late retirement) returns baseRate', () async {
      final rate = LppCalculator.adjustedConversionRate(
        baseRate: baseRate,
        retirementAge: 70,
      );
      expect(rate, equals(baseRate));
    });

    test('low baseRate (0.04) with early retirement clamps at 0.03', () async {
      final rate = LppCalculator.adjustedConversionRate(
        baseRate: 0.04,
        retirementAge: 58,
        reductionPerYear: reduction,
      );
      // 0.04 - 7 * 0.002 = 0.04 - 0.014 = 0.026
      // Clamped to 0.03
      expect(rate, equals(0.03));
    });

    test('custom referenceAge 64 with retirement at 64 returns baseRate', () async {
      final rate = LppCalculator.adjustedConversionRate(
        baseRate: baseRate,
        retirementAge: 64,
        referenceAge: 64,
      );
      expect(rate, equals(baseRate));
    });

    test('custom referenceAge 64 with retirement at 62 applies 2-year reduction',
        () {
      final rate = LppCalculator.adjustedConversionRate(
        baseRate: baseRate,
        retirementAge: 62,
        referenceAge: 64,
      );
      // 0.068 - 2 * 0.002 = 0.064
      expect(rate, closeTo(0.064, 1e-10));
    });

    test('reduction never goes below 3% floor', () async {
      // Extreme early retirement with high reduction
      final rate = LppCalculator.adjustedConversionRate(
        baseRate: 0.068,
        retirementAge: 45,
        reductionPerYear: 0.005, // aggressive reduction
      );
      // 0.068 - 20 * 0.005 = 0.068 - 0.100 = -0.032 → clamped to 0.03
      expect(rate, equals(0.03));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  2. Monte Carlo conjoint name matching logic
  // ════════════════════════════════════════════════════════════

  group('Monte Carlo conjoint name matching', () {
    // The Monte Carlo service uses this pattern to filter conjoint contributions:
    //   final conjName = conjoint.firstName?.toLowerCase() ?? '';
    //   if (conjName.isEmpty) { amount = 0; }
    //   else { filter by c.id/c.label containing conjName }
    //
    // We test the filtering logic directly with PlannedMonthlyContribution lists.

    final contributions = [
      const PlannedMonthlyContribution(
        id: 'lpp_buyback_lauren',
        label: 'Rachat LPP Lauren',
        amount: 500,
        category: 'lpp_buyback',
      ),
      const PlannedMonthlyContribution(
        id: 'lpp_buyback_julien',
        label: 'Rachat LPP Julien',
        amount: 800,
        category: 'lpp_buyback',
      ),
      const PlannedMonthlyContribution(
        id: '3a_lauren',
        label: '3a Lauren (VIAC)',
        amount: 604,
        category: '3a',
      ),
      const PlannedMonthlyContribution(
        id: '3a_julien',
        label: '3a Julien',
        amount: 604,
        category: '3a',
      ),
      const PlannedMonthlyContribution(
        id: 'epargne_libre_julien',
        label: 'Epargne libre',
        amount: 200,
        category: 'epargne_libre',
      ),
    ];

    test('null firstName produces empty conjName — no matching', () async {
      const String? firstName = null;
      final conjName = firstName?.toLowerCase() ?? '';
      expect(conjName.isEmpty, isTrue);

      // With empty conjName, buyback should be 0
      final double conjAnnualBuyback;
      if (conjName.isEmpty) {
        conjAnnualBuyback = 0;
      } else {
        conjAnnualBuyback = contributions
            .where((c) =>
                c.category == 'lpp_buyback' &&
                (c.id.toLowerCase().contains(conjName) ||
                    c.label.toLowerCase().contains(conjName)))
            .fold(0.0, (sum, c) => sum + c.amount) *
            12;
      }
      expect(conjAnnualBuyback, equals(0));
    });

    test('empty string firstName produces empty conjName — no matching', () async {
      const firstName = '';
      final conjName = firstName.toLowerCase();
      expect(conjName.isEmpty, isTrue);

      final double conj3aMonthly;
      if (conjName.isEmpty) {
        conj3aMonthly = 0;
      } else {
        conj3aMonthly = contributions
            .where((c) =>
                c.category == '3a' &&
                (c.id.toLowerCase().contains(conjName) ||
                    c.label.toLowerCase().contains(conjName)))
            .fold(0.0, (sum, c) => sum + c.amount);
      }
      expect(conj3aMonthly, equals(0));
    });

    test('firstName "Lauren" matches lpp_buyback_lauren contribution', () async {
      const firstName = 'Lauren';
      final conjName = firstName.toLowerCase();
      expect(conjName, equals('lauren'));

      final matchedBuybacks = contributions
          .where((c) =>
              c.category == 'lpp_buyback' &&
              (c.id.toLowerCase().contains(conjName) ||
                  c.label.toLowerCase().contains(conjName)))
          .toList();

      expect(matchedBuybacks.length, equals(1));
      expect(matchedBuybacks[0].id, equals('lpp_buyback_lauren'));
      expect(matchedBuybacks[0].amount, equals(500));
    });

    test('firstName "Lauren" matches 3a_lauren contribution', () async {
      const firstName = 'Lauren';
      final conjName = firstName.toLowerCase();

      final matched3a = contributions
          .where((c) =>
              c.category == '3a' &&
              (c.id.toLowerCase().contains(conjName) ||
                  c.label.toLowerCase().contains(conjName)))
          .toList();

      expect(matched3a.length, equals(1));
      expect(matched3a[0].id, equals('3a_lauren'));
      expect(matched3a[0].amount, equals(604));
    });

    test('firstName "Lauren" does NOT match Julien contributions', () async {
      const firstName = 'Lauren';
      final conjName = firstName.toLowerCase();

      final matchedJulien = contributions
          .where((c) =>
              c.id.toLowerCase().contains('julien') &&
              (c.id.toLowerCase().contains(conjName) ||
                  c.label.toLowerCase().contains(conjName)))
          .toList();

      expect(matchedJulien, isEmpty);
    });

    test('case-insensitive matching works (LAUREN vs lauren)', () async {
      const firstName = 'LAUREN';
      final conjName = firstName.toLowerCase();
      expect(conjName, equals('lauren'));

      final matched = contributions
          .where((c) =>
              c.category == 'lpp_buyback' &&
              (c.id.toLowerCase().contains(conjName) ||
                  c.label.toLowerCase().contains(conjName)))
          .toList();

      expect(matched.length, equals(1));
      expect(matched[0].id, equals('lpp_buyback_lauren'));
    });

    test('label-only match works when id does not contain name', () async {
      final customContributions = [
        const PlannedMonthlyContribution(
          id: 'lpp_buyback_conj',
          label: 'Rachat LPP Marie',
          amount: 300,
          category: 'lpp_buyback',
        ),
      ];
      const firstName = 'Marie';
      final conjName = firstName.toLowerCase();

      final matched = customContributions
          .where((c) =>
              c.category == 'lpp_buyback' &&
              (c.id.toLowerCase().contains(conjName) ||
                  c.label.toLowerCase().contains(conjName)))
          .toList();

      expect(matched.length, equals(1));
      expect(matched[0].amount, equals(300));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  3. ConfidenceScorer constants
  // ════════════════════════════════════════════════════════════

  group('ConfidenceScorer constants', () {
    test('minConfidenceForProjection is 40.0', () async {
      expect(ConfidenceScorer.minConfidenceForProjection, equals(40.0));
    });

    test('minConfidenceForProjection is a double', () async {
      expect(ConfidenceScorer.minConfidenceForProjection, isA<double>());
    });
  });

  // ════════════════════════════════════════════════════════════
  //  4. Monte Carlo integration: conjoint firstName guard
  // ════════════════════════════════════════════════════════════

  group('Monte Carlo integration — conjoint firstName guard', () {
    /// Helper to build a minimal couple profile for Monte Carlo.
    CoachProfile buildCoupleProfile({
      String? conjointFirstName,
      List<PlannedMonthlyContribution> contributions = const [],
    }) {
      return CoachProfile(
        firstName: 'Test',
        birthYear: 1985,
        canton: 'ZH',
        etatCivil: CoachCivilStatus.marie,
        salaireBrutMensuel: 8000,
        conjoint: ConjointProfile(
          firstName: conjointFirstName,
          birthYear: 1987,
          salaireBrutMensuel: 5000,
          prevoyance: const PrevoyanceProfile(
            avoirLppTotal: 100000,
            tauxConversion: 0.068,
            rachatMaximum: 50000,
          ),
        ),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
          tauxConversion: 0.068,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050, 12, 31),
          label: 'Retraite a 65 ans',
        ),
        plannedContributions: contributions,
      );
    }

    test('simulate() with conjoint firstName=null does not crash', () async {
      final profile = buildCoupleProfile(conjointFirstName: null);
      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 10,
        seed: 42,
      );
      expect(result.projection, isNotEmpty);
      expect(result.medianAt65, greaterThan(0));
      expect(result.disclaimer, isNotEmpty);
    });

    test('simulate() with conjoint firstName="" does not crash', () async {
      final profile = buildCoupleProfile(conjointFirstName: '');
      final result = await MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 10,
        seed: 42,
      );
      expect(result.projection, isNotEmpty);
      expect(result.medianAt65, greaterThan(0));
    });

    test('simulate() with conjoint firstName="Lauren" assigns buyback correctly',
        () async {
      final profileWithBuyback = buildCoupleProfile(
        conjointFirstName: 'Lauren',
        contributions: const [
          PlannedMonthlyContribution(
            id: 'lpp_buyback_lauren',
            label: 'Rachat LPP Lauren',
            amount: 500,
            category: 'lpp_buyback',
          ),
          PlannedMonthlyContribution(
            id: 'lpp_buyback_test',
            label: 'Rachat LPP Test',
            amount: 800,
            category: 'lpp_buyback',
          ),
        ],
      );
      final profileWithout = buildCoupleProfile(
        conjointFirstName: 'Lauren',
        contributions: const [],
      );

      final withBuyback = await MonteCarloProjectionService.simulate(
        profile: profileWithBuyback,
        numSimulations: 50,
        seed: 42,
      );
      final withoutBuyback = await MonteCarloProjectionService.simulate(
        profile: profileWithout,
        numSimulations: 50,
        seed: 42,
      );

      // With buybacks, the median income should be higher (more LPP capital)
      expect(withBuyback.medianAt65, greaterThan(withoutBuyback.medianAt65));
    });

    test(
        'simulate() with conjoint firstName=null ignores buyback contributions',
        () async {
      final profileNullName = buildCoupleProfile(
        conjointFirstName: null,
        contributions: const [
          PlannedMonthlyContribution(
            id: 'lpp_buyback_someone',
            label: 'Rachat LPP Someone',
            amount: 500,
            category: 'lpp_buyback',
          ),
        ],
      );
      final profileNoContrib = buildCoupleProfile(
        conjointFirstName: null,
        contributions: const [],
      );

      final withContrib = await MonteCarloProjectionService.simulate(
        profile: profileNullName,
        numSimulations: 50,
        seed: 42,
      );
      final withoutContrib = await MonteCarloProjectionService.simulate(
        profile: profileNoContrib,
        numSimulations: 50,
        seed: 42,
      );

      // With null firstName, buyback contributions should be ignored
      // so results should be identical (same seed)
      expect(withContrib.medianAt65, equals(withoutContrib.medianAt65));
    });

    test('simulate() is deterministic with fixed seed', () async {
      final profile = buildCoupleProfile(conjointFirstName: 'Lauren');
      final run1 = await MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 50,
        seed: 123,
      );
      final run2 = await MonteCarloProjectionService.simulate(
        profile: profile,
        numSimulations: 50,
        seed: 123,
      );

      expect(run1.medianAt65, equals(run2.medianAt65));
      expect(run1.p10At65, equals(run2.p10At65));
      expect(run1.p90At65, equals(run2.p90At65));
      expect(run1.ruinProbability, equals(run2.ruinProbability));
    });
  });
}
