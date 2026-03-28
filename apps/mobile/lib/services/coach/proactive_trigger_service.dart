// ────────────────────────────────────────────────────────────
//  PROACTIVE TRIGGER SERVICE — S62 / Phase 2 "Le Compagnon"
// ────────────────────────────────────────────────────────────
//
// Evaluates whether the coach should proactively start a
// conversation when the user opens the Coach tab.
//
// Called ONCE per session (cooldown stored in SharedPreferences).
// Returns a ProactiveTrigger or null if no condition is met.
//
// Priority order:
//  1. lifecyclePhaseChange  — new phase since last stored
//  2. weeklyRecapAvailable  — Monday + recap not yet seen
//  3. goalMilestone         — active goal reached 50% or 100%
//  4. seasonalReminder      — seasonal event started today
//  5. inactivityReturn      — no activity for 7+ days
//  6. confidenceImproved    — confidence delta > 5 pts
//  7. newCapAvailable       — CapMemory has new prioritisation cycle
//
// Compliance:
//  - No banned terms (garanti, certain, assure, sans risque,
//    optimal, meilleur, parfait, conseiller)
//  - No social comparison
//  - All user-facing text via ARB keys
//  - Non-breaking space (\u00a0) before !, ?, :, ;, %
// ────────────────────────────────────────────────────────────
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/contract_alert_service.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/gamification/seasonal_event_service.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_detector.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:mint_mobile/models/coaching_preference.dart';

// ════════════════════════════════════════════════════════════════
//  MODELS
// ════════════════════════════════════════════════════════════════

/// Type of proactive trigger.
enum ProactiveTriggerType {
  /// User entered a new lifecycle phase since last session.
  lifecyclePhaseChange,

  /// It's Monday and the weekly recap has not been seen yet this week.
  weeklyRecapAvailable,

  /// An active goal reached 50% or 100% progress.
  goalMilestone,

  /// A seasonal event started today.
  seasonalReminder,

  /// User has not been active for 7+ days.
  inactivityReturn,

  /// Confidence score improved by 5+ points since last session.
  confidenceImproved,

  /// CapEngine has a new priority recommendation vs last shown cap.
  newCapAvailable,

  /// A contract deadline is approaching (lease, insurance, LPP cert expiry).
  contractDeadlineApproaching,
}

/// A proactive trigger returned by [ProactiveTriggerService.evaluate].
class ProactiveTrigger {
  /// Which condition fired.
  final ProactiveTriggerType type;

  /// ARB key for the coach's opening message.
  final String messageKey;

  /// Optional i18n parameter map for parameterised ARB strings.
  final Map<String, String>? params;

  /// Optional GoRouter route tag to offer as first suggestion chip.
  final String? intentTag;

  /// When the trigger was evaluated.
  final DateTime triggeredAt;

  const ProactiveTrigger({
    required this.type,
    required this.messageKey,
    this.params,
    this.intentTag,
    required this.triggeredAt,
  });
}

// ════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════

/// Evaluates proactive trigger conditions when the Coach tab opens.
///
/// Max 1 trigger per calendar day (cooldown stored in SharedPreferences).
/// All methods are static — no instantiation needed.
class ProactiveTriggerService {
  ProactiveTriggerService._();

  // ── SharedPreferences keys ────────────────────────────────

  /// Last trigger date (ISO8601). One trigger per calendar day max.
  static const _keyLastTriggerDate = '_proactive_last_trigger_date';

  /// Lifecycle phase stored at last evaluation (enum name).
  static const _keyStoredPhase = '_proactive_stored_phase';

  /// Confidence score stored at last evaluation (double as string).
  static const _keyStoredConfidence = '_proactive_stored_confidence';

  /// Cap id that was last surfaced to the user from CapMemory.
  static const _keyLastShownCapId = '_proactive_last_cap_id';

  /// ISO8601 of the last weekly recap seen.
  static const _keyLastRecapSeen = '_proactive_last_recap_seen';

  // ── Configuration ─────────────────────────────────────────

  /// Inactivity threshold in days that triggers [ProactiveTriggerType.inactivityReturn].
  static const int inactivityThresholdDays = 7;

  /// Confidence delta (in score points) that triggers [ProactiveTriggerType.confidenceImproved].
  static const double confidenceImprovementDelta = 5.0;

  /// Goal progress thresholds that trigger [ProactiveTriggerType.goalMilestone].
  static const List<int> goalMilestoneThresholds = [50, 100];

  // ── Public API ────────────────────────────────────────────

