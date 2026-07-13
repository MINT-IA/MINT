/// Exact CHF value used by the 13th AVS pension contract.
///
/// The calculator never accepts binary floating-point money internally. The
/// legacy boundary exists only to reject unsafe values before conversion.
class ChfAmount {
  const ChfAmount.fromCents(this.cents);

  const ChfAmount.fromFrancs(int francs) : cents = francs * 100;

  factory ChfAmount.fromLegacyDouble(double francs) {
    if (!francs.isFinite) {
      throw ArgumentError.value(francs, 'francs', 'must be finite');
    }
    final amount = tryFromLegacyDouble(francs);
    if (amount == null) {
      throw ArgumentError.value(
        francs,
        'francs',
        'must have at most two decimal places',
      );
    }
    return amount;
  }

  static ChfAmount? tryFromLegacyDouble(double francs) {
    if (!francs.isFinite) return null;
    final centimes = francs * 100;
    final roundedCentimes = centimes.round();
    if ((centimes - roundedCentimes).abs() > 0.0000001) {
      return null;
    }
    return ChfAmount.fromCents(roundedCentimes);
  }

  final int cents;

  double get francs => cents / 100;

  ChfAmount operator +(ChfAmount other) =>
      ChfAmount.fromCents(cents + other.cents);

  ChfAmount operator -(ChfAmount other) =>
      ChfAmount.fromCents(cents - other.cents);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChfAmount && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => 'CHF ${francs.toStringAsFixed(2)}';
}

enum AvsMonthlyOldAgeState {
  paidEligibleOldAge,
  explicitlyNoOldAgeEntitlement,
  unknown,
}

enum AvsOldAgePensionKind { ordinary, extraordinary }

enum AvsOldAgeAdjustment {
  capped,
  anticipated,
  deferredIncrease,
  widowSupplementIncluded,
}

enum AvsPensionBenefitKind { oldAge, disability, survivor, none, unknown }

enum AvsExcludedComponentKind {
  disabilityPension,
  survivorPension,
  orphanPension,
  childPension,
  complementaryPension,
  avs21TransitionSupplement,
  helplessnessAllowance,
  supplementaryBenefit,
  unknown,
}

enum AvsDecemberEntitlementState { entitled, notEntitled, unknown }

enum AvsPensionPaymentCadence { monthly, annualArticle44Paragraph2 }

enum AvsEvidenceTier {
  avsFundLedger,
  avsFundDecision,
  userDeclaredFromDocument,
  scenario,
}

enum AvsThirteenthReadiness {
  certified,
  explicitlyNotEntitled,
  notInForce,
  declaredComplete,
  illustrativeOnly,
  pendingDecember,
  missingMonthlyHistory,
  unclassifiedComponent,
  sourceTooWeak,
  unsupportedLegalYear,
  providerCorrectionRequired,
}

class AvsEvidence {
  const AvsEvidence({
    required this.tier,
    required this.ownerId,
    required this.documentOrProviderRef,
    required this.sourceDate,
    required this.effectiveFrom,
    required this.legalYear,
  });

  final AvsEvidenceTier tier;
  final String ownerId;
  final String? documentOrProviderRef;
  final DateTime? sourceDate;
  final DateTime effectiveFrom;
  final int legalYear;
}

class AvsMonthlyOldAgeFact {
  const AvsMonthlyOldAgeFact({
    required this.month,
    required this.state,
    required this.benefitKind,
    required this.determiningOldAgePensionChf,
    required this.pensionKind,
    required this.adjustments,
    required this.excludedCashflowsChf,
    required this.evidence,
  });

  final int month;
  final AvsMonthlyOldAgeState state;
  final AvsPensionBenefitKind benefitKind;
  final ChfAmount? determiningOldAgePensionChf;
  final AvsOldAgePensionKind? pensionKind;
  final Set<AvsOldAgeAdjustment> adjustments;
  final Map<AvsExcludedComponentKind, ChfAmount> excludedCashflowsChf;
  final AvsEvidence evidence;
}

