import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/timeline_service.dart';
import 'package:mint_mobile/models/age_band_policy.dart';

/// Unit tests for TimelineService
///
/// Tests the timeline generation from wizard answers, upcoming/overdue
/// reminder filtering, life event delta questions, and event-specific
/// timeline item generation.
void main() {
  const sessionId = 'test-session-001';

  group('generateTimeline — mortgage reminder', () {
    test('creates mortgage renewal reminder 120 days before end date', () {
      final endDate = DateTime.now().add(const Duration(days: 365));
      final answers = <String, dynamic>{
        'q_mortgage_fixed_end_date': endDate.toIso8601String(),
      };

      final items = TimelineService.generateTimeline(sessionId, answers);
      final mortgageItem = items.firstWhere((i) => i.id.contains('mortgage_renewal'));

      expect(mortgageItem.category, 'housing');
      expect(mortgageItem.priority, ReminderPriority.high);
      expect(mortgageItem.sourceSessionId, sessionId);

      // Reminder should be 120 days before end date
      final expectedDate = endDate.subtract(const Duration(days: 120));
      expect(mortgageItem.date.year, expectedDate.year);
      expect(mortgageItem.date.month, expectedDate.month);
      expect(mortgageItem.date.day, expectedDate.day);
    });

    test('no mortgage reminder when q_mortgage_fixed_end_date is null', () {
      final answers = <String, dynamic>{};
      final items = TimelineService.generateTimeline(sessionId, answers);
      expect(items.where((i) => i.id.contains('mortgage')), isEmpty);
    });
  });

  group('generateTimeline — leasing reminder', () {
    test('creates leasing end reminder 60 days before end date', () {
      final endDate = DateTime.now().add(const Duration(days: 200));
      final answers = <String, dynamic>{
        'q_leasing_end_date': endDate.toIso8601String(),
      };

      final items = TimelineService.generateTimeline(sessionId, answers);
      final leasingItem = items.firstWhere((i) => i.id.contains('leasing_end'));

      expect(leasingItem.category, 'debt');
      expect(leasingItem.priority, ReminderPriority.medium);

      final expectedDate = endDate.subtract(const Duration(days: 60));
      expect(leasingItem.date.year, expectedDate.year);
      expect(leasingItem.date.month, expectedDate.month);
      expect(leasingItem.date.day, expectedDate.day);
    });
  });

  group('generateTimeline — consumer credit reminder', () {
    test('creates credit end reminder 30 days before end date', () {
      final endDate = DateTime.now().add(const Duration(days: 180));
      final answers = <String, dynamic>{
        'q_consumer_credit_end_date': endDate.toIso8601String(),
        'q_consumer_credit_monthly': 500,
      };

      final items = TimelineService.generateTimeline(sessionId, answers);
      final creditItem = items.firstWhere((i) => i.id.contains('credit_end'));

      expect(creditItem.category, 'debt');
      expect(creditItem.priority, ReminderPriority.medium);
      expect(creditItem.description, contains('500'));

      final expectedDate = endDate.subtract(const Duration(days: 30));
      expect(creditItem.date.day, expectedDate.day);
    });
  });

  group('generateTimeline — housing purchase reminder', () {
    test('creates housing purchase reminder 12 months before target date', () {
      final targetDate = DateTime.now().add(const Duration(days: 730)); // ~2 years
      final answers = <String, dynamic>{
        'q_mid_housing_purchase_date': targetDate.toIso8601String(),
      };

      final items = TimelineService.generateTimeline(sessionId, answers);
      final housingItem = items.firstWhere((i) => i.id.contains('housing_purchase'));

      expect(housingItem.category, 'housing');
      expect(housingItem.priority, ReminderPriority.high);

      final expectedDate = targetDate.subtract(const Duration(days: 365));
      expect(housingItem.date.year, expectedDate.year);
      expect(housingItem.date.month, expectedDate.month);
    });
  });

  group('generateTimeline — retirement reminder', () {
    test('creates retirement plan reminder 10 years before target age', () {
      final now = DateTime.now();
      final answers = <String, dynamic>{
        'q_birth_year': now.year - 40, // Age 40
        'q_preretire_target_age': 65,
      };

      final items = TimelineService.generateTimeline(sessionId, answers);
      final retirementItem = items.firstWhere(
        (i) => i.id.contains('retirement_plan'),
        orElse: () => throw StateError('No retirement item found'),
      );

      expect(retirementItem.category, 'pension');
      expect(retirementItem.priority, ReminderPriority.high);

      // Retirement year = birthYear + 65 = (now - 40) + 65 = now + 25
      // Reminder year = retirement - 10 = now + 15
      final expectedYear = now.year + 15;
      expect(retirementItem.date.year, expectedYear);
    });

    test('no retirement reminder if reminder date is in the past', () {
      final now = DateTime.now();
      final answers = <String, dynamic>{
        'q_birth_year': now.year - 60, // Age 60
        'q_preretire_target_age': 65,
      };
      // Retirement year = birthYear + 65 = now + 5
      // Reminder year = now + 5 - 10 = now - 5 (in the past)

      final items = TimelineService.generateTimeline(sessionId, answers);
      final retirementItems = items.where((i) => i.id.contains('retirement_plan'));
      expect(retirementItems, isEmpty);
    });
  });

  group('generateTimeline — 3a annual reminder', () {
    test('creates 3a annual reminder for December', () {
      final answers = <String, dynamic>{
        'q_has_3a': true,
      };

      final items = TimelineService.generateTimeline(sessionId, answers);
      final item3a = items.firstWhere((i) => i.id.contains('3a_annual'));

      expect(item3a.category, 'pension');
      expect(item3a.priority, ReminderPriority.medium);
      expect(item3a.date.month, 12);
    });

    test('no 3a reminder when q_has_3a is not true', () {
      final answers = <String, dynamic>{
        'q_has_3a': 'yes', // String, not bool — the code checks == true
      };

      final items = TimelineService.generateTimeline(sessionId, answers);
      final items3a = items.where((i) => i.id.contains('3a_annual'));
      // Since 'yes' != true, no 3a reminder should be generated
      expect(items3a, isEmpty);
    });
  });

  group('generateTimeline — beneficiaries reminder for 50+', () {
    test('creates beneficiaries reminder for users aged 50+', () {
      final now = DateTime.now();
      final answers = <String, dynamic>{
        'q_birth_year': now.year - 55, // Age 55
      };

      final items = TimelineService.generateTimeline(sessionId, answers);
      final benItem = items.firstWhere((i) => i.id.contains('beneficiaries'));

      expect(benItem.category, 'pension');
      expect(benItem.priority, ReminderPriority.medium);
      expect(benItem.date.month, 1);
      expect(benItem.date.year, now.year + 1);
    });

    test('no beneficiaries reminder for users under 50', () {
      final now = DateTime.now();
      final answers = <String, dynamic>{
        'q_birth_year': now.year - 30, // Age 30
      };

      final items = TimelineService.generateTimeline(sessionId, answers);
      final benItems = items.where((i) => i.id.contains('beneficiaries'));
      expect(benItems, isEmpty);
    });

    test('no beneficiaries reminder when birth_year is null', () {
      final answers = <String, dynamic>{};
      final items = TimelineService.generateTimeline(sessionId, answers);
      final benItems = items.where((i) => i.id.contains('beneficiaries'));
      expect(benItems, isEmpty);
    });
  });

  group('generateTimeline — empty answers', () {
    test('returns empty list for empty answers', () {
      final items = TimelineService.generateTimeline(sessionId, {});
      expect(items, isEmpty);
    });
  });

  group('getUpcomingReminders', () {
    test('returns only items within next 90 days that are not completed', () {
      final now = DateTime.now();
      final timeline = [
        TimelineItem(
          id: 'past',
          date: now.subtract(const Duration(days: 10)),
          category: 'debt',
          label: 'Past item',
          description: 'Already past',
          priority: ReminderPriority.medium,
          sourceSessionId: sessionId,
        ),
        TimelineItem(
          id: 'soon',
          date: now.add(const Duration(days: 30)),
          category: 'debt',
          label: 'Soon item',
          description: 'Coming soon',
          priority: ReminderPriority.high,
          sourceSessionId: sessionId,
        ),
        TimelineItem(
          id: 'far',
          date: now.add(const Duration(days: 200)),
          category: 'housing',
          label: 'Far item',
          description: 'Too far',
          priority: ReminderPriority.low,
          sourceSessionId: sessionId,
        ),
        TimelineItem(
          id: 'completed_soon',
          date: now.add(const Duration(days: 20)),
          category: 'pension',
          label: 'Completed',
          description: 'Done',
          priority: ReminderPriority.medium,
          completed: true,
          sourceSessionId: sessionId,
        ),
      ];

      final upcoming = TimelineService.getUpcomingReminders(timeline);
      expect(upcoming.length, 1);
      expect(upcoming[0].id, 'soon');
    });

    test('sorts upcoming reminders by date ascending', () {
      final now = DateTime.now();
      final timeline = [
        TimelineItem(
          id: 'later',
          date: now.add(const Duration(days: 60)),
          category: 'debt',
          label: 'Later',
          description: 'Later',
          priority: ReminderPriority.medium,
          sourceSessionId: sessionId,
        ),
        TimelineItem(
          id: 'sooner',
          date: now.add(const Duration(days: 10)),
          category: 'pension',
          label: 'Sooner',
          description: 'Sooner',
          priority: ReminderPriority.high,
          sourceSessionId: sessionId,
        ),
      ];

      final upcoming = TimelineService.getUpcomingReminders(timeline);
      expect(upcoming.length, 2);
      expect(upcoming[0].id, 'sooner');
      expect(upcoming[1].id, 'later');
    });

    test('returns empty for empty timeline', () {
      expect(TimelineService.getUpcomingReminders([]), isEmpty);
    });
  });

  group('getOverdueReminders', () {
    test('returns only past uncompleted items', () {
      final now = DateTime.now();
      final timeline = [
        TimelineItem(
          id: 'overdue',
          date: now.subtract(const Duration(days: 30)),
          category: 'debt',
          label: 'Overdue',
          description: 'Overdue',
          priority: ReminderPriority.high,
          sourceSessionId: sessionId,
        ),
        TimelineItem(
          id: 'future',
          date: now.add(const Duration(days: 30)),
          category: 'pension',
          label: 'Future',
          description: 'Future',
          priority: ReminderPriority.low,
          sourceSessionId: sessionId,
        ),
        TimelineItem(
          id: 'completed_overdue',
          date: now.subtract(const Duration(days: 10)),
          category: 'debt',
          label: 'Done',
          description: 'Done',
          priority: ReminderPriority.critical,
          completed: true,
          sourceSessionId: sessionId,
        ),
      ];

      final overdue = TimelineService.getOverdueReminders(timeline);
      expect(overdue.length, 1);
      expect(overdue[0].id, 'overdue');
    });

    test('sorts overdue by priority descending', () {
      final now = DateTime.now();
      final timeline = [
        TimelineItem(
          id: 'low_priority',
          date: now.subtract(const Duration(days: 5)),
          category: 'debt',
          label: 'Low',
          description: 'Low',
          priority: ReminderPriority.low,
          sourceSessionId: sessionId,
        ),
        TimelineItem(
          id: 'critical_priority',
          date: now.subtract(const Duration(days: 10)),
          category: 'pension',
          label: 'Critical',
          description: 'Critical',
          priority: ReminderPriority.critical,
          sourceSessionId: sessionId,
        ),
        TimelineItem(
          id: 'medium_priority',
          date: now.subtract(const Duration(days: 2)),
          category: 'housing',
          label: 'Medium',
          description: 'Medium',
          priority: ReminderPriority.medium,
          sourceSessionId: sessionId,
        ),
      ];

      final overdue = TimelineService.getOverdueReminders(timeline);
      expect(overdue.length, 3);
      expect(overdue[0].id, 'critical_priority');
      expect(overdue[1].id, 'medium_priority');
      expect(overdue[2].id, 'low_priority');
    });
  });

  group('getDeltaQuestionIds', () {
    test('returns delta questions for newJob event', () {
      final ids = TimelineService.getDeltaQuestionIds(LifeEventType.newJob);
      expect(ids, isNotEmpty);
      expect(ids, contains('lpp_transfer_needed'));
    });

    test('returns delta questions for birth event', () {
      final ids = TimelineService.getDeltaQuestionIds(LifeEventType.birth);
      expect(ids, isNotEmpty);
      expect(ids, contains('insurance_coverage_review'));
    });

    test('returns delta questions for marriage event', () {
      final ids = TimelineService.getDeltaQuestionIds(LifeEventType.marriage);
      expect(ids, isNotEmpty);
      expect(ids, contains('beneficiaries_update'));
    });

    test('returns delta questions for divorce event', () {
      final ids = TimelineService.getDeltaQuestionIds(LifeEventType.divorce);
      expect(ids, isNotEmpty);
      expect(ids, contains('pension_split'));
    });

    test('returns delta questions for housingPurchase event', () {
      final ids = TimelineService.getDeltaQuestionIds(LifeEventType.housingPurchase);
      expect(ids, isNotEmpty);
      expect(ids, contains('mortgage_amount'));
    });
  });

  group('getEventTimelineItems', () {
    test('generates LPP transfer item for newJob event', () {
      final items = TimelineService.getEventTimelineItems(
        sessionId,
        LifeEventType.newJob,
        {},
      );

      expect(items.length, 1);
      expect(items[0].id, contains('new_job_lpp_transfer'));
      expect(items[0].category, 'pension');
      expect(items[0].priority, ReminderPriority.high);
      expect(items[0].label, contains('Transfert LPP'));
    });

    test('generates insurance review item for birth event', () {
      final items = TimelineService.getEventTimelineItems(
        sessionId,
        LifeEventType.birth,
        {},
      );

      expect(items.length, 1);
      expect(items[0].id, contains('birth_insurance_review'));
      expect(items[0].category, 'insurance');
      expect(items[0].priority, ReminderPriority.critical);
    });

    test('returns empty items for unhandled event type', () {
      final items = TimelineService.getEventTimelineItems(
        sessionId,
        LifeEventType.cantonMove,
        {},
      );

      expect(items, isEmpty);
    });
  });

  group('TimelineItem model', () {
    test('toJson and fromJson round-trip', () {
      final original = TimelineItem(
        id: 'test-item',
        date: DateTime(2026, 6, 15),
        category: 'pension',
        label: 'Test Label',
        description: 'Test Description',
        actionUrl: '/test/url',
        priority: ReminderPriority.high,
        completed: false,
        sourceSessionId: sessionId,
      );

      final json = original.toJson();
      final restored = TimelineItem.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.date, original.date);
      expect(restored.category, original.category);
      expect(restored.label, original.label);
      expect(restored.description, original.description);
      expect(restored.actionUrl, original.actionUrl);
      expect(restored.priority, original.priority);
      expect(restored.completed, original.completed);
      expect(restored.sourceSessionId, original.sourceSessionId);
    });

    test('copyWith creates modified copy', () {
      final original = TimelineItem(
        id: 'test-item',
        date: DateTime(2026, 1, 1),
        category: 'debt',
        label: 'Original',
        description: 'Original desc',
        priority: ReminderPriority.low,
        sourceSessionId: sessionId,
      );

      final modified = original.copyWith(
        completed: true,
        priority: ReminderPriority.critical,
      );

      expect(modified.id, original.id); // unchanged
      expect(modified.completed, true);
      expect(modified.priority, ReminderPriority.critical);
      expect(modified.label, 'Original'); // unchanged
    });
  });
}
