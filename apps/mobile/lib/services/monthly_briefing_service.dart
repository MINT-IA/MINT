import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/micro_action_engine.dart';

// ────────────────────────────────────────────────────────────
//  MONTHLY BRIEFING SERVICE — Coach Vivant (Track A)
// ────────────────────────────────────────────────────────────
//
//  Compare le mois N vs N-1 a partir des MonthlyCheckIn.
//  Genere un MonthlyBriefingDelta avec:
//    - Deltas versements (CHF + %)
//    - Tendance (en_hausse / stable / en_baisse)
//    - Insights comparatifs (max 3 phrases)
//    - Micro-actions recommandees (max 3)
//
//  Ne constitue pas un conseil financier — outil educatif (LSFin).
// ────────────────────────────────────────────────────────────

/// Trend direction for month-to-month comparison.
enum BriefingTrend { enHausse, stable, enBaisse }

/// Result of comparing month N vs month N-1.
class MonthlyBriefingDelta {
  /// Current month's check-in data.
  final MonthlyCheckIn currentMonth;

  /// Previous month's check-in data (null if first check-in).
  final MonthlyCheckIn? previousMonth;

  /// Absolute change in total versements (CHF).
  final double versementsDeltaChf;

  /// Relative change in total versements (%).
  final double versementsDeltaPct;

  /// Absolute change in depenses exceptionnelles (CHF).
  final double depensesExcDeltaChf;

  /// Absolute change in revenus exceptionnels (CHF).
  final double revenusExcDeltaChf;

  /// Overall trend direction.
  final BriefingTrend trend;

  /// FRI score delta (current - previous). 0 if no previous snapshot.
  final double friDelta;

  /// Comparative insights (max 3 phrases, compliance-safe).
  final List<String> insights;

  /// Recommended micro-actions for this month.
  final List<MicroAction> microActions;

  /// Disclaimer (required by LSFin).
  final String disclaimer;

  const MonthlyBriefingDelta({
    required this.currentMonth,
    this.previousMonth,
    required this.versementsDeltaChf,
    required this.versementsDeltaPct,
    required this.depensesExcDeltaChf,
    required this.revenusExcDeltaChf,
    required this.trend,
    required this.friDelta,
    required this.insights,
    required this.microActions,
    required this.disclaimer,
  });

  /// Whether this is the user's first check-in (no N-1 available).
  bool get isFirstCheckIn => previousMonth == null;

  /// Narrative-ready trend label in French.
  String get trendLabel => switch (trend) {
        BriefingTrend.enHausse => 'en hausse',
        BriefingTrend.stable => 'stable',
        BriefingTrend.enBaisse => 'en baisse',
      };
}

class MonthlyBriefingService {
  MonthlyBriefingService._();

  static const _disclaimer =
      'Outil educatif — ne constitue pas un conseil financier. LSFin.';

  /// Compare two consecutive monthly check-ins and generate a briefing.
  ///
  /// [profile] is needed for micro-action generation (age, archetype, gaps).
  /// If [previous] is null, generates a "first check-in" briefing.
  static MonthlyBriefingDelta compare({
    required CoachProfile profile,
    required MonthlyCheckIn current,
    MonthlyCheckIn? previous,
  }) {
    // ── Versements delta ──────────────────────────────
    final currentTotal = current.totalVersements;
    final previousTotal = previous?.totalVersements ?? 0;
    final vDeltaChf = currentTotal - previousTotal;
    final vDeltaPct =
        previousTotal > 0 ? (vDeltaChf / previousTotal) * 100 : 0.0;

    // ── Depenses exceptionnelles delta ────────────────
    final currentDepExc = current.depensesExceptionnelles ?? 0;
    final previousDepExc = previous?.depensesExceptionnelles ?? 0;
    final depExcDelta = currentDepExc - previousDepExc;

    // ── Revenus exceptionnels delta ──────────────────
    final currentRevExc = current.revenusExceptionnels ?? 0;
    final previousRevExc = previous?.revenusExceptionnels ?? 0;
    final revExcDelta = currentRevExc - previousRevExc;

    // ── Trend detection ──────────────────────────────
    final trend = _detectTrend(vDeltaPct, previous);

    // ── FRI delta (from persisted check-in snapshots) ─
    final friDelta = _computeFriDelta(current, previous);

    // ── Insights generation ──────────────────────────
    final insights = _generateInsights(
      profile: profile,
      current: current,
      previous: previous,
      vDeltaChf: vDeltaChf,
      vDeltaPct: vDeltaPct,
      depExcDelta: depExcDelta,
      friDelta: friDelta,
    );

    // ── Micro-actions ────────────────────────────────
    final microActions = MicroActionEngine.suggest(
      profile: profile,
      currentCheckIn: current,
      previousCheckIn: previous,
    );

    return MonthlyBriefingDelta(
      currentMonth: current,
      previousMonth: previous,
      versementsDeltaChf: vDeltaChf,
      versementsDeltaPct: vDeltaPct,
      depensesExcDeltaChf: depExcDelta,
      revenusExcDeltaChf: revExcDelta,
      trend: trend,
      friDelta: friDelta,
      insights: insights,
      microActions: microActions,
      disclaimer: _disclaimer,
    );
  }

