import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/benchmark_service.dart';

void main() {
  // =========================================================================
  // BENCHMARK SERVICE — Unit tests (personal progression, no social comparison)
  // =========================================================================
  //
  // Tests the personal financial progress tracking service:
  //   - compareSavings: savings vs own previous values
  //   - compare3a: 3a contribution progress
  //   - compareEmergencyFund: emergency fund progress vs personal target
  //   - Age bracket mapping
  //   - Edge cases (zero income, extreme values, boundary ages)
  //
  // COMPLIANCE: No social comparison (CLAUDE.md § 6).
  // =========================================================================

  group('compareSavings - structure du resultat', () {
    test('returns all expected fields', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5400,
        monthlySavings: 650,
      );

      expect(result.userValue, isA<double>());
      expect(result.previousValue, isA<double>());
      expect(result.delta, isA<double>());
      expect(result.bracket, isA<String>());
      expect(result.message, isA<String>());
    });

    test('userValue equals input monthlySavings', () {
      final result = BenchmarkService.compareSavings(
        age: 40,
        monthlyNetIncome: 6200,
        monthlySavings: 800,
      );
      expect(result.userValue, 800);
    });

    test('delta equals current minus previous savings', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5400,
        monthlySavings: 650,
        previousMonthlySavings: 500,
      );
      expect(result.delta, closeTo(150, 0.01));
    });

    test('default previousMonthlySavings is 0', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5400,
        monthlySavings: 650,
      );
      expect(result.previousValue, 0);
      expect(result.delta, closeTo(650, 0.01));
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
    test('zero income returns result without division error', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 0,
        monthlySavings: 0,
      );
      expect(result.userValue, 0);
      expect(result.message, isA<String>());
    });

    test('negative savings returns negative delta', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5000,
        monthlySavings: -500,
        previousMonthlySavings: 200,
      );
      expect(result.delta, lessThan(0));
    });

    test('positive progression shows encouraging message', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5000,
        monthlySavings: 2500,
        previousMonthlySavings: 1000,
      );
      expect(result.delta, 1500);
      expect(result.message, contains('plus'));
    });
  });

  group('compareSavings - messages en francais', () {
    test('positive delta shows progression message', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5000,
        monthlySavings: 2500,
        previousMonthlySavings: 1000,
      );
      expect(result.message, contains('plus'));
    });

    test('no previous data shows current amount', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5000,
        monthlySavings: 600,
      );
      expect(result.message, contains('600'));
    });

    test('no social comparison terms in message', () {
      final result = BenchmarkService.compareSavings(
        age: 30,
        monthlyNetIncome: 5000,
        monthlySavings: 2500,
      );
      expect(result.message, isNot(contains('Suisse')));
      expect(result.message, isNot(contains('médiane')));
      expect(result.message, isNot(contains('Top')));
      expect(result.message, isNot(contains('%  des')));
    });
  });

  group('compare3a - avec et sans 3a', () {
    test('no 3a returns encouragement message', () {
      final result = BenchmarkService.compare3a(
        age: 30,
        has3a: false,
        annualContribution: 0,
      );
      expect(result.userValue, 0);
      expect(result.message, contains('3a'));
    });

    test('has 3a with high contribution returns current value', () {
      final result = BenchmarkService.compare3a(
        age: 30,
        has3a: true,
        annualContribution: 7258,
      );
      expect(result.userValue, 7258);
    });

    test('has 3a with progression shows delta', () {
      final result = BenchmarkService.compare3a(
        age: 30,
        has3a: true,
        annualContribution: 5500,
        previousAnnualContribution: 3000,
      );
      expect(result.delta, closeTo(2500, 0.01));
    });

    test('3a message never contains social comparison', () {
      final result = BenchmarkService.compare3a(
        age: 30,
        has3a: true,
        annualContribution: 5500,
      );
      expect(result.message, isNot(contains('cotisant·e·s suisses')));
      expect(result.message, isNot(contains('Top')));
    });

    test('no 3a message encourages without social pressure', () {
      final result = BenchmarkService.compare3a(
        age: 30,
        has3a: false,
        annualContribution: 0,
      );
      expect(result.message, isNot(contains('% des')));
      expect(result.message, isNot(contains('en Suisse')));
    });
  });

  group('compareEmergencyFund', () {
    test('returns correct bracket', () {
      final result = BenchmarkService.compareEmergencyFund(
        age: 30,
        emergencyFundMonths: 2.0,
      );
      expect(result.bracket, '25-34');
    });

    test('high fund months shows positive message', () {
      final result = BenchmarkService.compareEmergencyFund(
        age: 30,
        emergencyFundMonths: 6.0,
      );
      expect(result.message, contains('3-6 mois'));
    });

    test('zero fund months returns result', () {
      final result = BenchmarkService.compareEmergencyFund(
        age: 30,
        emergencyFundMonths: 0,
      );
      expect(result.userValue, 0);
    });

    test('3+ months shows comfort zone message', () {
      final result = BenchmarkService.compareEmergencyFund(
        age: 30,
        emergencyFundMonths: 4.0,
      );
      expect(result.message, contains('mois'));
      expect(result.message, contains('confort'));
    });

    test('under 3 months shows recommendation message', () {
      final result = BenchmarkService.compareEmergencyFund(
        age: 30,
        emergencyFundMonths: 1.0,
      );
      expect(result.message, contains('3-6 mois'));
      expect(result.message, contains('recommandation'));
    });

    test('progression tracked via delta', () {
      final result = BenchmarkService.compareEmergencyFund(
        age: 30,
        emergencyFundMonths: 4.0,
        previousEmergencyFundMonths: 2.0,
      );
      expect(result.delta, closeTo(2.0, 0.01));
      expect(result.message, contains('+'));
    });
  });
}