  /// Evaluate whether the coach should proactively start a conversation.
  ///
  /// Called when the user opens the Coach tab.
  /// Returns a [ProactiveTrigger] if conditions are met, null otherwise.
  ///
  /// Respects [CoachingPreference.intensity] for cooldown duration
  /// and [CoachingPreference.triggerEngagement] for per-type suppression.
  ///
  /// [profile] — current user CoachProfile.
  /// [prefs]   — injectable SharedPreferences for testing.
  /// [now]     — override for deterministic testing.
  static Future<ProactiveTrigger?> evaluate({
    required CoachProfile profile,
    required SharedPreferences prefs,
    DateTime? now,
  }) async {
    final currentDate = now ?? DateTime.now();
    final coachingPref = CoachingPreference.load(prefs);

    // ── Cooldown: respects user's coaching intensity preference ──
    if (_isCoolingDown(prefs, currentDate, coachingPref.cooldownDays)) {
      return null;
    }

    // ── Evaluate in priority order ────────────────────────
    ProactiveTrigger? trigger;

    trigger ??= _checkLifecyclePhaseChange(prefs, profile, currentDate);
    trigger ??= _checkWeeklyRecapAvailable(prefs, currentDate);
    trigger ??= await _checkGoalMilestone(prefs, currentDate);
    trigger ??= _checkSeasonalReminder(prefs, currentDate);
    trigger ??= _checkInactivityReturn(prefs, profile, currentDate);
    trigger ??= _checkConfidenceImproved(prefs, profile, currentDate);
    trigger ??= await _checkNewCapAvailable(prefs, currentDate);
    trigger ??= await _checkContractDeadlines(currentDate);

    // ── Per-type engagement suppression ─────────────────────
    // If the user has consistently ignored this trigger type,
    // suppress it (unless in max-proactive mode).
    if (trigger != null &&
        coachingPref.isTriggerSuppressed(trigger.type.name)) {
      trigger = null;
    }

    if (trigger != null) {
      // Persist trigger date to enforce cooldown.
      await prefs.setString(
          _keyLastTriggerDate, currentDate.toIso8601String());
    }

    return trigger;
  }

  // ── State persistence helpers (call after greeting is shown) ─

  /// Store the user's current lifecycle phase for future change detection.
  ///
  /// Call this after the initial greeting has been displayed.
  static Future<void> storeCurrentPhase(
    CoachProfile profile,
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final phase = LifecycleDetector.detect(profile, now: now);
    await prefs.setString(_keyStoredPhase, phase.name);
  }

  /// Store the current confidence score for future delta detection.
  ///
  /// Call this after the initial greeting has been displayed.
  static Future<void> storeCurrentConfidence(
    CoachProfile profile,
    SharedPreferences prefs,
  ) async {
    final score = ConfidenceScorer.score(profile).score;
    await prefs.setString(_keyStoredConfidence, score.toString());
  }

  /// Mark the weekly recap as seen for this week.
  ///
  /// Call this when the user opens the recap view.
  static Future<void> markRecapSeen(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final date = now ?? DateTime.now();
    await prefs.setString(_keyLastRecapSeen, date.toIso8601String());
  }

  /// Store the cap id currently shown to the user (from CapMemory.lastCapServed).
  ///
  /// Call this when the cap is displayed on screen.
  static Future<void> storeShownCapId(
    String capId,
    SharedPreferences prefs,
  ) async {
    await prefs.setString(_keyLastShownCapId, capId);
  }

  // ── Cooldown ──────────────────────────────────────────────

  /// Returns true if a trigger was fired within the cooldown period.
  ///
  /// [cooldownDays] — from [CoachingPreference.cooldownDays]:
  ///   - 0 = no cooldown (can fire every session)
  ///   - 1 = once per day (default behavior)
  ///   - 3 = once every 3 days
  ///   - 7 = once per week
  static bool _isCoolingDown(
    SharedPreferences prefs,
    DateTime now, [
    int cooldownDays = 1,
  ]) {
    if (cooldownDays <= 0) return false; // intensity 4-5: no cooldown
    final raw = prefs.getString(_keyLastTriggerDate);
    if (raw == null) return false;
    try {
      final last = DateTime.parse(raw);
      final daysSince = now.difference(last).inDays;
      return daysSince < cooldownDays;
    } catch (_) {
      return false;
    }
  }

  // ── Trigger 1: Lifecycle phase change ─────────────────────

