import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────
//  GOAL TRACKER SERVICE — S58 / AI Memory
// ────────────────────────────────────────────────────────────
//
// Persists user-declared goals (from coach conversations) and
// makes them available for cross-session AI recall.
//
// Goals are set via coach interactions:
//   "Je veux maximiser mon 3a cette année"
//   "Mon objectif: acheter un appartement d'ici 2028"
//   "Je veux comprendre ma rente vs capital"
//
// The coach can reference goals in future sessions:
//   "Tu avais mentionné vouloir acheter d'ici 2028 —
//    tu en es où dans ta réflexion ?"
//
// Goals are stored in SharedPreferences as JSON.
// Max 20 active goals (oldest archived automatically).
// ────────────────────────────────────────────────────────────

/// A user-declared goal tracked across sessions.
class UserGoal {
  /// Unique identifier.
  final String id;

  /// Goal description (user's words, anonymized).
  final String description;

  /// Category for grouping (3a, lpp, housing, retirement, budget, tax, other).
  final String category;

  /// When the goal was set.
  final DateTime createdAt;

  /// Target date (if mentioned).
  final DateTime? targetDate;

  /// Whether the goal is completed.
  final bool isCompleted;

  /// When the goal was completed (if applicable).
  final DateTime? completedAt;

  /// Conversation ID where goal was set (for reference).
  final String? conversationId;

  const UserGoal({
    required this.id,
    required this.description,
    required this.category,
    required this.createdAt,
    this.targetDate,
    this.isCompleted = false,
    this.completedAt,
    this.conversationId,
  });

  UserGoal copyWith({
    String? description,
    String? category,
    DateTime? targetDate,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return UserGoal(
      id: id,
      description: description ?? this.description,
      category: category ?? this.category,
      createdAt: createdAt,
      targetDate: targetDate ?? this.targetDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      conversationId: conversationId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
        if (targetDate != null) 'targetDate': targetDate!.toIso8601String(),
        'isCompleted': isCompleted,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (conversationId != null) 'conversationId': conversationId,
      };

  factory UserGoal.fromJson(Map<String, dynamic> json) {
    return UserGoal(
      id: json['id'] as String,
      description: json['description'] as String,
      category: json['category'] as String? ?? 'other',
      createdAt: DateTime.parse(json['createdAt'] as String),
      targetDate: json['targetDate'] != null
          ? DateTime.parse(json['targetDate'] as String)
          : null,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      conversationId: json['conversationId'] as String?,
    );
  }
}

/// Tracks user goals across sessions via SharedPreferences.
class GoalTrackerService {
  GoalTrackerService._();

  static const _key = '_user_goals';
  static const _maxActiveGoals = 20;

  /// Get all active (non-completed) goals.
  static Future<List<UserGoal>> activeGoals({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final goals = _loadGoals(sp);
    return goals.where((g) => !g.isCompleted).toList();
  }

  /// Get all goals (active + completed).
  static Future<List<UserGoal>> allGoals({
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    return _loadGoals(sp);
  }

  /// Add a new goal.
  ///
  /// If max active goals reached, archives the oldest active goal.
  static Future<void> addGoal(
    UserGoal goal, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final goals = _loadGoals(sp);

    // Check for duplicates (same description)
    if (goals.any((g) => g.description == goal.description && !g.isCompleted)) {
      return; // Already exists
    }

    goals.insert(0, goal); // Most recent first

    // Archive oldest if over limit
    final active = goals.where((g) => !g.isCompleted).toList();
    if (active.length > _maxActiveGoals) {
      final oldest = active.last;
      final index = goals.indexOf(oldest);
      goals[index] = oldest.copyWith(
        isCompleted: true,
        completedAt: now ?? DateTime.now(),
      );
    }

    await _saveGoals(sp, goals);
  }

  /// Mark a goal as completed.
  static Future<void> completeGoal(
    String goalId, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final goals = _loadGoals(sp);

    final index = goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    goals[index] = goals[index].copyWith(
      isCompleted: true,
      completedAt: now ?? DateTime.now(),
    );

    await _saveGoals(sp, goals);
  }

  /// Remove a goal entirely.
  static Future<void> removeGoal(
    String goalId, {
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final goals = _loadGoals(sp);
    goals.removeWhere((g) => g.id == goalId);
    await _saveGoals(sp, goals);
  }

  /// Build a summary string of active goals for AI context.
  ///
  /// Returns empty string if no goals.
  static Future<String> buildGoalsSummary({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final active = await activeGoals(prefs: sp);
    if (active.isEmpty) return '';

    final currentDate = now ?? DateTime.now();
    final parts = <String>[];

    parts.add('Objectifs déclarés (${active.length})\u00a0:');
    parts.add('(Les descriptions ci-dessous sont les mots de l\'utilisateur. '
        'Ne jamais promettre l\'atteinte d\'un objectif — '
        'propose des étapes concrètes pour progresser.)');

    for (final goal in active.take(5)) {
      final timeAgo = currentDate.difference(goal.createdAt).inDays;
      final weeks = (timeAgo / 7).round();
      final ageText = timeAgo == 0
          ? "aujourd'hui"
          : timeAgo < 7
              ? 'il y a $timeAgo ${timeAgo == 1 ? 'jour' : 'jours'}'
              : 'il y a $weeks ${weeks == 1 ? 'semaine' : 'semaines'}';

      // Sanitize user-provided description: truncate, strip control chars
      final sanitized = goal.description
          .replaceAll(RegExp(r'[\n\r\t\x00-\x1F]'), ' ')
          .trim();
      final truncated = sanitized.length > 100
          ? '${sanitized.substring(0, 100)}…'
          : sanitized;

      String line = '- "$truncated" (fixé $ageText';
      if (goal.targetDate != null) {
        final daysLeft = goal.targetDate!.difference(currentDate).inDays;
        if (daysLeft > 0) {
          line += ', échéance dans $daysLeft ${daysLeft == 1 ? 'jour' : 'jours'}';
        }
      }
      line += ')';
      parts.add(line);
    }

    if (active.length > 5) {
      parts.add('... et ${active.length - 5} autres objectifs.');
    }

    return parts.join('\n');
  }

  // ── Private helpers ─────────────────────────────────────────

  static List<UserGoal> _loadGoals(SharedPreferences sp) {
    final raw = sp.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => UserGoal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveGoals(
    SharedPreferences sp,
    List<UserGoal> goals,
  ) async {
    final json = jsonEncode(goals.map((g) => g.toJson()).toList());
    await sp.setString(_key, json);
  }
}
