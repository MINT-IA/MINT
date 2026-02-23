import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

void main() {
  group('ConfidenceScorer.score', () {
    test('complete profile → high confidence (>= 70)', () {
      final profile = _buildProfile(
        age: 45,
        salary: 8000,
        canton: 'ZH',
        avoirLpp: 300000,
        epargne3a: 50000,
        patrimoine: 100000,
        employmentStatus: 'salarie',
        tauxConversion: 0.054,
        anneesContribuees: 25,
      );
      final confidence = ConfidenceScorer.score(profile);
      expect(confidence.score, greaterThanOrEqualTo(70));
      expect(confidence.level, equals('high'));
    });

    test('minimal profile → low confidence (< 40)', () {
      final profile = _buildProfile(
        age: 30,
        salary: 0,
        canton: '',
      );
      final confidence = ConfidenceScorer.score(profile);
      expect(confidence.score, lessThan(40));
      expect(confidence.level, equals('low'));
      expect(confidence.prompts, isNotEmpty);
    });

    test('expat without foreign pension → penalty + prompt', () {
      final profile = _buildProfile(
        age: 45,
        salary: 8000,
        canton: 'ZH',
        arrivalAge: 35,
        employmentStatus: 'salarie',
      );
      final confidence = ConfidenceScorer.score(profile);
      final foreignPrompt = confidence.prompts
          .where((p) => p.category == 'foreign_pension')
          .toList();
      expect(foreignPrompt, isNotEmpty);
      expect(
        confidence.assumptions,
        contains(contains('etrangere')),
      );
    });

    test('independent without LPP → no LPP penalty', () {
      final profile = _buildProfile(
        age: 40,
        salary: 6000,
        canton: 'VD',
        employmentStatus: 'independant',
        avoirLpp: null,
      );
      final confidence = ConfidenceScorer.score(profile);
      // Independent without LPP should not lose points for missing LPP
      final lppPrompts =
          confidence.prompts.where((p) => p.category == 'lpp').toList();
      expect(lppPrompts, isEmpty);
    });

    test('prompts ranked by Bayesian EVI (with bayesianResult)', () {
      final profile = _buildProfile(
        age: 30,
        salary: 5000,
        canton: 'ZH',
      );
      final confidence = ConfidenceScorer.score(profile);
      // Prompts should be non-empty and re-ranked by EVI
      expect(confidence.prompts, isNotEmpty);
      // Bayesian result should be attached
      expect(confidence.bayesianResult, isNotNull);
      // Bayesian EVI prompts should also be ranked descending
      final eviPrompts = confidence.bayesianResult!.rankedPrompts;
      for (int i = 0; i < eviPrompts.length - 1; i++) {
        expect(
          eviPrompts[i].evi,
          greaterThanOrEqualTo(eviPrompts[i + 1].evi),
        );
      }
    });

    test('assumptions list populated for missing data', () {
      final profile = _buildProfile(
        age: 35,
        salary: 6000,
        canton: 'GE',
      );
      final confidence = ConfidenceScorer.score(profile);
      expect(confidence.assumptions, isNotEmpty);
      expect(
        confidence.assumptions,
        contains(contains('LPP')),
      );
    });
  });
}

/// Helper to build a CoachProfile for testing.
CoachProfile _buildProfile({
  required int age,
  required double salary,
  required String canton,
  double? avoirLpp,
  double epargne3a = 0,
  double patrimoine = 0,
  String employmentStatus = 'salarie',
  double tauxConversion = 0.068,
  int? anneesContribuees,
  int? arrivalAge,
  String? residencePermit,
}) {
  return CoachProfile(
    firstName: 'Test',
    birthYear: DateTime.now().year - age,
    salaireBrutMensuel: salary,
    canton: canton,
    etatCivil: CoachCivilStatus.celibataire,
    employmentStatus: employmentStatus,
    arrivalAge: arrivalAge,
    residencePermit: residencePermit,
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLpp,
      tauxConversion: tauxConversion,
      totalEpargne3a: epargne3a,
      anneesContribuees: anneesContribuees,
    ),
    patrimoine: PatrimoineProfile(
      epargneLiquide: patrimoine,
    ),
    depenses: const DepensesProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
  );
}