  static ProactiveTrigger? _checkLifecyclePhaseChange(
    SharedPreferences prefs,
    CoachProfile profile,
    DateTime now,
  ) {
    final storedPhaseName = prefs.getString(_keyStoredPhase);
    // No stored phase yet means first session — no trigger, just baseline.
    if (storedPhaseName == null) return null;

    LifecyclePhase? storedPhase;
    for (final p in LifecyclePhase.values) {
      if (p.name == storedPhaseName) {
        storedPhase = p;
        break;
      }
    }
    if (storedPhase == null) return null;

    final currentPhase = LifecycleDetector.detect(profile, now: now);
    if (currentPhase == storedPhase) return null;

    return ProactiveTrigger(
      type: ProactiveTriggerType.lifecyclePhaseChange,
      messageKey: 'proactiveLifecycleChange',
      intentTag: '/profile',
      triggeredAt: now,
    );
  }

  // ── Trigger 2: Weekly recap available ─────────────────────

  static ProactiveTrigger? _checkWeeklyRecapAvailable(
    SharedPreferences prefs,
    DateTime now,
  ) {
    // Only fires on Monday.
    if (now.weekday != DateTime.monday) return null;

    final raw = prefs.getString(_keyLastRecapSeen);
    if (raw != null) {
      try {
        final lastSeen = DateTime.parse(raw);
        // If the recap was already seen this week (on or after this Monday), skip.
        final thisMonday = _mondayOf(now);
        if (!lastSeen.isBefore(thisMonday)) return null;
      } catch (_) {
        // Malformed date — treat as not yet seen.
      }
    }

    return ProactiveTrigger(
      type: ProactiveTriggerType.weeklyRecapAvailable,
      messageKey: 'proactiveWeeklyRecap',
      intentTag: '/coach/weekly-recap',
      triggeredAt: now,
    );
  }

  // ── Trigger 3: Goal milestone ─────────────────────────────

  static Future<ProactiveTrigger?> _checkGoalMilestone(
    SharedPreferences prefs,
    DateTime now,
  ) async {
    final goals = await GoalTrackerService.activeGoals(prefs: prefs);
    if (goals.isEmpty) return null;

    // Evaluate milestone progress for each goal; surface the highest.
    // No CapSequence access at this layer — temporal fallback used.
    for (final goal in goals) {
      final progress = estimateGoalProgress(goal, now);
      if (goalMilestoneThresholds.contains(progress)) {
        return ProactiveTrigger(
          type: ProactiveTriggerType.goalMilestone,
          messageKey: 'proactiveGoalMilestone',
          params: {'progress': progress.toString()},
          intentTag: '/coach/chat',
          triggeredAt: now,
        );
      }
    }

    return null;
  }

  // ── Trigger 4: Seasonal reminder ──────────────────────────

  static ProactiveTrigger? _checkSeasonalReminder(
    SharedPreferences prefs,
    DateTime now,
  ) {
    final activeEvents = SeasonalEventService.activeEvents(now: now);
    if (activeEvents.isEmpty) return null;

    // Only fire if a seasonal event starts exactly today.
    final todayStart = activeEvents.where((e) {
      final start =
          DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      final today = DateTime(now.year, now.month, now.day);
      return start == today;
    }).toList();

    if (todayStart.isEmpty) return null;

    final event = todayStart.first;
    return ProactiveTrigger(
      type: ProactiveTriggerType.seasonalReminder,
      messageKey: 'proactiveSeasonalReminder',
      params: {'event': event.titleKey},
      intentTag: event.intentTag,
      triggeredAt: now,
    );
  }

  // ── Trigger 5: Inactivity return ──────────────────────────

  static ProactiveTrigger? _checkInactivityReturn(
    SharedPreferences prefs,
    CoachProfile profile,
    DateTime now,
  ) {
    // Reuse the NudgePersistence last-activity key for consistency.
    const lastActivityKey = '_nudge_last_activity';
    final raw = prefs.getString(lastActivityKey);

    DateTime? lastActivity;
    if (raw != null) {
      try {
        lastActivity = DateTime.parse(raw);
      } catch (_) {
        lastActivity = null;
      }
    }

    // Use profile creation as baseline when no activity is recorded.
    final baseline = lastActivity ?? profile.createdAt;
    final daysSince = now.difference(baseline).inDays;

    if (daysSince < inactivityThresholdDays) return null;

    return ProactiveTrigger(
      type: ProactiveTriggerType.inactivityReturn,
      messageKey: 'proactiveInactivityReturn',
      params: {'days': daysSince.toString()},
      intentTag: '/home',
      triggeredAt: now,
    );
  }

