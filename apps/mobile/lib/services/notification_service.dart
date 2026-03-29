/// Service de notifications locales pour le coaching proactif MINT.
///
/// Notifications schedulees localement sur le device.
/// Pas de Firebase, pas de backend — tout est local.
/// Respecte le consentement coaching_notifications.
///
/// Sprint Coach AI Layer — T4
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/consent_manager.dart';

// ────────────────────────────────────────────────────────────
//  NOTIFICATION STRINGS — i18n-ready, resolved at call site
// ────────────────────────────────────────────────────────────

/// Holds all user-facing notification strings.
///
/// Since `flutter_local_notifications` has no [BuildContext], strings are
/// resolved at the call site (where context IS available) and passed in.
class NotificationStrings {
  final String channelDescription;
  final String weeklyRecapTitle;
  final String weeklyRecapBody;
  final String checkinTitle;
  final String checkinBody;
  final String deadline3aTitle;
  final String deadline3aBody3Months;
  final String deadline3aBody46Days;
  final String deadline3aBody16Days;
  final String deadline3aBodyLastDays;
  final String taxDeadlineTitle;
  final String taxDeadlineBody44Days;
  final String taxDeadlineBody16Days;
  final String taxDeadlineBodyLastWeek;
  final String streakProtectionTitle;
  final String streakProtectionBody;

  const NotificationStrings({
    required this.channelDescription,
    required this.weeklyRecapTitle,
    required this.weeklyRecapBody,
    required this.checkinTitle,
    required this.checkinBody,
    required this.deadline3aTitle,
    required this.deadline3aBody3Months,
    required this.deadline3aBody46Days,
    required this.deadline3aBody16Days,
    required this.deadline3aBodyLastDays,
    required this.taxDeadlineTitle,
    required this.taxDeadlineBody44Days,
    required this.taxDeadlineBody16Days,
    required this.taxDeadlineBodyLastWeek,
    required this.streakProtectionTitle,
    required this.streakProtectionBody,
  });

  /// Create from [S] (AppLocalizations) at call site where context exists.
  ///
  /// Parameterized strings use `{remaining}` / `{streak}` as sentinel
  /// placeholders — they are `.replaceAll()`'d with real values at
  /// scheduling time.
  factory NotificationStrings.fromL10n(S l) => NotificationStrings(
        channelDescription: l.notifChannelDescription,
        weeklyRecapTitle: l.notifWeeklyRecapTitle,
        weeklyRecapBody: l.notifWeeklyRecapBody,
        checkinTitle: l.notifCheckinTitle,
        checkinBody: l.notifCheckinBody,
        deadline3aTitle: l.notifDeadline3aTitle,
        deadline3aBody3Months: l.notifDeadline3aBody3Months('{remaining}'),
        deadline3aBody46Days: l.notifDeadline3aBody46Days('{remaining}'),
        deadline3aBody16Days: l.notifDeadline3aBody16Days,
        deadline3aBodyLastDays: l.notifDeadline3aBodyLastDays,
        taxDeadlineTitle: l.notifTaxDeadlineTitle,
        taxDeadlineBody44Days: l.notifTaxDeadlineBody44Days,
        taxDeadlineBody16Days: l.notifTaxDeadlineBody16Days,
        taxDeadlineBodyLastWeek: l.notifTaxDeadlineBodyLastWeek,
        streakProtectionTitle: l.notifStreakProtectionTitle,
        streakProtectionBody: l.notifStreakProtectionBody('{streak}'),
      );

