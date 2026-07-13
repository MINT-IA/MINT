import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';

const _notSeparated = AvsJudicialSeparationEvidence(
  isSeparated: false,
  source: 'confirmed civil-status declaration',
);

AvsPersonPensionInput _oldAge({
  required AvsPersonRole owner,
  double? rawMonthlyPension = 2520,
  int? contributionScale = 44,
  double? pensionPercentage = 1,
  AvsOldAgePaymentMode? paymentMode = AvsOldAgePaymentMode.ordinary,
}) =>
    AvsPersonPensionInput(
      owner: owner,
      entitlement: AvsPensionEntitlement.oldAge,
      rawMonthlyPension: rawMonthlyPension,
      contributionScale: contributionScale,
      pensionPercentage: pensionPercentage,
      oldAgePaymentMode: paymentMode,
    );

AvsPersonPensionInput _noBenefit(AvsPersonRole owner) => AvsPersonPensionInput(
      owner: owner,
      entitlement: AvsPensionEntitlement.none,
    );

AvsPersonPensionInput _disability({
  required AvsPersonRole owner,
  double? rawMonthlyPension = 2520,
  int? contributionScale = 44,
  double? pensionPercentage = 1,
}) =>
    AvsPersonPensionInput(
      owner: owner,
      entitlement: AvsPensionEntitlement.disability,
      rawMonthlyPension: rawMonthlyPension,
      contributionScale: contributionScale,
      pensionPercentage: pensionPercentage,
    );

AvsCouplePensionResult _compute({
  AvsCoupleLegalStatus? status = AvsCoupleLegalStatus.married,
  AvsPersonPensionInput? self,
  AvsPersonPensionInput? partner,
  AvsJudicialSeparationEvidence? separation = _notSeparated,
}) =>
    AvsCalculator.computeCouplePensions(
      AvsCouplePensionInput(
        legalStatus: status,
        self: self ?? _oldAge(owner: AvsPersonRole.self),
        partner: partner ?? _oldAge(owner: AvsPersonRole.partner),
        judicialSeparation: separation,
      ),
    );

