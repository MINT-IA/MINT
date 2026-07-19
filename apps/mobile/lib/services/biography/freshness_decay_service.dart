import 'package:mint_mobile/services/biography/biography_fact.dart';

/// Calendar-decay policy from the canonical G1 ledger matrix.
enum LedgerFreshnessTier {
  static,
  eventStatic,
  annual,
  volatile;

  String get wireName => switch (this) {
        LedgerFreshnessTier.static => 'static',
        LedgerFreshnessTier.eventStatic => 'event_static',
        LedgerFreshnessTier.annual => 'annual',
        LedgerFreshnessTier.volatile => 'volatile',
      };
}

/// A generic ledger value is either usable, stale, invalid, or owned by a
/// specialist reference selector outside calendar decay.
enum LedgerFreshnessState { current, stale, invalid, separateReference }

/// The next safe write-path for an existing non-current value.
enum LedgerReconfirmation {
  none,
  confirmAsUserInput,
  renewEvidence,
  separateReference,
  unavailable,
}

class LedgerFieldFreshnessPolicy {
  const LedgerFieldFreshnessPolicy({
    required this.tier,
    required this.allowedSourceNames,
  });

  final LedgerFreshnessTier tier;
  final Set<String> allowedSourceNames;

  bool get allowsUserReconfirmation => allowedSourceNames.contains('userInput');
}

class LedgerFreshnessAssessment<T> {
  const LedgerFreshnessAssessment({
    required this.state,
    required this.weight,
    required this.previousValue,
    required this.reconfirmation,
    this.policy,
  });

  final LedgerFreshnessState state;
  final double weight;
  final T? previousValue;
  final LedgerReconfirmation reconfirmation;
  final LedgerFieldFreshnessPolicy? policy;

  bool get isCurrent => state == LedgerFreshnessState.current;
}

/// Pure freshness kernel shared by biography facts and canonical ledger fields.
///
/// The ledger API is deliberately model-free and synchronous. Callers extract
/// value/provenance from CoachProfile; BiographyRepository never overrides the
/// canonical profile or hides an asynchronous lookup behind this service.
class FreshnessDecayService {
  FreshnessDecayService._();

  static const _floor = 0.3;
  static const _refreshThreshold = 0.60;
  static const _annualFullMonths = 12.0;
  static const _annualFloorMonths = 36.0;
  static const _volatileFullMonths = 3.0;
  static const _volatileFloorMonths = 12.0;

