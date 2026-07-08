import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/first_salary_tax_3a_calculator.dart';

void main() {
  group('FirstSalaryTax3aCalculator', () {
    test('computes tax, net payslip, and full 3a room for a young employee',
        () {
      final result = FirstSalaryTax3aCalculator.analyze(
        const FirstSalaryTax3aInput(
          grossAnnualSalary: 96000,
          canton: 'GE',
          age: 25,
          hasLpp: true,
          canContribute3a: true,
          current3aContribution: 0,
        ),
      );

      expect(result.income.grossSalary, 96000);
      expect(result.income.incomeTaxEstimate, greaterThan(0));
      expect(result.netMonthlyPayslip,
          closeTo(result.income.netPayslip / 12, 0.01));
      expect(result.pillar3aLimit, pilier3aPlafondAvecLpp);
      expect(result.remaining3aRoom, pilier3aPlafondAvecLpp);
      expect(result.max3aTaxSaving, closeTo(1402.16, 0.01));
      expect(result.max3aTaxSaving, greaterThan(700));
      expect(result.additional3aTaxSaving, result.max3aTaxSaving);
    });

    test('keeps current 3a contribution distinct from remaining tax room', () {
      final result = FirstSalaryTax3aCalculator.analyze(
        const FirstSalaryTax3aInput(
          grossAnnualSalary: 96000,
          canton: 'GE',
          age: 25,
          hasLpp: true,
          canContribute3a: true,
          current3aContribution: 3000,
        ),
      );

      expect(result.current3aContribution, 3000);
      expect(result.remaining3aRoom, pilier3aPlafondAvecLpp - 3000);
      expect(result.current3aTaxSaving, greaterThan(0));
      expect(result.additional3aTaxSaving, greaterThan(0));
      expect(result.max3aTaxSaving, greaterThan(result.current3aTaxSaving));
    });

    test('routes cross-border workers through withholding tax estimate', () {
      final ordinary = FirstSalaryTax3aCalculator.analyze(
        const FirstSalaryTax3aInput(
          grossAnnualSalary: 96000,
          canton: 'GE',
          age: 25,
          hasLpp: true,
          canContribute3a: true,
        ),
      );
      final crossBorder = FirstSalaryTax3aCalculator.analyze(
        const FirstSalaryTax3aInput(
          grossAnnualSalary: 96000,
          canton: 'GE',
          age: 25,
          hasLpp: true,
          canContribute3a: true,
          isCrossBorder: true,
        ),
      );

      expect(crossBorder.income.incomeTaxEstimate,
          isNot(ordinary.income.incomeTaxEstimate));
      expect(crossBorder.max3aTaxSaving, isNot(ordinary.max3aTaxSaving));
    });

    test(
        'infers no LPP below entry threshold when no explicit certificate exists',
        () {
      expect(
        FirstSalaryTax3aCalculator.inferHasLppFor3a(
          grossAnnualSalary: lppSeuilEntree - 1,
          age: 25,
          employmentStatus: 'salarie',
          explicitHasPensionFund: null,
          hasCertificateSignals: false,
          lppBalance: null,
        ),
        isFalse,
      );
      expect(
        FirstSalaryTax3aCalculator.inferHasLppFor3a(
          grossAnnualSalary: lppSeuilEntree - 1,
          age: 25,
          employmentStatus: 'salarie',
          explicitHasPensionFund: true,
          hasCertificateSignals: false,
          lppBalance: null,
        ),
        isTrue,
      );
    });

    test('infers no LPP savings affiliation before age 25', () {
      expect(
        FirstSalaryTax3aCalculator.inferHasLppFor3a(
          grossAnnualSalary: lppSeuilEntree + 1000,
          age: 24,
          employmentStatus: 'salarie',
          explicitHasPensionFund: null,
          hasCertificateSignals: false,
          lppBalance: null,
        ),
        isFalse,
      );
      expect(
        FirstSalaryTax3aCalculator.inferHasLppFor3a(
          grossAnnualSalary: lppSeuilEntree + 1000,
          age: 25,
          employmentStatus: 'salarie',
          explicitHasPensionFund: null,
          hasCertificateSignals: false,
          lppBalance: null,
        ),
        isTrue,
      );
    });

    test('does not recommend a 3a deduction when contribution is blocked', () {
      final result = FirstSalaryTax3aCalculator.analyze(
        const FirstSalaryTax3aInput(
          grossAnnualSalary: 96000,
          canton: 'GE',
          age: 25,
          hasLpp: true,
          canContribute3a: false,
          current3aContribution: 3000,
        ),
      );

      expect(result.pillar3aLimit, 0);
      expect(result.remaining3aRoom, 0);
      expect(result.current3aContribution, 0);
      expect(result.current3aTaxSaving, 0);
      expect(result.additional3aTaxSaving, 0);
      expect(result.max3aTaxSaving, 0);
    });
  });
}
