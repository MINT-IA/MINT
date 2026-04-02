/// Snapshot service — captures financial health at key moments.
///
/// Sprint S33 — Arbitrage Phase 2 + Snapshots.
/// W15: Wired to backend persistence + auto-trigger on check-in.
///
/// Stores snapshots in a local cache AND syncs to backend via ApiService.
/// Each snapshot captures a point-in-time view of the user's financial state,
/// triggered by wizard completion, life event, check-in, or document scan.
///
/// Backend: POST /snapshots, GET /snapshots
library;

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';

/// A point-in-time capture of the user's financial health indicators.
class FinancialSnapshot {
  /// Unique identifier (UUID-like).
  final String id;

  /// When this snapshot was created.
  final DateTime createdAt;

  /// What triggered this snapshot (e.g. "wizard_complete", "annual_refresh",
  /// "life_event:marriage").
  final String trigger;

  /// User's age at the time of the snapshot.
  final int age;

  /// Gross annual income in CHF.
  final double grossIncome;

  /// Canton of residence (2-letter code).
  final String canton;

  /// Retirement replacement ratio (0-1, percentage of pre-retirement income).
  final double replacementRatio;

  /// Months of liquidity reserve.
  final double monthsLiquidity;

  /// Annual tax saving potential in CHF (3a, rachat LPP, etc.).
  final double taxSavingPotential;

  /// Confidence score (0-100) of the projection.
  final double confidenceScore;

  /// Number of enrichment prompts remaining.
  final int enrichmentCount;

  const FinancialSnapshot({
    required this.id,
    required this.createdAt,
    required this.trigger,
    required this.age,
    required this.grossIncome,
    required this.canton,
    required this.replacementRatio,
    required this.monthsLiquidity,
    required this.taxSavingPotential,
    required this.confidenceScore,
    required this.enrichmentCount,
  });

