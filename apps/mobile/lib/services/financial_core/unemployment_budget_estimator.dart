import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/unemployment_financial_facts.dart';

class UnemploymentBudgetEstimate {
  final double normalIncome;
  final double survivalIncome;
  final double housing;
  final double lamal;
  final double? transport;

  const UnemploymentBudgetEstimate({
    required this.normalIncome,
    required this.survivalIncome,
    required this.housing,
    required this.lamal,
    this.transport,
  });
}

class UnemploymentBudgetEstimator {
  const UnemploymentBudgetEstimator._();

  static UnemploymentBudgetEstimate? fromLedger({
    required CoachProfile? profile,
    required double grossMonthlyBenefit,
  }) {
    if (profile == null ||
        !profile.userProvidedFields.contains('monthlyExpenses') ||
        !profile.userProvidedFields.contains('netIncome') ||
        profile.monthlyNetIncomeDeclared == null) {
      return null;
    }

    final depenses = profile.depenses;
    if (depenses.loyer <= 0 || depenses.assuranceMaladie <= 0) {
      return null;
    }

    final transport = depenses.transport;
    final estimatedNetBenefit =
        UnemploymentFinancialFacts.estimatedNetMonthlyBenefitFromGross(
      grossMonthlyBenefit,
    );
    return UnemploymentBudgetEstimate(
      normalIncome: profile.monthlyNetIncomeDeclared!,
      survivalIncome: estimatedNetBenefit,
      housing: depenses.loyer,
      lamal: depenses.assuranceMaladie,
      transport: transport != null && transport > 0 ? transport : null,
    );
  }
}
