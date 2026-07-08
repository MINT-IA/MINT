import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

class FirstSalaryTax3aInput {
  final double grossAnnualSalary;
  final String canton;
  final int age;
  final bool hasLpp;
  final bool canContribute3a;
  final bool isCrossBorder;
  final bool isMarried;
  final int children;
  final int contributionMonths;
  final double current3aContribution;

  const FirstSalaryTax3aInput({
    required this.grossAnnualSalary,
    required this.canton,
    required this.age,
    required this.hasLpp,
    required this.canContribute3a,
    this.isCrossBorder = false,
    this.isMarried = false,
    this.children = 0,
    this.contributionMonths = 12,
    this.current3aContribution = 0,
  });
}

class FirstSalaryTax3aResult {
  final NetIncomeBreakdown income;
  final double pillar3aLimit;
  final double current3aContribution;
  final double remaining3aRoom;
  final double current3aTaxSaving;
  final double additional3aTaxSaving;
  final double max3aTaxSaving;

  const FirstSalaryTax3aResult({
    required this.income,
    required this.pillar3aLimit,
    required this.current3aContribution,
    required this.remaining3aRoom,
    required this.current3aTaxSaving,
    required this.additional3aTaxSaving,
    required this.max3aTaxSaving,
  });

  double get netMonthlyPayslip => income.monthlyNetPayslip;

  double get monthlyIncomeTaxEstimate => income.incomeTaxEstimate / 12;
}

class FirstSalaryTax3aCalculator {
  FirstSalaryTax3aCalculator._();

  static double annualizeMonthly3aContribution(double monthlyContribution) {
    if (monthlyContribution <= 0) return 0;
    return monthlyContribution * 12;
  }

  static FirstSalaryTax3aResult analyze(FirstSalaryTax3aInput input) {
    final grossAnnualSalary =
        input.grossAnnualSalary > 0 ? input.grossAnnualSalary : 0.0;
    final canton =
        input.canton.trim().isEmpty ? 'ZH' : input.canton.trim().toUpperCase();
    final age = input.age > 0 ? input.age : 25;
    final income = NetIncomeBreakdown.compute(
      grossSalary: grossAnnualSalary,
      canton: canton,
      age: age,
      etatCivil: input.isMarried ? 'marie' : 'celibataire',
      nombreEnfants: input.children,
      isCrossBorder: input.isCrossBorder,
    );

    if (!input.canContribute3a || grossAnnualSalary <= 0) {
      return FirstSalaryTax3aResult(
        income: income,
        pillar3aLimit: 0,
        current3aContribution: 0,
        remaining3aRoom: 0,
        current3aTaxSaving: 0,
        additional3aTaxSaving: 0,
        max3aTaxSaving: 0,
      );
    }

    final annualCeiling = input.hasLpp
        ? reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp)
        : (grossAnnualSalary * pilier3aTauxRevenuSansLpp)
            .clamp(0.0, reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp))
            .toDouble();
    final months = input.contributionMonths.clamp(1, 12);
    final pillar3aLimit = annualCeiling * months / 12;
    final current3aContribution =
        input.current3aContribution.clamp(0.0, pillar3aLimit).toDouble();
    final remaining3aRoom = pillar3aLimit - current3aContribution;

    final current3aTaxSaving = current3aContribution <= 0
        ? 0.0
        : RetirementTaxCalculator.estimate3aTaxSaving(
            grossAnnualSalary: grossAnnualSalary,
            canton: canton,
            isMarried: input.isMarried,
            children: input.children,
            hasLpp: input.hasLpp,
            isCrossBorder: input.isCrossBorder,
            contributionMonths: months,
            contribution: current3aContribution,
          );
    final max3aTaxSaving = RetirementTaxCalculator.estimate3aTaxSaving(
      grossAnnualSalary: grossAnnualSalary,
      canton: canton,
      isMarried: input.isMarried,
      children: input.children,
      hasLpp: input.hasLpp,
      isCrossBorder: input.isCrossBorder,
      contributionMonths: months,
      contribution: pillar3aLimit,
    );
    final additional3aTaxSaving =
        (max3aTaxSaving - current3aTaxSaving).clamp(0.0, double.infinity);

    return FirstSalaryTax3aResult(
      income: income,
      pillar3aLimit: pillar3aLimit,
      current3aContribution: current3aContribution,
      remaining3aRoom: remaining3aRoom,
      current3aTaxSaving: current3aTaxSaving,
      additional3aTaxSaving: additional3aTaxSaving,
      max3aTaxSaving: max3aTaxSaving,
    );
  }

  static bool inferHasLppFor3a({
    required double grossAnnualSalary,
    required int age,
    required String employmentStatus,
    required bool? explicitHasPensionFund,
    required bool hasCertificateSignals,
    required double? lppBalance,
  }) {
    if (explicitHasPensionFund != null) return explicitHasPensionFund;
    if (hasCertificateSignals) return true;
    if ((lppBalance ?? 0) > 0) return true;

    final normalizedStatus = employmentStatus.trim().toLowerCase();
    if (normalizedStatus == 'independant' ||
        normalizedStatus == 'self_employed') {
      return false;
    }

    final referenceAge =
        reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble()).toInt();
    if (age < 25 || age > referenceAge) return false;
    return grossAnnualSalary >= reg('lpp.entry_threshold', lppSeuilEntree);
  }
}
