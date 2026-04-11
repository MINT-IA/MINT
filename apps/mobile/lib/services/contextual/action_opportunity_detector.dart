import 'package:flutter/material.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

// ────────────────────────────────────────────────────────────
//  ACTION OPPORTUNITY DETECTOR — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Surfaces contextual next actions based on profile state.
//
// Checks in order:
//   (a) No document scans -> "Scanner un document"
//   (b) Completeness < 70% -> "Completer ton profil"
//
// Design: Pure static, zero side effects, zero async.
// See: CTX-05 requirement.
// ────────────────────────────────────────────────────────────

/// Detects action opportunities based on profile state.
///
/// Pure static class — no state, no side effects.
class ActionOpportunityDetector {
  ActionOpportunityDetector._();

  /// Maximum action cards returned.
  static const _maxActions = 2;

  /// Detect action opportunities from profile and biography.
  ///
  /// Returns max 2 action cards, ordered by priority.
  static List<ContextualActionCard> detect({
    required CoachProfile profile,
    required List<BiographyFact> facts,
  }) {
    final cards = <ContextualActionCard>[];

    // (a) No document scans in biography -> suggest scanning
    final hasDocumentScans = facts.any(
      (f) => f.source == FactSource.document,
    );
    if (!hasDocumentScans) {
      cards.add(const ContextualActionCard(
        title: 'Scanner un document',
        body: 'Un certificat LPP ou de salaire affine tes projections.',
        route: '/scan',
        icon: Icons.document_scanner_outlined,
        priorityScore: 0.7,
      ));
    }

    // (b) Profile completeness < 70% -> suggest completing profile
    if (cards.length < _maxActions) {
      final confidence = ConfidenceScorer.scoreEnhanced(profile);
      final completeness = confidence.combined;
      if (completeness < 70) {
        cards.add(const ContextualActionCard(
          title: 'Completer ton profil',
          body:
              'Quelques informations de plus pour des projections fiables.',
          route: '/coach/chat?prompt=profile',
          icon: Icons.person_add_outlined,
          priorityScore: 0.6,
        ));
      }
    }

    return cards.take(_maxActions).toList();
  }
}