  /// Exact addressable projection of G1_P0_CANONICAL_KEYS.
  ///
  /// `NONE`, collection wildcards and specialist references are intentionally
  /// excluded. The contract test derives this registry from the matrix and
  /// hard-fails on tier conflicts or drift.
  static const Map<String, LedgerFieldFreshnessPolicy> ledgerFieldPolicies = {
    'avsGapStatus': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'birthYear': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.static,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'bonusPourcentage': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'canton': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'commune': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'companyProfitAnnual': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'conjoint.birthYear': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.static,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'conjoint.prevoyance.anneesContribuees': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'dateOfBirth': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.static,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'depenses.assuranceMaladie': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'openBanking', 'userInput'},
    ),
    'depenses.loyer': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.volatile,
      allowedSourceNames: {'certificate', 'openBanking', 'userInput'},
    ),
    'dettes.autresDettes': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.volatile,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'dettes.hasDette': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.volatile,
      allowedSourceNames: {'userInput'},
    ),
    'dettes.hypotheque': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.volatile,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'dettes.totalMensualite': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.volatile,
      allowedSourceNames: {'certificate', 'openBanking', 'userInput'},
    ),
    'employmentRate': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'employmentStatus': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.eventStatic,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'etatCivil': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.eventStatic,
      allowedSourceNames: {'userInput'},
    ),
    'gender': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.static,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'goalA.type': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.eventStatic,
      allowedSourceNames: {'userInput'},
    ),
    'hasPillar3a': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'openBanking', 'userInput'},
    ),
    'monthlyNetIncomeDeclared': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'openBanking', 'userInput'},
    ),
    'monthlySavingsContribution': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'openBanking', 'userInput'},
    ),
    'nationality': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.static,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'nombreEnfants': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.eventStatic,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'patrimoine.epargneLiquide': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {
        'certificate',
        'crossValidated',
        'openBanking',
        'userInput'
      },
    ),
    'patrimoine.investissements': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'openBanking', 'userInput'},
    ),
    'patrimoine.mortgageRate': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.volatile,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'patrimoine.propertyMarketValue': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'estimated', 'userInput'},
    ),
    'patrimoine.wealthEstimate': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'estimated', 'userInput'},
    ),
    'pillar3aAnnualContribution': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'openBanking', 'userInput'},
    ),
    'prevoyance.anneesContribuees': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'prevoyance.avoirLppObligatoire': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate'},
    ),
    'prevoyance.avoirLppSurobligatoire': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate'},
    ),
    'prevoyance.avoirLppTotal': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'estimated', 'userInput'},
    ),
    'prevoyance.deathCoverage': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate'},
    ),
    'prevoyance.disabilityCoverage': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate'},
    ),
    'prevoyance.hasPensionFund': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.eventStatic,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'prevoyance.hasVoluntaryLpp': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.eventStatic,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'prevoyance.nombre3a': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'openBanking', 'userInput'},
    ),
    'prevoyance.projectedCapital65': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate'},
    ),
    'prevoyance.projectedRenteLpp': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate'},
    ),
    'prevoyance.rachatMaximum': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'prevoyance.ramd': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate'},
    ),
    'prevoyance.renteAVSEstimeeMensuelle': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'estimated'},
    ),
    'prevoyance.salaireAssure': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'prevoyance.tauxConversion': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'estimated'},
    ),
    'prevoyance.tauxConversionSuroblig': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate'},
    ),
    'prevoyance.totalEpargne3a': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'openBanking', 'userInput'},
    ),
    'providers3a': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'openBanking', 'userInput'},
    ),
    'residenceCountry': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.eventStatic,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'residencePermit': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.eventStatic,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'revenuBrutAnnuel': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'salaireBrutMensuel': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'openBanking', 'userInput'},
    ),
    'selfEmployedNetIncome': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'targetRetirementAge': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.eventStatic,
      allowedSourceNames: {'userInput'},
    ),
    'unemploymentContributionMonths': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'userProvidedFields.liquidSavingsAmount': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {
        'certificate',
        'crossValidated',
        'openBanking',
        'userInput'
      },
    ),
    'userProvidedFields.monthlyExpenses': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.volatile,
      allowedSourceNames: {'certificate', 'openBanking', 'userInput'},
    ),
    'workCanton': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.annual,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
    'workCountry': LedgerFieldFreshnessPolicy(
      tier: LedgerFreshnessTier.eventStatic,
      allowedSourceNames: {'certificate', 'userInput'},
    ),
  };

  /// These references use their strict root/BND/intrinsic selectors. A generic
  /// timestamp must never expire or renew their authority.
  static const Set<String> specialistReferencePaths = {
    'currentPillar3aBeneficiaryEvidence',
    'latestTaxDecisionReference',
    'lppCapitalNoticeDeadline',
    'lppRegulationReference',
  };

  /// Assess one canonical CoachProfile field without importing CoachProfile.
  ///
  /// Missing/future timestamps, unknown paths and forbidden provenance fail
  /// closed at the floor while preserving [previousValue]. A stale mixed-source
  /// field may be confirmed as user input; certificate-only fields require new
  /// evidence instead of laundering certificate confidence through a tap.
  static LedgerFreshnessAssessment<T> assessLedgerField<T>({
    required String fieldPath,
    required T? previousValue,
    required DateTime? updatedAt,
    required String? sourceName,
    required DateTime now,
  }) {
    if (specialistReferencePaths.contains(fieldPath)) {
      return LedgerFreshnessAssessment<T>(
        state: LedgerFreshnessState.separateReference,
        weight: _floor,
        previousValue: previousValue,
        reconfirmation: LedgerReconfirmation.separateReference,
      );
    }

    final policy = ledgerFieldPolicies[fieldPath];
    if (policy == null || previousValue == null) {
      return LedgerFreshnessAssessment<T>(
        state: LedgerFreshnessState.invalid,
        weight: _floor,
        previousValue: previousValue,
        reconfirmation: LedgerReconfirmation.unavailable,
        policy: policy,
      );
    }
    if (sourceName == null || !policy.allowedSourceNames.contains(sourceName)) {
      return LedgerFreshnessAssessment<T>(
        state: LedgerFreshnessState.invalid,
        weight: _floor,
        previousValue: previousValue,
        reconfirmation: LedgerReconfirmation.unavailable,
        policy: policy,
      );
    }

    final reconfirmation = policy.allowsUserReconfirmation
        ? LedgerReconfirmation.confirmAsUserInput
        : LedgerReconfirmation.renewEvidence;
    if (updatedAt == null || updatedAt.isAfter(now)) {
      return LedgerFreshnessAssessment<T>(
        state: LedgerFreshnessState.invalid,
        weight: _floor,
        previousValue: previousValue,
        reconfirmation: reconfirmation,
        policy: policy,
      );
    }

    final freshness = _weightForTier(policy.tier, updatedAt, now);
    final stale = freshness < _refreshThreshold;
    return LedgerFreshnessAssessment<T>(
      state: stale ? LedgerFreshnessState.stale : LedgerFreshnessState.current,
      weight: freshness,
      previousValue: previousValue,
      reconfirmation: stale ? reconfirmation : LedgerReconfirmation.none,
      policy: policy,
    );
  }

  /// Biography uses its persisted tier, but never sourceDate, for chronology.
  static double weight(BiographyFact fact, DateTime now) {
    final tier = _tierFromWireName(fact.freshnessCategory);
    if (tier == null || fact.updatedAt.isAfter(now)) return _floor;
    return _weightForTier(tier, fact.updatedAt, now);
  }

  static double _weightForTier(
    LedgerFreshnessTier tier,
    DateTime updatedAt,
    DateTime now,
  ) {
    if (updatedAt.isAfter(now)) return _floor;
    return switch (tier) {
      LedgerFreshnessTier.static || LedgerFreshnessTier.eventStatic => 1.0,
      LedgerFreshnessTier.annual => _decay(
          now.difference(updatedAt).inDays / 30.44,
          _annualFullMonths,
          _annualFloorMonths,
        ),
      LedgerFreshnessTier.volatile => _decay(
          now.difference(updatedAt).inDays / 30.44,
          _volatileFullMonths,
          _volatileFloorMonths,
        ),
    };
  }

  static LedgerFreshnessTier? _tierFromWireName(String value) =>
      switch (value) {
        'static' => LedgerFreshnessTier.static,
        'event_static' => LedgerFreshnessTier.eventStatic,
        'annual' => LedgerFreshnessTier.annual,
        'volatile' => LedgerFreshnessTier.volatile,
        _ => null,
      };

  static double _decay(
    double monthsOld,
    double fullMonths,
    double floorMonths,
  ) {
    if (monthsOld <= fullMonths) return 1.0;
    if (monthsOld >= floorMonths) return _floor;
    final elapsed = monthsOld - fullMonths;
    return 1.0 - (1.0 - _floor) * (elapsed / (floorMonths - fullMonths));
  }

  static bool needsRefresh(BiographyFact fact, DateTime now) =>
      weight(fact, now) < _refreshThreshold;

  static String categoryFor(FactType type) => switch (type) {
        FactType.mortgageDebt => LedgerFreshnessTier.volatile.wireName,
        FactType.civilStatus ||
        FactType.employmentStatus ||
        FactType.lifeEvent ||
        FactType.userDecision ||
        FactType.coachPreference =>
          LedgerFreshnessTier.eventStatic.wireName,
        FactType.alertAcknowledged => LedgerFreshnessTier.static.wireName,
        FactType.salary ||
        FactType.lppCapital ||
        FactType.lppRachatMax ||
        FactType.threeACapital ||
        FactType.avsContributionYears ||
        FactType.taxRate ||
        FactType.canton =>
          LedgerFreshnessTier.annual.wireName,
      };
}
