import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/benchmark_service.dart';

void main() {
  // =========================================================================
  // BENCHMARK SERVICE — Unit tests
  // =========================================================================
  //
  // Tests the anonymous financial benchmark comparison service:
  //   - compareSavings: savings rate vs Swiss median (OFS EBM 2022)
  //   - compare3a: 3a participation & contributions vs Swiss average
  //   - compareEmergencyFund: emergency fund months vs Swiss median
  //   - Age bracket mapping
  //   - Percentile estimation
  //   - Edge cases (zero income, extreme values, boundary ages)
  //
  // Sources: OFS EBM 2022, OFS SILC 2023, OFS/ASA Prévoyance privée 2023.
  // =========================================================================

  group('compareSavings - structure du resultat', () {
    test('returns all expected fields', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5400,
        monthlySavings: 650,
      );

      expect(result.percentile, isA<int>());
      expect(result.medianValue, isA<double>());
      expect(result.userValue, isA<double>());
      expect(result.delta, isA<double>());
      expect(result.bracket, isA<String>());
      expect(result.message, isA<String>());
    });

    test('percentile is clamped between 1 and 99', () {
      // Extremely high savings rate
      final highResult = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5000,
        monthlySavings: 5000, // 100% savings rate
      );
      expect(highResult.percentile, lessThanOrEqualTo(99));
      expect(highResult.percentile, greaterThanOrEqualTo(1));

      // Zero savings
      final lowResult = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5000,
        monthlySavings: 0,
      );
      expect(lowResult.percentile, lessThanOrEqualTo(99));
      expect(lowResult.percentile, greaterThanOrEqualTo(1));
    });

    test('userValue equals input monthlySavings', () {
      final result = BenchmarkService.compareSavings(
        age: 40,
        monthlyNetIncome: 6200,
        monthlySavings: 800,
      );
      expect(result.userValue, 800);
    });

    test('delta equals user savings minus median savings', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5400,
        monthlySavings: 650,
      );
      // median for 25-34 = 5400 * 0.12 = 648
      expect(result.delta, closeTo(650 - 648, 0.01));
    });
  });

  group('compareSavings - tranches d\'age', () {
    test('age 20 maps to bracket 18-24', () {
      final result = BenchmarkService.compareSavings(
        age: 20,
        monthlyNetIncome: 3200,
        monthlySavings: 200,
      );
      expect(result.bracket, '18-24');
    });

    test('age 30 maps to bracket 25-34', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5400,
        monthlySavings: 500,
      );
      expect(result.bracket, '25-34');
    });

    test('age 42 maps to bracket 35-44', () {
      final result = BenchmarkService.compareSavings(
        age: 42,
        monthlyNetIncome: 6200,
        monthlySavings: 600,
      );
      expect(result.bracket, '35-44');
    });

    test('age 50 maps to bracket 45-54', () {
      final result = BenchmarkService.compareSavings(
        age: 50,
        monthlyNetIncome: 6800,
        monthlySavings: 1000,
      );
      expect(result.bracket, '45-54');
    });

    test('age 60 maps to bracket 55-64', () {
      final result = BenchmarkService.compareSavings(
        age: 60,
        monthlyNetIncome: 6500,
        monthlySavings: 1200,
      );
      expect(result.bracket, '55-64');
    });

    test('age 70 maps to bracket 65+', () {
      final result = BenchmarkService.compareSavings(
        age: 70,
        monthlyNetIncome: 4800,
        monthlySavings: 400,
      );
      expect(result.bracket, '65+');
    });
  });

  group('compareSavings - edge cases', () {
    test('zero income returns percentile without division error', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 0,
        monthlySavings: 0,
      );
      expect(result.percentile, isA<int>());
      expect(result.percentile, greaterThanOrEqualTo(1));
      expect(result.percentile, lessThanOrEqualTo(99));
    });

    test('negative savings returns low percentile', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5000,
        monthlySavings: -500,
      );
      expect(result.percentile, lessThan(50));
    });

    test('very high saver gets high percentile', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5000,
        monthlySavings: 2500, // 50% savings rate
      );
      expect(result.percentile, greaterThan(75));
    });
  });

  group('compareSavings - messages en francais', () {
    test('high saver gets positive message', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5000,
        monthlySavings: 2500,
      );
      expect(result.message, contains('plus que'));
      expect(result.message, contains('25-34'));
    });

    test('average saver gets neutral message', () {
      // median rate for 25-34 is 0.12, so ~600 on 5000
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5000,
        monthlySavings: 600,
      );
      expect(result.message, contains('25-34'));
    });
  });

  group('compare3a - avec et sans 3a', () {
    test('no 3a returns adoption rate message', () {
      final result = BenchmarkService.compare3a(
        age: 30,
        has3a: false,
        annualContribution: 0,
      );
      expect(result.userValue, 0);
      expect(result.message, contains('3e pilier'));
      expect(result.message, contains('25-34'));
    });

    test('has 3a with high contribution gets high percentile', () {
      final result = BenchmarkService.compare3a(
        age: 30,
        has3a: true,
        annualContribution: 7258, // max 3a
      );
      expect(result.percentile, greaterThan(50));
      expect(result.userValue, 7258);
    });

    test('has 3a with low contribution gets low percentile', () {
      final result = BenchmarkService.compare3a(
        age: 30,
        has3a: true,
        annualContribution: 1000,
      );
      expect(result.percentile, lessThan(50));
    });

    test('3a median comparison uses CHF 5500', () {
      final result = BenchmarkService.compare3a(
        age: 30,
        has3a: true,
        annualContribution: 5500,
      );
      // At the median, delta should be ~0
      expect(result.delta, closeTo(0, 0.01));
      expect(result.medianValue, 5500);
    });

    test('no 3a percentile reflects adoption rate inverse', () {
      // For 25-34, adoption = 52%, so percentile = (1-0.52)*100 = 48
      final result = BenchmarkService.compare3a(
        age: 30,
        has3a: false,
        annualContribution: 0,
      );
      expect(result.percentile, closeTo(48, 1));
    });
  });

  group('compareEmergencyFund', () {
    test('returns correct bracket and median', () {
      final result = BenchmarkService.compareEmergencyFund(
        age: 30,
        emergencyFundMonths: 2.0,
      );
      expect(result.bracket, '25-34');
      // Median for 25-34 is 1.5 months
      expect(result.medianValue, 1.5);
    });

    test('high fund months gets high percentile', () {
      final result = BenchmarkService.compareEmergencyFund(
        age: 30,
        emergencyFundMonths: 6.0,
      );
      expect(result.percentile, greaterThan(75));
    });

    test('zero fund months gets low percentile', () {
      final result = BenchmarkService.compareEmergencyFund(
        age: 30,
        emergencyFundMonths: 0,
      );
      expect(result.percentile, lessThan(50));
    });

    test('3+ months shows positive message', () {
      final result = BenchmarkService.compareEmergencyFund(
        age: 30,
        emergencyFundMonths: 4.0,
      );
      expect(result.message, contains('mois'));
      expect(result.message, contains('couvre'));
    });

    test('under 3 months shows recommendation message', () {
      final result = BenchmarkService.compareEmergencyFund(
        age: 30,
        emergencyFundMonths: 1.0,
      );
      expect(result.message, contains('3-6 mois'));
      expect(result.message, contains('recommandation'));
    });

    test('elderly bracket has higher median', () {
      final resultYoung = BenchmarkService.compareEmergencyFund(
        age: 30,
        emergencyFundMonths: 3.0,
      );
      final resultOld = BenchmarkService.compareEmergencyFund(
        age: 60,
        emergencyFundMonths: 3.0,
      );
      // At 3 months, younger should rank higher than older
      // because older has higher median (5.0 vs 1.5)
      expect(resultYoung.percentile, greaterThan(resultOld.percentile));
    });
  });
}
