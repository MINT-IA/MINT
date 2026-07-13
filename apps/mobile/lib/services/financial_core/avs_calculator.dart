import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/avs_reference_age.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';

// ALL AVS calculations MUST use AvsCalculator from financial_core.
// See ADR-20260223-unified-financial-engine.md
// Do NOT create local _calculateAvs() or similar methods.

/// Civil statuses relevant to the AVS household cap.
enum AvsCoupleLegalStatus { married, registeredPartnership, cohabiting }

/// Benefits that can participate in the LAVS art. 35 cap test.
enum AvsPensionEntitlement { none, oldAge, disability }

/// RAVS art. 53ter treatment for a percentage of an old-age pension.
enum AvsOldAgePaymentMode { ordinary, anticipated, deferred }

/// Stable person ownership within a self/partner household calculation.
enum AvsPersonRole { self, partner }

/// Legal outcome of the AVS couple cap evaluation.
enum AvsCoupleCapState {
  applied,
  notNeeded,
  notApplicable,
  legalException,
  pending,
}

/// Person-owned, evidence-backed ordinary pension input.
///
/// [rawMonthlyPension] is the person's uncapped ordinary monthly benefit at
/// the selected [pensionPercentage]. It is not a salary-derived estimate and
/// excludes the December supplement.
class AvsPersonPensionInput {
  final AvsPersonRole owner;
  final AvsPensionEntitlement? entitlement;
  final double? rawMonthlyPension;
  final int? contributionScale;
  final double? pensionPercentage;
  final AvsOldAgePaymentMode? oldAgePaymentMode;

  const AvsPersonPensionInput({
    required this.owner,
    this.entitlement,
    this.rawMonthlyPension,
    this.contributionScale,
    this.pensionPercentage,
    this.oldAgePaymentMode,
  });
}

/// Sourced LAVS art. 35 judicial-separation state.
///
/// A null envelope is unknown. Addresses, account links, and user silence do
/// not create this evidence.
class AvsJudicialSeparationEvidence {
  final bool isSeparated;
  final String source;

  const AvsJudicialSeparationEvidence({
    required this.isSeparated,
    required this.source,
  });
}

/// Complete input boundary for an AVS household cap calculation.
class AvsCouplePensionInput {
  final AvsCoupleLegalStatus? legalStatus;
  final AvsPersonPensionInput self;
  final AvsPersonPensionInput partner;
  final AvsJudicialSeparationEvidence? judicialSeparation;

  const AvsCouplePensionInput({
    required this.legalStatus,
    required this.self,
    required this.partner,
    this.judicialSeparation,
  });
}

/// Uncapped and certified-capped pension values owned by one person.
class AvsPersonPensionResult {
  final AvsPersonRole owner;
  final AvsPensionEntitlement? entitlement;
  final double? rawMonthlyPension;
  final double? cappedMonthlyPension;
  final int? contributionScale;
  final double? scalePercentage;
  final double? pensionPercentage;
  final AvsOldAgePaymentMode? oldAgePaymentMode;

  const AvsPersonPensionResult({
    required this.owner,
    required this.entitlement,
    required this.rawMonthlyPension,
    required this.cappedMonthlyPension,
    required this.contributionScale,
    required this.scalePercentage,
    required this.pensionPercentage,
    required this.oldAgePaymentMode,
  });
}

/// Fail-closed AVS household result under the 2026 legal snapshot.
class AvsCouplePensionResult {
  final AvsPersonPensionResult self;
  final AvsPersonPensionResult partner;

  /// Sum of resolved person-owned raw pensions before a marital cap.
  ///
  /// An explicit [AvsPensionEntitlement.none] contributes no component; it is
  /// never represented as a person pension worth CHF 0.
  final double? rawHouseholdMonthlyPension;

  /// Certified ordinary monthly household amount after any applicable cap.
  ///
  /// This remains null while an applicable incomplete-scale cap lacks the
  /// versioned official pension-table amount.
  final double? householdMonthlyPension;
  final double? weightedScaleRaw;
  final int? weightedContributionScale;

