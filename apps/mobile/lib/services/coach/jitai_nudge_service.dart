import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';
import 'package:mint_mobile/services/daily_engagement_service.dart';

// ────────────────────────────────────────────────────────────
//  JITAI NUDGE SERVICE — S61 / Proactive Nudges
// ────────────────────────────────────────────────────────────
//
// JITAI = Just-In-Time Adaptive Interventions.
//
// Pure service that detects when a nudge should be shown on
// the Pulse dashboard. NEVER interrupts user mid-task (no
// popups during simulations).
//
// Nudges use positive framing ("As-tu pensé à..." not
// "Tu n'as pas encore..."), informal French "tu", and
// conditional language.
//
// Max 3 nudges shown at once, sorted by priority.
// Cooldown: once dismissed, not re-triggered for X days.
// ────────────────────────────────────────────────────────────

/// Nudge trigger types.
enum NudgeType {
  salaryDay,
  taxDeadline,
  threeADeadline,
  birthdayMilestone,
  contractAnniversary,
  lppBonificationChange,
  weeklyCheckIn,
  streakAtRisk,
  goalDeadlineApproaching,
  fhsDropped,
}

/// Priority level for nudge ordering.
enum NudgePriority { high, medium, low }

/// A single JITAI nudge to display.
class JitaiNudge {
  /// Trigger type.
  final NudgeType type;

  /// Short headline (French, accented).
  final String title;

  /// 1-2 sentence educational message (positive framing).
  final String message;

  /// GoRouter route to navigate to on CTA tap (nullable).
  final String? actionRoute;

  /// CTA button label (nullable).
  final String? actionLabel;

  /// When this nudge was triggered.
  final DateTime triggeredAt;

  /// Priority for display ordering.
  final NudgePriority priority;

  const JitaiNudge({
    required this.type,
    required this.title,
    required this.message,
    this.actionRoute,
    this.actionLabel,
    required this.triggeredAt,
    required this.priority,
  });
}

/// Service that evaluates and manages JITAI nudges.
class JitaiNudgeService {
  JitaiNudgeService._();

  /// SharedPreferences prefix for cooldown tracking.
  static const _dismissPrefix = '_jitai_dismissed_';

  /// SharedPreferences key for last FHS score.
  static const _lastFhsKey = '_jitai_last_fhs';

  /// Maximum nudges returned by [evaluateNudges].
  static const maxNudges = 3;

  // ── Public API ──────────────────────────────────────────────

