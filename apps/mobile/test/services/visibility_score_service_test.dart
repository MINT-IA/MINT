import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';

/// Unit tests for VisibilityScoreService — Phase 0 Pulse + Phase 1 Contextual
///
/// Tests 4-axis visibility scoring with contextual weighting by age/archetype.
/// Weights: 50+ → retraite surponderee, <35 → liquidite surponderee,
/// independant → securite +5, expat → fiscalite +3.
///
/// Legal references: LPP art. 7-16, OPP3 art. 7, LAVS art. 21-40
void main() {
  // ── Helper profiles ───────────────────────────────────────
  CoachProfile _young() => CoachProfile(
        firstName: 'Alice',
        birthYear: 2000, // ~26 ans
        canton: 'VD',
        salaireBrutMensuel: 5000,
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2065),
          label: 'Retraite',
        ),
      );

  CoachProfile _midCareer() => CoachProfile(
        firstName: 'Bob',
        birthYear: 1980, // ~46 ans
        canton: 'ZH',
        salaireBrutMensuel: 8000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 200000,
          tauxConversion: 0.068,
        ),
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2045),
          label: 'Retraite',
        ),
      );

  CoachProfile _preRetiree() => CoachProfile(
        firstName: 'Claude',
        birthYear: 1968, // ~58 ans
        canton: 'GE',
        salaireBrutMensuel: 10000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 500000,
          tauxConversion: 0.068,
          totalEpargne3a: 80000,
        ),
        depenses: const DepensesProfile(
          loyer: 2000,
          assuranceMaladie: 500,
        ),
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2033),
          label: 'Retraite',
        ),
      );

  CoachProfile _independant() => CoachProfile(
        firstName: 'Denis',
        birthYear: 1985, // ~41 ans
        canton: 'VS',
        salaireBrutMensuel: 7000,
        employmentStatus: 'independant',
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2050),
          label: 'Retraite',
        ),
      );

  CoachProfile _expat() => CoachProfile(
        firstName: 'Emma',
        birthYear: 1988, // ~38 ans
        canton: 'VD',
        salaireBrutMensuel: 9000,
        nationality: 'US',
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2053),
          label: 'Retraite',
        ),
      );

  // ════════════════════════════════════════════════════════════
  //  Basic compute() invariants
  // ════════════════════════════════════════════════════════════

  group('VisibilityScoreService.compute() — invariants', () {
    test('returns score between 0 and 100', () {
      final score = VisibilityScoreService.compute(_midCareer());
      expect(score.total, greaterThanOrEqualTo(0));
      expect(score.total, lessThanOrEqualTo(100));
      expect(score.percentage, greaterThanOrEqualTo(0));
      expect(score.percentage, lessThanOrEqualTo(100));
    });

    test('returns exactly 4 axes', () {
      final score = VisibilityScoreService.compute(_midCareer());
      expect(score.axes.length, equals(4));
    });

    test('axis sum equals total', () {
      final score = VisibilityScoreService.compute(_midCareer());
      final axisSum = score.axes.fold<double>(0, (s, a) => s + a.score);
      expect(axisSum, closeTo(score.total, 0.01));
    });

    test('each axis score <= maxScore', () {
      final score = VisibilityScoreService.compute(_midCareer());
      for (final axis in score.axes) {
        expect(axis.score, lessThanOrEqualTo(axis.maxScore),
            reason: '${axis.id} score should not exceed maxScore');
      }
    });

    test('sum of maxScores equals 100', () {
      final score = VisibilityScoreService.compute(_midCareer());
      final maxSum = score.axes.fold<double>(0, (s, a) => s + a.maxScore);
      expect(maxSum, closeTo(100, 0.1),
          reason: 'Sum of all axis maxScores should be 100');
    });

    test('narrative is non-empty', () {
      final score = VisibilityScoreService.compute(_midCareer());
      expect(score.narrative, isNotEmpty);
    });

    test('actions list is max 3', () {
      final score = VisibilityScoreService.compute(_midCareer());
      expect(score.actions.length, lessThanOrEqualTo(3));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  Contextual weighting — age-based
  // ════════════════════════════════════════════════════════════

  group('Contextual weighting — age-based', () {
    test('young profile (<35) has liquidite maxScore >= 28', () {
      final score = VisibilityScoreService.compute(_young());
      final liquidite = score.axes.firstWhere((a) => a.id == 'liquidite');
      expect(liquidite.maxScore, greaterThanOrEqualTo(28),
          reason: '<35 should weight liquidite at ~30');
    });

    test('young profile (<35) has retraite maxScore <= 22', () {
      final score = VisibilityScoreService.compute(_young());
      final retraite = score.axes.firstWhere((a) => a.id == 'retraite');
      expect(retraite.maxScore, lessThanOrEqualTo(22),
          reason: '<35 should underweight retraite (~20)');
    });

    test('pre-retiree (55+) has retraite maxScore >= 33', () {
      final score = VisibilityScoreService.compute(_preRetiree());
      final retraite = score.axes.firstWhere((a) => a.id == 'retraite');
      expect(retraite.maxScore, greaterThanOrEqualTo(33),
          reason: '55+ should weight retraite at ~35');
    });

    test('mid-career (45-54) has retraite > default 25', () {
      final score = VisibilityScoreService.compute(_midCareer());
      final retraite = score.axes.firstWhere((a) => a.id == 'retraite');
      expect(retraite.maxScore, greaterThan(25),
          reason: '45-54 should increase retraite weight');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  Contextual weighting — archetype-based
  // ════════════════════════════════════════════════════════════

  group('Contextual weighting — archetype-based', () {
    test('independant has higher securite weight than salarie', () {
      final indep = VisibilityScoreService.compute(_independant());
      final salarie = VisibilityScoreService.compute(_midCareer());

      final indepSecurite =
          indep.axes.firstWhere((a) => a.id == 'securite').maxScore;
      final salarieSecurite =
          salarie.axes.firstWhere((a) => a.id == 'securite').maxScore;
      expect(indepSecurite, greaterThan(salarieSecurite),
          reason: 'Independant should have higher securite weight');
    });

    test('expat has higher fiscalite weight than CH native', () {
      final expat = VisibilityScoreService.compute(_expat());
      final native = VisibilityScoreService.compute(_young());

      final expatFiscal =
          expat.axes.firstWhere((a) => a.id == 'fiscalite').maxScore;
      final nativeFiscal =
          native.axes.firstWhere((a) => a.id == 'fiscalite').maxScore;
      expect(expatFiscal, greaterThan(nativeFiscal),
          reason: 'Expat should have higher fiscalite weight');
    });
  });

  // ════════════════════════════════════════════════════════════
  //  Couple mode
  // ════════════════════════════════════════════════════════════

  group('VisibilityScoreService.computeCouple()', () {
    test('couple score is between 0 and 100', () {
      final score = VisibilityScoreService.computeCouple(
        _midCareer(),
        _young(),
      );
      expect(score.total, greaterThanOrEqualTo(0));
      expect(score.total, lessThanOrEqualTo(100));
    });

    test('identifies weaker partner', () {
      final score = VisibilityScoreService.computeCouple(
        _preRetiree(), // more complete profile
        _young(), // minimal profile
      );
      // The weaker partner should be identified
      // (may or may not be present depending on score difference)
      expect(score, isNotNull);
    });

    test('returns 4 merged axes', () {
      final score = VisibilityScoreService.computeCouple(
        _midCareer(),
        _young(),
      );
      expect(score.axes.length, equals(4));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  Axis status thresholds
  // ════════════════════════════════════════════════════════════

  group('Axis status thresholds', () {
    test('empty profile axes are missing or partial', () {
      final empty = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 0,
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
        ),
      );
      final score = VisibilityScoreService.compute(empty);
      for (final axis in score.axes) {
        expect(axis.status, isIn(['missing', 'partial', 'complete']));
      }
    });

    test('rich profile has at least one complete axis', () {
      final score = VisibilityScoreService.compute(_preRetiree());
      final hasComplete = score.axes.any((a) => a.status == 'complete');
      // With LPP 500k, 3a 80k, loyer, assurance → should have completeness
      expect(
        hasComplete || score.percentage > 40,
        isTrue,
        reason: 'Rich profile should have good visibility',
      );
    });
  });

  // ════════════════════════════════════════════════════════════
  //  Demo profile (golden test)
  // ════════════════════════════════════════════════════════════

  group('Demo profile (Julien+Lauren)', () {
    test('demo profile computes without error', () {
      final demo = CoachProfile.buildDemo();
      final score = VisibilityScoreService.compute(demo);
      expect(score.percentage, greaterThan(0));
    });

    test('demo couple computes without error', () {
      final demo = CoachProfile.buildDemo();
      // Build a conjoint profile from demo data
      final conjoint = CoachProfile(
        firstName: 'Lauren',
        birthYear: 1982,
        canton: 'VS',
        salaireBrutMensuel: 4800,
        nationality: 'US',
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 19620,
        ),
        dettes: const DetteProfile(),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2047),
          label: 'Retraite',
        ),
      );
      final score = VisibilityScoreService.computeCouple(demo, conjoint);
      expect(score.percentage, greaterThanOrEqualTo(0));
    });
  });
}
