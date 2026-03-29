/// Notification Scheduler Service — Sprint S36.
///
/// Generates scheduled notifications with personal numbers,
/// time references, and deeplinks. Three tiers:
///   Tier 1: Calendar-driven (scheduled at app launch)
///   Tier 2: Event-driven (triggered on app resume)
///   Tier 3: BYOK-enriched (LLM text via CoachNarrativeService)
///
/// Rules:
/// - Every notification contains a personal number (CHF or %)
/// - Every notification contains a time reference
/// - Every notification has a deeplink
/// - No generic encouragement
/// - No social comparison
/// - No prescriptive language
/// - All French, informal "tu"
library;

import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/services/plan_tracking_service.dart';

// ────────────────────────────────────────────────────────────
//  NOTIFICATION SCHEDULER SERVICE — S36 / Notifications + Milestones
// ────────────────────────────────────────────────────────────
//
// Service purement deterministe : genere des objets ScheduledNotification
// a partir des donnees du profil. Aucune dependance LLM (Tier 1 & 2).
//
// Tier 1 : Calendar-driven (deadlines 3a, declarations fiscales, check-in)
// Tier 2 : Event-driven (FRI delta, profile update, check-in complete)
// Tier 3 : BYOK-enriched (delegue au CoachNarrativeService — hors scope ici)
//
// Conventions :
//   - Montants CHF formated avec apostrophe suisse (1'820)
//   - Toujours un chiffre personnel + reference temporelle + deeplink
//   - Ton pedagogique, tutoiement, pas de termes bannis
// ────────────────────────────────────────────────────────────

/// Tier of notification scheduling.
enum NotificationTier {
  /// Tier 1: Calendar-driven, scheduled at app launch.
  calendar,

  /// Tier 2: Event-driven, triggered on app resume.
  event,

  /// Tier 3: BYOK-enriched, LLM text via CoachNarrativeService.
  byok,
}

/// Category of notification.
enum NotificationCategory {
  /// Deadline 3e pilier (31 dec).
  threeADeadline,

  /// Deadline declaration fiscale (31 mars).
  taxDeclaration,

  /// Check-in mensuel disponible.
  monthlyCheckIn,

  /// Score de solidite (FRI) ameliore.
  friImprovement,

  /// Profil mis a jour — nouvelles projections.
  profileUpdate,

  /// Plan vs realite: trajectory drift detected.
  offTrack,

  /// Nouveaux plafonds de l'annee.
  newYearPlafonds,
}

/// A scheduled notification with personal data, time reference, and deeplink.
class ScheduledNotification {
  /// Category of the notification.
  final NotificationCategory category;

  /// Tier of notification scheduling.
  final NotificationTier tier;

  /// Short title (displayed as notification title).
  final String title;

  /// Body text with personal number and time reference.
  final String body;

  /// Deeplink route for GoRouter navigation on tap.
  final String deeplink;

  /// When this notification should be shown.
  final DateTime scheduledDate;

  /// Personal number embedded in the body (e.g. "1'820 CHF").
  final String personalNumber;

  /// Time reference embedded in the body (e.g. "92 jours").
  final String timeReference;

  const ScheduledNotification({
    required this.category,
    required this.tier,
    required this.title,
    required this.body,
    required this.deeplink,
    required this.scheduledDate,
    required this.personalNumber,
    required this.timeReference,
  });
}

/// Pure, deterministic notification generator — no device scheduling.
///
/// Generates [ScheduledNotification] objects that can be consumed by
/// [NotificationService] for actual device-level scheduling.
class NotificationSchedulerService {
  NotificationSchedulerService._();

  // ── Tier 1: Calendar-driven notifications ──────────────────