  /// Evaluate all nudge triggers and return applicable nudges
  /// sorted by priority (high first), capped at [maxNudges].
  ///
  /// **Important**: Callers MUST call [recordFhsScore] after each FHS
  /// computation so that [_checkFhsDropped] can detect score changes.
  /// This method does NOT auto-record FHS scores.
  ///
  /// [profile] — current user profile.
  /// [now] — override for testing (defaults to DateTime.now()).
  /// [prefs] — injectable SharedPreferences for testing.
  /// [currentStreak] — current engagement streak (injectable for testing).
  /// [engagedYesterday] — whether user engaged yesterday (injectable).
  /// [fhsScore] — current FHS score (0-100), nullable.
  /// [goals] — active goals list (injectable for testing).
  /// [l] — optional localizations; when null (e.g. in tests) French fallbacks are used.
  static Future<List<JitaiNudge>> evaluateNudges({
    required CoachProfile profile,
    DateTime? now,
    SharedPreferences? prefs,
    int? currentStreak,
    bool? engagedYesterday,
    double? fhsScore,
    List<UserGoal>? goals,
    S? l,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final today = now ?? DateTime.now();

    final nudges = <JitaiNudge>[];

    // Evaluate each trigger
    _checkSalaryDay(nudges, profile, today, l);
    _checkTaxDeadline(nudges, today, l);
    _checkThreeADeadline(nudges, today, profile, l);
    _checkBirthdayMilestone(nudges, profile, today, l);
    _checkContractAnniversary(nudges, profile, today, l);
    _checkLppBonificationChange(nudges, profile, today, l);
    await _checkWeeklyCheckIn(nudges, today, sp, l);
    _checkStreakAtRisk(nudges, currentStreak, engagedYesterday, today, l, profile: profile);
    _checkGoalDeadlineApproaching(nudges, goals, today, l);
    _checkFhsDropped(nudges, fhsScore, sp, today, l);

    // Filter out dismissed (in cooldown) nudges
    final filtered = <JitaiNudge>[];
    for (final nudge in nudges) {
      if (!_isDismissed(nudge.type, sp, today)) {
        filtered.add(nudge);
      }
    }

    // Sort by priority (high=0, medium=1, low=2)
    filtered.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    // Cap at max
    return filtered.take(maxNudges).toList();
  }

  /// Dismiss a nudge (starts cooldown).
  ///
  /// [type] — nudge type to dismiss.
  /// [prefs] — injectable SharedPreferences for testing.
  /// [now] — override for testing.
  static Future<void> dismissNudge({
    required NudgeType type,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final today = now ?? DateTime.now();
    await sp.setString(
      '$_dismissPrefix${type.name}',
      today.toIso8601String(),
    );
  }

  /// Returns a map of nudge types to their cooldown expiry dates.
  ///
  /// Useful for UI to show "dismissed until..." or "available in X days".
  /// Returns only nudges that are currently in cooldown.
  ///
  /// [prefs] — injectable for testing.
  /// [now] — override for testing.
  static Future<Map<NudgeType, DateTime>> activeCooldowns({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    final today = now ?? DateTime.now();
    final result = <NudgeType, DateTime>{};

    for (final type in NudgeType.values) {
      final raw = sp.getString('$_dismissPrefix${type.name}');
      if (raw == null) continue;
      try {
        final dismissedAt = DateTime.parse(raw);
        final cooldown = _cooldownDays(type);
        final expiresAt = dismissedAt.add(Duration(days: cooldown));
        if (expiresAt.isAfter(today)) {
          result[type] = expiresAt;
        }
      } catch (_) {
        // Invalid date format — skip
      }
    }

    return result;
  }

  /// Store current FHS score for delta detection.
  ///
  /// Call this after each FHS computation so the next evaluation
  /// can detect drops.
  static Future<void> recordFhsScore({
    required double score,
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.setDouble(_lastFhsKey, score);
  }

  // ── Cooldown logic ──────────────────────────────────────────

  /// Cooldown in days per nudge type.
  static int _cooldownDays(NudgeType type) {
    switch (type) {
      case NudgeType.salaryDay:
        return 25;
      case NudgeType.taxDeadline:
        return 7;
      case NudgeType.threeADeadline:
        return 7;
      case NudgeType.birthdayMilestone:
        return 360;
      case NudgeType.contractAnniversary:
        return 360;
      case NudgeType.lppBonificationChange:
        return 360;
      case NudgeType.weeklyCheckIn:
        return 5;
      case NudgeType.streakAtRisk:
        return 2;
      case NudgeType.goalDeadlineApproaching:
        return 7;
      case NudgeType.fhsDropped:
        return 7;
    }
  }

  /// Check if a nudge type is currently in cooldown.
  static bool _isDismissed(NudgeType type, SharedPreferences sp, DateTime now) {
    final raw = sp.getString('$_dismissPrefix${type.name}');
    if (raw == null) return false;
    try {
      final dismissedAt = DateTime.parse(raw);
      final cooldown = _cooldownDays(type);
      return now.difference(dismissedAt).inDays < cooldown;
    } catch (_) {
      return false;
    }
  }

  // ── Trigger checks ──────────────────────────────────────────

  /// Salary day: 25th of the month → remind 3a transfer.
  static void _checkSalaryDay(
    List<JitaiNudge> nudges,
    CoachProfile profile,
    DateTime now,
    S? l,
  ) {
    if (now.day == 25) {
      nudges.add(JitaiNudge(
        type: NudgeType.salaryDay,
        title: l?.nudgeSalaryDayTitle ?? 'Jour de salaire\u00a0!',
        message: l?.nudgeSalaryDayMessage ?? 'As-tu pensé à ton virement 3a ce mois-ci\u00a0? Chaque mois compte pour ta prévoyance.',
        actionRoute: '/pilier-3a',
        actionLabel: l?.nudgeSalaryDayAction ?? 'Voir mon 3a',
        triggeredAt: now,
        priority: NudgePriority.medium,
      ));
    }
  }

  /// Tax filing deadline: Feb-March → remind to file.
  /// M4: Canton-specific dates vary — generic reminder without hardcoded date.
  static void _checkTaxDeadline(List<JitaiNudge> nudges, DateTime now, S? l) {
    if (now.month >= 2 && now.month <= 3) {
      nudges.add(JitaiNudge(
        type: NudgeType.taxDeadline,
        title: l?.nudgeTaxDeadlineTitle ?? 'Déclaration fiscale',
        message: l?.nudgeTaxDeadlineMessage ?? 'Vérifie la date limite de déclaration fiscale dans ton canton. As-tu pensé à vérifier tes déductions 3a et LPP\u00a0?',
        actionRoute: '/fiscal',
        actionLabel: l?.nudgeTaxDeadlineAction ?? 'Simuler mes impôts',
        triggeredAt: now,
        priority: NudgePriority.high,
      ));
    }
  }

  /// 3a contribution deadline: Dec 1-31 → remind to max out.
  /// Skips FATCA/expat_us: most 3a providers refuse US persons.
  static void _checkThreeADeadline(
    List<JitaiNudge> nudges,
    DateTime now,
    CoachProfile profile,
    S? l,
  ) {
    if (profile.archetype == FinancialArchetype.expatUs) return;
    if (now.month == 12) {
      final daysLeft = 31 - now.day;
      // M2: Dec 31 edge case
      if (daysLeft == 0) {
        nudges.add(JitaiNudge(
          type: NudgeType.threeADeadline,
          title: l?.nudgeThreeADeadlineTitle ?? 'Dernière ligne droite pour ton 3a',
          message: l?.nudgeThreeADeadlineMessageLastDay ?? 'C\'est le dernier jour pour verser sur ton 3a\u00a0!',
          actionRoute: '/pilier-3a',
          actionLabel: l?.nudgeThreeADeadlineAction ?? 'Calculer mon économie',
          triggeredAt: now,
          priority: NudgePriority.high,
        ));
        return;
      }
      // H5: Correct 3a limit based on archetype
      final isIndependentNoLpp =
          profile.archetype == FinancialArchetype.independentNoLpp;
      final plafondStr = isIndependentNoLpp ? '36\'288' : '7\'258';
      nudges.add(JitaiNudge(
        type: NudgeType.threeADeadline,
        title: l?.nudgeThreeADeadlineTitle ?? 'Dernière ligne droite pour ton 3a',
        message: 'Il reste $daysLeft\u00a0jour${daysLeft > 1 ? 's' : ''} '
            'pour verser jusqu\'à $plafondStr\u00a0CHF '
            'et réduire tes impôts ${now.year}.', // Dynamic string with numbers — not fully extractable
        actionRoute: '/pilier-3a',
        actionLabel: l?.nudgeThreeADeadlineAction ?? 'Calculer mon économie',
        triggeredAt: now,
        priority: NudgePriority.high,
      ));
    }
  }

  /// Birthday milestone: user's birthday → age-relevant tip.
  static void _checkBirthdayMilestone(
    List<JitaiNudge> nudges,
    CoachProfile profile,
    DateTime now,
    S? l,
  ) {
    // We only know birthYear, not exact date. Trigger on Jan 1 of a new age year.
    // This is a simplification — if exact birth date were available, we'd use it.
    final currentAge = now.year - profile.birthYear;
    final isNewYear = now.month == 1 && now.day <= 7;

    if (!isNewYear) return;

    // Only trigger for milestone ages
    final milestoneMessage = _birthdayMessage(currentAge);
    if (milestoneMessage == null) return;

    nudges.add(JitaiNudge(
      type: NudgeType.birthdayMilestone,
      title: 'Tu as $currentAge\u00a0ans cette année\u00a0!', // Dynamic with age — not extracted
      message: milestoneMessage,
      actionRoute: '/pulse',
      actionLabel: l?.nudgeBirthdayDashboardAction ?? 'Voir mon tableau de bord',
      triggeredAt: now,
      priority: NudgePriority.low,
    ));
  }

  /// Contract anniversary: 1 year since profile creation.
  static void _checkContractAnniversary(
    List<JitaiNudge> nudges,
    CoachProfile profile,
    DateTime now,
    S? l,
  ) {
    final daysSinceCreation = now.difference(profile.createdAt).inDays;

    // Trigger around 365 days (±3 days window)
    if (daysSinceCreation >= 362 && daysSinceCreation <= 368) {
      nudges.add(JitaiNudge(
        type: NudgeType.contractAnniversary,
        title: l?.nudgeAnniversaryTitle ?? 'Déjà 1\u00a0an ensemble\u00a0!',
        message: l?.nudgeAnniversaryMessage ?? 'Tu utilises MINT depuis un an. C\'est le moment idéal pour actualiser ton profil et mesurer tes progrès.',
        actionRoute: '/profile',
        actionLabel: l?.nudgeAnniversaryAction ?? 'Actualiser mon profil',
        triggeredAt: now,
        priority: NudgePriority.low,
      ));
    }
  }

  /// LPP bonification change: user crosses age bracket.
  static void _checkLppBonificationChange(
    List<JitaiNudge> nudges,
    CoachProfile profile,
    DateTime now,
    S? l,
  ) {
    final currentAge = now.year - profile.birthYear;

    // LPP brackets: 25, 35, 45, 55 (from social_insurance.dart)
    // Trigger in Jan of the year they cross a bracket
    if (now.month == 1 && now.day <= 14) {
      final bracketAges = [25, 35, 45, 55];
      if (bracketAges.contains(currentAge)) {
        final rate = getLppBonificationRate(currentAge);
        final ratePct = (rate * 100).toInt();
        // M3: At 25, contributions START — different message
        final message = currentAge == 25
            ? 'Tes cotisations LPP de vieillesse commencent cette année '
                '($ratePct\u00a0%). C\'est le début de ta prévoyance professionnelle.'
            : 'À $currentAge\u00a0ans, ta bonification de vieillesse '
                'passe à $ratePct\u00a0%. Cela pourrait être le bon moment '
                'pour envisager un rachat LPP.';
        nudges.add(JitaiNudge(
          type: NudgeType.lppBonificationChange,
          title: currentAge == 25
              ? (l?.nudgeLppBonifStartTitle ?? 'Début des cotisations LPP')
              : (l?.nudgeLppBonifChangeTitle ?? 'Changement de tranche LPP'),
          message: message, // Dynamic with age/rate — not extracted
          actionRoute: '/rachat-lpp',
          actionLabel: l?.nudgeLppBonifAction ?? 'Explorer le rachat',
          triggeredAt: now,
          priority: NudgePriority.medium,
        ));
      }
    }
  }

  /// Weekly check-in: 7+ days since last engagement.
  static Future<void> _checkWeeklyCheckIn(
    List<JitaiNudge> nudges,
    DateTime now,
    SharedPreferences sp,
    S? l,
  ) async {
    final recentDates = await DailyEngagementService.recentDates(
      days: 7,
      prefs: sp,
      now: now,
    );

    if (recentDates.isEmpty) {
      nudges.add(JitaiNudge(
        type: NudgeType.weeklyCheckIn,
        title: l?.nudgeWeeklyCheckInTitle ?? 'Ça fait un moment\u00a0!',
        message: l?.nudgeWeeklyCheckInMessage ?? 'Ta situation financière évolue chaque semaine. Prends 2\u00a0minutes pour vérifier ton tableau de bord.',
        actionRoute: '/pulse',
        actionLabel: l?.nudgeWeeklyCheckInAction ?? 'Voir mon Pulse',
        triggeredAt: now,
        priority: NudgePriority.medium,
      ));
    }
  }

  /// Streak at risk: either (a) engagement streak > 3 && missed yesterday,
  /// or (b) no monthly check-in for current month AND day >= 28.
  static void _checkStreakAtRisk(
    List<JitaiNudge> nudges,
    int? currentStreak,
    bool? engagedYesterday,
    DateTime now,
    S? l, {
    CoachProfile? profile,
  }) {
    // (a) Original engagement streak logic
    if (currentStreak != null && engagedYesterday != null) {
      if (currentStreak > 3 && !engagedYesterday) {
        nudges.add(JitaiNudge(
          type: NudgeType.streakAtRisk,
          title: l?.nudgeStreakRiskTitle ?? 'Ta série est en danger\u00a0!',
          message: 'Tu as une série de $currentStreak\u00a0jours. '
              'Une petite action aujourd\'hui suffit pour la maintenir.', // Dynamic with streak count — not extracted
          actionRoute: '/coach/chat',
          actionLabel: l?.nudgeStreakRiskAction ?? 'Continuer ma série',
          triggeredAt: now,
          priority: NudgePriority.high,
        ));
        return; // Don't double-fire
      }
    }

    // (b) Monthly check-in streak: day >= 28 and no check-in for current month
    if (profile != null && now.day >= 28) {
      final currentMonth = DateTime(now.year, now.month);
      final hasCheckInThisMonth = profile.checkIns.any(
        (c) =>
            c.month.year == currentMonth.year &&
            c.month.month == currentMonth.month,
      );
      if (!hasCheckInThisMonth) {
        final lastDayOfMonth =
            DateTime(now.year, now.month + 1, 0).day;
        final daysLeft = lastDayOfMonth - now.day;
        final totalCheckIns = profile.checkIns.length;
        nudges.add(JitaiNudge(
          type: NudgeType.streakAtRisk,
          title: l?.streakAtRiskTitle ?? 'Ta s\u00e9rie est en jeu\u00a0!',
          message: l?.streakAtRiskBody(daysLeft, totalCheckIns) ??
              'Il te reste $daysLeft\u00a0jour${daysLeft > 1 ? 's' : ''} '
                  'pour maintenir ta s\u00e9rie de $totalCheckIns\u00a0mois.',
          actionRoute: '/coach/chat?topic=monthlyCheckIn',
          actionLabel: l?.nudgeStreakRiskAction ?? 'Faire mon point du mois',
          triggeredAt: now,
          priority: NudgePriority.high,
        ));
      }
    }
  }

  /// Goal deadline approaching: target date within 30 days.
  static void _checkGoalDeadlineApproaching(
    List<JitaiNudge> nudges,
    List<UserGoal>? goals,
    DateTime now,
    S? l,
  ) {
    if (goals == null || goals.isEmpty) return;

    for (final goal in goals) {
      if (goal.targetDate == null || goal.isCompleted) continue;

      final daysLeft = goal.targetDate!.difference(now).inDays;
      if (daysLeft > 0 && daysLeft <= 30) {
        // Sanitize description
        final desc = goal.description.length > 50
            ? '${goal.description.substring(0, 50)}…'
            : goal.description;

        nudges.add(JitaiNudge(
          type: NudgeType.goalDeadlineApproaching,
          title: l?.nudgeGoalApproachingTitle ?? 'Ton objectif approche',
          message: '«\u00a0$desc\u00a0» — '
              'il reste $daysLeft\u00a0jour${daysLeft > 1 ? 's' : ''}. '
              'As-tu avancé sur ce sujet\u00a0?', // Dynamic with goal desc/days — not extracted
          actionRoute: '/coach/chat',
          actionLabel: l?.nudgeGoalApproachingAction ?? 'En parler au coach',
          triggeredAt: now,
          priority: NudgePriority.medium,
        ));
        // Only one goal nudge at a time
        break;
      }
    }
  }

  /// FHS dropped > 5 points since last recorded score.
  static void _checkFhsDropped(
    List<JitaiNudge> nudges,
    double? fhsScore,
    SharedPreferences sp,
    DateTime now,
    S? l,
  ) {
    if (fhsScore == null) return;

    final lastFhs = sp.getDouble(_lastFhsKey);
    if (lastFhs == null) return;

    final drop = lastFhs - fhsScore;
    if (drop > 5) {
      nudges.add(JitaiNudge(
        type: NudgeType.fhsDropped,
        title: l?.nudgeFhsDroppedTitle ?? 'Ton score santé a baissé',
        message: 'Ton Financial Health Score a perdu '
            '${drop.round()}\u00a0points. '
            'Voyons ensemble ce qui pourrait expliquer ce changement.', // Dynamic with drop amount — not extracted
        actionRoute: '/pulse',
        actionLabel: l?.nudgeFhsDroppedAction ?? 'Comprendre la baisse',
        triggeredAt: now,
        priority: NudgePriority.high,
      ));
    }
  }

  // ── Birthday message helpers ────────────────────────────────

  /// Returns an age-relevant message for milestone birthdays, or null.
  static String? _birthdayMessage(int age) {
    if (age == 25) {
      return 'C\'est l\'année où tes cotisations LPP commencent\u00a0! '
          'Un bon moment pour comprendre ta prévoyance.';
    }
    if (age == 30) {
      return 'À 30\u00a0ans, le 3e pilier devient un allié fiscal puissant. '
          'As-tu maximisé tes versements\u00a0?';
    }
    if (age == 35) {
      return 'Ta bonification LPP passe à 10\u00a0%. '
          'C\'est le moment d\'envisager un rachat si tu as des lacunes.';
    }
    if (age == 40) {
      return 'À mi-parcours professionnel, ton 2e pilier accélère. '
          'Vérifie que ta caisse travaille bien pour toi.';
    }
    if (age == 45) {
      return 'Ta bonification LPP passe à 15\u00a0%. '
          'Un rachat maintenant pourrait réduire significativement tes impôts.';
    }
    if (age == 50) {
      return 'La retraite se dessine dans 15\u00a0ans. '
          'C\'est le moment idéal pour une simulation complète.';
    }
    if (age == 55) {
      return 'Ta bonification LPP atteint 18\u00a0% — le maximum\u00a0! '
          'La question rente vs capital devient concrète.';
    }
    if (age == 58) {
      return 'Des caisses de pension permettent la retraite anticipée dès 58\u00a0ans. '
          'As-tu simulé les différents scénarios\u00a0?';
    }
    if (age == 60) {
      return 'Plus que 5\u00a0ans avant l\'âge de référence. '
          'C\'est le bon moment pour finaliser ta stratégie de retrait.';
    }
    if (age == 63) {
      return 'Tu peux anticiper ta rente AVS dès cette année (LAVS art.\u00a040). '
          'Attention\u00a0: chaque année d\'anticipation réduit ta rente '
          'd\'environ 6 à 7\u00a0%, selon le barème en vigueur (LAVS art.\u00a040).';
    }
    if (age == reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble()).toInt()) {
      return 'C\'est l\'année de référence AVS\u00a0! '
          'Vérifie que ta demande de rente est en cours.';
    }
    return null;
  }
}
