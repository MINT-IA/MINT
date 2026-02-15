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
  final BudgetStyle style;
  final double emergencyFundMonths; // Mois de dépenses couverts par l'épargne liquide

  const BudgetInputs({
    required this.payFrequency,
    required this.netIncome,
    required this.housingCost,
    required this.debtPayments,
    this.style = BudgetStyle.envelopes3,
    this.emergencyFundMonths = 0,
  });

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

    return BudgetInputs(
      payFrequency: PayFrequency.values.firstWhere(
        (e) => e.name == map['q_pay_frequency'],
        orElse: () => PayFrequency.monthly,
      ),
      netIncome: (map['q_net_income_period_chf'] as num?)?.toDouble() ?? 0.0,
      housingCost:
          (map['q_housing_cost_period_chf'] as num?)?.toDouble() ?? 0.0,
      debtPayments:
          (map['q_debt_payments_period_chf'] as num?)?.toDouble() ?? 0.0,
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
      'q_budget_style': style.name,
      'emergency_fund_months': emergencyFundMonths,
    };
  }
}
