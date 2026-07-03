import 'package:mint_mobile/models/coach_profile.dart';
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

  /// Ledger field freshness categories used when no immutable BiographyFact is
  /// available and the profile provenance maps are the freshest source.
  static const Map<String, String> kFieldFreshnessCategory = {
    // Identity and life-shape fields change by explicit life event, not decay.
    'birthYear': 'static',
    'dateOfBirth': 'static',
    'householdType': 'static',
    'employmentStatus': 'static',
    'goal': 'static',
    'targetRetirementAge': 'static',
    'gender': 'static',
    'arrivalAge': 'static',
    'residencePermit': 'static',
    'nationality': 'static',
    'has2ndPillar': 'static',
    'hasVoluntaryLpp': 'static',
    'nombreEnfants': 'static',
    'financialLiteracyLevel': 'static',
    'primaryFocus': 'static',
    'conjoint.invitationLevel': 'static',

    // Income / tax / pension values are generally refreshed annually.
    'canton': 'annual',
    'commune': 'annual',
    'incomeNetMonthly': 'annual',
    'incomeNetYearly': 'annual',
    'incomeGrossMonthly': 'annual',
    'incomeGrossYearly': 'annual',
    'selfEmployedNetIncome': 'annual',
    'employmentRate': 'annual',
    'annualBonus': 'annual',
    'salaireBrutMensuel': 'annual',
    'prevoyance.avoirLppTotal': 'annual',
    'prevoyance.avoirLppObligatoire': 'annual',
    'prevoyance.avoirLppSurobligatoire': 'annual',
    'prevoyance.salaireAssure': 'annual',
    'prevoyance.rachatMaximum': 'annual',
    'prevoyance.renteAVSEstimeeMensuelle': 'annual',
    'prevoyance.projectedRenteLpp': 'annual',
    'parentAnnualRetirementIncome': 'annual',
    'parentAnnualLivingCosts': 'volatile',
    'prevoyance.dateRachats': 'static',
    'avoirLpp': 'annual',
    'avoirLppObligatoire': 'annual',
    'avoirLppSurobligatoire': 'annual',
    'lppInsuredSalary': 'annual',
    'lppBuybackMax': 'annual',
    'pillar3aAnnual': 'annual',
    'pillar3aBalance': 'annual',
    'savingsMonthly': 'annual',
    'patrimoine.epargneLiquide': 'annual',
    'patrimoine.investissements': 'annual',
    'patrimoine.deviseInvestissements': 'static',
    'patrimoine.propertyMarketValue': 'annual',
    'patrimoine.monthlyRent': 'volatile',
    'patrimoine.mortgageCapacity': 'volatile',
    'patrimoine.estimatedMonthlyPayment': 'volatile',
    'totalSavings': 'annual',
    'wealthEstimate': 'annual',
    'spouseBirthYear': 'static',
    'spouseIncomeNetMonthly': 'annual',
    'spouseAvsContributionYears': 'annual',
    'hasAvsGaps': 'annual',
    'avsContributionYears': 'annual',

    // Debt and mortgage balances/rates can become stale faster.
    'hasDebt': 'volatile',
    'totalDebt': 'volatile',
    'dettes.totalDettes': 'volatile',
    'dettes.creditConsommation': 'volatile',
    'dettes.leasing': 'volatile',
    'dettes.hypotheque': 'volatile',
    'dettes.autresDettes': 'volatile',
    'dettes.tauxHypotheque': 'volatile',
    'dettes.tauxCreditConso': 'volatile',
    'dettes.tauxLeasing': 'volatile',
    'dettes.mensualiteHypotheque': 'volatile',
    'dettes.mensualiteCreditConso': 'volatile',
    'dettes.mensualiteLeasing': 'volatile',
    'dettes.echeanceHypotheque': 'static',
    'dettes.echeanceCreditConso': 'static',
    'dettes.echeanceLeasing': 'static',
    'dettes.rangHypotheque': 'static',
    'dettes.amortissementIndirect': 'static',
    'patrimoine.mortgageBalance': 'volatile',
    'patrimoine.mortgageRate': 'volatile',
    'depenses.loyer': 'volatile',
    'depenses.assuranceMaladie': 'annual',
    'depenses.electricite': 'volatile',
    'depenses.transport': 'volatile',
    'depenses.telecom': 'volatile',
    'depenses.fraisMedicaux': 'volatile',
    'depenses.autresDepensesFixes': 'volatile',
    'conjoint.nationality': 'static',
    'conjoint.isFatcaResident': 'static',
    'conjoint.canContribute3a': 'static',
    'conjoint.arrivalAge': 'static',
    'goalA': 'static',
    'goalsB': 'static',
    'goalsB[]': 'static',
    'plannedContributions': 'volatile',
    'plannedContributions[]': 'volatile',
  };

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

  /// Freshness for a CoachProfile ledger field path.
  ///
  /// This is the synchronous adapter for runtime surfaces that already have a
  /// hydrated CoachProfile but not an async BiographyRepository lookup.
  static double weightForField(
    String fieldPath,
    CoachProfile profile,
    DateTime now,
  ) {
    final category = kFieldFreshnessCategory[fieldPath] ?? 'annual';
    if (category == 'static') return 1.0;

    final updatedAt = profile.dataTimestamps[fieldPath];
    if (updatedAt == null) return _floor;

    return weight(
      BiographyFact(
        id: 'profile:$fieldPath',
        factType: _factTypeForFieldPath(fieldPath),
        fieldPath: fieldPath,
        value: '',
        source: _factSourceFromProfile(profile.dataSources[fieldPath]),
        sourceDate: profile.dataSourceDates[fieldPath],
        createdAt: updatedAt,
        updatedAt: updatedAt,
        freshnessCategory: category,
      ),
      now,
    );
  }

  static FactType _factTypeForFieldPath(String fieldPath) {
    if (fieldPath.contains('mortgage')) return FactType.mortgageDebt;
    if (fieldPath.contains('avoirLpp') ||
        fieldPath.contains('lpp') ||
        fieldPath.contains('Lpp')) {
      return FactType.lppCapital;
    }
    if (fieldPath.contains('3a')) return FactType.threeACapital;
    if (fieldPath.contains('avs') || fieldPath.contains('Avs')) {
      return FactType.avsContributionYears;
    }
    if (fieldPath == 'canton' || fieldPath == 'commune') {
      return FactType.canton;
    }
    if (fieldPath.contains('employment')) return FactType.employmentStatus;
    if (fieldPath.contains('household') || fieldPath.contains('conjoint')) {
      return FactType.civilStatus;
    }
    return FactType.salary;
  }

  static FactSource _factSourceFromProfile(ProfileDataSource? source) {
    return switch (source) {
      ProfileDataSource.certificate => FactSource.document,
      ProfileDataSource.openBanking => FactSource.document,
      ProfileDataSource.crossValidated => FactSource.userEdit,
      ProfileDataSource.userInput => FactSource.userInput,
      ProfileDataSource.estimated || null => FactSource.coach,
    };
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
