import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/property_transmission_calculator.dart';

void main() {
  group('PropertyTransmissionCalculator', () {
    test('matches canonical Raiffeisen property transmission fixture', () {
      final fixture = jsonDecode(
        File(
          'test/fixtures/scenarios/property_transmission_raiffeisen.json',
        ).readAsStringSync(),
      ) as Map<String, dynamic>;
      final result = PropertyTransmissionCalculator.compute(
        PropertyTransmissionInputs.fromJson(
          fixture['inputs'] as Map<String, dynamic>,
        ),
      );
      final expected = fixture['expected'] as Map<String, dynamic>;

      expect(result.scenarioKey, expected['scenarioKey']['value']);
      expect(
        result.computed.propertyEquity,
        expected['computed.propertyEquity']['value'],
      );
      expect(
        result.computed.economicTransferValue,
        expected['computed.economicTransferValue']['value'],
      );
      expect(
        result.computed.parentLiquidityAfterTransfer,
        expected['computed.parentLiquidityAfterTransfer']['value'],
      );
      expect(
        result.computed.annualRetirementMargin,
        expected['computed.annualRetirementMargin']['value'],
      );
      expect(
        result.familyEqualization.immediateEqualizationNeedPerOtherHeir,
        expected['familyEqualization.immediateEqualizationNeedPerOtherHeir']
            ['value'],
      );
      expect(
        result.familyEqualization.immediateEqualizationGap,
        expected['familyEqualization.immediateEqualizationGap']['value'],
      );
      expect(
        result.retirementAffordability.status.rawValue,
        expected['retirementAffordability.status']['value'],
      );
      expect(
        result.familyEqualization.status.rawValue,
        expected['familyEqualization.status']['value'],
      );
      final scenarioStatuses =
          'scenario_statuses: ${result.retirementAffordability.status.rawValue} | '
          'CHF ${_formatScenarioChf(result.computed.annualRetirementMargin)} | '
          '${result.familyEqualization.status.rawValue} | '
          'CHF ${_formatScenarioChf(result.familyEqualization.immediateEqualizationGap)}';
      expect(
        scenarioStatuses,
        "scenario_statuses: needs_review | CHF -8'000 | at_risk | CHF 195'000",
      );
      expect(result.scenarioConfidence, PropertyScenarioConfidence.medium);
      expect(
        result.scenarioConfidenceRationale.limits,
        contains(
          'successionPropertyTransmissionConfidenceLimitLppCapitalTax',
        ),
      );
      expect(
        result.scenarioConfidenceRationale.limits,
        contains(
          'successionPropertyTransmissionConfidenceLimitLiquidityBufferAssumption',
        ),
      );
      expect(
        result.scenarioConfidenceRationale.basis,
        'required_inputs_present',
      );
      expect(
        result.scenarioConfidenceRationale.axes['completeness'],
        'medium',
      );
      expect(
        result.scenarioConfidenceRationale.axes['freshness'],
        'missing_source_dates',
      );
      expect(
        result.scenarioConfidenceRationale.axes['understanding'],
        'educational_triage',
      );
      expect(result.modelScope.classification, 'educational_triage');
      expect(result.modelScope.notLegalPartition, isTrue);
      expect(result.modelScope.requiresSpecialistReview, isTrue);
      expect(
        result.modelScope.unmodelledLegalFactors,
        contains('successionPropertyTransmissionScopeMatrimonialRegime'),
      );
      expect(result.cantonalTax.rank, 3);
      expect(result.cantonalTax.canton, 'VD');
      expect(result.cantonalTax.requiresCantonalReview, isTrue);
      expect(result.retainedRight.label.toLowerCase(), contains("habitation"));
      expect(
        result.retainedRight.label,
        'successionPropertyTransmissionRetainedRightHabitationLabel',
      );
      expect(
        result.formalities,
        contains('successionPropertyTransmissionFormalityNotary'),
      );
      expect(
        result.formalities,
        contains('successionPropertyTransmissionFormalityLandRegistry'),
      );
      expect(result.requiresInputCompletion, isFalse);
    });

    test('degrades to missing_data before quantifying partial local inputs',
        () {
      final result = PropertyTransmissionCalculator.compute(
        const PropertyTransmissionInputs(propertyMarketValue: 1200000),
      );

      expect(result.requiresInputCompletion, isTrue);
      expect(result.scenarioConfidence, PropertyScenarioConfidence.none);
      expect(
        result.scenarioConfidenceRationale.basis,
        'missing_required_inputs',
      );
      expect(result.scenarioConfidenceRationale.axes['completeness'], 'none');
      expect(
        result.missingInputs,
        containsAll(<String>[
          'mortgageBalance',
          'parentLiquidAssets',
          'parentAnnualRetirementIncome',
          'parentAnnualLivingCosts',
          'heirsCount',
        ]),
      );
      expect(
        result.retirementAffordability.status,
        PropertyTransmissionStatus.missingData,
      );
      expect(
        result.familyEqualization.status,
        PropertyTransmissionStatus.missingData,
      );
    });

    test('uses total equalization need across all other heirs', () {
      final result = PropertyTransmissionCalculator.compute(
        const PropertyTransmissionInputs(
          propertyMarketValue: 900000,
          mortgageBalance: 0,
          cashPaidByRecipient: 0,
          mortgageAssumedByRecipient: 0,
          parentLiquidAssets: 100000,
          parentAnnualRetirementIncome: 90000,
          parentAnnualLivingCosts: 70000,
          heirsCount: 3,
        ),
      );

      expect(
        result.familyEqualization.immediateEqualizationNeedPerOtherHeir,
        300000,
      );
      expect(result.familyEqualization.immediateEqualizationNeedTotal, 600000);
      expect(result.familyEqualization.immediateEqualizationGap, 500000);
      expect(
        result.familyEqualization.status,
        PropertyTransmissionStatus.atRisk,
      );
    });

    test('treats explicit zero heirs as not applicable, not missing data', () {
      final result = PropertyTransmissionCalculator.compute(
        const PropertyTransmissionInputs(
          propertyMarketValue: 900000,
          mortgageBalance: 200000,
          parentLiquidAssets: 250000,
          parentAnnualRetirementIncome: 90000,
          parentAnnualLivingCosts: 70000,
          heirsCount: 0,
        ),
      );

      expect(result.requiresInputCompletion, isFalse);
      expect(result.missingInputs, isNot(contains('heirsCount')));
      expect(
        result.familyEqualization.status,
        PropertyTransmissionStatus.notApplicable,
      );
      expect(result.scenarioConfidence, PropertyScenarioConfidence.medium);
    });

    test('degrades when annual living costs are absent', () {
      final result = PropertyTransmissionCalculator.compute(
        const PropertyTransmissionInputs(
          propertyMarketValue: 900000,
          mortgageBalance: 200000,
          parentLiquidAssets: 250000,
          parentAnnualRetirementIncome: 90000,
          heirsCount: 2,
        ),
      );

      expect(result.requiresInputCompletion, isTrue);
      expect(result.missingInputs, contains('parentAnnualLivingCosts'));
      expect(result.scenarioConfidence, PropertyScenarioConfidence.none);
      expect(
        result.scenarioConfidenceRationale.basis,
        'missing_required_inputs',
      );
      expect(
        result.retirementAffordability.status,
        PropertyTransmissionStatus.missingData,
      );
      expect(
        result.retirementAffordability.status,
        isNot(PropertyTransmissionStatus.ok),
      );
      expect(
        result.familyEqualization.status,
        PropertyTransmissionStatus.missingData,
      );
    });

    test('marks freshness current when all tracked source dates are recent',
        () {
      final result = PropertyTransmissionCalculator.compute(
        PropertyTransmissionInputs(
          propertyMarketValue: 900000,
          mortgageBalance: 200000,
          parentLiquidAssets: 180000,
          parentAnnualRetirementIncome: 90000,
          parentAnnualLivingCosts: 70000,
          heirsCount: 2,
          inputSourceDates: {
            'propertyMarketValue': DateTime.utc(2026, 2, 15),
            'mortgageBalance': DateTime.utc(2026, 5, 31),
            'parentLiquidAssets': DateTime.utc(2026, 6, 30),
            'parentAnnualRetirementIncome': DateTime.utc(2026, 1, 31),
            'parentAnnualLivingCosts': DateTime.utc(2026, 6, 30),
          },
          freshnessAsOf: DateTime.utc(2026, 7, 1),
        ),
      );

      expect(
        result.scenarioConfidenceRationale.axes['freshness'],
        'current_source_dates',
      );
    });

    test('marks freshness stale when a tracked source date is old', () {
      final result = PropertyTransmissionCalculator.compute(
        PropertyTransmissionInputs(
          propertyMarketValue: 900000,
          mortgageBalance: 200000,
          parentLiquidAssets: 250000,
          parentAnnualRetirementIncome: 90000,
          parentAnnualLivingCosts: 70000,
          heirsCount: 2,
          inputSourceDates: {
            'propertyMarketValue': DateTime.utc(2026, 2, 15),
            'mortgageBalance': DateTime.utc(2024, 1, 1),
            'parentLiquidAssets': DateTime.utc(2026, 6, 30),
            'parentAnnualRetirementIncome': DateTime.utc(2026, 1, 31),
            'parentAnnualLivingCosts': DateTime.utc(2026, 6, 30),
          },
          freshnessAsOf: DateTime.utc(2026, 7, 1),
        ),
      );

      expect(
        result.scenarioConfidenceRationale.axes['freshness'],
        'stale_source_dates',
      );
    });

    test('preserves estimated retirement-income provenance', () {
      final result = PropertyTransmissionCalculator.compute(
        const PropertyTransmissionInputs(
          propertyMarketValue: 900000,
          mortgageBalance: 200000,
          parentLiquidAssets: 250000,
          parentAnnualRetirementIncome: 90000,
          parentAnnualRetirementIncomeSource: 'estimated',
          parentAnnualRetirementIncomeSourceKeys: [
            'prevoyance.renteAVSEstimeeMensuelle',
            'prevoyance.projectedRenteLpp',
          ],
          parentAnnualLivingCosts: 70000,
          heirsCount: 0,
        ),
      );

      expect(result.parentAnnualRetirementIncomeSource, 'estimated');
      expect(
        result.scenarioConfidenceRationale.basis,
        'required_inputs_present_with_estimated_composition',
      );
      expect(result.scenarioConfidenceRationale.axes['completeness'], 'low');
      expect(
        result.scenarioConfidenceRationale.composedInputs,
        contains(
          'parentAnnualRetirementIncome:prevoyance.renteAVSEstimeeMensuelle+prevoyance.projectedRenteLpp',
        ),
      );
      expect(
        result.scenarioConfidenceRationale.semanticsValue,
        contains('composed_inputs=parentAnnualRetirementIncome:'),
      );
      expect(result.requiresInputCompletion, isFalse);
    });

    test(
        'documents liquidity and LPP capital-tax limits as product assumptions',
        () {
      final result = PropertyTransmissionCalculator.compute(
        const PropertyTransmissionInputs(
          propertyMarketValue: 900000,
          mortgageBalance: 200000,
          parentLiquidAssets: 180000,
          parentAnnualRetirementIncome: 90000,
          parentAnnualLivingCosts: 70000,
          heirsCount: 2,
        ),
      );

      expect(
        result.scenarioConfidenceRationale.limits,
        containsAll(<String>[
          'successionPropertyTransmissionConfidenceLimitLiquidityBufferAssumption',
          'successionPropertyTransmissionConfidenceLimitLppCapitalTax',
        ]),
      );
      expect(
        result.retirementAffordability.reasons,
        contains(
          'successionPropertyTransmissionRetirementReasonLiquidityCoverageBelowThreeYears',
        ),
      );
    });

    test('exposes localization keys instead of user-facing prose', () {
      final completeResult = PropertyTransmissionCalculator.compute(
        const PropertyTransmissionInputs(
          propertyMarketValue: 900000,
          mortgageBalance: 200000,
          parentLiquidAssets: 120000,
          parentAnnualRetirementIncome: 60000,
          parentAnnualLivingCosts: 76000,
          heirsCount: 3,
          retainedRight: 'habitation',
        ),
      );
      final missingResult = PropertyTransmissionCalculator.compute(
        const PropertyTransmissionInputs(propertyMarketValue: 900000),
      );

      final exposedStrings = <String>[
        completeResult.articleThesis,
        ...completeResult.scenarioConfidenceRationale.limits,
        ...completeResult.modelScope.unmodelledLegalFactors,
        ...completeResult.retirementAffordability.reasons,
        ...missingResult.retirementAffordability.reasons,
        ...completeResult.familyEqualization.notes,
        ...missingResult.familyEqualization.notes,
        ...completeResult.cantonalTax.notes,
        completeResult.retainedRight.label,
        ...completeResult.retainedRight.notes,
        for (final variant in completeResult.variants) ...[
          variant.label,
          variant.mainTradeoff,
        ],
        ...completeResult.formalities,
      ];

      expect(exposedStrings, isNotEmpty);
      expect(
        exposedStrings,
        everyElement(
          matches(RegExp(r'^successionPropertyTransmission[A-Za-z0-9]+$')),
        ),
      );
      expect(exposedStrings.join(' '), isNot(contains('hérit')));
      expect(exposedStrings.join(' '), isNot(contains('logement')));
      expect(exposedStrings.join(' '), isNot(contains('notaire')));
    });
  });
}

String _formatScenarioChf(num value) {
  final rounded = value.round();
  final sign = rounded < 0 ? '-' : '';
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write("'");
    }
  }
  return '$sign$buffer';
}
