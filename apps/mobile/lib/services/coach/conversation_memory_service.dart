import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';

// ────────────────────────────────────────────────────────────
//  CONVERSATION MEMORY SERVICE — S58 / AI Memory
// ────────────────────────────────────────────────────────────
//
// Summarizes past conversations into a compact memory block
// that can be injected into the coach AI system prompt.
//
// Memory is built from ConversationMeta (titles, tags, dates)
// without replaying full messages — privacy-safe, token-efficient.
//
// The memory block gives the AI continuity across sessions:
//   - "User discussed retirement planning 3 weeks ago"
//   - "Frequent topics: 3a, LPP buyback, housing"
//   - "Last conversation: rente vs capital comparison"
//
// Pure functions where possible. SharedPreferences for persistence.
// ────────────────────────────────────────────────────────────

/// A compact memory summary for AI context injection.
class ConversationMemory {
  /// Summary text for system prompt injection (max 500 chars).
  final String summary;

  /// Most frequent topics across all conversations.
  final List<String> frequentTopics;

  /// Total number of past conversations.
  final int totalConversations;

  /// Total messages across all conversations.
  final int totalMessages;

  /// Date of first conversation (null if none).
  final DateTime? firstConversationAt;

  /// Date of most recent conversation (null if none).
  final DateTime? lastConversationAt;

  /// Recent conversation titles (last 5).
  final List<String> recentTitles;

  const ConversationMemory({
    required this.summary,
    required this.frequentTopics,
    required this.totalConversations,
    required this.totalMessages,
    this.firstConversationAt,
    this.lastConversationAt,
    this.recentTitles = const [],
  });

  /// Empty memory (no conversations yet).
  static const empty = ConversationMemory(
    summary: '',
    frequentTopics: [],
    totalConversations: 0,
    totalMessages: 0,
    recentTitles: [],
  );

  bool get isEmpty => totalConversations == 0;
}

/// Builds conversation memory from stored conversation metadata.
class ConversationMemoryService {
  ConversationMemoryService._();

  /// Build a memory summary from all stored conversations.
  ///
  /// Uses ConversationMeta (titles, tags, dates) — NOT full messages.
  /// This is privacy-safe (no PII) and token-efficient.
  ///
  /// [prefs] — injectable for tests.
  static Future<ConversationMemory> buildMemory({
    SharedPreferences? prefs,
    DateTime? now,
    List<ConversationMeta>? conversationsOverride,
  }) async {
    final conversations = conversationsOverride ??
        await ConversationStore().listConversations();

    if (conversations.isEmpty) return ConversationMemory.empty;

    final currentDate = now ?? DateTime.now();

    // Extract frequent topics from all conversation tags
    final topicCounts = <String, int>{};
    int totalMessages = 0;

    for (final conv in conversations) {
      totalMessages += conv.messageCount;
      for (final tag in conv.tags) {
        topicCounts[tag] = (topicCounts[tag] ?? 0) + 1;
      }
    }

    // Sort topics by frequency, take top 5
    final sortedTopics = topicCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final frequentTopics =
        sortedTopics.take(5).map((e) => e.key).toList();

    // Recent titles (last 5 conversations), sanitized
    final recentTitles = conversations
        .take(5) // Already sorted by recency from ConversationStore
        .map((c) => _sanitizeTitle(c.title))
        .toList();

    // Build summary text (max 500 chars for token efficiency)
    final summary = _buildSummaryText(
      conversations: conversations,
      frequentTopics: frequentTopics,
      totalMessages: totalMessages,
      now: currentDate,
    );

    return ConversationMemory(
      summary: summary,
      frequentTopics: frequentTopics,
      totalConversations: conversations.length,
      totalMessages: totalMessages,
      firstConversationAt: conversations.last.createdAt,
      lastConversationAt: conversations.first.lastMessageAt,
      recentTitles: recentTitles,
    );
  }

  /// Build a human-readable summary for system prompt injection.
  static String _buildSummaryText({
    required List<ConversationMeta> conversations,
    required List<String> frequentTopics,
    required int totalMessages,
    required DateTime now,
  }) {
    final parts = <String>[];

    final convCount = conversations.length;
    parts.add('$convCount ${convCount == 1 ? 'conversation passée' : 'conversations passées'} '
        '($totalMessages messages au total).');

    if (frequentTopics.isNotEmpty) {
      parts.add('Sujets fréquents\u00a0: ${frequentTopics.join(', ')}.');
    }

    // Last conversation context
    if (conversations.isNotEmpty) {
      final last = conversations.first;
      final daysSince = now.difference(last.lastMessageAt).inDays;
      final timeAgo = daysSince == 0
          ? "aujourd'hui"
          : daysSince == 1
              ? 'hier'
              : 'il y a $daysSince jours';
      parts.add('Dernière conversation ($timeAgo)\u00a0: "${_sanitizeTitle(last.title)}".');
    }

    // Recent titles
    if (conversations.length > 1) {
      final titles = conversations
          .skip(1)
          .take(3)
          .map((c) => '"${_sanitizeTitle(c.title)}"')
          .join(', ');
      parts.add('Conversations récentes\u00a0: $titles.');
    }

    final fullText = parts.join(' ');
    // Trim to 500 chars max
    return fullText.length > 500 ? '${fullText.substring(0, 497)}...' : fullText;
  }

  /// Sanitize a conversation title to prevent prompt injection.
  ///
  /// Strips system markers, triple-dash delimiters, and truncates
  /// to 100 chars to prevent memory block manipulation.
  static String _sanitizeTitle(String title) {
    var s = title;
    for (final marker in [
      '--- MÉMOIRE MINT ---',
      '--- FIN MÉMOIRE ---',
      'RAPPEL\u00a0:',
      'HISTORIQUE DE CONVERSATION',
    ]) {
      s = s.replaceAll(RegExp(RegExp.escape(marker), caseSensitive: false), '');
    }
    s = s.replaceAll(RegExp(r'-{3,}'), '');
    s = s.replaceAll(RegExp(r'\s{3,}'), '  ').trim();
    return s.length > 100 ? '${s.substring(0, 97)}...' : s;
  }
}
