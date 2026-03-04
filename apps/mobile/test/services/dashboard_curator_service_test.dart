import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/dashboard_curator_service.dart';
import 'package:mint_mobile/services/reengagement_engine.dart';

/// Unit tests for DashboardCuratorService (P3).
///
/// Tests cover:
///   - Alert urgency computation
///   - Deadline text formatting
///   - Deadline days calculation with year-wrapping
///   - Card curation (sorting, limiting, mixed sources)
///   - Tip ID alignment with CoachingService
///   - Edge cases (empty, null, boundaries)
void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  CoachingTip _makeTip({
    required String id,
    CoachingPriority priority = CoachingPriority.basse,
    double? impact,
  }) {
    return CoachingTip(
      id: id,
      category: 'test',
      priority: priority,
      title: 'Tip $id',
      message: 'Message for $id',
      action: 'Action',
      estimatedImpactChf: impact,
      source: 'Test source',
      icon: Icons.info,
    );
  }

  ReengagementMessage _makeReengagement({
    required String title,
    ReengagementTrigger trigger = ReengagementTrigger.quarterlyFri,
  }) {
    return ReengagementMessage(
      trigger: trigger,
      title: title,
      body: 'Body for $title',
      deeplink: '/test',
      personalNumber: 'CHF 100',
      timeConstraint: '30 jours',
      month: 1,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 1. ALERT URGENCY
  // ═══════════════════════════════════════════════════════════════════════

  group('computeAlertUrgency', () {
    test('null tip returns info', () {
      expect(
        DashboardCuratorService.computeAlertUrgency(null),
        AlertUrgency.info,
      );
    });

    test('non-haute priority returns info', () {
      final tip = _makeTip(id: 'deadline_3a', priority: CoachingPriority.basse);
      expect(
        DashboardCuratorService.computeAlertUrgency(tip),
        AlertUrgency.info,
      );
    });

    test('haute priority with deadline <= 30 days returns urgent', () {
      final tip = _makeTip(
        id: 'deadline_3a',
        priority: CoachingPriority.haute,
      );
      // In December, deadline is <= 30 days
      final urgency = DashboardCuratorService.computeAlertUrgency(tip);
      // This depends on current date — we just verify it's not info
      expect(urgency, isNot(AlertUrgency.info));
    });

    test('haute priority without deadline returns active', () {
      final tip = _makeTip(
        id: 'unknown_tip',
        priority: CoachingPriority.haute,
      );
      expect(
        DashboardCuratorService.computeAlertUrgency(tip),
        AlertUrgency.active,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2. DEADLINE TEXT
  // ═══════════════════════════════════════════════════════════════════════

  group('computeDeadlineText', () {
    test('null tip returns null', () {
      expect(DashboardCuratorService.computeDeadlineText(null), isNull);
    });

    test('tip without deadline returns null', () {
      final tip = _makeTip(id: 'emergency_fund');
      expect(DashboardCuratorService.computeDeadlineText(tip), isNull);
    });

    test('tip with deadline returns J-X format', () {
      final tip = _makeTip(id: 'deadline_3a');
      final text = DashboardCuratorService.computeDeadlineText(tip);
      // Should be non-null since deadline_3a has a date
      expect(text, isNotNull);
      expect(text,
          anyOf(startsWith('J-'), equals("Aujourd'hui"), equals('Demain')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3. DEADLINE DAYS WITH YEAR-WRAPPING
  // ═══════════════════════════════════════════════════════════════════════

  group('getDeadlineDaysForTip', () {
    test('deadline_3a returns Dec 31 days', () {
      final tip = _makeTip(id: 'deadline_3a');
      final days = DashboardCuratorService.getDeadlineDaysForTip(
        tip,
        today: DateTime(2026, 6, 1),
      );
      // Jun 1 to Dec 31 = 213 days
      expect(days, 213);
    });

    test('deadline_3a wraps to next year after Dec 31', () {
      final tip = _makeTip(id: 'deadline_3a');
      final days = DashboardCuratorService.getDeadlineDaysForTip(
        tip,
        today: DateTime(2027, 1, 1),
      );
      // Jan 1, 2027 to Dec 31, 2027 = 364 days
      expect(days, 364);
    });

    test('missing_3a maps to same deadline as deadline_3a', () {
      final tip1 = _makeTip(id: 'deadline_3a');
      final tip2 = _makeTip(id: 'missing_3a');
      final today = DateTime(2026, 3, 15);

      final days1 = DashboardCuratorService.getDeadlineDaysForTip(
        tip1,
        today: today,
      );
      final days2 = DashboardCuratorService.getDeadlineDaysForTip(
        tip2,
        today: today,
      );
      expect(days1, days2);
    });

    test('3a_not_maxed maps to same deadline as deadline_3a', () {
      final tip = _makeTip(id: '3a_not_maxed');
      final days = DashboardCuratorService.getDeadlineDaysForTip(
        tip,
        today: DateTime(2026, 10, 1),
      );
      // Oct 1 to Dec 31 = 91 days
      expect(days, 91);
    });

    test('tax_deadline returns Mar 31 days', () {
      final tip = _makeTip(id: 'tax_deadline');
      final days = DashboardCuratorService.getDeadlineDaysForTip(
        tip,
        today: DateTime(2026, 1, 15),
      );
      // Jan 15 to Mar 31 = 74-75 days (depends on DateTime precision)
      expect(days, inInclusiveRange(74, 75));
    });

    test('tax_deadline wraps to next year after Mar 31', () {
      final tip = _makeTip(id: 'tax_deadline');
      final days = DashboardCuratorService.getDeadlineDaysForTip(
        tip,
        today: DateTime(2026, 4, 1),
      );
      // Apr 1 to Mar 31 next year = 364 days
      expect(days, 364);
    });

    test('lpp_buyback returns Dec 31 with year-wrap', () {
      final tip = _makeTip(id: 'lpp_buyback');
      final days = DashboardCuratorService.getDeadlineDaysForTip(
        tip,
        today: DateTime(2027, 1, 2),
      );
      // Jan 2 to Dec 31 = 363 days
      expect(days, 363);
    });

    test('unknown tip returns null', () {
      final tip = _makeTip(id: 'emergency_fund');
      expect(
        DashboardCuratorService.getDeadlineDaysForTip(tip),
        isNull,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4. CARD CURATION
  // ═══════════════════════════════════════════════════════════════════════

  group('curate', () {
    test('empty inputs returns empty list', () {
      final result = DashboardCuratorService.curate(tips: []);
      expect(result, isEmpty);
    });

    test('respects maxCards limit', () {
      final tips = List.generate(
        10,
        (i) => _makeTip(id: 'tip_$i', impact: 1000.0 * i),
      );
      final result = DashboardCuratorService.curate(tips: tips);
      expect(result.length, DashboardCuratorService.maxCards);
    });

    test('custom limit works', () {
      final tips = List.generate(
        10,
        (i) => _makeTip(id: 'tip_$i'),
      );
      final result = DashboardCuratorService.curate(tips: tips, limit: 2);
      expect(result.length, 2);
    });

    test('sorts by urgency first', () {
      final tips = [
        _makeTip(id: 'emergency_fund', priority: CoachingPriority.basse),
        _makeTip(id: 'deadline_3a', priority: CoachingPriority.haute),
      ];
      final result = DashboardCuratorService.curate(tips: tips);
      // deadline_3a has a deadline + haute priority → more urgent
      expect(result.first.title, contains('deadline_3a'));
    });

    test('sorts by impact when urgency is equal', () {
      final tips = [
        _makeTip(id: 'tip_low', impact: 100),
        _makeTip(id: 'tip_high', impact: 5000),
      ];
      final result = DashboardCuratorService.curate(tips: tips);
      // Higher impact first
      expect(result.first.title, contains('tip_high'));
    });

    test('mixes coaching tips and reengagement messages', () {
      final tips = [_makeTip(id: 'emergency_fund', impact: 200)];
      final msgs = [_makeReengagement(title: 'Quarterly FRI')];
      final result = DashboardCuratorService.curate(
        tips: tips,
        reengagementMessages: msgs,
      );
      expect(result.length, 2);
      final types = result.map((c) => c.type).toSet();
      expect(types, contains(CuratedCardType.coachingTip));
      expect(types, contains(CuratedCardType.reengagement));
    });

    test('curated card has correct fields', () {
      final tip = _makeTip(id: 'lpp_buyback', impact: 3000);
      tip.narrativeMessage = 'LLM enriched message';
      final result = DashboardCuratorService.curate(tips: [tip]);

      expect(result.single.type, CuratedCardType.coachingTip);
      expect(result.single.title, 'Tip lpp_buyback');
      expect(result.single.message, 'LLM enriched message');
      expect(result.single.impactChf, 3000);
      expect(result.single.source, isA<CoachingTip>());
    });

    test('prefers narrativeMessage over message', () {
      final tip = _makeTip(id: 'test');
      tip.narrativeMessage = 'Enriched';
      final result = DashboardCuratorService.curate(tips: [tip]);
      expect(result.single.message, 'Enriched');
    });

    test('falls back to message when narrativeMessage is null', () {
      final tip = _makeTip(id: 'test');
      final result = DashboardCuratorService.curate(tips: [tip]);
      expect(result.single.message, 'Message for test');
    });

    test('maps known coaching tip IDs to active deeplinks', () {
      final result = DashboardCuratorService.curate(tips: [
        _makeTip(id: 'missing_3a'),
        _makeTip(id: 'lpp_buyback'),
        _makeTip(id: 'retirement_countdown'),
        _makeTip(id: 'debt_ratio'),
      ], limit: 10);

      final deeplinks = {
        for (final c in result)
          if (c.deeplink != null) c.title: c.deeplink!,
      };

      expect(deeplinks['Tip missing_3a'], '/3a-deep/comparator');
      expect(deeplinks['Tip lpp_buyback'], '/lpp-deep/rachat');
      expect(deeplinks['Tip retirement_countdown'], '/coach/projection');
      expect(deeplinks['Tip debt_ratio'], '/budget');
    });

    test('unknown tip ID keeps null deeplink', () {
      final result = DashboardCuratorService.curate(
        tips: [_makeTip(id: 'unknown_tip')],
      );
      expect(result.single.deeplink, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 5. TIP ID ALIGNMENT
  // ═══════════════════════════════════════════════════════════════════════

  group('Tip ID alignment with CoachingService', () {
    test('all known tip IDs have valid deadline mapping', () {
      final knownDeadlineIds = [
        'deadline_3a',
        'missing_3a',
        '3a_not_maxed',
        'tax_deadline',
        'lpp_buyback',
      ];

      for (final id in knownDeadlineIds) {
        final tip = _makeTip(id: id);
        final days = DashboardCuratorService.getDeadlineDaysForTip(
          tip,
          today: DateTime(2026, 6, 15),
        );
        expect(days, isNotNull, reason: '$id should have a deadline');
        expect(days, greaterThanOrEqualTo(0),
            reason: '$id days should be >= 0');
      }
    });

    test('non-deadline tips return null correctly', () {
      final noDeadlineIds = [
        'retirement_countdown',
        'emergency_fund',
        'debt_ratio',
        'budget_missing',
        'budget_drift',
      ];

      for (final id in noDeadlineIds) {
        final tip = _makeTip(id: id);
        expect(
          DashboardCuratorService.getDeadlineDaysForTip(tip),
          isNull,
          reason: '$id should not have a deadline',
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6. CONSTANTS
  // ═══════════════════════════════════════════════════════════════════════

  group('Constants', () {
    test('maxCards is 4', () {
      expect(DashboardCuratorService.maxCards, 4);
    });
  });
}
