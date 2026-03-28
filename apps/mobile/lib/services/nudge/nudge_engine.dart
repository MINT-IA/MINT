import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/nudge/nudge_trigger.dart';

// ────────────────────────────────────────────────────────────
//  NUDGE ENGINE — S61 / JITAI Proactive Nudges
// ────────────────────────────────────────────────────────────
//
// Pure, stateless engine. No SharedPreferences, no Flutter UI.
// Evaluates all NudgeTrigger conditions and returns applicable
// Nudge objects sorted by priority.
//
// Persistence (dismiss/cooldown) is handled by NudgePersistence.
//
// Callers must filter dismissed nudges before rendering:
//   final dismissed = await NudgePersistence.getDismissedIds(prefs);
//   final nudges = NudgeEngine.evaluate(
//     profile: profile,
//     now: DateTime.now(),
//     dismissedNudgeIds: dismissed,
//   );
//
// Compliance:
//   - No banned terms (garanti, certain, assuré, sans risque, optimal,
//     meilleur, parfait, conseiller)
//   - No social comparison
//   - Conditional language (pourrait, envisager, peut-être)
//   - Positive framing only
//   - Non-breaking space (\u00a0) before !, ?, :, ;, %
// ────────────────────────────────────────────────────────────

/// Priority level for nudge display ordering.
/// `high` = 0, `medium` = 1, `low` = 2 (ascending sort).
enum NudgePriority { high, medium, low }

/// A single proactive nudge to display on the Pulse dashboard.
///
/// All text fields use French with:
///   - Informal "tu"
///   - Non-breaking space (\u00a0) before !, ?, :, ;
///   - Conditional language
///   - No banned terms
class Nudge {
  /// Unique identifier: `{trigger.name}_{yyyyMMdd}`.
  final String id;

  /// Trigger type (determines cooldown and icon).
  final NudgeTrigger trigger;

  /// Display priority for ordering.
  final NudgePriority priority;

  /// GoRouter route to navigate to on CTA tap.
  /// Always starts with '/'.
  final String intentTag;

  /// ARB key for the headline (no params).
  final String titleKey;

  /// ARB key for the 1–2 sentence body.
  final String bodyKey;

  /// Optional i18n parameter map for parameterised ARB strings.
  /// Key = ARB placeholder name, value = resolved string.
  final Map<String, String>? params;

  /// After this datetime the nudge auto-dismisses.
  final DateTime expiresAt;

