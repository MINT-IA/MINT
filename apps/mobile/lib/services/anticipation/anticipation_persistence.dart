import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/anticipation/anticipation_trigger.dart';

// ────────────────────────────────────────────────────────────
//  ANTICIPATION PERSISTENCE — Phase 04 / Moteur d'Anticipation
// ────────────────────────────────────────────────────────────
//
// Manages SharedPreferences I/O for the anticipation layer:
//   1. Weekly frequency cap (max 2 signals per ISO week)
//   2. Dismiss cooldown (per-trigger suppression)
//   3. Snooze duration (per-trigger deferral)
//
// Pattern: Follows NudgePersistence from S61.
// Design: Static methods, SharedPreferences injectable, DateTime injectable.
//
// See: ANT-05 (frequency cap), ANT-07 (dismiss/snooze).
// ────────────────────────────────────────────────────────────

/// Manages anticipation signal persistence: weekly cap, dismiss, snooze.
///
/// All methods are static and accept injectable [SharedPreferences]
/// and [DateTime] for hermetic testing.
class AnticipationPersistence {
  AnticipationPersistence._();

  // ── Keys ────────────────────────────────────────────────────

  static const _weekIdKey = '_anticipation_week_id';
  static const _weekCountKey = '_anticipation_week_count';
  static const _dismissPrefix = '_anticipation_dismissed_';
  static const _snoozePrefix = '_anticipation_snoozed_';

  // ═══════════════════════════════════════════════════════════
  // 1. Weekly frequency cap (ANT-05)
  // ═══════════════════════════════════════════════════════════

  /// Returns the number of signals shown in the current ISO week.
  ///
  /// Resets to 0 when the ISO week changes.
  static Future<int> signalsShownThisWeek(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final currentWeekId = _isoWeekId(today);
    final storedWeekId = prefs.getString(_weekIdKey);

    if (storedWeekId != currentWeekId) {
      // New week — reset counter
      return 0;
    }

    return prefs.getInt(_weekCountKey) ?? 0;
  }

  /// Record that a signal was shown this week.
  ///
  /// Increments the weekly counter, resetting if the ISO week changed.
  static Future<void> recordSignalShown(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final currentWeekId = _isoWeekId(today);
    final storedWeekId = prefs.getString(_weekIdKey);

    int count;
    if (storedWeekId != currentWeekId) {
      // New week — reset
      await prefs.setString(_weekIdKey, currentWeekId);
      count = 1;
    } else {
      count = (prefs.getInt(_weekCountKey) ?? 0) + 1;
    }

    await prefs.setInt(_weekCountKey, count);
  }

  /// Compute ISO week identifier: `{year}-W{weekNumber}`.
  static String _isoWeekId(DateTime date) {
    // ISO 8601: week starts on Monday.
    // The ISO week number is computed from the Thursday of the same week.
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    final jan1 = DateTime(thursday.year, 1, 1);
    final weekNumber =
        ((thursday.difference(jan1).inDays) / 7).ceil() + 1;
    return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════
  // 2. Dismiss logic (ANT-07 "Got it")
  // ═══════════════════════════════════════════════════════════

  /// Dismiss cooldown in days per trigger type.
  ///
  /// After dismissal, the trigger will not fire for this many days.
  static int dismissCooldownDays(AnticipationTrigger trigger) {
    switch (trigger) {
      case AnticipationTrigger.fiscal3aDeadline:
        return 365; // Rest of year
      case AnticipationTrigger.cantonalTaxDeadline:
        return 30;
      case AnticipationTrigger.lppRachatWindow:
        return 60;
      case AnticipationTrigger.salaryIncrease3aRecalc:
        return 90;
      case AnticipationTrigger.ageMilestoneLppBonification:
        return 365; // Once per milestone
    }
  }

  /// Dismiss a trigger, starting its cooldown.
  static Future<void> dismiss(
    SharedPreferences prefs,
    AnticipationTrigger trigger, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final key = '$_dismissPrefix${trigger.name}';
    await prefs.setString(key, today.toIso8601String());
  }

  /// Returns triggers that are currently dismissed (within cooldown).
  static Future<List<AnticipationTrigger>> getDismissedTriggers(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final result = <AnticipationTrigger>[];

    for (final trigger in AnticipationTrigger.values) {
      final key = '$_dismissPrefix${trigger.name}';
      final raw = prefs.getString(key);
      if (raw == null) continue;

      try {
        final dismissedAt = DateTime.parse(raw);
        final cooldown = dismissCooldownDays(trigger);
        final expiresAt = dismissedAt.add(Duration(days: cooldown));
        if (expiresAt.isAfter(today)) {
          result.add(trigger);
        }
      } catch (_) {
        // Malformed timestamp — skip
      }
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════════
  // 3. Snooze logic (ANT-07 "Remind me later")
  // ═══════════════════════════════════════════════════════════

  /// Snooze duration in days per trigger type.
  ///
  /// Shorter than dismiss — just defers the signal temporarily.
  static int snoozeDays(AnticipationTrigger trigger) {
    switch (trigger) {
      case AnticipationTrigger.fiscal3aDeadline:
        return 7;
      case AnticipationTrigger.cantonalTaxDeadline:
        return 7;
      case AnticipationTrigger.lppRachatWindow:
        return 14;
      case AnticipationTrigger.salaryIncrease3aRecalc:
        return 14;
      case AnticipationTrigger.ageMilestoneLppBonification:
        return 30;
    }
  }

  /// Snooze a trigger, deferring it for [snoozeDays].
  static Future<void> snooze(
    SharedPreferences prefs,
    AnticipationTrigger trigger, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final key = '$_snoozePrefix${trigger.name}';
    await prefs.setString(key, today.toIso8601String());
  }

  /// Returns triggers that are currently snoozed.
  static Future<List<AnticipationTrigger>> getSnoozedTriggers(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final result = <AnticipationTrigger>[];

    for (final trigger in AnticipationTrigger.values) {
      final key = '$_snoozePrefix${trigger.name}';
      final raw = prefs.getString(key);
      if (raw == null) continue;

      try {
        final snoozedAt = DateTime.parse(raw);
        final duration = snoozeDays(trigger);
        final expiresAt = snoozedAt.add(Duration(days: duration));
        if (expiresAt.isAfter(today)) {
          result.add(trigger);
        }
      } catch (_) {
        // Malformed timestamp — skip
      }
    }

    return result;
  }
}
