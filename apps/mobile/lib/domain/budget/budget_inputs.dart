import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';

enum PayFrequency {
  monthly,
  biweekly,
  weekly,
}

enum BudgetStyle {
  justAvailable,
  envelopes3,
}

class BudgetInputs {
  final PayFrequency payFrequency;
  final double netIncome; // Périodique (selon frequency)
  final double housingCost; // Périodique
  final double debtPayments; // Périodique
  final double taxProvision; // Mensuel (provision impots)
  final double healthInsurance; // Mensuel (LAMal)
  final double otherFixedCosts; // Mensuel (assurances/autres charges fixes)
  final bool isTaxEstimated;
  final bool isHealthEstimated;
  final bool isOtherFixedMissing;
  final BudgetStyle style;
  final double
      emergencyFundMonths; // Mois de dépenses couverts par l'épargne liquide

  const BudgetInputs({
    required this.payFrequency,
    required this.netIncome,
    required this.housingCost,
    required this.debtPayments,
    this.taxProvision = 0,
    this.healthInsurance = 0,
    this.otherFixedCosts = 0,
    this.isTaxEstimated = false,
    this.isHealthEstimated = false,
    this.isOtherFixedMissing = false,
    this.style = BudgetStyle.envelopes3,
    this.emergencyFundMonths = 0,
  });

  bool get hasEstimatedValues => isTaxEstimated || isHealthEstimated;
  bool get hasMissingValues => isOtherFixedMissing;

