import 'package:flutter/material.dart';

import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';

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
sealed class ContextualCard {
  /// Priority score for ranking (0.0 = lowest, 1.0 = highest).
  final double priorityScore;

  const ContextualCard({required this.priorityScore});
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
    required double priorityScore,
  }) : super(priorityScore: priorityScore);
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
    required double priorityScore,
  }) : super(priorityScore: priorityScore);
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