  /// French defaults (fallback when no context available).
  static const french = NotificationStrings(
    channelDescription:
        'Rappels de check-in, deadlines 3a, et notifications de coaching',
    weeklyRecapTitle: 'Ton récap de la semaine',
    weeklyRecapBody: 'Budget, progrès, prochaine étape — tout est prêt.',
    checkinTitle: 'Check-in mensuel',
    checkinBody: 'Confirme tes versements du mois en 2 min',
    deadline3aTitle: 'Deadline 3a',
    deadline3aBody3Months:
        'Il reste 3 mois pour verser sur ton 3a (CHF {remaining} de marge)',
    deadline3aBody46Days:
        'Il reste 46 jours pour maximiser ton 3a (CHF {remaining} de marge)',
    deadline3aBody16Days: 'Il reste 16 jours pour verser sur ton 3a',
    deadline3aBodyLastDays:
        'Derniers jours ! Verse sur ton 3a avant le 31 décembre',
    taxDeadlineTitle: 'Déclaration fiscale',
    taxDeadlineBody44Days:
        'Déclaration fiscale dans 44 jours — pense à rassembler tes documents',
    taxDeadlineBody16Days:
        'Déclaration fiscale dans 16 jours — commence à la remplir',
    taxDeadlineBodyLastWeek:
        'Déclaration à rendre avant le 31 mars — dernière semaine !',
    streakProtectionTitle: 'Protège ta série',
    streakProtectionBody:
        'Tu es à {streak} mois consécutifs — ne casse pas ta série !',
  );
}