void main() {
  group('AVS couple legal contract — LAVS art. 35', () {
    test('6. married scale44 pair caps proportionally at 3780', () {
      final result = _compute();

      expect(result.capState, AvsCoupleCapState.applied);
      expect(result.self.rawMonthlyPension, 2520);
      expect(result.partner.rawMonthlyPension, 2520);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.self.cappedMonthlyPension, closeTo(1890, 0.001));
      expect(result.partner.cappedMonthlyPension, closeTo(1890, 0.001));
      expect(result.householdMonthlyPension, closeTo(3780, 0.001));
      expect(result.formulaLayerMonthlyCapEstimate, 3780);
      expect(result.payableMonthlyCap, 3780);
      expect(result.missingFields, isEmpty);
      expect(result.legalYear, 2026);
      expect(result.legalSource, contains('LAVS art. 35'));
      expect(result.legalSource, contains('RAVS art. 53bis'));
      expect(result.requiresOfficialTableRounding, isFalse);
      expect(result.isHouseholdComplete, isTrue);
    });

    test('7. registered partnership uses identical AVS cap contract', () {
      final married = _compute();
      final registered = _compute(
        status: AvsCoupleLegalStatus.registeredPartnership,
      );

      expect(registered.capState, married.capState);
      expect(
        registered.self.cappedMonthlyPension,
        married.self.cappedMonthlyPension,
      );
      expect(
        registered.partner.cappedMonthlyPension,
        married.partner.cappedMonthlyPension,
      );
      expect(
        registered.householdMonthlyPension,
        married.householdMonthlyPension,
      );
    });

    test('8. cohabiting pair is not capped', () {
      final result = _compute(
        status: AvsCoupleLegalStatus.cohabiting,
        separation: null,
      );

      expect(result.capState, AvsCoupleCapState.notApplicable);
      expect(result.self.cappedMonthlyPension, 2520);
      expect(result.partner.cappedMonthlyPension, 2520);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.householdMonthlyPension, 5040);
      expect(result.scaleWeightedMonthlyCap, isNull);
      expect(result.requiresOfficialTableRounding, isFalse);
      expect(result.isHouseholdComplete, isTrue);
    });

    test('8b. cohabiting raw pensions need no couple-cap scale evidence', () {
      final result = _compute(
        status: AvsCoupleLegalStatus.cohabiting,
        self: _oldAge(
          owner: AvsPersonRole.self,
          contributionScale: null,
          pensionPercentage: null,
          paymentMode: null,
        ),
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          contributionScale: null,
          pensionPercentage: null,
          paymentMode: null,
        ),
        separation: null,
      );

      expect(result.capState, AvsCoupleCapState.notApplicable);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.householdMonthlyPension, 5040);
      expect(result.missingFields, isEmpty);
      expect(result.isHouseholdComplete, isTrue);
    });

    test('9. scale38 plus scale26 selects exact scale34 before lookup', () {
      final result = _compute(
        self: _oldAge(
          owner: AvsPersonRole.self,
          contributionScale: 38,
        ),
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          contributionScale: 26,
        ),
      );
      const expectedScalePercent = (26 / 44 + 2 * (38 / 44)) / 3;
      const expectedCap = 3780 * expectedScalePercent;

      expect(result.self.scalePercentage, closeTo(38 / 44, 1e-12));
      expect(result.partner.scalePercentage, closeTo(26 / 44, 1e-12));
      expect(result.weightedScaleRaw, 34);
      expect(result.weightedContributionScale, 34);
      expect(
        result.scaleWeightedMonthlyCap,
        closeTo(expectedCap, 1e-9),
      );
      expect(
        result.formulaLayerMonthlyCapEstimate,
        closeTo(expectedCap, 1e-9),
      );
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.payableMonthlyCap, isNull);
      expect(result.self.cappedMonthlyPension, isNull);
      expect(result.partner.cappedMonthlyPension, isNull);
      expect(result.householdMonthlyPension, isNull);
      expect(result.capState, AvsCoupleCapState.pending);
      expect(
        result.missingFields,
        ['officialPensionTableProvider.scale.34'],
      );
      expect(result.requiresOfficialTableRounding, isTrue);
      expect(result.isHouseholdComplete, isFalse);
    });

    test('9b. scale44 plus scale21 rounds up to scale37 before lookup', () {
      final result = _compute(
        self: _oldAge(
          owner: AvsPersonRole.self,
          contributionScale: 44,
        ),
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          contributionScale: 21,
        ),
      );

      // RAVS art. 53bis: (21 + 2 × 44) / 3 = 36.33, determining scale 37.
      expect(result.weightedScaleRaw, closeTo(36.333333, 1e-6));
      expect(result.weightedContributionScale, 37);
      expect(
        result.scaleWeightedMonthlyCap,
        closeTo(3780 * (37 / 44), 1e-9),
      );
      expect(
        result.scaleWeightedMonthlyCap,
        isNot(closeTo(3780 * ((21 / 44 + 2) / 3), 0.01)),
      );
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.payableMonthlyCap, isNull);
      expect(result.self.cappedMonthlyPension, isNull);
      expect(result.partner.cappedMonthlyPension, isNull);
      expect(result.householdMonthlyPension, isNull);
      expect(result.capState, AvsCoupleCapState.pending);
      expect(
        result.missingFields,
        ['officialPensionTableProvider.scale.37'],
      );
      expect(result.requiresOfficialTableRounding, isTrue);
      expect(result.isHouseholdComplete, isFalse);
    });

    test('9c. incomplete-scale anticipation adjusts only formula estimate', () {
      final result = _compute(
        self: _oldAge(
          owner: AvsPersonRole.self,
          rawMonthlyPension: 1600,
          contributionScale: 38,
          pensionPercentage: 0.5,
          paymentMode: AvsOldAgePaymentMode.anticipated,
        ),
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          rawMonthlyPension: 1800,
          contributionScale: 26,
          pensionPercentage: 0.75,
          paymentMode: AvsOldAgePaymentMode.anticipated,
        ),
      );
      const baseFormula = 3780 * (34 / 44);

      expect(result.scaleWeightedMonthlyCap, closeTo(baseFormula, 1e-9));
      expect(result.percentageCapMultiplier, 0.75);
      expect(
        result.formulaLayerMonthlyCapEstimate,
        closeTo(baseFormula * 0.75, 1e-9),
      );
      expect(result.payableMonthlyCap, isNull);
      expect(result.rawHouseholdMonthlyPension, 3400);
      expect(result.householdMonthlyPension, isNull);
      expect(result.capState, AvsCoupleCapState.pending);
      expect(
        result.missingFields,
        ['officialPensionTableProvider.scale.34'],
      );
    });

    test('10. separated spouses aggregate raw pensions without cap inputs', () {
      const separated = AvsJudicialSeparationEvidence(
        isSeparated: true,
        source: 'court decision confirmed by the user',
      );
      final result = _compute(
        self: _oldAge(
          owner: AvsPersonRole.self,
          contributionScale: null,
          pensionPercentage: null,
          paymentMode: null,
        ),
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          contributionScale: null,
          pensionPercentage: null,
          paymentMode: null,
        ),
        separation: separated,
      );

      expect(result.capState, AvsCoupleCapState.legalException);
      expect(result.self.cappedMonthlyPension, 2520);
      expect(result.partner.cappedMonthlyPension, 2520);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.householdMonthlyPension, 5040);
      expect(result.judicialSeparationSource, separated.source);
      expect(result.missingFields, isEmpty);
      expect(result.isHouseholdComplete, isTrue);
    });

    test('11. first pension event does not activate cap or require scales', () {
      final result = _compute(
        self: _oldAge(
          owner: AvsPersonRole.self,
          contributionScale: null,
          pensionPercentage: null,
          paymentMode: null,
        ),
        partner: _noBenefit(AvsPersonRole.partner),
        separation: null,
      );

      expect(result.capState, AvsCoupleCapState.notNeeded);
      expect(result.self.rawMonthlyPension, 2520);
      expect(result.self.cappedMonthlyPension, 2520);
      expect(result.partner.rawMonthlyPension, isNull);
      expect(result.partner.cappedMonthlyPension, isNull);
      expect(result.rawHouseholdMonthlyPension, 2520);
      expect(result.householdMonthlyPension, 2520);
      expect(result.missingFields, isEmpty);
      expect(result.isHouseholdComplete, isTrue);
    });

    test('11b. old-age plus disability pensions activate the couple cap', () {
      final result = _compute(
        partner: _disability(owner: AvsPersonRole.partner),
      );

      expect(result.capState, AvsCoupleCapState.applied);
      expect(result.self.rawMonthlyPension, 2520);
      expect(result.partner.rawMonthlyPension, 2520);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.householdMonthlyPension, 3780);
      expect(result.missingFields, isEmpty);
    });

    test('12. missing partner scale makes cap pending, not scale44', () {
      final result = _compute(
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          contributionScale: null,
        ),
      );

      expect(result.capState, AvsCoupleCapState.pending);
      expect(result.partner.rawMonthlyPension, 2520);
      expect(result.partner.scalePercentage, isNull);
      expect(result.partner.cappedMonthlyPension, isNull);
      expect(result.householdMonthlyPension, isNull);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.payableMonthlyCap, isNull);
      expect(result.missingFields, ['partner.contributionScale']);
      expect(result.judicialSeparationSource, _notSeparated.source);
    });

    test('12a. unknown separation blocks cap before scale requests', () {
      final result = _compute(
        self: _oldAge(
          owner: AvsPersonRole.self,
          contributionScale: null,
          pensionPercentage: null,
          paymentMode: null,
        ),
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          contributionScale: null,
          pensionPercentage: null,
          paymentMode: null,
        ),
        separation: null,
      );

      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.householdMonthlyPension, isNull);
      expect(result.capState, AvsCoupleCapState.pending);
      expect(result.missingFields, ['judicialSeparation']);
    });
  });

  group('RAVS art. 53ter percentage treatment', () {
    test('32. anticipated percentage uses the highest percentage', () {
      final result = _compute(
        self: _oldAge(
          owner: AvsPersonRole.self,
          rawMonthlyPension: 1600,
          pensionPercentage: 0.5,
          paymentMode: AvsOldAgePaymentMode.anticipated,
        ),
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          rawMonthlyPension: 1800,
          pensionPercentage: 0.75,
          paymentMode: AvsOldAgePaymentMode.anticipated,
        ),
      );

      expect(result.percentageCapMultiplier, 0.75);
      expect(result.scaleWeightedMonthlyCap, 3780);
      expect(result.formulaLayerMonthlyCapEstimate, closeTo(2835, 0.001));
      expect(result.payableMonthlyCap, closeTo(2835, 0.001));
      expect(result.capState, AvsCoupleCapState.applied);
      expect(result.householdMonthlyPension, closeTo(2835, 0.001));
    });

    test('33. deferred percentage uses the full pension as determinant', () {
      final result = _compute(
        self: _oldAge(
          owner: AvsPersonRole.self,
          rawMonthlyPension: 2100,
          pensionPercentage: 0.5,
          paymentMode: AvsOldAgePaymentMode.deferred,
        ),
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          rawMonthlyPension: 1900,
          pensionPercentage: 0.75,
          paymentMode: AvsOldAgePaymentMode.anticipated,
        ),
      );

      expect(result.percentageCapMultiplier, 1);
      expect(result.scaleWeightedMonthlyCap, 3780);
      expect(result.formulaLayerMonthlyCapEstimate, 3780);
      expect(result.payableMonthlyCap, 3780);
      expect(result.capState, AvsCoupleCapState.applied);
      expect(result.householdMonthlyPension, 3780);
    });
  });

  group('fail-closed missing legal evidence', () {
    test('first pension needs no legal status for raw or payable aggregate',
        () {
      final result = _compute(
        status: null,
        self: _oldAge(
          owner: AvsPersonRole.self,
          contributionScale: null,
          pensionPercentage: null,
          paymentMode: null,
        ),
        partner: _noBenefit(AvsPersonRole.partner),
        separation: null,
      );

      expect(result.capState, AvsCoupleCapState.notNeeded);
      expect(result.rawHouseholdMonthlyPension, 2520);
      expect(result.householdMonthlyPension, 2520);
      expect(result.missingFields, isEmpty);
    });

    test('two disability benefits with unknown status request only status', () {
      final result = _compute(
        status: null,
        self: _disability(owner: AvsPersonRole.self),
        partner: _disability(owner: AvsPersonRole.partner),
        separation: null,
      );

      expect(result.capState, AvsCoupleCapState.notApplicable);
      expect(result.self.rawMonthlyPension, 2520);
      expect(result.partner.rawMonthlyPension, 2520);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.self.cappedMonthlyPension, isNull);
      expect(result.partner.cappedMonthlyPension, isNull);
      expect(result.payableMonthlyCap, isNull);
      expect(result.householdMonthlyPension, isNull);
      expect(result.missingFields, ['legalStatus']);
      expect(result.isHouseholdComplete, isFalse);
    });

    for (final status in [
      AvsCoupleLegalStatus.married,
      AvsCoupleLegalStatus.registeredPartnership,
    ]) {
      test('two disability benefits with ${status.name} wait for AI provider',
          () {
        final result = _compute(
          status: status,
          self: _disability(owner: AvsPersonRole.self),
          partner: _disability(owner: AvsPersonRole.partner),
          separation: null,
        );

        expect(result.capState, AvsCoupleCapState.notApplicable);
        expect(result.rawHouseholdMonthlyPension, 5040);
        expect(result.self.cappedMonthlyPension, isNull);
        expect(result.partner.cappedMonthlyPension, isNull);
        expect(result.payableMonthlyCap, isNull);
        expect(result.householdMonthlyPension, isNull);
        expect(
          result.missingFields,
          ['aiCoupleCapProvider.laiArticle37Paragraph1bis'],
        );
        expect(result.isHouseholdComplete, isFalse);
      });
    }

    test('cohabiting disability benefits aggregate as payable raw pensions',
        () {
      final result = _compute(
        status: AvsCoupleLegalStatus.cohabiting,
        self: _disability(owner: AvsPersonRole.self),
        partner: _disability(owner: AvsPersonRole.partner),
        separation: null,
      );

      expect(result.capState, AvsCoupleCapState.notApplicable);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.self.cappedMonthlyPension, 2520);
      expect(result.partner.cappedMonthlyPension, 2520);
      expect(result.payableMonthlyCap, isNull);
      expect(result.householdMonthlyPension, 5040);
      expect(result.missingFields, isEmpty);
      expect(result.isHouseholdComplete, isTrue);
    });

    test('cohabiting cap stays notApplicable when raw household is partial',
        () {
      final result = _compute(
        status: AvsCoupleLegalStatus.cohabiting,
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          rawMonthlyPension: null,
        ),
        separation: null,
      );

      expect(result.capState, AvsCoupleCapState.notApplicable);
      expect(result.rawHouseholdMonthlyPension, isNull);
      expect(result.self.cappedMonthlyPension, isNull);
      expect(result.partner.cappedMonthlyPension, isNull);
      expect(result.householdMonthlyPension, isNull);
      expect(result.missingFields, ['partner.rawMonthlyPension']);
    });

    test('AI plus AI cap stays notApplicable when raw household is partial',
        () {
      final result = _compute(
        status: null,
        self: _disability(owner: AvsPersonRole.self),
        partner: _disability(
          owner: AvsPersonRole.partner,
          rawMonthlyPension: null,
        ),
        separation: null,
      );

      expect(result.capState, AvsCoupleCapState.notApplicable);
      expect(result.rawHouseholdMonthlyPension, isNull);
      expect(result.self.cappedMonthlyPension, isNull);
      expect(result.partner.cappedMonthlyPension, isNull);
      expect(result.payableMonthlyCap, isNull);
      expect(result.householdMonthlyPension, isNull);
      expect(
        result.missingFields,
        [
          'partner.rawMonthlyPension',
          'legalStatus',
        ],
      );
    });

    test('missing legal status keeps household pending', () {
      final result = _compute(status: null);
      expect(result.capState, AvsCoupleCapState.pending);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.householdMonthlyPension, isNull);
      expect(result.missingFields, contains('legalStatus'));
    });

    test('missing entitlement keeps household pending', () {
      final result = _compute(
        partner: const AvsPersonPensionInput(
          owner: AvsPersonRole.partner,
        ),
      );
      expect(result.capState, AvsCoupleCapState.pending);
      expect(result.rawHouseholdMonthlyPension, isNull);
      expect(result.householdMonthlyPension, isNull);
      expect(result.missingFields, contains('partner.entitlement'));
    });

    test('missing judicial separation evidence keeps cap pending', () {
      final result = _compute(separation: null);
      expect(result.capState, AvsCoupleCapState.pending);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.householdMonthlyPension, isNull);
      expect(result.missingFields, contains('judicialSeparation'));
    });

    test('empty judicial separation source keeps cap pending', () {
      const unsourced = AvsJudicialSeparationEvidence(
        isSeparated: false,
        source: '   ',
      );
      final result = _compute(separation: unsourced);

      expect(result.capState, AvsCoupleCapState.pending);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.householdMonthlyPension, isNull);
      expect(result.missingFields, contains('judicialSeparation.source'));
    });

    test('missing pension keeps household pending, never zero', () {
      final result = _compute(
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          rawMonthlyPension: null,
        ),
      );
      expect(result.capState, AvsCoupleCapState.pending);
      expect(result.partner.rawMonthlyPension, isNull);
      expect(result.partner.cappedMonthlyPension, isNull);
      expect(result.rawHouseholdMonthlyPension, isNull);
      expect(result.householdMonthlyPension, isNull);
      expect(result.missingFields, contains('partner.rawMonthlyPension'));
    });

    test('missing pension percentage keeps household pending', () {
      final result = _compute(
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          pensionPercentage: null,
        ),
      );
      expect(result.capState, AvsCoupleCapState.pending);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.householdMonthlyPension, isNull);
      expect(result.missingFields, contains('partner.pensionPercentage'));
    });

    test('ordinary old-age mode rejects a fractional pension percentage', () {
      final result = _compute(
        partner: _oldAge(
          owner: AvsPersonRole.partner,
          pensionPercentage: 0.5,
          paymentMode: AvsOldAgePaymentMode.ordinary,
        ),
      );

      expect(result.capState, AvsCoupleCapState.pending);
      expect(result.rawHouseholdMonthlyPension, 5040);
      expect(result.householdMonthlyPension, isNull);
      expect(
        result.missingFields,
        contains('partner.pensionPercentage.ordinaryRequiresFullPension'),
      );
    });

    test('scale outside 1 to 44 is rejected instead of clamped', () {
      for (final scale in [0, 45]) {
        final result = _compute(
          partner: _oldAge(
            owner: AvsPersonRole.partner,
            contributionScale: scale,
          ),
        );
        expect(result.capState, AvsCoupleCapState.pending);
        expect(result.rawHouseholdMonthlyPension, 5040);
        expect(result.householdMonthlyPension, isNull);
        expect(result.missingFields, contains('partner.contributionScale'));
      }
    });

    test('swapped person ownership is rejected instead of silently inverted',
        () {
      final result = _compute(
        self: _oldAge(owner: AvsPersonRole.partner),
        partner: _oldAge(owner: AvsPersonRole.self),
      );

      expect(result.capState, AvsCoupleCapState.pending);
      expect(result.rawHouseholdMonthlyPension, isNull);
      expect(result.householdMonthlyPension, isNull);
      expect(
          result.missingFields, containsAll(['self.owner', 'partner.owner']));
    });
  });
}