  /// Serialize to JSON for backend API.
  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'trigger': trigger,
        'age': age,
        'grossIncome': grossIncome,
        'canton': canton,
        'replacementRatio': replacementRatio,
        'monthsLiquidity': monthsLiquidity,
        'taxSavingPotential': taxSavingPotential,
        'confidenceScore': confidenceScore,
        'enrichmentCount': enrichmentCount,
      };

  /// Deserialize from backend JSON response (camelCase keys).
  factory FinancialSnapshot.fromJson(Map<String, dynamic> json) {
    return FinancialSnapshot(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      trigger: json['trigger'] as String? ?? 'unknown',
      age: (json['age'] as num?)?.toInt() ?? 0,
      grossIncome: (json['grossIncome'] as num?)?.toDouble() ?? 0.0,
      canton: json['canton'] as String? ?? 'VD',
      replacementRatio:
          (json['replacementRatio'] as num?)?.toDouble() ?? 0.0,
      monthsLiquidity:
          (json['monthsLiquidity'] as num?)?.toDouble() ?? 0.0,
      taxSavingPotential:
          (json['taxSavingPotential'] as num?)?.toDouble() ?? 0.0,
      confidenceScore:
          (json['confidenceScore'] as num?)?.toDouble() ?? 0.0,
      enrichmentCount:
          (json['enrichmentCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Financial snapshot storage with backend sync.
///
/// Local cache + fire-and-forget backend persistence.
/// Loads from backend at startup, syncs on create.
class SnapshotService {
  SnapshotService._();

  static List<FinancialSnapshot> _snapshots = [];

  static int _counter = 0;

  /// Create and store a new financial snapshot.
  ///
  /// Stores locally AND syncs to backend (fire-and-forget).
  /// Returns the created snapshot with a generated ID and timestamp.
  static FinancialSnapshot createSnapshot({
    required String trigger,
    required int age,
    required double grossIncome,
    required String canton,
    required double replacementRatio,
    required double monthsLiquidity,
    required double taxSavingPotential,
    required double confidenceScore,
    int enrichmentCount = 3,
  }) {
    _counter++;
    final snapshot = FinancialSnapshot(
      id: 'snap_${DateTime.now().millisecondsSinceEpoch}_$_counter',
      createdAt: DateTime.now(),
      trigger: trigger,
      age: age,
      grossIncome: grossIncome,
      canton: canton,
      replacementRatio: replacementRatio,
      monthsLiquidity: monthsLiquidity,
      taxSavingPotential: taxSavingPotential,
      confidenceScore: confidenceScore,
      enrichmentCount: enrichmentCount,
    );
    _snapshots.add(snapshot);

    // Sync to backend (fire-and-forget — local cache is primary)
    _syncToBackend(snapshot);

    return snapshot;
  }

  /// Fire-and-forget backend sync for a single snapshot.
  static Future<void> _syncToBackend(FinancialSnapshot snapshot) async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) {
        debugPrint('[Snapshot] No auth user — skipping backend sync');
        return;
      }
      // Backend expects: trigger, profileData, userId (camelCase aliases)
      await ApiService.post('/snapshots', {
        'userId': userId,
        'trigger': _normalizeBackendTrigger(snapshot.trigger),
        'profileData': {
          'age': snapshot.age,
          'gross_income': snapshot.grossIncome,
          'canton': snapshot.canton,
          'replacement_ratio': snapshot.replacementRatio,
          'months_liquidity': snapshot.monthsLiquidity,
          'tax_saving_potential': snapshot.taxSavingPotential,
          'confidence_score': snapshot.confidenceScore,
          'enrichment_count': snapshot.enrichmentCount,
        },
      });
      debugPrint('[Snapshot] Synced to backend: ${snapshot.id}');
    } catch (e) {
      debugPrint('[Snapshot] Backend sync failed: $e');
    }
  }

  /// Map Flutter trigger names to backend VALID_TRIGGERS.
  /// Backend accepts: quarterly, life_event, profile_update, check_in
  static String _normalizeBackendTrigger(String trigger) {
    if (trigger.startsWith('life_event')) return 'life_event';
    if (trigger == 'check_in' || trigger == 'monthly_check_in') {
      return 'check_in';
    }
    if (trigger == 'document_scan' || trigger == 'lpp_certificate') {
      return 'profile_update';
    }
    if (trigger == 'wizard_complete' || trigger == 'annual_refresh') {
      return 'profile_update';
    }
    // Fallback to profile_update for unknown triggers
    const validTriggers = {
      'quarterly',
      'life_event',
      'profile_update',
      'check_in',
    };
    return validTriggers.contains(trigger) ? trigger : 'profile_update';
  }

  /// Load snapshots from backend at startup.
  ///
  /// Replaces local cache with backend data. Fire-and-forget — if it fails,
  /// the local cache remains empty (will populate on next createSnapshot).
  static Future<void> loadFromBackend() async {
    try {
      final data = await ApiService.get('/snapshots?limit=50');
      final snapshotsList = data['snapshots'] as List<dynamic>?;
      if (snapshotsList != null) {
        _snapshots = snapshotsList
            .map((s) =>
                FinancialSnapshot.fromJson(s as Map<String, dynamic>))
            .toList();
        debugPrint(
            '[Snapshot] Loaded ${_snapshots.length} snapshots from backend');
      }
    } catch (e) {
      debugPrint('[Snapshot] Load from backend failed: $e');
    }
  }

  /// Retrieve the most recent snapshots, ordered by creation date descending.
  ///
  /// [limit] Maximum number of snapshots to return.
  static List<FinancialSnapshot> getSnapshots({int limit = 10}) {
    final sorted = List<FinancialSnapshot>.from(_snapshots)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  /// Delete all snapshots (for testing or reset).
  static void deleteAll() {
    _snapshots.clear();
    _counter = 0;
  }

  /// Get the evolution of a specific field over time.
  ///
  /// Returns a list of (date, value) tuples in chronological order.
  /// Supported fields: "replacementRatio", "monthsLiquidity",
  /// "taxSavingPotential", "confidenceScore", "grossIncome".
  static List<({DateTime date, double value})> getEvolution(String field) {
    final sorted = List<FinancialSnapshot>.from(_snapshots)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return sorted.map((s) {
      final value = switch (field) {
        'replacementRatio' => s.replacementRatio,
        'monthsLiquidity' => s.monthsLiquidity,
        'taxSavingPotential' => s.taxSavingPotential,
        'confidenceScore' => s.confidenceScore,
        'grossIncome' => s.grossIncome,
        _ => 0.0,
      };
      return (date: s.createdAt, value: value);
    }).toList();
  }

  // TODO(P2): Implement snapshot timeline screen (/financial-timeline)
  // Backend supports GET /snapshots with date range
  // Display: line chart of patrimoine net, replacement rate, confidence over time
}
