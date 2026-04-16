/// Lightweight session snapshot for "Depuis ta dernière visite" delta display.
///
/// Persists 3 key metrics on app pause. On resume, diffs against current
/// state to show what changed. Uses SharedPreferences — no backend needed.
///
/// See: MINT_FINAL_EXECUTION_SYSTEM.md §13.12 (Chantier 5)
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal snapshot of the user's financial state at a point in time.
class SessionSnapshot {
  final double confidenceScore;
  final double monthlyRetirementIncome;
  final double fhsScore;
  final DateTime savedAt;

  const SessionSnapshot({
    required this.confidenceScore,
    required this.monthlyRetirementIncome,
    required this.fhsScore,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'confidenceScore': confidenceScore,
    'monthlyRetirementIncome': monthlyRetirementIncome,
    'fhsScore': fhsScore,
    'savedAt': savedAt.toIso8601String(),
  };

  factory SessionSnapshot.fromJson(Map<String, dynamic> json) =>
      SessionSnapshot(
        confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0,
        monthlyRetirementIncome:
            (json['monthlyRetirementIncome'] as num?)?.toDouble() ?? 0,
        fhsScore: (json['fhsScore'] as num?)?.toDouble() ?? 0,
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Delta between two snapshots. Only non-zero deltas are meaningful.
class SessionDelta {
  final double confidenceDelta;
  final double retirementIncomeDelta;
  final double fhsDelta;
  final Duration timeSinceLastVisit;

  /// Why the delta happened: 'inaction', 'macro', or 'user_action'.
  final String cause;

  /// Linear extrapolation: projected retirement income in 30 days
  /// if nothing changes. Only meaningful when cause == 'inaction'.
  final double? projected30d;

  /// Linear extrapolation: projected retirement income in 6 months
  /// if nothing changes. Only meaningful when cause == 'inaction'.
  final double? projected6m;

  const SessionDelta({
    required this.confidenceDelta,
    required this.retirementIncomeDelta,
    required this.fhsDelta,
    required this.timeSinceLastVisit,
    this.cause = 'inaction',
    this.projected30d,
    this.projected6m,
  });

  /// True if any delta is significant enough to show to the user.
  bool get isSignificant =>
      confidenceDelta.abs() >= 3 ||
      retirementIncomeDelta.abs() >= 50 ||
      fhsDelta.abs() >= 2;
}

/// Persists and loads session snapshots via SharedPreferences.
class SessionSnapshotService {
  static const _key = 'mint_session_snapshot';

  /// Save current state as the session snapshot.
  /// Called on AppLifecycleState.paused.
  static Future<void> save(SessionSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // Never crash on persistence failure.
    }
  }

  /// Load the previous session snapshot.
  /// Returns null if no prior snapshot exists (first launch).
  static Future<SessionSnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return SessionSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Compute delta between previous snapshot and current values.
  static SessionDelta computeDelta({
    required SessionSnapshot previous,
    required double currentConfidence,
    required double currentMonthlyRetirement,
    required double currentFhs,
  }) {
    return SessionDelta(
      confidenceDelta: currentConfidence - previous.confidenceScore,
      retirementIncomeDelta:
          currentMonthlyRetirement - previous.monthlyRetirementIncome,
      fhsDelta: currentFhs - previous.fhsScore,
      timeSinceLastVisit: DateTime.now().difference(previous.savedAt),
    );
  }
}