  /// Scale-weighted base cap before art. 53ter percentage treatment.
  final double? scaleWeightedMonthlyCap;
  final double? percentageCapMultiplier;

  /// Educational formula estimate after scale and percentage treatment.
  ///
  /// This never certifies an incomplete-scale payable amount.
  final double? formulaLayerMonthlyCapEstimate;

  /// Certified scale- and percentage-aware payable cap.
  final double? payableMonthlyCap;
  final AvsCoupleCapState capState;
  final List<String> missingFields;
  final int legalYear;
  final String legalSource;
  final String? judicialSeparationSource;
  final bool requiresOfficialTableRounding;

  AvsCouplePensionResult({
    required this.self,
    required this.partner,
    required this.rawHouseholdMonthlyPension,
    required this.householdMonthlyPension,
    required this.weightedScaleRaw,
    required this.weightedContributionScale,
    required this.scaleWeightedMonthlyCap,
    required this.percentageCapMultiplier,
    required this.formulaLayerMonthlyCapEstimate,
    required this.payableMonthlyCap,
    required this.capState,
    required List<String> missingFields,
    required this.legalYear,
    required this.legalSource,
    required this.judicialSeparationSource,
    required this.requiresOfficialTableRounding,
  }) : missingFields = List.unmodifiable(missingFields);

  bool get isHouseholdComplete =>
      householdMonthlyPension != null &&
      missingFields.isEmpty &&
      !requiresOfficialTableRounding;
}

/// AVS pension calculator — pure static functions.
///
/// Legal basis: LAVS art. 21-29, 34, 35, 39, 40.
/// All computations are deterministic and stateless.
class AvsCalculator {
  AvsCalculator._();

  static const int coupleLegalYear = 2026;
  static const String coupleLegalSource =
      'LAVS art. 35; RAVS art. 52; RAVS art. 53; RAVS art. 53bis; '
      'RAVS art. 53ter; '
      'OFAS 2026 pension amounts';

