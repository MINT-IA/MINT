import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/reengagement_engine.dart';
import 'package:mint_mobile/services/notification_scheduler_service.dart';
import 'package:mint_mobile/services/plan_tracking_service.dart';

/// Temporal priority service (P3).
///
/// Merges reengagement messages and scheduled notifications into a single
/// priority-sorted list for the TemporalStrip widget.
///
/// Sort order: deadline proximity (ascending) → urgency level.
class TemporalPriorityService {
  TemporalPriorityService._();

  /// Generate prioritized temporal items from all sources.
  ///
  /// Merges [ReengagementEngine] (calendar-driven) and
  /// [NotificationSchedulerService] (event-driven) into a single list,
  /// deduplicated by category and sorted by deadline proximity.
  static List<TemporalItem> prioritize({
    required S s,
    DateTime? today,
    String canton = 'ZH',
    double taxSaving3a = 0,
    double friTotal = 0,
    double friDelta = 0,
    bool profileUpdated = false,
    bool checkInCompleted = false,
    PlanStatus? planStatus,
    int limit = 5,
  }) {
    final now = today ?? DateTime.now();
    final items = <TemporalItem>[];
    final seenCategories = <String>{};

    // Source 1: ReengagementEngine (calendar-driven)
    final reengagementMessages = ReengagementEngine.generateMessages(
      today: now,
      canton: canton,
      taxSaving3a: taxSaving3a,
      friTotal: friTotal,
      friDelta: friDelta,
    );

    for (final msg in reengagementMessages) {
      final category = _normalizeTriggerCategory(msg.trigger.name);
      if (seenCategories.contains(category)) continue;
      seenCategories.add(category);

      items.add(TemporalItem(
        title: msg.title,
        body: msg.body,
        deeplink: msg.deeplink,
        personalNumber: msg.personalNumber,
        timeConstraint: msg.timeConstraint,
        urgency: _urgencyFromTrigger(msg.trigger),
        daysUntil: _daysUntilFromTrigger(msg.trigger, now),
        source: TemporalSource.reengagement,
      ));
    }

    // Source 2: NotificationSchedulerService — event-driven
    final eventNotifications =
        NotificationSchedulerService.generateEventNotifications(
      s: s,
      friDelta: friDelta,
      profileUpdated: profileUpdated,
      checkInCompleted: checkInCompleted,
      planStatus: planStatus,
      today: now,
    );

    for (final notif in eventNotifications) {
      final category = _normalizeNotifCategory(notif.category.name);
      if (seenCategories.contains(category)) continue;
      seenCategories.add(category);

      items.add(TemporalItem(
        title: notif.title,
        body: notif.body,
        deeplink: notif.deeplink,
        personalNumber: notif.personalNumber,
        timeConstraint: notif.timeReference,
        urgency: _urgencyFromNotifCategory(notif.category),
        daysUntil: notif.scheduledDate.difference(now).inDays,
        source: TemporalSource.notification,
      ));
    }

    // Sort by urgency (high first), then by days until (ascending)
    items.sort((a, b) {
      final urgencyCompare = a.urgency.index.compareTo(b.urgency.index);
      if (urgencyCompare != 0) return urgencyCompare;
      return a.daysUntil.compareTo(b.daysUntil);
    });

    return items.take(limit).toList();
  }

  static TemporalUrgency _urgencyFromTrigger(ReengagementTrigger trigger) {
    switch (trigger) {
      case ReengagementTrigger.threeAFinal:
        return TemporalUrgency.critical;
      case ReengagementTrigger.threeAUrgency:
      case ReengagementTrigger.taxDeadline:
        return TemporalUrgency.high;
      case ReengagementTrigger.threeACountdown:
      case ReengagementTrigger.taxPrep:
        return TemporalUrgency.medium;
      case ReengagementTrigger.newYear:
      case ReengagementTrigger.quarterlyFri:
        return TemporalUrgency.low;
    }
  }

  static int _daysUntilFromTrigger(ReengagementTrigger trigger, DateTime now) {
    switch (trigger) {
      case ReengagementTrigger.threeACountdown:
      case ReengagementTrigger.threeAUrgency:
      case ReengagementTrigger.threeAFinal:
        var endOfYear = DateTime(now.year, 12, 31);
        if (endOfYear.isBefore(now)) {
          endOfYear = DateTime(now.year + 1, 12, 31);
        }
        return endOfYear.difference(now).inDays;
      case ReengagementTrigger.taxDeadline:
        var deadline = DateTime(now.year, 3, 31);
        if (deadline.isBefore(now)) {
          deadline = DateTime(now.year + 1, 3, 31);
        }
        return deadline.difference(now).inDays;
      case ReengagementTrigger.taxPrep:
        var deadline = DateTime(now.year, 3, 31);
        if (deadline.isBefore(now)) {
          deadline = DateTime(now.year + 1, 3, 31);
        }
        return deadline.difference(now).inDays;
      case ReengagementTrigger.newYear:
      case ReengagementTrigger.quarterlyFri:
        return 90; // Approximate next quarter
    }
  }

  /// Normalize reengagement trigger names for cross-source dedup.
  ///
  /// All 3a-related triggers (threeACountdown, threeAUrgency, threeAFinal)
  /// map to 'threeA' so they don't duplicate with NotificationScheduler's
  /// threeADeadline category.
  static String _normalizeTriggerCategory(String triggerName) {
    const threeATriggers = {
      'threeACountdown',
      'threeAUrgency',
      'threeAFinal',
    };
    if (threeATriggers.contains(triggerName)) return 'threeA';

    const taxTriggers = {'taxDeadline', 'taxPrep'};
    if (taxTriggers.contains(triggerName)) return 'tax';

    return triggerName;
  }

  /// Normalize notification category names for cross-source dedup.
  static String _normalizeNotifCategory(String categoryName) {
    if (categoryName == 'threeADeadline') return 'threeA';
    if (categoryName == 'taxDeclaration') return 'tax';
    return categoryName;
  }

  static TemporalUrgency _urgencyFromNotifCategory(
      NotificationCategory category) {
    switch (category) {
      case NotificationCategory.threeADeadline:
        return TemporalUrgency.high;
      case NotificationCategory.taxDeclaration:
        return TemporalUrgency.medium;
      case NotificationCategory.monthlyCheckIn:
        return TemporalUrgency.low;
      case NotificationCategory.friImprovement:
        return TemporalUrgency.low;
      case NotificationCategory.profileUpdate:
        return TemporalUrgency.low;
      case NotificationCategory.newYearPlafonds:
        return TemporalUrgency.low;
      case NotificationCategory.offTrack:
        return TemporalUrgency.high;
    }
  }
}

/// Urgency level for temporal items.
enum TemporalUrgency {
  /// Red — imminent deadline (< 30 days).
  critical,

  /// Orange — approaching deadline (30-60 days).
  high,

  /// Yellow — upcoming (60-90 days).
  medium,

  /// Blue — informational.
  low,
}

/// Source of the temporal item.
enum TemporalSource {
  reengagement,
  notification,
}

/// A prioritized temporal item for display in the TemporalStrip.
class TemporalItem {
  final String title;
  final String body;
  final String deeplink;
  final String personalNumber;
  final String timeConstraint;
  final TemporalUrgency urgency;
  final int daysUntil;
  final TemporalSource source;

  const TemporalItem({
    required this.title,
    required this.body,
    required this.deeplink,
    required this.personalNumber,
    required this.timeConstraint,
    required this.urgency,
    required this.daysUntil,
    required this.source,
  });
}
