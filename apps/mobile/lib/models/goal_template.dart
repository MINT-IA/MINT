class GoalTemplate {
  final String id;
  final String label;

  const GoalTemplate({
    required this.id,
    required this.label,
  });

  factory GoalTemplate.fromJson(Map<String, dynamic> json) {
    return GoalTemplate(
      id: json['id'] as String,
      label: json['label'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
  };

  // Canonical templates
  static const goalControlDebts = GoalTemplate(id: 'goal_control_debts', label: 'Reprendre le contrôle');
  static const goalEmergencyFund = GoalTemplate(id: 'goal_emergency_fund', label: 'Construire un fonds d\'urgence');
  static const goalTaxBasic = GoalTemplate(id: 'goal_tax_basic', label: 'Payer moins d\'impôts');
  static const goalHouse = GoalTemplate(id: 'goal_house', label: 'Préparer un achat logement');
  static const goalPensionOpt = GoalTemplate(id: 'goal_pension_opt', label: 'Optimiser ma prévoyance');
  static const goalInvestSimple = GoalTemplate(id: 'goal_invest_simple', label: 'Investir simplement');
  static const goalRetirementPlan = GoalTemplate(id: 'goal_retirement_plan', label: 'Préparer la retraite');

  static const all = [
    goalControlDebts,
    goalEmergencyFund,
    goalTaxBasic,
    goalHouse,
    goalPensionOpt,
    goalInvestSimple,
    goalRetirementPlan,
  ];
}