class AvsDecemberEntitlementEvidence {
  const AvsDecemberEntitlementEvidence({
    required this.state,
    required this.ownerId,
    required this.evidenceTier,
    required this.aliveOnDecemberFirst,
    required this.decisionOrProviderRef,
    required this.sourceDate,
    required this.legalYear,
  });

  final AvsDecemberEntitlementState state;
  final String ownerId;
  final AvsEvidenceTier evidenceTier;
  final bool? aliveOnDecemberFirst;
  final String? decisionOrProviderRef;
  final DateTime? sourceDate;
  final int legalYear;
}

class AvsThirteenthPensionInput {
  const AvsThirteenthPensionInput({
    required this.ownerId,
    required this.calendarYear,
    required this.months,
    required this.decemberEntitlement,
    required this.paymentCadence,
    required this.supplementPaymentDate,
    required this.previouslyPaidThirteenthChf,
    required this.calculationDate,
    required this.legalYear,
    required this.ruleVersion,
  });

  factory AvsThirteenthPensionInput.fullYearScenario({
    required String ownerId,
    required int calendarYear,
    required ChfAmount determiningMonthlyOldAgePensionChf,
    required DateTime sourceDate,
    required DateTime calculationDate,
    required int legalYear,
    required String ruleVersion,
    required String scenarioRef,
  }) {
    return AvsThirteenthPensionInput(
      ownerId: ownerId,
      calendarYear: calendarYear,
      months: List.unmodifiable(
        List.generate(
          12,
          (index) => AvsMonthlyOldAgeFact(
            month: index + 1,
            state: AvsMonthlyOldAgeState.paidEligibleOldAge,
            benefitKind: AvsPensionBenefitKind.oldAge,
            determiningOldAgePensionChf: determiningMonthlyOldAgePensionChf,
            pensionKind: AvsOldAgePensionKind.ordinary,
            adjustments: const {},
            excludedCashflowsChf: const {},
            evidence: AvsEvidence(
              tier: AvsEvidenceTier.scenario,
              ownerId: ownerId,
              documentOrProviderRef: scenarioRef,
              sourceDate: sourceDate,
              effectiveFrom: DateTime.utc(calendarYear, index + 1, 1),
              legalYear: legalYear,
            ),
          ),
        ),
      ),
      decemberEntitlement: AvsDecemberEntitlementEvidence(
        state: AvsDecemberEntitlementState.entitled,
        ownerId: ownerId,
        evidenceTier: AvsEvidenceTier.scenario,
        aliveOnDecemberFirst: true,
        decisionOrProviderRef: scenarioRef,
        sourceDate: sourceDate,
        legalYear: legalYear,
      ),
      paymentCadence: AvsPensionPaymentCadence.monthly,
      supplementPaymentDate: null,
      previouslyPaidThirteenthChf: null,
      calculationDate: calculationDate,
      legalYear: legalYear,
      ruleVersion: ruleVersion,
    );
  }

  final String ownerId;
  final int calendarYear;
  final List<AvsMonthlyOldAgeFact> months;
  final AvsDecemberEntitlementEvidence decemberEntitlement;
  final AvsPensionPaymentCadence paymentCadence;
  final DateTime? supplementPaymentDate;
  final ChfAmount? previouslyPaidThirteenthChf;
  final DateTime calculationDate;
  final int legalYear;
  final String ruleVersion;
}

class AvsThirteenthPensionResult {
  const AvsThirteenthPensionResult({
    required this.ownerId,
    required this.calendarYear,
    required this.decemberOrdinaryOldAgePensionChf,
    required this.eligibleOldAgePensionsPaidChf,
    required this.monthlyAccrualPartsChf,
    required this.certifiedThirteenthPensionChf,
    required this.educationalEstimateChf,
    required this.eligibleOldAgeCashflowWithSupplementChf,
    required this.correctionAgainstPreviousPaymentChf,
    required this.paymentCadence,
    required this.supplementPaymentDate,
    required this.readiness,
    required this.missingFields,
    required this.excludedComponentKinds,
    required this.legalYear,
    required this.ruleVersion,
    required this.legalSources,
    required this.calculatedAt,
  });

