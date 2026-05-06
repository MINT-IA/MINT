// ────────────────────────────────────────────────────────────
//  CROSS-SESSION OPENER BUILDER — Phase 91 / VIVANT-02
// ────────────────────────────────────────────────────────────
//
// Cleo 3.0 parity. When a returning user re-opens [CoachChatScreen]
// AND [_messages.isEmpty] AND [hasSeenPremierEclairage] is true, we
// prepend a single coach bubble that references the prior session
// instead of re-rendering the cold first-contact opener.
//
// Source of truth :
//   - [CapMemoryStore.load()]      → [CapMemory] (last completed cap +
//                                    last cap served + completed actions).
//   - [ConversationMemoryService.buildMemory()] → [ConversationMemory]
//                                    (frequent topics, recent titles,
//                                    last conversation date).
//
// This is a pure async function — caller awaits on screen mount, no
// silent prefetch (per 91-CONTEXT decisions VIVANT-02).
//
// Returns null when neither source has any signal — caller falls
// back to the existing 4-chip opener / silent opener.
//
// DEVIATION (documented per Karpathy practice 3 — match existing
// infra, don't invent APIs that aren't there) :
//   - The PLAN spec referenced [CapMemoryStore.lastOutcome] and
//     [ConversationMemoryService.getSummary(maxTokens: 200)] but the
//     real codebase does NOT expose those signatures. We adapt :
//       * topic source = [CapMemory.lastCompletedCapHeadline] →
//         fallback [CapMemory.lastCapServed] → fallback first
//         [ConversationMemory.frequentTopics] entry → fallback first
//         [ConversationMemory.recentTitles] entry.
//       * action source = a generic localized « tu veux qu'on regarde
//         la suite ? » via [coachOpenerCrossSessionAction] (single key,
//         language-agnostic at the wire layer).
//   - This keeps the contract intact (« reference last topic + suggest
//     next action ») while staying honest about the actual stores.
// ────────────────────────────────────────────────────────────

import 'package:flutter/widgets.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/conversation_memory_service.dart';

/// Builds the localized cross-session opener string for [CoachChatScreen].
///
/// Returns `null` when neither [CapMemory] nor [ConversationMemory] carries
/// any usable topic — the caller (CoachChatScreen empty-state branch) then
/// falls back to the existing 4-chip first-contact opener.
class CrossSessionOpenerBuilder {
  CrossSessionOpenerBuilder._();

  /// Topic-tag → human label map. Mirrors the curated list already used
  /// by [MemoryReferenceService] so we stay consistent with the rest of
  /// the coach memory layer (lpp → « 2e pilier », 3a → « 3e pilier »…).
  ///
  /// When a tag is not in the map, the raw tag is used as-is (after a
  /// light cleanup) — this is the safest behaviour for unknown caps
  /// (e.g. canton-specific or experimental cap ids).
  static const Map<String, String> _topicLabels = <String, String>{
    'lpp': '2e pilier',
    'avs': 'AVS',
    '3a': '3e pilier',
    'pillar_3a': '3e pilier',
    'pillar3a': '3e pilier',
    'retraite': 'la retraite',
    'retirement': 'la retraite',
    'housing': 'l’immobilier',
    'logement': 'l’immobilier',
    'tax': 'la fiscalité',
    'fiscal': 'la fiscalité',
    'fiscalite': 'la fiscalité',
    'budget': 'le budget',
    'divorce': 'le divorce',
    'marriage': 'le mariage',
    'birth': 'la naissance',
    'inheritance': 'la succession',
    'disability': 'l’invalidité',
    'debt': 'les dettes',
  };

  /// Pure async builder. Reads memory + outcome, returns the formatted
  /// opener or `null` (no memory → caller shows the 4-chip opener).
  ///
  /// Inputs are kept overrideable for testing :
  ///   - [memoryOverride]  injects a pre-built [CapMemory]
  ///   - [convOverride]    injects a pre-built [ConversationMemory]
  ///
  /// When both overrides are null, the function loads the live stores.
  static Future<String?> build({
    required BuildContext context,
    CapMemory? memoryOverride,
    ConversationMemory? convOverride,
  }) async {
    final S? l = S.of(context);
    if (l == null) return null;
    return buildWithLocalizations(
      l: l,
      memoryOverride: memoryOverride,
      convOverride: convOverride,
    );
  }

  /// BuildContext-free variant — accepts an [S] localization directly.
  /// Used by unit tests (no widget pump required) and internally by [build].
  static Future<String?> buildWithLocalizations({
    required S l,
    CapMemory? memoryOverride,
    ConversationMemory? convOverride,
  }) async {
    final CapMemory caps = memoryOverride ?? await CapMemoryStore.load();
    final ConversationMemory conv =
        convOverride ?? await ConversationMemoryService.buildMemory();

    final String? topic = _resolveTopic(caps, conv);
    if (topic == null) return null;

    // The action suggestion stays generic and localized — keeps the
    // wire-layer simple (1 ARB key, 6 locales) and avoids inventing
    // a `suggestNextAction(profile)` method that doesn't exist.
    final String action = l.coachOpenerCrossSessionAction;

    return l.coachOpenerCrossSessionTemplate(topic, action);
  }

  /// Pick the best topic string available, in order of richness :
  ///   1. last completed cap headline (richest, user actually acted on it),
  ///   2. last cap served (raw cap id → mapped label),
  ///   3. first frequent topic from conversation memory (raw tag → label),
  ///   4. first recent conversation title (already user-readable).
  /// Returns null when nothing usable exists.
  static String? _resolveTopic(CapMemory caps, ConversationMemory conv) {
    final String? headline = caps.lastCompletedCapHeadline?.trim();
    if (headline != null && headline.isNotEmpty) {
      return _truncate(headline, 80);
    }

    final String? capId = caps.lastCapServed?.trim();
    if (capId != null && capId.isNotEmpty) {
      return _topicLabel(capId);
    }

    final List<String> topics = conv.frequentTopics;
    if (topics.isNotEmpty) {
      final String first = topics.first.trim();
      if (first.isNotEmpty) return _topicLabel(first);
    }

    final List<String> titles = conv.recentTitles;
    if (titles.isNotEmpty) {
      final String first = titles.first.trim();
      if (first.isNotEmpty) return _truncate(first, 80);
    }

    return null;
  }

  /// Map a raw topic tag to its localized label, falling back to the raw
  /// tag (cleaned + truncated) when unknown.
  static String _topicLabel(String tag) {
    final String key = tag.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (_topicLabels.containsKey(key)) return _topicLabels[key]!;
    // Try a partial match (e.g. "lpp_buyback" → "lpp").
    for (final MapEntry<String, String> entry in _topicLabels.entries) {
      if (key.startsWith(entry.key)) return entry.value;
    }
    return _truncate(tag, 80);
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';
}