  /// Generate Tier 1 calendar notifications for the year.
  ///
  /// [taxSaving3a] — estimated annual tax saving from 3a contributions (CHF).
  /// [today] — override for testing (defaults to DateTime.now()).
  /// [l] — localizations instance; when provided all user-facing strings are
  ///        i18n'd. When null (unit tests without BuildContext) falls back to
  ///        hardcoded French strings.
  ///
  /// Returns a list of [ScheduledNotification] for:
  ///   - Oct 1: 92 days remaining for 3a
  ///   - Nov 1: 61 days remaining + saving amount
  ///   - Dec 1: last month + saving amount
  ///   - Dec 20: 11 days, final reminder
  ///   - Jan 5: new year limits
  ///   - Monthly 1st: monthly check-in
  static List<ScheduledNotification> generateCalendarNotifications({
    required double taxSaving3a,
    DateTime? today,
    S? l,
  }) {
    final now = today ?? DateTime.now();
    final year = now.year;
    final savingStr = _formatChf(taxSaving3a);
    final notifications = <ScheduledNotification>[];

    // ── 3a deadline reminders ─────────────────────────────────

    // Oct 1 — 92 days remaining
    final oct1 = DateTime(year, 10, 1, 10, 0);
    if (oct1.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.threeADeadline,
        tier: NotificationTier.calendar,
        title: l?.notifThreeATitle ?? 'Deadline 3a',
        body: l?.notifThreeA92Days ?? 'Il reste 92 jours pour verser sur ton 3a.',
        deeplink: '/pilier-3a',
        scheduledDate: oct1,
        personalNumber: savingStr,
        timeReference: '92 jours',
      ));
    }

    // Nov 1 — 61 days remaining + saving
    final nov1 = DateTime(year, 11, 1, 10, 0);
    if (nov1.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.threeADeadline,
        tier: NotificationTier.calendar,
        title: l?.notifThreeATitle ?? 'Deadline 3a',
        body: l?.notifThreeA61Days(savingStr) ??
            'Il reste 61 jours. Économie estimée : CHF $savingStr.',
        deeplink: '/pilier-3a',
        scheduledDate: nov1,
        personalNumber: 'CHF $savingStr',
        timeReference: '61 jours',
      ));
    }

    // Dec 1 — last month + saving
    final dec1 = DateTime(year, 12, 1, 10, 0);
    if (dec1.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.threeADeadline,
        tier: NotificationTier.calendar,
        title: l?.notifThreeATitle ?? 'Deadline 3a',
        body: l?.notifThreeALastMonth(savingStr) ??
            'Dernier mois pour ton 3a. CHF $savingStr d\'économie en jeu.',
        deeplink: '/pilier-3a',
        scheduledDate: dec1,
        personalNumber: 'CHF $savingStr',
        timeReference: 'Dernier mois',
      ));
    }

    // Dec 20 — 11 days, final reminder
    final dec20 = DateTime(year, 12, 20, 10, 0);
    if (dec20.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.threeADeadline,
        tier: NotificationTier.calendar,
        title: l?.notifThreeATitle ?? 'Deadline 3a',
        body: l?.notifThreeA11Days ?? '11 jours. Dernier rappel 3a.',
        deeplink: '/pilier-3a',
        scheduledDate: dec20,
        personalNumber: savingStr,
        timeReference: '11 jours',
      ));
    }

    // Jan 5 next year — new year limits
    final jan5 = DateTime(year + 1, 1, 5, 10, 0);
    if (jan5.isAfter(now)) {
      final nextYear = '${year + 1}';
      notifications.add(ScheduledNotification(
        category: NotificationCategory.newYearPlafonds,
        tier: NotificationTier.calendar,
        title: l?.notifNewYearTitle(nextYear) ??
            'Nouveaux plafonds ${year + 1}',
        body: l?.notifNewYearBody(nextYear) ??
            'Nouveaux plafonds ${year + 1}. Ton économie potentielle a changé.',
        deeplink: '/pilier-3a',
        scheduledDate: jan5,
        personalNumber: savingStr,
        timeReference: '${year + 1}',
      ));
    }

    // ── Monthly check-in reminders (1st of each remaining month)

    // FIX-060: was month+1, skipping December when now.month=12.
    for (int month = now.month; month <= 12; month++) {
      final first = DateTime(year, month, 1, 10, 0);
      if (first.isAfter(now)) {
        final monthName = _monthName(month);
        notifications.add(ScheduledNotification(
          category: NotificationCategory.monthlyCheckIn,
          tier: NotificationTier.calendar,
          title: l?.notifCheckInTitle ?? 'Check-in mensuel',
          body: l?.notifCheckInBody ?? 'Ton check-in mensuel est disponible.',
          deeplink: '/coach/checkin',
          scheduledDate: first,
          personalNumber: monthName,
          timeReference: '1er $monthName',
        ));
      }
    }

    // Also Jan of next year
    final jan1Next = DateTime(year + 1, 1, 1, 10, 0);
    if (jan1Next.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.monthlyCheckIn,
        tier: NotificationTier.calendar,
        title: l?.notifCheckInTitle ?? 'Check-in mensuel',
        body: l?.notifCheckInBody ?? 'Ton check-in mensuel est disponible.',
        deeplink: '/coach/checkin',
        scheduledDate: jan1Next,
        personalNumber: 'janvier',
        timeReference: '1er janvier',
      ));
    }

    // ── Tax declaration reminders ─────────────────────────────

    // Feb 15 — 44 days before March 31
    final feb15 = DateTime(year, 2, 15, 10, 0);
    if (feb15.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.taxDeclaration,
        tier: NotificationTier.calendar,
        title: l?.notifTaxTitle ?? 'Declaration fiscale',
        body: l?.notifTax44Days ??
            'Déclaration fiscale dans 44 jours. Pense à rassembler tes documents.',
        deeplink: '/home',
        scheduledDate: feb15,
        personalNumber: savingStr,
        timeReference: '44 jours',
      ));
    }

    // Mar 15 — 16 days before March 31
    final mar15 = DateTime(year, 3, 15, 10, 0);
    if (mar15.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.taxDeclaration,
        tier: NotificationTier.calendar,
        title: l?.notifTaxTitle ?? 'Declaration fiscale',
        body: l?.notifTax16Days ??
            'Déclaration fiscale dans 16 jours. Commence à la remplir.',
        deeplink: '/home',
        scheduledDate: mar15,
        personalNumber: savingStr,
        timeReference: '16 jours',
      ));
    }

    // Mar 25 — last week
    final mar25 = DateTime(year, 3, 25, 10, 0);
    if (mar25.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.taxDeclaration,
        tier: NotificationTier.calendar,
        title: l?.notifTaxTitle ?? 'Declaration fiscale',
        body: l?.notifTaxLastWeek ??
            'Déclaration à rendre avant le 31 mars. Dernière semaine.',
        deeplink: '/home',
        scheduledDate: mar25,
        personalNumber: savingStr,
        timeReference: 'Derniere semaine',
      ));
    }

    return notifications;
  }

  // ── Tier 2: Event-driven notifications ─────────────────────

  /// Generate Tier 2 event notifications based on state changes.
  ///
  /// [friDelta] — change in FRI score since last check-in.
  /// [profileUpdated] — whether profile data was recently updated.
  /// [checkInCompleted] — whether a check-in was just completed.
  /// [today] — override for testing (defaults to DateTime.now()).
  /// [l] — localizations instance; when provided all user-facing strings are
  ///        i18n’d. When null (unit tests without BuildContext) falls back to
  ///        hardcoded French strings.
  ///
  /// Returns event-driven notifications (immediate, not calendar-scheduled).
  static List<ScheduledNotification> generateEventNotifications({
    double friDelta = 0,
    bool profileUpdated = false,
    bool checkInCompleted = false,
    PlanStatus? planStatus,
    DateTime? today,
    S? l,
  }) {
    final now = today ?? DateTime.now();
    final notifications = <ScheduledNotification>[];

    // Check-in completed — show FRI delta
    if (checkInCompleted && friDelta != 0) {
      final sign = friDelta > 0 ? "+" : "";
      final deltaStr = sign + friDelta.toStringAsFixed(0);
      notifications.add(ScheduledNotification(
        category: NotificationCategory.friImprovement,
        tier: NotificationTier.event,
        title: l?.notifFriTitle ?? "Score de solidit\u00e9",
        body: l?.notifFriCheckIn(deltaStr) ??
            "Depuis ton dernier check-in\u00a0: $deltaStr points.",
        deeplink: "/retraite",
        scheduledDate: now,
        personalNumber: "$deltaStr points",
        timeReference: "dernier check-in",
      ));
    }

    // Profile updated — new projections available
    if (profileUpdated) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.profileUpdate,
        tier: NotificationTier.event,
        title: l?.notifProfileUpdatedTitle ?? "Profil mis \u00e0 jour",
        body: l?.notifProfileUpdatedBody ??
            "Ton profil a \u00e9t\u00e9 mis \u00e0 jour. Nouvelles projections disponibles.",
        deeplink: "/retraite",
        scheduledDate: now,
        personalNumber: "nouvelles projections",
        timeReference: "maintenant",
      ));
    }

    // FRI improved (without check-in context)
    if (!checkInCompleted && friDelta > 0) {
      final deltaStr = "+${friDelta.toStringAsFixed(0)}";
      final deltaRaw = friDelta.toStringAsFixed(0);
      notifications.add(ScheduledNotification(
        category: NotificationCategory.friImprovement,
        tier: NotificationTier.event,
        title: l?.notifFriTitle ?? "Score de solidit\u00e9",
        body: l?.notifFriImproved(deltaRaw) ??
            "Ta solidit\u00e9 a progress\u00e9 de $deltaRaw points.",
        deeplink: "/retraite",
        scheduledDate: now,
        personalNumber: "$deltaStr points",
        timeReference: "r\u00e9cemment",
      ));
    }

    // Plan-vs-reality drift alert
    if (planStatus != null &&
        planStatus.totalActions > 0 &&
        planStatus.adherenceRate < 0.8) {
      final adherence = (planStatus.adherenceRate * 100).toStringAsFixed(0);
      final impact = _formatChf(planStatus.monthlyGapChf * 12);
      final total = planStatus.totalActions.toString();
      final actionsBehind =
          (planStatus.totalActions - planStatus.completedActions).clamp(0, 999);
      notifications.add(ScheduledNotification(
        category: NotificationCategory.offTrack,
        tier: NotificationTier.event,
        title: l?.notifOffTrackTitle ?? "Tu t’\u00e9loignes de ton plan",
        body: l?.notifOffTrackBody(adherence, total, impact) ??
            "Adh\u00e9rence \u00e0 $adherence% sur $total actions. "
            "Indication lin\u00e9aire (hors rendement/fiscalit\u00e9)\u00a0: ~CHF $impact.",
        deeplink: "/coach/checkin",
        scheduledDate: now,
        personalNumber: "$adherence%",
        timeReference: "$actionsBehind actions en retard",
      ));
    }

    return notifications;
  }

  // ── Formatting helpers ─────────────────────────────────────

  /// Format a CHF amount with Swiss apostrophe as thousands separator.
  ///
  /// Example: 1820.5 → "1'820", 7258.0 → "7'258"
  static String _formatChf(double amount) {
    final intStr = amount.toStringAsFixed(0);
    return intStr.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}\'',
    );
  }

  /// French month name (lowercase).
  static String _monthName(int month) {
    const names = [
      '',
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return names[month.clamp(1, 12)];
  }
}