// ────────────────────────────────────────────────────────────
//  NOTIFICATION SERVICE — Local-only, zero backend
// ────────────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  FlutterLocalNotificationsPlugin? _plugin;
  bool _isInitialized = false;

  /// Android notification channel for coaching reminders
  static const _channelId = 'mint_coaching';
  static const _channelName = 'Coaching MINT';

  // ── Notification IDs (ranges to avoid collisions) ────────
  static const _idCheckinMonthly = 1000;
  static const _idStreakProtection = 2000;
  static const _id3aDeadlineBase = 3000;
  static const _idTaxDeadlineBase = 4000;

  // ── Init ──────────────────────────────────────────────────

  /// Init au demarrage de l'app (dans app.dart initState).
  /// Safe to call on web — no-ops silently.
  Future<void> init() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    // Initialize timezone data for scheduled notifications
    tz.initializeTimeZones();
    // Use Europe/Zurich for Swiss users
    tz.setLocalLocation(tz.getLocation('Europe/Zurich'));

    _plugin = FlutterLocalNotificationsPlugin();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin!.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Check for cold-start notification tap.
    // When the app was killed and the user taps a notification,
    // getNotificationAppLaunchDetails() captures the payload so
    // GoRouter can navigate to the correct route on first frame.
    final launchDetails = await _plugin!.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      pendingRoute = launchDetails!.notificationResponse?.payload;
    }

    _isInitialized = true;
  }

  // ── Permission ────────────────────────────────────────────

  /// Request permission (iOS). Returns true if granted.
  /// Call this when user enables coaching notifications, not at startup.
  Future<bool> requestPermission() async {
    if (kIsWeb || _plugin == null) return false;

    if (Platform.isIOS) {
      final iosPlugin =
          _plugin!.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final result = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return result ?? false;
      }
      return false;
    }

    if (Platform.isAndroid) {
      final androidPlugin =
          _plugin!.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final result = await androidPlugin.requestNotificationsPermission();
        return result ?? false;
      }
      return false;
    }

    return false;
  }

  // ── Scheduling ────────────────────────────────────────────

  /// Schedule coaching reminders based on user profile.
  /// Call this after each check-in and at app startup.
  ///
  /// [strings] — i18n-resolved notification text. Pass
  /// `NotificationStrings.fromL10n(S.of(context)!)` when a [BuildContext] is
  /// available. Falls back to [NotificationStrings.french] otherwise.
  Future<void> scheduleCoachingReminders({
    required CoachProfile profile,
    NotificationStrings? strings,
  }) async {
    if (kIsWeb || _plugin == null) return;

    final s = strings ?? NotificationStrings.french;

    // V5-3 audit fix: check notification consent before scheduling.
    // If user has not consented, skip all notification scheduling.
    final hasConsent = await ConsentManager.isConsentGiven(
      ConsentType.notifications,
    );
    if (!hasConsent) return;

    // Request permission if not already granted (deferred, not at startup).
    // This is the right place because scheduleCoachingReminders is only
    // called after a check-in, not during app init.
    await requestPermission();

    await cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    // 1. Monthly check-in reminder: 1st of each month at 10:00
    //    ONLY if check-in not done for current month
    _scheduleMonthlyCheckin(profile, now, s);

    // 2. 3a deadline reminders: Oct 1, Nov 15, Dec 15, Dec 28
    //    ONLY if user has 3a AND not maxed
    _schedule3aDeadlines(profile, now, s);

    // 3. Tax deadline reminders: Feb 15, Mar 15, Mar 25
    _scheduleTaxDeadlines(now, s);

    // 4. Streak protection: 25th of each month if no check-in this month
    _scheduleStreakProtection(profile, now, s);

    // 5. Weekly recap: Monday 10:00 — "Ton récap de la semaine est prêt"
    _scheduleWeeklyRecap(now, s);
  }

  /// Weekly recap notification: fires every Monday at 10:00.
  void _scheduleWeeklyRecap(tz.TZDateTime now, NotificationStrings s) {
    // Find next Monday
    var nextMonday = now.add(Duration(days: (8 - now.weekday) % 7));
    if (nextMonday.isBefore(now) || nextMonday.isAtSameMomentAs(now)) {
      nextMonday = nextMonday.add(const Duration(days: 7));
    }
    final scheduledDate = tz.TZDateTime(
      tz.local,
      nextMonday.year,
      nextMonday.month,
      nextMonday.day,
      10, // 10:00
    );

    _scheduleNotification(
      id: 500, // Unique ID for weekly recap
      title: s.weeklyRecapTitle,
      body: s.weeklyRecapBody,
      scheduledDate: scheduledDate,
      payload: '/coach/weekly-recap',
      matchDateComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Monthly check-in reminder (1st of month, 10:00)
  void _scheduleMonthlyCheckin(
    CoachProfile profile,
    tz.TZDateTime now,
    NotificationStrings s,
  ) {
    // Check if current month check-in already done
    final hasCurrentMonthCheckin = profile.checkIns.any((ci) =>
        ci.month.year == now.year && ci.month.month == now.month);

    if (hasCurrentMonthCheckin) return;

    // Schedule for 1st of next month at 10:00 (recurring monthly)
    final nextFirst = tz.TZDateTime(
      tz.local,
      now.day >= 1 ? (now.month == 12 ? now.year + 1 : now.year) : now.year,
      now.day >= 1 ? (now.month == 12 ? 1 : now.month + 1) : now.month,
      1,
      10,
      0,
    );

    // Only schedule if in the future
    if (nextFirst.isAfter(now)) {
      _scheduleNotification(
        id: _idCheckinMonthly,
        title: s.checkinTitle,
        body: s.checkinBody,
        scheduledDate: nextFirst,
        payload: '/coach/checkin',
        matchDateComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  /// 3a deadline reminders: Oct 1, Nov 15, Dec 15, Dec 28
  void _schedule3aDeadlines(
    CoachProfile profile,
    tz.TZDateTime now,
    NotificationStrings s,
  ) {
    // Only schedule if user has 3a contributions
    final has3a = profile.prevoyance.nombre3a > 0 ||
        profile.plannedContributions.any((c) => c.category == '3a');
    if (!has3a) return;

    // Check if 3a is already maxed for the year
    final plafond3a = profile.employmentStatus == 'independant' ? reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp) : reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);
    final montant3aAnnuel = profile.total3aMensuel * 12;
    if (montant3aAnnuel >= plafond3a) return;

    final restant = (plafond3a - montant3aAnnuel).toStringAsFixed(0);

    final deadlines = [
      (
        month: 10,
        day: 1,
        body: s.deadline3aBody3Months.replaceAll('{remaining}', restant),
      ),
      (
        month: 11,
        day: 15,
        body: s.deadline3aBody46Days.replaceAll('{remaining}', restant),
      ),
      (
        month: 12,
        day: 15,
        body: s.deadline3aBody16Days,
      ),
      (
        month: 12,
        day: 28,
        body: s.deadline3aBodyLastDays,
      ),
    ];

    for (int i = 0; i < deadlines.length; i++) {
      final d = deadlines[i];
      final year = now.month > d.month ||
              (now.month == d.month && now.day > d.day)
          ? now.year + 1
          : now.year;
      final scheduledDate = tz.TZDateTime(
        tz.local,
        year,
        d.month,
        d.day,
        10,
        0,
      );

      // Don't schedule if already past
      if (scheduledDate.isAfter(now)) {
        _scheduleNotification(
          id: _id3aDeadlineBase + i,
          title: s.deadline3aTitle,
          body: d.body,
          scheduledDate: scheduledDate,
          payload: '/pilier-3a',
        );
      }
    }
  }

  /// Tax deadline reminders: Feb 15, Mar 15, Mar 25
  void _scheduleTaxDeadlines(tz.TZDateTime now, NotificationStrings s) {
    final deadlines = [
      (month: 2, day: 15, body: s.taxDeadlineBody44Days),
      (month: 3, day: 15, body: s.taxDeadlineBody16Days),
      (month: 3, day: 25, body: s.taxDeadlineBodyLastWeek),
    ];

    for (int i = 0; i < deadlines.length; i++) {
      final d = deadlines[i];
      final year = now.month > d.month ||
              (now.month == d.month && now.day > d.day)
          ? now.year + 1
          : now.year;
      final scheduledDate = tz.TZDateTime(
        tz.local,
        year,
        d.month,
        d.day,
        10,
        0,
      );

      if (scheduledDate.isAfter(now)) {
        _scheduleNotification(
          id: _idTaxDeadlineBase + i,
          title: s.taxDeadlineTitle,
          body: d.body,
          scheduledDate: scheduledDate,
          payload: '/home',
        );
      }
    }
  }

  /// Streak protection: 25th of each month if no check-in this month
  void _scheduleStreakProtection(
    CoachProfile profile,
    tz.TZDateTime now,
    NotificationStrings s,
  ) {
    final streak = profile.streak;
    if (streak <= 0) return;

    // Check if current month already has a check-in
    final hasCurrentMonthCheckin = profile.checkIns.any((ci) =>
        ci.month.year == now.year && ci.month.month == now.month);
    if (hasCurrentMonthCheckin) return;

    // Schedule for the 25th of the current or next month
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      25,
      18, // 18:00 — evening reminder
      0,
    );

    if (scheduledDate.isBefore(now)) {
      // If already past the 25th, schedule for next month
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.month == 12 ? now.year + 1 : now.year,
        now.month == 12 ? 1 : now.month + 1,
        25,
        18,
        0,
      );
    }

    if (scheduledDate.isAfter(now)) {
      _scheduleNotification(
        id: _idStreakProtection,
        title: s.streakProtectionTitle,
        body: s.streakProtectionBody.replaceAll('{streak}', '$streak'),
        scheduledDate: scheduledDate,
        payload: '/coach/checkin',
      );
    }
  }

  // ── Core scheduling helper ────────────────────────────────

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
    DateTimeComponents? matchDateComponents,
  }) async {
    if (_plugin == null) return;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: NotificationStrings.french.channelDescription,
      importance: Importance.high,
      priority: Priority.defaultPriority,
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin!.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateComponents,
      payload: payload,
    );
  }

  // ── Cancel ────────────────────────────────────────────────

  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    if (_plugin == null) return;
    await _plugin!.cancelAll();
  }

  // ── Deep link handler ─────────────────────────────────────

  /// Handle notification tap — extract route from payload.
  /// Store the route in a static field that GoRouter can read on next frame.
  void _onNotificationTap(NotificationResponse response) {
    pendingRoute = response.payload;
  }

  /// Route to navigate to after notification tap (consumed once)
  static String? pendingRoute;

  /// Consume the pending route (returns it and clears it).
  /// Called by MainNavigationShell on resume to handle deep links.
  static String? consumePendingRoute() {
    final route = pendingRoute;
    pendingRoute = null;
    return route;
  }
}
