import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════
  //  actualRate parameter on estimateMarginalRate
  // ═══════════════════════════════════════════════════════════

  group('RetirementTaxCalculator.estimateMarginalRate — actualRate', () {
    test('actualRate overrides estimation when valid', () {
      final estimated = RetirementTaxCalculator.estimateMarginalRate(
        120000, 'ZH',
      );
      final withActual = RetirementTaxCalculator.estimateMarginalRate(
        120000, 'ZH',
        actualRate: 0.275,
      );
      expect(withActual, equals(0.275));
      expect(withActual, isNot(equals(estimated)));
    });

    test('actualRate 0.0 falls back to estimation', () {
      final result = RetirementTaxCalculator.estimateMarginalRate(
        100000, 'ZH',
        actualRate: 0.0,
      );
      // Should NOT be 0.0 — should be the estimate
      expect(result, greaterThan(0.05));
    });

    test('actualRate negative falls back to estimation', () {
      final result = RetirementTaxCalculator.estimateMarginalRate(
        100000, 'ZH',
        actualRate: -0.10,
      );
      expect(result, greaterThan(0.05));
    });

    test('actualRate > 0.5 falls back to estimation', () {
      final result = RetirementTaxCalculator.estimateMarginalRate(
        100000, 'ZH',
        actualRate: 0.60,
      );
      expect(result, lessThan(0.5));
    });

    test('actualRate null uses estimation (backward-compatible)', () {
      final result = RetirementTaxCalculator.estimateMarginalRate(
        100000, 'ZH',
      );
      expect(result, greaterThan(0.05));
      expect(result, lessThan(0.5));
    });

    test('actualRate boundary 0.001 is accepted', () {
      final result = RetirementTaxCalculator.estimateMarginalRate(
        100000, 'ZH',
        actualRate: 0.001,
      );
      expect(result, equals(0.001));
    });

    test('actualRate boundary 0.499 is accepted', () {
      final result = RetirementTaxCalculator.estimateMarginalRate(
        100000, 'ZH',
        actualRate: 0.499,
      );
      expect(result, equals(0.499));
    });
  });
}