  final String ownerId;
  final int calendarYear;
  final ChfAmount? decemberOrdinaryOldAgePensionChf;
  final ChfAmount? eligibleOldAgePensionsPaidChf;
  final List<ChfAmount?> monthlyAccrualPartsChf;
  final ChfAmount? certifiedThirteenthPensionChf;
  final ChfAmount? educationalEstimateChf;
  final ChfAmount? eligibleOldAgeCashflowWithSupplementChf;
  final ChfAmount? correctionAgainstPreviousPaymentChf;
  final AvsPensionPaymentCadence paymentCadence;
  final DateTime? supplementPaymentDate;
  final AvsThirteenthReadiness readiness;
  final List<String> missingFields;
  final Set<AvsExcludedComponentKind> excludedComponentKinds;
  final int legalYear;
  final String ruleVersion;
  final List<String> legalSources;
  final DateTime calculatedAt;
}

class AvsThirteenthPensionCalculator {
  AvsThirteenthPensionCalculator._();

  static const supportedLegalYear = 2026;
  static const supportedRuleVersion = 'OFAS-C13RV-2026-01-01';
  static const _legalSources = <String>[
    'LAVS art. 34ter',
    'RAVS art. 52ater-52aquinquies',
    'OFAS C 13 RV, version 01.01.2026',
  ];

