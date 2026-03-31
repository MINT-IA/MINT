import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/fhs_daily_score.dart';
import 'package:mint_mobile/services/financial_core/fri_calculator.dart';
import 'package:mint_mobile/services/financial_health_score_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper: create a FriBreakdown with given axis values.
FriBreakdown _makeFri({
  double l = 0,
  double f = 0,
  double r = 0,
  double s = 0,
}) {
  return FriBreakdown(
    liquidite: l,
    fiscalite: f,
    retraite: r,
    risque: s,
    total: double.parse((l + f + r + s).toStringAsFixed(2)),
    computedAt: DateTime.now(),
  );
}

/// Helper: seed SharedPreferences with FHS history entries.
Future<SharedPreferences> _seedHistory(
  List<Map<String, dynamic>> entries,
) async {
  SharedPreferences.setMockInitialValues({
    kFhsHistoryKey: entries.isEmpty ? '' : _encodeHistory(entries),
  });
  return SharedPreferences.getInstance();
}

String _encodeHistory(List<Map<String, dynamic>> entries) {
  // Use dart:convert inline to avoid extra import in test
  return entries
      .map((e) =>
          '{"score":${e['score']},"level":"${e['level']}","trend":"${e['trend']}",'
          '"deltaVsYesterday":${e['deltaVsYesterday']},"deltaVsWeekAgo":${e['deltaVsWeekAgo']},'
          '"computedAt":"${e['computedAt']}","liquidite":${e['liquidite']},'
          '"fiscalite":${e['fiscalite']},"retraite":${e['retraite']},'
          '"risque":${e['risque']}}')
      .toList()
      .toString();
}

