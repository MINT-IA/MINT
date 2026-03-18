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

    // Must have engaged today or yesterday to have an active streak
    final yesterdayKey = _dateKey(today.subtract(const Duration(days: 1)));
    if (!dates.contains(todayKey) && !dates.contains(yesterdayKey)) {
      return 0;
    }

    int streak = 0;
    int freezesUsedInWindow = 0;
    int daysSinceLastFreeze = 7; // Start with freeze available

    // Start from today and count backwards
    for (int i = 0; i < 3650; i++) {
      // Max ~10 years
      final date = today.subtract(Duration(days: i));
      final key = _dateKey(date);

      if (dates.contains(key)) {
        streak++;
        daysSinceLastFreeze++;
      } else {
        // Check if we can use a freeze
        // Reset freeze counter every 7 days
        if (daysSinceLastFreeze >= 7) {
          freezesUsedInWindow = 0;
        }

        if (freezesUsedInWindow < 1) {
          // Use the freeze — gap forgiven, but doesn't add to streak count
          freezesUsedInWindow++;
          daysSinceLastFreeze = 0;
        } else {
          // No freeze available — streak broken
          break;
        }
      }
    }

    return streak;
  }
}
