/// Phase 91 Plan 91-04 (VIVANT-01) — push notification copy + scheduling
/// gates for [ProactiveTriggerService] triggers.
///
/// Two responsibilities, both pure (no async, no platform calls):
///
///   1. [ProactiveNotificationCopy.titleAndBodyFor] — maps a
///      [ProactiveTriggerType] to a `(title, body, prefill)` triple. Title
///      and body are short forms suitable for the iOS / Android banner;
///      `prefill` is the one-liner pushed into [CoachChatScreen] when the
///      user taps the banner. Strings are i18n-resolved at the call site
///      (BuildContext is passed in via [S]) — same pattern as
///      [NotificationStrings.fromL10n].
///
///   2. [ProactiveNotificationCopy.applyQuietHoursAndWeekend] — pure
///      timezone math : push the requested fire time to the next 09:00
///      user-local if it falls inside the 22:00-08:00 quiet window, and
///      shift it forward to Monday 09:00 if it lands on a weekend AND the
///      trigger type is not `confidenceImproved` (positive-only suppression
///      bypass per CONTEXT.md `<decisions>` VIVANT-01).
///
/// The 6 wired trigger types correspond to the actual `ProactiveTriggerType`
/// enum in the codebase (Karpathy #1 — match existing infrastructure
/// exactly; the plan's `paieDay` / `documentUploadCompleted` / `jitaiFiscalDate`
/// / `lifecyclePhaseChanged` / `inactivityReturn7d` names are an
/// approximation of the enum that DOES exist) :
///
///   - `lifecyclePhaseChange`        ← plan's `lifecyclePhaseChanged`
///   - `confidenceImproved`          ← plan's `confidenceImproved`
///   - `seasonalReminder`            ← plan's `jitaiFiscalDate` (both fire
///                                      on calendar / fiscal events)
///   - `inactivityReturn`            ← plan's `inactivityReturn7d`
///   - `newCapAvailable`             ← plan's `documentUploadCompleted`
///                                      (CapMemoryStore feeds new caps as
///                                      documents complete)
///   - `contractDeadlineApproaching` ← plan's `paieDay` (ContractAlertService
///                                      surfaces deadlines including
///                                      salary / lease / LPP cert)
///
/// 2 explicitly skipped trigger types (per CONTEXT.md `<deferred>`) :
///
///   - `weeklyRecapAvailable` — deleted in Phase 2b (façade audit). No
///     [WeeklyRecapService] consumer survives.
///   - `goalMilestone` — depends on [GoalTrackerService] reactivation
///     (deferred to v3.x).
///
/// These are surfaced via [ProactiveNotificationCopy.titleAndBodyFor]
/// returning `null`; callers MUST treat null as « do not schedule push ».
library;

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach/proactive_trigger_service.dart';

/// Quiet hours window (user-local). Push schedules that fall inside
/// `[startHour, 24) ∪ [0, endHour)` are forwarded to [endHour] of the
/// same day OR the next day, whichever is later.
///
/// 22:00-08:00 per CONTEXT.md `<decisions>` VIVANT-01.
const int kQuietHoursStart = 22;

/// See [kQuietHoursStart].
const int kQuietHoursEnd = 8;

/// User-local hour (in [kQuietHoursEnd, kQuietHoursStart)) at which a
/// quiet-hours-suppressed notification fires the morning after.
const int kReleaseHour = 9;

/// Returned by [ProactiveNotificationCopy.titleAndBodyFor].
class ProactivePushCopy {
  /// Short title (≤ 40 chars recommended for iOS banner).
  final String title;

  /// Short body (≤ 120 chars recommended for iOS banner).
  final String body;

  /// One-liner pushed into the chat input field on tap.
  final String prefill;

  const ProactivePushCopy({
    required this.title,
    required this.body,
    required this.prefill,
  });
}

/// Pure helper — no async, no DI, no platform calls. See file-level docs.
class ProactiveNotificationCopy {
  ProactiveNotificationCopy._();