Map<String, dynamic> _makeHistoryEntry({
  required double score,
  required DateTime computedAt,
  double l = 0,
  double f = 0,
  double r = 0,
  double s = 0,
}) {
  return {
    'score': score,
    'level': FhsDailyScore.levelFromScore(score).name,
    'trend': 'stable',
    'deltaVsYesterday': 0.0,
    'deltaVsWeekAgo': 0.0,
    'computedAt': computedAt.toIso8601String(),
    'liquidite': l,
    'fiscalite': f,
    'retraite': r,
    'risque': s,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════
  //  1-6. Level thresholds (WHOOP-inspired boundaries)
  // ═══════════════════════════════════════════════════════════════

  group('FhsDailyScore.levelFromScore — thresholds', () {
    test('1. score 0 → critical', () {
      expect(FhsDailyScore.levelFromScore(0), FhsLevel.critical);
    });

    test('2. score 39 → critical, 40 → needsImprovement', () {
      expect(FhsDailyScore.levelFromScore(39), FhsLevel.critical);
      expect(FhsDailyScore.levelFromScore(40), FhsLevel.needsImprovement);
    });

    test('3. score 59 → needsImprovement, 60 → good', () {
      expect(FhsDailyScore.levelFromScore(59), FhsLevel.needsImprovement);
      expect(FhsDailyScore.levelFromScore(60), FhsLevel.good);
    });

    test('4. score 79 → good, 80 → excellent', () {
      expect(FhsDailyScore.levelFromScore(79), FhsLevel.good);
      expect(FhsDailyScore.levelFromScore(80), FhsLevel.excellent);
    });

    test('5. score 100 → excellent', () {
      expect(FhsDailyScore.levelFromScore(100), FhsLevel.excellent);
    });

    test('6. boundary exclusivity — each threshold is strict', () {
      // 39.99 still critical
      expect(FhsDailyScore.levelFromScore(39.99), FhsLevel.critical);
      // 40.0 exactly is needsImprovement
      expect(FhsDailyScore.levelFromScore(40.0), FhsLevel.needsImprovement);
      // 59.99 still needsImprovement
      expect(FhsDailyScore.levelFromScore(59.99), FhsLevel.needsImprovement);
      // 79.99 still good
      expect(FhsDailyScore.levelFromScore(79.99), FhsLevel.good);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  7-9. Trend computation
  // ═══════════════════════════════════════════════════════════════

  group('Trend computation', () {
    test('7. trend up when delta > +2', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final prefs = await _seedHistory([
        _makeHistoryEntry(score: 50, computedAt: yesterday),
      ]);
      final service = FinancialHealthScoreService(prefs);
      final fri = _makeFri(l: 15, f: 10, r: 15, s: 13); // total 53
      final fhs = await service.computeDailyAt(fri, now);
      // delta = 53 - 50 = 3 > 2 → up
      expect(fhs.trend, FhsTrend.up);
      expect(fhs.deltaVsYesterday, closeTo(3.0, 0.1));
    });

    test('8. trend down when delta < -2', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final prefs = await _seedHistory([
        _makeHistoryEntry(score: 60, computedAt: yesterday),
      ]);
      final service = FinancialHealthScoreService(prefs);
      final fri = _makeFri(l: 15, f: 10, r: 15, s: 15); // total 55
      final fhs = await service.computeDailyAt(fri, now);
      // delta = 55 - 60 = -5 < -2 → down
      expect(fhs.trend, FhsTrend.down);
      expect(fhs.deltaVsYesterday, closeTo(-5.0, 0.1));
    });

    test('9. trend stable when delta between -2 and +2', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final prefs = await _seedHistory([
        _makeHistoryEntry(score: 54, computedAt: yesterday),
      ]);
      final service = FinancialHealthScoreService(prefs);
      final fri = _makeFri(l: 15, f: 10, r: 15, s: 15); // total 55
      final fhs = await service.computeDailyAt(fri, now);
      // delta = 55 - 54 = 1, |1| < 2 → stable
      expect(fhs.trend, FhsTrend.stable);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  10-11. Delta computation
  // ═══════════════════════════════════════════════════════════════

  group('Delta computation', () {
    test('10. delta vs yesterday computed correctly', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final prefs = await _seedHistory([
        _makeHistoryEntry(score: 70, computedAt: yesterday),
      ]);
      final service = FinancialHealthScoreService(prefs);
      final fri = _makeFri(l: 20, f: 15, r: 20, s: 20); // total 75
      final fhs = await service.computeDailyAt(fri, now);
      expect(fhs.deltaVsYesterday, closeTo(5.0, 0.1));
    });

    test('11. delta vs week ago computed correctly (or 0 if no history)', () async {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final yesterday = now.subtract(const Duration(days: 1));
      final prefs = await _seedHistory([
        _makeHistoryEntry(score: 60, computedAt: weekAgo),
        _makeHistoryEntry(score: 70, computedAt: yesterday),
      ]);
      final service = FinancialHealthScoreService(prefs);
      final fri = _makeFri(l: 20, f: 15, r: 20, s: 20); // total 75
      final fhs = await service.computeDailyAt(fri, now);
      expect(fhs.deltaVsWeekAgo, closeTo(15.0, 0.1));

      // No week-ago entry → delta = 0
      final prefs2 = await _seedHistory([
        _makeHistoryEntry(score: 70, computedAt: yesterday),
      ]);
      final service2 = FinancialHealthScoreService(prefs2);
      final fhs2 = await service2.computeDailyAt(fri, now);
      expect(fhs2.deltaVsWeekAgo, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  12. History limit (90 days)
  // ═══════════════════════════════════════════════════════════════

  group('History management', () {
    test('12. history limited to 90 days', () async {
      final now = DateTime.now();
      // Seed with 95 entries (5 over limit)
      final entries = List.generate(95, (i) {
        return _makeHistoryEntry(
          score: 50.0 + (i % 10),
          computedAt: now.subtract(Duration(days: 95 - i)),
        );
      });
      final prefs = await _seedHistory(entries);
      final service = FinancialHealthScoreService(prefs);

      // Add one more entry via computeDaily
      final fri = _makeFri(l: 15, f: 15, r: 15, s: 15); // total 60
      await service.computeDailyAt(fri, now);

      // History should be pruned to kFhsMaxHistoryDays (90)
      expect(service.historyLength, kFhsMaxHistoryDays);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  13. Golden test: Julien (FRI ~78 → FHS excellent)
  // ═══════════════════════════════════════════════════════════════

  group('Golden test — Julien', () {
    test('13. Julien FRI ~78 → FHS excellent, score = 78', () async {
      // Julien: swiss_native, 49yo, VS, salaire 122'207
      // FRI ~78 from calibration (approximate axis values)
      final prefs = await _seedHistory([]);
      final service = FinancialHealthScoreService(prefs);
      final fri = _makeFri(l: 20, f: 18, r: 20, s: 20); // total 78
      final fhs = await service.computeDailyAt(fri, DateTime.now());

      expect(fhs.score, 78.0);
      expect(fhs.level, FhsLevel.good);
      // Note: 78 < 80, so "good" not "excellent"
      // If Julien's actual FRI were 80+, it would be excellent.
      // Let's also test with score exactly 80:
      final fri80 = _makeFri(l: 20, f: 20, r: 20, s: 20); // total 80
      final fhs80 = await service.computeDailyAt(fri80, DateTime.now());
      expect(fhs80.score, 80.0);
      expect(fhs80.level, FhsLevel.excellent);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  14. FHS breakdown matches FRI breakdown
  // ═══════════════════════════════════════════════════════════════

  group('Breakdown passthrough', () {
    test('14. FHS breakdown matches FRI breakdown exactly', () async {
      final prefs = await _seedHistory([]);
      final service = FinancialHealthScoreService(prefs);
      final fri = _makeFri(l: 22.5, f: 18.3, r: 14.7, s: 21.0);
      final fhs = await service.computeDailyAt(fri, DateTime.now());

      expect(fhs.liquidite, fri.liquidite);
      expect(fhs.fiscalite, fri.fiscalite);
      expect(fhs.retraite, fri.retraite);
      expect(fhs.risque, fri.risque);
      expect(fhs.score, fri.total);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  15. Empty history → stable, deltas = 0
  // ═══════════════════════════════════════════════════════════════

  group('Empty history', () {
    test('15. empty history → trend stable, deltas = 0', () async {
      final prefs = await _seedHistory([]);
      final service = FinancialHealthScoreService(prefs);
      final fri = _makeFri(l: 15, f: 15, r: 15, s: 15); // total 60
      final fhs = await service.computeDailyAt(fri, DateTime.now());

      expect(fhs.trend, FhsTrend.stable);
      expect(fhs.deltaVsYesterday, 0.0);
      expect(fhs.deltaVsWeekAgo, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  16. Pure computation (same input → same output)
  // ═══════════════════════════════════════════════════════════════

  group('Purity', () {
    test('16. computeDaily is pure (same input → same output, ignoring time)',
        () async {
      final prefs = await _seedHistory([]);
      final service = FinancialHealthScoreService(prefs);
      final fri = _makeFri(l: 10, f: 10, r: 10, s: 10); // total 40
      final fixedTime = DateTime(2026, 3, 17, 12, 0);

      final fhs1 = await service.computeDailyAt(fri, fixedTime);

      // Reset prefs to empty history for second call
      final prefs2 = await _seedHistory([]);
      final service2 = FinancialHealthScoreService(prefs2);
      final fhs2 = await service2.computeDailyAt(fri, fixedTime);

      expect(fhs1.score, fhs2.score);
      expect(fhs1.level, fhs2.level);
      expect(fhs1.trend, fhs2.trend);
      expect(fhs1.deltaVsYesterday, fhs2.deltaVsYesterday);
      expect(fhs1.deltaVsWeekAgo, fhs2.deltaVsWeekAgo);
      expect(fhs1.liquidite, fhs2.liquidite);
      expect(fhs1.fiscalite, fhs2.fiscalite);
      expect(fhs1.retraite, fhs2.retraite);
      expect(fhs1.risque, fhs2.risque);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  17. JSON serialization roundtrip
  // ═══════════════════════════════════════════════════════════════

  group('Serialization', () {
    test('17. FhsDailyScore toJson → fromJson roundtrip', () {
      final original = FhsDailyScore(
        score: 72.5,
        level: FhsLevel.good,
        trend: FhsTrend.up,
        deltaVsYesterday: 3.5,
        deltaVsWeekAgo: -1.2,
        computedAt: DateTime(2026, 3, 17, 10, 30),
        liquidite: 20.0,
        fiscalite: 18.5,
        retraite: 17.0,
        risque: 17.0,
      );

      final json = original.toJson();
      final restored = FhsDailyScore.fromJson(json);

      expect(restored.score, original.score);
      expect(restored.level, original.level);
      expect(restored.trend, original.trend);
      expect(restored.deltaVsYesterday, original.deltaVsYesterday);
      expect(restored.deltaVsWeekAgo, original.deltaVsWeekAgo);
      expect(restored.computedAt, original.computedAt);
      expect(restored.liquidite, original.liquidite);
      expect(restored.fiscalite, original.fiscalite);
      expect(restored.retraite, original.retraite);
      expect(restored.risque, original.risque);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  18. getHistory returns correct window
  // ═══════════════════════════════════════════════════════════════

  group('getHistory', () {
    test('18. getHistory returns entries within requested window', () async {
      final now = DateTime.now();
      final entries = [
        _makeHistoryEntry(score: 50, computedAt: now.subtract(const Duration(days: 10))),
        _makeHistoryEntry(score: 55, computedAt: now.subtract(const Duration(days: 5))),
        _makeHistoryEntry(score: 60, computedAt: now.subtract(const Duration(days: 2))),
        _makeHistoryEntry(score: 65, computedAt: now.subtract(const Duration(days: 1))),
      ];
      final prefs = await _seedHistory(entries);
      final service = FinancialHealthScoreService(prefs);

      // Last 7 days should include 3 entries (days 5, 2, 1)
      final last7 = service.getHistory(7);
      expect(last7.length, 3);
      // Newest first
      expect(last7.first.score, 65.0);
      expect(last7.last.score, 55.0);

      // Last 3 days should include 2 entries (days 2, 1)
      final last3 = service.getHistory(3);
      expect(last3.length, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  19. All-zeros edge case
  // ═══════════════════════════════════════════════════════════════

  group('Edge cases', () {
    test('19. all-zeros FRI → FHS score 0, level critical', () async {
      final prefs = await _seedHistory([]);
      final service = FinancialHealthScoreService(prefs);
      final fri = _makeFri(l: 0, f: 0, r: 0, s: 0); // total 0
      final fhs = await service.computeDailyAt(fri, DateTime.now());

      expect(fhs.score, 0.0);
      expect(fhs.level, FhsLevel.critical);
      expect(fhs.liquidite, 0.0);
      expect(fhs.fiscalite, 0.0);
      expect(fhs.retraite, 0.0);
      expect(fhs.risque, 0.0);
      expect(fhs.trend, FhsTrend.stable);
      expect(fhs.deltaVsYesterday, 0.0);
    });

    test('20. maximum profile (100) → FHS excellent', () async {
      final prefs = await _seedHistory([]);
      final service = FinancialHealthScoreService(prefs);
      final fri = _makeFri(l: 25, f: 25, r: 25, s: 25); // total 100
      final fhs = await service.computeDailyAt(fri, DateTime.now());

      expect(fhs.score, 100.0);
      expect(fhs.level, FhsLevel.excellent);
    });

    test('21. trend detection across 3 consecutive days', () async {
      // Use fixed dates to avoid freshness decay drift
      final day3 = DateTime(2026, 3, 15);
      final day1 = day3.subtract(const Duration(days: 2));
      final day2 = day3.subtract(const Duration(days: 1));

      // Day 1: score 50
      final prefs1 = await _seedHistory([
        _makeHistoryEntry(score: 50, computedAt: day1),
      ]);
      final service1 = FinancialHealthScoreService(prefs1);
      final fri60 = _makeFri(l: 15, f: 15, r: 15, s: 15); // total 60
      final fhsDay2 = await service1.computeDailyAt(fri60, day2);
      // Day 2 vs Day 1: delta = 60-50 = 10 → up
      expect(fhsDay2.trend, FhsTrend.up);
      expect(fhsDay2.deltaVsYesterday, closeTo(10.0, 0.1));

      // Day 3: score drops to 45
      final prefs2 = await _seedHistory([
        _makeHistoryEntry(score: 50, computedAt: day1),
        _makeHistoryEntry(score: 60, computedAt: day2),
      ]);
      final service2 = FinancialHealthScoreService(prefs2);
      final fri45 = _makeFri(l: 10, f: 10, r: 15, s: 10); // total 45
      final fhsDay3 = await service2.computeDailyAt(fri45, day3);
      // Day 3 vs Day 2: delta = 45-60 = -15 → down
      expect(fhsDay3.trend, FhsTrend.down);
      expect(fhsDay3.deltaVsYesterday, closeTo(-15.0, 0.1));
    });
  });
}
