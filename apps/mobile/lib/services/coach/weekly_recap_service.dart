/// Weekly Recap Service — Sprint S59.
///
/// Generates a weekly financial recap from user engagement data,
/// goals, budget, and FHS trends.
///
/// Pure service — no Provider dependency.
/// All text in French (informal "tu"), educational tone.
///
/// Outil éducatif — ne constitue pas un conseil financier (LSFin).
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';
import 'package:mint_mobile/services/daily_engagement_service.dart';

// ════════════════════════════════════════════════════════════════
//  MODELS
// ════════════════════════════════════════════════════════════════

/// Budget status for the recap week.
enum RecapBudgetStatus { onTrack, overBudget, underBudget, noData }

/// A single highlight in the weekly recap.
class RecapHighlight {
  /// Icon name (emoji or icon identifier).
  final String icon;

  /// Short title for the highlight.
  final String title;

  /// Detail text (1 sentence).
  final String detail;

  const RecapHighlight({
    required this.icon,
    required this.title,
    required this.detail,
  });
}

/// Weekly recap output.
class WeeklyRecap {
  /// Monday of the recap week.
  final DateTime weekStart;

  /// Sunday of the recap week.
  final DateTime weekEnd;

  /// 3-5 sentence narrative summary (max 500 chars).
  final String summaryText;

  /// 3-5 bullet-point highlights.
  final List<RecapHighlight> highlights;

  /// Budget status for the week.
  final RecapBudgetStatus budgetStatus;

  /// Number of engagement days this week.
  final int actionsThisWeek;

  /// Number of active (non-completed) goals.
  final int activeGoals;

  /// FHS change this week (null if unavailable).
  final double? fhsDelta;

  /// 1 sentence motivational insight, educational and actionnable.
  final String motivationalInsight;

  /// Compliance disclaimer.
  final String disclaimer;

  /// Legal references (if applicable).
  final List<String> sources;

  const WeeklyRecap({
    required this.weekStart,
    required this.weekEnd,
    required this.summaryText,
    required this.highlights,
    required this.budgetStatus,
    required this.actionsThisWeek,
    required this.activeGoals,
    this.fhsDelta,
    required this.motivationalInsight,
    required this.disclaimer,
    required this.sources,
  });
}

// ════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════

/// Generates a weekly financial recap from profile, engagement,
/// goals, and FHS data.
///
/// All methods are static. Dependencies injected via parameters.
class WeeklyRecapService {
  WeeklyRecapService._();

  /// Non-breaking space used before French punctuation.
  static const _nbsp = '\u00a0';

  /// Compliance disclaimer (always present).
  static const _disclaimer =
      'Ce récapitulatif est un outil éducatif et ne constitue '
      'pas un conseil financier.';

