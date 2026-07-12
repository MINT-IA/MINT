import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/confidence/coach_profile_confidence_adapter.dart';

void main() {
  group('EnhancedConfidenceService CoachProfile adapter', () {
    test('defaults do not become complete, accurate, or fresh facts', () {
      final result = CoachProfileConfidenceAdapter.compute(
        CoachProfile.defaults(),
      );

      expect(result.breakdown.completeness, 0);
      expect(result.breakdown.accuracy, 0);
      expect(result.breakdown.freshness, 0);
    });

    test('an explicitly sourced field is counted', () {
      final now = DateTime.now();
      final profile = CoachProfile.defaults().copyWith(
        birthYear: 1985,
        dataSources: const {'age': ProfileDataSource.userInput},
        dataTimestamps: {'age': now},
      );

      final result = CoachProfileConfidenceAdapter.compute(profile);

      expect(result.breakdown.completeness, greaterThan(0));
      expect(result.breakdown.accuracy, greaterThan(0));
      expect(result.breakdown.freshness, greaterThan(0));
    });

    test('propertyMarketValue source maps to property_value on every axis', () {
      final now = DateTime.now();
      final profile = CoachProfile.defaults().copyWith(
        patrimoine: const PatrimoineProfile(propertyMarketValue: 850000),
        dataSources: const {
          'patrimoine.propertyMarketValue': ProfileDataSource.userInput,
        },
        dataTimestamps: {
          'patrimoine.propertyMarketValue': now,
        },
      );

      final result = CoachProfileConfidenceAdapter.compute(profile);

      expect(result.breakdown.completeness, greaterThan(0));
      expect(result.breakdown.accuracy, greaterThan(0));
      expect(result.breakdown.freshness, greaterThan(0));
    });

    test('legacy property provenance alias is not silently accepted', () {
      final profile = CoachProfile.defaults().copyWith(
        patrimoine: const PatrimoineProfile(propertyMarketValue: 850000),
        dataSources: const {
          'patrimoine.valeurImmobiliere': ProfileDataSource.userInput,
        },
      );

      final result = CoachProfileConfidenceAdapter.compute(profile);

      expect(result.breakdown.completeness, 0);
      expect(result.breakdown.accuracy, 0);
      expect(result.breakdown.freshness, 0);
    });
  });
}