  /// Returns localised push copy for [type], or `null` for the 2 skipped
  /// trigger types ([ProactiveTriggerType.weeklyRecapAvailable] and
  /// [ProactiveTriggerType.goalMilestone]).
  ///
  /// [params] mirrors [ProactiveTrigger.params] — used to interpolate
  /// `{days}`, `{delta}`, `{label}`, `{event}` into the body when relevant.
  static ProactivePushCopy? titleAndBodyFor(
    ProactiveTriggerType type,
    S l, {
    Map<String, String>? params,
  }) {
    switch (type) {
      // ── 6 wired ───────────────────────────────────────────────
      case ProactiveTriggerType.lifecyclePhaseChange:
        return ProactivePushCopy(
          title: l.proactivePushLifecycleTitle,
          body: l.proactivePushLifecycleBody,
          prefill: l.proactivePushLifecyclePrefill,
        );

      case ProactiveTriggerType.confidenceImproved:
        return ProactivePushCopy(
          title: l.proactivePushConfidenceTitle,
          body: l.proactivePushConfidenceBody(params?['delta'] ?? '5'),
          prefill: l.proactivePushConfidencePrefill,
        );

      case ProactiveTriggerType.seasonalReminder:
        return ProactivePushCopy(
          title: l.proactivePushSeasonalTitle,
          body: l.proactivePushSeasonalBody(params?['event'] ?? ''),
          prefill: l.proactivePushSeasonalPrefill,
        );

      case ProactiveTriggerType.inactivityReturn:
        return ProactivePushCopy(
          title: l.proactivePushInactivityTitle,
          body: l.proactivePushInactivityBody(params?['days'] ?? '7'),
          prefill: l.proactivePushInactivityPrefill,
        );

      case ProactiveTriggerType.newCapAvailable:
        return ProactivePushCopy(
          title: l.proactivePushNewCapTitle,
          body: l.proactivePushNewCapBody,
          prefill: l.proactivePushNewCapPrefill,
        );

      case ProactiveTriggerType.contractDeadlineApproaching:
        return ProactivePushCopy(
          title: l.proactivePushDeadlineTitle,
          body: l.proactivePushDeadlineBody(
            params?['label'] ?? '',
            params?['days'] ?? '',
          ),
          prefill: l.proactivePushDeadlinePrefill,
        );

      // ── 2 deferred — caller MUST skip on null ────────────────
      case ProactiveTriggerType.weeklyRecapAvailable:
      case ProactiveTriggerType.goalMilestone:
        return null;
    }
  }

  /// Apply quiet-hours + weekend dampening to a desired schedule time.
  ///
  /// Rules (per CONTEXT.md `<decisions>` VIVANT-01) :
  ///   1. If [requestedAt] falls in [kQuietHoursStart, 24) ∪ [0, kQuietHoursEnd) —
  ///      shift to [kReleaseHour]:00 of the next « daytime » day.
  ///   2. If the resulting day is Sat/Sun AND [type] is NOT
  ///      `confidenceImproved` (positive-only bypass) — shift to Monday
  ///      [kReleaseHour]:00.
  ///
  /// Returns the new fire time (always non-null — no « cancel » signal).
  /// Callers can compare with [requestedAt] to log whether dampening
  /// actually fired (useful for Sentry breadcrumbs).
  static DateTime applyQuietHoursAndWeekend(
    DateTime requestedAt,
    ProactiveTriggerType type,
  ) {
    var t = requestedAt;

    // 1. Quiet hours guard.
    if (_inQuietHours(t)) {
      // Move to today @ kReleaseHour, OR tomorrow @ kReleaseHour if
      // requestedAt's calendar day already past kReleaseHour.
      final today = DateTime(t.year, t.month, t.day, kReleaseHour);
      if (t.isAfter(today) || t.hour >= kQuietHoursStart) {
        // Late-night case (22:00-23:59) → next day morning.
        t = today.add(const Duration(days: 1));
      } else {
        // Early-morning case (00:00-07:59) → today @ release hour.
        t = today;
      }
    }

    // 2. Weekend dampening — `confidenceImproved` bypasses (positive-only).
    if (type != ProactiveTriggerType.confidenceImproved) {
      while (t.weekday == DateTime.saturday || t.weekday == DateTime.sunday) {
        t = DateTime(t.year, t.month, t.day, kReleaseHour)
            .add(const Duration(days: 1));
      }
    }

    return t;
  }

  /// Inside the 22:00-08:00 quiet window ?
  static bool _inQuietHours(DateTime t) {
    return t.hour >= kQuietHoursStart || t.hour < kQuietHoursEnd;
  }
}