  static AvsThirteenthPensionResult calculate(
    AvsThirteenthPensionInput input,
  ) {
    if (input.ownerId.trim().isEmpty) {
      return _failure(
        input,
        AvsThirteenthReadiness.providerCorrectionRequired,
        const ['ownerId'],
      );
    }
    if (!input.calculationDate.isUtc) {
      return _failure(
        input,
        AvsThirteenthReadiness.providerCorrectionRequired,
        const ['calculationDate.mustBeUtc'],
      );
    }
    final supplementPaymentDate = input.supplementPaymentDate;
    if (supplementPaymentDate != null && !supplementPaymentDate.isUtc) {
      return _failure(
        input,
        AvsThirteenthReadiness.providerCorrectionRequired,
        const ['supplementPaymentDate.mustBeUtc'],
      );
    }
    if ((input.previouslyPaidThirteenthChf?.cents ?? 0) < 0) {
      return _failure(
        input,
        AvsThirteenthReadiness.providerCorrectionRequired,
        const ['previouslyPaidThirteenthChf'],
      );
    }
    if (input.legalYear != supportedLegalYear) {
      return _failure(
        input,
        AvsThirteenthReadiness.unsupportedLegalYear,
        const ['legalYear'],
      );
    }
    if (input.ruleVersion != supportedRuleVersion) {
      return _failure(
        input,
        AvsThirteenthReadiness.unsupportedLegalYear,
        const ['ruleVersion'],
      );
    }
    if (input.paymentCadence ==
        AvsPensionPaymentCadence.annualArticle44Paragraph2) {
      final paymentDate = supplementPaymentDate;
      if (paymentDate == null) {
        return _failure(
          input,
          AvsThirteenthReadiness.providerCorrectionRequired,
          const ['supplementPaymentDate'],
        );
      }
      if (_isCivilDateBefore(paymentDate, input.calendarYear, 12, 1)) {
        return _failure(
          input,
          AvsThirteenthReadiness.providerCorrectionRequired,
          const ['supplementPaymentDate.beforeEntitlementDate'],
        );
      }
    }
    if (input.months.length != 12) {
      return _failure(
        input,
        AvsThirteenthReadiness.providerCorrectionRequired,
        const ['months.exactly12'],
      );
    }

    for (var index = 0; index < input.months.length; index++) {
      final month = input.months[index];
      if (month.month < 1 || month.month > 12) {
        return _failure(
          input,
          AvsThirteenthReadiness.providerCorrectionRequired,
          ['months.${index + 1}.month'],
        );
      }
    }
    if (List.generate(12, (index) => index + 1)
        .asMap()
        .entries
        .any((entry) => input.months[entry.key].month != entry.value)) {
      return _failure(
        input,
        AvsThirteenthReadiness.providerCorrectionRequired,
        const ['months.uniqueOrdered1To12'],
      );
    }

    final excludedKinds = <AvsExcludedComponentKind>{};
    final monthlyParts = <ChfAmount?>[];
    var eligibleCents = 0;
    String? missingMonthlyHistoryField;
    String? missingMonthlyEvidenceField;
    var weakestTier = AvsEvidenceTier.avsFundLedger;

    for (final month in input.months) {
      final prefix = 'months.${month.month}';
      if (month.evidence.ownerId != input.ownerId) {
        return _failure(
          input,
          AvsThirteenthReadiness.providerCorrectionRequired,
          ['$prefix.evidence.ownerId'],
          excludedKinds: excludedKinds,
        );
      }
      if (!month.evidence.effectiveFrom.isUtc) {
        return _failure(
          input,
          AvsThirteenthReadiness.providerCorrectionRequired,
          ['$prefix.evidence.effectiveFrom.mustBeUtc'],
          excludedKinds: excludedKinds,
        );
      }
      if (input.calendarYear >= supportedLegalYear &&
          _isOfficial(month.evidence.tier) &&
          _isYearMonthAfter(
            month.evidence.effectiveFrom,
            input.calendarYear,
            month.month,
          )) {
        return _failure(
          input,
          AvsThirteenthReadiness.providerCorrectionRequired,
          ['$prefix.evidence.effectiveFrom.afterDescribedMonth'],
          excludedKinds: excludedKinds,
        );
      }
      if (month.evidence.legalYear != input.legalYear) {
        return _failure(
          input,
          AvsThirteenthReadiness.unsupportedLegalYear,
          ['$prefix.evidence.legalYear'],
          excludedKinds: excludedKinds,
        );
      }
      final sourceDate = month.evidence.sourceDate;
      if (sourceDate == null) {
        missingMonthlyEvidenceField ??= '$prefix.evidence.sourceDate';
      } else if (!sourceDate.isUtc) {
        return _failure(
          input,
          AvsThirteenthReadiness.sourceTooWeak,
          ['$prefix.evidence.sourceDate.mustBeUtc'],
          excludedKinds: excludedKinds,
        );
      }
      if (month.evidence.documentOrProviderRef == null ||
          month.evidence.documentOrProviderRef!.trim().isEmpty) {
        missingMonthlyEvidenceField ??=
            '$prefix.evidence.documentOrProviderRef';
      }

      excludedKinds.addAll(month.excludedCashflowsChf.keys);
      if (month.excludedCashflowsChf
          .containsKey(AvsExcludedComponentKind.unknown)) {
        return _failure(
          input,
          AvsThirteenthReadiness.unclassifiedComponent,
          ['$prefix.excludedComponentKinds.unknown'],
          excludedKinds: excludedKinds,
        );
      }
      if (month.excludedCashflowsChf.values.any((amount) => amount.cents < 0)) {
        return _failure(
          input,
          AvsThirteenthReadiness.providerCorrectionRequired,
          ['$prefix.excludedCashflowsChf'],
          excludedKinds: excludedKinds,
        );
      }

      switch (month.state) {
        case AvsMonthlyOldAgeState.paidEligibleOldAge:
          final amount = month.determiningOldAgePensionChf;
          if (amount == null) {
            return _failure(
              input,
              AvsThirteenthReadiness.missingMonthlyHistory,
              ['$prefix.determiningOldAgePensionChf'],
              excludedKinds: excludedKinds,
            );
          }
          if (amount.cents < 0) {
            return _failure(
              input,
              AvsThirteenthReadiness.providerCorrectionRequired,
              ['$prefix.determiningOldAgePensionChf'],
              excludedKinds: excludedKinds,
            );
          }
          if (month.benefitKind != AvsPensionBenefitKind.oldAge) {
            return _failure(
              input,
              AvsThirteenthReadiness.unclassifiedComponent,
              ['$prefix.benefitKind.oldAge'],
              excludedKinds: excludedKinds,
            );
          }
          if (month.pensionKind == null) {
            return _failure(
              input,
              AvsThirteenthReadiness.unclassifiedComponent,
              ['$prefix.pensionKind'],
              excludedKinds: excludedKinds,
            );
          }
          eligibleCents += amount.cents;
          monthlyParts.add(
            ChfAmount.fromCents(_roundTwelfthToCent(amount.cents)),
          );
        case AvsMonthlyOldAgeState.explicitlyNoOldAgeEntitlement:
          if (month.determiningOldAgePensionChf != null) {
            return _failure(
              input,
              AvsThirteenthReadiness.providerCorrectionRequired,
              ['$prefix.determiningOldAgePensionChf'],
              excludedKinds: excludedKinds,
            );
          }
          monthlyParts.add(const ChfAmount.fromCents(0));
        case AvsMonthlyOldAgeState.unknown:
          if (month.determiningOldAgePensionChf != null) {
            return _failure(
              input,
              AvsThirteenthReadiness.providerCorrectionRequired,
              ['$prefix.determiningOldAgePensionChf'],
              excludedKinds: excludedKinds,
            );
          }
          monthlyParts.add(null);
          missingMonthlyHistoryField ??= '$prefix.determiningOldAgePensionChf';
      }
      weakestTier = _weakerTier(weakestTier, month.evidence.tier);
    }

    final december = input.decemberEntitlement;
    if (december.ownerId != input.ownerId) {
      return _failure(
        input,
        AvsThirteenthReadiness.providerCorrectionRequired,
        const ['decemberEntitlement.ownerId'],
        excludedKinds: excludedKinds,
      );
    }
    if (december.legalYear != input.legalYear) {
      return _failure(
        input,
        AvsThirteenthReadiness.unsupportedLegalYear,
        const ['decemberEntitlement.legalYear'],
        excludedKinds: excludedKinds,
      );
    }
    if (december.sourceDate == null) {
      return _failure(
        input,
        AvsThirteenthReadiness.sourceTooWeak,
        const ['decemberEntitlement.sourceDate'],
        excludedKinds: excludedKinds,
      );
    }
    if (!december.sourceDate!.isUtc) {
      return _failure(
        input,
        AvsThirteenthReadiness.sourceTooWeak,
        const ['decemberEntitlement.sourceDate.mustBeUtc'],
        excludedKinds: excludedKinds,
      );
    }
    if (december.decisionOrProviderRef == null ||
        december.decisionOrProviderRef!.trim().isEmpty) {
      return _failure(
        input,
        AvsThirteenthReadiness.sourceTooWeak,
        const ['decemberEntitlement.decisionOrProviderRef'],
        excludedKinds: excludedKinds,
      );
    }
    if (december.state == AvsDecemberEntitlementState.entitled) {
      if (december.aliveOnDecemberFirst == null) {
        return _failure(
          input,
          AvsThirteenthReadiness.providerCorrectionRequired,
          const ['decemberEntitlement.aliveOnDecemberFirst'],
          excludedKinds: excludedKinds,
        );
      }
      if (december.aliveOnDecemberFirst == false) {
        return _failure(
          input,
          AvsThirteenthReadiness.providerCorrectionRequired,
          const [
            'decemberEntitlement.aliveOnDecemberFirst.contradictsEntitled',
          ],
          excludedKinds: excludedKinds,
        );
      }
      if (input.months[11].state ==
          AvsMonthlyOldAgeState.explicitlyNoOldAgeEntitlement) {
        return _failure(
          input,
          AvsThirteenthReadiness.providerCorrectionRequired,
          const ['decemberEntitlement.state.contradictsMonths.12.state'],
          excludedKinds: excludedKinds,
        );
      }
    } else if (december.state == AvsDecemberEntitlementState.notEntitled &&
        input.months[11].state == AvsMonthlyOldAgeState.paidEligibleOldAge) {
      return _failure(
        input,
        AvsThirteenthReadiness.providerCorrectionRequired,
        const ['decemberEntitlement.state.contradictsMonths.12.state'],
        excludedKinds: excludedKinds,
      );
    }

    final onlyScenarioEvidence = input.months.every(
          (month) => month.evidence.tier == AvsEvidenceTier.scenario,
        ) &&
        december.evidenceTier == AvsEvidenceTier.scenario;
    if (input.calendarYear > supportedLegalYear && !onlyScenarioEvidence) {
      return _failure(
        input,
        AvsThirteenthReadiness.unsupportedLegalYear,
        const ['calendarYear.requiresScenarioSnapshot'],
        excludedKinds: excludedKinds,
      );
    }

    final eligible = ChfAmount.fromCents(eligibleCents);
    final decemberAmount =
        input.months[11].state == AvsMonthlyOldAgeState.paidEligibleOldAge
            ? input.months[11].determiningOldAgePensionChf
            : const ChfAmount.fromCents(0);
    final roundedSupplement = ChfAmount.fromCents(
      _roundToWholeFranc(
        monthlyParts.fold<int>(0, (sum, part) => sum + (part?.cents ?? 0)),
      ),
    );

    if (input.calendarYear < supportedLegalYear) {
      return _resolved(
        input,
        decemberAmount: decemberAmount,
        eligible: missingMonthlyHistoryField == null ? eligible : null,
        monthlyParts: monthlyParts,
        certified: const ChfAmount.fromCents(0),
        educational: null,
        readiness: AvsThirteenthReadiness.notInForce,
        excludedKinds: excludedKinds,
      );
    }

    final beforeDecember = _isCivilDateBefore(
      input.calculationDate,
      input.calendarYear,
      12,
      1,
    );
    final officialDecemberNotEntitled =
        december.state == AvsDecemberEntitlementState.notEntitled &&
            _isOfficial(december.evidenceTier);
    if (officialDecemberNotEntitled &&
        !beforeDecember &&
        !december.sourceDate!.isAfter(input.calculationDate)) {
      return _resolved(
        input,
        decemberAmount: decemberAmount,
        eligible: missingMonthlyHistoryField == null ? eligible : null,
        monthlyParts: monthlyParts,
        certified: const ChfAmount.fromCents(0),
        educational: null,
        readiness: AvsThirteenthReadiness.explicitlyNotEntitled,
        excludedKinds: excludedKinds,
      );
    }

    if (missingMonthlyEvidenceField != null) {
      return _failure(
        input,
        AvsThirteenthReadiness.sourceTooWeak,
        [missingMonthlyEvidenceField],
        excludedKinds: excludedKinds,
      );
    }

    if (missingMonthlyHistoryField != null) {
      return _failure(
        input,
        AvsThirteenthReadiness.missingMonthlyHistory,
        [missingMonthlyHistoryField],
        excludedKinds: excludedKinds,
      );
    }

    weakestTier = _weakerTier(weakestTier, december.evidenceTier);
    final futureEvidence = <String>[];
    if (weakestTier != AvsEvidenceTier.scenario) {
      for (final month in input.months) {
        if (month.evidence.sourceDate!.isAfter(input.calculationDate)) {
          futureEvidence.add(
            'months.${month.month}.evidence.sourceDate.future',
          );
        }
        if (month.evidence.effectiveFrom.isAfter(input.calculationDate)) {
          futureEvidence.add(
            'months.${month.month}.evidence.effectiveFrom.future',
          );
        }
      }
      if (december.sourceDate!.isAfter(input.calculationDate)) {
        futureEvidence.add('decemberEntitlement.sourceDate.future');
      }
    }
    if (futureEvidence.isNotEmpty ||
        beforeDecember && weakestTier != AvsEvidenceTier.scenario) {
      if (futureEvidence.isEmpty) {
        futureEvidence.add('decemberEntitlement.state.notYetObservable');
      }
      return _resolved(
        input,
        decemberAmount: decemberAmount,
        eligible: eligible,
        monthlyParts: monthlyParts,
        certified: null,
        educational: roundedSupplement,
        readiness: AvsThirteenthReadiness.pendingDecember,
        excludedKinds: excludedKinds,
        missingFields: futureEvidence,
      );
    }

    if (december.state == AvsDecemberEntitlementState.unknown) {
      return _resolved(
        input,
        decemberAmount: decemberAmount,
        eligible: eligible,
        monthlyParts: monthlyParts,
        certified: null,
        educational: null,
        readiness: AvsThirteenthReadiness.pendingDecember,
        excludedKinds: excludedKinds,
        missingFields: const ['decemberEntitlement.state'],
      );
    }

    final official = _isOfficial(weakestTier);
    if (december.state == AvsDecemberEntitlementState.notEntitled ||
        december.aliveOnDecemberFirst == false) {
      if (official) {
        return _resolved(
          input,
          decemberAmount: decemberAmount,
          eligible: eligible,
          monthlyParts: monthlyParts,
          certified: const ChfAmount.fromCents(0),
          educational: null,
          readiness: AvsThirteenthReadiness.explicitlyNotEntitled,
          excludedKinds: excludedKinds,
        );
      }
      return _resolved(
        input,
        decemberAmount: decemberAmount,
        eligible: eligible,
        monthlyParts: monthlyParts,
        certified: null,
        educational: const ChfAmount.fromCents(0),
        readiness: _nonOfficialReadiness(weakestTier),
        excludedKinds: excludedKinds,
      );
    }

    if (official) {
      return _resolved(
        input,
        decemberAmount: decemberAmount,
        eligible: eligible,
        monthlyParts: monthlyParts,
        certified: roundedSupplement,
        educational: null,
        readiness: AvsThirteenthReadiness.certified,
        excludedKinds: excludedKinds,
      );
    }
    return _resolved(
      input,
      decemberAmount: decemberAmount,
      eligible: eligible,
      monthlyParts: monthlyParts,
      certified: null,
      educational: roundedSupplement,
      readiness: _nonOfficialReadiness(weakestTier),
      excludedKinds: excludedKinds,
    );
  }

