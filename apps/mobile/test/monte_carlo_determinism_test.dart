import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/monte_carlo_service.dart';

/// Monte Carlo determinism and annual-draw tests.
///
/// Verifies that:
/// 1. Same seed produces same results (determinism).
/// 2. Annual draws produce wider P10-P90 bands than the old
///    sim-level-only approach would (sequence-of-returns risk).
/// 3. FATCA conjoint 3a is excluded when canContribute3a=false.

GoalA _testGoalA() => GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 12, 31),
      label: 'Retraite',
    );

void main() {
  group('Monte Carlo — seed determinism', () {
    late CoachProfile profile;

    setUp(() {
      profile = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        commune: 'Sion',
        etatCivil: CoachCivilStatus.marie,
        nombreEnfants: 2,
        salaireBrutMensuel: 9080,
        nombreDeMois: 13,
        employmentStatus: 'salarie',
        depenses: const DepensesProfile(loyer: 1800, assuranceMaladie: 400),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 180000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 42000,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 20000,
          investissements: 60000,
        ),
        dettes: const DetteProfile(),
        goalA: _testGoalA(),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_julien',
            label: '3a Julien',
            amount: 604.83,
            category: '3a',
          ),
        ],
      );
    });

    test('same seed → identical medianAt65 and ruinProbability', () {
      final r1 = MonteCarloProjectionService.simulate(
        profile: profile,
        seed: 42,
        numSimulations: 100,
      );
      final r2 = MonteCarloProjectionService.simulate(
        profile: profile,
        seed: 42,
        numSimulations: 100,
      );

      expect(r1.medianAt65, r2.medianAt65);
      expect(r1.ruinProbability, r2.ruinProbability);
      expect(r1.p10At65, r2.p10At65);
      expect(r1.p90At65, r2.p90At65);
    });

    test('different seeds → different results', () {
      final r1 = MonteCarloProjectionService.simulate(
        profile: profile,
        seed: 42,
        numSimulations: 100,
      );
      final r2 = MonteCarloProjectionService.simulate(
        profile: profile,
        seed: 99,
        numSimulations: 100,
      );

      // Extremely unlikely to be identical with different seeds
      expect(r1.medianAt65 == r2.medianAt65, isFalse);
    });

    test('annual returns produce meaningful P10-P90 spread', () {
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        seed: 42,
        numSimulations: 200,
      );

      // P90 should be significantly higher than P10
      // (sequence-of-returns risk creates spread)
      expect(result.p90At65, greaterThan(result.p10At65));
      final spread = result.p90At65 - result.p10At65;
      // Spread should be at least 500 CHF/month for a typical profile
      expect(spread, greaterThan(500));
    });

    test('disclaimer mentions annual draws', () {
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        seed: 42,
        numSimulations: 50,
      );
      expect(result.disclaimer, contains('tirages annuels'));
    });

    test('sources include legal references', () {
      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        seed: 42,
        numSimulations: 50,
      );
      expect(result.sources, isNotEmpty);
      expect(result.sources.any((s) => s.contains('LPP')), isTrue);
      expect(result.sources.any((s) => s.contains('LAVS')), isTrue);
    });
  });

  group('Monte Carlo — FATCA 3a guard (C01)', () {
    test('conjoint canContribute3a=false → no conjoint 3a projected', () {
      // Profile with FATCA conjoint (cannot contribute to 3a)
      final fatcaProfile = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        commune: 'Sion',
        etatCivil: CoachCivilStatus.marie,
        nombreEnfants: 2,
        salaireBrutMensuel: 9080,
        nombreDeMois: 13,
        employmentStatus: 'salarie',
        depenses: const DepensesProfile(loyer: 1800, assuranceMaladie: 400),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 180000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 42000,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 20000,
          investissements: 60000,
        ),
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042, 12, 31),
          label: 'Retraite',
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_julien',
            label: '3a Julien',
            amount: 604.83,
            category: '3a',
          ),
        ],
        conjoint: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1981,
          salaireBrutMensuel: 5000,
          employmentStatus: 'salarie',
          prevoyance: PrevoyanceProfile(
            avoirLppTotal: 60000,
            tauxConversion: 0.068,
            rendementCaisse: 0.02,
            totalEpargne3a: 15000,
            canContribute3a: false, // FATCA restriction
          ),
        ),
      );

      // With FATCA restriction
      final r1 = MonteCarloProjectionService.simulate(
        profile: fatcaProfile,
        seed: 42,
        numSimulations: 100,
      );

      // Same profile but conjoint CAN contribute to 3a
      final nonFatcaProfile = CoachProfile(
        firstName: 'Julien',
        birthYear: 1977,
        canton: 'VS',
        commune: 'Sion',
        etatCivil: CoachCivilStatus.marie,
        nombreEnfants: 2,
        salaireBrutMensuel: 9080,
        nombreDeMois: 13,
        employmentStatus: 'salarie',
        depenses: const DepensesProfile(loyer: 1800, assuranceMaladie: 400),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 180000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 42000,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 20000,
          investissements: 60000,
        ),
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042, 12, 31),
          label: 'Retraite',
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a_julien',
            label: '3a Julien',
            amount: 604.83,
            category: '3a',
          ),
        ],
        conjoint: const ConjointProfile(
          firstName: 'Lauren',
          birthYear: 1981,
          salaireBrutMensuel: 5000,
          employmentStatus: 'salarie',
          prevoyance: PrevoyanceProfile(
            avoirLppTotal: 60000,
            tauxConversion: 0.068,
            rendementCaisse: 0.02,
            totalEpargne3a: 15000,
            canContribute3a: true, // No FATCA restriction
          ),
        ),
      );

      final r2 = MonteCarloProjectionService.simulate(
        profile: nonFatcaProfile,
        seed: 42,
        numSimulations: 100,
      );

      // FATCA profile should have lower median (no conjoint 3a growth)
      expect(r1.medianAt65, lessThan(r2.medianAt65));
    });
  });

  group('Monte Carlo — alertes and compliance', () {
    test('early retirement before 63 triggers bridge alert', () {
      final profile = CoachProfile(
        firstName: 'Marc',
        birthYear: 1985,
        canton: 'GE',
        commune: 'Geneve',
        etatCivil: CoachCivilStatus.celibataire,
        nombreEnfants: 0,
        salaireBrutMensuel: 7000,
        nombreDeMois: 12,
        employmentStatus: 'salarie',
        depenses: const DepensesProfile(loyer: 1500, assuranceMaladie: 400),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 100000,
          tauxConversion: 0.068,
          rendementCaisse: 0.02,
          totalEpargne3a: 20000,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 10000,
          investissements: 50000,
        ),
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2045, 12, 31),
          label: 'Retraite',
        ),
        plannedContributions: const [],
      );

      final result = MonteCarloProjectionService.simulate(
        profile: profile,
        retirementAgeUser: 60,
        seed: 42,
        numSimulations: 50,
      );

      // Should warn about no AVS for 3 years (60→63)
      expect(
        result.alertes.any((a) => a.contains('aucune rente AVS')),
        isTrue,
      );
    });
  });
}
