import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// User's coaching intensity preference — controls how proactive MINT is.
///
/// Adjusts:
///   - Proactive trigger cooldown (intensity 1→7 days, 3→1 day, 5→every session)
///   - Memory recall depth in coach context (fewer/more past references)
///   - Nudge frequency
///   - Voice intensity via [cashLevel] (1-5, see VOICE_SYSTEM.md §11)
///
/// Two sources of signal:
///   - Explicit: user sets [intensity] via settings slider
///   - Implicit: [triggerEngagement] scores updated from greeting interactions
///
/// Persisted in SharedPreferences as JSON.
class CoachingPreference {
  /// Coaching intensity level (1-5).
  ///
  /// 1 = discret (triggers rare, recall minimal)
  /// 2 = calme
  /// 3 = équilibré (default — 1 trigger/day, standard recall)
  /// 4 = attentif
  /// 5 = proactif (triggers every session, rich recall)
  final int intensity;

  /// Voice intensity level (1-5). Default: 2 (Clair).
  ///
  /// 1 = Tranquille: chiffres seuls, pas d'opinion
  /// 2 = Clair: chiffres + une phrase de contexte (default)
  /// 3 = Direct: comparaisons concrètes, questions franches
  /// 4 = Cash: dit ce que l'ami cultivé penserait
  /// 5 = Brut: aucun filtre de politesse, pique et fait sourire (settings only)
  final int cashLevel;

  /// Per-trigger-type engagement score (0.0 to 1.0).
  ///
  /// Updated implicitly when user engages with or ignores a proactive greeting.
  /// - Engagement (user responds, clicks) → score increases
  /// - Dismissal (user ignores, sends unrelated message) → score decreases
  ///
  /// Triggers with score < 0.3 are suppressed even in high-intensity mode.
  final Map<String, double> triggerEngagement;

  /// Total proactive greetings shown (for averaging engagement).
  final int totalGreetingsShown;

  /// Total proactive greetings engaged with (user responded within 60s).
  final int totalGreetingsEngaged;

  const CoachingPreference({
    this.intensity = 3,
    this.cashLevel = 2,
    this.triggerEngagement = const {},
    this.totalGreetingsShown = 0,
    this.totalGreetingsEngaged = 0,
  });

  /// Default preference — balanced coaching.
  static const CoachingPreference balanced = CoachingPreference();

  /// Creates a copy with updated fields.
  CoachingPreference copyWith({
    int? intensity,
    int? cashLevel,
    Map<String, double>? triggerEngagement,
    int? totalGreetingsShown,
    int? totalGreetingsEngaged,
  }) {
    return CoachingPreference(
      intensity: intensity ?? this.intensity,
      cashLevel: cashLevel ?? this.cashLevel,
      triggerEngagement: triggerEngagement ?? this.triggerEngagement,
      totalGreetingsShown: totalGreetingsShown ?? this.totalGreetingsShown,
      totalGreetingsEngaged: totalGreetingsEngaged ?? this.totalGreetingsEngaged,
    );
  }

  // ── Derived values ─────────────────────────────────────────

  /// Cooldown in days based on intensity.
  ///
  /// 1 → 7 days (weekly at most)
  /// 2 → 3 days
  /// 3 → 1 day (default, current behavior)
  /// 4 → 0 days (can fire every session, max 1/session)
  /// 5 → 0 days + no per-type filtering
  int get cooldownDays {
    switch (intensity) {
      case 1:
        return 7;
      case 2:
        return 3;
      case 3:
        return 1;
      case 4:
      case 5:
        return 0;
      default:
        return 1;
    }
  }

  /// Maximum number of memory recall references in coach context.
  ///
  /// 1 → 1 recent insight
  /// 3 → 3 (default)
  /// 5 → 5 recent insights
  int get maxRecallDepth {
    switch (intensity) {
      case 1:
        return 1;
      case 2:
        return 2;
      case 3:
        return 3;
      case 4:
        return 4;
      case 5:
        return 5;
      default:
        return 3;
    }
  }

  /// Whether a specific trigger type should be suppressed
  /// based on low engagement history.
  bool isTriggerSuppressed(String triggerType) {
    if (intensity >= 5) return false; // proactive mode = no suppression
    final score = triggerEngagement[triggerType];
    if (score == null) return false; // no data = allow
    return score < 0.3; // suppress below 30% engagement
  }

