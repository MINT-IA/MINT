import 'dart:math';

// ────────────────────────────────────────────────────────────
//  PLAN TRACKING SERVICE — Phase 5 / Dashboard Assembly
// ────────────────────────────────────────────────────────────
//
// Évalue l'adhérence du plan financier de l'utilisateur
// (check-ins mensuels, actions planifiées, etc.).
//
// compoundProjectedImpact() calcule l'impact composé FV
// d'une action régulière sur N mois (FV annuity formula).
//
// Outil éducatif — ne constitue pas un conseil financier (LSFin).
// ────────────────────────────────────────────────────────────

/// Résultat d'évaluation du plan financier.
class PlanStatus {
  final double score;
  final int completedActions;
  final int totalActions;
  final List<String> nextActions;

  const PlanStatus({
    required this.score,
    required this.completedActions,
    required this.totalActions,
    required this.nextActions,
  });

  /// Taux d'adhérence (0.0 - 1.0).
  double get adherenceRate =>
      totalActions > 0 ? completedActions / totalActions : 0;
}

/// Service d'évaluation du plan et projection de l'impact composé.
class PlanTrackingService {
  PlanTrackingService._();

  /// Évalue le plan de l'utilisateur à partir des check-ins et actions.
  ///
  /// [checkIns] : liste de check-ins mensuels (chaque map contient
  /// 'completed': bool et 'actions': List<String>).
  /// [plannedActions] : liste des actions planifiées pour le mois courant.
  ///
  /// Retourne un [PlanStatus] avec score, adhérence, et prochaines actions.
  static PlanStatus evaluate({
    required List<Map<String, dynamic>> checkIns,
    required List<String> plannedActions,
  }) {
    if (plannedActions.isEmpty) {
      return const PlanStatus(
        score: 0,
        completedActions: 0,
        totalActions: 0,
        nextActions: [],
      );
    }

    // Comptage des actions complétées à travers les check-ins
    int completed = 0;
    final completedSet = <String>{};

    for (final ci in checkIns) {
      final isCompleted = ci['completed'] as bool? ?? false;
      if (isCompleted) completed++;

      final actions = ci['actions'] as List<dynamic>? ?? [];
      for (final a in actions) {
        if (a is String) completedSet.add(a);
      }
    }

    // Actions restantes
    final remaining = plannedActions
        .where((a) => !completedSet.contains(a))
        .toList();

    // Score basé sur le taux d'adhérence (0-100)
    final rate = plannedActions.isNotEmpty
        ? completedSet.length / plannedActions.length
        : 0.0;
    final score = (rate * 100).clamp(0, 100).toDouble();

    return PlanStatus(
      score: score,
      completedActions: completedSet.length,
      totalActions: plannedActions.length,
      nextActions: remaining.take(3).toList(),
    );
  }

  /// Calcule l'impact composé projeté d'actions régulières (FV annuity).
  ///
  /// Formule: PMT × ((1+r)^n - 1) / r
  /// avec r = rendement mensuel, n = nombre de mois.
  ///
  /// [status] : résultat de evaluate().
  /// [monthsToRetirement] : nombre de mois jusqu'à la retraite.
  /// [annualReturn] : rendement réel annuel (défaut 2%, conservateur).
  ///
  /// Retourne le montant total accumulé (CHF).
  ///
  /// Sources: LPP art. 15-16 (bonifications), OPP3 art. 7 (3a).
  /// Outil éducatif — ne constitue pas un conseil financier.
  static double compoundProjectedImpact({
    required PlanStatus status,
    required int monthsToRetirement,
    double annualReturn = 0.02, // 2% real return (conservative estimate)
  }) {
    if (monthsToRetirement <= 0 || status.nextActions.isEmpty) return 0;

    final monthlyRate = annualReturn / 12;
    final n = monthsToRetirement.toDouble();

    // Monthly gap = contribution proportionnelle à l'adhérence
    final monthlyGap =
        status.score > 0 ? (status.completedActions * 100.0) : 0.0;

    // FV annuity formula: PMT × ((1+r)^n - 1) / r
    if (monthlyRate == 0) return monthlyGap * n;
    return monthlyGap * ((pow(1 + monthlyRate, n) - 1) / monthlyRate);
  }
}
