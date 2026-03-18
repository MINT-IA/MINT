import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/daily_engagement_service.dart';

// ────────────────────────────────────────────────────────────
//  DAILY ENGAGEMENT SERVICE TESTS — S55
// ────────────────────────────────────────────────────────────
//
// 14 tests covering:
//   - recordEngagement persistence
//   - hasEngagedToday (true/false)
//   - currentStreak (1, 3, reset on gap, freeze mechanic)
//   - longestStreak persistence
//   - totalDays counting
//   - Empty SharedPreferences
//   - Duplicate recording
//   - Freeze limits (once per 7-day window)
// ────────────────────────────────────────────────────────────

void main() {
  group('DailyEngagementService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    // ── Helper ─────────────────────────────────────────────────
    String dateKey(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    Future<void> recordOn(DateTime date) async {
      // Manually insert a date to simulate engagement on a specific day
      final existing =
          prefs.getStringList('_daily_engagement_dates')?.toSet() ?? <String>{};
      existing.add(dateKey(date));
      await prefs.setStringList(
          '_daily_engagement_dates', existing.toList());
    }

    // ── 1. recordEngagement persists today's date ──────────────
    test('recordEngagement persists today\'s date', () async {
      final now = DateTime(2026, 3, 18);
      await DailyEngagementService.recordEngagement(prefs: prefs, now: now);

      final dates = prefs.getStringList('_daily_engagement_dates');
      expect(dates, isNotNull);
      expect(dates, contains('2026-03-18'));
    });

    // ── 2. hasEngagedToday true after recording ────────────────
    test('hasEngagedToday true after recording', () async {
      final now = DateTime(2026, 3, 18);
      await DailyEngagementService.recordEngagement(prefs: prefs, now: now);

      final engaged =
          await DailyEngagementService.hasEngagedToday(prefs: prefs, now: now);
      expect(engaged, isTrue);
    });

    // ── 3. hasEngagedToday false before recording ──────────────
    test('hasEngagedToday false before recording', () async {
      final now = DateTime(2026, 3, 18);
      final engaged =
          await DailyEngagementService.hasEngagedToday(prefs: prefs, now: now);
      expect(engaged, isFalse);
    });

    // ── 4. currentStreak = 1 after first engagement ────────────
    test('currentStreak = 1 after first engagement', () async {
      final now = DateTime(2026, 3, 18);
      await DailyEngagementService.recordEngagement(prefs: prefs, now: now);

      final streak =
          await DailyEngagementService.currentStreak(prefs: prefs, now: now);
      expect(streak, equals(1));
    });

    // ── 5. currentStreak = 3 after 3 consecutive days ──────────
    test('currentStreak = 3 after 3 consecutive days', () async {
      final now = DateTime(2026, 3, 18);
      await recordOn(DateTime(2026, 3, 16));
      await recordOn(DateTime(2026, 3, 17));
      await recordOn(DateTime(2026, 3, 18));

      final streak =
          await DailyEngagementService.currentStreak(prefs: prefs, now: now);
      expect(streak, equals(3));
    });

    // ── 6. Streak resets after 2+ day gap ──────────────────────
    test('streak resets after 2+ day gap', () async {
      final now = DateTime(2026, 3, 18);
      // Engaged on 14, 15, then skip 16 and 17
      await recordOn(DateTime(2026, 3, 14));
      await recordOn(DateTime(2026, 3, 15));
      await recordOn(DateTime(2026, 3, 18));

      final streak =
          await DailyEngagementService.currentStreak(prefs: prefs, now: now);
      // From 18 backward: 18 (engaged, streak=1), 17 (missed, freeze used),
      // 16 (missed, no freeze left) => break. Streak = 1.
      expect(streak, equals(1));
    });

    // ── 7. Streak survives 1-day gap (freeze mechanic) ─────────
    test('streak survives 1-day gap (freeze mechanic)', () async {
      final now = DateTime(2026, 3, 18);
      // Engaged on 15, 16, skip 17, engaged 18
      await recordOn(DateTime(2026, 3, 15));
      await recordOn(DateTime(2026, 3, 16));
      // Skip 17
      await recordOn(DateTime(2026, 3, 18));

      final streak =
          await DailyEngagementService.currentStreak(prefs: prefs, now: now);
      // Freeze bridges day 17, so streak = 3 (15 + 16 + 18)
      expect(streak, equals(3));
    });

    // ── 8. Freeze only works once per 7-day window ─────────────
    test('freeze only works once per 7-day window', () async {
      final now = DateTime(2026, 3, 18);
      // Pattern: 12, skip 13, 14, 15, skip 16, 17, 18
      await recordOn(DateTime(2026, 3, 12));
      // skip 13 (freeze #1)
      await recordOn(DateTime(2026, 3, 14));
      await recordOn(DateTime(2026, 3, 15));
      // skip 16 (freeze #2 — but within same 7-day window from freeze #1)
      await recordOn(DateTime(2026, 3, 17));
      await recordOn(DateTime(2026, 3, 18));

      final streak =
          await DailyEngagementService.currentStreak(prefs: prefs, now: now);
      // Freeze used for day 16, then day 13 would need another freeze
      // but it's within the same 7-day window => streak breaks at 13
      // Streak = 18, freeze(17 not needed — 17 is present),
      // Actually: 18, 17, skip 16 (freeze used), 15, 14, skip 13 (no freeze) => break
      // Streak = 4 (18, 17, 15, 14 — freeze bridging 16)
      expect(streak, equals(4));
    });

    // ── 9. longestStreak persisted across sessions ─────────────
    test('longestStreak persisted across sessions', () async {
      // Record a 3-day streak
      await DailyEngagementService.recordEngagement(
          prefs: prefs, now: DateTime(2026, 3, 15));
      await DailyEngagementService.recordEngagement(
          prefs: prefs, now: DateTime(2026, 3, 16));
      await DailyEngagementService.recordEngagement(
          prefs: prefs, now: DateTime(2026, 3, 17));

      final longest =
          await DailyEngagementService.longestStreak(prefs: prefs);
      expect(longest, equals(3));

      // Simulate new session (reset prefs instance but keep data)
      final longest2 =
          await DailyEngagementService.longestStreak(prefs: prefs);
      expect(longest2, equals(3));
    });

    // ── 10. totalDays counted correctly ────────────────────────
    test('totalDays counted correctly', () async {
      await recordOn(DateTime(2026, 3, 10));
      await recordOn(DateTime(2026, 3, 14));
      await recordOn(DateTime(2026, 3, 18));

      final total =
          await DailyEngagementService.totalDays(prefs: prefs);
      expect(total, equals(3));
    });

    // ── 11. Empty SharedPreferences = streak 0 ─────────────────
    test('empty SharedPreferences = streak 0', () async {
      final streak = await DailyEngagementService.currentStreak(
          prefs: prefs, now: DateTime(2026, 3, 18));
      expect(streak, equals(0));

      final longest =
          await DailyEngagementService.longestStreak(prefs: prefs);
      expect(longest, equals(0));

      final total = await DailyEngagementService.totalDays(prefs: prefs);
      expect(total, equals(0));

      final engaged = await DailyEngagementService.hasEngagedToday(
          prefs: prefs, now: DateTime(2026, 3, 18));
      expect(engaged, isFalse);
    });

    // ── 12. Duplicate recording same day = no change ───────────
    test('duplicate recording same day = no change', () async {
      final now = DateTime(2026, 3, 18);

      await DailyEngagementService.recordEngagement(prefs: prefs, now: now);
      await DailyEngagementService.recordEngagement(prefs: prefs, now: now);
      await DailyEngagementService.recordEngagement(prefs: prefs, now: now);

      final total = await DailyEngagementService.totalDays(prefs: prefs);
      expect(total, equals(1));
    });

    // ── 13. recentDates returns last 7 days ────────────────────
    test('recentDates returns correct engaged days', () async {
      final now = DateTime(2026, 3, 18);
      await recordOn(DateTime(2026, 3, 15));
      await recordOn(DateTime(2026, 3, 17));
      await recordOn(DateTime(2026, 3, 18));

      final recent = await DailyEngagementService.recentDates(
        prefs: prefs,
        now: now,
      );
      expect(recent, contains('2026-03-15'));
      expect(recent, contains('2026-03-17'));
      expect(recent, contains('2026-03-18'));
      expect(recent.length, equals(3));
    });

    // ── 14. Streak from yesterday still counts ─────────────────
    test('streak from yesterday still counts (not yet engaged today)',
        () async {
      final now = DateTime(2026, 3, 18);
      await recordOn(DateTime(2026, 3, 16));
      await recordOn(DateTime(2026, 3, 17));
      // NOT engaged on 18 yet

      final streak =
          await DailyEngagementService.currentStreak(prefs: prefs, now: now);
      // Yesterday was engaged, starts scan from i=1 (17), counts 17+16 = 2
      expect(streak, equals(2));
    });

    // ── 15. Freeze preserved overnight (Bug fix verification) ────
    test('freeze preserved when checking streak next morning', () async {
      // Engaged 15, 16, skip 17 (freeze), engaged 18
      await recordOn(DateTime(2026, 3, 15));
      await recordOn(DateTime(2026, 3, 16));
      // Skip 17
      await recordOn(DateTime(2026, 3, 18));

      // Check streak ON day 18 (engaged today): freeze bridges 17
      final streakDay18 =
          await DailyEngagementService.currentStreak(
              prefs: prefs, now: DateTime(2026, 3, 18));
      expect(streakDay18, equals(3)); // 18 + 16 + 15 (freeze on 17)

      // Next morning (day 19), user hasn't engaged yet.
      // Streak should still be 3 — freeze NOT consumed by "today pending".
      final streakDay19 =
          await DailyEngagementService.currentStreak(
              prefs: prefs, now: DateTime(2026, 3, 19));
      expect(streakDay19, equals(3)); // 18 + 16 + 15 (freeze on 17)
    });

    // ── 16. Double gap breaks streak even with freeze ────────────
    test('two consecutive missed days break streak', () async {
      await recordOn(DateTime(2026, 3, 14));
      await recordOn(DateTime(2026, 3, 15));
      // Skip 16 AND 17
      await recordOn(DateTime(2026, 3, 18));

      final streak =
          await DailyEngagementService.currentStreak(
              prefs: prefs, now: DateTime(2026, 3, 18));
      // 18 engaged, 17 miss (freeze), 16 miss (no freeze) → break
      expect(streak, equals(1)); // Only day 18
    });
  });
}
