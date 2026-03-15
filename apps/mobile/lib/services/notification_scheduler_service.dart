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

import 'package:mint_mobile/services/plan_tracking_service.dart';

// ────────────────────────────────────────────────────────────
//  NOTIFICATION SCHEDULER SERVICE — S36 / Notifications + Milestones
// ────────────────────────────────────────────────────────────
//
// Service purement déterministe : génère des objets ScheduledNotification
// à partir des données du profil. Aucune dépendance LLM (Tier 1 & 2).
//
// Tier 1 : Calendar-driven (deadlines 3a, déclarations fiscales, check-in)
// Tier 2 : Event-driven (FRI delta, profile update, check-in complete)
// Tier 3 : BYOK-enriched (delegue au CoachNarrativeService — hors scope ici)
//
// Conventions :
//   - Montants CHF formated avec apostrophe suisse (1'820)
//   - Toujours un chiffre personnel + reference temporelle + deeplink
//   - Ton pédagogique, tutoiement, pas de termes bannis
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

  /// Deadline déclaration fiscale (31 mars).
  taxDeclaration,

  /// Check-in mensuel disponible.
  monthlyCheckIn,

  /// Score de solidité (FRI) amélioré.
  friImprovement,

  /// Profil mis à jour — nouvelles projections.
  profileUpdate,

  /// Plan vs realite: trajectory drift detected.
  offTrack,

  /// Nouveaux plafonds de l'année.
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
  ///
  /// Returns a list of [ScheduledNotification] for:
  ///   - Oct 1: 92 jours remaining for 3a
  ///   - Nov 1: 61 jours remaining + saving amount
  ///   - Dec 1: dernier mois + saving amount
  ///   - Dec 20: 11 jours, dernier rappel
  ///   - Jan 5: nouveaux plafonds
  ///   - Monthly 1st: check-in mensuel
  static List<ScheduledNotification> generateCalendarNotifications({
    required double taxSaving3a,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final year = now.year;
    final savingStr = _formatChf(taxSaving3a);
    final notifications = <ScheduledNotification>[];

    // ── 3a deadline reminders ─────────────────────────────────

    // Oct 1 — 92 jours restants
    final oct1 = DateTime(year, 10, 1, 10, 0);
    if (oct1.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.threeADeadline,
        tier: NotificationTier.calendar,
        title: 'Deadline 3a',
        body: 'Il reste 92 jours pour verser sur ton 3a.',
        deeplink: '/simulator/3a',
        scheduledDate: oct1,
        personalNumber: savingStr,
        timeReference: '92 jours',
      ));
    }

    // Nov 1 — 61 jours restants + saving
    final nov1 = DateTime(year, 11, 1, 10, 0);
    if (nov1.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.threeADeadline,
        tier: NotificationTier.calendar,
        title: 'Deadline 3a',
        body: 'Il reste 61 jours. Économie estimée : CHF $savingStr.',
        deeplink: '/simulator/3a',
        scheduledDate: nov1,
        personalNumber: 'CHF $savingStr',
        timeReference: '61 jours',
      ));
    }

    // Dec 1 — dernier mois + saving
    final dec1 = DateTime(year, 12, 1, 10, 0);
    if (dec1.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.threeADeadline,
        tier: NotificationTier.calendar,
        title: 'Deadline 3a',
        body: 'Dernier mois pour ton 3a. CHF $savingStr d\'économie en jeu.',
        deeplink: '/simulator/3a',
        scheduledDate: dec1,
        personalNumber: 'CHF $savingStr',
        timeReference: 'Dernier mois',
      ));
    }

    // Dec 20 — 11 jours, dernier rappel
    final dec20 = DateTime(year, 12, 20, 10, 0);
    if (dec20.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.threeADeadline,
        tier: NotificationTier.calendar,
        title: 'Deadline 3a',
        body: '11 jours. Dernier rappel 3a.',
        deeplink: '/simulator/3a',
        scheduledDate: dec20,
        personalNumber: savingStr,
        timeReference: '11 jours',
      ));
    }

    // Jan 5 next year — nouveaux plafonds
    final jan5 = DateTime(year + 1, 1, 5, 10, 0);
    if (jan5.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.newYearPlafonds,
        tier: NotificationTier.calendar,
        title: 'Nouveaux plafonds ${year + 1}',
        body:
            'Nouveaux plafonds ${year + 1}. Ton économie potentielle a changé.',
        deeplink: '/simulator/3a',
        scheduledDate: jan5,
        personalNumber: savingStr,
        timeReference: '${year + 1}',
      ));
    }

    // ── Monthly check-in reminders (1st of each remaining month)

    for (int month = now.month + 1; month <= 12; month++) {
      final first = DateTime(year, month, 1, 10, 0);
      if (first.isAfter(now)) {
        final monthName = _monthName(month);
        notifications.add(ScheduledNotification(
          category: NotificationCategory.monthlyCheckIn,
          tier: NotificationTier.calendar,
          title: 'Check-in mensuel',
          body: 'Ton check-in mensuel est disponible.',
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
        title: 'Check-in mensuel',
        body: 'Ton check-in mensuel est disponible.',
        deeplink: '/coach/checkin',
        scheduledDate: jan1Next,
        personalNumber: 'janvier',
        timeReference: '1er janvier',
      ));
    }

    // ── Tax declaration reminders ─────────────────────────────

    // Feb 15 — 44 jours avant le 31 mars
    final feb15 = DateTime(year, 2, 15, 10, 0);
    if (feb15.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.taxDeclaration,
        tier: NotificationTier.calendar,
        title: 'Déclaration fiscale',
        body:
            'Déclaration fiscale dans 44 jours. Pense à rassembler tes documents.',
        deeplink: '/home',
        scheduledDate: feb15,
        personalNumber: savingStr,
        timeReference: '44 jours',
      ));
    }

    // Mar 15 — 16 jours avant le 31 mars
    final mar15 = DateTime(year, 3, 15, 10, 0);
    if (mar15.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.taxDeclaration,
        tier: NotificationTier.calendar,
        title: 'Déclaration fiscale',
        body: 'Déclaration fiscale dans 16 jours. Commence à la remplir.',
        deeplink: '/home',
        scheduledDate: mar15,
        personalNumber: savingStr,
        timeReference: '16 jours',
      ));
    }

    // Mar 25 — dernière semaine
    final mar25 = DateTime(year, 3, 25, 10, 0);
    if (mar25.isAfter(now)) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.taxDeclaration,
        tier: NotificationTier.calendar,
        title: 'Déclaration fiscale',
        body: 'Déclaration à rendre avant le 31 mars. Dernière semaine.',
        deeplink: '/home',
        scheduledDate: mar25,
        personalNumber: savingStr,
        timeReference: 'Dernière semaine',
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
  ///
  /// Returns event-driven notifications (immediate, not calendar-scheduled).
  static List<ScheduledNotification> generateEventNotifications({
    double friDelta = 0,
    bool profileUpdated = false,
    bool checkInCompleted = false,
    PlanStatus? planStatus,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final notifications = <ScheduledNotification>[];

    // Check-in completed — show FRI delta
    if (checkInCompleted && friDelta != 0) {
      final sign = friDelta > 0 ? '+' : '';
      final deltaStr = '$sign${friDelta.toStringAsFixed(0)}';
      notifications.add(ScheduledNotification(
        category: NotificationCategory.friImprovement,
        tier: NotificationTier.event,
        title: 'Score de solidité',
        body: 'Depuis ton dernier check-in : $deltaStr points.',
        deeplink: '/coach/dashboard',
        scheduledDate: now,
        personalNumber: '$deltaStr points',
        timeReference: 'dernier check-in',
      ));
    }

    // Profile updated — new projections available
    if (profileUpdated) {
      notifications.add(ScheduledNotification(
        category: NotificationCategory.profileUpdate,
        tier: NotificationTier.event,
        title: 'Profil mis à jour',
        body: 'Ton profil a été mis à jour. Nouvelles projections disponibles.',
        deeplink: '/coach/dashboard',
        scheduledDate: now,
        personalNumber: 'nouvelles projections',
        timeReference: 'maintenant',
      ));
    }

    // FRI improved (without check-in context)
    if (!checkInCompleted && friDelta > 0) {
      final deltaStr = '+${friDelta.toStringAsFixed(0)}';
      notifications.add(ScheduledNotification(
        category: NotificationCategory.friImprovement,
        tier: NotificationTier.event,
        title: 'Score de solidité',
        body:
            'Ta solidité a progressé de ${friDelta.toStringAsFixed(0)} points.',
        deeplink: '/coach/dashboard',
        scheduledDate: now,
        personalNumber: '$deltaStr points',
        timeReference: 'récemment',
      ));
    }

    // Plan-vs-reality drift alert
    if (planStatus != null &&
        planStatus.totalActions > 0 &&
        planStatus.adherenceRate < 0.8) {
      final adherence = (planStatus.adherenceRate * 100).toStringAsFixed(0);
      final impact = _formatChf(planStatus.monthlyGapChf * 12);
      final actionsBehind =
          (planStatus.totalActions - planStatus.completedActions).clamp(0, 999);
      notifications.add(ScheduledNotification(
        category: NotificationCategory.offTrack,
        tier: NotificationTier.event,
        title: 'Tu t\'éloignes de ton plan',
        body: 'Adhérence à $adherence% sur ${planStatus.totalActions} actions. '
            'Indication linéaire (hors rendement/fiscalité)\u00a0: ~CHF $impact.',
        deeplink: '/coach/checkin',
        scheduledDate: now,
        personalNumber: '$adherence%',
        timeReference: '$actionsBehind actions en retard',
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
