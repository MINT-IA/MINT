/// Local history of the 4-axis confidence score.
///
/// D5 — North Star « évolution visible » (« toi d'avant vs toi maintenant »,
/// mesuré en compréhension). This is the invisible socle: it persists one
/// dated [ConfidencePoint] per day so a later unit can draw the confidence
/// curve on « Ton histoire ».
///
/// Storage contract:
/// - Local only (`SharedPreferences`), key [storageKey]. Never synced to the
///   backend — the axes are derived scores but the series is still a device
///   history the user never asked to upload.
/// - De-duplicated by calendar day: the latest measurement of a given day wins
///   (mirrors the monthly `score_history_v1` replace semantics).
/// - Capped at [_capDays] most-recent days.
/// - Cleared as part of the reset contract via
///   `ReportPersistenceService.clearCoachHistory()`.
///
/// The curve rendering (next unit) is responsible for showing a series that
/// never regresses by simple inaction (North Star principle 5): it should plot
/// a monotonic view (e.g. running max of `combined`, or a non-decaying axis),
/// not the raw daily `combined`, which can dip as freshness decays. Storing the
/// raw axes here keeps the socle honest and leaves that choice to the widget.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/confidence_point.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

class ConfidenceHistoryService {
  ConfidenceHistoryService._();

  /// SharedPreferences key. Exposed so the reset contract can remove it.
  static const String storageKey = 'confidence_history_v1';

  /// Maximum number of dated points kept (oldest dropped first).
  static const int _capDays = 90;

  /// Passive capture trigger(s): recorded by hydration, not by a user action.
  /// A passive capture must not downgrade an explicit event's trigger recorded
  /// the same day (the trigger names the milestone on the curve).
  static const Set<String> _passiveTriggers = {'profile_load'};

  /// Merge [point] into [existing]: keep one point per calendar day, chronological
  /// order, capped to the [_capDays] most recent days.
  ///
  /// Same-day rule: the latest measurement of the day wins, EXCEPT a passive
  /// [_passiveTriggers] capture never replaces an explicit-event point recorded
  /// the same day — so a next-morning `profile_load` cannot erase yesterday
  /// evening's `document_scan` milestone.
  ///
  /// Pure function — no I/O — so the de-dup / cap / priority logic is testable.
  static List<ConfidencePoint> mergePoint(
    List<ConfidencePoint> existing,
    ConfidencePoint point,
  ) {
    final byDay = <String, ConfidencePoint>{};
    for (final p in existing) {
      byDay[p.dayKey] = p;
    }
    final sameDay = byDay[point.dayKey];
    final passiveOverExplicit = sameDay != null &&
        _passiveTriggers.contains(point.trigger) &&
        !_passiveTriggers.contains(sameDay.trigger);
    if (!passiveOverExplicit) {
      byDay[point.dayKey] = point;
    }

    final merged = byDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (merged.length > _capDays) {
      return merged.sublist(merged.length - _capDays);
    }
    return merged;
  }

  /// Record a confidence measurement. Fire-and-forget in production; returns a
  /// Future so hydration paths and tests can await a deterministic write.
  ///
  /// Self-contained read-modify-write (deliberately NOT chained on a shared
  /// static future): a shared write chain deadlocks widget tests, because an
  /// awaited hydration record can end up waiting on a fire-and-forget record
  /// scheduled inside a `pumpAndSettle` fake-async zone that never resolves in
  /// real async. Concurrency safety is provided by [mergePoint] instead: same
  /// calendar day de-dups (last write wins, with explicit-event trigger
  /// priority), so a rare interleaving loses at most one same-day trigger, not a
  /// point — acceptable for a sparse 90-day curve.
  ///
  /// Skips non-finite or non-positive `combined` scores so an empty/identity
  /// profile does not seed a meaningless origin point.
  static Future<void> record(
    EnhancedConfidence confidence, {
    required String trigger,
    DateTime? now,
  }) async {
    final combined = confidence.combined;
    if (!combined.isFinite || combined <= 0) return;
    final point = ConfidencePoint(
      date: now ?? DateTime.now(),
      combined: combined,
      completeness: confidence.completeness,
      accuracy: confidence.accuracy,
      freshness: confidence.freshness,
      understanding: confidence.understanding,
      trigger: trigger,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = _decode(prefs.getString(storageKey));
      final merged = mergePoint(existing, point);
      await prefs.setString(
        storageKey,
        json.encode(merged.map((p) => p.toJson()).toList()),
      );
    } catch (e) {
      // Never surface a history-write failure to the user.
      debugPrint('[ConfidenceHistory] record failed: $e');
    }
  }

  /// Load the persisted confidence history, chronological (oldest first).
  static Future<List<ConfidencePoint>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _decode(prefs.getString(storageKey));
    } catch (e) {
      debugPrint('[ConfidenceHistory] load failed: $e');
      return const [];
    }
  }

  /// Erase the confidence history (reset contract).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  static List<ConfidencePoint> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => ConfidencePoint.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      debugPrint('[ConfidenceHistory] decode failed: $e');
      return const [];
    }
  }
}
