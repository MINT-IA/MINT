import 'dart:math' as math;

import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';

// ────────────────────────────────────────────────────────────
//  ANTICIPATION RANKING — Phase 04 / Moteur d'Anticipation
// ────────────────────────────────────────────────────────────
//
// Deterministic priority ranking for anticipation signals.
//
// Formula: priority_score = timeliness * 0.5
//                         + user_relevance * 0.3
//                         + confidence * 0.2
//
// Top 2 signals (respecting weekly budget) are returned as
// visible cards; the rest go to overflow.
//
// Design: Pure static, zero side effects, zero async (ANT-06/ANT-08).
// Pattern: Follows NudgeEngine pure-static pattern.
//
// See: ANT-06 (ranking formula), ANT-05 (weekly budget).
// ────────────────────────────────────────────────────────────

/// Result of ranking anticipation signals.
///
/// [visible]: top signals to display as cards (max 2 per week).
/// [overflow]: remaining signals for expandable section.
class AnticipationRankResult {
  final List<AnticipationSignal> visible;
  final List<AnticipationSignal> overflow;

  const AnticipationRankResult({
    required this.visible,
    required this.overflow,
  });
}

/// Deterministic priority ranking for anticipation signals.
///
/// All methods are static pure functions. No side effects, no async.
class AnticipationRanking {
  AnticipationRanking._();

  /// Default confidence for template-based signals.
  ///
  /// Template-based signals have high inherent confidence since they
  /// are deterministic (not LLM-generated). Can be refined in Phase 5
  /// with actual biography freshness data.
  static const _defaultConfidence = 0.8;

  /// Maximum days for timeliness normalization.
  /// Signals beyond 90 days have timeliness = 0.0.
  static const _timelinessHorizon = 90.0;

  /// Maximum visible signals per week (ANT-05).
  static const _maxVisiblePerWeek = 2;

  /// Rank signals by priority score and split into visible + overflow.
  ///
  /// [signals]: all candidate signals from AnticipationEngine.
  /// [now]: current DateTime (injectable for tests).
  /// [signalsAlreadyShownThisWeek]: count from AnticipationPersistence.
  ///
  /// Returns [AnticipationRankResult] with top signals as visible
  /// (capped by weekly budget) and remaining as overflow.
  static AnticipationRankResult rank({
    required List<AnticipationSignal> signals,
    required DateTime now,
    required int signalsAlreadyShownThisWeek,
  }) {
    if (signals.isEmpty) {
      return const AnticipationRankResult(visible: [], overflow: []);
    }

    // Compute priority score for each signal
    final scored = signals.map((signal) {
      final timeliness = computeTimeliness(signal, now);
      final relevance = baseRelevance(signal.template);
      const confidence = _defaultConfidence;

      final score = timeliness * 0.5 + relevance * 0.3 + confidence * 0.2;
      return signal.copyWith(priorityScore: score);
    }).toList();

    // Sort descending by priority score
    scored.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    // Weekly budget: max visible = min(2, 2 - alreadyShown)
    final budget =
        math.max(0, _maxVisiblePerWeek - signalsAlreadyShownThisWeek);
    final visibleCount = math.min(budget, scored.length);

    return AnticipationRankResult(
      visible: scored.sublist(0, visibleCount),
      overflow: scored.sublist(visibleCount),
    );
  }

  /// Compute timeliness score (0.0 - 1.0) based on days until expiry.
  ///
  /// Closer to expiry = higher timeliness.
  /// - 0 days remaining = 1.0
  /// - 90+ days remaining = 0.0
  /// - Linear interpolation between.
  static double computeTimeliness(AnticipationSignal signal, DateTime now) {
    final daysUntilExpiry =
        signal.expiresAt.difference(now).inDays.toDouble();
    return (1.0 - (daysUntilExpiry / _timelinessHorizon)).clamp(0.0, 1.0);
  }

  /// Base relevance score per alert template type.
  ///
  /// These are static base relevances. Phase 5 can refine with
  /// actual user profile data (e.g., archetype, life events).
  static double baseRelevance(AlertTemplate template) {
    switch (template) {
      case AlertTemplate.fiscal3aDeadline:
        return 1.0;
      case AlertTemplate.salaryIncrease3aRecalc:
        return 0.95;
      case AlertTemplate.cantonalTaxDeadline:
        return 0.9;
      case AlertTemplate.ageMilestoneLppBonification:
        return 0.85;
      case AlertTemplate.lppRachatWindow:
        return 0.8;
    }
  }
}
