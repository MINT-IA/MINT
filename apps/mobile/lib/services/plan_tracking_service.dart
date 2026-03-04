import 'dart:math';

import 'package:mint_mobile/models/coach_profile.dart';

// ────────────────────────────────────────────────────────────
//  PLAN TRACKING SERVICE — Phase 5 / Dashboard Assembly
// ────────────────────────────────────────────────────────────
//
// Évalue l'adhérence du plan financier de l'utilisateur en
// comparant les versements réels (MonthlyCheckIn.versements)
// aux contributions planifiées (PlannedMonthlyContribution).
//
// compoundProjectedImpact() calcule l'impact composé FV
// du gap mensuel non-versé sur N mois (FV annuity formula).
//
// Outil éducatif — ne constitue pas un conseil financier (LSFin).
// ────────────────────────────────────────────────────────────

/// Résultat d'évaluation du plan financier.
class PlanStatus {
  final double score;
  final int completedActions;
  final int totalActions;
  final List<String> nextActions;

  /// Total CHF réellement versé par mois (moyenne des check-ins).
  final double averageMonthlyActual;

  /// Total CHF planifié par mois.
  final double totalMonthlyPlanned;

  const PlanStatus({
    required this.score,
    required this.completedActions,
    required this.totalActions,
    required this.nextActions,
    this.averageMonthlyActual = 0,
    this.totalMonthlyPlanned = 0,
  });

  /// Taux d'adhérence (0.0 - 1.0).
  double get adherenceRate =>
      totalActions > 0 ? completedActions / totalActions : 0;

  /// Gap mensuel CHF non-versé (planned - actual).
  double get monthlyGapChf =>
      (totalMonthlyPlanned - averageMonthlyActual).clamp(0, double.infinity);
}

/// Service d'évaluation du plan et projection de l'impact composé.
class PlanTrackingService {
  PlanTrackingService._();

  /// Évalue l'adhérence du plan en comparant check-ins réels aux contributions planifiées.
  ///
  /// Pour chaque [PlannedMonthlyContribution], cherche dans les [MonthlyCheckIn]
  /// les versements correspondants (par contribution.id dans versements keys).
  /// Un plan est "complété" si le versement moyen >= 80% du montant planifié.
  ///
  /// Retourne un [PlanStatus] avec score, adhérence, CHF réels et gap.
  static PlanStatus evaluate({
    required List<MonthlyCheckIn> checkIns,
    required List<PlannedMonthlyContribution> contributions,
  }) {
    if (contributions.isEmpty) {
      return const PlanStatus(
        score: 0,
        completedActions: 0,
        totalActions: 0,
        nextActions: [],
      );
    }

    final totalPlanned = contributions.fold(0.0, (s, c) => s + c.amount);
    int completed = 0;
    double totalActualMonthlyAvg = 0;
    final pendingActions = <String>[];

    for (final contrib in contributions) {
      // Find all check-in versements matching this contribution ID
      double sumActual = 0;

      for (final ci in checkIns) {
        final actual = ci.versements[contrib.id];
        if (actual != null) {
          sumActual += actual;
        }
      }

      // Missing key in a monthly check-in means 0 for this contribution.
      // Divide by total check-ins (not only matched entries) to avoid
      // inflating adherence when some months were skipped.
      final avgActual = checkIns.isNotEmpty ? sumActual / checkIns.length : 0.0;
      totalActualMonthlyAvg += avgActual;

      // Contribution is "completed" if average >= 80% of planned
      if (avgActual >= contrib.amount * 0.8) {
        completed++;
      } else {
        final gap = contrib.amount - avgActual;
        pendingActions.add(
          '${contrib.label} : +${gap.round()} CHF/mois',
        );
      }
    }

    final rate = completed / contributions.length;
    final score = (rate * 100).clamp(0, 100).toDouble();

    return PlanStatus(
      score: score,
      completedActions: completed,
      totalActions: contributions.length,
      nextActions: pendingActions.take(3).toList(),
      averageMonthlyActual: totalActualMonthlyAvg,
      totalMonthlyPlanned: totalPlanned,
    );
  }

  /// Calcule l'impact composé projeté du gap mensuel (FV annuity).
  ///
  /// Formule: monthlyGapChf × ((1+r)^n - 1) / r
  /// avec r = rendement mensuel, n = nombre de mois.
  ///
  /// Le PMT est le gap réel en CHF entre planifié et versé.
  /// Si le gap est 0 (tout est versé), l'impact est 0.
  ///
  /// [status] : résultat de evaluate() (contient monthlyGapChf).
  /// [monthsToRetirement] : nombre de mois jusqu'à la retraite.
  /// [annualReturn] : rendement réel annuel (défaut 2%, conservateur).
  ///
  /// Retourne le montant composé du gap (CHF) — ce que l'utilisateur
  /// pourrait accumuler en comblant le gap.
  ///
  /// Sources: LPP art. 15-16 (bonifications), OPP3 art. 7 (3a).
  /// Outil éducatif — ne constitue pas un conseil financier.
  static double compoundProjectedImpact({
    required PlanStatus status,
    required int monthsToRetirement,
    double annualReturn = 0.02, // 2% real return (conservative estimate)
  }) {
    if (monthsToRetirement <= 0) return 0;

    final monthlyGap = status.monthlyGapChf;
    if (monthlyGap <= 0) return 0;

    final monthlyRate = annualReturn / 12;
    final n = monthsToRetirement.toDouble();

    // FV annuity formula: PMT × ((1+r)^n - 1) / r
    if (monthlyRate == 0) return monthlyGap * n;
    return monthlyGap * ((pow(1 + monthlyRate, n) - 1) / monthlyRate);
  }
}
