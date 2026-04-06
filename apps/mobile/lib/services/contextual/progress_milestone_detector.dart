import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';

// ────────────────────────────────────────────────────────────
//  PROGRESS MILESTONE DETECTOR — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Detects progress milestones from profile and biography state.
//
// Design: Pure static, zero side effects, zero async.
// See: CTX-05 requirement.
// ────────────────────────────────────────────────────────────

/// Detects progress milestones from profile completeness and biography.
///
/// Pure static class — no state, no side effects.
class ProgressMilestoneDetector {
  ProgressMilestoneDetector._();

  /// Detect active progress milestones.
  ///
  /// Returns max 2 progress cards.
  static List<ContextualProgressCard> detect({
    required CoachProfile profile,
    required List<BiographyFact> facts,
  }) {
    // TODO: implement
    throw UnimplementedError();
  }
}
