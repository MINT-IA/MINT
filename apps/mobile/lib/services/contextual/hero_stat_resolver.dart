import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';

// ────────────────────────────────────────────────────────────
//  HERO STAT RESOLVER — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Selects the most impactful metric for the hero card (slot 1).
//
// Priority: (1) 3a gap > (2) retirement income > (3) profile completeness
//
// Design: Pure static, zero side effects, zero async.
// See: CTX-01 requirement.
// ────────────────────────────────────────────────────────────

/// Resolves the hero stat card based on profile data.
///
/// Pure static class — no state, no side effects.
class HeroStatResolver {
  HeroStatResolver._();

  /// Resolve the hero stat from profile and biography.
  ///
  /// Priority:
  /// 1. 3a contribution gap (if salary present and gap > 0)
  /// 2. Retirement income projection (if LPP data available)
  /// 3. Profile completeness (fallback)
  static ContextualHeroCard resolve({
    required CoachProfile profile,
    required List<BiographyFact> facts,
    DateTime? now,
  }) {
    // TODO: implement
    throw UnimplementedError();
  }
}
