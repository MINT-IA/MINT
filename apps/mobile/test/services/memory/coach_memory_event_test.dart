/// Tests for [CoachMemoryService.saveEvent] / [hasEvent] — Wave A-MINIMAL A1.
///
/// Contract: events are durable anchors (scan LPP, life event, major
/// financial action) stored in a separate namespace from regular insights
/// so they survive the 50-insight FIFO pruning.
///
/// Refs:
/// - Panel adversaire BUG 5 (FIFO 50 evicts scan events after ~1 week active coaching)
/// - .planning/wave-a-notifs-wiring/PLAN.md (A1)
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

    test('saveEvent persists + hasEvent returns true within freshness window',
        () async {
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'Certificat LPP CPE — 70 377 CHF',
        prefs: prefs,
      );
      final found = await CoachMemoryService.hasEvent(
        'scan_lpp',
        maxAgeDays: 30,
        prefs: prefs,
      );
      expect(found, isTrue);
    });

    test('hasEvent returns false when no matching topic', () async {
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'Certificat LPP',
        prefs: prefs,
      );
      final found = await CoachMemoryService.hasEvent(
        'scan_3a',
        prefs: prefs,
      );
      expect(found, isFalse);
    });

    test('hasEvent returns false when event too old (beyond maxAgeDays)',
        () async {
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'Certificat ancien',
        date: DateTime.now().toUtc().subtract(const Duration(days: 400)),
        prefs: prefs,
      );
      // Within 365 days → not found.
      expect(
        await CoachMemoryService.hasEvent(
          'scan_lpp',
          maxAgeDays: 365,
          prefs: prefs,
        ),
        isFalse,
      );
      // Within 500 days → found.
      expect(
        await CoachMemoryService.hasEvent(
          'scan_lpp',
          maxAgeDays: 500,
          prefs: prefs,
        ),
        isTrue,
      );
    });

    test('saveEvent dedup: same topic same day collapses to one entry',
        () async {
      final now = DateTime.now().toUtc();
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'V1',
        date: now,
        prefs: prefs,
      );
      await CoachMemoryService.saveEvent(
        'scan_lpp',
        'V2 (updated)',
        date: now.add(const Duration(hours: 3)),
        prefs: prefs,
      );
      final events = await CoachMemoryService.getEvents(prefs: prefs);
      final scanLpp = events.where((e) => e.topic == 'scan_lpp').toList();
      expect(scanLpp, hasLength(1),
          reason: 'Same topic same day should dedup to 1 entry');
      expect(scanLpp.first.summary, equals('V2 (updated)'));
    });

    test('different days for same topic create distinct entries', () async {
      final day1 = DateTime.utc(2026, 4, 1, 10);
      final day2 = DateTime.utc(2026, 4, 5, 10);
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
      final events = await CoachMemoryService.getEvents(prefs: prefs);
      expect(events.where((e) => e.topic == 'scan_lpp'), hasLength(2));
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
      final events = await CoachMemoryService.getEvents(prefs: prefs);
      expect(events.where((e) => e.topic == 'scan_lpp'), hasLength(1));

      // hasEvent still true.
      expect(
        await CoachMemoryService.hasEvent('scan_lpp', prefs: prefs),
        isTrue,
        reason: 'Scan event must survive FIFO 50 eviction of regular insights',
      );

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
      final events = await CoachMemoryService.getEvents(prefs: prefs);
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

      expect(await CoachMemoryService.getEvents(prefs: prefs), isEmpty);
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
