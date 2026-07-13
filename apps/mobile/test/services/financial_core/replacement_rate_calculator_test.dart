import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';

void main() {
  group('ReplacementRateCalculator', () {
    test('returns null when retirement income is unknown', () {
      expect(
        ReplacementRateCalculator.calculate(
          monthlyRetirementIncome: null,
          currentMonthlyIncome: 8000,
        ),
        isNull,
      );
    });

    test('returns null when current income is invalid', () {
      for (final currentIncome in <double>[
        0,
        -1,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          ReplacementRateCalculator.calculate(
            monthlyRetirementIncome: 5000,
            currentMonthlyIncome: currentIncome,
          ),
          isNull,
          reason: 'current income $currentIncome must be rejected',
        );
      }
    });

    test('returns null when retirement income is invalid', () {
      for (final retirementIncome in <double>[
        -1,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          ReplacementRateCalculator.calculate(
            monthlyRetirementIncome: retirementIncome,
            currentMonthlyIncome: 8000,
          ),
          isNull,
          reason: 'retirement income $retirementIncome must be rejected',
        );
      }
    });

    test('calculates a positive replacement rate', () {
      expect(
        ReplacementRateCalculator.calculate(
          monthlyRetirementIncome: 5200,
          currentMonthlyIncome: 8000,
        ),
        65,
      );
    });

    test('caps the replacement rate at 150 percent', () {
      expect(
        ReplacementRateCalculator.calculate(
          monthlyRetirementIncome: 6000,
          currentMonthlyIncome: 2000,
        ),
        150,
      );
    });
  });
}