  // ── Trigger 6: Confidence improved ────────────────────────

  static ProactiveTrigger? _checkConfidenceImproved(
    SharedPreferences prefs,
    CoachProfile profile,
    DateTime now,
  ) {
    final rawStored = prefs.getString(_keyStoredConfidence);
    if (rawStored == null) return null;

    double? stored;
    try {
      stored = double.parse(rawStored);
    } catch (_) {
      return null;
    }

    final current = ConfidenceScorer.score(profile).score;
    final delta = current - stored;

    if (delta < confidenceImprovementDelta) return null;

    return ProactiveTrigger(
      type: ProactiveTriggerType.confidenceImproved,
      messageKey: 'proactiveConfidenceUp',
      params: {'delta': delta.round().toString()},
      intentTag: '/profile',
      triggeredAt: now,
    );
  }

  // ── Trigger 7: New cap available ──────────────────────────

  static Future<ProactiveTrigger?> _checkNewCapAvailable(
    SharedPreferences prefs,
    DateTime now,
  ) async {
    // Compare the cap id stored by ProactiveTriggerService with
    // the most recent cap served (from CapMemoryStore.lastCapServed).
    // If they differ, a new cap recommendation is available.
    final memory = await CapMemoryStore.load();
    final latestCapId = memory.lastCapServed;
    if (latestCapId == null) return null; // No cap has been served yet.

    final lastShown = prefs.getString(_keyLastShownCapId);
    if (lastShown == latestCapId) return null; // Same cap still active.

    return ProactiveTrigger(
      type: ProactiveTriggerType.newCapAvailable,
      messageKey: 'proactiveNewCap',
      intentTag: '/home',
      triggeredAt: now,
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Compute the Monday of the week containing [date].
  static DateTime _mondayOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final daysFromMonday = d.weekday - DateTime.monday;
    return d.subtract(Duration(days: daysFromMonday));
  }

  /// Estimate goal completion progress as 0, 50, or 100.
  ///
  /// Returns a milestone threshold (50 or 100) if reached,
  /// or 0 if below the first threshold.
  ///
  /// When [sequenceProgress] is provided (0.0–100.0 from a CapSequence),
  /// it is used as the authoritative signal — this reflects actual user
  /// progress through the plan rather than elapsed time.
  ///
  /// When [sequenceProgress] is null, falls back to temporal estimation:
  ///   - With target date: elapsed / total duration × 100, clamped to 100.
  ///   - Without target date: 50% at 45 days old, 100% at 90 days old.
  ///
  /// Callers with access to CapSequence (e.g. ProactiveTriggerService callers
  /// that read MintUserState) should pass [sequenceProgress] for accurate
  /// milestone detection. Internal callers without CapMemory access use the
  /// temporal fallback automatically.
  static int estimateGoalProgress(
    UserGoal goal,
    DateTime now, {
    double? sequenceProgress,
  }) {
    // Prefer real CapSequence progress when available.
    if (sequenceProgress != null) {
      final pct = sequenceProgress.round().clamp(0, 100);
      if (pct >= 100) return 100;
      if (pct >= 50) return 50;
      return 0;
    }
    // Temporal proxy fallback (no CapSequence signal available).
    if (goal.targetDate != null) {
      final total = goal.targetDate!.difference(goal.createdAt).inDays;
      if (total <= 0) return 100;
      final elapsed = now.difference(goal.createdAt).inDays;
      final pct = ((elapsed / total) * 100).round().clamp(0, 100);
      if (pct >= 100) return 100;
      if (pct >= 50) return 50;
      return 0;
    } else {
      final daysOld = now.difference(goal.createdAt).inDays;
      if (daysOld >= 90) return 100;
      if (daysOld >= 45) return 50;
      return 0;
    }
  }

  /// Check if any contract deadline is approaching.
  static Future<ProactiveTrigger?> _checkContractDeadlines(
    DateTime now,
  ) async {
    final alerts = await ContractAlertService.getActiveAlerts(now);
    if (alerts.isEmpty) return null;

    final nearest = alerts.first;
    final days = nearest.daysRemaining(now);

    return ProactiveTrigger(
      type: ProactiveTriggerType.contractDeadlineApproaching,
      messageKey: 'proactiveContractDeadline',
      params: {
        'label': nearest.label,
        'days': days.toString(),
      },
      triggeredAt: now,
    );
  }
}