  /// Compute individual AVS monthly rente.
  ///
  /// Takes into account:
  /// - Contribution duration (lacunes, arrivalAge) — LAVS art. 29
  /// - Income level via RAMD proxy — LAVS art. 34, echelle 44
  /// - Early retirement penalty (6.8%/yr from 63) — LAVS art. 40
  /// - Deferral bonus (up to +31.5% at 70) — LAVS art. 39
  /// - Gender-aware reference age for AVS21 (LAVS art. 21 al. 1)
  /// - Child-raising credits (bonifications éducatives) — LAVS art. 29sexies
  ///
  /// This illustration does not perform LAVS art. 29quinquies splitting.
  /// Exact splitting needs year-by-year individual-account histories and a
  /// statutory trigger; current salaries and marriage duration are rejected as
  /// a substitute by the couple legal contract.
  ///
  /// [isFemale] and [birthYear] are optional — when provided, the
  /// reference age accounts for AVS21 transitional cohorts (women
  /// born 1961-1963). When omitted, defaults to 65 (male/unknown).
  static double computeMonthlyRente({
    required int currentAge,
    required int retirementAge,
    int lacunes = 0,
    int? anneesContribuees,
    int? arrivalAge,
    double grossAnnualSalary = 0,
    bool? isFemale,
    int? birthYear,
    int childRaisingYears = 0,
    int totalContributionYears = avsDureeCotisationComplete,
  }) {
    // Determine gender-aware reference age (AVS21, LAVS art. 21 al. 1)
    final refAge = (isFemale != null && birthYear != null)
        ? avsReferenceAgeYears(birthYear: birthYear, isFemale: isFemale)
        : reg('avs.reference_age_men', avsAgeReferenceHomme.toDouble());

    // 1. Contribution years
    final fullYears = reg('avs.full_contribution_years', avsDureeCotisationComplete.toDouble()).toInt();

    int currentYears;
    if (anneesContribuees != null) {
      currentYears = anneesContribuees;
    } else if (arrivalAge != null && arrivalAge > 20) {
      currentYears =
          (currentAge - arrivalAge).clamp(0, fullYears);
    } else {
      currentYears =
          (currentAge - 20).clamp(0, fullYears);
    }
    final futureYears = (retirementAge - currentAge).clamp(0, 50);
    final totalYears =
        (currentYears + futureYears).clamp(0, fullYears);
    final effectiveYears =
        (totalYears - lacunes).clamp(0, fullYears);
    final gapFactor = fullYears > 0 ? effectiveYears / fullYears : 0.0;

    // 2. Effective salary (RAMD) with child credits
    double effectiveSalary = grossAnnualSalary;

    // 2a. Child-raising credits / bonifications éducatives (LAVS art. 29sexies)
    // Annual credit = 3× minimum annual AVS pension.
    // Added to RAMD prorated over total contribution years.
    if (childRaisingYears > 0 && totalContributionYears > 0) {
      const bonificationAnnuelle = 3 * avsRenteMinMensuelle * 12;
      final bonificationRAMD =
          (bonificationAnnuelle * childRaisingYears) / totalContributionYears;
      effectiveSalary += bonificationRAMD;
      effectiveSalary = effectiveSalary.clamp(0, avsRAMDMax);
    }

    // 2b. RAMD-based rente (LAVS art. 34, echelle 44)
    final baseRente = renteFromRAMD(effectiveSalary);
    double rente = baseRente * gapFactor;

    // 3. Early/late retirement adjustments relative to gender-aware refAge
    if (retirementAge < 63) {
      // AVS anticipation only possible from 63 (LAVS art. 40)
      return 0.0;
    } else if (retirementAge < refAge) {
      final yearsEarly = refAge - retirementAge;
      rente *= (1.0 - reg('avs.anticipation_reduction', avsReductionAnticipation) * yearsEarly);
    } else if (retirementAge > refAge) {
      final yearsLate = (retirementAge - refAge).clamp(1, 5).round();
      final bonus = avsDeferralBonus[yearsLate] ?? avsDeferralBonus[5]!;
      rente *= (1.0 + bonus);
    }

    return rente;
  }

  /// Round to nearest 5 centimes (Swiss standard for social insurance amounts).
  /// OAVS art. 53 — applied at display level, not computation level,
  /// to avoid cascading rounding effects in couple/optimizer calculations.
  static double roundTo5Centimes(double value) {
    return (value * 20).roundToDouble() / 20;
  }

  /// Position the self-employed AVS/AI/APG barème gauge.
  ///
  /// `1.0` means the income has reached the full-rate bracket for independent
  /// AVS cotisations. Keep this threshold in financial_core so screens render
  /// calculator output instead of owning financial constants.
  static double selfEmployedCotisationGaugePosition(double revenuNet) {
    final fullRateThreshold =
        reg('avs.self_employed_full_rate_threshold', 60500.0);
    if (revenuNet <= 0 || fullRateThreshold <= 0) return 0.0;
    return (revenuNet / fullRateThreshold).clamp(0.0, 1.0).toDouble();
  }

  /// AVS rente based on RAMD using Echelle 44 (LAVS art. 34).
  ///
  /// Concave lookup + linear interpolation between table points.
  /// Source: Memento 6.01 — Tables des rentes AVS/AI (OFAS 2025).
  /// RAMD <= 0 → 0 (no salary data).
  /// RAMD <= 14'700 → 1'260/mois (minimum).
  /// RAMD >= 88'200 → 2'520/mois (maximum).
  /// Between table points: linear interpolation within the bracket.
  /// gapFactor in computeMonthlyRente already handles contribution years.
  static double renteFromRAMD(double grossAnnualSalary) {
    if (grossAnnualSalary <= 0) return 0;
    final table = RegulatorySyncService.getEchelle44();
    if (grossAnnualSalary <= table.first[0]) return table.first[1];
    if (grossAnnualSalary >= table.last[0]) return table.last[1];
    for (int i = 0; i < table.length - 1; i++) {
      final lower = table[i];
      final upper = table[i + 1];
      if (grossAnnualSalary >= lower[0] && grossAnnualSalary <= upper[0]) {
        final ratio = (grossAnnualSalary - lower[0]) / (upper[0] - lower[0]);
        return lower[1] + ratio * (upper[1] - lower[1]);
      }
    }
    return table.last[1];
  }

