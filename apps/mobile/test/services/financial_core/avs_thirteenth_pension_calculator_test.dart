import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/avs_thirteenth_pension_calculator.dart';

const _owner = 'person-self';
const _partner = 'person-partner';
const _legalYear = 2026;
const _ruleVersion = 'OFAS-C13RV-2026-01-01';

AvsEvidence _evidence(
  String ownerId, {
  AvsEvidenceTier tier = AvsEvidenceTier.avsFundDecision,
  bool includeSourceDate = true,
  bool includeReference = true,
  DateTime? sourceDate,
  DateTime? effectiveFrom,
  int legalYear = _legalYear,
  int month = 1,
}) =>
    AvsEvidence(
      tier: tier,
      ownerId: ownerId,
      documentOrProviderRef:
          includeReference ? 'avs-fund-decision-$ownerId' : null,
      sourceDate:
          includeSourceDate ? sourceDate ?? DateTime.utc(2026, 12, 1) : null,
      effectiveFrom: effectiveFrom ?? DateTime.utc(2026, month, 1),
      legalYear: legalYear,
    );

AvsMonthlyOldAgeFact _paid(
  int month,
  int francs, {
  String ownerId = _owner,
  AvsEvidenceTier tier = AvsEvidenceTier.avsFundDecision,
  AvsPensionBenefitKind benefitKind = AvsPensionBenefitKind.oldAge,
  AvsOldAgePensionKind pensionKind = AvsOldAgePensionKind.ordinary,
  Set<AvsOldAgeAdjustment> adjustments = const {},
  Map<AvsExcludedComponentKind, ChfAmount> excluded = const {},
  AvsEvidence? evidence,
}) =>
    AvsMonthlyOldAgeFact(
      month: month,
      state: AvsMonthlyOldAgeState.paidEligibleOldAge,
      benefitKind: benefitKind,
      determiningOldAgePensionChf: ChfAmount.fromFrancs(francs),
      pensionKind: pensionKind,
      adjustments: adjustments,
      excludedCashflowsChf: excluded,
      evidence: evidence ??
          _evidence(
            ownerId,
            tier: tier,
            month: month,
          ),
    );

AvsMonthlyOldAgeFact _paidCents(
  int month,
  int cents, {
  String ownerId = _owner,
  AvsEvidenceTier tier = AvsEvidenceTier.avsFundDecision,
  AvsPensionBenefitKind benefitKind = AvsPensionBenefitKind.oldAge,
  AvsEvidence? evidence,
}) =>
    AvsMonthlyOldAgeFact(
      month: month,
      state: AvsMonthlyOldAgeState.paidEligibleOldAge,
      benefitKind: benefitKind,
      determiningOldAgePensionChf: ChfAmount.fromCents(cents),
      pensionKind: AvsOldAgePensionKind.ordinary,
      adjustments: const {},
      excludedCashflowsChf: const {},
      evidence: evidence ??
          _evidence(
            ownerId,
            tier: tier,
            month: month,
          ),
    );

AvsMonthlyOldAgeFact _noOldAge(
  int month, {
  String ownerId = _owner,
  AvsEvidenceTier tier = AvsEvidenceTier.avsFundDecision,
  AvsPensionBenefitKind benefitKind = AvsPensionBenefitKind.none,
  Map<AvsExcludedComponentKind, ChfAmount> excluded = const {},
  AvsEvidence? evidence,
}) =>
    AvsMonthlyOldAgeFact(
      month: month,
      state: AvsMonthlyOldAgeState.explicitlyNoOldAgeEntitlement,
      benefitKind: benefitKind,
      determiningOldAgePensionChf: null,
      pensionKind: null,
      adjustments: const {},
      excludedCashflowsChf: excluded,
      evidence: evidence ??
          _evidence(
            ownerId,
            tier: tier,
            month: month,
          ),
    );

AvsMonthlyOldAgeFact _unknown(
  int month, {
  String ownerId = _owner,
  AvsEvidence? evidence,
}) =>
    AvsMonthlyOldAgeFact(
      month: month,
      state: AvsMonthlyOldAgeState.unknown,
      benefitKind: AvsPensionBenefitKind.unknown,
      determiningOldAgePensionChf: null,
      pensionKind: null,
      adjustments: const {},
      excludedCashflowsChf: const {},
      evidence: evidence ?? _evidence(ownerId, month: month),
    );

List<AvsMonthlyOldAgeFact> _fullYear(
  int francs, {
  String ownerId = _owner,
  AvsEvidenceTier tier = AvsEvidenceTier.avsFundDecision,
  Set<AvsOldAgeAdjustment> adjustments = const {},
  Map<AvsExcludedComponentKind, ChfAmount> excluded = const {},
}) =>
    List.generate(
      12,
      (index) => _paid(
        index + 1,
        francs,
        ownerId: ownerId,
        tier: tier,
        adjustments: adjustments,
        excluded: excluded,
      ),
    );

