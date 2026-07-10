import 'package:mint_mobile/constants/social_insurance.dart';

/// Financial helper for the self-employed hub educational widgets.
///
/// The screen owns presentation only; percentages and contribution formulas
/// live here so financial drift gates can review them in one place.
class IndependentHubCalculator {
  static const double _lppRescueBalanceProxyRate = 0.15;
  static const double _voluntaryLppTaxSavingsProxyRate = 0.08;
  static const double _grand3aTaxSavingsProxyRate = 0.25;
  static const double independentTaxProxyRate = 0.25;
  static const double grand3aIllustrativeDeduction = 20000.0;
  static const double lppPremiumIllustrativeDeduction = 3600.0;
  static const double librePassageFiveYearGain = 8500.0;
  static const double substituteInstitutionFiveYearGain = 1200.0;
  static const double voluntaryLppFiveYearGain = 12000.0;
  static const double _taxBurdenProxyRate = 0.22;
  static const double _socialChargesProxyRate = 0.10;
  static const double _businessExpensesProxyRate = 0.15;
  static const double _unpaidDaysProxyRate = 0.05;
  static const double _employeeProfessionalCoverageProxyRate = 0.020;
  static const double _selfEmployedProfessionalCoverageProxyRate = 0.040;

  static double estimatedLppRescueBalance(double annualIncome) {
    return annualIncome * _lppRescueBalanceProxyRate;
  }

  static double employeeAvsMonthly(double annualIncome) {
    return annualIncome * avsCotisationSalarie / 12;
  }

  static double employeeLppMonthly(double annualIncome, int age) {
    return annualIncome * getLppBonificationRate(age) / 12;
  }

  static double voluntaryLppTaxSavings(double annualIncome) {
    return annualIncome * _voluntaryLppTaxSavingsProxyRate;
  }

  static double estimatedTaxBurden(double desiredNetIncome) {
    return desiredNetIncome * _taxBurdenProxyRate;
  }

  static double estimatedSocialCharges(double desiredNetIncome) {
    return desiredNetIncome * _socialChargesProxyRate;
  }

  static double estimatedBusinessExpenses(double desiredNetIncome) {
    return desiredNetIncome * _businessExpensesProxyRate;
  }

  static double estimatedUnpaidDaysCost(double desiredNetIncome) {
    return desiredNetIncome * _unpaidDaysProxyRate;
  }

  static double requiredRevenueForDesiredNet(double desiredNetIncome) {
    return desiredNetIncome +
        estimatedTaxBurden(desiredNetIncome) +
        estimatedSocialCharges(desiredNetIncome) +
        estimatedBusinessExpenses(desiredNetIncome) +
        estimatedUnpaidDaysCost(desiredNetIncome);
  }

  static double taxSavingForDeduction(double annualDeduction) {
    return annualDeduction * independentTaxProxyRate;
  }

  static double grand3aTaxSavings(double annualIncome) {
    final eligibleContribution = (annualIncome * pilier3aTauxRevenuSansLpp)
        .clamp(0.0, pilier3aPlafondSansLpp);
    return eligibleContribution * _grand3aTaxSavingsProxyRate;
  }

  static double employeeAvsCharge(double annualIncome) {
    return annualIncome * avsCotisationSalarie;
  }

  static double selfEmployedAvsCharge(double annualIncome) {
    return annualIncome * avsCotisationTotal;
  }

  static double employeeLppCharge(double annualIncome, int age) {
    return annualIncome * getLppBonificationRate(age);
  }

  static double employeeUnemploymentCharge(double annualIncome) {
    return annualIncome * acCotisationSalarie;
  }

  static double employeeProfessionalCoverageCharge(double annualIncome) {
    return annualIncome * _employeeProfessionalCoverageProxyRate;
  }

  static double selfEmployedProfessionalCoverageCharge(double annualIncome) {
    return annualIncome * _selfEmployedProfessionalCoverageProxyRate;
  }

  static double employeeProtectionTotal(double annualIncome, int age) {
    return employeeAvsCharge(annualIncome) +
        employeeLppCharge(annualIncome, age) +
        employeeUnemploymentCharge(annualIncome) +
        employeeProfessionalCoverageCharge(annualIncome);
  }

  static double selfEmployedProtectionTotal(double annualIncome) {
    return selfEmployedAvsCharge(annualIncome) +
        selfEmployedProfessionalCoverageCharge(annualIncome);
  }
}
