import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────
//  DAILY ENGAGEMENT SERVICE — S55 / Daily Streaks
// ────────────────────────────────────────────────────────────
//
// Tracks daily app engagement for streak counting.
// Stores engaged dates as Set<String> of ISO date strings
// (yyyy-MM-dd) in SharedPreferences.
//
// Streak logic: consecutive days backward from today,
// allowing ONE gap per 7-day window (freeze mechanic).
//
// Call recordEngagement() when user performs a meaningful action:
//   - Completes a simulation
//   - Scans a document
//   - Checks budget
//   - Reads an educational article
//   - Sends a coach message
//   (NOT just opening the app)
// ────────────────────────────────────────────────────────────

/// Service tracking daily app engagement for streak counting.
///
/// All methods are static and use [SharedPreferences] for persistence.
/// An optional [SharedPreferences] instance can be passed for testing.
class DailyEngagementService {
  DailyEngagementService._();

  /// SharedPreferences key for engaged dates set.
  static const _key = '_daily_engagement_dates';

  /// SharedPreferences key for longest streak ever.
  static const _longestKey = '_daily_engagement_longest';

  /// Maximum streak length before auto-freeze.
  ///
  /// Design rationale: Unlike Duolingo (infinite streaks), MINT caps
  /// at 30 days to prevent anxiety-driven engagement. Research shows
  /// that streaks beyond 30 days shift from motivation to obligation
  /// (Hamari et al., 2014). The cap lets users "reset" without guilt.
  ///
  /// After 30 days: streak freezes, user gets a "30-day milestone"
  /// badge, and a new cycle begins. This aligns with the MINT ethos
  /// of education over addiction.
  static const int maxStreakDays = 30;

  /// Record today as an engaged day.
  ///
  /// Call this when user performs a meaningful action:
  /// - Completes a simulation
  /// - Scans a document
  /// - Checks budget
  /// - Reads an educational article
  /// - Sends a coach message
  /// (NOT just opening the app)
  ///
  /// [prefs] — injectable for tests.
  /// [now] — override for testing (defaults to DateTime.now()).
  static Future<void> recordEngagement({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final dates = _loadDates(sp);
    final today = _dateKey(now ?? DateTime.now());

    if (dates.contains(today)) return; // Already recorded today

    dates.add(today);

    // Prune dates older than 400 days to prevent unbounded growth
    if (dates.length > 400) {
      final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 400));
      final cutoffKey = _dateKey(cutoff);
      dates.removeWhere((d) => d.compareTo(cutoffKey) < 0);
    }

    await sp.setStringList(_key, dates.toList());

    // Update longest streak if needed
    final current = _computeCurrentStreak(dates, now ?? DateTime.now());
    final longest = sp.getInt(_longestKey) ?? 0;
    if (current > longest) {
      await sp.setInt(_longestKey, current);
    }
  }

  /// Current daily streak (consecutive days of engagement,
  /// allowing 1 freeze per 7-day window).
  ///
  /// [prefs] — injectable for tests.
  /// [now] — override for testing (defaults to DateTime.now()).
  static Future<int> currentStreak({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final dates = _loadDates(sp);
    return _computeCurrentStreak(dates, now ?? DateTime.now());
  }

  /// Longest daily streak ever.
  ///
  /// [prefs] — injectable for tests.
  static Future<int> longestStreak({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    return sp.getInt(_longestKey) ?? 0;
  }

  /// Has the user engaged today?
  ///
  /// [prefs] — injectable for tests.
  /// [now] — override for testing.
  static Future<bool> hasEngagedToday({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final dates = _loadDates(sp);
    final today = _dateKey(now ?? DateTime.now());
    return dates.contains(today);
  }

  /// Total engaged days.
  ///
  /// [prefs] — injectable for tests.
  static Future<int> totalDays({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final dates = _loadDates(sp);
    return dates.length;
  }

  /// Get the set of engaged dates for the last [days] days.
  ///
  /// Useful for rendering a weekly calendar view.
  /// [prefs] — injectable for tests.
  /// [now] — override for testing.
  static Future<Set<String>> recentDates({
    int days = 7,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final allDates = _loadDates(sp);
    final today = now ?? DateTime.now();
    final result = <String>{};

    for (int i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: i));
      final key = _dateKey(date);
      if (allDates.contains(key)) {
        result.add(key);
      }
    }
    return result;
  }

  // ── Private helpers ─────────────────────────────────────────

  /// Load persisted date set from SharedPreferences.
  static Set<String> _loadDates(SharedPreferences sp) {
    return sp.getStringList(_key)?.toSet() ?? <String>{};
  }

  /// Format a DateTime to ISO date string (yyyy-MM-dd).
  static String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Compute current streak counting backward from [today].
  ///
  /// Allows ONE gap (missed day) per 7-day window.
  /// A "freeze" is consumed when a day is missed but the streak
  /// continues. Only one freeze is allowed per rolling 7-day window.
  static int _computeCurrentStreak(Set<String> dates, DateTime today) {
    if (dates.isEmpty) return 0;

    final todayKey = _dateKey(today);

    // If engaged today, scan from today (i=0).
    // If NOT engaged today, scan from yesterday (i=1) — today is still
    // in progress so it shouldn't count as a miss or consume the freeze.
    // The scan's freeze logic handles the rest: if yesterday is also a
    // miss, the freeze covers it; if two consecutive days are missed,
    // the streak breaks naturally.
    final startDay = dates.contains(todayKey) ? 0 : 1;

    int streak = 0;
    int freezesUsedInWindow = 0;
    int daysSinceLastFreeze = 7; // Start with freeze available

    for (int i = startDay; i < 3650; i++) {
      final date = today.subtract(Duration(days: i));
      final key = _dateKey(date);

      if (dates.contains(key)) {
        streak++;
        if (streak >= maxStreakDays) return maxStreakDays;
        daysSinceLastFreeze++;
      } else {
        // Reset freeze counter every 7 engaged/frozen days.
        if (daysSinceLastFreeze >= 7) {
          freezesUsedInWindow = 0;
        }

        if (freezesUsedInWindow < 1) {
          // Use the freeze — gap forgiven, streak continues.
          freezesUsedInWindow++;
          daysSinceLastFreeze = 0;
        } else {
          // No freeze available — streak broken.
          break;
        }
      }
    }

    return streak;
  }
}