  /// Apply the LAVS art. 35 / RAVS arts. 53bis-53ter couple contract.
  ///
  /// This accepts only person-owned ordinary pensions. Missing or invalid
  /// legal evidence returns [AvsCoupleCapState.pending] and no complete
  /// household amount. It never derives a pension from salary, age, or a
  /// default scale.
  static AvsCouplePensionResult computeCouplePensions(
    AvsCouplePensionInput input,
  ) {
    final missing = <String>[];

    final aggregationMissing = <String>[];
    _appendMissingBasePersonFields(
      input.self,
      AvsPersonRole.self,
      aggregationMissing,
    );
    _appendMissingBasePersonFields(
      input.partner,
      AvsPersonRole.partner,
      aggregationMissing,
    );
    missing.addAll(aggregationMissing);

    final rawHousehold = aggregationMissing.isEmpty
        ? [_activeRawPension(input.self), _activeRawPension(input.partner)]
            .whereType<double>()
            .fold<double>(0, (sum, value) => sum + value)
        : null;

    final capBenefitCombination =
        _qualifiesForArticle35(input.self, input.partner);
    final entitlementsResolved = input.self.entitlement != null &&
        input.partner.entitlement != null;
    final hasNoOldAgeBenefit =
        input.self.entitlement != AvsPensionEntitlement.oldAge &&
            input.partner.entitlement != AvsPensionEntitlement.oldAge;
    final nonQualifyingCapState =
        entitlementsResolved && !capBenefitCombination
            ? hasNoOldAgeBenefit
                ? AvsCoupleCapState.notApplicable
                : AvsCoupleCapState.notNeeded
            : null;
    if (capBenefitCombination && input.legalStatus == null) {
      missing.add('legalStatus');
    }
    final marriageEquivalent =
        input.legalStatus == AvsCoupleLegalStatus.married ||
            input.legalStatus == AvsCoupleLegalStatus.registeredPartnership;
    if (marriageEquivalent && capBenefitCombination) {
      final separation = input.judicialSeparation;
      if (separation == null) {
        missing.add('judicialSeparation');
      } else if (separation.source.trim().isEmpty) {
        missing.add('judicialSeparation.source');
      } else if (!separation.isSeparated) {
        _appendMissingCapFields(input.self, AvsPersonRole.self, missing);
        _appendMissingCapFields(
          input.partner,
          AvsPersonRole.partner,
          missing,
        );
      }
    }

    if (missing.isNotEmpty) {
      final separationSource = input.judicialSeparation?.source;
      return _coupleResult(
        input: input,
        rawHousehold: rawHousehold,
        selfCapped: null,
        partnerCapped: null,
        household: null,
        capState: input.legalStatus == AvsCoupleLegalStatus.cohabiting
            ? AvsCoupleCapState.notApplicable
            : nonQualifyingCapState ?? AvsCoupleCapState.pending,
        missing: missing,
        judicialSeparationSource:
            separationSource != null && separationSource.trim().isNotEmpty
                ? separationSource
                : null,
      );
    }

    final selfRaw = _activeRawPension(input.self);
    final partnerRaw = _activeRawPension(input.partner);
    final resolvedRawHousehold = rawHousehold!;

    if (input.legalStatus == AvsCoupleLegalStatus.cohabiting) {
      return _coupleResult(
        input: input,
        rawHousehold: resolvedRawHousehold,
        selfCapped: selfRaw,
        partnerCapped: partnerRaw,
        household: resolvedRawHousehold,
        capState: AvsCoupleCapState.notApplicable,
        missing: const [],
      );
    }

    if (!capBenefitCombination) {
      return _coupleResult(
        input: input,
        rawHousehold: resolvedRawHousehold,
        selfCapped: selfRaw,
        partnerCapped: partnerRaw,
        household: resolvedRawHousehold,
        capState: nonQualifyingCapState!,
        missing: const [],
      );
    }

    final separation = input.judicialSeparation!;
    if (separation.isSeparated) {
      return _coupleResult(
        input: input,
        rawHousehold: resolvedRawHousehold,
        selfCapped: selfRaw,
        partnerCapped: partnerRaw,
        household: resolvedRawHousehold,
        capState: AvsCoupleCapState.legalException,
        missing: const [],
        judicialSeparationSource: separation.source,
      );
    }

    final selfScale = input.self.contributionScale!;
    final partnerScale = input.partner.contributionScale!;
    final lowerScale = selfScale < partnerScale ? selfScale : partnerScale;
    final higherScale = selfScale > partnerScale ? selfScale : partnerScale;
    final weightedScaleRaw = (lowerScale + 2 * higherScale) / 3;
    // RAVS art. 53bis uses the next higher integer pension scale. It is not a
    // continuous interpolation between two scales.
    final determiningScale = weightedScaleRaw.ceil();
    final determiningScalePercentage = determiningScale / 44;
    final fullScaleCap =
        reg('avs.couple_max_monthly', avsRenteCoupleMaxMensuelle);
    final formulaLayerCap = fullScaleCap * determiningScalePercentage;
    final percentageMultiplier =
        _article53terPercentageMultiplier(input.self, input.partner);
    final formulaLayerApplicableCap = formulaLayerCap * percentageMultiplier;

    if (determiningScale < 44) {
      return _coupleResult(
        input: input,
        rawHousehold: resolvedRawHousehold,
        selfCapped: null,
        partnerCapped: null,
        household: null,
        capState: AvsCoupleCapState.pending,
        missing: ['officialPensionTableProvider.scale.$determiningScale'],
        weightedScaleRaw: weightedScaleRaw,
        weightedContributionScale: determiningScale,
        scaleWeightedCap: formulaLayerCap,
        percentageMultiplier: percentageMultiplier,
        formulaLayerCapEstimate: formulaLayerApplicableCap,
        judicialSeparationSource: separation.source,
      );
    }

    final payableCap = formulaLayerApplicableCap;
    if (resolvedRawHousehold <= payableCap) {
      return _coupleResult(
        input: input,
        rawHousehold: resolvedRawHousehold,
        selfCapped: selfRaw,
        partnerCapped: partnerRaw,
        household: resolvedRawHousehold,
        capState: AvsCoupleCapState.notNeeded,
        missing: const [],
        weightedScaleRaw: weightedScaleRaw,
        weightedContributionScale: determiningScale,
        scaleWeightedCap: formulaLayerCap,
        percentageMultiplier: percentageMultiplier,
        formulaLayerCapEstimate: formulaLayerApplicableCap,
        payableCap: payableCap,
        judicialSeparationSource: separation.source,
      );
    }

    final reductionFactor = payableCap / resolvedRawHousehold;
    return _coupleResult(
      input: input,
      rawHousehold: resolvedRawHousehold,
      selfCapped: selfRaw! * reductionFactor,
      partnerCapped: partnerRaw! * reductionFactor,
      household: payableCap,
      capState: AvsCoupleCapState.applied,
      missing: const [],
      weightedScaleRaw: weightedScaleRaw,
      weightedContributionScale: determiningScale,
      scaleWeightedCap: formulaLayerCap,
      percentageMultiplier: percentageMultiplier,
      formulaLayerCapEstimate: formulaLayerApplicableCap,
      payableCap: payableCap,
      judicialSeparationSource: separation.source,
    );
  }

