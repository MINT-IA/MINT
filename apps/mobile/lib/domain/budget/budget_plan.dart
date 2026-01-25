class BudgetPlan {
  final double available; // reste à vivre
  final double variables; // enveloppe variables
  final double future; // enveloppe futur (épargne)
  final bool stopRuleTriggered; // Alert si variables <= 0

  const BudgetPlan({
    required this.available,
    required this.variables,
    required this.future,
    required this.stopRuleTriggered,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetPlan &&
          runtimeType == other.runtimeType &&
          available == other.available &&
          variables == other.variables &&
          future == other.future &&
          stopRuleTriggered == other.stopRuleTriggered;

  @override
  int get hashCode =>
      available.hashCode ^
      variables.hashCode ^
      future.hashCode ^
      stopRuleTriggered.hashCode;
}
