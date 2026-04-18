/// Tests for [CoachMemoryService.saveEvent] — Wave A-MINIMAL A1 + A2-fix.
///
/// Contract: events are durable anchors (scan LPP, life event, major
/// financial action) stored in a separate namespace from regular insights
/// so they survive the 50-insight FIFO pruning.
///
/// Refs:
/// - Panel adversaire BUG 5 (FIFO 50 evicts scan events after ~1 week active coaching)
/// - Panel bugs BUG #4 (timezone dedup — local day, not UTC)
/// - .planning/wave-a-notifs-wiring/PLAN.md (A1)
///
/// A2-fix (2026-04-18): hasEvent and getEvents were removed as façade
/// (zero production callers). Tests now use `debugGetEvents` to inspect
/// persistence state — marked `@visibleForTesting` so the API cannot
/// leak into production consumers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CoachMemoryService — events namespace', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('saveEvent persists the entry', () async {
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'Certificat LPP CPE — 70 377 CHF',
        prefs: prefs,
      );
      final events = await CoachMemoryService.debugGetEvents(prefs: prefs);
      expect(events, hasLength(1));
      expect(events.first.topic, 'scan_lpp');
      expect(events.first.type, InsightType.event);
      expect(events.first.summary, 'Certificat LPP CPE — 70 377 CHF');
    });

    test('saveEvent dedup: same topic same LOCAL day → 1 entry, latest wins',
        () async {
      // Use explicit mid-morning times so the 3-hour gap never straddles
      // midnight in any timezone (prior version used DateTime.now()
      // which made the test flaky when CI ran after 21:00 local).
      final morning = DateTime(2026, 4, 18, 10);
      final afternoon = DateTime(2026, 4, 18, 14);
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'V1',
        date: morning,
        prefs: prefs,
      );
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'V2 (updated)',
        date: afternoon,
        prefs: prefs,
      );
      final events = await CoachMemoryService.debugGetEvents(prefs: prefs);
      final scanLpp = events.where((e) => e.topic == 'scan_lpp').toList();
      expect(scanLpp, hasLength(1),
          reason: 'Same topic same local day should dedup to 1 entry');
      expect(scanLpp.first.summary, equals('V2 (updated)'));
    });

    test('different local days for same topic create distinct entries',
        () async {
      final day1 = DateTime(2026, 4, 1, 10);
      final day2 = DateTime(2026, 4, 5, 10);
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'First scan',
        date: day1,
        prefs: prefs,
      );
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'Re-scan after update',
        date: day2,
        prefs: prefs,
      );
      final events = await CoachMemoryService.debugGetEvents(prefs: prefs);
      expect(events.where((e) => e.topic == 'scan_lpp'), hasLength(2));
    });

    test(
        'A2-fix BUG #4 regression: dedup respects LOCAL day, not UTC day. '
        'Two scans that share the same UTC day but straddle midnight in '
        'CEST should be treated as two distinct entries.', () async {
      // Simulate CEST (UTC+2) 00:15 on day N+1 ≈ 22:15 UTC on day N.
      // And 23:45 local on day N ≈ 21:45 UTC on day N.
      // Under UTC bucketing both would collapse to day N → 1 entry.
      // Under LOCAL bucketing they split into day N and day N+1 → 2 entries.
      final lateEvening = DateTime(2026, 4, 3, 23, 45);
      final earlyNextMorning = DateTime(2026, 4, 4, 0, 15);

      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'Late evening scan',
        date: lateEvening,
        prefs: prefs,
      );
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'Next morning scan',
        date: earlyNextMorning,
        prefs: prefs,
      );

      final events = await CoachMemoryService.debugGetEvents(prefs: prefs);
      expect(events.where((e) => e.topic == 'scan_lpp'), hasLength(2),
          reason:
              'Local calendar day is the dedup key — panel bugs BUG #4');
    });

    test('events namespace isolated from regular insights', () async {
      // Save an event.
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'Scan event',
        prefs: prefs,
      );

      // Push 60 regular insights (exceeds _maxInsights = 50, triggers prune).
      for (var i = 0; i < 60; i++) {
        await CoachMemoryService.saveInsight(
          CoachInsight(
            id: 'fact_$i',
            createdAt: DateTime.now(),
            topic: 'topic_$i',
            summary: 'fact $i',
            type: InsightType.fact,
          ),
          prefs: prefs,
        );
      }

      // The event MUST still be retrievable despite FIFO eviction in
      // the insights namespace — this is the point of the separate ns.
      final events = await CoachMemoryService.debugGetEvents(prefs: prefs);
      expect(events.where((e) => e.topic == 'scan_lpp'), hasLength(1),
          reason:
              'Scan event must survive FIFO 50 eviction of regular insights');

      // Sanity: the regular insights WERE pruned to 50.
      final insights = await CoachMemoryService.getInsights(prefs: prefs);
      expect(insights, hasLength(lessThanOrEqualTo(50)));
    });

    test('event entries have InsightType.event', () async {
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'Summary',
        prefs: prefs,
      );
      final events = await CoachMemoryService.debugGetEvents(prefs: prefs);
      expect(events.first.type, equals(InsightType.event));
    });

    test('clear() wipes both insights and events namespaces', () async {
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'will be wiped',
        prefs: prefs,
      );
      await CoachMemoryService.saveInsight(
        CoachInsight(
          id: 'fact_1',
          createdAt: DateTime.now(),
          topic: 'topic',
          summary: 'will be wiped',
          type: InsightType.fact,
        ),
        prefs: prefs,
      );

      await CoachMemoryService.clear(prefs: prefs);

      expect(await CoachMemoryService.debugGetEvents(prefs: prefs), isEmpty);
      expect(await CoachMemoryService.getInsights(prefs: prefs), isEmpty);
    });
  });

  group('InsightType.event JSON round-trip — Wave A-MINIMAL A1', () {
    test('serialize + deserialize preserves event type', () {
      final insight = CoachInsight(
        id: 'e1',
        createdAt: DateTime.utc(2026, 4, 18, 10),
        topic: 'scan_lpp',
        summary: 'Certificat LPP CPE',
        type: InsightType.event,
      );
      final json = insight.toJson();
      expect(json['type'], equals('event'));

      final restored = CoachInsight.fromJson(json);
      expect(restored.type, equals(InsightType.event));
      expect(restored.topic, equals('scan_lpp'));
    });

    test('unknown type string falls back to fact (back-compat)', () {
      final payload = {
        'id': 'x1',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'topic': 'tag',
        'summary': 'summary',
        'type': 'unknown_future_type',
      };
      final restored = CoachInsight.fromJson(payload);
      expect(restored.type, equals(InsightType.fact));
    });
  });
}