  static void _appendMissingBasePersonFields(
    AvsPersonPensionInput person,
    AvsPersonRole expectedOwner,
    List<String> missing,
  ) {
    final prefix = expectedOwner.name;
    if (person.owner != expectedOwner) {
      missing.add('$prefix.owner');
    }
    final entitlement = person.entitlement;
    if (entitlement == null) {
      missing.add('$prefix.entitlement');
      return;
    }
    if (entitlement == AvsPensionEntitlement.none) return;

    final raw = person.rawMonthlyPension;
    if (raw == null || !raw.isFinite || raw <= 0) {
      missing.add('$prefix.rawMonthlyPension');
    }
  }

  static void _appendMissingCapFields(
    AvsPersonPensionInput person,
    AvsPersonRole expectedOwner,
    List<String> missing,
  ) {
    final prefix = expectedOwner.name;
    final scale = person.contributionScale;
    if (scale == null || scale < 1 || scale > 44) {
      missing.add('$prefix.contributionScale');
    }
    final percentage = person.pensionPercentage;
    if (percentage == null ||
        !percentage.isFinite ||
        percentage <= 0 ||
        percentage > 1) {
      missing.add('$prefix.pensionPercentage');
    }
    if (person.entitlement == AvsPensionEntitlement.oldAge &&
        person.oldAgePaymentMode == null) {
      missing.add('$prefix.oldAgePaymentMode');
    }
  }