AvsDecemberEntitlementEvidence _december(
  AvsDecemberEntitlementState state, {
  String ownerId = _owner,
  AvsEvidenceTier tier = AvsEvidenceTier.avsFundDecision,
  bool includeSourceDate = true,
  bool includeReference = true,
  DateTime? sourceDate,
  int legalYear = _legalYear,
  bool? aliveOnDecemberFirst,
}) =>
    AvsDecemberEntitlementEvidence(
      state: state,
      ownerId: ownerId,
      evidenceTier: tier,
      aliveOnDecemberFirst: aliveOnDecemberFirst ??
          (state == AvsDecemberEntitlementState.entitled ? true : null),
      decisionOrProviderRef:
          includeReference ? 'december-entitlement-$ownerId' : null,
      sourceDate:
          includeSourceDate ? sourceDate ?? DateTime.utc(2026, 12, 1) : null,
      legalYear: legalYear,
    );

AvsThirteenthPensionInput _input({
  required List<AvsMonthlyOldAgeFact> months,
  String ownerId = _owner,
  int calendarYear = 2026,
  AvsDecemberEntitlementEvidence? december,
  AvsPensionPaymentCadence cadence = AvsPensionPaymentCadence.monthly,
  DateTime? supplementPaymentDate,
  ChfAmount? previouslyPaid,
  DateTime? calculationDate,
  int legalYear = _legalYear,
  String ruleVersion = _ruleVersion,
}) =>
    AvsThirteenthPensionInput(
      ownerId: ownerId,
      calendarYear: calendarYear,
      months: months,
      decemberEntitlement: december ??
          _december(
            AvsDecemberEntitlementState.entitled,
            ownerId: ownerId,
          ),
      paymentCadence: cadence,
      supplementPaymentDate: supplementPaymentDate,
      previouslyPaidThirteenthChf: previouslyPaid,
      calculationDate: calculationDate ?? DateTime.utc(2026, 12, 15),
      legalYear: legalYear,
      ruleVersion: ruleVersion,
    );

void _expectCents(ChfAmount? actual, int cents) {
  expect(actual, isNotNull);
  expect(actual!.cents, cents);
}

