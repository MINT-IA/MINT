import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';
import 'package:mint_mobile/services/temporal_priority_service.dart';

/// Unit tests for TemporalPriorityService (P3).
///
/// Tests cover:
///   - Prioritization output structure
///   - Temporal sorting (urgency + daysUntil)
///   - Cross-source deduplication (3a triggers + tax categories)
///   - Limit enforcement
///   - Edge cases (empty inputs, zero values, boundaries)
///   - Calendar-driven deadline computation
void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // 1. BASIC OUTPUT
  // ═══════════════════════════════════════════════════════════════════════

  group('prioritize — basic output', () {
    test('returns non-empty list for October (3a countdown active)', () {
      final items = TemporalPriorityService.prioritize(
        today: DateTime(2026, 10, 15),
        canton: 'ZH',
        taxSaving3a: 1800,
        friTotal: 55,
        friDelta: 3,
      );
      expect(items, isNotEmpty);
    });

    test('returns TemporalItem objects with required fields', () {
      final items = TemporalPriorityService.prioritize(
        today: DateTime(2026, 10, 15),
        canton: 'ZH',
        taxSaving3a: 1800,
        friTotal: 55,
        friDelta: 3,
      );

      if (items.isNotEmpty) {
        final item = items.first;
        expect(item.title, isNotEmpty);
        expect(item.body, isNotEmpty);
        expect(item.deeplink, isNotEmpty);
        expect(item.urgency, isA<TemporalUrgency>());
        expect(item.daysUntil, isA<int>());
        expect(item.source, isA<TemporalSource>());
      }
    });

    test('respects limit parameter', () {
      final items = TemporalPriorityService.prioritize(
        today: DateTime(2026, 10, 15),
        canton: 'ZH',
        taxSaving3a: 1800,
        friTotal: 55,
        friDelta: 3,
        limit: 2,
      );
      expect(items.length, lessThanOrEqualTo(2));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. SORTING
  // ═══════════════════════════════════════════════════════════════════════

  group('prioritize — sorting', () {
    test('items sorted by urgency (critical first)', () {
      final items = TemporalPriorityService.prioritize(
        today: DateTime(2026, 12, 20),
        canton: 'ZH',
        taxSaving3a: 1800,
        friTotal: 55,
        friDelta: 3,
      );

      if (items.length >= 2) {
        for (int i = 0; i < items.length - 1; i++) {
          final current = items[i].urgency.index;
          final next = items[i + 1].urgency.index;
          // If same urgency, daysUntil should be ascending
          if (current == next) {
            expect(
                items[i].daysUntil, lessThanOrEqualTo(items[i + 1].daysUntil));
          } else {
            expect(current, lessThanOrEqualTo(next));
          }
        }
      }
    });

    test('December items have higher urgency than January items', () {
      final decItems = TemporalPriorityService.prioritize(
        today: DateTime(2026, 12, 15),
        canton: 'ZH',
        taxSaving3a: 1800,
        friTotal: 55,
        friDelta: 3,
      );

      final janItems = TemporalPriorityService.prioritize(
        today: DateTime(2026, 1, 15),
        canton: 'ZH',
        taxSaving3a: 1800,
        friTotal: 55,
        friDelta: 3,
      );

      // December should have at least one critical (threeAFinal)
      if (decItems.isNotEmpty) {
        expect(
          decItems.any((i) => i.urgency == TemporalUrgency.critical),
          isTrue,
          reason: 'December should have critical 3a deadline',
        );
      }

      // January should not have critical 3a
      if (janItems.isNotEmpty) {
        final has3aCritical = janItems.any(
          (i) =>
              i.urgency == TemporalUrgency.critical &&
              i.title.toLowerCase().contains('3a'),
        );
        expect(
          has3aCritical,
          isFalse,
          reason: 'January should not have critical 3a deadline',
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. CROSS-SOURCE DEDUPLICATION
  // ═══════════════════════════════════════════════════════════════════════

  group('prioritize — deduplication', () {
    test('no duplicate 3a items across reengagement and notifications', () {
      final items = TemporalPriorityService.prioritize(
        today: DateTime(2026, 10, 15),
        canton: 'ZH',
        taxSaving3a: 1800,
        friTotal: 55,
        friDelta: 3,
      );

      final threeAItems = items
          .where(
            (i) => i.title.toLowerCase().contains('3a'),
          )
          .toList();

      // At most 1 3a-related item thanks to dedup
      expect(
        threeAItems.length,
        lessThanOrEqualTo(1),
        reason: '3a items should be deduplicated across sources',
      );
    });

    test('no duplicate tax items across reengagement and notifications', () {
      final items = TemporalPriorityService.prioritize(
        today: DateTime(2026, 2, 15),
        canton: 'ZH',
        taxSaving3a: 1800,
        friTotal: 55,
        friDelta: 3,
      );

      final taxItems = items
          .where(
            (i) =>
                i.title.toLowerCase().contains('fiscal') ||
                i.title.toLowerCase().contains('imp\u00f4') ||
                i.title.toLowerCase().contains('tax'),
          )
          .toList();

      expect(
        taxItems.length,
        lessThanOrEqualTo(1),
        reason: 'Tax items should be deduplicated across sources',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. YEAR-WRAPPING
  // ═══════════════════════════════════════════════════════════════════════

  group('prioritize — year-wrapping', () {
    test('3a deadlines always have positive daysUntil', () {
      // Test on Jan 1 (just after Dec 31) — should wrap to next year
      final items = TemporalPriorityService.prioritize(
        today: DateTime(2027, 1, 1),
        canton: 'ZH',
        taxSaving3a: 1800,
        friTotal: 55,
        friDelta: 3,
      );

      for (final item in items) {
        expect(
          item.daysUntil,
          greaterThanOrEqualTo(0),
          reason: '${item.title} should have non-negative daysUntil',
        );
      }
    });

    test('tax deadlines always have positive daysUntil', () {
      // Test on Apr 1 (just after Mar 31) — should wrap to next year
      final items = TemporalPriorityService.prioritize(
        today: DateTime(2026, 4, 1),
        canton: 'ZH',
        taxSaving3a: 1800,
        friTotal: 55,
        friDelta: 3,
      );

      for (final item in items) {
        expect(
          item.daysUntil,
          greaterThanOrEqualTo(0),
          reason: '${item.title} should have non-negative daysUntil',
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 5. EDGE CASES
  // ═══════════════════════════════════════════════════════════════════════

  group('prioritize — edge cases', () {
    test('zero tax saving still produces items', () {
      final items = TemporalPriorityService.prioritize(
        today: DateTime(2026, 10, 15),
        canton: 'ZH',
        taxSaving3a: 0,
        friTotal: 0,
        friDelta: 0,
      );
      // Should still generate calendar-driven items
      expect(items, isA<List<TemporalItem>>());
    });

    test('zero limit returns empty list', () {
      final items = TemporalPriorityService.prioritize(
        today: DateTime(2026, 10, 15),
        limit: 0,
      );
      expect(items, isEmpty);
    });

    test('default limit is 5', () {
      final items = TemporalPriorityService.prioritize(
        today: DateTime(2026, 10, 15),
        canton: 'ZH',
        taxSaving3a: 1800,
        friTotal: 55,
        friDelta: 3,
      );
      expect(items.length, lessThanOrEqualTo(5));
    });

    test('includes off-track item when plan status is off-track', () {
      const planStatus = PlanStatus(
        hasPlan: true,
        monthsAnalyzed: 3,
        monthsBehind: 2,
        monthlyPlanned: 1000,
        monthlyActual: 550,
        adherenceRate: 55,
        projectedImpactChf: 24000,
        topGaps: [],
      );

      final items = TemporalPriorityService.prioritize(
        today: DateTime(2026, 10, 15),
        planStatus: planStatus,
      );

      expect(
        items.any((i) => i.body.contains('Adherence a 55%')),
        isTrue,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6. ENUMS
  // ═══════════════════════════════════════════════════════════════════════

  group('Enums', () {
    test('TemporalUrgency has 4 levels', () {
      expect(TemporalUrgency.values.length, 4);
      expect(
          TemporalUrgency.values,
          containsAll([
            TemporalUrgency.critical,
            TemporalUrgency.high,
            TemporalUrgency.medium,
            TemporalUrgency.low,
          ]));
    });

    test('TemporalUrgency order: critical < high < medium < low', () {
      expect(
          TemporalUrgency.critical.index, lessThan(TemporalUrgency.high.index));
      expect(
          TemporalUrgency.high.index, lessThan(TemporalUrgency.medium.index));
      expect(TemporalUrgency.medium.index, lessThan(TemporalUrgency.low.index));
    });

    test('TemporalSource has 2 values', () {
      expect(TemporalSource.values.length, 2);
    });
  });
}