  static bool _qualifiesForArticle35(
    AvsPersonPensionInput self,
    AvsPersonPensionInput partner,
  ) {
    final selfOldAge = self.entitlement == AvsPensionEntitlement.oldAge;
    final partnerOldAge = partner.entitlement == AvsPensionEntitlement.oldAge;
    final selfDisability = self.entitlement == AvsPensionEntitlement.disability;
    final partnerDisability =
        partner.entitlement == AvsPensionEntitlement.disability;
    return (selfOldAge && partnerOldAge) ||
        (selfOldAge && partnerDisability) ||
        (selfDisability && partnerOldAge);
  }

  static double? _activeRawPension(AvsPersonPensionInput person) =>
      person.entitlement == AvsPensionEntitlement.none
          ? null
          : person.rawMonthlyPension;

  static double _article53terPercentageMultiplier(
    AvsPersonPensionInput self,
    AvsPersonPensionInput partner,
  ) {
    final hasDeferredOldAge =
        self.entitlement == AvsPensionEntitlement.oldAge &&
                self.oldAgePaymentMode == AvsOldAgePaymentMode.deferred ||
            partner.entitlement == AvsPensionEntitlement.oldAge &&
                partner.oldAgePaymentMode == AvsOldAgePaymentMode.deferred;
    if (hasDeferredOldAge) return 1;

    final selfPercentage = self.pensionPercentage!;
    final partnerPercentage = partner.pensionPercentage!;
    return selfPercentage > partnerPercentage
        ? selfPercentage
        : partnerPercentage;
  }

  static AvsCouplePensionResult _coupleResult({
    required AvsCouplePensionInput input,
    required double? rawHousehold,
    required double? selfCapped,
    required double? partnerCapped,
    required double? household,
    required AvsCoupleCapState capState,
    required List<String> missing,
    double? weightedScaleRaw,
    int? weightedContributionScale,
    double? scaleWeightedCap,
    double? percentageMultiplier,
    double? formulaLayerCapEstimate,
    double? payableCap,
    String? judicialSeparationSource,
  }) =>
      AvsCouplePensionResult(
        self: _personResult(input.self, selfCapped),
        partner: _personResult(input.partner, partnerCapped),
        rawHouseholdMonthlyPension: rawHousehold,
        householdMonthlyPension: household,
        weightedScaleRaw: weightedScaleRaw,
        weightedContributionScale: weightedContributionScale,
        scaleWeightedMonthlyCap: scaleWeightedCap,
        percentageCapMultiplier: percentageMultiplier,
        formulaLayerMonthlyCapEstimate: formulaLayerCapEstimate,
        payableMonthlyCap: payableCap,
        capState: capState,
        missingFields: missing,
        legalYear: coupleLegalYear,
        legalSource: coupleLegalSource,
        judicialSeparationSource: judicialSeparationSource,
        requiresOfficialTableRounding: weightedContributionScale != null &&
            weightedContributionScale < 44,
      );

