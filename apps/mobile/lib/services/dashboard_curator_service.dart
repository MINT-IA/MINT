import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/reengagement_engine.dart';

/// Dashboard content curation service (P3).
///
/// Selects and prioritizes the cards shown on the retirement dashboard.
/// Max 3-4 cards, sorted by: urgency > impact CHF > deadline proximity.
///
/// Extracts urgency/deadline logic from legacy dashboard monolith (archived) monolith
/// into a reusable, testable service.
class DashboardCuratorService {
  DashboardCuratorService._();

  /// Maximum cards shown on dashboard at once.
  static const int maxCards = 4;

  /// Days threshold for urgent deadline.
  static const int _urgentDeadlineDays = 30;

  // ── Alert urgency ──────────────────────────────────────────

  /// Compute urgency level for a coaching tip.
  ///
  /// Returns [AlertUrgency.urgent] if high priority AND deadline <= 30 days.
  /// Extracted from legacy dashboard monolith (archived) L2824-2835.
  static AlertUrgency computeAlertUrgency(CoachingTip? tip) {
    if (tip == null) return AlertUrgency.info;
    if (tip.priority != CoachingPriority.haute) return AlertUrgency.info;

    final days = getDeadlineDaysForTip(tip);
    if (days != null && days <= _urgentDeadlineDays) {
      return AlertUrgency.urgent;
    }
    return AlertUrgency.active;
  }

  /// Format deadline countdown text for a coaching tip.
  ///
  /// Returns "Aujourd'hui", "Demain", or "J-{days}".
  /// Extracted from legacy dashboard monolith (archived) L2837-2844.
  static String? computeDeadlineText(CoachingTip? tip) {
    if (tip == null) return null;
    final days = getDeadlineDaysForTip(tip);
    if (days == null || days < 0) return null;
    if (days == 0) return "Aujourd'hui";
    if (days == 1) return 'Demain';
    return 'J-$days';
  }

  /// Get days until deadline for a specific tip.
  ///
  /// Switch on tip.id for known deadlines:
  /// - 'deadline_3a' → Dec 31
  /// - 'tax_deadline' → Mar 31
  ///
  /// Extracted from legacy dashboard monolith (archived) L2846-2862.
  static int? getDeadlineDaysForTip(CoachingTip tip, {DateTime? today}) {
    final now = today ?? DateTime.now();

    switch (tip.id) {
      case 'deadline_3a':
      case 'missing_3a':
      case '3a_not_maxed':
        // Dec 31 of current year (or next year if past Dec 31)
        var deadline3a = DateTime(now.year, 12, 31);
        if (deadline3a.isBefore(now)) {
          deadline3a = DateTime(now.year + 1, 12, 31);
        }
        return deadline3a.difference(now).inDays;

      case 'tax_deadline':
        // Mar 31 of current or next year
        var deadline = DateTime(now.year, 3, 31);
        if (deadline.isBefore(now)) {
          deadline = DateTime(now.year + 1, 3, 31);
        }
        return deadline.difference(now).inDays;

      case 'lpp_buyback':
        // Dec 31 for tax deduction (year-wrapped)
        var deadlineLpp = DateTime(now.year, 12, 31);
        if (deadlineLpp.isBefore(now)) {
          deadlineLpp = DateTime(now.year + 1, 12, 31);
        }
        return deadlineLpp.difference(now).inDays;

      default:
        return null;
    }
  }

  // ── Card curation ──────────────────────────────────────────

  /// Select and rank the top cards for the dashboard.
  ///
  /// Combines coaching tips and reengagement messages, ranks by:
  /// 1. Urgency (urgent > active > info)
  /// 2. Estimated CHF impact (descending)
  /// 3. Deadline proximity (ascending)
  ///
  /// Returns max [maxCards] items.
  static List<CuratedCard> curate({
    required List<CoachingTip> tips,
    List<ReengagementMessage> reengagementMessages = const [],
    int limit = maxCards,
  }) {
    final cards = <CuratedCard>[];

    // Add coaching tip cards
    for (final tip in tips) {
      final urgency = computeAlertUrgency(tip);
      final deadlineDays = getDeadlineDaysForTip(tip);
      cards.add(CuratedCard(
        type: CuratedCardType.coachingTip,
        title: tip.title,
        message: tip.narrativeMessage ?? tip.message,
        urgency: urgency,
        deadlineDays: deadlineDays,
        impactChf: tip.estimatedImpactChf,
        deeplink: _deeplinkForTip(tip.id),
        source: tip,
      ));
    }

    // Detect if coaching tips already cover fiscal deadline
    final hasTaxTip = tips.any((t) => t.id == 'tax_deadline');

    // Add reengagement message cards (skip fiscal if already in tips)
    for (final msg in reengagementMessages) {
      if (hasTaxTip &&
          (msg.trigger == ReengagementTrigger.taxPrep ||
              msg.trigger == ReengagementTrigger.taxDeadline)) {
        continue;
      }
      cards.add(CuratedCard(
        type: CuratedCardType.reengagement,
        title: msg.title,
        message: msg.body,
        urgency: AlertUrgency.active,
        deadlineDays: null,
        impactChf: null,
        deeplink: msg.deeplink,
        source: msg,
      ));
    }

    // Sort: urgent first, then by impact (desc), then by deadline (asc)
    cards.sort((a, b) {
      final urgencyCompare = a.urgency.index.compareTo(b.urgency.index);
      if (urgencyCompare != 0) return urgencyCompare;

      // Higher impact first
      final impactA = a.impactChf ?? 0;
      final impactB = b.impactChf ?? 0;
      if (impactA != impactB) return impactB.compareTo(impactA);

      // Closer deadline first
      final deadlineA = a.deadlineDays ?? 999;
      final deadlineB = b.deadlineDays ?? 999;
      return deadlineA.compareTo(deadlineB);
    });

    return cards.take(limit).toList();
  }

  /// Map coaching tip IDs to actionable deeplinks.
  ///
  /// Returns null if no natural navigation target exists for the tip.
  static String? _deeplinkForTip(String tipId) {
    switch (tipId) {
      case 'deadline_3a':
      case 'missing_3a':
      case '3a_not_maxed':
        return '/simulator/3a';
      case 'lpp_buyback':
        return '/arbitrage/rachat-vs-marche';
      case 'tax_deadline':
        return '/tools';
      case 'retirement_countdown':
        return '/coach/dashboard';
      case 'emergency_fund':
        return '/budget';
      default:
        return null;
    }
  }
}

/// Urgency level for a dashboard alert.
enum AlertUrgency {
  /// Red — deadline within 30 days + high priority.
  urgent,

  /// Orange — high priority but no imminent deadline.
  active,

  /// Blue — informational.
  info,
}

/// Type of curated card.
enum CuratedCardType {
  coachingTip,
  reengagement,
}

/// A curated card ready for display on the dashboard.
class CuratedCard {
  final CuratedCardType type;
  final String title;
  final String message;
  final AlertUrgency urgency;
  final int? deadlineDays;
  final double? impactChf;
  final String? deeplink;

  /// Original source object (CoachingTip or ReengagementMessage).
  final Object source;

  const CuratedCard({
    required this.type,
    required this.title,
    required this.message,
    required this.urgency,
    required this.deadlineDays,
    required this.impactChf,
    required this.deeplink,
    required this.source,
  });
}
