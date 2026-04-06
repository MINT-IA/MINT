import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';

// ────────────────────────────────────────────────────────────
//  ACTION OPPORTUNITY DETECTOR — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Surfaces contextual next actions based on profile state.
//
// Design: Pure static, zero side effects, zero async.
// See: CTX-05 requirement.
// ────────────────────────────────────────────────────────────

/// Detects action opportunities based on profile state.
///
/// Pure static class — no state, no side effects.
class ActionOpportunityDetector {
  ActionOpportunityDetector._();

  /// Detect action opportunities from profile and biography.
  ///
  /// Returns max 2 action cards.
  static List<ContextualActionCard> detect({
    required CoachProfile profile,
    required List<BiographyFact> facts,
  }) {
    // TODO: implement
    throw UnimplementedError();
  }
}