  static AvsPersonPensionResult _personResult(
    AvsPersonPensionInput input,
    double? capped,
  ) {
    final scale = input.contributionScale;
    final validScale = scale != null && scale >= 1 && scale <= 44;
    return AvsPersonPensionResult(
      owner: input.owner,
      entitlement: input.entitlement,
      rawMonthlyPension: input.rawMonthlyPension,
      cappedMonthlyPension: capped,
      contributionScale: input.contributionScale,
      scalePercentage: validScale ? scale / 44 : null,
      pensionPercentage: input.pensionPercentage,
      oldAgePaymentMode: input.oldAgePaymentMode,
    );
  }

  /// Bridge pension (rente-pont) estimate for early retirees.
  ///
  /// When retiring before the AVS reference age, there is an income gap
  /// where neither AVS nor LPP rente is paid. Some employers/caisses offer
  /// a bridge pension to cover this gap.
  ///
  /// Returns the estimated monthly gap and total bridge cost.
  /// - [retirementAge]: actual retirement age (e.g. 60)
  /// - [referenceAge]: AVS reference age (e.g. 65)
  /// - [estimatedAvsMonthly]: what the AVS rente would be at reference age
  /// - [estimatedLppMonthly]: what the LPP rente would be (if annuity chosen)
  static ({double monthlyGap, double totalBridgeCost, int gapYears}) computeBridgePension({
    required int retirementAge,
    required int referenceAge,
    required double estimatedAvsMonthly,
    double estimatedLppMonthly = 0,
  }) {
    final gapYears = (referenceAge - retirementAge).clamp(0, 10);
    if (gapYears <= 0) {
      return (monthlyGap: 0, totalBridgeCost: 0, gapYears: 0);
    }
    // During the gap: no AVS, potentially no LPP rente either
    final monthlyGap = estimatedAvsMonthly + estimatedLppMonthly;
    final totalBridgeCost = monthlyGap * 12 * gapYears;
    return (
      monthlyGap: monthlyGap,
      totalBridgeCost: totalBridgeCost,
      gapYears: gapYears,
    );
  }

  /// Convert monthly AVS rente to annual, including the 13th rente if active.
  ///
  /// From December 2026 onwards, AVS pays 13 monthly rentes per year
  /// instead of 12 (initiative populaire, LAVS art. 34 nouveau).
  ///
  /// The 13th rente applies ONLY to vieillesse pensions, NOT to AI,
  /// survivors, or children's pensions.
  ///
  /// [monthlyRente] — individual monthly pension (output of computeMonthlyRente).
  /// [include13eme] — override: false to get the traditional 12-month total.
  static double annualRente(
    double monthlyRente, {
    bool include13eme = avs13emeRenteActive,
  }) {
    if (include13eme) {
      return monthlyRente * avsNombreRentesParAn;
    }
    return monthlyRente * 12;
  }

  /// Returns the AVS rente reduction percentage for a given gap in contribution years.
  ///
  /// Example: gap=4 → 9.09% reduction (4/44 × 100).
  /// Use this instead of inline `gap / 44 * 100` calculations.
  static double reductionPercentageFromGap(int gap) {
    if (gap <= 0) return 0.0;
    final fullYears = reg('avs.full_contribution_years', avsDureeCotisationComplete.toDouble()).toInt();
    return (gap / fullYears * 100);
  }

  /// Returns the estimated monthly AVS rente loss for a given gap.
  ///
  /// Example: gap=4 → ~229 CHF/mois (2520 × 4/44).
  /// Use this instead of inline `2520 * gap / 44` calculations.
  static double monthlyLossFromGap(int gap) {
    if (gap <= 0) return 0.0;
    final renteMax = reg('avs.max_monthly_pension', avsRenteMaxMensuelle);
    final fullYears = reg('avs.full_contribution_years', avsDureeCotisationComplete.toDouble()).toInt();
    return renteMax * gap / fullYears;
  }

}
