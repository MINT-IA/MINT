import 'dart:math';

import 'package:mint_mobile/models/coach_profile.dart';

/// Gap analysis for one planned contribution.
class ContributionGap {
  final String id;
  final String label;
  final double plannedMonthly;
  final double actualMonthly;
  final double gapMonthly;
  final double gapPercent;

  const ContributionGap({
    required this.id,
    required this.label,
    required this.plannedMonthly,
    required this.actualMonthly,
    required this.gapMonthly,
    required this.gapPercent,
  });
}

/// Aggregated plan-vs-reality status over a rolling window.
class PlanStatus {
  final bool hasPlan;
  final int monthsAnalyzed;
  final int monthsBehind;
  final double monthlyPlanned;
  final double monthlyActual;
  final double adherenceRate;
  final double projectedImpactChf;
  final List<ContributionGap> topGaps;

  const PlanStatus({
    required this.hasPlan,
    required this.monthsAnalyzed,
    required this.monthsBehind,
    required this.monthlyPlanned,
    required this.monthlyActual,
    required this.adherenceRate,
    required this.projectedImpactChf,
    required this.topGaps,
  });

  bool get isOffTrack => hasPlan && monthsBehind >= 2 && adherenceRate < 70.0;
}

/// Deterministic plan tracker (no network, no AI).
class PlanTrackingService {
  PlanTrackingService._();

  /// Compare planned monthly contributions with actual check-ins.
  ///
  /// `lookbackMonths` defaults to 3 to smooth one-off noise.
  static PlanStatus evaluate({
    required CoachProfile profile,
    int lookbackMonths = 3,
    DateTime? today,
  }) {
    final months = max(1, lookbackMonths);
    final planned = profile.plannedContributions;

    if (planned.isEmpty) {
      return const PlanStatus(
        hasPlan: false,
        monthsAnalyzed: 0,
        monthsBehind: 0,
        monthlyPlanned: 0,
        monthlyActual: 0,
        adherenceRate: 0,
        projectedImpactChf: 0,
        topGaps: [],
      );
    }

    final now = today ?? DateTime.now();
    final monthKeys = List<String>.generate(
      months,
      (i) => _monthKey(DateTime(now.year, now.month - i)),
    );
    final keySet = monthKeys.toSet();

    final checkinsByMonth = <String, MonthlyCheckIn>{};
    for (final ci in profile.checkIns) {
      final key = _monthKey(ci.month);
      if (!keySet.contains(key)) continue;
      final existing = checkinsByMonth[key];
      if (existing == null || ci.completedAt.isAfter(existing.completedAt)) {
        checkinsByMonth[key] = ci;
      }
    }

    final monthlyPlanned =
        planned.fold<double>(0.0, (sum, c) => sum + c.amount);

    double totalActual = 0;
    int monthsBehind = 0;
    final actualByContribution = <String, double>{
      for (final c in planned) c.id: 0.0,
    };

    for (final key in monthKeys) {
      final ci = checkinsByMonth[key];
      final monthActual = ci?.versements.values
              .where((v) => v.isFinite)
              .fold<double>(0.0, (sum, v) => sum + v) ??
          0.0;
      totalActual += monthActual;

      if (monthActual < monthlyPlanned * 0.70) {
        monthsBehind++;
      }

      if (ci != null) {
        for (final entry in ci.versements.entries) {
          if (!actualByContribution.containsKey(entry.key)) continue;
          actualByContribution[entry.key] =
              (actualByContribution[entry.key] ?? 0) + entry.value;
        }
      }
    }

    final expectedTotal = monthlyPlanned * months;
    final monthlyActual = totalActual / months;
    final adherence = expectedTotal > 0
        ? (totalActual / expectedTotal * 100).clamp(0.0, 200.0)
        : 100.0;

    final gaps = planned.map((c) {
      final actualMonthly = (actualByContribution[c.id] ?? 0) / months;
      final gap = c.amount - actualMonthly;
      final pct = c.amount > 0 ? (gap / c.amount) * 100 : 0.0;
      return ContributionGap(
        id: c.id,
        label: c.label,
        plannedMonthly: c.amount,
        actualMonthly: actualMonthly,
        gapMonthly: gap,
        gapPercent: pct,
      );
    }).toList()
      ..sort((a, b) => b.gapMonthly.compareTo(a.gapMonthly));

    final totalGapMonthly = gaps
        .where((g) => g.gapMonthly > 0)
        .fold<double>(0.0, (sum, g) => sum + g.gapMonthly);
    final monthsToRetirement = max(
      0,
      (profile.effectiveRetirementAge - profile.age) * 12,
    );
    final projectedImpact = totalGapMonthly * monthsToRetirement;

    return PlanStatus(
      hasPlan: true,
      monthsAnalyzed: months,
      monthsBehind: monthsBehind,
      monthlyPlanned: monthlyPlanned,
      monthlyActual: monthlyActual,
      adherenceRate: adherence,
      projectedImpactChf: projectedImpact,
      topGaps: gaps.take(3).toList(),
    );
  }

  static String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}