  /// Overall engagement rate (0.0 to 1.0).
  double get engagementRate {
    if (totalGreetingsShown == 0) return 0.5; // neutral default
    return (totalGreetingsEngaged / totalGreetingsShown).clamp(0.0, 1.0);
  }

  // ── Implicit feedback ─────────────────────────────────────

  /// Record that a proactive greeting of [triggerType] was engaged with.
  CoachingPreference recordEngagement(String triggerType) {
    final updated = Map<String, double>.from(triggerEngagement);
    final current = updated[triggerType] ?? 0.5;
    // Exponential moving average: 80% current + 20% new signal (1.0 = engaged)
    updated[triggerType] = (current * 0.8 + 0.2).clamp(0.0, 1.0);
    return CoachingPreference(
      intensity: intensity,
      cashLevel: cashLevel,
      triggerEngagement: updated,
      totalGreetingsShown: totalGreetingsShown + 1,
      totalGreetingsEngaged: totalGreetingsEngaged + 1,
    );
  }

  /// Record that a proactive greeting of [triggerType] was ignored.
  CoachingPreference recordDismissal(String triggerType) {
    final updated = Map<String, double>.from(triggerEngagement);
    final current = updated[triggerType] ?? 0.5;
    // Exponential moving average: 80% current + 20% new signal (0.0 = ignored)
    updated[triggerType] = (current * 0.8).clamp(0.0, 1.0);
    return CoachingPreference(
      intensity: intensity,
      cashLevel: cashLevel,
      triggerEngagement: updated,
      totalGreetingsShown: totalGreetingsShown + 1,
      totalGreetingsEngaged: totalGreetingsEngaged,
    );
  }

  /// Create a copy with a new explicit intensity setting.
  CoachingPreference withIntensity(int newIntensity) => CoachingPreference(
        intensity: newIntensity.clamp(1, 5),
        cashLevel: cashLevel,
        triggerEngagement: triggerEngagement,
        totalGreetingsShown: totalGreetingsShown,
        totalGreetingsEngaged: totalGreetingsEngaged,
      );

  // ── Persistence ────────────────────────────────────────────

  static const _key = 'coaching_preference';

  Map<String, dynamic> toJson() => {
        'intensity': intensity,
        'cashLevel': cashLevel,
        'triggerEngagement': triggerEngagement,
        'totalGreetingsShown': totalGreetingsShown,
        'totalGreetingsEngaged': totalGreetingsEngaged,
      };

  factory CoachingPreference.fromJson(Map<String, dynamic> json) {
    final rawCash = json['cashLevel'] ?? json['cash_level'] ?? 2;
    final cashLvl = (rawCash is int) ? rawCash : int.tryParse('$rawCash') ?? 2;
    return CoachingPreference(
      intensity: (json['intensity'] as int?) ?? 3,
      cashLevel: cashLvl.clamp(1, 5),
      triggerEngagement: json['triggerEngagement'] != null
          ? Map<String, double>.from(
              (json['triggerEngagement'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : const {},
      totalGreetingsShown: (json['totalGreetingsShown'] as int?) ?? 0,
      totalGreetingsEngaged: (json['totalGreetingsEngaged'] as int?) ?? 0,
    );
  }

  /// Load from SharedPreferences. Returns [balanced] if not persisted.
  static CoachingPreference load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return balanced;
    try {
      return CoachingPreference.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return balanced;
    }
  }

  /// Save to SharedPreferences.
  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  @override
  String toString() => 'CoachingPreference(intensity: $intensity, '
      'cashLevel: $cashLevel, '
      'engagement: ${engagementRate.toStringAsFixed(2)}, '
      'shown: $totalGreetingsShown, engaged: $totalGreetingsEngaged)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachingPreference &&
          runtimeType == other.runtimeType &&
          intensity == other.intensity &&
          cashLevel == other.cashLevel &&
          totalGreetingsShown == other.totalGreetingsShown &&
          totalGreetingsEngaged == other.totalGreetingsEngaged;

  @override
  int get hashCode => Object.hash(intensity, cashLevel, totalGreetingsShown, totalGreetingsEngaged);
}
