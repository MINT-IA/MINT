import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/contextual/action_opportunity_detector.dart';
import 'package:mint_mobile/services/contextual/hero_stat_resolver.dart';
import 'package:mint_mobile/services/contextual/progress_milestone_detector.dart';

// ────────────────────────────────────────────────────────────
//  CONTEXTUAL RANKING SERVICE — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Unified ranking service producing max 5 ranked cards
// (4 direct + 1 overflow) from heterogeneous card types.
//
// Formula: hero always slot 1, rest sorted by priorityScore desc.
// Cards with priorityScore == 0 sort last (CTX-05).
//
// Design: Pure static, zero side effects, injectable DateTime.
// See: CTX-02, CTX-05 requirements.
// ────────────────────────────────────────────────────────────

/// Maximum direct visible cards (hero + 3 non-hero).
const _maxVisibleSlots = 4;

/// Maximum non-hero slots.
const _maxNonHeroSlots = _maxVisibleSlots - 1;

/// Result of contextual card ranking.
class ContextualRankResult {
  /// Top cards to display directly (max 4).
  final List<ContextualCard> visible;

  /// Overflow card containing remaining cards (null if none).
  final ContextualOverflowCard? overflow;

  const ContextualRankResult({
    required this.visible,
    this.overflow,
  });
}

/// Unified ranking service for all contextual card types.
///
/// Pure static class — no state, no side effects.
class ContextualRankingService {
  ContextualRankingService._();

  /// Rank all contextual cards and split into visible + overflow.
  ///
  /// Steps:
  /// 1. Resolve hero card (always slot 1)
  /// 2. Wrap anticipation signals as contextual cards
  /// 3. Detect action opportunities
  /// 4. Detect progress milestones
  /// 5. Sort non-hero cards by priorityScore descending
  /// 6. Top 3 non-hero -> slots 2-4, rest -> overflow
  ///
  /// Deterministic: same inputs always produce same order.
  static ContextualRankResult rank({
    required CoachProfile profile,
    required List<BiographyFact> facts,
    required List<AnticipationSignal> anticipationVisible,
    required List<AnticipationSignal> anticipationOverflow,
    DateTime? now,
  }) {
    // (a) Resolve hero card — always slot 1
    final hero = HeroStatResolver.resolve(
      profile: profile,
      facts: facts,
      now: now,
    );

    // (b) Wrap anticipation visible signals as contextual cards
    final anticipationCards = anticipationVisible
        .map((s) => ContextualAnticipationCard(signal: s))
        .toList();

    // Also include overflow anticipation signals (they are candidates
    // for the unified ranking — Phase 4 overflow may fit in Phase 5 slots)
    final overflowAnticipationCards = anticipationOverflow
        .map((s) => ContextualAnticipationCard(signal: s))
        .toList();

    // (c) Detect action opportunities
    final actionCards = ActionOpportunityDetector.detect(
      profile: profile,
      facts: facts,
    );

    // (d) Detect progress milestones
    final progressCards = ProgressMilestoneDetector.detect(
      profile: profile,
      facts: facts,
    );

    // (e) Collect all non-hero cards
    final nonHero = <ContextualCard>[
      ...anticipationCards,
      ...overflowAnticipationCards,
      ...actionCards,
      ...progressCards,
    ];

    // Sort by priorityScore descending (deterministic: stable sort)
    // Cards with priorityScore == 0 sort last (CTX-05: completed actions)
    nonHero.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    // (f) Split into visible (top 3) and overflow
    final visibleNonHero = nonHero.take(_maxNonHeroSlots).toList();
    final overflowCards = nonHero.skip(_maxNonHeroSlots).toList();

    // Build result
    final visible = <ContextualCard>[hero, ...visibleNonHero];

    final overflowCard = overflowCards.isNotEmpty
        ? ContextualOverflowCard(cards: overflowCards)
        : null;

    return ContextualRankResult(
      visible: visible,
      overflow: overflowCard,
    );
  }
}
