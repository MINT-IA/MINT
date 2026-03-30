/// Conversation persistence service — Sprint S51.
///
/// Lightweight store using SharedPreferences (consistent with MINT pattern).
/// Stores conversation messages as JSON and maintains an index of metadata.
///
/// ARCHITECTURAL NOTE (V12-5): SharedPreferences keys are global, not per-account.
/// Account isolation relies on purge at logout/deleteAccount (auth_provider.dart).
/// TODO: Prefix all keys with user ID for native multi-account isolation.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';

// ────────────────────────────────────────────────────────────
//  ConversationMeta — lightweight metadata for list display
// ────────────────────────────────────────────────────────────

class ConversationMeta {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final int messageCount;
  final String? summary;
  final List<String> tags;
  final String? lastMessagePreview;

  const ConversationMeta({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messageCount,
    this.summary,
    this.tags = const [],
    this.lastMessagePreview,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'lastMessageAt': lastMessageAt.toIso8601String(),
        'messageCount': messageCount,
        if (summary != null) 'summary': summary,
        'tags': tags,
        if (lastMessagePreview != null)
          'lastMessagePreview': lastMessagePreview,
      };

  factory ConversationMeta.fromJson(Map<String, dynamic> json) {
    return ConversationMeta(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      messageCount: json['messageCount'] as int? ?? 0,
      summary: json['summary'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => t as String)
              .toList() ??
          const [],
      lastMessagePreview: json['lastMessagePreview'] as String?,
    );
  }

  ConversationMeta copyWith({
    String? title,
    DateTime? lastMessageAt,
    int? messageCount,
    String? summary,
    List<String>? tags,
    String? lastMessagePreview,
  }) {
    return ConversationMeta(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      messageCount: messageCount ?? this.messageCount,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    );
  }
}

// ────────────────────────────────────────────────────────────
//  ConversationStore — SharedPreferences-based persistence
// ────────────────────────────────────────────────────────────

class ConversationStore {
  /// Prefix for individual conversation message lists.
  static const _messagesPrefix = '_chat_conversations_';

  /// Key for the conversation index (list of metadata).
  static const _indexKey = '_chat_conversation_index';

  /// Maximum conversations retained in SharedPreferences.
  /// Oldest conversations are pruned when this limit is exceeded.
  static const _maxConversations = 50;

  /// Maximum title length (characters).
  static const _maxTitleLength = 50;

  // ── Public API ──────────────────────────────────────────

