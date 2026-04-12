import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/services/anticipation/anticipation_ranking.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';

// ────────────────────────────────────────────────────────────
//  ANTICIPATION RANKING TESTS — Phase 04 Plan 02
// ────────────────────────────────────────────────────────────
//
// Tests for AnticipationRanking.rank():
//   - Priority score formula: timeliness*0.5 + relevance*0.3 + confidence*0.2
//   - Top-2 split (visible vs overflow)
//   - Weekly budget enforcement
//   - Descending sort order
// ────────────────────────────────────────────────────────────

AnticipationSignal _makeSignal({
  required String id,
  AlertTemplate template = AlertTemplate.fiscal3aDeadline,
  required DateTime expiresAt,
  double priorityScore = 0.0,
}) {
  return AnticipationSignal(
    id: id,
    template: template,
    titleKey: 'test_title',
    factKey: 'test_fact',
    sourceRef: 'Test art. 1',
    simulatorLink: '/test',
    priorityScore: priorityScore,
    expiresAt: expiresAt,
  );
}

void main() {
  final now = DateTime(2026, 4, 6);

  // ═══════════════════════════════════════════════════════════
  // Basic ranking
  // ═══════════════════════════════════════════════════════════

  group('Basic ranking', () {
    test('rank with 3 signals returns 2 visible + 1 overflow', () {
      final signals = [
        _makeSignal(
          id: 's1',
          template: AlertTemplate.fiscal3aDeadline,
          expiresAt: now.add(const Duration(days: 10)),
        ),
        _makeSignal(
          id: 's2',
          template: AlertTemplate.cantonalTaxDeadline,
          expiresAt: now.add(const Duration(days: 20)),
        ),
        _makeSignal(
          id: 's3',
          template: AlertTemplate.lppRachatWindow,
          expiresAt: now.add(const Duration(days: 50)),
        ),
      ];

      final result = AnticipationRanking.rank(
        signals: signals,
        now: now,
        signalsAlreadyShownThisWeek: 0,
      );

      expect(result.visible.length, 2);
      expect(result.overflow.length, 1);
    });

    test('rank with 1 signal returns visible=[1], overflow=[]', () {
      final signals = [
        _makeSignal(
          id: 's1',
          expiresAt: now.add(const Duration(days: 10)),
        ),
      ];

      final result = AnticipationRanking.rank(
        signals: signals,
        now: now,
        signalsAlreadyShownThisWeek: 0,
      );

      expect(result.visible.length, 1);
      expect(result.overflow, isEmpty);
    });

    test('rank with 0 signals returns both empty', () {
      final result = AnticipationRanking.rank(
        signals: [],
        now: now,
        signalsAlreadyShownThisWeek: 0,
      );

      expect(result.visible, isEmpty);
      expect(result.overflow, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Timeliness scoring
  // ═══════════════════════════════════════════════════════════

  group('Timeliness scoring', () {
    test('signal expiring in 3 days scores higher than 60 days', () {
      final urgent = _makeSignal(
        id: 's1',
        expiresAt: now.add(const Duration(days: 3)),
      );
      final distant = _makeSignal(
        id: 's2',
        expiresAt: now.add(const Duration(days: 60)),
      );

      final urgentTimeliness =
          AnticipationRanking.computeTimeliness(urgent, now);
      final distantTimeliness =
          AnticipationRanking.computeTimeliness(distant, now);

      expect(urgentTimeliness, greaterThan(distantTimeliness));
    });

    test('signal expiring today has timeliness ~1.0', () {
      final today = _makeSignal(
        id: 's1',
        expiresAt: now,
      );

      final timeliness = AnticipationRanking.computeTimeliness(today, now);
      expect(timeliness, closeTo(1.0, 0.01));
    });

    test('signal expiring in 90+ days has timeliness 0.0', () {
      final far = _makeSignal(
        id: 's1',
        expiresAt: now.add(const Duration(days: 100)),
      );

      final timeliness = AnticipationRanking.computeTimeliness(far, now);
      expect(timeliness, closeTo(0.0, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Priority score formula
  // ═══════════════════════════════════════════════════════════

  group('Priority score formula', () {
    test('exact formula: timeliness*0.5 + relevance*0.3 + confidence*0.2',
        () {
      // fiscal3aDeadline: relevance = 1.0, confidence = 0.8
      // 9 days until expiry -> timeliness = 1.0 - (9/90) = 0.9
      final signal = _makeSignal(
        id: 's1',
        template: AlertTemplate.fiscal3aDeadline,
        expiresAt: now.add(const Duration(days: 9)),
      );

      final result = AnticipationRanking.rank(
        signals: [signal],
        now: now,
        signalsAlreadyShownThisWeek: 0,
      );

      // timeliness=0.9, relevance=1.0, confidence=0.8
      // score = 0.9*0.5 + 1.0*0.3 + 0.8*0.2 = 0.45 + 0.30 + 0.16 = 0.91
      expect(result.visible.first.priorityScore, closeTo(0.91, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Base relevance per template
  // ═══════════════════════════════════════════════════════════

  group('Base relevance', () {
    test('fiscal3aDeadline has highest relevance', () {
      expect(
        AnticipationRanking.baseRelevance(AlertTemplate.fiscal3aDeadline),
        1.0,
      );
    });

    test('cantonalTaxDeadline relevance is 0.9', () {
      expect(
        AnticipationRanking.baseRelevance(AlertTemplate.cantonalTaxDeadline),
        0.9,
      );
    });

    test('salaryIncrease3aRecalc relevance is 0.95', () {
      expect(
        AnticipationRanking.baseRelevance(AlertTemplate.salaryIncrease3aRecalc),
        0.95,
      );
    });

    test('lppRachatWindow relevance is 0.8', () {
      expect(
        AnticipationRanking.baseRelevance(AlertTemplate.lppRachatWindow),
        0.8,
      );
    });

    test('ageMilestoneLppBonification relevance is 0.85', () {
      expect(
        AnticipationRanking.baseRelevance(
            AlertTemplate.ageMilestoneLppBonification),
        0.85,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Weekly budget
  // ═══════════════════════════════════════════════════════════

  group('Weekly budget', () {
    test('signalsAlreadyShownThisWeek=1 caps visible at 1', () {
      final signals = [
        _makeSignal(
          id: 's1',
          expiresAt: now.add(const Duration(days: 5)),
        ),
        _makeSignal(
          id: 's2',
          template: AlertTemplate.cantonalTaxDeadline,
          expiresAt: now.add(const Duration(days: 10)),
        ),
      ];

      final result = AnticipationRanking.rank(
        signals: signals,
        now: now,
        signalsAlreadyShownThisWeek: 1,
      );

      expect(result.visible.length, 1);
      expect(result.overflow.length, 1);
    });

    test('signalsAlreadyShownThisWeek=2 means budget exhausted', () {
      final signals = [
        _makeSignal(
          id: 's1',
          expiresAt: now.add(const Duration(days: 5)),
        ),
        _makeSignal(
          id: 's2',
          template: AlertTemplate.cantonalTaxDeadline,
          expiresAt: now.add(const Duration(days: 10)),
        ),
      ];

      final result = AnticipationRanking.rank(
        signals: signals,
        now: now,
        signalsAlreadyShownThisWeek: 2,
      );

      expect(result.visible, isEmpty);
      expect(result.overflow.length, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Sort order
  // ═══════════════════════════════════════════════════════════

  group('Sort order', () {
    test('visible list is sorted descending by priorityScore', () {
      final signals = [
        _makeSignal(
          id: 's1',
          template: AlertTemplate.lppRachatWindow, // lower relevance
          expiresAt: now.add(const Duration(days: 60)),
        ),
        _makeSignal(
          id: 's2',
          template: AlertTemplate.fiscal3aDeadline, // higher relevance
          expiresAt: now.add(const Duration(days: 5)),
        ),
        _makeSignal(
          id: 's3',
          template: AlertTemplate.cantonalTaxDeadline,
          expiresAt: now.add(const Duration(days: 10)),
        ),
      ];

      final result = AnticipationRanking.rank(
        signals: signals,
        now: now,
        signalsAlreadyShownThisWeek: 0,
      );

      expect(result.visible.length, 2);
      expect(
        result.visible.first.priorityScore,
        greaterThanOrEqualTo(result.visible.last.priorityScore),
      );
    });
  });
}
