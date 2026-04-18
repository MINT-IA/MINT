import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/notification_service.dart';

/// Listens to CoachProfileProvider changes and re-schedules coaching
/// reminders when the user's notification-relevant triad (birthYear +
/// canton + salaireBrutMensuel) transitions from incomplete to
/// complete, or when a previously-scheduled triad's signature changes.
///
/// Wave A-MINIMAL A2 (2026-04-18). Panel adversaire BUG 2+3 flagged
/// that the prior wiring (`coach_chat_screen.dart _markOnboardingCompletedIfNeeded`)
/// fires exactly once at onboarding intent; a user who completes the
/// triad via conversational `save_fact` (canton last, several minutes
/// later) would NEVER have their notifications scheduled because
/// `CoachProfileProvider.notifyListeners()` is not a lifecycle
/// `didChangeAppLifecycleState.resumed`.
///
/// This service bridges the gap: plug it into a
/// `ChangeNotifierProxyProvider<CoachProfileProvider, NotificationsWiringService>`
/// in the widget tree and it observes each profile update, debounces
/// 500ms so bursts of `save_fact` collapse into one reschedule, and
/// calls [NotificationService.scheduleCoachingReminders] when the
/// triad signature actually changes.
class NotificationsWiringService extends ChangeNotifier {
  NotificationsWiringService({
    Future<void> Function(CoachProfile)? scheduleOverride,
  }) : _schedule = scheduleOverride ??
            ((profile) =>
                NotificationService().scheduleCoachingReminders(profile: profile));

  final Future<void> Function(CoachProfile) _schedule;
  Timer? _debouncer;

  /// Signature of the last triad we scheduled for. Starts empty — the
  /// first "complete" profile we observe always schedules. Subsequent
  /// notifications fire only when any of the three fields change.
  String? _lastScheduledSignature;

  /// Exposed for tests — overridable clock + sync path avoidance.
  @visibleForTesting
  static Duration debounce = const Duration(milliseconds: 500);

  /// Call this on every CoachProfileProvider.notifyListeners. Safe to
  /// call with a null profile (= provider not yet loaded).
  void onProfileChanged(CoachProfile? profile) {
    _debouncer?.cancel();
    if (profile == null) return;
    _debouncer = Timer(debounce, () => _maybeSchedule(profile));
  }

  Future<void> _maybeSchedule(CoachProfile profile) async {
    if (!_hasTriad(profile)) {
      // Profile still incomplete — clear the signature so that the
      // next complete profile we observe does schedule even if the
      // birthYear/canton/salary values match a previous completed
      // profile that was invalidated by a logout/reset.
      _lastScheduledSignature = null;
      return;
    }
    final signature = _triadSignature(profile);
    if (signature == _lastScheduledSignature) {
      // Triad unchanged since the last schedule — nothing to do.
      return;
    }
    try {
      await _schedule(profile);
      _lastScheduledSignature = signature;
      debugPrint('[NotificationsWiring] scheduled triad=$signature');
    } catch (e, st) {
      debugPrint('[NotificationsWiring] scheduleCoachingReminders threw: $e\n$st');
    }
  }

  bool _hasTriad(CoachProfile p) {
    return p.birthYear >= 1900 &&
        p.canton.isNotEmpty &&
        p.salaireBrutMensuel > 0;
  }

  /// Deterministic signature of the triad — any change invalidates.
  /// Uses the salary bucket (rounded to nearest 100 CHF) so every
  /// keystroke during a manual edit doesn't thrash notifications.
  String _triadSignature(CoachProfile p) {
    final salaryBucket = (p.salaireBrutMensuel / 100).round() * 100;
    return '${p.birthYear}|${p.canton}|$salaryBucket';
  }

  @visibleForTesting
  String? get lastScheduledSignature => _lastScheduledSignature;

  @override
  void dispose() {
    _debouncer?.cancel();
    super.dispose();
  }
}