  /// Save a conversation (messages + metadata).
  ///
  /// Creates or updates the conversation in the index and persists
  /// all messages as JSON.
  Future<void> saveConversation(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    if (messages.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    // Serialize messages
    final messagesJson = messages.map(_messageToJson).toList();
    await prefs.setString(
      '$_messagesPrefix$conversationId',
      jsonEncode(messagesJson),
    );

    // Update index
    final index = await _loadIndex(prefs);
    final existingIdx = index.indexWhere((m) => m.id == conversationId);

    final lastMessage = messages.last;
    final lastPreview = lastMessage.content.length > 80
        ? '${lastMessage.content.substring(0, 80)}...'
        : lastMessage.content;

    final meta = ConversationMeta(
      id: conversationId,
      title: existingIdx >= 0
          ? index[existingIdx].title
          : _generateTitle(messages),
      createdAt: existingIdx >= 0
          ? index[existingIdx].createdAt
          : messages.first.timestamp,
      lastMessageAt: lastMessage.timestamp,
      messageCount: messages.length,
      summary: _generateSummary(messages),
      tags: _inferTags(messages),
      lastMessagePreview: lastPreview,
    );

    if (existingIdx >= 0) {
      index[existingIdx] = meta;
    } else {
      index.add(meta);
    }

    await _saveIndex(prefs, index);
  }

  /// Load messages for a conversation.
  ///
  /// Returns an empty list if the conversation does not exist.
  Future<List<ChatMessage>> loadConversation(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_messagesPrefix$conversationId');
    if (raw == null) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _messageFromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// List all conversation metadata, sorted by lastMessageAt descending.
  Future<List<ConversationMeta>> listConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final index = await _loadIndex(prefs);
    index.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return index;
  }

  /// Delete a conversation (messages + metadata).
  Future<void> deleteConversation(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_messagesPrefix$conversationId');

    final index = await _loadIndex(prefs);
    index.removeWhere((m) => m.id == conversationId);
    await _saveIndex(prefs, index);
  }

  /// Rename a conversation.
  Future<void> renameConversation(String id, String newTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final index = await _loadIndex(prefs);
    final idx = index.indexWhere((m) => m.id == id);
    if (idx < 0) return;

    index[idx] = index[idx].copyWith(title: newTitle);
    await _saveIndex(prefs, index);
  }

  // ── Private helpers ─────────────────────────────────────

  // ── PII scrubbing (V3-5 audit) ───────────────────────────
  //
  // Regex-based redaction of amounts, emails, phone numbers,
  // and common "mon salaire est de X" patterns from text that
  // will be persisted as titles/summaries or injected into AI context.

  /// Patterns for PII-like data to redact from persisted text.
  static final _piiPatterns = [
    // CHF amounts: "CHF 120'000", "120'000 CHF", "120000", "12'345.67"
    RegExp(r"CHF\s*[\d'\.]+", caseSensitive: false),
    RegExp(r"[\d'\.]{4,}\s*CHF", caseSensitive: false),
    // Standalone large numbers (4+ digits, possibly formatted)
    RegExp(r"\b\d{1,3}(?:['\s]\d{3})+(?:\.\d{1,2})?\b"),
    RegExp(r"\b\d{4,}(?:\.\d{1,2})?\b"),
    // "mon salaire est de X" / "je gagne X" patterns
    RegExp(r'(salaire|gagne|touche|revenu)[^.]{0,20}[\d\s\x27\.]{4,}', caseSensitive: false),
    // Email addresses
    RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.]+\b'),
    // Swiss phone numbers: +41..., 07x...
    RegExp(r'(?:\+41|0)\s*\d[\d\s]{7,}'),
    // Swiss NPA (4-digit postal codes before city names)
    RegExp(r'\b[1-9]\d{3}\s+[A-Z]', caseSensitive: false),
    // Employer patterns: "je travaille chez X", "mon employeur X"
    RegExp(r'(travaille\s+chez|employeur\s+est|boîte|entreprise)\s+\S+', caseSensitive: false),
    // IBAN (CH + 19 digits, with optional spaces)
    RegExp(r'CH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{1,2}', caseSensitive: false),
    // Written-out amounts: "septante mille", "cent vingt mille"
    RegExp(r'(septante|huitante|nonante|cinquante|soixante|vingt|trente|quarante)\s+(mille|cents?)', caseSensitive: false),
  ];

  /// Scrub PII-like patterns from text for safe persistence.
  static String scrubPii(String text) {
    var result = text;
    for (final pattern in _piiPatterns) {
      result = result.replaceAll(pattern, '[***]');
    }
    // Collapse multiple consecutive redactions
    result = result.replaceAll(RegExp(r'(\[\*\*\*\]\s*){2,}'), '[***] ');
    return result.trim();
  }

  /// Auto-generate title from first user message (first N chars).
  String _generateTitle(List<ChatMessage> messages) {
    final firstUserMsg = messages
        .where((m) => m.role == 'user')
        .map((m) => m.content.trim())
        .firstOrNull;

    if (firstUserMsg == null || firstUserMsg.isEmpty) {
      return 'Conversation';
    }

    final scrubbed = scrubPii(firstUserMsg);
    if (scrubbed.length <= _maxTitleLength) return scrubbed;
    return '${scrubbed.substring(0, _maxTitleLength)}...';
  }