  /// Generate the weekly recap.
  ///
  /// [profile] — user's CoachProfile (may be minimal).
  /// [weekStart] — Monday of the target week (time ignored, normalized to Monday).
  /// [now] — override for testing (defaults to DateTime.now()).
  /// [prefs] — injectable SharedPreferences for testing.
  /// [fhsDelta] — FHS score change this week (null if no FHS data).
  static Future<WeeklyRecap> generateRecap({
    required CoachProfile profile,
    required DateTime weekStart,
    DateTime? now,
    SharedPreferences? prefs,
    double? fhsDelta,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final sp = prefs ?? await SharedPreferences.getInstance();

    // Normalize weekStart to Monday 00:00
    final monday = _normalizeToMonday(weekStart);
    final sunday = monday.add(const Duration(days: 6));

    // ── Engagement data ──────────────────────────────────────
    final engagementDays = await _countEngagementDays(
      sp: sp,
      monday: monday,
      now: effectiveNow,
    );

    // ── Goals data ───────────────────────────────────────────
    final goals = await GoalTrackerService.activeGoals(prefs: sp);
    final activeGoalCount = goals.length;

    // ── Budget status ────────────────────────────────────────
    final budget = _computeBudgetStatus(profile);

    // ── Build highlights ─────────────────────────────────────
    final highlights = _buildHighlights(
      engagementDays: engagementDays,
      activeGoalCount: activeGoalCount,
      budgetStatus: budget,
      fhsDelta: fhsDelta,
      profile: profile,
    );

    // ── Build summary text ───────────────────────────────────
    final summary = _buildSummary(
      engagementDays: engagementDays,
      activeGoalCount: activeGoalCount,
      budgetStatus: budget,
      fhsDelta: fhsDelta,
      profile: profile,
    );

    // ── Motivational insight ─────────────────────────────────
    final insight = _buildMotivationalInsight(
      engagementDays: engagementDays,
      activeGoalCount: activeGoalCount,
      budgetStatus: budget,
    );

    return WeeklyRecap(
      weekStart: monday,
      weekEnd: sunday,
      summaryText: summary,
      highlights: highlights,
      budgetStatus: budget,
      actionsThisWeek: engagementDays,
      activeGoals: activeGoalCount,
      fhsDelta: fhsDelta,
      motivationalInsight: insight,
      disclaimer: _disclaimer,
      sources: const ['LAVS art. 21-29', 'LPP art. 14-16'],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ════════════════════════════════════════════════════════════

  /// Normalize any DateTime to the Monday of that week (00:00).
  static DateTime _normalizeToMonday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    // DateTime.weekday: Monday = 1, Sunday = 7
    final daysFromMonday = d.weekday - DateTime.monday;
    return d.subtract(Duration(days: daysFromMonday));
  }

  /// Count engagement days within [monday..sunday] window.
  static Future<int> _countEngagementDays({
    required SharedPreferences sp,
    required DateTime monday,
    required DateTime now,
  }) async {
    // Get recent dates (up to 7 days from now)
    final recentDates = await DailyEngagementService.recentDates(
      days: 14, // Look back enough to cover the target week
      prefs: sp,
      now: now,
    );

    // Use SharedPreferences directly for reliable week-window counting
    final stored =
        sp.getStringList('_daily_engagement_dates')?.toSet() ?? <String>{};
    // Also merge recentDates for completeness
    stored.addAll(recentDates);
    int count = 0;
    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      if (day.isAfter(now)) break;
      final key = _dateKey(day);
      if (stored.contains(key)) {
        count++;
      }
    }

    return count;
  }

  /// Format a DateTime to yyyy-MM-dd (same as DailyEngagementService).
  static String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Determine budget status from profile expenses vs estimated net income.
  ///
  /// Gross salary is converted to approximate net using a 0.80 factor
  /// (typical Swiss deductions: AVS/LPP/LAMal). Thresholds are then
  /// applied against this estimated net income.
  static RecapBudgetStatus _computeBudgetStatus(CoachProfile profile) {
    final revenuBrutMensuel = profile.salaireBrutMensuel;
    if (revenuBrutMensuel <= 0) return RecapBudgetStatus.noData;

    final depensesMensuelles = profile.depenses.totalMensuel;
    if (depensesMensuelles <= 0) return RecapBudgetStatus.noData;

    // Approximate net income (after AVS/LPP/LAMal deductions ~20%)
    final revenuNetEstime = revenuBrutMensuel * 0.80;

    // If expenses > 90% of estimated net → overBudget
    // If expenses < 70% of estimated net → underBudget, else onTrack
    final ratio = depensesMensuelles / revenuNetEstime;
    if (ratio > 0.90) return RecapBudgetStatus.overBudget;
    if (ratio < 0.70) return RecapBudgetStatus.underBudget;
    return RecapBudgetStatus.onTrack;
  }

  /// Build 3-5 highlights for the recap.
  static List<RecapHighlight> _buildHighlights({
    required int engagementDays,
    required int activeGoalCount,
    required RecapBudgetStatus budgetStatus,
    required double? fhsDelta,
    required CoachProfile profile,
  }) {
    final highlights = <RecapHighlight>[];

    // Engagement highlight
    if (engagementDays > 0) {
      highlights.add(RecapHighlight(
        icon: 'streak',
        title: 'Engagement',
        detail: 'Tu as été actif $engagementDays${_nbsp}jour${engagementDays > 1 ? 's' : ''} '
            'cette semaine.',
      ));
    } else {
      highlights.add(const RecapHighlight(
        icon: 'streak',
        title: 'Engagement',
        detail: 'Aucune activité cette semaine — chaque petit pas compte.',
      ));
    }

    // Budget highlight
    switch (budgetStatus) {
      case RecapBudgetStatus.onTrack:
        highlights.add(const RecapHighlight(
          icon: 'budget',
          title: 'Budget',
          detail: 'Tes dépenses semblent en ligne avec tes revenus.',
        ));
      case RecapBudgetStatus.overBudget:
        highlights.add(const RecapHighlight(
          icon: 'alert',
          title: 'Budget',
          detail:
              'Tes dépenses semblent élevées par rapport à tes revenus — '
              'tu pourrais envisager de revoir quelques postes.',
        ));
      case RecapBudgetStatus.underBudget:
        highlights.add(const RecapHighlight(
          icon: 'savings',
          title: 'Épargne',
          detail:
              'Tu sembles dégager une marge intéressante — '
              'as-tu pensé à renforcer ton 3e pilier$_nbsp?',
        ));
      case RecapBudgetStatus.noData:
        highlights.add(const RecapHighlight(
          icon: 'info',
          title: 'Budget',
          detail:
              'Pas encore de données budget — complète ton profil '
              'pour un récap personnalisé.',
        ));
    }

    // Goals highlight
    if (activeGoalCount > 0) {
      highlights.add(RecapHighlight(
        icon: 'target',
        title: 'Objectifs',
        detail: 'Tu suis $activeGoalCount objectif${activeGoalCount > 1 ? 's' : ''} actif${activeGoalCount > 1 ? 's' : ''}.',
      ));
    }

    // FHS highlight
    if (fhsDelta != null) {
      if (fhsDelta > 0) {
        highlights.add(RecapHighlight(
          icon: 'trending_up',
          title: 'Score financier',
          detail:
              'Ton score de santé financière a progressé de '
              '+${fhsDelta.toStringAsFixed(1)} pts cette semaine.',
        ));
      } else if (fhsDelta < -2.0) {
        highlights.add(RecapHighlight(
          icon: 'trending_down',
          title: 'Score financier',
          detail:
              'Ton score a reculé de ${fhsDelta.toStringAsFixed(1)} pts '
              '— cela pourrait être temporaire.',
        ));
      } else {
        highlights.add(const RecapHighlight(
          icon: 'stable',
          title: 'Score financier',
          detail: 'Ton score de santé financière est stable cette semaine.',
        ));
      }
    }

    return highlights;
  }

  /// Build the 3-5 sentence narrative summary (max 500 chars).
  static String _buildSummary({
    required int engagementDays,
    required int activeGoalCount,
    required RecapBudgetStatus budgetStatus,
    required double? fhsDelta,
    required CoachProfile profile,
  }) {
    final parts = <String>[];

    // Opening
    if (engagementDays >= 5) {
      parts.add('Belle semaine$_nbsp! Tu as été très actif.');
    } else if (engagementDays >= 3) {
      parts.add('Bonne semaine — tu as maintenu un rythme régulier.');
    } else if (engagementDays > 0) {
      parts.add('Cette semaine, tu as fait quelques pas en avant.');
    } else {
      parts.add('Cette semaine était calme côté finances.');
    }

    // Budget
    if (budgetStatus == RecapBudgetStatus.onTrack) {
      parts.add('Ton budget semble équilibré.');
    } else if (budgetStatus == RecapBudgetStatus.overBudget) {
      parts.add(
          'Tes dépenses semblent dépasser ta zone de confort — '
          'un coup d\'œil pourrait être utile.');
    }

    // Goals
    if (activeGoalCount > 0) {
      parts.add(
          'Tu poursuis $activeGoalCount objectif${activeGoalCount > 1 ? 's' : ''} '
          'en cours.');
    }

    // FHS
    if (fhsDelta != null && fhsDelta > 0) {
      parts.add('Ton score financier progresse$_nbsp!');
    }

    // Trim to 500 chars
    var result = parts.join(' ');
    if (result.length > 500) {
      result = '${result.substring(0, 497)}...';
    }
    return result;
  }

  /// Build one actionnable motivational insight.
  static String _buildMotivationalInsight({
    required int engagementDays,
    required int activeGoalCount,
    required RecapBudgetStatus budgetStatus,
  }) {
    if (engagementDays == 0) {
      return 'Concrètement, tu peux prendre 2${_nbsp}minutes pour '
          'vérifier ton budget — c\'est une étape concrète pour bien '
          'démarrer la semaine.';
    }

    if (budgetStatus == RecapBudgetStatus.overBudget) {
      return 'En pratique, tu peux lister tes 3 plus grosses '
          'dépenses du mois — imagine l\'impact si tu réduis '
          'un seul poste de 10${_nbsp}%.';
    }

    if (activeGoalCount == 0) {
      return 'Tu peux définir un premier objectif financier — '
          'concrètement, cela t\'aide à structurer tes prochaines '
          'décisions et à mesurer ton progrès.';
    }

    if (engagementDays >= 5) {
      return 'Bravo pour ta régularité$_nbsp! En pratique, '
          'continue sur cette lancée — chaque semaine active '
          'fait une vraie différence sur le long terme.';
    }

    return 'Chaque action compte — concrètement, même '
        '5${_nbsp}minutes par semaine peuvent faire la différence '
        'sur le long terme.';
  }
}
