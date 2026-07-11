import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';

class IndependentProtectionFinancialFacts {
  IndependentProtectionFinancialFacts._();

  static const double _vestedBenefitsFoundationFiveYearGainRate = 0.07;
  static const double _substituteInstitutionFiveYearGainRate = 0.04;
  static const double _newPensionFundFiveYearGainRate = 0.15;
  static const double _voluntaryLppTaxSavingProxyRate = 0.08;
  static const double _professionalEmployeeCoverageRate = 0.020;
  static const double _professionalSelfEmployedCoverageRate = 0.040;

  /// Extra AVS/AI/APG contribution an employee effectively has to cover after
  /// switching to self-employment, approximated by the former employer share.
  static double employeeAvsMonthly(double annualIncome) {
    return annualIncome * avsCotisationSalarie / 12;
  }

  /// Minimum LPP share no longer covered by an employer after the switch.
  ///
  /// This is an educational proxy: the independent flow often knows the user's
  /// declared annual independent income before it knows the former insured
  /// salary. Still, the LPP math itself must remain Swiss-law shaped: age
  /// credit on the coordinated salary, then minimum 50% employer share.
  static double employeeLppMonthly(double annualIncome, int age) {
    final coordinatedSalary = LppCalculator.computeSalaireCoordonne(
      annualIncome,
    );
    return coordinatedSalary * getLppBonificationRate(age) / 2 / 12;
  }

  /// Educational five-year opportunity proxy for a declared vested-benefits
  /// balance. These are not statutory yields and must stay labelled as
  /// scenario assumptions in the UI.
  static double vestedBenefitsFoundationFiveYearGain(double balance) {
    return balance * _vestedBenefitsFoundationFiveYearGainRate;
  }

  static double substituteInstitutionFiveYearGain(double balance) {
    return balance * _substituteInstitutionFiveYearGainRate;
  }

  static double newPensionFundFiveYearGain(double balance) {
    return balance * _newPensionFundFiveYearGainRate;
  }

  /// Rough marginal tax relief proxy for the voluntary LPP option in the
  /// independent education screen. A personalised tax result must come from a
  /// tax calculator fed with canton, family status and deductions.
  static double voluntaryLppTaxSavingProxy(double annualIncome) {
    return annualIncome * _voluntaryLppTaxSavingProxyRate;
  }

  /// Educational proxy for employee-side professional coverage cost
  /// components such as IJM/LAA before moving to self-employment.
  static double employeeProfessionalCoverageProxy(double annualIncome) {
    return annualIncome * _professionalEmployeeCoverageRate;
  }

  /// Educational proxy for comparable professional protection the independent
  /// person has to contract and pay directly.
  static double selfEmployedProfessionalCoverageProxy(double annualIncome) {
    return annualIncome * _professionalSelfEmployedCoverageRate;
  }
}
