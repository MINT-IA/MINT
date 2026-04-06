import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';

// ────────────────────────────────────────────────────────────
//  CONTEXTUAL RANKING SERVICE — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Unified ranking service producing max 5 ranked cards
// (4 direct + 1 overflow) from heterogeneous card types.
//
// Formula: hero always slot 1, rest sorted by priorityScore desc.
//
// Design: Pure static, zero side effects, injectable DateTime.
// See: CTX-02, CTX-05 requirements.
// ────────────────────────────────────────────────────────────

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
  static ContextualRankResult rank({
    required CoachProfile profile,
    required List<BiographyFact> facts,
    required List<AnticipationSignal> anticipationVisible,
    required List<AnticipationSignal> anticipationOverflow,
    DateTime? now,
  }) {
    // TODO: implement
    throw UnimplementedError();
  }
}