  /// Convenience: generate briefing from profile's check-in history.
  ///
  /// Uses the last two check-ins from [profile.checkIns].
  static MonthlyBriefingDelta? fromProfile(CoachProfile profile) {
    if (profile.checkIns.isEmpty) return null;

    final sorted = List<MonthlyCheckIn>.from(profile.checkIns)
      ..sort((a, b) => b.month.compareTo(a.month));

    final current = sorted.first;
    final previous = sorted.length >= 2 ? sorted[1] : null;

    return compare(
      profile: profile,
      current: current,
      previous: previous,
    );
  }

  // ──────────────────────────────────────────────────
  //  PRIVATE: Trend detection
  // ──────────────────────────────────────────────────

  static BriefingTrend _detectTrend(
      double vDeltaPct, MonthlyCheckIn? previous) {
    if (previous == null) return BriefingTrend.stable;
    if (vDeltaPct > 5) return BriefingTrend.enHausse;
    if (vDeltaPct < -5) return BriefingTrend.enBaisse;
    return BriefingTrend.stable;
  }

  // ──────────────────────────────────────────────────
  //  PRIVATE: FRI delta (from persisted check-in snapshots)
  // ──────────────────────────────────────────────────

  static double _computeFriDelta(
      MonthlyCheckIn current, MonthlyCheckIn? previous) {
    // Both check-ins need persisted FRI scores for a real delta.
    // Legacy check-ins (before FRI snapshot) have null friScore → delta = 0.
    final currentFri = current.friScore;
    final previousFri = previous?.friScore;
    if (currentFri != null && previousFri != null) {
      return currentFri - previousFri;
    }
    return 0;
  }

  // ──────────────────────────────────────────────────
  //  PRIVATE: Comparative insights (max 3)
  // ──────────────────────────────────────────────────

  static List<String> _generateInsights({
    required CoachProfile profile,
    required MonthlyCheckIn current,
    MonthlyCheckIn? previous,
    required double vDeltaChf,
    required double vDeltaPct,
    required double depExcDelta,
    required double friDelta,
  }) {
    final insights = <String>[];

    if (previous == null) {
      insights.add(
          'Premier check-in enregistre. A partir du mois prochain, tu verras ton evolution.');
      if (current.totalVersements > 0) {
        insights.add(
            'Tu as verse CHF ${current.totalVersements.round()} ce mois.');
      }
      return insights;
    }

    // ── Versements trend ──────────────────────────
    if (vDeltaPct > 10) {
      insights.add(
          'Tes versements sont en hausse de ${vDeltaPct.round()}% vs le mois dernier.');
    } else if (vDeltaPct < -10) {
      insights.add(
          'Tes versements ont baisse de ${vDeltaPct.abs().round()}% vs le mois dernier.');
    } else if (vDeltaPct.abs() <= 5) {
      insights.add('Tes versements restent stables ce mois.');
    }

    // ── Depenses exceptionnelles ──────────────────
    if (depExcDelta > 500) {
      insights.add(
          'Depenses exceptionnelles en hausse de CHF ${depExcDelta.round()}. '
          'Pense a ajuster ton budget si necessaire.');
    }

    // ── Per-category versement changes ────────────
    if (insights.length < 3) {
      final categoriesUp = <String>[];
      for (final entry in current.versements.entries) {
        final prevVal = previous.versements[entry.key] ?? 0;
        if (entry.value > prevVal && prevVal > 0) {
          categoriesUp.add(_readableCategoryName(entry.key));
        }
      }
      if (categoriesUp.isNotEmpty && categoriesUp.length <= 2) {
        insights.add(
            'En progression : ${categoriesUp.join(' et ')}.');
      }
    }

    return insights.take(3).toList();
  }

  static String _readableCategoryName(String key) {
    if (key.contains('3a')) return '3e pilier';
    if (key.contains('lpp') || key.contains('rachat')) return 'rachat LPP';
    if (key.contains('invest') || key.contains('marche')) return 'investissement';
    if (key.contains('epargne')) return 'epargne';
    return key;
  }
}
