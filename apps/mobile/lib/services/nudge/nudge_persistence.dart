import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/nudge/nudge_trigger.dart';

// ────────────────────────────────────────────────────────────
//  NUDGE PERSISTENCE — S61 / JITAI Proactive Nudges
// ────────────────────────────────────────────────────────────
//
// Manages all SharedPreferences I/O for the nudge layer.
// NudgeEngine is pure; NudgePersistence owns all side effects.
//
// Storage keys:
//   _nudge_dismissed_{trigger}  — ISO8601 dismiss timestamp
//   _nudge_last_activity        — ISO8601 of last user activity
//
// Cooldown logic:
//   A dismissed nudge is suppressed until `dismissedAt + cooldownDays`.
//   After expiry the id is removed from dismissed list automatically.
// ────────────────────────────────────────────────────────────

/// Manages nudge dismiss/cooldown and activity timestamps.
///
/// All methods are static and accept an injectable [SharedPreferences]
/// instance for hermetic testing.
class NudgePersistence {
  NudgePersistence._();

  // ── Keys ────────────────────────────────────────────────

  static const _dismissPrefix = '_nudge_dismissed_';
  static const _lastActivityKey = '_nudge_last_activity';

  // ── Cooldown days per trigger ────────────────────────────

  /// Cooldown in days per trigger type.
  ///
  /// After dismissal the nudge will not re-appear for this many days.
  static int cooldownDays(NudgeTrigger trigger) {
    switch (trigger) {
      case NudgeTrigger.salaryReceived:
        return 25;
      case NudgeTrigger.taxDeadlineApproach:
        return 7;
      case NudgeTrigger.pillar3aDeadline:
        return 7;
      case NudgeTrigger.birthdayMilestone:
        return 360;
      case NudgeTrigger.profileIncomplete:
        return 14;
      case NudgeTrigger.noActivityWeek:
        return 5;
      case NudgeTrigger.goalProgress:
        return 7;
      case NudgeTrigger.lifeEventAnniversary:
        return 360;
      case NudgeTrigger.lppBuybackWindow:
        return 30;
      case NudgeTrigger.newYearReset:
        return 14;
    }
  }

  // ── Public API ───────────────────────────────────────────

  /// Returns the list of nudge ids that are currently dismissed
  /// (i.e. within their cooldown window).
  ///
  /// Expired dismissals are excluded (but NOT cleaned up here
  /// to keep this read-only; use [clearExpired] for cleanup).
  static Future<List<String>> getDismissedIds(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final result = <String>[];

    for (final trigger in NudgeTrigger.values) {
      final key = '$_dismissPrefix${trigger.name}';
      final raw = prefs.getString(key);
      if (raw == null) continue;

      try {
        final dismissedAt = DateTime.parse(raw);
        final cooldown = cooldownDays(trigger);
        final expiresAt = dismissedAt.add(Duration(days: cooldown));
        if (expiresAt.isAfter(today)) {
          // Build the same id format as NudgeEngine._id:
          // {trigger}_{yyyyMM} — use the dismiss month
          final id =
              '${trigger.name}_${dismissedAt.year}${dismissedAt.month.toString().padLeft(2, '0')}';
          result.add(id);
        }
      } catch (_) {
        // Malformed timestamp — skip
      }
    }

    return result;
  }

  /// Dismiss a nudge type, starting its cooldown.
  ///
  /// [nudgeId]  — id from Nudge.id (used to log, not stored).
  /// [trigger]  — the trigger to suppress.
  /// [now]      — current datetime (injectable for tests).
  static Future<void> dismiss(
    String nudgeId,
    NudgeTrigger trigger,
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final key = '$_dismissPrefix${trigger.name}';
    await prefs.setString(key, today.toIso8601String());
  }

  /// Remove all expired dismiss entries from SharedPreferences.
  ///
  /// Call periodically (e.g. on app start) to keep storage clean.
  static Future<void> clearExpired(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();

    for (final trigger in NudgeTrigger.values) {
      final key = '$_dismissPrefix${trigger.name}';
      final raw = prefs.getString(key);
      if (raw == null) continue;

      try {
        final dismissedAt = DateTime.parse(raw);
        final cooldown = cooldownDays(trigger);
        final expiresAt = dismissedAt.add(Duration(days: cooldown));
        if (!expiresAt.isAfter(today)) {
          await prefs.remove(key);
        }
      } catch (_) {
        // Malformed timestamp — remove it
        await prefs.remove(key);
      }
    }
  }

  /// Returns the last recorded user activity time, or null if never set.
  static Future<DateTime?> getLastActivityTime(SharedPreferences prefs) async {
    final raw = prefs.getString(_lastActivityKey);
    if (raw == null) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Record a user activity timestamp.
  ///
  /// Call this when the user performs a meaningful action
  /// (simulation completed, document scanned, coach message sent, etc.)
  /// NOT when the app is merely opened.
  static Future<void> recordActivity(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    await prefs.setString(_lastActivityKey, today.toIso8601String());
  }
}
