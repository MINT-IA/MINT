/// Weekly Recap Service — Sprint S59.
///
/// Generates a structured weekly summary of user financial activity,
/// goals, budget status, and confidence progress.
///
/// This service provides the S59 data model (RecapBudget, RecapAction,
/// RecapProgress) over the top of the engagement / goal tracking layer
/// introduced in S58.
///
/// Pure static methods — no Provider dependency, injectable SharedPreferences.
///
/// Outil éducatif — ne constitue pas un conseil financier (LSFin).
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/goal_tracker_service.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';

// ════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════════

/// Budget summary for the recap week, derived from CoachProfile.
class RecapBudget {
  /// Estimated total spent (monthly expenses as reported in profile).
  final double totalSpent;

  /// Estimated monthly income (gross → net at 80%).
  final double totalIncome;

  /// Estimated amount available after expenses (income − expenses).
  final double savedAmount;

  /// Savings rate relative to estimated net income (0.0–1.0).
  final double savingsRate;

  const RecapBudget({
    required this.totalSpent,
    required this.totalIncome,
    required this.savedAmount,
    required this.savingsRate,
  });
}

/// A CapMemory-compatible action record for the recap.
class RecapAction {
  /// Unique action identifier.
  final String actionId;

  /// When the action was completed.
  final DateTime completedAt;

  /// Cap identifier (e.g. '3a', 'lpp', 'budget').
  final String capId;

  const RecapAction({
    required this.actionId,
    required this.completedAt,
    required this.capId,
  });
}

/// Confidence / FRI progression over the week.
class RecapProgress {
  /// Confidence score at week start (0–100).
  final double confidenceBefore;

  /// Confidence score at week end (0–100).
  final double confidenceAfter;

  /// Net delta (confidenceAfter − confidenceBefore).
  final double delta;

  const RecapProgress({
    required this.confidenceBefore,
    required this.confidenceAfter,
    required this.delta,
  });
}

/// Full weekly recap output.
class WeeklyRecap {
  /// Monday 00:00 of the recap window.
  final DateTime weekStart;

  /// Sunday 00:00 of the recap window.
  final DateTime weekEnd;

  /// Budget breakdown (null when profile lacks salary / expense data).
  final RecapBudget? budget;

  /// Engagement-backed actions this week (one per engaged day).
  final List<RecapAction> actions;

  /// Confidence progression (null when no FHS delta available).
  final RecapProgress? progress;

  /// ARB key references for display-layer highlights.
  final List<String> highlights;

  /// Intent tag suggesting next week's focus (e.g. '3a', 'lpp', 'budget').
  final String? nextWeekFocus;

  /// Number of active goals tracked this week.
  final int activeGoals;

  /// Compliance disclaimer (always present).
  final String disclaimer;

  /// Legal references (always present).
  final List<String> sources;

  const WeeklyRecap({
    required this.weekStart,
    required this.weekEnd,
    this.budget,
    required this.actions,
    this.progress,
    required this.highlights,
    this.nextWeekFocus,
    required this.activeGoals,
    required this.disclaimer,
    required this.sources,
  });
}

// ════════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════════

/// Generates a [WeeklyRecap] from profile data, engagement history,
/// goals, and optional FHS delta.
///
/// All methods are static. Dependencies injected via parameters.
class WeeklyRecapService {
  WeeklyRecapService._();

  static const _disclaimer =
      'Ce récapitulatif est un outil éducatif et ne constitue '
      'pas un conseil financier.';

  static const _sources = <String>[
    'LAVS\u00a0art.\u00a021-29',
    'LPP\u00a0art.\u00a014-16',
  ];

