import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/confidence/enhanced_confidence_service.dart';

void main() {
  group('EnhancedConfidenceService', () {
    test('scoreCompleteness returns 0 for empty profile', () {
      final score = EnhancedConfidenceService.scoreCompleteness({});
      expect(score, 0);
    });

    test('scoreCompleteness treats false and zero as filled values', () {
      final score = EnhancedConfidenceService.scoreCompleteness({
        'is_married': false,
        'monthly_expenses': 0,
      });
      expect(score, greaterThan(0));
    });

    test('scoreAccuracy returns 0 when there are no field sources', () {
      final score = EnhancedConfidenceService.scoreAccuracy(const []);
      expect(score, 0);
    });

    test('scoreFreshness floors to 25 for old data', () {
      final score = EnhancedConfidenceService.scoreFreshness([
        FieldSource(
          fieldName: 'salaire_brut',
          source: DataSource.userEntry,
          updatedAt: DateTime.now().subtract(const Duration(days: 500)),
          value: 8000,
        ),
      ]);
      expect(score, 25);
    });

    test('computeConfidence enables only basic gate for empty profile', () {
      final result = EnhancedConfidenceService.computeConfidence({}, const []);
      expect(result.featureGates.first.unlocked, isTrue);
      expect(result.featureGates[1].unlocked, isFalse);
    });

    test('computeConfidence unlocks full precision with high quality data', () {
      final profile = <String, dynamic>{
        'salaire_brut': 8000,
        'age': 35,
        'canton': 'VD',
        'lpp_total': 200000,
        'lpp_obligatoire': 120000,
        'lpp_surobligatoire': 80000,
        'conversion_rate_oblig': 6.8,
        'conversion_rate_suroblig': 5.2,
        'buyback_potential': 25000,
        'employee_lpp_contribution': 450,
        'avs_contribution_years': 20,
        'avs_ramd': 85000,
        'pillar_3a_balance': 45000,
        'taxable_income': 100000,
        'taxable_wealth': 150000,
        'mortgage_remaining': 300000,
        'mortgage_rate': 1.7,
        'property_value': 700000,
        'is_married': false,
        'nb_children': 0,
        'monthly_expenses': 4200,
        'taux_marginal': 31.0,
        'is_independant': false,
        'has_lpp': true,
      };

      final fieldSources = profile.entries
          .map(
            (e) => FieldSource(
              fieldName: e.key,
              source: DataSource.openBanking,
              updatedAt: DateTime.now().subtract(const Duration(days: 2)),
              value: e.value,
            ),
          )
          .toList();

      final result =
          EnhancedConfidenceService.computeConfidence(profile, fieldSources);
      expect(result.breakdown.overall, greaterThanOrEqualTo(85));
      expect(result.featureGates.last.unlocked, isTrue);
    });

    test('rankEnrichmentPrompts returns sorted priorities', () {
      final prompts = EnhancedConfidenceService.rankEnrichmentPrompts({}, const []);
      expect(prompts, isNotEmpty);
      for (var i = 0; i < prompts.length; i++) {
        expect(prompts[i].priority, i + 1);
      }
    });
  });
}
