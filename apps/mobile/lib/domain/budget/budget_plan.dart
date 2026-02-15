class BudgetPlan {
  final double available; // reste à vivre
  final double variables; // enveloppe variables
  final double future; // enveloppe futur (épargne)
  final bool stopRuleTriggered; // Alert si variables <= 0
  final double emergencyFundMonths; // Mois couverts par l'épargne liquide
  static const double emergencyFundTarget = 6.0; // Cible : 6 mois

  const BudgetPlan({
    required this.available,
    required this.variables,
    required this.future,
    required this.stopRuleTriggered,
    this.emergencyFundMonths = 0,
  });

  /// Progression du fonds d'urgence (0.0 à 1.0)
  double get emergencyFundProgress =>
      emergencyFundTarget > 0
          ? (emergencyFundMonths / emergencyFundTarget).clamp(0.0, 1.0)
          : 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetPlan &&
          runtimeType == other.runtimeType &&
          available == other.available &&
          variables == other.variables &&
          future == other.future &&
          stopRuleTriggered == other.stopRuleTriggered &&
          emergencyFundMonths == other.emergencyFundMonths;

  @override
  int get hashCode =>
      available.hashCode ^
      variables.hashCode ^
      future.hashCode ^
      stopRuleTriggered.hashCode ^
      emergencyFundMonths.hashCode;
}
