import 'package:flutter/foundation.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/contextual/card_ranking_service.dart';
import 'package:mint_mobile/services/contextual/coach_opener_service.dart';
import 'package:mint_mobile/services/contextual/contextual_ranking_service.dart';

// ────────────────────────────────────────────────────────────
//  CONTEXTUAL CARD PROVIDER — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// ChangeNotifier bridging ContextualRankingService and
// CoachOpenerService to the widget tree. Evaluates once per
// session (CTX-02) and exposes ranked cards + coach opener.
//
// Consumers: MintHomeScreen via context.watch<ContextualCardProvider>()
//
// Pattern: Follows AnticipationProvider (session cache, resetSession).
// See: CTX-02, CTX-03, CTX-05 requirements.
// ────────────────────────────────────────────────────────────

/// Provider bridging contextual ranking service to widget tree.
///
/// Evaluates once per session, exposing ranked cards and
/// biography-aware coach opener for the Aujourd'hui tab.
class ContextualCardProvider extends ChangeNotifier {
  ContextualRankResult? _rankResult;
  String _coachOpener = '';
  bool _evaluated = false;

  /// Visible cards (hero + up to 3 non-hero), with Phase 9 G3 alert
  /// cards floated to index 0 by [rankCards] (D-05).
  List<ContextualCard> get visibleCards =>
      rankCards(_rankResult?.visible ?? const []);

  /// Overflow card containing remaining cards (null if none).
  ContextualOverflowCard? get overflowCard => _rankResult?.overflow;

  /// Biography-aware coach opener text.
  String get coachOpener => _coachOpener;

  /// Whether evaluation has been performed this session.
  bool get evaluated => _evaluated;

  /// Evaluate contextual cards for the current session.
  ///
  /// Only evaluates once per session (CTX-02). Call [resetSession]
  /// to allow re-evaluation on next app launch.
  ///
  /// Orchestrates:
  /// 1. [ContextualRankingService.rank] for card ranking
  /// 2. [CoachOpenerService.generate] for biography-aware opener
  Future<void> evaluateOnSessionStart({
    required CoachProfile profile,
    required List<BiographyFact> facts,
    required List<AnticipationSignal> anticipationVisible,
    required List<AnticipationSignal> anticipationOverflow,
    DateTime? now,
  }) async {
    if (_evaluated) return;

    try {
      // Rank contextual cards
      _rankResult = ContextualRankingService.rank(
        profile: profile,
        facts: facts,
        anticipationVisible: anticipationVisible,
        anticipationOverflow: anticipationOverflow,
        now: now,
      );

      // Generate biography-aware coach opener
      _coachOpener = CoachOpenerService.generate(
        profile: profile,
        facts: facts,
        now: now,
      );

      _evaluated = true;
    } catch (e) {
      debugPrint('[ContextualCardProvider] Evaluation error: $e');
      _rankResult = const ContextualRankResult(visible: []);
      _coachOpener = 'Bienvenue. Voici ton aperçu financier.';
      _evaluated = true;
    }

    notifyListeners();
  }

  /// Reset session flag to allow re-evaluation on next app launch.
  void resetSession() {
    _evaluated = false;
  }

  /// Demote a card by setting its priority to 0 (CTX-05).
  ///
  /// Removes the card from visible and adds to overflow if present.
  void demoteCard(ContextualCard card) {
    if (_rankResult == null) return;

    final visible = _rankResult!.visible.where((c) => c != card).toList();
    final existingOverflow = _rankResult!.overflow?.cards ?? [];
    final overflow = [...existingOverflow, card];

    _rankResult = ContextualRankResult(
      visible: visible,
      overflow: overflow.isNotEmpty
          ? ContextualOverflowCard(cards: overflow)
          : null,
    );

    notifyListeners();
  }
}