  static int _roundTwelfthToCent(int cents) => (cents + 6) ~/ 12;

  static int _roundToWholeFranc(int cents) => ((cents + 50) ~/ 100) * 100;

  static bool _isYearMonthAfter(DateTime value, int year, int month) {
    final civilValue = _toZurichCivil(value);
    return civilValue.year > year ||
        civilValue.year == year && civilValue.month > month;
  }

  static bool _isCivilDateBefore(
    DateTime value,
    int year,
    int month,
    int day,
  ) {
    final civilValue = _toZurichCivil(value);
    return civilValue.year < year ||
        civilValue.year == year && civilValue.month < month ||
        civilValue.year == year &&
            civilValue.month == month &&
            civilValue.day < day;
  }

  static DateTime _toZurichCivil(DateTime value) {
    assert(value.isUtc, 'UTC validation must precede Zurich civil conversion');
    // Switzerland follows the European DST rule: from the last Sunday in
    // March at 01:00 UTC until the last Sunday in October at 01:00 UTC.
    final offsetHours = _isZurichSummerTime(value) ? 2 : 1;
    return value.add(Duration(hours: offsetHours));
  }

  static bool _isZurichSummerTime(DateTime value) {
    final year = value.year;
    final startsAt = DateTime.utc(
      year,
      3,
      _lastSundayOfMonth(year, 3),
      1,
    );
    final endsAt = DateTime.utc(
      year,
      10,
      _lastSundayOfMonth(year, 10),
      1,
    );
    return !value.isBefore(startsAt) && value.isBefore(endsAt);
  }

