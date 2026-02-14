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

  const BudgetInputs({
    required this.payFrequency,
    required this.netIncome,
    required this.housingCost,
    required this.debtPayments,
    this.style = BudgetStyle.envelopes3,
  });

  // Factory depuis une map (pour deserialization depuis Session.answers)
  factory BudgetInputs.fromMap(Map<String, dynamic> map) {
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'q_pay_frequency': payFrequency.name,
      'q_net_income_period_chf': netIncome,
      'q_housing_cost_period_chf': housingCost,
      'q_debt_payments_period_chf': debtPayments,
      'q_budget_style': style.name,
    };
  }
}
