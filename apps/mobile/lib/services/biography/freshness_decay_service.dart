import 'package:mint_mobile/services/biography/biography_fact.dart';

// ────────────────────────────────────────────────────────────
//  FRESHNESS DECAY SERVICE — Phase 03 / Memoire Narrative
// ────────────────────────────────────────────────────────────
//
// Two-tier freshness decay for FinancialBiography facts.
//
// Annual tier (salary, LPP, 3a, AVS, tax):
//   Full weight (1.0) for 12 months, linear decay to 0.3 at 36 months.
//   Rationale: financial data changes yearly (salary review, LPP statement).
//
// Volatile tier (mortgage debt):
//   Full weight (1.0) for 3 months, linear decay to 0.3 at 12 months.
//   Rationale: mortgage rates and balances shift more frequently.
//
// Floor at 0.3: stale data is better than no data, but heavily discounted.
//
// Reference: confidence_scorer.dart _freshnessScore (single-tier, 6mo/24mo/36mo).
// This service extends that pattern with category-aware two-tier decay.
//
// See: BIO-06, BIO-08 requirements.
// ────────────────────────────────────────────────────────────

/// Two-tier freshness decay calculation for biography facts.
///
/// All methods are static pure functions for testability and
/// determinism (no side effects, no state).
class FreshnessDecayService {
  FreshnessDecayService._();

  /// Minimum freshness weight. Stale data is still valuable
  /// but heavily discounted in confidence scoring.
  static const _floor = 0.3;

  /// Refresh threshold: facts below this weight trigger refresh prompts.
  /// Per BIO-08: 0.60 threshold.
  static const _refreshThreshold = 0.60;

  // ── Annual tier parameters ──────────────────────────────────
  /// Months of full weight for annual-category facts.
  static const _annualFullMonths = 12.0;

  /// Months at which annual-category facts hit the floor.
  static const _annualFloorMonths = 36.0;

  // ── Volatile tier parameters ────────────────────────────────
  /// Months of full weight for volatile-category facts.
  static const _volatileFullMonths = 3.0;

  /// Months at which volatile-category facts hit the floor.
  static const _volatileFloorMonths = 12.0;

  /// Calculate the freshness weight for a biography fact.
  ///
  /// Returns a value between [_floor] (0.3) and 1.0.
  /// Uses [fact.updatedAt] (when MINT last confirmed the data),
  /// NOT [fact.sourceDate] (when the original document was issued).
  ///
  /// Decay model:
  /// - Within full-weight window: 1.0
  /// - After window: linear decay from 1.0 to [_floor]
  /// - Beyond floor point: capped at [_floor]
  static double weight(BiographyFact fact, DateTime now) {
    final monthsOld = now.difference(fact.updatedAt).inDays / 30.44;

    if (fact.freshnessCategory == 'volatile') {
      return _decay(monthsOld, _volatileFullMonths, _volatileFloorMonths);
    }

    // Default: annual tier
    return _decay(monthsOld, _annualFullMonths, _annualFloorMonths);
  }

  /// Linear decay from 1.0 to [_floor] between [fullMonths] and [floorMonths].
  static double _decay(
      double monthsOld, double fullMonths, double floorMonths) {
    if (monthsOld <= fullMonths) return 1.0;
    if (monthsOld >= floorMonths) return _floor;

    // Linear interpolation: 1.0 at fullMonths -> _floor at floorMonths
    final decayRange = floorMonths - fullMonths;
    final elapsed = monthsOld - fullMonths;
    return 1.0 - (1.0 - _floor) * (elapsed / decayRange);
  }

  /// Whether a fact needs refreshing (weight below threshold).
  ///
  /// Per BIO-08: threshold is 0.60.
  /// Used by the coach to prompt users to update stale data.
  static bool needsRefresh(BiographyFact fact, DateTime now) {
    return weight(fact, now) < _refreshThreshold;
  }

  /// Determine the freshness category for a given fact type.
  ///
  /// - Annual: salary, LPP capital, LPP rachat max, 3a capital,
  ///   AVS contribution years, tax rate
  /// - Volatile: mortgage debt
  /// - Default: annual (safe fallback)
  static String categoryFor(FactType type) {
    switch (type) {
      case FactType.mortgageDebt:
        return 'volatile';
      case FactType.salary:
      case FactType.lppCapital:
      case FactType.lppRachatMax:
      case FactType.threeACapital:
      case FactType.avsContributionYears:
      case FactType.taxRate:
      case FactType.canton:
      case FactType.civilStatus:
      case FactType.employmentStatus:
      case FactType.lifeEvent:
      case FactType.userDecision:
      case FactType.coachPreference:
      case FactType.alertAcknowledged:
        return 'annual';
    }
  }
}