  static int _lastSundayOfMonth(int year, int month) {
    final lastDay = DateTime.utc(year, month + 1, 0);
    return lastDay.day - lastDay.weekday % DateTime.daysPerWeek;
  }

  static bool _isOfficial(AvsEvidenceTier tier) =>
      tier == AvsEvidenceTier.avsFundLedger ||
      tier == AvsEvidenceTier.avsFundDecision;

  static int _tierRank(AvsEvidenceTier tier) => switch (tier) {
        AvsEvidenceTier.avsFundLedger => 0,
        AvsEvidenceTier.avsFundDecision => 0,
        AvsEvidenceTier.userDeclaredFromDocument => 1,
        AvsEvidenceTier.scenario => 2,
      };

  static AvsEvidenceTier _weakerTier(
    AvsEvidenceTier current,
    AvsEvidenceTier candidate,
  ) =>
      _tierRank(candidate) > _tierRank(current) ? candidate : current;

  static AvsThirteenthReadiness _nonOfficialReadiness(
    AvsEvidenceTier tier,
  ) =>
      tier == AvsEvidenceTier.scenario
          ? AvsThirteenthReadiness.illustrativeOnly
          : AvsThirteenthReadiness.declaredComplete;

  static AvsThirteenthPensionResult _failure(
    AvsThirteenthPensionInput input,
    AvsThirteenthReadiness readiness,
    List<String> missingFields, {
    Set<AvsExcludedComponentKind> excludedKinds = const {},
  }) {
    return AvsThirteenthPensionResult(
      ownerId: input.ownerId,
      calendarYear: input.calendarYear,
      decemberOrdinaryOldAgePensionChf: null,
      eligibleOldAgePensionsPaidChf: null,
      monthlyAccrualPartsChf: const [],
      certifiedThirteenthPensionChf: null,
      educationalEstimateChf: null,
      eligibleOldAgeCashflowWithSupplementChf: null,
      correctionAgainstPreviousPaymentChf: null,
      paymentCadence: input.paymentCadence,
      supplementPaymentDate: input.supplementPaymentDate,
      readiness: readiness,
      missingFields: List.unmodifiable(missingFields),
      excludedComponentKinds: Set.unmodifiable(excludedKinds),
      legalYear: input.legalYear,
      ruleVersion: input.ruleVersion,
      legalSources: _legalSources,
      calculatedAt: input.calculationDate,
    );
  }

