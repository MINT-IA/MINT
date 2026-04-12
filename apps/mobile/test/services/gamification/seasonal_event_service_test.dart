import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/gamification/seasonal_event_service.dart';

// ═══════════════════════════════════════════════════════════════
//  SEASONAL EVENT SERVICE — Unit tests
// ═══════════════════════════════════════════════════════════════
//
// Tests:
//  1.  March → taxSeason active
//  2.  December → pillar3aCountdown active
//  3.  July → midYearReview active
//  4.  October → retirementMonth active
//  5.  January → newYearResolutions active
//  6.  Every month has at least 1 active event
//  7.  isActiveOn logic works correctly
//  8.  No events active outside their windows (basic boundary)
//  9.  August → pillar3aCountdown active (awareness)
// 10.  All events have non-empty keys and valid dates
// 11.  COMPLIANCE: no ranking/comparison terms in keys
// ═══════════════════════════════════════════════════════════════

void main() {
  // ── Active events by month ───────────────────────────────────

  group('SeasonalEventService.activeEvents — monthly coverage', () {
    test('January has newYearResolutions event active', () {
      final events = SeasonalEventService.activeEvents(
        now: DateTime(2026, 1, 15),
      );

      expect(
        events.any((e) => e.type == SeasonalEventType.newYearResolutions),
        isTrue,
      );
    });

    test('February has taxSeason event active', () {
      final events = SeasonalEventService.activeEvents(
        now: DateTime(2026, 2, 14),
      );

      expect(
        events.any((e) => e.type == SeasonalEventType.taxSeason),
        isTrue,
      );
    });

    test('March has taxSeason event active', () {
      final events = SeasonalEventService.activeEvents(
        now: DateTime(2026, 3, 31),
      );

      expect(
        events.any((e) => e.type == SeasonalEventType.taxSeason),
        isTrue,
      );
    });

    test('April has midYearReview event active', () {
      final events = SeasonalEventService.activeEvents(
        now: DateTime(2026, 4, 15),
      );

      expect(
        events.any((e) => e.type == SeasonalEventType.midYearReview),
        isTrue,
      );
    });

    test('May has midYearReview event active', () {
      final events = SeasonalEventService.activeEvents(
        now: DateTime(2026, 5, 10),
      );

      expect(
        events.any((e) => e.type == SeasonalEventType.midYearReview),
        isTrue,
      );
    });

    test('June has midYearReview event active', () {
      final events = SeasonalEventService.activeEvents(
        now: DateTime(2026, 6, 1),
      );

      expect(
        events.any((e) => e.type == SeasonalEventType.midYearReview),
        isTrue,
      );
    });

    test('July has midYearReview event active', () {
      final events = SeasonalEventService.activeEvents(
        now: DateTime(2026, 7, 15),
      );

      expect(
        events.any((e) => e.type == SeasonalEventType.midYearReview),
        isTrue,
      );
    });

    test('August has pillar3aCountdown (awareness) active', () {
      final events = SeasonalEventService.activeEvents(
        now: DateTime(2026, 8, 20),
      );

      expect(
        events.any((e) => e.type == SeasonalEventType.pillar3aCountdown),
        isTrue,
      );
    });

    test('September has pillar3aCountdown active', () {
      final events = SeasonalEventService.activeEvents(
        now: DateTime(2026, 9, 5),
      );

      expect(
        events.any((e) => e.type == SeasonalEventType.pillar3aCountdown),
        isTrue,
      );
    });

    test('October has retirementMonth event active', () {
      final events = SeasonalEventService.activeEvents(
        now: DateTime(2026, 10, 1),
      );

      expect(
        events.any((e) => e.type == SeasonalEventType.retirementMonth),
        isTrue,
      );
    });

    test('November has pillar3aCountdown active', () {
      final events = SeasonalEventService.activeEvents(
        now: DateTime(2026, 11, 25),
      );

      expect(
        events.any((e) => e.type == SeasonalEventType.pillar3aCountdown),
        isTrue,
      );
    });

    test('December has pillar3aCountdown active', () {
      final events = SeasonalEventService.activeEvents(
        now: DateTime(2026, 12, 31),
      );

      expect(
        events.any((e) => e.type == SeasonalEventType.pillar3aCountdown),
        isTrue,
      );
    });

    test('every month has at least 1 active event', () {
      for (int month = 1; month <= 12; month++) {
        final events = SeasonalEventService.activeEvents(
          now: DateTime(2026, month, 15),
        );
        expect(
          events,
          isNotEmpty,
          reason: 'Month $month should have at least 1 active event',
        );
      }
    });
  });

  // ── isActiveOn boundary logic ─────────────────────────────────

  group('SeasonalEvent.isActiveOn — boundary tests', () {
    test('event is active on its start date', () {
      final events = SeasonalEventService.allEventsForYear(2026);
      final taxSeason = events.firstWhere(
        (e) => e.type == SeasonalEventType.taxSeason,
      );

      expect(taxSeason.isActiveOn(taxSeason.startDate), isTrue);
    });

    test('event is active on its end date', () {
      final events = SeasonalEventService.allEventsForYear(2026);
      final taxSeason = events.firstWhere(
        (e) => e.type == SeasonalEventType.taxSeason,
      );

      expect(taxSeason.isActiveOn(taxSeason.endDate), isTrue);
    });

    test('event is not active one day before start', () {
      final events = SeasonalEventService.allEventsForYear(2026);
      final newYear = events.firstWhere(
        (e) => e.type == SeasonalEventType.newYearResolutions,
      );

      final dayBefore = newYear.startDate.subtract(const Duration(days: 1));
      expect(newYear.isActiveOn(dayBefore), isFalse);
    });

    test('taxSeason ends March 31 — not active in April', () {
      final taxSeasonEvent = SeasonalEventService.activeEvents(
        now: DateTime(2026, 4, 1),
      ).where((e) => e.type == SeasonalEventType.taxSeason);

      expect(taxSeasonEvent, isEmpty);
    });
  });

  // ── allEventsForYear ─────────────────────────────────────────

  group('SeasonalEventService.allEventsForYear', () {
    test('returns non-empty list for a given year', () {
      final events = SeasonalEventService.allEventsForYear(2026);
      expect(events, isNotEmpty);
    });

    test('all events have non-empty titleKey', () {
      final events = SeasonalEventService.allEventsForYear(2026);
      for (final e in events) {
        expect(e.titleKey, isNotEmpty, reason: 'Event ${e.id} must have a titleKey');
      }
    });

    test('all events have non-empty descriptionKey', () {
      final events = SeasonalEventService.allEventsForYear(2026);
      for (final e in events) {
        expect(
          e.descriptionKey,
          isNotEmpty,
          reason: 'Event ${e.id} must have a descriptionKey',
        );
      }
    });

    test('all events have startDate before or equal to endDate', () {
      final events = SeasonalEventService.allEventsForYear(2026);
      for (final e in events) {
        expect(
          !e.startDate.isAfter(e.endDate),
          isTrue,
          reason: 'Event ${e.id}: startDate must be <= endDate',
        );
      }
    });

    test('all events belong to expected year', () {
      final events = SeasonalEventService.allEventsForYear(2026);
      for (final e in events) {
        expect(
          e.startDate.year,
          2026,
          reason: 'Event ${e.id} startDate year must be 2026',
        );
      }
    });
  });

  // ── COMPLIANCE ───────────────────────────────────────────────

  group('SeasonalEventService — COMPLIANCE', () {
    test('no event titleKey or descriptionKey contains banned terms', () {
      final bannedTerms = [
        'top',
        'classement',
        'rang',
        'leaderboard',
        'mieux que',
        'pire que',
      ];

      final events = SeasonalEventService.allEventsForYear(2026);
      for (final e in events) {
        for (final term in bannedTerms) {
          expect(
            e.titleKey.toLowerCase(),
            isNot(contains(term)),
            reason: 'Event ${e.id} titleKey must not contain "$term"',
          );
          expect(
            e.descriptionKey.toLowerCase(),
            isNot(contains(term)),
            reason: 'Event ${e.id} descriptionKey must not contain "$term"',
          );
        }
      }
    });
  });
}
