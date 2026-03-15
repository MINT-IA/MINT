/// Service de notifications locales pour le coaching proactif MINT.
///
/// Notifications schedulées localement sur le device.
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

  // ── Notification IDs (ranges to avoid collisions) ────────
  static const _idCheckinMonthly = 1000;
  static const _idStreakProtection = 2000;
  static const _id3aDeadlineBase = 3000;
  static const _idTaxDeadlineBase = 4000;

  // ── Init ──────────────────────────────────────────────────

  /// Init au démarrage de l'app (dans app.dart initState).
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
  /// [s] — localized strings (pass `S.of(context)!` from caller).
  Future<void> scheduleCoachingReminders({
    required CoachProfile profile,
    required S s,
  }) async {
    if (kIsWeb || _plugin == null) return;

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
  }

  /// Monthly check-in reminder (1st of month, 10:00)
  void _scheduleMonthlyCheckin(
    CoachProfile profile,
    tz.TZDateTime now,
    S s,
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
        title: s.notifCheckinTitle,
        body: s.notifCheckinBody,
        scheduledDate: nextFirst,
        payload: '/coach/checkin',
        channelName: s.notifChannelName,
        channelDescription: s.notifChannelDescription,
        matchDateComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  /// 3a deadline reminders: Oct 1, Nov 15, Dec 15, Dec 28
  void _schedule3aDeadlines(
    CoachProfile profile,
    tz.TZDateTime now,
    S s,
  ) {
    // Only schedule if user has 3a contributions
    final has3a = profile.prevoyance.nombre3a > 0 ||
        profile.plannedContributions.any((c) => c.category == '3a');
    if (!has3a) return;

    // Check if 3a is already maxed for the year
    final plafond3a = profile.employmentStatus == 'independant' ? pilier3aPlafondSansLpp : pilier3aPlafondAvecLpp;
    final montant3aAnnuel = profile.total3aMensuel * 12;
    if (montant3aAnnuel >= plafond3a) return;

    final restant = (plafond3a - montant3aAnnuel).toStringAsFixed(0);

    final deadlines = [
      (
        month: 10,
        day: 1,
        body: s.notifDeadline3aBody3months(restant),
      ),
      (
        month: 11,
        day: 15,
        body: s.notifDeadline3aBody46days(restant),
      ),
      (
        month: 12,
        day: 15,
        body: s.notifDeadline3aBody16days,
      ),
      (
        month: 12,
        day: 28,
        body: s.notifDeadline3aBodyFinal,
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
          title: s.notifDeadline3aTitle,
          body: d.body,
          scheduledDate: scheduledDate,
          payload: '/simulator/3a',
          channelName: s.notifChannelName,
          channelDescription: s.notifChannelDescription,
        );
      }
    }
  }

  /// Tax deadline reminders: Feb 15, Mar 15, Mar 25
  void _scheduleTaxDeadlines(tz.TZDateTime now, S s) {
    final deadlines = [
      (
        month: 2,
        day: 15,
        body: s.notifTaxBody44daysShort,
      ),
      (
        month: 3,
        day: 15,
        body: s.notifTaxBody16daysShort,
      ),
      (
        month: 3,
        day: 25,
        body: s.notifTaxBodyLastWeekShort,
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

      if (scheduledDate.isAfter(now)) {
        _scheduleNotification(
          id: _idTaxDeadlineBase + i,
          title: s.notifTaxTitle,
          body: d.body,
          scheduledDate: scheduledDate,
          payload: '/home',
          channelName: s.notifChannelName,
          channelDescription: s.notifChannelDescription,
        );
      }
    }
  }

  /// Streak protection: 25th of each month if no check-in this month
  void _scheduleStreakProtection(
    CoachProfile profile,
    tz.TZDateTime now,
    S s,
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
        title: s.notifStreakTitle,
        body: s.notifStreakBody(streak),
        scheduledDate: scheduledDate,
        payload: '/coach/checkin',
        channelName: s.notifChannelName,
        channelDescription: s.notifChannelDescription,
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
    required String channelName,
    required String channelDescription,
    DateTimeComponents? matchDateComponents,
  }) async {
    if (_plugin == null) return;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      channelName,
      channelDescription: channelDescription,
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
