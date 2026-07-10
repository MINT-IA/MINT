import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/unemployment_calculator.dart';

void main() {
  group('UnemploymentCalculator', () {
    test('caps insured monthly earnings and computes 70 percent benefit', () {
      final result = UnemploymentCalculator.compute(
        monthlyInsuredEarnings: 15000,
        age: 56,
        contributionMonths: 22,
      );

      expect(result.eligible, isTrue);
      expect(result.rate, 0.70);
      expect(result.retainedMonthlyEarnings, 12350);
      expect(result.dailyBenefit, 397.47);
      expect(result.monthlyBenefit, 8644.97);
      expect(result.monthlyLoss, 6355.03);
      expect(result.dailyBenefitCount, 520);
      expect(result.coverageMonths, closeTo(23.908, 0.01));
    });

    test('uses enhanced 80 percent rate for maintenance obligation', () {
      final result = UnemploymentCalculator.compute(
        monthlyInsuredEarnings: 6000,
        age: 35,
        contributionMonths: 18,
        hasChildren: true,
      );

      expect(result.eligible, isTrue);
      expect(result.rate, 0.80);
      expect(result.retainedMonthlyEarnings, 6000);
      expect(result.dailyBenefit, 220.69);
      expect(result.monthlyBenefit, 4800.01);
      expect(result.monthlyLoss, 1199.99);
      expect(result.dailyBenefitCount, 400);
    });

    test('uses 260 days for 12 to 17 contribution months', () {
      final result = UnemploymentCalculator.compute(
        monthlyInsuredEarnings: 6000,
        age: 35,
        contributionMonths: 17,
      );

      expect(result.eligible, isTrue);
      expect(result.dailyBenefitCount, 260);
    });

    test('uses 400 days from 18 contribution months', () {
      final result = UnemploymentCalculator.compute(
        monthlyInsuredEarnings: 6000,
        age: 35,
        contributionMonths: 18,
      );

      expect(result.eligible, isTrue);
      expect(result.dailyBenefitCount, 400);
    });

    test('keeps under-25 users without children at 200 days', () {
      final result = UnemploymentCalculator.compute(
        monthlyInsuredEarnings: 6000,
        age: 24,
        contributionMonths: 18,
      );

      expect(result.eligible, isTrue);
      expect(result.dailyBenefitCount, 200);
    });

    test('lets under-25 users with children reach the contribution bracket',
        () {
      final result = UnemploymentCalculator.compute(
        monthlyInsuredEarnings: 6000,
        age: 24,
        contributionMonths: 18,
        hasChildren: true,
      );

      expect(result.eligible, isTrue);
      expect(result.dailyBenefitCount, 400);
    });

    test('uses 520 days for disability with at least 22 contribution months',
        () {
      final result = UnemploymentCalculator.compute(
        monthlyInsuredEarnings: 6000,
        age: 35,
        contributionMonths: 22,
        hasDisability: true,
      );

      expect(result.eligible, isTrue);
      expect(result.dailyBenefitCount, 520);
    });

    test('keeps invalid salary and insufficient contributions in core result',
        () {
      final invalidSalary = UnemploymentCalculator.compute(
        monthlyInsuredEarnings: 0,
        age: 35,
        contributionMonths: 18,
      );
      final insufficientContributions = UnemploymentCalculator.compute(
        monthlyInsuredEarnings: 6000,
        age: 35,
        contributionMonths: 11,
      );

      expect(invalidSalary.eligible, isFalse);
      expect(invalidSalary.ineligibilityReason,
          UnemploymentIneligibilityReason.invalidMonthlyEarnings);
      expect(invalidSalary.monthlyBenefit, 0);
      expect(insufficientContributions.eligible, isFalse);
      expect(insufficientContributions.ineligibilityReason,
          UnemploymentIneligibilityReason.insufficientContributions);
      expect(insufficientContributions.dailyBenefitCount, 0);
    });
  });
}