  /// Auto-generate summary from first exchange (user + assistant).
  String? _generateSummary(List<ChatMessage> messages) {
    final userMsgs = messages.where((m) => m.role == 'user').toList();
    if (userMsgs.isEmpty) return null;

    final first = scrubPii(userMsgs.first.content.trim());
    if (first.length <= 120) return first;
    return '${first.substring(0, 120)}...';
  }

  /// Auto-tag by keywords found in message content.
  List<String> _inferTags(List<ChatMessage> messages) {
    final allText =
        messages.map((m) => m.content.toLowerCase()).join(' ');
    final tags = <String>{};

    const tagKeywords = {
      'retraite': ['retraite', 'avs', 'rente', 'pension', 'retirement'],
      'lpp': ['lpp', '2e pilier', 'caisse de pension', 'rachat'],
      '3a': ['3a', 'pilier 3a', 'troisième pilier', '3ème pilier'],
      'impôts': ['impôt', 'fiscal', 'déduction', 'tax', 'lifd'],
      'budget': ['budget', 'dépenses', 'épargne', 'économiser'],
      'immobilier': ['hypothèque', 'immobilier', 'maison', 'appartement', 'epl'],
      'famille': ['mariage', 'divorce', 'enfant', 'concubinage', 'naissance'],
      'emploi': ['emploi', 'salaire', 'chômage', 'indépendant', 'travail'],
      'succession': ['succession', 'héritage', 'donation', 'décès'],
      'assurance': ['lamal', 'assurance', 'maladie', 'invalidité', 'ai'],
    };

    for (final entry in tagKeywords.entries) {
      if (entry.value.any((kw) => allText.contains(kw))) {
        tags.add(entry.key);
      }
    }

    return tags.toList()..sort();
  }

  /// Load the conversation index from SharedPreferences.
  Future<List<ConversationMeta>> _loadIndex(SharedPreferences prefs) async {
    final raw = prefs.getString(_indexKey);
    if (raw == null) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ConversationMeta.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persist the conversation index, pruning oldest if over limit.
  Future<void> _saveIndex(
    SharedPreferences prefs,
    List<ConversationMeta> index,
  ) async {
    // Prune oldest conversations if over limit
    if (index.length > _maxConversations) {
      final toRemove = index.sublist(_maxConversations);
      for (final meta in toRemove) {
        await prefs.remove('$_messagesPrefix${meta.id}');
      }
      index = index.sublist(0, _maxConversations);
    }
    final json = index.map((m) => m.toJson()).toList();
    await prefs.setString(_indexKey, jsonEncode(json));
  }

  // ── ChatMessage serialization ───────────────────────────
  //
  // ChatMessage doesn't have toJson/fromJson, so we handle it here.
  // We persist role, content, timestamp, tier, suggestedActions,
  // and disclaimers. Sources and responseCards are not persisted
  // (they are session-specific and would bloat storage).

  Map<String, dynamic> _messageToJson(ChatMessage msg) => {
        'schemaVersion': ChatMessage.schemaVersion,
        'role': msg.role,
        'content': msg.content,
        'timestamp': msg.timestamp.toIso8601String(),
        'tier': msg.tier.name,
        if (msg.suggestedActions != null)
          'suggestedActions': msg.suggestedActions,
        if (msg.disclaimers.isNotEmpty) 'disclaimers': msg.disclaimers,
      };

  ChatMessage _messageFromJson(Map<String, dynamic> json) {
    // Schema migration: version 0 (pre-schema) and 1 share the same format.
    // Future migrations: final version = json['schemaVersion'] as int? ?? 0;
    final tierName = json['tier'] as String? ?? 'none';
    final tier = ChatTier.values.firstWhere(
      (t) => t.name == tierName,
      orElse: () => ChatTier.none,
    );

    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      tier: tier,
      suggestedActions: (json['suggestedActions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      disclaimers: (json['disclaimers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}
