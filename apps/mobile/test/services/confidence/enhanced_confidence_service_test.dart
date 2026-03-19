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

    // ════════════════════════════════════════════════════════════
    //  BATCH 3: Boundary tests for each axis
    // ════════════════════════════════════════════════════════════

    test('scoreCompleteness returns 100 for fully filled profile', () {
      final profile = <String, dynamic>{
        'age': 49,
        'canton': 'VS',
        'salaire_brut': 122207,
        'salaire_net': 95000,
        'lpp_total': 70377,
        'lpp_obligatoire': 50000,
        'lpp_surobligatoire': 20377,
        'lpp_insured_salary': 95000,
        'conversion_rate_oblig': 6.8,
        'conversion_rate_suroblig': 5.2,
        'buyback_potential': 539414,
        'employee_lpp_contribution': 450,
        'avs_contribution_years': 27,
        'avs_ramd': 85000,
        'pillar_3a_balance': 32000,
        'taux_marginal': 31.0,
        'taxable_income': 100000,
        'taxable_wealth': 150000,
        'mortgage_remaining': 0,
        'mortgage_rate': 0,
        'property_value': 0,
        'is_married': true,
        'nb_children': 0,
        'monthly_expenses': 4200,
        'is_independant': false,
        'has_lpp': true,
      };

      final score = EnhancedConfidenceService.scoreCompleteness(profile);
      expect(score, 100.0);
    });

    test('scoreAccuracy returns 100 for all openBanking sources', () {
      final sources = [
        FieldSource(
          fieldName: 'salaire_brut',
          source: DataSource.openBanking,
          updatedAt: DateTime.now(),
          value: 122207,
        ),
        FieldSource(
          fieldName: 'lpp_total',
          source: DataSource.openBanking,
          updatedAt: DateTime.now(),
          value: 70377,
        ),
      ];

      final score = EnhancedConfidenceService.scoreAccuracy(sources);
      expect(score, 100.0);
    });

    test('scoreAccuracy returns 25 for all systemEstimate sources', () {
      final sources = [
        FieldSource(
          fieldName: 'salaire_brut',
          source: DataSource.systemEstimate,
          updatedAt: DateTime.now(),
          value: 80000,
        ),
        FieldSource(
          fieldName: 'lpp_total',
          source: DataSource.systemEstimate,
          updatedAt: DateTime.now(),
          value: 50000,
        ),
      ];

      final score = EnhancedConfidenceService.scoreAccuracy(sources);
      expect(score, 25.0);
    });

    test('scoreFreshness returns 100 for very recent data', () {
      final sources = [
        FieldSource(
          fieldName: 'salaire_brut',
          source: DataSource.userEntry,
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          value: 8000,
        ),
        FieldSource(
          fieldName: 'lpp_total',
          source: DataSource.userEntry,
          updatedAt: DateTime.now().subtract(const Duration(days: 5)),
          value: 70000,
        ),
      ];

      final score = EnhancedConfidenceService.scoreFreshness(sources);
      expect(score, 100.0);
    });

    test('scoreFreshness decays for mixed-age data', () {
      final sources = [
        FieldSource(
          fieldName: 'salaire_brut',
          source: DataSource.userEntry,
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          value: 8000,
        ),
        FieldSource(
          fieldName: 'lpp_total',
          source: DataSource.userEntry,
          updatedAt: DateTime.now().subtract(const Duration(days: 200)),
          value: 70000,
        ),
      ];

      final score = EnhancedConfidenceService.scoreFreshness(sources);
      // Mix of fresh (1.0) and 6-12 month old (0.50) → between 50 and 100
      expect(score, greaterThan(50));
      expect(score, lessThan(100));
    });

    test('ConfidenceBreakdown.overall is weighted 40/35/25', () {
      const breakdown = ConfidenceBreakdown(
        completeness: 100,
        accuracy: 100,
        freshness: 100,
      );
      expect(breakdown.overall, 100.0);

      const half = ConfidenceBreakdown(
        completeness: 50,
        accuracy: 50,
        freshness: 50,
      );
      expect(half.overall, 50.0);

      // Weighted check: 80*0.4 + 60*0.35 + 40*0.25 = 32+21+10 = 63
      const mixed = ConfidenceBreakdown(
        completeness: 80,
        accuracy: 60,
        freshness: 40,
      );
      expect(mixed.overall, closeTo(63.0, 0.01));
    });

    test('computeConfidence feature gates unlock progressively', () {
      // Medium profile → some gates unlocked
      final profile = <String, dynamic>{
        'salaire_brut': 8000,
        'age': 35,
        'canton': 'VD',
        'lpp_total': 200000,
        'lpp_obligatoire': 120000,
        'avs_contribution_years': 20,
        'is_married': false,
        'monthly_expenses': 4200,
      };

      final fieldSources = profile.entries
          .map((e) => FieldSource(
                fieldName: e.key,
                source: DataSource.userEntry,
                updatedAt: DateTime.now().subtract(const Duration(days: 60)),
                value: e.value,
              ))
          .toList();

      final result =
          EnhancedConfidenceService.computeConfidence(profile, fieldSources);

      // With ~8 fields at userEntry and 60-day freshness, overall should
      // be moderate (30-70 range).
      expect(result.breakdown.overall, greaterThanOrEqualTo(20));
      expect(result.breakdown.overall, lessThan(85));

      // Basic gate always unlocked
      expect(result.featureGates.first.unlocked, isTrue);

      // Disclaimer and sources always present
      expect(result.disclaimer, isNotEmpty);
      expect(result.sources, isNotEmpty);
    });

    test('scoreCompleteness handles NaN value as not filled', () {
      final profile = <String, dynamic>{
        'salaire_brut': double.nan,
        'age': 35,
      };

      final score = EnhancedConfidenceService.scoreCompleteness(profile);
      // age is filled, salaire_brut is NaN (not filled)
      // Only 'age' weight (1.0) out of total weights
      expect(score, greaterThan(0));
      expect(score, lessThan(20)); // Only 1 of ~25 fields filled
    });

    test('scoreCompleteness treats empty string as not filled', () {
      final profile = <String, dynamic>{
        'canton': '',
        'age': 49,
      };

      final score = EnhancedConfidenceService.scoreCompleteness(profile);
      // 'canton' is empty string → not filled; only 'age' counts
      final sameWithoutEmpty = <String, dynamic>{
        'age': 49,
      };
      final scoreWithout =
          EnhancedConfidenceService.scoreCompleteness(sameWithoutEmpty);
      expect(score, scoreWithout);
    });

    test('rankEnrichmentPrompts suggests openBanking when not connected', () {
      final profile = <String, dynamic>{
        'salaire_brut': 8000,
        'age': 35,
      };

      // No openBanking source
      final sources = [
        FieldSource(
          fieldName: 'salaire_brut',
          source: DataSource.userEntry,
          updatedAt: DateTime.now(),
          value: 8000,
        ),
      ];

      final prompts =
          EnhancedConfidenceService.rankEnrichmentPrompts(profile, sources);

      // Should suggest connecting bLink
      final obPrompt =
          prompts.where((p) => p.fieldName == 'open_banking').toList();
      expect(obPrompt, isNotEmpty);
      expect(obPrompt.first.method, 'openBanking');
    });

    test('rankEnrichmentPrompts does NOT suggest openBanking when already connected', () {
      final profile = <String, dynamic>{
        'salaire_brut': 8000,
      };

      final sources = [
        FieldSource(
          fieldName: 'salaire_brut',
          source: DataSource.openBanking,
          updatedAt: DateTime.now(),
          value: 8000,
        ),
      ];

      final prompts =
          EnhancedConfidenceService.rankEnrichmentPrompts(profile, sources);

      final obPrompt =
          prompts.where((p) => p.fieldName == 'open_banking').toList();
      expect(obPrompt, isEmpty);
    });
  });
}
