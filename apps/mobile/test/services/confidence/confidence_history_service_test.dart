import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/confidence_point.dart';
import 'package:mint_mobile/services/confidence/confidence_history_service.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:shared_preferences/shared_preferences.dart';

EnhancedConfidence _confidence(double combined) => EnhancedConfidence(
      completeness: 60,
      accuracy: 50,
      freshness: 70,
      understanding: 40,
      combined: combined,
      level: 'medium',
      baseResult: const ProjectionConfidence(
        score: 60,
        level: 'medium',
        prompts: [],
        assumptions: [],
      ),
    );

ConfidencePoint _point(DateTime date, double combined,
        {String trigger = 'test'}) =>
    ConfidencePoint(
      date: date,
      combined: combined,
      completeness: combined,
      accuracy: combined,
      freshness: combined,
      understanding: combined,
      trigger: trigger,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('mergePoint (pure de-dup / cap)', () {
    test('same-day point replaces the earlier one (latest wins)', () {
      final existing = [_point(DateTime(2026, 3, 12, 9), 40)];
      final merged =
          ConfidenceHistoryService.mergePoint(existing, _point(DateTime(2026, 3, 12, 18), 55));
      expect(merged, hasLength(1));
      expect(merged.single.combined, 55);
    });

    test('different days are kept and ordered chronologically', () {
      var list = <ConfidencePoint>[];
      list = ConfidenceHistoryService.mergePoint(list, _point(DateTime(2026, 3, 14), 50));
      list = ConfidenceHistoryService.mergePoint(list, _point(DateTime(2026, 3, 12), 40));
      list = ConfidenceHistoryService.mergePoint(list, _point(DateTime(2026, 3, 13), 45));
      expect(list.map((p) => p.combined).toList(), [40, 45, 50]);
    });

    test('a passive profile_load does not downgrade a same-day explicit event',
        () {
      final existing = [
        _point(DateTime(2026, 3, 12, 19), 62, trigger: 'document_scan'),
      ];
      final merged = ConfidenceHistoryService.mergePoint(
        existing,
        _point(DateTime(2026, 3, 12, 22), 62, trigger: 'profile_load'),
      );
      expect(merged, hasLength(1));
      expect(merged.single.trigger, 'document_scan');
    });

    test('an explicit event replaces a same-day passive profile_load', () {
      final existing = [
        _point(DateTime(2026, 3, 12, 8), 40, trigger: 'profile_load'),
      ];
      final merged = ConfidenceHistoryService.mergePoint(
        existing,
        _point(DateTime(2026, 3, 12, 19), 58, trigger: 'document_scan'),
      );
      expect(merged, hasLength(1));
      expect(merged.single.trigger, 'document_scan');
      expect(merged.single.combined, 58);
    });

    test('caps at 90 most-recent days, dropping the oldest', () {
      var list = <ConfidencePoint>[];
      for (var i = 0; i < 95; i++) {
        list = ConfidenceHistoryService.mergePoint(
          list,
          _point(DateTime(2026, 1, 1).add(Duration(days: i)), 30 + i.toDouble()),
        );
      }
      expect(list, hasLength(90));
      // Oldest kept = day index 5 (30+5), newest = day index 94 (30+94).
      expect(list.first.combined, 35);
      expect(list.last.combined, 124);
    });
  });

  group('record / load / clear round-trip', () {
    test('records a point and reloads it with axes preserved', () async {
      await ConfidenceHistoryService.record(
        _confidence(54),
        trigger: 'document_scan',
        now: DateTime(2026, 3, 12, 10),
      );
      final history = await ConfidenceHistoryService.load();
      expect(history, hasLength(1));
      final p = history.single;
      expect(p.combined, 54);
      expect(p.completeness, 60);
      expect(p.accuracy, 50);
      expect(p.freshness, 70);
      expect(p.understanding, 40);
      expect(p.trigger, 'document_scan');
    });

    test('two records on the same day collapse to the latest', () async {
      await ConfidenceHistoryService.record(_confidence(40),
          trigger: 'profile_load', now: DateTime(2026, 3, 12, 8));
      await ConfidenceHistoryService.record(_confidence(58),
          trigger: 'document_scan', now: DateTime(2026, 3, 12, 20));
      final history = await ConfidenceHistoryService.load();
      expect(history, hasLength(1));
      expect(history.single.combined, 58);
      expect(history.single.trigger, 'document_scan');
    });

    test('records across days build a chronological series', () async {
      await ConfidenceHistoryService.record(_confidence(40),
          trigger: 'profile_load', now: DateTime(2026, 3, 12));
      await ConfidenceHistoryService.record(_confidence(52),
          trigger: 'check_in', now: DateTime(2026, 3, 19));
      final history = await ConfidenceHistoryService.load();
      expect(history.map((p) => p.combined).toList(), [40, 52]);
    });

    test('skips a non-positive combined score (empty/identity profile)',
        () async {
      await ConfidenceHistoryService.record(_confidence(0),
          trigger: 'profile_load', now: DateTime(2026, 3, 12));
      expect(await ConfidenceHistoryService.load(), isEmpty);
    });

    test('clear() erases the history', () async {
      await ConfidenceHistoryService.record(_confidence(54),
          trigger: 'profile_load', now: DateTime(2026, 3, 12));
      expect(await ConfidenceHistoryService.load(), hasLength(1));
      await ConfidenceHistoryService.clear();
      expect(await ConfidenceHistoryService.load(), isEmpty);
    });
  });

  test('ConfidencePoint JSON round-trip', () {
    final p = _point(DateTime(2026, 3, 12, 10, 30), 61.5);
    final restored = ConfidencePoint.fromJson(p.toJson());
    expect(restored.combined, 61.5);
    expect(restored.dayKey, '2026-03-12');
    expect(restored.date, p.date);
  });
}
