import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/partner_estimate_service.dart';

void main() {
  group('PartnerEstimate', () {
    test('fromJson with full fields', () {
      final json = {
        'estimated_salary': 85000.0,
        'estimated_age': 42,
        'estimated_lpp': 120000.0,
        'estimated_3a': 35000.0,
        'estimated_canton': 'VD',
      };
      final estimate = PartnerEstimate.fromJson(json);
      expect(estimate.estimatedSalary, 85000.0);
      expect(estimate.estimatedAge, 42);
      expect(estimate.estimatedLpp, 120000.0);
      expect(estimate.estimated3a, 35000.0);
      expect(estimate.estimatedCanton, 'VD');
    });

    test('fromJson with partial fields', () {
      final json = {
        'estimated_salary': 67000,
        'estimated_age': 43,
      };
      final estimate = PartnerEstimate.fromJson(json);
      expect(estimate.estimatedSalary, 67000.0);
      expect(estimate.estimatedAge, 43);
      expect(estimate.estimatedLpp, isNull);
      expect(estimate.estimated3a, isNull);
      expect(estimate.estimatedCanton, isNull);
    });

    test('fromJson with empty map', () {
      final estimate = PartnerEstimate.fromJson({});
      expect(estimate.estimatedSalary, isNull);
      expect(estimate.estimatedAge, isNull);
      expect(estimate.estimatedLpp, isNull);
      expect(estimate.estimated3a, isNull);
      expect(estimate.estimatedCanton, isNull);
    });

    test('filledCount is 0 for empty estimate', () {
      const estimate = PartnerEstimate();
      expect(estimate.filledCount, 0);
    });

    test('filledCount is 3 for partial estimate', () {
      const estimate = PartnerEstimate(
        estimatedSalary: 80000,
        estimatedAge: 35,
        estimatedCanton: 'ZH',
      );
      expect(estimate.filledCount, 3);
    });

    test('filledCount is 5 for full estimate', () {
      const estimate = PartnerEstimate(
        estimatedSalary: 80000,
        estimatedAge: 35,
        estimatedLpp: 50000,
        estimated3a: 20000,
        estimatedCanton: 'ZH',
      );
      expect(estimate.filledCount, 5);
    });

    test('confidence is 0.0 for empty estimate', () {
      const estimate = PartnerEstimate();
      expect(estimate.confidence, 0.0);
    });

    test('confidence is 0.15 for 3 of 5 fields', () {
      const estimate = PartnerEstimate(
        estimatedSalary: 80000,
        estimatedAge: 35,
        estimatedCanton: 'ZH',
      );
      expect(estimate.confidence, closeTo(0.15, 0.001));
    });

    test('confidence is 0.25 for 5 of 5 fields', () {
      const estimate = PartnerEstimate(
        estimatedSalary: 80000,
        estimatedAge: 35,
        estimatedLpp: 50000,
        estimated3a: 20000,
        estimatedCanton: 'ZH',
      );
      expect(estimate.confidence, 0.25);
    });

    test('confidence is 0.05 for 1 of 5 fields', () {
      const estimate = PartnerEstimate(estimatedSalary: 80000);
      expect(estimate.confidence, closeTo(0.05, 0.001));
    });

    test('isDeclared is false for empty estimate', () {
      const estimate = PartnerEstimate();
      expect(estimate.isDeclared, false);
    });

    test('isDeclared is true for any field set', () {
      const estimate = PartnerEstimate(estimatedAge: 30);
      expect(estimate.isDeclared, true);
    });

    test('missingFields returns all 5 for empty estimate', () {
      const estimate = PartnerEstimate();
      expect(estimate.missingFields, [
        'estimated_salary',
        'estimated_age',
        'estimated_lpp',
        'estimated_3a',
        'estimated_canton',
      ]);
    });

    test('missingFields returns only missing for partial estimate', () {
      const estimate = PartnerEstimate(
        estimatedSalary: 80000,
        estimatedAge: 35,
      );
      expect(estimate.missingFields, [
        'estimated_lpp',
        'estimated_3a',
        'estimated_canton',
      ]);
    });

    test('missingFields returns empty for full estimate', () {
      const estimate = PartnerEstimate(
        estimatedSalary: 80000,
        estimatedAge: 35,
        estimatedLpp: 50000,
        estimated3a: 20000,
        estimatedCanton: 'ZH',
      );
      expect(estimate.missingFields, isEmpty);
    });

    test('copyWith merges correctly', () {
      const original = PartnerEstimate(
        estimatedSalary: 80000,
        estimatedAge: 35,
      );
      final updated = original.copyWith(estimatedLpp: 50000);
      expect(updated.estimatedSalary, 80000);
      expect(updated.estimatedAge, 35);
      expect(updated.estimatedLpp, 50000);
      expect(updated.estimated3a, isNull);
    });

    test('copyWith overwrites existing field', () {
      const original = PartnerEstimate(estimatedSalary: 80000);
      final updated = original.copyWith(estimatedSalary: 90000);
      expect(updated.estimatedSalary, 90000);
    });

    test('toJson round-trips correctly', () {
      const original = PartnerEstimate(
        estimatedSalary: 85000.0,
        estimatedAge: 42,
        estimatedLpp: 120000.0,
        estimated3a: 35000.0,
        estimatedCanton: 'VD',
      );
      final json = original.toJson();
      final roundTripped = PartnerEstimate.fromJson(json);
      expect(roundTripped.estimatedSalary, original.estimatedSalary);
      expect(roundTripped.estimatedAge, original.estimatedAge);
      expect(roundTripped.estimatedLpp, original.estimatedLpp);
      expect(roundTripped.estimated3a, original.estimated3a);
      expect(roundTripped.estimatedCanton, original.estimatedCanton);
    });

    test('toJson omits null fields', () {
      const estimate = PartnerEstimate(estimatedSalary: 80000);
      final json = estimate.toJson();
      expect(json.containsKey('estimated_salary'), true);
      expect(json.containsKey('estimated_age'), false);
      expect(json.containsKey('estimated_lpp'), false);
      expect(json.containsKey('estimated_3a'), false);
      expect(json.containsKey('estimated_canton'), false);
    });

    test('fromJson handles int salary as double', () {
      final json = {'estimated_salary': 80000};
      final estimate = PartnerEstimate.fromJson(json);
      expect(estimate.estimatedSalary, 80000.0);
      expect(estimate.estimatedSalary, isA<double>());
    });
  });
}
