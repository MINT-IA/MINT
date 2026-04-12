import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';

/// Unit tests for FinancialFitnessService — Sprint C2 (MINT Coach)
///
/// Tests the Financial Fitness Score calculation with 3 sub-scores,
/// trend analysis, coach messages, and edge cases.
void main() {
  // ════════════════════════════════════════════════════════════
  //  DEMO PROFILE SCORE (Julien+Lauren)
  // ════════════════════════════════════════════════════════════

  group('FinancialFitnessService - Demo profile', () {
    late CoachProfile demo;
    late FinancialFitnessScore score;

    setUp(() {
      demo = CoachProfile.buildDemo();
      score = FinancialFitnessService.calculate(profile: demo);
    });

    test('global score is between 0 and 100', () {
      expect(score.global, greaterThanOrEqualTo(0));
      expect(score.global, lessThanOrEqualTo(100));
    });

    test('sub-scores are between 0 and 100', () {
      expect(score.budget.score, greaterThanOrEqualTo(0));
      expect(score.budget.score, lessThanOrEqualTo(100));
      expect(score.prevoyance.score, greaterThanOrEqualTo(0));
      expect(score.prevoyance.score, lessThanOrEqualTo(100));
      expect(score.patrimoine.score, greaterThanOrEqualTo(0));
      expect(score.patrimoine.score, lessThanOrEqualTo(100));
    });

    test('global is weighted average of sub-scores', () {
      final expected = (score.budget.score * 0.35 +
              score.prevoyance.score * 0.40 +
              score.patrimoine.score * 0.25)
          .round();
      expect(score.global, closeTo(expected, 1));
    });

    test('weights sum to 1.0', () {
      final totalWeight =
          score.budget.weight + score.prevoyance.weight + score.patrimoine.weight;
      expect(totalWeight, closeTo(1.0, 0.001));
    });

    test('level is assigned correctly', () {
      expect(score.level, isNotNull);
      if (score.global >= 80) {
        expect(score.level, FitnessLevel.excellent);
      } else if (score.global >= 60) {
        expect(score.level, FitnessLevel.bon);
      } else if (score.global >= 40) {
        expect(score.level, FitnessLevel.attention);
      } else {
        expect(score.level, FitnessLevel.critique);
      }
    });

    test('coach message is not empty', () {
      expect(score.coachMessage, isNotEmpty);
    });

    test('calculatedAt is recent', () {
      expect(
        score.calculatedAt.difference(DateTime.now()).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('trend is stable without previous score', () {
      expect(score.trend, ScoreTrend.stable);
      expect(score.deltaVsPreviousMonth, isNull);
    });

    test('each sub-score has 4 criteria', () {
      expect(score.budget.criteria.length, 4);
      expect(score.prevoyance.criteria.length, 4);
      expect(score.patrimoine.criteria.length, 4);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  BUDGET SUB-SCORE
  // ════════════════════════════════════════════════════════════

  group('FinancialFitnessService - Budget sub-score', () {
    test('no debt gives 25 points on dette_consommation', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        dettes: const DetteProfile(), // no debt
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final detteCrit = score.budget.criteria
          .firstWhere((c) => c.id == 'dette_consommation');
      expect(detteCrit.points, 25);
    });

    test('consumer debt gives 0 points', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        dettes: const DetteProfile(creditConsommation: 10000),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final detteCrit = score.budget.criteria
          .firstWhere((c) => c.id == 'dette_consommation');
      expect(detteCrit.points, 0);
    });

    test('leasing counts as consumer debt', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        dettes: const DetteProfile(leasing: 15000),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final detteCrit = score.budget.criteria
          .firstWhere((c) => c.id == 'dette_consommation');
      expect(detteCrit.points, 0);
    });

    test('high emergency fund gives 25 points', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        depenses: const DepensesProfile(loyer: 1500, assuranceMaladie: 400),
        patrimoine: const PatrimoineProfile(epargneLiquide: 30000), // >> 3 months
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final fondsCrit = score.budget.criteria
          .firstWhere((c) => c.id == 'fonds_urgence');
      expect(fondsCrit.points, 25);
    });

    test('zero emergency fund gives 0 points', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        depenses: const DepensesProfile(loyer: 2000, assuranceMaladie: 500),
        patrimoine: const PatrimoineProfile(epargneLiquide: 0),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final fondsCrit = score.budget.criteria
          .firstWhere((c) => c.id == 'fonds_urgence');
      expect(fondsCrit.points, 0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  PREVOYANCE SUB-SCORE
  // ════════════════════════════════════════════════════════════

  group('FinancialFitnessService - Prevoyance sub-score', () {
    test('maxed 3a gives 25 points', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a',
            label: '3a',
            amount: 604.83, // 7258/12
            category: '3a',
          ),
        ],
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final threACrit = score.prevoyance.criteria
          .firstWhere((c) => c.id == '3a_maximise');
      expect(threACrit.points, 25);
    });

    test('no 3a contribution gives 0 points', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final threACrit = score.prevoyance.criteria
          .firstWhere((c) => c.id == '3a_maximise');
      expect(threACrit.points, 0);
    });

    test('LPP lacune comblee gives 25 points', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
          rachatMaximum: 200000, // All bought back
          rachatEffectue: 200000,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final lppCrit = score.prevoyance.criteria
          .firstWhere((c) => c.id == 'lpp_buyback');
      expect(lppCrit.points, 25);
    });

    test('no AVS gaps gives 25 points', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        prevoyance: const PrevoyanceProfile(lacunesAVS: 0),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final avsCrit = score.prevoyance.criteria
          .firstWhere((c) => c.id == 'avs_gaps');
      expect(avsCrit.points, 25);
    });

    test('many AVS gaps gives 0 points', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        prevoyance: const PrevoyanceProfile(lacunesAVS: 10),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final avsCrit = score.prevoyance.criteria
          .firstWhere((c) => c.id == 'avs_gaps');
      expect(avsCrit.points, 0);
    });

    test('couple AVS gaps are cumulated', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        etatCivil: CoachCivilStatus.marie,
        prevoyance: const PrevoyanceProfile(lacunesAVS: 2),
        conjoint: const ConjointProfile(
          prevoyance: PrevoyanceProfile(lacunesAVS: 14),
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final avsCrit = score.prevoyance.criteria
          .firstWhere((c) => c.id == 'avs_gaps');
      // 2 + 14 = 16 → 0 points
      expect(avsCrit.points, 0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  PATRIMOINE SUB-SCORE
  // ════════════════════════════════════════════════════════════

  group('FinancialFitnessService - Patrimoine sub-score', () {
    test('high investment ratio gives 25 points', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 5000,
          investissements: 100000, // 95% invested
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final investCrit = score.patrimoine.criteria
          .firstWhere((c) => c.id == 'epargne_investie');
      expect(investCrit.points, 25);
    });

    test('diversification with multiple asset classes', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 100000,
          totalEpargne3a: 20000,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 10000,
          investissements: 50000,
          immobilier: 300000,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final divCrit = score.patrimoine.criteria
          .firstWhere((c) => c.id == 'diversification');
      // 5 classes: liquide + invest + immo + 3a + LPP
      expect(divCrit.points, 25);
    });

    test('no contributions gives 0 croissance points', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 7000,
        patrimoine: const PatrimoineProfile(epargneLiquide: 5000),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final croiCrit = score.patrimoine.criteria
          .firstWhere((c) => c.id == 'croissance');
      expect(croiCrit.points, 0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TREND
  // ════════════════════════════════════════════════════════════

  group('FinancialFitnessService - Trend', () {
    test('up trend when score improves', () {
      final demo = CoachProfile.buildDemo();
      final score = FinancialFitnessService.calculate(
        profile: demo,
        previousScore: 50,
      );
      // Demo profile should score > 50
      if (score.global > 50) {
        expect(score.trend, ScoreTrend.up);
        expect(score.deltaVsPreviousMonth, greaterThan(0));
      }
    });

    test('down trend when previous was higher', () {
      final demo = CoachProfile.buildDemo();
      final score = FinancialFitnessService.calculate(
        profile: demo,
        previousScore: 99,
      );
      // Almost certainly below 99
      if (score.global < 99) {
        expect(score.trend, ScoreTrend.down);
        expect(score.deltaVsPreviousMonth, lessThan(0));
      }
    });

    test('stable when same score', () {
      final demo = CoachProfile.buildDemo();
      final score = FinancialFitnessService.calculate(profile: demo);
      final score2 = FinancialFitnessService.calculate(
        profile: demo,
        previousScore: score.global,
      );
      expect(score2.trend, ScoreTrend.stable);
      expect(score2.deltaVsPreviousMonth, 0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  FITNESS LEVEL
  // ════════════════════════════════════════════════════════════

  group('FitnessLevel', () {
    test('level labels are in French', () {
      expect(FitnessLevel.critique.label, contains('stabilisons'));
      expect(FitnessLevel.attention.label, contains('améliorer'));
      expect(FitnessLevel.bon.label, contains('bonne voie'));
      expect(FitnessLevel.excellent.label, contains('avance'));
    });

    test('shortLabel returns short string', () {
      expect(FitnessLevel.critique.shortLabel, 'Critique');
      expect(FitnessLevel.excellent.shortLabel, 'Excellent');
    });
  });

  group('ScoreTrend', () {
    test('symbols are correct', () {
      expect(ScoreTrend.up.symbol, '\u2191');
      expect(ScoreTrend.stable.symbol, '\u2192');
      expect(ScoreTrend.down.symbol, '\u2193');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  COACH MESSAGE
  // ════════════════════════════════════════════════════════════

  group('FinancialFitnessService - Coach message', () {
    test('debt profile gets debt-focused message', () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 5000,
        dettes: const DetteProfile(creditConsommation: 20000, leasing: 15000),
        patrimoine: const PatrimoineProfile(epargneLiquide: 500),
        goalA: GoalA(
          type: GoalAType.debtFree,
          targetDate: DateTime(2028),
          label: 'Sortir des dettes',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      // Message should mention debt or fundamentals
      expect(
        score.coachMessage.contains('dette') ||
            score.coachMessage.contains('fondamentaux') ||
            score.coachMessage.contains('budget'),
        true,
        reason: 'Coach message should address debt: "${score.coachMessage}"',
      );
    });

    test('coach message has no banned terms', () {
      final demo = CoachProfile.buildDemo();
      final score = FinancialFitnessService.calculate(profile: demo);
      expect(score.coachMessage.contains('garanti'), false);
      expect(score.coachMessage.contains('certain'), false);
      expect(score.coachMessage.contains('assure'), false);
      expect(score.coachMessage.contains('optimal'), false);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SERIALIZATION
  // ════════════════════════════════════════════════════════════

  group('FinancialFitnessScore - JSON', () {
    test('toJson produces valid map', () {
      final demo = CoachProfile.buildDemo();
      final score = FinancialFitnessService.calculate(profile: demo);
      final json = score.toJson();

      expect(json['global'], isA<int>());
      expect(json['budget'], isA<Map>());
      expect(json['prevoyance'], isA<Map>());
      expect(json['patrimoine'], isA<Map>());
      expect(json['level'], isA<String>());
      expect(json['trend'], isA<String>());
      expect(json['coachMessage'], isA<String>());
    });
  });

  // ════════════════════════════════════════════════════════════
  //  EDGE CASES
  // ════════════════════════════════════════════════════════════

  group('FinancialFitnessService - Edge cases', () {
    test('minimal profile (no data) gives low score', () {
      final profile = CoachProfile(
        birthYear: 2000,
        canton: 'ZH',
        salaireBrutMensuel: 4000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2065),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      expect(score.global, lessThan(50));
    });

    test('perfect profile gives high score', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'ZH',
        salaireBrutMensuel: 10000,
        depenses: const DepensesProfile(
          loyer: 1500,
          assuranceMaladie: 400,
        ),
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 500000,
          rachatMaximum: 500000,
          rachatEffectue: 500000, // fully bought back
          totalEpargne3a: 100000,
          nombre3a: 5,
          lacunesAVS: 0,
        ),
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 50000, // >> 3 months
          investissements: 200000,
          immobilier: 500000,
        ),
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: '3a', label: '3a', amount: 604.83, category: '3a',
          ),
          PlannedMonthlyContribution(
            id: 'invest', label: 'ETF', amount: 2000, category: 'investissement',
          ),
        ],
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      expect(score.global, greaterThan(70));
      expect(score.level, anyOf(FitnessLevel.bon, FitnessLevel.excellent));
    });

    test('score is deterministic (same input → same output)', () {
      final demo = CoachProfile.buildDemo();
      final score1 = FinancialFitnessService.calculate(profile: demo);
      final score2 = FinancialFitnessService.calculate(profile: demo);
      expect(score1.global, score2.global);
      expect(score1.budget.score, score2.budget.score);
      expect(score1.prevoyance.score, score2.prevoyance.score);
      expect(score1.patrimoine.score, score2.patrimoine.score);
    });

    test('independent without LPP gets 0 invalidite points', () {
      final profile = CoachProfile(
        birthYear: 1985,
        canton: 'VD',
        salaireBrutMensuel: 8000,
        employmentStatus: 'independant',
        prevoyance: const PrevoyanceProfile(avoirLppTotal: 0),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );
      final score = FinancialFitnessService.calculate(profile: profile);
      final invaliditeCrit = score.prevoyance.criteria
          .firstWhere((c) => c.id == 'invalidite');
      expect(invaliditeCrit.points, 0);
    });
  });
}