  static AvsThirteenthPensionResult _resolved(
    AvsThirteenthPensionInput input, {
    required ChfAmount? decemberAmount,
    required ChfAmount? eligible,
    required List<ChfAmount?> monthlyParts,
    required ChfAmount? certified,
    required ChfAmount? educational,
    required AvsThirteenthReadiness readiness,
    required Set<AvsExcludedComponentKind> excludedKinds,
    List<String> missingFields = const [],
  }) {
    final supplement = certified ?? educational;
    final correction =
        certified != null && input.previouslyPaidThirteenthChf != null
            ? certified - input.previouslyPaidThirteenthChf!
            : null;
    return AvsThirteenthPensionResult(
      ownerId: input.ownerId,
      calendarYear: input.calendarYear,
      decemberOrdinaryOldAgePensionChf: decemberAmount,
      eligibleOldAgePensionsPaidChf: eligible,
      monthlyAccrualPartsChf: List.unmodifiable(monthlyParts),
      certifiedThirteenthPensionChf: certified,
      educationalEstimateChf: educational,
      eligibleOldAgeCashflowWithSupplementChf:
          supplement == null || eligible == null ? null : eligible + supplement,
      correctionAgainstPreviousPaymentChf: correction,
      paymentCadence: input.paymentCadence,
      supplementPaymentDate: input.supplementPaymentDate,
      readiness: readiness,
      missingFields: List.unmodifiable(missingFields),
      excludedComponentKinds: Set.unmodifiable(excludedKinds),
      legalYear: input.legalYear,
      ruleVersion: input.ruleVersion,
      legalSources: _legalSources,
      calculatedAt: input.calculationDate,
    );
  }
}
