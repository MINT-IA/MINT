import 'dart:convert';

import 'package:flutter/foundation.dart';

// ────────────────────────────────────────────────────────────
//  CoachInsight — S58 / AI Memory
// ────────────────────────────────────────────────────────────
//
// Represents a key insight extracted from a coach conversation
// and persisted for cross-session context injection.
//
// Insights are stored in SharedPreferences as JSON, keyed by id.
// They are injected into the coach AI system prompt on every
// new conversation to give Claude continuity across sessions.
//
// Privacy rules (CLAUDE.md §7 + §6):
//   - summary must NEVER contain exact salary, IBAN, name, SSN
//   - Use ranges and categories only (e.g. "revenu ~120k CHF")
//   - metadata may contain structured data (e.g. amounts) but
//     NEVER passed to LLM verbatim — summarised via buildContext()
// ────────────────────────────────────────────────────────────

/// Type of insight captured from a coach conversation.
enum InsightType {
  /// A declared user goal ("je veux maximiser mon 3a").
  goal,

  /// A decision the user made ("j'ai décidé de retirer en capital").
  decision,

  /// A concern the user expressed ("je m'inquiète de l'inflation").
  concern,

  /// A fact about the user's situation ("a un avoir LPP de ~70k").
  fact,
}

/// A key insight extracted from a coach conversation.
///
/// Insights are persisted across sessions so Claude can reference
/// past context without replaying full conversation history.
///
/// Use JSON serialization via [toJson] / [fromJson] for
/// SharedPreferences storage.
class CoachInsight {
  /// Unique identifier (UUID v4 or timestamp-based).
  final String id;

  /// When the insight was captured.
  final DateTime createdAt;

  /// Topic / intent tag (e.g. "lpp", "retraite", "3a", "housing").
  /// Matches tags used in ConversationMeta for cross-referencing.
  final String topic;

  /// Human-readable summary of what was discussed / decided.
  /// Max 200 chars. Must not contain exact PII.
  final String summary;

  /// Insight classification.
  final InsightType type;

  /// Optional structured metadata (amounts, dates, etc.).
  /// Used for calculation context — NEVER injected verbatim into LLM.
  final Map<String, dynamic>? metadata;

  const CoachInsight({
    required this.id,
    required this.createdAt,
    required this.topic,
    required this.summary,
    required this.type,
    this.metadata,
  });

  CoachInsight copyWith({
    String? topic,
    String? summary,
    InsightType? type,
    Map<String, dynamic>? metadata,
  }) {
    return CoachInsight(
      id: id,
      createdAt: createdAt,
      topic: topic ?? this.topic,
      summary: summary ?? this.summary,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'topic': topic,
        'summary': summary,
        'type': type.name,
        if (metadata != null) 'metadata': metadata,
      };

  factory CoachInsight.fromJson(Map<String, dynamic> json) {
    return CoachInsight(
      id: json['id'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      topic: json['topic'] as String? ?? 'general',
      summary: json['summary'] as String,
      type: InsightType.values.firstWhere(
        (t) => t.name == (json['type'] as String? ?? 'fact'),
        orElse: () => InsightType.fact,
      ),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  /// Encode a list of insights to a JSON string (for SharedPreferences).
  static String encodeList(List<CoachInsight> insights) =>
      jsonEncode(insights.map((i) => i.toJson()).toList());

  /// Decode a list of insights from a JSON string.
  ///
  /// Returns an empty list on parse errors (graceful degradation).
  static List<CoachInsight> decodeList(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CoachInsight.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // STAB-16 (07-04): corrupt insight payload — log and return empty.
      // User's insight history appears blank instead of crashing the chat.
      debugPrint('[coach_insight] decodeList failed: $e');
      return [];
    }
  }

  @override
  String toString() =>
      'CoachInsight(id: $id, topic: $topic, type: ${type.name}, '
      'createdAt: ${createdAt.toIso8601String()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachInsight &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
