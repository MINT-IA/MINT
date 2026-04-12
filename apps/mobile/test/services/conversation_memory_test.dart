import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/conversation_memory_service.dart';

// ────────────────────────────────────────────────────────────
//  CONVERSATION MEMORY SERVICE — buildCheckInSummary tests
//  Phase 5 / Suivi & Check-in (SUI-04)
// ────────────────────────────────────────────────────────────

CoachProfile profileWithCheckIns(List<MonthlyCheckIn> checkIns) {
  return CoachProfile(
    birthYear: 1985,
    canton: 'VS',
    salaireBrutMensuel: 8000.0,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
    checkIns: checkIns,
  );
}

void main() {
  group('ConversationMemoryService.buildCheckInSummary', () {
    test('returns empty string when no check-ins exist', () {
      final profile = profileWithCheckIns([]);
      final result = ConversationMemoryService.buildCheckInSummary(profile);
      expect(result, '');
    });

    test('returns summary for a single check-in', () {
      final checkIn = MonthlyCheckIn(
        month: DateTime(2026, 3, 1),
        versements: {'3a': 500.0},
        completedAt: DateTime(2026, 3, 5),
      );
      final profile = profileWithCheckIns([checkIn]);
      final result = ConversationMemoryService.buildCheckInSummary(profile);
      expect(result,
          'Dernier check-in (mars 2026)\u00a0: 500\u00a0CHF vers\u00e9s au total.');
    });

    test('returns most recent check-in when multiple exist', () {
      final older = MonthlyCheckIn(
        month: DateTime(2026, 1, 1),
        versements: {'3a': 300.0},
        completedAt: DateTime(2026, 1, 5),
      );
      final newer = MonthlyCheckIn(
        month: DateTime(2026, 3, 1),
        versements: {'3a': 600.0},
        completedAt: DateTime(2026, 3, 5),
      );
      final profile = profileWithCheckIns([older, newer]);
      final result = ConversationMemoryService.buildCheckInSummary(profile);
      // Should return march (600), not january (300)
      expect(result,
          'Dernier check-in (mars 2026)\u00a0: 600\u00a0CHF vers\u00e9s au total.');
    });

    test('rounds total to nearest integer — 604.83 rounds to 605', () {
      final checkIn = MonthlyCheckIn(
        month: DateTime(2026, 4, 1),
        versements: {'3a': 604.83},
        completedAt: DateTime(2026, 4, 5),
      );
      final profile = profileWithCheckIns([checkIn]);
      final result = ConversationMemoryService.buildCheckInSummary(profile);
      // 604.83 rounds to 605
      expect(result,
          'Dernier check-in (avril 2026)\u00a0: 605\u00a0CHF vers\u00e9s au total.');
    });

    test('sums multiple versements correctly', () {
      final checkIn = MonthlyCheckIn(
        month: DateTime(2026, 2, 1),
        versements: {'3a_julien': 604.0, 'lpp_buyback': 200.0},
        completedAt: DateTime(2026, 2, 10),
      );
      final profile = profileWithCheckIns([checkIn]);
      final result = ConversationMemoryService.buildCheckInSummary(profile);
      expect(result,
          'Dernier check-in (f\u00e9vrier 2026)\u00a0: 804\u00a0CHF vers\u00e9s au total.');
    });

    test('uses correct month name for key months', () {
      final testCases = {
        1: 'janvier',
        2: 'f\u00e9vrier',
        6: 'juin',
        8: 'ao\u00fbt',
        12: 'd\u00e9cembre',
      };
      for (final entry in testCases.entries) {
        final checkIn = MonthlyCheckIn(
          month: DateTime(2026, entry.key, 1),
          versements: {'3a': 100.0},
          completedAt: DateTime(2026, entry.key, 5),
        );
        final profile = profileWithCheckIns([checkIn]);
        final result = ConversationMemoryService.buildCheckInSummary(profile);
        expect(result, contains(entry.value),
            reason: 'Month ${entry.key} should produce ${entry.value}');
      }
    });

    test('T-05-06: result does not contain contribution_id keys (PII minimization)',
        () {
      final checkIn = MonthlyCheckIn(
        month: DateTime(2026, 3, 1),
        versements: {'3a_julien_secret_id': 500.0},
        completedAt: DateTime(2026, 3, 5),
      );
      final profile = profileWithCheckIns([checkIn]);
      final result = ConversationMemoryService.buildCheckInSummary(profile);
      // The contribution_id should NOT appear in the LLM context
      expect(result, isNot(contains('3a_julien_secret_id')));
    });
  });
}