  const Nudge({
    required this.id,
    required this.trigger,
    required this.priority,
    required this.intentTag,
    required this.titleKey,
    required this.bodyKey,
    this.params,
    required this.expiresAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Nudge && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Pure evaluation engine for JITAI nudges.
///
/// All public methods are static. No side effects.
class NudgeEngine {
  NudgeEngine._();

  // ── Configuration ────────────────────────────────────────

  /// Milestone ages that trigger [NudgeTrigger.birthdayMilestone].
  static const _milestoneAges = [25, 30, 35, 40, 45, 50, 55, 60, 65];

  /// Minimum confidence score (0–100) below which profile nudge fires.
  static const double _profileConfidenceThreshold = 40.0;

  /// Minimum account age in days before profile nudge fires.
  static const int _profileMinDaysOld = 7;

  /// Days of inactivity before [NudgeTrigger.noActivityWeek] fires.
  static const int _inactivityDays = 7;

  /// Goal progress thresholds that trigger [NudgeTrigger.goalProgress].
  static const _goalProgressThresholds = [50, 100];

  // ── Public API ───────────────────────────────────────────

  /// Evaluate all triggers and return applicable nudges.
  ///
  /// **Pure function** — no side effects. All persistence (dismiss,
  /// last-activity) is passed in by the caller via [dismissedNudgeIds]
  /// and [lastActivityTime].
  ///
  /// Returns nudges sorted by priority (high first).
  /// Dismissed nudges (id in [dismissedNudgeIds]) are excluded.
  /// Expired nudges are excluded.
  ///
  /// [profile]          — current user CoachProfile (non-null).
  /// [now]              — current datetime (injectable for tests).
  /// [dismissedNudgeIds]— ids from NudgePersistence.getDismissedIds().
  /// [lastActivityTime] — from NudgePersistence.getLastActivityTime().
  /// [confidenceScore]  — 0–100 from EnhancedConfidence.score (optional).
  /// [goalProgressPct]  — progress % of primary active goal (optional).
  /// [lifeEventDate]    — date of the most recent life event (optional).
  static List<Nudge> evaluate({
    required CoachProfile profile,
    required DateTime now,
    required List<String> dismissedNudgeIds,
    DateTime? lastActivityTime,
    double? confidenceScore,
    int? goalProgressPct,
    DateTime? lifeEventDate,
  }) {
    final candidates = <Nudge>[];

    _checkSalaryReceived(candidates, now);
    _checkTaxDeadlineApproach(candidates, now);
    _checkPillar3aDeadline(candidates, now, profile);
    _checkBirthdayMilestone(candidates, now, profile);
    _checkProfileIncomplete(candidates, now, profile, confidenceScore);
    _checkNoActivityWeek(candidates, now, lastActivityTime);
    _checkGoalProgress(candidates, now, profile, goalProgressPct);
    _checkLifeEventAnniversary(candidates, now, lifeEventDate);
    _checkLppBuybackWindow(candidates, now, profile);
    _checkNewYearReset(candidates, now);

    // Filter dismissed and expired
    final active = candidates.where((n) {
      if (dismissedNudgeIds.contains(n.id)) return false;
      if (n.expiresAt.isBefore(now)) return false;
      return true;
    }).toList();

    // Sort by priority ascending (high=0, medium=1, low=2)
    active.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    return active;
  }

  // ── Trigger implementations ──────────────────────────────

  /// Salary received: 1st–5th of month.
  static void _checkSalaryReceived(List<Nudge> nudges, DateTime now) {
    if (now.day >= 1 && now.day <= 5) {
      final id = _id(NudgeTrigger.salaryReceived, now);
      nudges.add(Nudge(
        id: id,
        trigger: NudgeTrigger.salaryReceived,
        priority: NudgePriority.medium,
        intentTag: '/pilier-3a',
        titleKey: 'nudgeSalaryTitle',
        bodyKey: 'nudgeSalaryBody',
        expiresAt: DateTime(now.year, now.month, 6),
      ));
    }
  }

  /// Tax deadline approach: Feb–March (March 31) or Aug–Sept (Sept 30).
  static void _checkTaxDeadlineApproach(List<Nudge> nudges, DateTime now) {
    final inSpringWindow = now.month == 2 || now.month == 3;
    final inAutumnWindow = now.month == 8 || now.month == 9;
    if (!inSpringWindow && !inAutumnWindow) return;

    final expiresMonth = inSpringWindow ? 4 : 10;
    final id = _id(NudgeTrigger.taxDeadlineApproach, now);
    nudges.add(Nudge(
      id: id,
      trigger: NudgeTrigger.taxDeadlineApproach,
      priority: NudgePriority.high,
      intentTag: '/fiscal',
      titleKey: 'nudgeTaxDeadlineTitle',
      bodyKey: 'nudgeTaxDeadlineBody',
      expiresAt: DateTime(now.year, expiresMonth, 1),
    ));
  }

  /// Pillar 3a deadline: December.
  /// Uses archetype-aware plafond.
  static void _checkPillar3aDeadline(
    List<Nudge> nudges,
    DateTime now,
    CoachProfile profile,
  ) {
    if (now.month != 12) return;

    final daysLeft = 31 - now.day;
    final isIndependentNoLpp =
        profile.archetype == FinancialArchetype.independentNoLpp;
    final plafond = isIndependentNoLpp ? "36'288" : "7'258";

    final id = _id(NudgeTrigger.pillar3aDeadline, now);
    nudges.add(Nudge(
      id: id,
      trigger: NudgeTrigger.pillar3aDeadline,
      priority: NudgePriority.high,
      intentTag: '/pilier-3a',
      titleKey: 'nudge3aDeadlineTitle',
      bodyKey: 'nudge3aDeadlineBody',
      params: {
        'days': daysLeft.toString(),
        'limit': plafond,
        'year': now.year.toString(),
      },
      expiresAt: DateTime(now.year + 1, 1, 1),
    ));
  }

  /// Birthday milestone: first 7 days of January, milestone age.
  static void _checkBirthdayMilestone(
    List<Nudge> nudges,
    DateTime now,
    CoachProfile profile,
  ) {
    if (now.month != 1 || now.day > 7) return;

    final age = now.year - profile.birthYear;
    if (!_milestoneAges.contains(age)) return;

    final id = _id(NudgeTrigger.birthdayMilestone, now);
    nudges.add(Nudge(
      id: id,
      trigger: NudgeTrigger.birthdayMilestone,
      priority: NudgePriority.low,
      intentTag: '/pulse',
      titleKey: 'nudgeBirthdayTitle',
      bodyKey: 'nudgeBirthdayBody',
      params: {'age': age.toString()},
      expiresAt: DateTime(now.year, 1, 31),
    ));
  }

  /// Profile incomplete: confidence < 40% after 7+ days.
  static void _checkProfileIncomplete(
    List<Nudge> nudges,
    DateTime now,
    CoachProfile profile,
    double? confidenceScore,
  ) {
    final daysSinceCreation = now.difference(profile.createdAt).inDays;
    if (daysSinceCreation < _profileMinDaysOld) return;

    // If no confidence score provided, use heuristic based on profile fields
    final score = confidenceScore ?? _estimateConfidence(profile);
    if (score >= _profileConfidenceThreshold) return;

    final id = _id(NudgeTrigger.profileIncomplete, now);
    nudges.add(Nudge(
      id: id,
      trigger: NudgeTrigger.profileIncomplete,
      priority: NudgePriority.medium,
      intentTag: '/profile',
      titleKey: 'nudgeProfileTitle',
      bodyKey: 'nudgeProfileBody',
      expiresAt: now.add(const Duration(days: 14)),
    ));
  }

  /// No activity in last 7 days.
  static void _checkNoActivityWeek(
    List<Nudge> nudges,
    DateTime now,
    DateTime? lastActivityTime,
  ) {
    final isInactive = lastActivityTime == null ||
        now.difference(lastActivityTime).inDays >= _inactivityDays;
    if (!isInactive) return;

    final id = _id(NudgeTrigger.noActivityWeek, now);
    nudges.add(Nudge(
      id: id,
      trigger: NudgeTrigger.noActivityWeek,
      priority: NudgePriority.low,
      intentTag: '/pulse',
      titleKey: 'nudgeInactiveTitle',
      bodyKey: 'nudgeInactiveBody',
      expiresAt: now.add(const Duration(days: 7)),
    ));
  }

  /// Goal progress: active goal reached 50% or 100%.
  static void _checkGoalProgress(
    List<Nudge> nudges,
    DateTime now,
    CoachProfile profile,
    int? goalProgressPct,
  ) {
    if (goalProgressPct == null) return;
    if (!_goalProgressThresholds.contains(goalProgressPct)) return;

    final id = '${NudgeTrigger.goalProgress.name}_${goalProgressPct}pct_'
        '${now.year}${now.month.toString().padLeft(2, '0')}';
    nudges.add(Nudge(
      id: id,
      trigger: NudgeTrigger.goalProgress,
      priority: goalProgressPct == 100
          ? NudgePriority.high
          : NudgePriority.medium,
      intentTag: '/home?tab=1',
      titleKey: 'nudgeGoalProgressTitle',
      bodyKey: 'nudgeGoalProgressBody',
      params: {'progress': goalProgressPct.toString()},
      expiresAt: now.add(const Duration(days: 7)),
    ));
  }

  /// Life event anniversary: 1 year since last life event.
  static void _checkLifeEventAnniversary(
    List<Nudge> nudges,
    DateTime now,
    DateTime? lifeEventDate,
  ) {
    if (lifeEventDate == null) return;

    final daysSince = now.difference(lifeEventDate).inDays;
    // Trigger in ±3-day window around the 365-day mark
    if (daysSince < 362 || daysSince > 368) return;

    final id = _id(NudgeTrigger.lifeEventAnniversary, now);
    nudges.add(Nudge(
      id: id,
      trigger: NudgeTrigger.lifeEventAnniversary,
      priority: NudgePriority.low,
      intentTag: '/profile',
      titleKey: 'nudgeAnniversaryTitle',
      bodyKey: 'nudgeAnniversaryBody',
      expiresAt: now.add(const Duration(days: 14)),
    ));
  }

  /// LPP buyback window: Q4 (Oct–Dec) + user has LPP.
  static void _checkLppBuybackWindow(
    List<Nudge> nudges,
    DateTime now,
    CoachProfile profile,
  ) {
    if (now.month < 10) return;

    // Only fire if user has LPP (not independentNoLpp archetype)
    final hasLpp = profile.archetype != FinancialArchetype.independentNoLpp;
    if (!hasLpp) return;

    final id = _id(NudgeTrigger.lppBuybackWindow, now);
    nudges.add(Nudge(
      id: id,
      trigger: NudgeTrigger.lppBuybackWindow,
      priority: NudgePriority.medium,
      intentTag: '/rachat-lpp',
      titleKey: 'nudgeLppBuybackTitle',
      bodyKey: 'nudgeLppBuybackBody',
      params: {'year': now.year.toString()},
      expiresAt: DateTime(now.year + 1, 1, 1),
    ));
  }

  /// New year reset: January 1–15.
  static void _checkNewYearReset(List<Nudge> nudges, DateTime now) {
    if (now.month != 1 || now.day > 15) return;

    final id = _id(NudgeTrigger.newYearReset, now);
    nudges.add(Nudge(
      id: id,
      trigger: NudgeTrigger.newYearReset,
      priority: NudgePriority.medium,
      intentTag: '/pilier-3a',
      titleKey: 'nudgeNewYearTitle',
      bodyKey: 'nudgeNewYearBody',
      params: {'year': now.year.toString()},
      expiresAt: DateTime(now.year, 1, 16),
    ));
  }

  // ── Helpers ──────────────────────────────────────────────

  /// Generate nudge id: `{trigger}_{yyyyMM}`.
  /// Monthly granularity prevents duplicate nudges within same month.
  static String _id(NudgeTrigger trigger, DateTime now) {
    return '${trigger.name}_${now.year}${now.month.toString().padLeft(2, '0')}';
  }

  /// Heuristic confidence estimate when no scorer is available.
  /// Counts filled mandatory profile fields (returns 0–100).
  static double _estimateConfidence(CoachProfile profile) {
    var score = 0.0;
    // birthYear: always set (required), +20
    score += 20;
    // canton: always set (required), +20
    score += 20;
    // salary: always set (required), +15
    score += 15;
    // prevoyance fields
    if (profile.prevoyance.avoirLppTotal != null) score += 15;
    if (profile.prevoyance.totalEpargne3a > 0) score += 10;
    if (profile.prevoyance.anneesContribuees != null) score += 10;
    if (profile.patrimoine.epargneLiquide > 0) score += 5;
    if (profile.dettes.totalDettes > 0) score += 5;
    return score.clamp(0, 100);
  }
}
