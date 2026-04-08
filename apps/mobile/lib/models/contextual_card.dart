import 'package:flutter/material.dart';

import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart';
import 'package:mint_mobile/widgets/alert/mint_alert_signal.dart';

// ────────────────────────────────────────────────────────────
//  CONTEXTUAL CARD — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Sealed class hierarchy for the 5 card types displayed on the
// Aujourd'hui tab. Each subtype carries its own data shape plus
// a shared priorityScore used by ContextualRankingService.
//
// Card types:
//   1. Hero Stat   — single dominant metric (always slot 1)
//   2. Anticipation — wraps Phase 4 AnticipationSignal
//   3. Progress     — milestone with animated progress bar
//   4. Action       — opportunity with chevron deep-link
//   5. Overflow     — container for >4 ranked cards
//
// Design: Immutable value objects, zero side effects.
// See: CTX-01, CTX-02 requirements.
// ────────────────────────────────────────────────────────────

/// Direction of a metric delta (for hero stat badge).
enum DeltaDirection { up, down, flat }

/// Base sealed class for all contextual cards.
///
/// [priorityScore] determines ranking order in the Aujourd'hui feed.
/// Hero card always has 1.0 (guaranteed slot 1).
///
/// [gravity] (Phase 9 D-03 / D-05) is an optional severity hint used by
/// `card_ranking_service.rankCards()` to float MintAlertObject-bearing cards
/// (Gravity.g3) to index 0. Null for non-alert cards (default).
sealed class ContextualCard {
  /// Priority score for ranking (0.0 = lowest, 1.0 = highest).
  final double priorityScore;

  /// Optional Phase 9 alert gravity hint. Null on every non-alert card.
  final Gravity? gravity;

  const ContextualCard({required this.priorityScore, this.gravity});
}

/// Slot 1: dominant financial metric with optional delta badge.
///
/// Shows a single large number (48px) with contextual narrative.
/// Always priorityScore = 1.0 (hero is always first).
final class ContextualHeroCard extends ContextualCard {
  /// Short label above the number (e.g., "Tu laisses X sur la table en 3a").
  final String label;

  /// Formatted display value (e.g., "7'258", "4'416 CHF/mois").
  final String value;

  /// Explanatory sentence below the number.
  final String narrative;

  /// Optional percentage change since last measurement.
  final double? deltaPercent;

  /// Direction of the delta (up = positive, down = negative, flat = unchanged).
  final DeltaDirection deltaDirection;

  /// GoRouter path for deep-link on tap.
  final String route;

  const ContextualHeroCard({
    required this.label,
    required this.value,
    required this.narrative,
    this.deltaPercent,
    this.deltaDirection = DeltaDirection.flat,
    required this.route,
    super.priorityScore = 1.0,
  });
}

/// Wraps a Phase 4 AnticipationSignal as a contextual card.
///
/// Delegates priorityScore to the signal's computed priority.
final class ContextualAnticipationCard extends ContextualCard {
  /// The underlying anticipation signal from Phase 4.
  final AnticipationSignal signal;

  ContextualAnticipationCard({
    required this.signal,
  }) : super(priorityScore: signal.priorityScore);
}

/// Progress milestone card with animated progress bar.
///
/// Shows profile completeness, biography milestones, etc.
final class ContextualProgressCard extends ContextualCard {
  /// Milestone title (e.g., "Ton profil se precise").
  final String title;

  /// Description with current progress detail.
  final String description;

  /// Progress percentage (0-100).
  final double percent;

  /// GoRouter path for deep-link on tap.
  final String route;

  const ContextualProgressCard({
    required this.title,
    required this.description,
    required this.percent,
    required this.route,
    required super.priorityScore,
  });
}

/// Action opportunity card with chevron deep-link.
///
/// Surfaces contextual next actions (scan document, complete profile).
final class ContextualActionCard extends ContextualCard {
  /// Action title (e.g., "Scanner un document").
  final String title;

  /// Action description body text.
  final String body;

  /// GoRouter path for deep-link on tap.
  final String route;

  /// Leading icon for the action.
  final IconData icon;

  const ContextualActionCard({
    required this.title,
    required this.body,
    required this.route,
    required this.icon,
    required super.priorityScore,
  });
}

/// Phase 9 — wraps a [MintAlertSignal] emitted by a rule-based feeder
/// (AnticipationProvider, NudgeEngine, ProactiveTriggerService) so it can
/// flow through the unified contextual card stream.
///
/// `card_ranking_service.rankCards()` floats G3 instances of this card to
/// index 0 (D-05). NEVER constructed inside a `claude_*_service.dart` file
/// (D-07; enforced by `tools/checks/no_llm_alert.py` in Plan 09-03).
final class ContextualAlertCard extends ContextualCard {
  /// The underlying typed alert signal.
  final MintAlertSignal signal;

  ContextualAlertCard({
    required this.signal,
    double? priorityScoreOverride,
  }) : super(
          // G3 → 1.0 visible slot priority; G2 → 0.85; G1 → 0.7. The
          // tiebreaker layer (rankCards) does the actual hard float for G3.
          priorityScore: priorityScoreOverride ??
              switch (signal.gravity) {
                Gravity.g3 => 1.0,
                Gravity.g2 => 0.85,
                Gravity.g1 => 0.70,
              },
          gravity: signal.gravity,
        );
}

/// Overflow container for cards beyond the visible 4 slots.
///
/// Contains a list of additional cards shown in an expandable section.
final class ContextualOverflowCard extends ContextualCard {
  /// The cards hidden in the overflow section.
  final List<ContextualCard> cards;

  const ContextualOverflowCard({
    required this.cards,
  }) : super(priorityScore: 0.0);
}
