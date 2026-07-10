import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/independent_hub_calculator.dart';

void main() {
  group('IndependentHubCalculator', () {
    test('estimates the libre-passage rescue balance proxy', () {
      expect(
        IndependentHubCalculator.estimatedLppRescueBalance(120000),
        closeTo(18000, 0.01),
      );
    });

    test('uses LPP bonification, not AVS, for the Jour J LPP monthly line', () {
      const annualIncome = 120000.0;
      const age = 44;

      expect(
        IndependentHubCalculator.employeeLppMonthly(annualIncome, age),
        closeTo(annualIncome * getLppBonificationRate(age) / 12, 0.01),
      );
      expect(
        IndependentHubCalculator.employeeLppMonthly(annualIncome, age),
        isNot(closeTo(
          IndependentHubCalculator.employeeAvsMonthly(annualIncome),
          0.01,
        )),
      );
    });

    test('uses LPP bonification rates at material age boundaries', () {
      const annualIncome = 120000.0;

      for (final age in [24, 25, 35, 45, 55]) {
        expect(
          IndependentHubCalculator.employeeLppMonthly(annualIncome, age),
          closeTo(annualIncome * getLppBonificationRate(age) / 12, 0.01),
          reason: 'age $age',
        );
      }
    });

    test('caps grand 3a tax savings at the legal no-LPP ceiling', () {
      expect(
        IndependentHubCalculator.grand3aTaxSavings(500000),
        closeTo(pilier3aPlafondSansLpp * 0.25, 0.01),
      );
    });

    test('builds the required revenue stack from named proxy layers', () {
      const desiredNetIncome = 100000.0;

      expect(
        IndependentHubCalculator.requiredRevenueForDesiredNet(desiredNetIncome),
        closeTo(
          desiredNetIncome +
              IndependentHubCalculator.estimatedTaxBurden(desiredNetIncome) +
              IndependentHubCalculator.estimatedSocialCharges(
                desiredNetIncome,
              ) +
              IndependentHubCalculator.estimatedBusinessExpenses(
                desiredNetIncome,
              ) +
              IndependentHubCalculator.estimatedUnpaidDaysCost(
                desiredNetIncome,
              ),
          0.01,
        ),
      );
    });

    test('uses one tax proxy for illustrative deduction savings', () {
      expect(
        IndependentHubCalculator.taxSavingForDeduction(
          IndependentHubCalculator.grand3aIllustrativeDeduction,
        ),
        closeTo(5000, 0.01),
      );
      expect(
        IndependentHubCalculator.taxSavingForDeduction(
          IndependentHubCalculator.lppPremiumIllustrativeDeduction,
        ),
        closeTo(900, 0.01),
      );
    });

    test('names LPP rescue option gains used by the hub', () {
      expect(
        IndependentHubCalculator.librePassageFiveYearGain,
        closeTo(8500, 0.01),
      );
      expect(
        IndependentHubCalculator.substituteInstitutionFiveYearGain,
        closeTo(1200, 0.01),
      );
      expect(
        IndependentHubCalculator.voluntaryLppFiveYearGain,
        closeTo(12000, 0.01),
      );
    });

    test('sums employee and self-employed protection totals from components',
        () {
      const annualIncome = 132000.0;
      const age = 52;

      expect(
        IndependentHubCalculator.employeeProtectionTotal(annualIncome, age),
        closeTo(
          IndependentHubCalculator.employeeAvsCharge(annualIncome) +
              IndependentHubCalculator.employeeLppCharge(annualIncome, age) +
              IndependentHubCalculator.employeeUnemploymentCharge(
                  annualIncome) +
              IndependentHubCalculator.employeeProfessionalCoverageCharge(
                annualIncome,
              ),
          0.01,
        ),
      );
      expect(
        IndependentHubCalculator.selfEmployedProtectionTotal(annualIncome),
        closeTo(
          IndependentHubCalculator.selfEmployedAvsCharge(annualIncome) +
              IndependentHubCalculator.selfEmployedProfessionalCoverageCharge(
                annualIncome,
              ),
          0.01,
        ),
      );
    });
  });
}