void main() {
  group('G1-AVS-02 numbered cash-flow contract', () {
    test('01 full maximum pension keeps monthly and December cash distinct',
        () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: _fullYear(2520)),
      );

      expect(result.readiness, AvsThirteenthReadiness.certified);
      _expectCents(result.decemberOrdinaryOldAgePensionChf, 252000);
      _expectCents(result.eligibleOldAgePensionsPaidChf, 3024000);
      expect(
        result.monthlyAccrualPartsChf.map((part) => part?.cents),
        everyElement(21000),
      );
      _expectCents(result.certifiedThirteenthPensionChf, 252000);
      _expectCents(result.eligibleOldAgeCashflowWithSupplementChf, 3276000);
      expect(result.paymentCadence, AvsPensionPaymentCadence.monthly);
      expect(result.supplementPaymentDate, isNull);
    });

    test('02 full minimum pension produces 1260 supplement', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: _fullYear(1260)),
      );

      _expectCents(result.certifiedThirteenthPensionChf, 126000);
      _expectCents(result.eligibleOldAgeCashflowWithSupplementChf, 1638000);
    });

    test('03 July start produces six monthly accruals and 900 supplement', () {
      final months = [
        for (var month = 1; month <= 6; month++) _noOldAge(month),
        for (var month = 7; month <= 12; month++) _paid(month, 1800),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      _expectCents(result.eligibleOldAgePensionsPaidChf, 1080000);
      _expectCents(result.certifiedThirteenthPensionChf, 90000);
      _expectCents(result.eligibleOldAgeCashflowWithSupplementChf, 1170000);
      expect(result.monthlyAccrualPartsChf.take(6).map((p) => p?.cents),
          everyElement(0));
      expect(result.monthlyAccrualPartsChf.skip(6).map((p) => p?.cents),
          everyElement(15000));
    });

    test('04 December-only 1266 rounds 105.50 up to 106 francs', () {
      final months = [
        for (var month = 1; month <= 11; month++) _noOldAge(month),
        _paid(12, 1266),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      _expectCents(result.monthlyAccrualPartsChf[11], 10550);
      _expectCents(result.certifiedThirteenthPensionChf, 10600);
      _expectCents(result.eligibleOldAgePensionsPaidChf, 126600);
    });

    test('05 October start rounds 317.49 down to 317 francs', () {
      final months = [
        for (var month = 1; month <= 9; month++) _noOldAge(month),
        for (var month = 10; month <= 12; month++) _paid(month, 1270),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(result.monthlyAccrualPartsChf.skip(9).map((p) => p?.cents),
          everyElement(10583));
      _expectCents(result.certifiedThirteenthPensionChf, 31700);
    });

    test('06 mid-year couple cap change produces OFAS 2205 supplement', () {
      final months = [
        for (var month = 1; month <= 6; month++) _paid(month, 2520),
        for (var month = 7; month <= 12; month++)
          _paid(
            month,
            1890,
            adjustments: const {AvsOldAgeAdjustment.capped},
          ),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      _expectCents(result.certifiedThirteenthPensionChf, 220500);
    });

    test('07 anticipated pension uses the reduced amount actually paid', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(
            2160,
            adjustments: const {AvsOldAgeAdjustment.anticipated},
          ),
        ),
      );

      _expectCents(result.certifiedThirteenthPensionChf, 216000);
    });

    test('08 anticipation amount change produces OFAS 2198 supplement', () {
      final months = [
        for (var month = 1; month <= 8; month++)
          _paid(
            month,
            2160,
            adjustments: const {AvsOldAgeAdjustment.anticipated},
          ),
        for (var month = 9; month <= 12; month++)
          _paid(
            month,
            2275,
            adjustments: const {AvsOldAgeAdjustment.anticipated},
          ),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      _expectCents(result.certifiedThirteenthPensionChf, 219800);
      expect(result.monthlyAccrualPartsChf[8]?.cents, 18958);
    });

    test('09 revoked deferral includes the increased pension', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(
            2951,
            adjustments: const {AvsOldAgeAdjustment.deferredIncrease},
          ),
        ),
      );

      _expectCents(result.monthlyAccrualPartsChf.first, 24592);
      _expectCents(result.certifiedThirteenthPensionChf, 295100);
    });

    test('10 fully deferred pension is explicitly not entitled', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: [for (var month = 1; month <= 12; month++) _noOldAge(month)],
          december: _december(
            AvsDecemberEntitlementState.notEntitled,
            aliveOnDecemberFirst: true,
          ),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.explicitlyNotEntitled);
      _expectCents(result.certifiedThirteenthPensionChf, 0);
    });

    test('11 partial deferral uses only the paid 1000-franc share', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(
            1000,
            adjustments: const {AvsOldAgeAdjustment.deferredIncrease},
          ),
        ),
      );

      expect(result.monthlyAccrualPartsChf.first?.cents, 8333);
      _expectCents(result.certifiedThirteenthPensionChf, 100000);
    });

    test('12 death on 30 November yields zero without prorata', () {
      final months = [
        for (var month = 1; month <= 11; month++) _paid(month, 2000),
        _noOldAge(12),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: months,
          december: _december(
            AvsDecemberEntitlementState.notEntitled,
            aliveOnDecemberFirst: false,
          ),
        ),
      );

      _expectCents(result.eligibleOldAgePensionsPaidChf, 2200000);
      _expectCents(result.certifiedThirteenthPensionChf, 0);
      _expectCents(result.eligibleOldAgeCashflowWithSupplementChf, 2200000);
    });

    test('13 death after 1 December leaves pension and supplement due', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: _fullYear(2000)),
      );

      _expectCents(result.decemberOrdinaryOldAgePensionChf, 200000);
      _expectCents(result.certifiedThirteenthPensionChf, 200000);
      _expectCents(result.eligibleOldAgeCashflowWithSupplementChf, 2600000);
    });

    test('14 AI months are excluded before old-age conversion in July', () {
      final months = [
        for (var month = 1; month <= 6; month++)
          _noOldAge(
            month,
            benefitKind: AvsPensionBenefitKind.disability,
            excluded: const {
              AvsExcludedComponentKind.disabilityPension:
                  ChfAmount.fromFrancs(1800),
            },
          ),
        for (var month = 7; month <= 12; month++) _paid(month, 2000),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      _expectCents(result.eligibleOldAgePensionsPaidChf, 1200000);
      _expectCents(result.certifiedThirteenthPensionChf, 100000);
      expect(
        result.excludedComponentKinds,
        contains(AvsExcludedComponentKind.disabilityPension),
      );
    });

    test('15 survivor pension only is explicitly not entitled', () {
      final months = [
        for (var month = 1; month <= 12; month++)
          _noOldAge(
            month,
            benefitKind: AvsPensionBenefitKind.survivor,
            excluded: const {
              AvsExcludedComponentKind.survivorPension:
                  ChfAmount.fromFrancs(2100),
            },
          ),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: months,
          december: _december(
            AvsDecemberEntitlementState.notEntitled,
            aliveOnDecemberFirst: true,
          ),
        ),
      );

      _expectCents(result.certifiedThirteenthPensionChf, 0);
      expect(result.readiness, AvsThirteenthReadiness.explicitlyNotEntitled);
    });

    test('16 child complementary and AVS21 cashflows stay excluded', () {
      const excluded = {
        AvsExcludedComponentKind.childPension: ChfAmount.fromFrancs(500),
        AvsExcludedComponentKind.complementaryPension:
            ChfAmount.fromFrancs(100),
        AvsExcludedComponentKind.avs21TransitionSupplement:
            ChfAmount.fromFrancs(50),
      };
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: _fullYear(2000, excluded: excluded)),
      );

      _expectCents(result.eligibleOldAgePensionsPaidChf, 2400000);
      _expectCents(result.certifiedThirteenthPensionChf, 200000);
      expect(result.excludedComponentKinds, containsAll(excluded.keys));
    });

    test('17 widow supplement already included is not added twice', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(
            2160,
            adjustments: const {
              AvsOldAgeAdjustment.widowSupplementIncluded,
            },
          ),
        ),
      );

      _expectCents(result.certifiedThirteenthPensionChf, 216000);
    });

    test('18 couple is two owner-scoped calculations without a second cap', () {
      final self = AvsThirteenthPensionCalculator.calculate(
        _input(months: _fullYear(1890)),
      );
      final partner = AvsThirteenthPensionCalculator.calculate(
        _input(
          ownerId: _partner,
          months: _fullYear(1890, ownerId: _partner),
          december: _december(
            AvsDecemberEntitlementState.entitled,
            ownerId: _partner,
          ),
        ),
      );

      _expectCents(self.certifiedThirteenthPensionChf, 189000);
      _expectCents(partner.certifiedThirteenthPensionChf, 189000);
      expect(
        self.certifiedThirteenthPensionChf!.cents +
            partner.certifiedThirteenthPensionChf!.cents,
        378000,
      );
    });

    test('19 one unknown month blocks the certified amount', () {
      final months = _fullYear(2000)..[4] = _unknown(5);
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.educationalEstimateChf, isNull);
      expect(result.readiness, AvsThirteenthReadiness.missingMonthlyHistory);
      expect(result.missingFields, ['months.5.determiningOldAgePensionChf']);
    });

    test('20 unknown component blocks the certified amount', () {
      final months = _fullYear(2000);
      months[0] = _paid(
        1,
        2000,
        excluded: const {
          AvsExcludedComponentKind.unknown: ChfAmount.fromFrancs(100),
        },
      );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.readiness, AvsThirteenthReadiness.unclassifiedComponent);
      expect(result.missingFields, ['months.1.excludedComponentKinds.unknown']);
    });

    test('21 July projection remains illustrative and never certified', () {
      final input = AvsThirteenthPensionInput.fullYearScenario(
        ownerId: _owner,
        calendarYear: 2026,
        determiningMonthlyOldAgePensionChf: const ChfAmount.fromFrancs(2000),
        sourceDate: DateTime.utc(2026, 7, 13),
        calculationDate: DateTime.utc(2026, 7, 13),
        legalYear: _legalYear,
        ruleVersion: _ruleVersion,
        scenarioRef: 'educational-max-pension-scenario',
      );
      final result = AvsThirteenthPensionCalculator.calculate(input);

      expect(result.certifiedThirteenthPensionChf, isNull);
      _expectCents(result.educationalEstimateChf, 200000);
      expect(result.readiness, AvsThirteenthReadiness.illustrativeOnly);
      expect(result.calculatedAt, DateTime.utc(2026, 7, 13));
    });

    test('22 annual article 44 payment uses seven entitlement months', () {
      final months = [
        for (var month = 1; month <= 5; month++) _noOldAge(month),
        for (var month = 6; month <= 12; month++) _paid(month, 200),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: months,
          cadence: AvsPensionPaymentCadence.annualArticle44Paragraph2,
          supplementPaymentDate: DateTime.utc(2027, 6, 15),
        ),
      );

      expect(result.monthlyAccrualPartsChf[5]?.cents, 1667);
      _expectCents(result.certifiedThirteenthPensionChf, 11700);
      expect(
        result.paymentCadence,
        AvsPensionPaymentCadence.annualArticle44Paragraph2,
      );
      expect(result.supplementPaymentDate, DateTime.utc(2027, 6, 15));
    });

    test('23 survivor replacement before December yields zero', () {
      final months = [
        for (var month = 1; month <= 8; month++) _paid(month, 2000),
        for (var month = 9; month <= 12; month++)
          _noOldAge(
            month,
            benefitKind: AvsPensionBenefitKind.survivor,
            excluded: const {
              AvsExcludedComponentKind.survivorPension:
                  ChfAmount.fromFrancs(2200),
            },
          ),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: months,
          december: _december(
            AvsDecemberEntitlementState.notEntitled,
            aliveOnDecemberFirst: true,
          ),
        ),
      );

      _expectCents(result.certifiedThirteenthPensionChf, 0);
      _expectCents(result.eligibleOldAgePensionsPaidChf, 1600000);
    });

    test('24 sourced foreign-transfer extinction before December yields zero',
        () {
      final months = [
        for (var month = 1; month <= 10; month++) _paid(month, 2000),
        _noOldAge(11),
        _noOldAge(12),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: months,
          december: _december(
            AvsDecemberEntitlementState.notEntitled,
            aliveOnDecemberFirst: true,
          ),
        ),
      );

      _expectCents(result.certifiedThirteenthPensionChf, 0);
      expect(result.readiness, AvsThirteenthReadiness.explicitlyNotEntitled);
    });

    test('25 upward retroactive correction exposes plus 50 francs', () {
      final months = [
        for (var month = 1; month <= 6; month++) _paid(month, 2100),
        for (var month = 7; month <= 12; month++) _paid(month, 2000),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: months,
          previouslyPaid: const ChfAmount.fromFrancs(2000),
        ),
      );

      _expectCents(result.certifiedThirteenthPensionChf, 205000);
      _expectCents(result.correctionAgainstPreviousPaymentChf, 5000);
    });

    test('26 downward retroactive correction exposes minus 50 francs', () {
      final months = [
        for (var month = 1; month <= 6; month++) _paid(month, 1900),
        for (var month = 7; month <= 12; month++) _paid(month, 2000),
      ];
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: months,
          previouslyPaid: const ChfAmount.fromFrancs(2000),
        ),
      );

      _expectCents(result.certifiedThirteenthPensionChf, 195000);
      _expectCents(result.correctionAgainstPreviousPaymentChf, -5000);
    });

    test('27 calendar year 2025 is explicitly not in force', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2520),
          calendarYear: 2025,
          calculationDate: DateTime.utc(2025, 12, 15),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.notInForce);
      _expectCents(result.certifiedThirteenthPensionChf, 0);
      _expectCents(result.eligibleOldAgePensionsPaidChf, 3024000);
      _expectCents(result.eligibleOldAgeCashflowWithSupplementChf, 3024000);
    });
  });

  group('G1-AVS-02 structural fail-closed contract', () {
    test('requires a non-empty envelope ownerId', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          ownerId: '   ',
          months: _fullYear(2000, ownerId: '   '),
          december: _december(
            AvsDecemberEntitlementState.entitled,
            ownerId: '   ',
          ),
        ),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['ownerId']);
    });

    test('requires exactly twelve months', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: _fullYear(2000).take(11).toList()),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['months.exactly12']);
    });

    test('rejects duplicate month', () {
      final months = _fullYear(2000)..[11] = _paid(11, 2000);
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.missingFields, ['months.uniqueOrdered1To12']);
    });

    test('rejects months 1 to 12 when their order is shuffled', () {
      final months = _fullYear(2000);
      final first = months[0];
      months[0] = months[1];
      months[1] = first;
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.missingFields, ['months.uniqueOrdered1To12']);
    });

    test('rejects month outside 1 to 12', () {
      final months = _fullYear(2000)..[11] = _paid(13, 2000);
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.missingFields, ['months.12.month']);
    });

    test('exact money boundary rejects NaN and infinity', () {
      expect(
        () => ChfAmount.fromLegacyDouble(double.nan),
        throwsArgumentError,
      );
      expect(
        () => ChfAmount.fromLegacyDouble(double.infinity),
        throwsArgumentError,
      );
      expect(
        () => ChfAmount.fromLegacyDouble(double.negativeInfinity),
        throwsArgumentError,
      );
    });

    test('rejects a negative determining pension', () {
      final months = _fullYear(2000)..[0] = _paidCents(1, -1);
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.missingFields, ['months.1.determiningOldAgePensionChf']);
    });

    test('paid eligible old-age state requires an explicit amount', () {
      final months = _fullYear(2000)
        ..[0] = AvsMonthlyOldAgeFact(
          month: 1,
          state: AvsMonthlyOldAgeState.paidEligibleOldAge,
          benefitKind: AvsPensionBenefitKind.oldAge,
          determiningOldAgePensionChf: null,
          pensionKind: AvsOldAgePensionKind.ordinary,
          adjustments: const {},
          excludedCashflowsChf: const {},
          evidence: _evidence(_owner, month: 1),
        );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(result.readiness, AvsThirteenthReadiness.missingMonthlyHistory);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['months.1.determiningOldAgePensionChf']);
    });

    test('explicit no-entitlement state rejects an attached amount', () {
      final months = _fullYear(2000)
        ..[0] = AvsMonthlyOldAgeFact(
          month: 1,
          state: AvsMonthlyOldAgeState.explicitlyNoOldAgeEntitlement,
          benefitKind: AvsPensionBenefitKind.none,
          determiningOldAgePensionChf: const ChfAmount.fromFrancs(2000),
          pensionKind: null,
          adjustments: const {},
          excludedCashflowsChf: const {},
          evidence: _evidence(_owner, month: 1),
        );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['months.1.determiningOldAgePensionChf']);
    });

    test('rejects owner mismatch', () {
      final months = _fullYear(2000)..[0] = _paid(1, 2000, ownerId: _partner);
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.missingFields, ['months.1.evidence.ownerId']);
    });

    test('calculationDate must be a canonical UTC instant', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          calculationDate: DateTime(2026, 12, 15),
        ),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['calculationDate.mustBeUtc']);
    });

    test('present supplementPaymentDate must be a canonical UTC instant', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          cadence: AvsPensionPaymentCadence.annualArticle44Paragraph2,
          supplementPaymentDate: DateTime(2027, 6, 15),
        ),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['supplementPaymentDate.mustBeUtc']);
    });

    test('every monthly sourceDate must be a canonical UTC instant', () {
      final months = _fullYear(2000)
        ..[4] = _paid(
          5,
          2000,
          evidence: _evidence(
            _owner,
            month: 5,
            sourceDate: DateTime(2026, 12, 1),
          ),
        );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(result.readiness, AvsThirteenthReadiness.sourceTooWeak);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['months.5.evidence.sourceDate.mustBeUtc']);
    });

    test('every monthly effectiveFrom must be a canonical UTC instant', () {
      final months = _fullYear(2000)
        ..[5] = _paid(
          6,
          2000,
          evidence: _evidence(
            _owner,
            month: 6,
            effectiveFrom: DateTime(2026, 6, 1),
          ),
        );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(
        result.missingFields,
        ['months.6.evidence.effectiveFrom.mustBeUtc'],
      );
    });

    test('December sourceDate must be a canonical UTC instant', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          december: _december(
            AvsDecemberEntitlementState.entitled,
            sourceDate: DateTime(2026, 12, 1),
          ),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.sourceTooWeak);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(
        result.missingFields,
        ['decemberEntitlement.sourceDate.mustBeUtc'],
      );
    });

    test('official effectiveFrom cannot postdate the described month', () {
      final months = _fullYear(2000)
        ..[0] = _paid(
          1,
          2000,
          evidence: _evidence(
            _owner,
            month: 1,
            effectiveFrom: DateTime.utc(2026, 2, 1),
          ),
        );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(
        result.missingFields,
        ['months.1.evidence.effectiveFrom.afterDescribedMonth'],
      );
    });

    test('future official facts keep the effectiveFrom month invariant', () {
      final months = _fullYear(2000)
        ..[0] = _paid(
          1,
          2000,
          evidence: _evidence(
            _owner,
            month: 1,
            effectiveFrom: DateTime.utc(2027, 2, 1),
          ),
        );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: months,
          calendarYear: 2027,
          calculationDate: DateTime.utc(2027, 12, 15),
        ),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(
        result.missingFields,
        ['months.1.evidence.effectiveFrom.afterDescribedMonth'],
      );
    });

    test('winter UTC effectiveFrom uses the Zurich civil month', () {
      final months = _fullYear(2000)
        ..[0] = _paid(
          1,
          2000,
          evidence: _evidence(
            _owner,
            month: 1,
            effectiveFrom: DateTime.utc(2026, 1, 31, 23, 30),
          ),
        );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(
        result.missingFields,
        ['months.1.evidence.effectiveFrom.afterDescribedMonth'],
      );
    });

    test('summer UTC effectiveFrom uses the Zurich civil month', () {
      final months = _fullYear(2000)
        ..[5] = _paid(
          6,
          2000,
          evidence: _evidence(
            _owner,
            month: 6,
            effectiveFrom: DateTime.utc(2026, 6, 30, 22, 30),
          ),
        );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(
        result.missingFields,
        ['months.6.evidence.effectiveFrom.afterDescribedMonth'],
      );
    });

    test('annual article 44 cadence requires a supplement payment date', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          cadence: AvsPensionPaymentCadence.annualArticle44Paragraph2,
        ),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.missingFields, ['supplementPaymentDate']);
      expect(
        result.paymentCadence,
        AvsPensionPaymentCadence.annualArticle44Paragraph2,
      );
      expect(result.supplementPaymentDate, isNull);
    });

    test('annual supplement payment date cannot precede Zurich 1 December', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          cadence: AvsPensionPaymentCadence.annualArticle44Paragraph2,
          supplementPaymentDate: DateTime.utc(2026, 11, 30, 22, 59),
        ),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(
        result.missingFields,
        ['supplementPaymentDate.beforeEntitlementDate'],
      );
    });

    test('official 2027 data cannot reuse the 2026 legal snapshot', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          calendarYear: 2027,
          calculationDate: DateTime.utc(2027, 12, 15),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.unsupportedLegalYear);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.educationalEstimateChf, isNull);
      expect(result.missingFields, ['calendarYear.requiresScenarioSnapshot']);
    });

    test('user-declared 2027 data cannot reuse the 2026 legal snapshot', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(
            2000,
            tier: AvsEvidenceTier.userDeclaredFromDocument,
          ),
          december: _december(
            AvsDecemberEntitlementState.entitled,
            tier: AvsEvidenceTier.userDeclaredFromDocument,
          ),
          calendarYear: 2027,
          calculationDate: DateTime.utc(2027, 12, 15),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.unsupportedLegalYear);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.educationalEstimateChf, isNull);
      expect(result.missingFields, ['calendarYear.requiresScenarioSnapshot']);
    });

    test('2027 full-year scenario keeps the 2026 snapshot illustrative', () {
      final input = AvsThirteenthPensionInput.fullYearScenario(
        ownerId: _owner,
        calendarYear: 2027,
        determiningMonthlyOldAgePensionChf: const ChfAmount.fromFrancs(2000),
        sourceDate: DateTime.utc(2027, 7, 13),
        calculationDate: DateTime.utc(2027, 7, 13),
        legalYear: _legalYear,
        ruleVersion: _ruleVersion,
        scenarioRef: '2026-snapshot-illustrative-2027',
      );
      final result = AvsThirteenthPensionCalculator.calculate(input);

      expect(result.readiness, AvsThirteenthReadiness.illustrativeOnly);
      expect(result.certifiedThirteenthPensionChf, isNull);
      _expectCents(result.educationalEstimateChf, 200000);
    });

    test('missing monthly sourceDate is sourceTooWeak', () {
      final months = _fullYear(2000)
        ..[0] = _paid(
          1,
          2000,
          evidence: _evidence(
            _owner,
            includeSourceDate: false,
            month: 1,
          ),
        );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(result.readiness, AvsThirteenthReadiness.sourceTooWeak);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['months.1.evidence.sourceDate']);
    });

    test('missing provider reference is sourceTooWeak', () {
      final months = _fullYear(2000)
        ..[0] = _paid(
          1,
          2000,
          evidence: _evidence(
            _owner,
            includeReference: false,
            month: 1,
          ),
        );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(result.readiness, AvsThirteenthReadiness.sourceTooWeak);
      expect(result.missingFields, ['months.1.evidence.documentOrProviderRef']);
    });

    test('incompatible legal year is unsupported', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: _fullYear(2000), legalYear: 2025),
      );

      expect(result.readiness, AvsThirteenthReadiness.unsupportedLegalYear);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['legalYear']);
    });

    test('unsupported rule version is rejected', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          ruleVersion: 'OFAS-C13RV-unknown',
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.unsupportedLegalYear);
      expect(result.missingFields, ['ruleVersion']);
    });

    test('AI cannot be injected as an eligible old-age pension', () {
      final months = _fullYear(2000)
        ..[0] = _paid(
          1,
          1800,
          benefitKind: AvsPensionBenefitKind.disability,
        );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(result.readiness, AvsThirteenthReadiness.unclassifiedComponent);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['months.1.benefitKind.oldAge']);
    });

    test('unknown excluded component fails closed', () {
      final months = _fullYear(2000)
        ..[0] = _paid(
          1,
          2000,
          excluded: const {
            AvsExcludedComponentKind.unknown: ChfAmount.fromFrancs(50),
          },
        );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(result.readiness, AvsThirteenthReadiness.unclassifiedComponent);
      expect(result.missingFields, ['months.1.excludedComponentKinds.unknown']);
    });

    test('unknown December entitlement never becomes zero', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          december: _december(AvsDecemberEntitlementState.unknown),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.pendingDecember);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['decemberEntitlement.state']);
    });

    test('entitled December evidence requires alive on 1 December', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          december: AvsDecemberEntitlementEvidence(
            state: AvsDecemberEntitlementState.entitled,
            ownerId: _owner,
            evidenceTier: AvsEvidenceTier.avsFundDecision,
            aliveOnDecemberFirst: null,
            decisionOrProviderRef: 'december-entitlement-$_owner',
            sourceDate: DateTime.utc(2026, 12, 1),
            legalYear: _legalYear,
          ),
        ),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(
        result.missingFields,
        ['decemberEntitlement.aliveOnDecemberFirst'],
      );
    });

    test('entitled plus not alive on 1 December is contradictory', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          december: _december(
            AvsDecemberEntitlementState.entitled,
            aliveOnDecemberFirst: false,
          ),
        ),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(
        result.missingFields,
        ['decemberEntitlement.aliveOnDecemberFirst.contradictsEntitled'],
      );
    });

    test('entitled plus a December no-entitlement month is contradictory', () {
      final months = _fullYear(2000)..[11] = _noOldAge(12);
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(months: months),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(
        result.missingFields,
        ['decemberEntitlement.state.contradictsMonths.12.state'],
      );
    });

    test('not entitled plus a paid December month is contradictory', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          december: _december(
            AvsDecemberEntitlementState.notEntitled,
            aliveOnDecemberFirst: true,
          ),
        ),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(
        result.missingFields,
        ['decemberEntitlement.state.contradictsMonths.12.state'],
      );
    });

    test('official not-entitled resolves zero before prior unknown history',
        () {
      final months = _fullYear(2000)
        ..[0] = _unknown(1)
        ..[11] = _noOldAge(12);
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: months,
          december: _december(
            AvsDecemberEntitlementState.notEntitled,
            aliveOnDecemberFirst: true,
          ),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.explicitlyNotEntitled);
      _expectCents(result.certifiedThirteenthPensionChf, 0);
      expect(result.eligibleOldAgePensionsPaidChf, isNull);
    });

    test('official not-entitled legal zero ignores an absent prior source', () {
      final months = _fullYear(2000)
        ..[0] = _unknown(
          1,
          evidence: _evidence(
            _owner,
            month: 1,
            includeSourceDate: false,
            includeReference: false,
          ),
        )
        ..[11] = _noOldAge(12);
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: months,
          december: _december(
            AvsDecemberEntitlementState.notEntitled,
            aliveOnDecemberFirst: true,
          ),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.explicitlyNotEntitled);
      _expectCents(result.certifiedThirteenthPensionChf, 0);
      expect(result.eligibleOldAgePensionsPaidChf, isNull);
    });

    test('pre-2026 legal zero does not require complete monthly history', () {
      final months = _fullYear(2000)..[0] = _unknown(1);
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: months,
          calendarYear: 2025,
          calculationDate: DateTime.utc(2025, 12, 15),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.notInForce);
      _expectCents(result.certifiedThirteenthPensionChf, 0);
      expect(result.eligibleOldAgePensionsPaidChf, isNull);
    });

    test('rejects a negative previous payment', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          previouslyPaid: const ChfAmount.fromCents(-1),
        ),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['previouslyPaidThirteenthChf']);
    });

    test('UTC instant at Zurich 1 December is in force by civil date', () {
      final sourceDate = DateTime.utc(2026, 11, 30, 23, 30);
      final months = List.generate(
        12,
        (index) => _paid(
          index + 1,
          2000,
          evidence: _evidence(
            _owner,
            month: index + 1,
            sourceDate: sourceDate,
            effectiveFrom: index == 11
                ? DateTime.utc(2026, 11, 30, 23)
                : DateTime.utc(2026, index + 1, 1),
          ),
        ),
      );
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: months,
          december: _december(
            AvsDecemberEntitlementState.entitled,
            sourceDate: sourceDate,
          ),
          calculationDate: DateTime.utc(2026, 11, 30, 23, 30),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.certified);
      _expectCents(result.certifiedThirteenthPensionChf, 200000);
    });

    test('missing December sourceDate never certifies', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          december: _december(
            AvsDecemberEntitlementState.entitled,
            includeSourceDate: false,
          ),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.sourceTooWeak);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['decemberEntitlement.sourceDate']);
    });

    test('December entitlement owner must match independently', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          december: _december(
            AvsDecemberEntitlementState.entitled,
            ownerId: _partner,
          ),
        ),
      );

      expect(
          result.readiness, AvsThirteenthReadiness.providerCorrectionRequired);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(result.missingFields, ['decemberEntitlement.ownerId']);
    });

    test('future official evidence before 1 December cannot certify', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(2000),
          calculationDate: DateTime.utc(2026, 7, 13),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.pendingDecember);
      expect(result.certifiedThirteenthPensionChf, isNull);
      expect(
        result.missingFields,
        contains('decemberEntitlement.sourceDate.future'),
      );
    });

    test('user-declared complete history is never certified', () {
      final result = AvsThirteenthPensionCalculator.calculate(
        _input(
          months: _fullYear(
            2000,
            tier: AvsEvidenceTier.userDeclaredFromDocument,
          ),
          december: _december(
            AvsDecemberEntitlementState.entitled,
            tier: AvsEvidenceTier.userDeclaredFromDocument,
          ),
        ),
      );

      expect(result.readiness, AvsThirteenthReadiness.declaredComplete);
      expect(result.certifiedThirteenthPensionChf, isNull);
      _expectCents(result.educationalEstimateChf, 200000);
    });

    test('inverted couple owners fail independently instead of crossing data',
        () {
      final selfWithPartnerFacts = AvsThirteenthPensionCalculator.calculate(
        _input(
          ownerId: _owner,
          months: _fullYear(1890, ownerId: _partner),
        ),
      );
      final partnerWithSelfFacts = AvsThirteenthPensionCalculator.calculate(
        _input(
          ownerId: _partner,
          months: _fullYear(1890, ownerId: _owner),
          december: _december(
            AvsDecemberEntitlementState.entitled,
            ownerId: _partner,
          ),
        ),
      );

      expect(selfWithPartnerFacts.readiness,
          AvsThirteenthReadiness.providerCorrectionRequired);
      expect(partnerWithSelfFacts.readiness,
          AvsThirteenthReadiness.providerCorrectionRequired);
      expect(selfWithPartnerFacts.certifiedThirteenthPensionChf, isNull);
      expect(partnerWithSelfFacts.certifiedThirteenthPensionChf, isNull);
    });
  });
}
