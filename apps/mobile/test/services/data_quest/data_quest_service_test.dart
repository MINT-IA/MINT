import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/data_quest/data_quest_service.dart';

void main() {
  group('DataQuestService', () {
    final now = DateTime.utc(2026, 7, 2);

    test('declares all P0 cases with dossier and proof status ids', () {
      const cases = DataQuestCaseRegistry.p0Cases;

      expect(
          cases.keys,
          containsAll(<String>[
            'first_salary_tax',
            'buy_property',
            'transmit_property',
          ]));
      for (final entry in cases.entries) {
        expect(entry.value.targetRoute, startsWith('/'));
        expect(entry.value.pdfSectionId, isNotEmpty);
        expect(entry.value.maestroFlowId, isNotEmpty);
      }
      expect(cases['first_salary_tax']!.maestroFlowId, 'pending');
      expect(cases['buy_property']!.maestroFlowId, 'pending');
      expect(
        cases['transmit_property']!.maestroFlowId,
        'phase2_data_quest_transmit_property',
      );
    });

    test('asks only missing first-salary variables in priority order', () {
      final plan = DataQuestService.planCase(
        caseId: 'first_salary_tax',
        answers: const {'q_birth_year': 2001},
        now: now,
      );

      expect(plan.targetRoute, '/pilier-3a');
      expect(plan.pdfSectionId, 'dossier_first_salary_tax');
      expect(
        plan.asks.map((ask) => ask.inputKey),
        <String>['incomeGrossYearly', 'canton', 'has2ndPillar'],
      );
      expect(plan.asks.every((ask) => ask.mode == DataQuestAskMode.collect),
          isTrue);
      expect(plan.asks.every((ask) => ask.tone == DataQuestTone.plain), isTrue);
    });

    test('next question changes when a high-priority variable is answered', () {
      final before = DataQuestService.planCase(
        caseId: 'first_salary_tax',
        answers: const {'q_birth_year': 2001},
        now: now,
      );
      final after = DataQuestService.planCase(
        caseId: 'first_salary_tax',
        answers: const {
          'q_birth_year': 2001,
          'q_gross_salary_annual': 78000,
        },
        now: now,
      );

      expect(before.asks.first.inputKey, 'incomeGrossYearly');
      expect(after.asks.first.inputKey, 'canton');
      expect(after.asks.map((ask) => ask.inputKey),
          isNot(contains('incomeGrossYearly')));
    });

    test('stale known data is reconfirmed instead of asked blank', () {
      final staleSalary = BiographyFact(
        id: 'salary-stale',
        factType: FactType.salary,
        fieldPath: 'incomeGrossYearly',
        value: '78000',
        source: FactSource.userInput,
        sourceDate: DateTime.utc(2024, 1, 31),
        createdAt: DateTime.utc(2024, 1, 31),
        updatedAt: DateTime.utc(2024, 1, 31),
      );
      final plan = DataQuestService.planCase(
        caseId: 'first_salary_tax',
        answers: const {
          'q_birth_year': 2001,
          'q_gross_salary_annual': 78000,
          'q_canton': 'VD',
          'q_has_pension_fund': true,
        },
        factsByLedgerKey: {'incomeGrossYearly': staleSalary},
        now: now,
      );

      expect(plan.asks, hasLength(1));
      expect(plan.asks.single.inputKey, 'incomeGrossYearly');
      expect(plan.asks.single.mode, DataQuestAskMode.reconfirm);
      expect(plan.asks.single.priorValue, 78000);
    });

    test('fresh complete first-salary answers produce no asks', () {
      final plan = DataQuestService.planCase(
        caseId: 'first_salary_tax',
        answers: const {
          'q_birth_year': 2001,
          'q_gross_salary_annual': 78000,
          'q_canton': 'VD',
          'q_has_pension_fund': true,
        },
        factsByLedgerKey: {
          'incomeGrossYearly': BiographyFact(
            id: 'salary-fresh',
            factType: FactType.salary,
            fieldPath: 'incomeGrossYearly',
            value: '78000',
            source: FactSource.userInput,
            sourceDate: DateTime.utc(2026, 6, 30),
            createdAt: DateTime.utc(2026, 6, 30),
            updatedAt: DateTime.utc(2026, 6, 30),
          ),
        },
        now: now,
      );

      expect(plan.asks, isEmpty);
      expect(plan.isSatisfied, isTrue);
    });

    test('known legacy answers without provenance are not false reconfirmed',
        () {
      final plan = DataQuestService.planCase(
        caseId: 'first_salary_tax',
        answers: const {
          'q_birth_year': 2001,
          'q_gross_salary_annual': 78000,
          'q_canton': 'VD',
          'q_has_pension_fund': true,
        },
        factsByLedgerKey: const {},
        now: now,
      );

      expect(plan.asks, isEmpty);
      expect(plan.isSatisfied, isTrue);
    });

    test('buy_property asks guard variables in priority order', () {
      final plan = DataQuestService.planCase(
        caseId: 'buy_property',
        answers: const {},
        now: now,
      );

      expect(plan.targetRoute, '/hypotheque');
      expect(plan.pdfSectionId, 'dossier_buy_property');
      expect(
        plan.asks.map((ask) => ask.inputKey),
        <String>[
          'incomeGrossYearly',
          'patrimoine.epargneLiquide',
          'targetPropertyValue',
          'householdType',
        ],
      );
      expect(
          plan.asks.every((ask) => ask.stage == DataQuestStage.guard), isTrue);
      expect(plan.asks.every((ask) => ask.mode == DataQuestAskMode.collect),
          isTrue);
    });

    test('buy_property moves from guard answers to enrichment questions', () {
      final guardPlan = DataQuestService.planCase(
        caseId: 'buy_property',
        answers: const {'q_gross_salary_annual': 145000},
        now: now,
      );
      final requiredPlan = DataQuestService.planCase(
        caseId: 'buy_property',
        answers: const {
          'q_gross_salary_annual': 145000,
          'q_cash_total': 250000,
          'q_target_property_value': 950000,
          'q_civil_status': 'couple',
        },
        now: now,
      );

      expect(guardPlan.asks.first.inputKey, 'patrimoine.epargneLiquide');
      expect(guardPlan.asks.map((ask) => ask.inputKey),
          isNot(contains('incomeGrossYearly')));
      expect(
        requiredPlan.asks.map((ask) => ask.inputKey),
        <String>['canton', 'patrimoine.mortgageRate'],
      );
      expect(
          requiredPlan.asks
              .every((ask) => ask.stage == DataQuestStage.required),
          isTrue);
    });

    test('buy_property does not accept owned property value as target price',
        () {
      final plan = DataQuestService.planCase(
        caseId: 'buy_property',
        answers: const {
          'q_gross_salary_annual': 145000,
          'q_cash_total': 250000,
          'q_property_market_value': 950000,
          'q_civil_status': 'couple',
        },
        now: now,
      );

      expect(plan.asks.first.inputKey, 'targetPropertyValue');
      expect(plan.asks.first.mode, DataQuestAskMode.collect);
      expect(
        plan.asks.map((ask) => ask.inputKey),
        isNot(contains('patrimoine.epargneLiquide')),
      );
    });

    test('buy_property reconfirms stale equity without losing delta order', () {
      final staleEquity = BiographyFact(
        id: 'equity-stale',
        factType: FactType.userDecision,
        fieldPath: 'patrimoine.epargneLiquide',
        value: '250000',
        source: FactSource.userInput,
        sourceDate: DateTime.utc(2024, 2, 1),
        createdAt: DateTime.utc(2024, 2, 1),
        updatedAt: DateTime.utc(2024, 2, 1),
      );
      final plan = DataQuestService.planCase(
        caseId: 'buy_property',
        answers: const {
          'q_gross_salary_annual': 145000,
          'q_cash_total': 250000,
          'q_target_property_value': 950000,
          'q_civil_status': 'couple',
        },
        factsByLedgerKey: {'patrimoine.epargneLiquide': staleEquity},
        now: now,
      );

      expect(plan.asks, hasLength(1));
      expect(plan.asks.single.inputKey, 'patrimoine.epargneLiquide');
      expect(plan.asks.single.mode, DataQuestAskMode.reconfirm);
      expect(plan.asks.single.priorValue, 250000);
    });

    test('transmit_property runs retirement guard before gift questions', () {
      final plan = DataQuestService.planCase(
        caseId: 'transmit_property',
        answers: const {
          'q_property_market_value': 1200000,
          'q_mortgage_balance': 420000,
          'q_children': 2,
        },
        factsByLedgerKey: {
          'patrimoine.propertyMarketValue': _fact(
            id: 'property-fresh',
            fieldPath: 'patrimoine.propertyMarketValue',
            value: '1200000',
          ),
        },
        now: now,
      );

      expect(plan.targetRoute, '/succession');
      expect(plan.asks, isNotEmpty);
      expect(
          plan.asks.every((ask) => ask.stage == DataQuestStage.guard), isTrue);
      expect(
          plan.asks.every((ask) => ask.tone == DataQuestTone.gentle), isTrue);
      expect(
        plan.asks.map((ask) => ask.inputKey),
        <String>[
          'targetRetirementAge',
          'avoirLpp',
          'pillar3aBalance',
          'parentLiquidAssets',
          'parentAnnualRetirementIncome',
          'parentAnnualLivingCosts',
        ],
      );
      expect(plan.asks.map((ask) => ask.inputKey),
          isNot(contains('mortgageBalance')));
    });

    test('transmit_property useful quest exposes transaction assumptions', () {
      final plan = DataQuestService.planCase(
        caseId: 'transmit_property',
        answers: const {
          'q_property_market_value': 1200000,
          'q_target_retirement_age': 64,
          '_coach_avoir_lpp': 650000,
          'q_3a_total': 180000,
          '_transmit_property_parent_annual_retirement_income': 76000,
          'q_housing_cost_period_chf': 6600,
          'q_lamal_premium_monthly_chf': 400,
          'q_cash_total': 120000,
          'q_mortgage_balance': 420000,
          'q_children': 2,
        },
        factsByLedgerKey: {
          'patrimoine.propertyMarketValue': _fact(
            id: 'property-fresh',
            fieldPath: 'patrimoine.propertyMarketValue',
            value: '1200000',
          ),
          'targetRetirementAge': _fact(
            id: 'retirement-age-fresh',
            fieldPath: 'targetRetirementAge',
            value: '64',
          ),
          'avoirLpp': _fact(
            id: 'lpp-fresh',
            fieldPath: 'prevoyance.avoirLppTotal',
            value: '650000',
            type: FactType.lppCapital,
          ),
          'pillar3aBalance': _fact(
            id: '3a-fresh',
            fieldPath: 'prevoyance.totalEpargne3a',
            value: '180000',
            type: FactType.threeACapital,
          ),
          'parentAnnualRetirementIncome': _fact(
            id: 'parent-income-fresh',
            fieldPath: 'parentAnnualRetirementIncome',
            value: '76000',
            type: FactType.salary,
          ),
          'parentAnnualLivingCosts': _fact(
            id: 'parent-living-costs-fresh',
            fieldPath: 'parentAnnualLivingCosts',
            value: '84000',
          ),
          'patrimoine.epargneLiquide': _fact(
            id: 'liquidity-fresh',
            fieldPath: 'patrimoine.epargneLiquide',
            value: '120000',
          ),
          'patrimoine.mortgageBalance': _fact(
            id: 'mortgage-fresh',
            fieldPath: 'patrimoine.mortgageBalance',
            value: '420000',
            type: FactType.mortgageDebt,
          ),
          'nombreEnfants': _fact(
            id: 'children-fresh',
            fieldPath: 'nombreEnfants',
            value: '2',
          ),
        },
        now: now,
        includeUseful: true,
      );

      expect(
        plan.asks.map((ask) => ask.inputKey),
        <String>[
          'cashPaidByRecipient',
          'mortgageAssumedByRecipient',
          'recipientRelationship',
          'retainedRight',
          'avancementHoirie',
          'canton',
        ],
      );
      expect(
        plan.asks.take(5).every(
              (ask) => ask.mode == DataQuestAskMode.scenarioAssumption,
            ),
        isTrue,
      );
      expect(plan.asks.take(5).every((ask) => ask.ledgerKey == null), isTrue);
      expect(plan.asks.last.inputKey, 'canton');
      expect(plan.asks.last.mode, DataQuestAskMode.collect);
      expect(
          plan.asks.every((ask) => ask.stage == DataQuestStage.useful), isTrue);
    });

    test('transmit_property treats legacy property as known until migration',
        () {
      final before = DataQuestService.planCase(
        caseId: 'transmit_property',
        answers: const {},
        now: now,
      );
      final after = DataQuestService.planCase(
        caseId: 'transmit_property',
        answers: const {'q_property_market_value': 1200000},
        now: now,
      );

      expect(before.asks.first.inputKey, 'propertyMarketValue');
      expect(after.asks.first.inputKey, 'targetRetirementAge');
      expect(after.asks.map((ask) => ask.inputKey),
          isNot(contains('propertyMarketValue')));
    });

    test('transmit_property reuses fresh property fact without duplicate ask',
        () {
      final plan = DataQuestService.planCase(
        caseId: 'transmit_property',
        answers: const {'q_property_market_value': 1200000},
        factsByLedgerKey: {
          'patrimoine.propertyMarketValue': BiographyFact(
            id: 'property-fresh',
            factType: FactType.userDecision,
            fieldPath: 'patrimoine.propertyMarketValue',
            value: '1200000',
            source: FactSource.userInput,
            sourceDate: DateTime.utc(2026, 7, 2),
            createdAt: DateTime.utc(2026, 7, 2),
            updatedAt: DateTime.utc(2026, 7, 2),
          ),
        },
        now: now,
      );

      expect(plan.asks.first.inputKey, 'targetRetirementAge');
      expect(
        plan.asks.map((ask) => ask.inputKey),
        isNot(contains('propertyMarketValue')),
      );
    });

    test('transmit_property asks annual living costs before mortgage details',
        () {
      final plan = DataQuestService.planCase(
        caseId: 'transmit_property',
        answers: const {
          'q_property_market_value': 1200000,
          'q_target_retirement_age': 64,
          '_coach_avoir_lpp': 650000,
          'q_3a_total': 180000,
          'q_cash_total': 120000,
          '_transmit_property_parent_annual_retirement_income': 76000,
        },
        factsByLedgerKey: {
          'patrimoine.propertyMarketValue': _fact(
            id: 'property-fresh',
            fieldPath: 'patrimoine.propertyMarketValue',
            value: '1200000',
          ),
          'targetRetirementAge': _fact(
            id: 'retirement-age-fresh',
            fieldPath: 'targetRetirementAge',
            value: '64',
          ),
          'avoirLpp': _fact(
            id: 'lpp-fresh',
            fieldPath: 'prevoyance.avoirLppTotal',
            value: '650000',
            type: FactType.lppCapital,
          ),
          'pillar3aBalance': _fact(
            id: '3a-fresh',
            fieldPath: 'prevoyance.totalEpargne3a',
            value: '180000',
            type: FactType.threeACapital,
          ),
          'patrimoine.epargneLiquide': _fact(
            id: 'liquidity-fresh',
            fieldPath: 'patrimoine.epargneLiquide',
            value: '120000',
          ),
          'parentAnnualRetirementIncome': _fact(
            id: 'parent-income-fresh',
            fieldPath: 'parentAnnualRetirementIncome',
            value: '76000',
            type: FactType.salary,
          ),
        },
        now: now,
      );

      expect(plan.asks.map((ask) => ask.inputKey),
          <String>['parentAnnualLivingCosts']);
      expect(plan.asks.single.mode, DataQuestAskMode.collect);
      expect(plan.asks.single.stage, DataQuestStage.guard);
      expect(
        plan.asks.map((ask) => ask.inputKey),
        isNot(contains('mortgageBalance')),
      );
    });

    test(
        'transmit_property keeps partial living-cost period answer on the living-cost ask',
        () {
      final plan = DataQuestService.planCase(
        caseId: 'transmit_property',
        answers: const {
          'q_property_market_value': 1200000,
          'q_target_retirement_age': 64,
          '_coach_avoir_lpp': 650000,
          'q_3a_total': 180000,
          'q_cash_total': 120000,
          '_transmit_property_parent_annual_retirement_income': 76000,
          'q_housing_cost_period_chf': 6600,
        },
        factsByLedgerKey: {
          'patrimoine.propertyMarketValue': _fact(
            id: 'property-fresh',
            fieldPath: 'patrimoine.propertyMarketValue',
            value: '1200000',
          ),
          'targetRetirementAge': _fact(
            id: 'retirement-age-fresh',
            fieldPath: 'targetRetirementAge',
            value: '64',
          ),
          'avoirLpp': _fact(
            id: 'lpp-fresh',
            fieldPath: 'prevoyance.avoirLppTotal',
            value: '650000',
            type: FactType.lppCapital,
          ),
          'pillar3aBalance': _fact(
            id: '3a-fresh',
            fieldPath: 'prevoyance.totalEpargne3a',
            value: '180000',
            type: FactType.threeACapital,
          ),
          'patrimoine.epargneLiquide': _fact(
            id: 'liquidity-fresh',
            fieldPath: 'patrimoine.epargneLiquide',
            value: '120000',
          ),
          'parentAnnualRetirementIncome': _fact(
            id: 'parent-income-fresh',
            fieldPath: 'parentAnnualRetirementIncome',
            value: '76000',
            type: FactType.salary,
          ),
        },
        now: now,
      );

      expect(plan.asks.first.questionId, 'ask_parent_annual_living_costs');
      expect(plan.asks.first.inputKey, 'parentAnnualLivingCosts');
      expect(plan.asks.first.mode, DataQuestAskMode.reconfirm);
      expect(
        plan.asks.map((ask) => ask.inputKey),
        isNot(contains('mortgageBalance')),
      );
    });

    test('transmit_property treats zero annual living costs as missing guard',
        () {
      final plan = DataQuestService.planCase(
        caseId: 'transmit_property',
        answers: const {
          'q_property_market_value': 1200000,
          'q_target_retirement_age': 64,
          '_coach_avoir_lpp': 650000,
          'q_3a_total': 180000,
          'q_cash_total': 120000,
          '_transmit_property_parent_annual_retirement_income': 76000,
          'q_parent_annual_living_costs': 0,
        },
        factsByLedgerKey: {
          'patrimoine.propertyMarketValue': _fact(
            id: 'property-fresh',
            fieldPath: 'patrimoine.propertyMarketValue',
            value: '1200000',
          ),
          'targetRetirementAge': _fact(
            id: 'retirement-age-fresh',
            fieldPath: 'targetRetirementAge',
            value: '64',
          ),
          'avoirLpp': _fact(
            id: 'lpp-fresh',
            fieldPath: 'prevoyance.avoirLppTotal',
            value: '650000',
            type: FactType.lppCapital,
          ),
          'pillar3aBalance': _fact(
            id: '3a-fresh',
            fieldPath: 'prevoyance.totalEpargne3a',
            value: '180000',
            type: FactType.threeACapital,
          ),
          'patrimoine.epargneLiquide': _fact(
            id: 'liquidity-fresh',
            fieldPath: 'patrimoine.epargneLiquide',
            value: '120000',
          ),
          'parentAnnualRetirementIncome': _fact(
            id: 'parent-income-fresh',
            fieldPath: 'parentAnnualRetirementIncome',
            value: '76000',
            type: FactType.salary,
          ),
        },
        now: now,
      );

      expect(plan.asks.map((ask) => ask.inputKey),
          <String>['parentAnnualLivingCosts']);
      expect(plan.asks.single.mode, DataQuestAskMode.collect);
      expect(plan.asks.single.stage, DataQuestStage.guard);
    });

    test(
        'transmit_property accepts composed retirement income evidence before asking aggregate',
        () {
      final plan = DataQuestService.planCase(
        caseId: 'transmit_property',
        answers: const {
          'q_property_market_value': 1200000,
          'q_target_retirement_age': 64,
          '_coach_avoir_lpp': 650000,
          'q_3a_total': 180000,
          'q_cash_total': 120000,
          '_coach_avs_rente_estimee': 6333.333333333333,
        },
        factsByLedgerKey: {
          'patrimoine.propertyMarketValue': _fact(
            id: 'property-fresh',
            fieldPath: 'patrimoine.propertyMarketValue',
            value: '1200000',
          ),
          'targetRetirementAge': _fact(
            id: 'retirement-age-fresh',
            fieldPath: 'targetRetirementAge',
            value: '64',
          ),
          'avoirLpp': _fact(
            id: 'lpp-fresh',
            fieldPath: 'prevoyance.avoirLppTotal',
            value: '650000',
            type: FactType.lppCapital,
          ),
          'pillar3aBalance': _fact(
            id: '3a-fresh',
            fieldPath: 'prevoyance.totalEpargne3a',
            value: '180000',
            type: FactType.threeACapital,
          ),
          'patrimoine.epargneLiquide': _fact(
            id: 'liquidity-fresh',
            fieldPath: 'patrimoine.epargneLiquide',
            value: '120000',
          ),
          'parentAnnualRetirementIncome': BiographyFact(
            id: 'parent-retirement-income',
            factType: FactType.salary,
            fieldPath: 'parentAnnualRetirementIncome',
            value: '76000',
            source: FactSource.coach,
            sourceDate: DateTime.utc(2026, 5),
            createdAt: DateTime.utc(2026, 5),
            updatedAt: DateTime.utc(2026, 5),
          ),
          'parentAnnualLivingCosts': _fact(
            id: 'parent-living-costs-fresh',
            fieldPath: 'parentAnnualLivingCosts',
            value: '84000',
          ),
        },
        now: now,
      );

      expect(
        plan.asks.map((ask) => ask.inputKey),
        isNot(contains('parentAnnualRetirementIncome')),
      );
      expect(plan.asks.first.inputKey, 'mortgageBalance');
    });

    test(
        'transmit_property does not treat AVS alone as annual income aggregate',
        () {
      final plan = DataQuestService.planCase(
        caseId: 'transmit_property',
        answers: const {
          'q_property_market_value': 1200000,
          'q_target_retirement_age': 64,
          '_coach_avoir_lpp': 650000,
          'q_3a_total': 180000,
          'q_cash_total': 120000,
          '_coach_avs_rente_estimee': 6333.333333333333,
        },
        now: now,
      );

      expect(
        plan.asks.map((ask) => ask.inputKey),
        contains('parentAnnualRetirementIncome'),
      );
      expect(
        plan.asks
            .singleWhere(
              (ask) => ask.inputKey == 'parentAnnualRetirementIncome',
            )
            .mode,
        DataQuestAskMode.collect,
      );
    });
  });
}

BiographyFact _fact({
  required String id,
  required String fieldPath,
  required String value,
  FactType type = FactType.userDecision,
}) {
  return BiographyFact(
    id: id,
    factType: type,
    fieldPath: fieldPath,
    value: value,
    source: FactSource.userInput,
    sourceDate: DateTime.utc(2026, 7, 2),
    createdAt: DateTime.utc(2026, 7, 2),
    updatedAt: DateTime.utc(2026, 7, 2),
  );
}
