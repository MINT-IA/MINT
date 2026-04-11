import 'dart:math' as math;

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

// ────────────────────────────────────────────────────────────
//  PROGRESS MILESTONE DETECTOR — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Detects progress milestones from profile and biography state.
//
// Milestones:
//   (a) Profile completeness between 20-95%
//   (b) Biography fact count >= 3
//
// Design: Pure static, zero side effects, zero async.
// See: CTX-05 requirement.
// ────────────────────────────────────────────────────────────

/// Detects progress milestones from profile completeness and biography.
///
/// Pure static class — no state, no side effects.
class ProgressMilestoneDetector {
  ProgressMilestoneDetector._();

  /// Maximum progress cards returned.
  static const _maxProgress = 2;

  /// Detect active progress milestones.
  ///
  /// Returns max 2 progress cards.
  static List<ContextualProgressCard> detect({
    required CoachProfile profile,
    required List<BiographyFact> facts,
  }) {
    final cards = <ContextualProgressCard>[];

    // (a) Profile completeness between 20-95%
    final confidence = ConfidenceScorer.scoreEnhanced(profile);
    final completeness = confidence.combined;
    if (completeness >= 20 && completeness <= 95) {
      cards.add(ContextualProgressCard(
        title: 'Ton profil se precise',
        description:
            '${completeness.toStringAsFixed(0)}\u00a0% de tes donnees sont a jour.',
        percent: completeness,
        route: '/coach/chat?prompt=profile',
        priorityScore: 0.5,
      ));
    }

    // (b) Biography fact count >= 3
    if (cards.length < _maxProgress && facts.length >= 3) {
      final count = facts.length;
      final percent = math.min(count / 10 * 100, 100.0);
      cards.add(ContextualProgressCard(
        title: 'Memoire financiere active',
        description:
            'MINT connait $count elements de ton histoire financiere.',
        percent: percent,
        route: '/profile/privacy-control',
        priorityScore: 0.4,
      ));
    }

    return cards.take(_maxProgress).toList();
  }
}
