/// Financial Health Score Service — Sprint S54.
///
/// Wraps FRI (4-axis: L/F/R/S) with daily freshness, trends, and persistence.
/// WHOOP-inspired daily engagement metric.
///
/// Pure computation layer — no Provider dependency.
/// Provider wraps this in a later step.
///
/// Persistence: SharedPreferences with JSON serialization
/// (same pattern as ConversationStore).
///
/// Sources: LAVS art. 21-29, LPP art. 14-16, LIFD art. 38.
/// Outil educatif — ne constitue pas un conseil financier (LSFin).
library;

import 'dart:convert';

import 'package:mint_mobile/models/fhs_daily_score.dart';
import 'package:mint_mobile/services/financial_core/fri_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for FHS history.
const String kFhsHistoryKey = '_fhs_history';

/// Maximum number of days to retain in history.
const int kFhsMaxHistoryDays = 90;

/// Trend threshold: delta must exceed this to count as up/down.
const double kFhsTrendThreshold = 2.0;

/// Service to compute and persist daily Financial Health Scores.
///
/// Usage:
/// ```dart
/// final service = FinancialHealthScoreService(prefs);
/// final fhs = await service.computeDaily(friBreakdown);
/// ```
class FinancialHealthScoreService {
  final SharedPreferences _prefs;

  FinancialHealthScoreService(this._prefs);

  // ═══════════════════════════════════════════════════════════════
  //  Public API
  // ═══════════════════════════════════════════════════════════════

  /// Compute today's FHS from an FRI breakdown.
  ///
  /// - Loads historical scores from SharedPreferences.
  /// - Computes trend and deltas vs yesterday / 7 days ago.
  /// - Persists today's score to history (prunes to [kFhsMaxHistoryDays]).
  /// - Returns the computed [FhsDailyScore].
  Future<FhsDailyScore> computeDaily(FriBreakdown fri) async {
    return computeDailyAt(fri, DateTime.now());
  }

  /// Compute FHS for a specific date (testable entry point).
  ///
  /// Same as [computeDaily] but accepts an explicit [now] timestamp.
  Future<FhsDailyScore> computeDailyAt(FriBreakdown fri, DateTime now) async {
    final history = _loadHistory();

    final deltaYesterday = _computeDelta(fri.total, history, 1);
    final deltaWeek = _computeDelta(fri.total, history, 7);
    final trend = _computeTrend(deltaYesterday);

    final fhs = FhsDailyScore(
      score: fri.total,
      level: FhsDailyScore.levelFromScore(fri.total),
      trend: trend,
      deltaVsYesterday: deltaYesterday,
      deltaVsWeekAgo: deltaWeek,
      computedAt: now,
      liquidite: fri.liquidite,
      fiscalite: fri.fiscalite,
      retraite: fri.retraite,
      risque: fri.risque,
    );

    // Persist: append today's score and prune old entries.
    _appendAndSave(fhs, history);

    return fhs;
  }

  /// Retrieve the last [days] scores from history.
  ///
  /// Returns newest-first. Returns empty list if no history.
  List<FhsDailyScore> getHistory(int days) {
    final history = _loadHistory();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final filtered = history
        .map((e) => FhsDailyScore.fromJson(e))
        .where((s) => s.computedAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.computedAt.compareTo(a.computedAt));
    return filtered;
  }

  /// Return the raw history length (for testing).
  int get historyLength => _loadHistory().length;

  // ═══════════════════════════════════════════════════════════════
  //  Persistence (SharedPreferences + JSON)
  // ═══════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> _loadHistory() {
    final raw = _prefs.getString(kFhsHistoryKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  void _saveHistory(List<Map<String, dynamic>> history) {
    _prefs.setString(kFhsHistoryKey, jsonEncode(history));
  }

  void _appendAndSave(FhsDailyScore fhs, List<Map<String, dynamic>> history) {
    history.add(fhs.toJson());

    // Prune: keep only the most recent kFhsMaxHistoryDays entries.
    if (history.length > kFhsMaxHistoryDays) {
      // Sort by date ascending, remove oldest.
      history.sort((a, b) {
        final da = DateTime.parse(a['computedAt'] as String);
        final db = DateTime.parse(b['computedAt'] as String);
        return da.compareTo(db);
      });
      history.removeRange(0, history.length - kFhsMaxHistoryDays);
    }

    _saveHistory(history);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Trend & Delta computation
  // ═══════════════════════════════════════════════════════════════

  /// Compute delta between today's score and the score [daysAgo] days back.
  ///
  /// Returns 0.0 if no historical entry exists for that day.
  /// Searches the most recent entry within [daysAgo] +-1 day tolerance.
  double _computeDelta(
    double todayScore,
    List<Map<String, dynamic>> history,
    int daysAgo,
  ) {
    if (history.isEmpty) return 0.0;

    final target = DateTime.now().subtract(Duration(days: daysAgo));
    Map<String, dynamic>? closest;
    var closestDiff = 2; // tolerance: max 1 day

    for (final entry in history) {
      final entryDate = DateTime.parse(entry['computedAt'] as String);
      final diff = (entryDate.difference(target).inDays).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closest = entry;
      }
    }

    if (closest == null) return 0.0;
    final pastScore = (closest['score'] as num).toDouble();
    return double.parse((todayScore - pastScore).toStringAsFixed(2));
  }

  /// Determine trend from delta vs yesterday.
  ///
  /// - delta > +[kFhsTrendThreshold] → up
  /// - delta < -[kFhsTrendThreshold] → down
  /// - otherwise → stable
  static FhsTrend _computeTrend(double deltaVsYesterday) {
    if (deltaVsYesterday > kFhsTrendThreshold) return FhsTrend.up;
    if (deltaVsYesterday < -kFhsTrendThreshold) return FhsTrend.down;
    return FhsTrend.stable;
  }
}
