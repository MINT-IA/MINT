import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart';

// ────────────────────────────────────────────────────────────
//  CARD RANKING SERVICE — Phase 9 / L1.5 MintAlertObject
// ────────────────────────────────────────────────────────────
//
// Pure-function tiebreaker (D-05) that floats Gravity.g3 alert
// cards to index 0 of the ContextualCard feed while preserving
// the input order within each tier (stable sort).
//
// Tiers (descending priority):
//   1. G3 alert cards   — top of feed, hard float
//   2. G2 alert cards   — calm-register block
//   3. ungraded cards   — everything else (hero, anticipation, action…)
//
// Within each tier the original input order is preserved. This is
// intentionally a one-pass O(n) partition — NOT a re-sort by score.
// Score-based ordering already happened upstream in
// ContextualRankingService.rank(); rankCards() only enforces the
// G3-floats-to-top invariant on top of it.
//
// Wired by ContextualCardProvider after aggregation. NEVER called by
// any claude_*_service.dart file.
// ────────────────────────────────────────────────────────────

/// Stable, pure tiebreaker that floats G3 alert cards to index 0.
///
/// Returns a new list. Input is not mutated.
///
/// Tiering rule:
///   * Cards with `gravity == Gravity.g3` go first (in input order).
///   * Cards with `gravity == Gravity.g2` go next (in input order).
///   * All other cards (ungraded or g1) go last (in input order).
///
/// Empty input returns an empty list.
List<ContextualCard> rankCards(List<ContextualCard> input) {
  if (input.isEmpty) return const <ContextualCard>[];

  final g3 = <ContextualCard>[];
  final g2 = <ContextualCard>[];
  final rest = <ContextualCard>[];

  for (final card in input) {
    switch (card.gravity) {
      case Gravity.g3:
        g3.add(card);
      case Gravity.g2:
        g2.add(card);
      case Gravity.g1:
      case null:
        rest.add(card);
    }
  }

  return <ContextualCard>[...g3, ...g2, ...rest];
}
