/// TensionCardProvider — aggregates service data into 3 tension cards.
///
/// Phase 17: Living Timeline. Consumes CommitmentService, FreshStartService,
/// ConversationStore (via SharedPreferences), and PartnerEstimateService
/// to build exactly 3 cards (earned/pulsing/ghosted) for the Aujourd'hui tab.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/tension_card.dart';
import 'package:mint_mobile/services/commitment_service.dart';
import 'package:mint_mobile/services/fresh_start_service.dart';
import 'package:mint_mobile/services/partner_estimate_service.dart';

class TensionCardProvider extends ChangeNotifier {
  List<TensionCard> _cards = [];
  CleoLoopPosition _loopPosition = CleoLoopPosition.insight;
  bool _isLoading = true;

  List<TensionCard> get cards => _cards;
  CleoLoopPosition get loopPosition => _loopPosition;
  bool get isLoading => _isLoading;
  bool get isEmpty => _cards.isEmpty;

  /// Refresh tension cards from all data sources.
  ///
  /// All service calls are wrapped in try/catch — network failure
  /// produces empty state, never a crash (T-17-02 mitigation).
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    // ── Fetch data from all sources ──────────────────────────
    List<Map<String, dynamic>> commitments = [];
    try {
      commitments = await CommitmentService().getCommitments();
    } catch (_) {
      // Auth or network error — graceful empty
    }

    List<FreshStartLandmark> landmarks = [];
    try {
      landmarks = await FreshStartService().fetchLandmarks();
    } catch (_) {
      // Non-critical — graceful empty
    }

    int conversationCount = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexRaw = prefs.getString(_conversationIndexKey());
      if (indexRaw != null) {
        final list = jsonDecode(indexRaw) as List<dynamic>;
        conversationCount = list.length;
      }
    } catch (_) {
      // SharedPreferences read error — treat as 0
    }

    PartnerEstimate? partner;
    try {
      partner = await PartnerEstimateService.load();
    } catch (_) {
      // SecureStorage error — graceful null
    }

    // ── Build cards ──────────────────────────────────────────
    _cards = _selectTensions(
      commitments: commitments,
      landmarks: landmarks,
      conversationCount: conversationCount,
      partner: partner,
    );

    // ── Determine loop position ──────────────────────────────
    _loopPosition = _determineLoopPosition(
      commitments: commitments,
      conversationCount: conversationCount,
      landmarks: landmarks,
    );

    _isLoading = false;
    notifyListeners();
  }

  // ── Private helpers ──────────────────────────────────────────

  /// Build the conversation index key matching ConversationStore pattern.
  /// ConversationStore uses `${userId}_${_indexKey}` when userId is set.
  /// We read directly from SharedPreferences to avoid coupling to the store.
  String _conversationIndexKey() => '_chat_conversation_index';

  /// Select exactly 3 tension cards from available data.
  ///
  /// T-17-01 mitigation: cards show category labels only, never amounts or PII.
  List<TensionCard> _selectTensions({
    required List<Map<String, dynamic>> commitments,
    required List<FreshStartLandmark> landmarks,
    required int conversationCount,
    required PartnerEstimate? partner,
  }) {
    // ── Earned (past) ────────────────────────────────────────
    TensionCard? earned;
    final completed = commitments
        .where((c) => c['status'] == 'completed')
        .toList();
    if (completed.isNotEmpty) {
      earned = TensionCard(
        type: TensionType.earned,
        title: 'tensionEarnedCommitment', // resolved via i18n in widget
        subtitle: completed.first['whenText'] as String? ?? '',
        deepLink: '/coach/chat?prompt=Montre-moi+mes+engagements+tenus',
        date: DateTime.tryParse(
          completed.first['updatedAt'] as String? ?? '',
        ),
      );
    } else if (partner != null && partner.isDeclared) {
      earned = const TensionCard(
        type: TensionType.earned,
        title: 'tensionEarnedCommitment',
        subtitle: '',
        deepLink: '/coach/chat?prompt=Montre-moi+mes+engagements+tenus',
      );
    } else if (conversationCount > 0) {
      earned = const TensionCard(
        type: TensionType.earned,
        title: 'tensionEarnedFirstConvo',
        subtitle: '',
        deepLink: '/coach/chat?prompt=Montre-moi+mes+engagements+tenus',
      );
    }

    // ── Pulsing (present) ────────────────────────────────────
    TensionCard? pulsing;
    final active = commitments
        .where((c) => c['status'] == 'active')
        .toList();
    if (active.isNotEmpty) {
      pulsing = TensionCard(
        type: TensionType.pulsing,
        title: 'tensionPulsingActiveCommitment',
        subtitle: active.first['ifThenText'] as String? ?? '',
        deepLink: '/coach/chat',
        date: DateTime.tryParse(
          active.first['createdAt'] as String? ?? '',
        ),
      );
    } else if (conversationCount > 0) {
      pulsing = const TensionCard(
        type: TensionType.pulsing,
        title: 'tensionPulsingActiveCommitment',
        subtitle: '',
        deepLink: '/coach/chat',
      );
    }

    // ── Ghosted (future) ─────────────────────────────────────
    TensionCard? ghosted;
    if (landmarks.isNotEmpty) {
      final nearest = landmarks.reduce(
        (a, b) => a.daysUntil < b.daysUntil ? a : b,
      );
      ghosted = TensionCard(
        type: TensionType.ghosted,
        title: 'tensionGhostedLandmark',
        subtitle: nearest.message,
        deepLink: '/coach/chat?prompt=Parle-moi+de+mon+prochain+jalon',
        date: DateTime.tryParse(nearest.date),
      );
    }

    // ── If all null, return empty (triggers empty state) ─────
    if (earned == null && pulsing == null && ghosted == null) {
      return [];
    }

    // ── Fill missing slots with sensible defaults ────────────
    earned ??= conversationCount > 0
        ? const TensionCard(
            type: TensionType.earned,
            title: 'tensionEarnedFirstConvo',
            subtitle: '',
            deepLink: '/coach/chat?prompt=Montre-moi+mes+engagements+tenus',
          )
        : const TensionCard(
            type: TensionType.earned,
            title: 'tensionEarnedFirstConvo',
            subtitle: '',
            deepLink: '/coach/chat',
          );

    pulsing ??= const TensionCard(
      type: TensionType.pulsing,
      title: 'tensionPulsingTalkToCoach',
      subtitle: '',
      deepLink: '/coach/chat',
    );

    ghosted ??= const TensionCard(
      type: TensionType.ghosted,
      title: 'tensionGhostedFuture',
      subtitle: '',
      deepLink: '/coach/chat?prompt=Parle-moi+de+mon+prochain+jalon',
    );

    return [earned, pulsing, ghosted];
  }

  /// Determine current Cleo loop position from most recent activity.
  CleoLoopPosition _determineLoopPosition({
    required List<Map<String, dynamic>> commitments,
    required int conversationCount,
    required List<FreshStartLandmark> landmarks,
  }) {
    // Active commitment = action phase
    final hasActive = commitments.any((c) => c['status'] == 'active');
    if (hasActive) return CleoLoopPosition.action;

    // Conversations exist = conversation phase
    if (conversationCount > 0) return CleoLoopPosition.conversation;

    // Landmarks received = insight phase
    if (landmarks.isNotEmpty) return CleoLoopPosition.insight;

    return CleoLoopPosition.insight;
  }
}