  /// Construit des BudgetInputs a partir d'un CoachProfile.
  ///
  /// Utilise pour synchroniser le budget quand le profil change
  /// (wizard, annual refresh, mini-onboarding).
  /// Le revenu net utilise NetIncomeBreakdown (canton + age).
  /// Les dettes sont reparties sur 36 mois de remboursement.
  static BudgetInputs fromCoachProfile(CoachProfile profile) {
    // Revenu net du menage (utilisateur + conjoint si couple)
    final ownBreakdown = NetIncomeBreakdown.compute(
      grossSalary: profile.salaireBrutMensuel * 12,
      canton: profile.canton,
      age: profile.age,
    );
    final ownNet = ownBreakdown.monthlyNetPayslip;
    final partnerNet = profile.conjoint != null
        ? NetIncomeBreakdown.compute(
            grossSalary: profile.conjoint!.salaireBrutMensuel * 12,
            canton: profile.canton,
            age: profile.conjoint!.age,
          ).monthlyNetPayslip
        : 0.0;
    final monthlyNet = ownNet + partnerNet;
    final monthlyDebt =
        profile.dettes.totalDettes > 0 ? profile.dettes.totalDettes / 36 : 0.0;
    // Charges fixes hors loyer et assurance maladie
    final otherFixed = profile.depenses.totalMensuel -
        profile.depenses.loyer -
        profile.depenses.assuranceMaladie;

    // Civilite mapping pour TaxEstimatorService
    final civilStatusStr = switch (profile.etatCivil) {
      CoachCivilStatus.marie => 'married',
      CoachCivilStatus.concubinage => 'single',
      _ => 'single',
    };

    return BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: monthlyNet,
      housingCost: profile.depenses.loyer,
      debtPayments: monthlyDebt,
      taxProvision: TaxEstimatorService.estimateMonthlyProvision(
        TaxEstimatorService.estimateAnnualTax(
          netMonthlyIncome: monthlyNet,
          cantonCode: profile.canton,
          civilStatus: civilStatusStr,
          childrenCount: profile.nombreEnfants,
          age: profile.age,
          isSourceTaxed: false,
        ),
      ),
      healthInsurance: profile.depenses.assuranceMaladie,
      otherFixedCosts: otherFixed > 0 ? otherFixed : 0,
      isTaxEstimated: true,
      isHealthEstimated: false,
      isOtherFixedMissing: otherFixed <= 0,
    );
  }

  // Factory depuis une map (pour deserialization depuis Session.answers)
  factory BudgetInputs.fromMap(Map<String, dynamic> map) {
    // Calculer les mois de fonds d'urgence depuis la réponse wizard
    double emergencyMonths = 0;
    final emergencyRaw = map['q_emergency_fund'];
    if (emergencyRaw is String) {
      switch (emergencyRaw.toLowerCase()) {
        case 'yes_6months':
          emergencyMonths = 6;
        case 'yes_3months':
          emergencyMonths = 3;
        case 'no':
          emergencyMonths = 0;
        default:
          final parsed = double.tryParse(emergencyRaw);
          if (parsed != null) emergencyMonths = parsed;
      }
    }

    final payFrequency = PayFrequency.values.firstWhere(
      (e) => e.name == map['q_pay_frequency'],
      orElse: () => PayFrequency.monthly,
    );
    final netIncome =
        (map['q_net_income_period_chf'] as num?)?.toDouble() ?? 0.0;
    final housingCost =
        (map['q_housing_cost_period_chf'] as num?)?.toDouble() ?? 0.0;
    final debtPayments =
        (map['q_debt_payments_period_chf'] as num?)?.toDouble() ?? 0.0;

    final normalizedMonthlyIncome = _toMonthly(netIncome, payFrequency);
    final taxProvisionRaw =
        (map['q_tax_provision_monthly_chf'] as num?)?.toDouble();
    final lamalRaw = (map['q_lamal_premium_monthly_chf'] as num?)?.toDouble();
    final otherFixedRaw =
        (map['q_other_fixed_costs_monthly_chf'] as num?)?.toDouble();

    final civilStatus = map['q_civil_status'] as String? ?? 'single';
    final canton = map['q_canton'] as String? ?? 'CH';
    final children = _parseChildrenCount(map['q_children']);

    final estimatedTax = taxProvisionRaw ??
        TaxEstimatorService.estimateMonthlyProvision(
          TaxEstimatorService.estimateAnnualTax(
            netMonthlyIncome: normalizedMonthlyIncome,
            cantonCode: canton,
            civilStatus: civilStatus,
            childrenCount: children,
            age: 35,
            isSourceTaxed: false,
          ),
        );

    final estimatedLamal = lamalRaw ??
        _estimateLamalPremium(canton, map['q_household_type'] as String?);

    final metaTaxEstimated = map['meta_tax_estimated'];
    final metaHealthEstimated = map['meta_health_estimated'];
    final metaOtherFixedMissing = map['meta_other_fixed_missing'];

    return BudgetInputs(
      payFrequency: payFrequency,
      netIncome: netIncome,
      housingCost: housingCost,
      debtPayments: debtPayments,
      taxProvision: estimatedTax,
      healthInsurance: estimatedLamal,
      otherFixedCosts: otherFixedRaw ?? 0.0,
      isTaxEstimated:
          metaTaxEstimated is bool ? metaTaxEstimated : taxProvisionRaw == null,
      isHealthEstimated:
          metaHealthEstimated is bool ? metaHealthEstimated : lamalRaw == null,
      isOtherFixedMissing: metaOtherFixedMissing is bool
          ? metaOtherFixedMissing
          : otherFixedRaw == null,
      style: BudgetStyle.values.firstWhere(
        (e) => e.name == map['q_budget_style'],
        orElse: () => BudgetStyle.envelopes3,
      ),
      emergencyFundMonths: emergencyMonths,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'q_pay_frequency': payFrequency.name,
      'q_net_income_period_chf': netIncome,
      'q_housing_cost_period_chf': housingCost,
      'q_debt_payments_period_chf': debtPayments,
      'q_tax_provision_monthly_chf': taxProvision,
      'q_lamal_premium_monthly_chf': healthInsurance,
      'q_other_fixed_costs_monthly_chf': otherFixedCosts,
      'meta_tax_estimated': isTaxEstimated,
      'meta_health_estimated': isHealthEstimated,
      'meta_other_fixed_missing': isOtherFixedMissing,
      'q_budget_style': style.name,
      'emergency_fund_months': emergencyFundMonths,
    };
  }

  static double _toMonthly(double amount, PayFrequency frequency) {
    switch (frequency) {
      case PayFrequency.weekly:
        return amount * 4.333;
      case PayFrequency.biweekly:
        return amount * 2.166;
      case PayFrequency.monthly:
        return amount;
    }
  }

  static int _parseChildrenCount(dynamic raw) {
    if (raw == null) return 0;
    final text = raw.toString().trim().replaceAll('+', '');
    return int.tryParse(text) ?? 0;
  }

  static double _estimateLamalPremium(
      String cantonCode, String? householdType) {
    const highCantons = {'GE', 'VD', 'BS', 'NE'};
    const lowCantons = {'ZG', 'AI', 'UR', 'OW', 'NW'};
    final adults =
        householdType == 'couple' || householdType == 'family' ? 2 : 1;

    final baseAdult = highCantons.contains(cantonCode)
        ? 520.0
        : lowCantons.contains(cantonCode)
            ? 350.0
            : 430.0;

    return baseAdult * adults;
  }
}