  /// Generate a [WeeklyRecap] for the 7-day window starting from [weekStart].
  ///
  /// [profile] — user profile (may be minimal).
  /// [prefs] — injectable SharedPreferences (defaults to getInstance()).
  /// [now] — override for testing (defaults to DateTime.now()).
  /// [fhsDelta] — FHS score change for the week (null if unavailable).
  static Future<WeeklyRecap> generate({
    required CoachProfile profile,
    required SharedPreferences prefs,
    DateTime? now,
    double? fhsDelta,
  }) async {
    final effectiveNow = now ?? DateTime.now();

    // ── Week boundaries ──────────────────────────────────────
    final monday = _normalizeToMonday(effectiveNow);
    final sunday = monday.add(const Duration(days: 6));

    // ── Engagement → actions list ────────────────────────────
    final actions = await _buildActions(
      sp: prefs,
      monday: monday,
      now: effectiveNow,
    );

    // ── Goals ────────────────────────────────────────────────
    final goals = await GoalTrackerService.activeGoals(prefs: prefs);
    final activeGoalCount = goals.length;

    // ── Budget ───────────────────────────────────────────────
    final budget = _buildBudget(profile);

    // ── Progress ─────────────────────────────────────────────
    RecapProgress? progress;
    if (fhsDelta != null) {
      // We only have the delta; reconstruct a plausible before/after pair.
      // The service never promises absolute values — use 0 baseline when unknown.
      progress = RecapProgress(
        confidenceBefore: 0,
        confidenceAfter: fhsDelta,
        delta: fhsDelta,
      );
    }

    // ── Highlights (ARB key references) ─────────────────────
    final highlights = _buildHighlightKeys(
      actionsCount: actions.length,
      budget: budget,
      activeGoalCount: activeGoalCount,
      fhsDelta: fhsDelta,
    );

    // ── Insights from memory → additional highlights ─────────
    final insights = await CoachMemoryService.getInsights(prefs: prefs);
    final recentInsights = insights
        .where((i) => i.createdAt.isAfter(monday.subtract(const Duration(days: 1))))
        .toList();
    if (recentInsights.isNotEmpty && !highlights.contains('recapHighlightsTitle')) {
      highlights.add('recapHighlightsTitle');
    }

    // ── Next week focus ──────────────────────────────────────
    final nextFocus = _deriveNextFocus(
      budget: budget,
      activeGoalCount: activeGoalCount,
      fhsDelta: fhsDelta,
      goals: goals,
    );

    return WeeklyRecap(
      weekStart: monday,
      weekEnd: sunday,
      budget: budget,
      actions: actions,
      progress: progress,
      highlights: highlights,
      nextWeekFocus: nextFocus,
      activeGoals: activeGoalCount,
      disclaimer: _disclaimer,
      sources: _sources,
    );
  }

  // ── Private helpers ────────────────────────────────────────────

  /// Normalize any DateTime to the Monday 00:00 of its week.
  static DateTime _normalizeToMonday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final daysFromMonday = d.weekday - DateTime.monday;
    return d.subtract(Duration(days: daysFromMonday));
  }

  /// Build a [RecapAction] per engaged day in the current week.
  static Future<List<RecapAction>> _buildActions({
    required SharedPreferences sp,
    required DateTime monday,
    required DateTime now,
  }) async {
    final stored =
        sp.getStringList('_daily_engagement_dates')?.toSet() ?? <String>{};
    final actions = <RecapAction>[];

    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      if (day.isAfter(now)) break;
      final key = _dateKey(day);
      if (stored.contains(key)) {
        actions.add(RecapAction(
          actionId: 'engagement_$key',
          completedAt: day,
          capId: 'engagement',
        ));
      }
    }

    return actions;
  }

  /// Build [RecapBudget] from profile income/expense data.
  ///
  /// Returns null when data is insufficient.
  static RecapBudget? _buildBudget(CoachProfile profile) {
    final grossMonthly = profile.salaireBrutMensuel;
    if (grossMonthly <= 0) return null;

    final totalExpenses = profile.depenses.totalMensuel;
    if (totalExpenses <= 0) return null;

    // Approximate net income (Swiss deductions ~20%: AVS/LPP/LAMal).
    final netIncome = grossMonthly * 0.80;
    final saved = (netIncome - totalExpenses).clamp(0.0, double.infinity);
    final savingsRate = netIncome > 0 ? saved / netIncome : 0.0;

    return RecapBudget(
      totalSpent: totalExpenses,
      totalIncome: netIncome,
      savedAmount: saved,
      savingsRate: savingsRate,
    );
  }

  /// Build ARB key list representing the highlights for this week.
  static List<String> _buildHighlightKeys({
    required int actionsCount,
    required RecapBudget? budget,
    required int activeGoalCount,
    required double? fhsDelta,
  }) {
    final keys = <String>[];

    // Budget
    if (budget != null) {
      keys.add('recapBudgetTitle');
    }

    // Actions
    if (actionsCount > 0) {
      keys.add('recapActionsTitle');
    } else {
      keys.add('recapActionsNone');
    }

    // Goals
    if (activeGoalCount > 0) {
      keys.add('recapProgressTitle');
    }

    // FHS progress
    if (fhsDelta != null && fhsDelta != 0) {
      keys.add('recapProgressDelta');
    }

    return keys;
  }

  /// Derive a next-week intent tag from profile state.
  static String? _deriveNextFocus({
    required RecapBudget? budget,
    required int activeGoalCount,
    required double? fhsDelta,
    required List<UserGoal> goals,
  }) {
    // Over budget → focus on budget
    if (budget != null && budget.savingsRate < 0.10) return 'budget';

    // Negative FHS delta → focus on most relevant goal category
    if (fhsDelta != null && fhsDelta < -2.0) {
      if (goals.isNotEmpty) return goals.first.category;
      return 'retraite';
    }

    // Under-budget with savings room → suggest 3a
    if (budget != null && budget.savingsRate > 0.30) return '3a';

    // Active goals → suggest the most recent one
    if (goals.isNotEmpty) return goals.first.category;

    return null;
  }

  /// Format DateTime to yyyy-MM-dd (matching DailyEngagementService).
  static String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
