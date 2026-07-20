import 'dart:math' show max, min;

import 'package:mint_mobile/constants/social_insurance.dart';

/// Financial-core facts used by the First Job presentation authority.
///
/// These are statutory illustrations only. They deliberately exclude AANP,
/// the personal LPP deduction and the exact net because those require payroll
/// or pension-plan evidence.
class FirstJobSalaryFinancialFacts {
  const FirstJobSalaryFinancialFacts({
    required this.avsAiApg,
    required this.ac,
    required this.avsAiApgRate,
    required this.acDisplayedRate,
    required this.lppAgeCreditIllustration,
  });

  final double avsAiApg;
  final double ac;
  final double avsAiApgRate;
  final double acDisplayedRate;
  final double? lppAgeCreditIllustration;
}

class FirstJobSalaryFinancialFactsCalculator {
  FirstJobSalaryFinancialFactsCalculator._();

  static FirstJobSalaryFinancialFacts calculate({
    required double grossMonthlySalary,
    required int age,
    double activityRate = 100,
  }) {
    final annualSalary = grossMonthlySalary * 12 * (activityRate / 100);
    final avsRate = reg('avs.employee_rate', avsCotisationSalarie);
    final avs = grossMonthlySalary * avsRate;
    final acCeiling = reg('ac.salary_ceiling', acPlafondSalaireAssure);
    final acRate = reg('ac.employee_rate', acCotisationSalarie);
    final solidarityRate =
        reg('ac.solidarity_rate', acCotisationSolidariteSalarie);
    final ac = annualSalary <= acCeiling
        ? grossMonthlySalary * acRate
        : (acCeiling * acRate + (annualSalary - acCeiling) * solidarityRate) /
            12;

    double? ageCredit;
    if (annualSalary >= reg('lpp.entry_threshold', lppSeuilEntree) &&
        age >= 25) {
      final coordinatedSalary = min(
        max(
          annualSalary -
              reg('lpp.coordination_deduction', lppDeductionCoordination),
          reg('lpp.min_coordinated_salary', lppSalaireCoordMin),
        ),
        reg('lpp.max_coordinated_salary', lppSalaireCoordMax),
      );
      ageCredit = coordinatedSalary * getLppBonificationRate(age) / 12;
    }

    return FirstJobSalaryFinancialFacts(
      avsAiApg: avs,
      ac: ac,
      avsAiApgRate: avsRate,
      acDisplayedRate: ac / grossMonthlySalary,
      lppAgeCreditIllustration: ageCredit,
    );
  }
}
