/// In-memory snapshot service — captures financial health at key moments.
///
/// Sprint S33 — Arbitrage Phase 2 + Snapshots.
///
/// Stores snapshots in memory (no backend dependency for now).
/// Each snapshot captures a point-in-time view of the user's financial state,
/// triggered by wizard completion, life event, or annual refresh.
///
/// Future: snapshots will be persisted to local storage and synced to backend.
library;

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
}

/// In-memory storage for financial snapshots.
///
/// Provides static methods to create, retrieve, and analyze snapshots
/// without any backend or persistent storage dependency.
class SnapshotService {
  SnapshotService._();

  static final List<FinancialSnapshot> _snapshots = [];

  static int _counter = 0;

  /// Create and store a new financial snapshot.
  ///
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
    return snapshot;
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
}
