/// Budget distress band surfaced by the budget service.
///
/// Wave 7 fiscal audit P0-B1 (2026-04-18) required this escalation so the
/// coach and UI can route a user with `charges / netIncome >= 0.70` to
/// Safe Mode (CLAUDE.md §7) instead of rendering the pct silently as a
/// neutral percentage. Bands are keyed off the LP art. 93 minimum-vital
/// boundary logic — `critical` = charges exceed income.
enum BudgetDistressLevel {
  /// pct < 0.70 of net income spent on fixed charges — normal state.
  none,

  /// 0.70 ≤ pct < 1.00 — fragile, désendettement priority (LP art. 93).
  fragile,

  /// pct ≥ 1.00 — charges > income. Trigger SafeMode + route to social
  /// services (CSP, Caritas, OCAS).
  critical,

  /// netIncome ≤ 0 or missing. Cannot compute — enrichment needed.
  unknown,
}

class BudgetPlan {
  final double available; // reste à vivre
  final double variables; // enveloppe variables
  final double future; // enveloppe futur (épargne)
  final bool stopRuleTriggered; // Alert si variables <= 0
  final double emergencyFundMonths; // Mois couverts par l'épargne liquide
  final BudgetDistressLevel distress; // Wave 7 P0-B1 escalation
  final double? chargesRatio; // 0..+∞ — null if netIncome <= 0
  static const double emergencyFundTarget = 6.0; // Cible : 6 mois

  /// Fragile threshold — above 70 % of net income on fixed charges.
  static const double fragileThreshold = 0.70;

  /// Critical threshold — charges meet or exceed net income.
  static const double criticalThreshold = 1.00;

  const BudgetPlan({
    required this.available,
    required this.variables,
    required this.future,
    required this.stopRuleTriggered,
    this.emergencyFundMonths = 0,
    this.distress = BudgetDistressLevel.none,
    this.chargesRatio,
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
          emergencyFundMonths == other.emergencyFundMonths &&
          distress == other.distress &&
          chargesRatio == other.chargesRatio;

  @override
  int get hashCode =>
      available.hashCode ^
      variables.hashCode ^
      future.hashCode ^
      stopRuleTriggered.hashCode ^
      emergencyFundMonths.hashCode ^
      distress.hashCode ^
      (chargesRatio?.hashCode ?? 0);
}
