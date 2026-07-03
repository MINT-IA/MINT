import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/dossier/dossier_payload_service.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DossierPayloadService', () {
    final generatedAt = DateTime.utc(2026, 7, 2, 10, 30);
    const ownerId = 'local_demo_fixture_owner';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      RegulatorySyncService.clearCache();
    });

    test('builds first_salary_tax payload matching its JSON schema', () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'first_salary_tax',
        answers: const {
          '_coach_profile_owner_id': ownerId,
          'q_birth_year': 2001,
          'q_canton': 'VD',
          'q_gross_salary_annual': 78000,
          'q_has_pension_fund': true,
          'q_3a_annual_contribution': 3000,
        },
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('first_salary_tax', payload), isEmpty);
      expect(payload['pdf_section_id'], 'dossier_first_salary_tax');
      expect((payload['inputs'] as Map)['incomeGrossYearly']['value'], 78000);
      expect(
        (payload['outputs'] as Map)['pillar3a_ceiling_context']
            ['annual_ceiling'],
        7258,
      );
      expect(payload['next_questions'], isEmpty);
      expect(payload['profile_owner_id'], startsWith('local_demo_'));
      expect(payload['profile_owner_id'], isNot('local_demo_pending'));
      expect(payload['scenario_id'], 'first_salary_tax_1782988200000');
    });

    test('uses explicit profile owner id when present', () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'first_salary_tax',
        answers: const {
          '_coach_profile_owner_id': 'local_demo_fixture_owner',
          'q_birth_year': 2001,
          'q_canton': 'VD',
          'q_gross_salary_annual': 78000,
          'q_has_pension_fund': true,
        },
        generatedAt: generatedAt,
      ).toJson();

      expect(payload['profile_owner_id'], 'local_demo_fixture_owner');
    });

    test('requires resolved local owner id before sync dossier build', () {
      expect(
        () => DossierPayloadService.buildP0Case(
          caseId: 'first_salary_tax',
          answers: const {
            'q_birth_year': 2001,
            'q_canton': 'VD',
            'q_gross_salary_annual': 78000,
            'q_has_pension_fund': true,
          },
          generatedAt: generatedAt,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects pending local owner id before sync dossier build', () {
      expect(
        () => DossierPayloadService.buildP0Case(
          caseId: 'first_salary_tax',
          answers: const {
            '_coach_profile_owner_id': 'local_demo_pending',
            'q_birth_year': 2001,
            'q_canton': 'VD',
            'q_gross_salary_annual': 78000,
            'q_has_pension_fund': true,
          },
          generatedAt: generatedAt,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('keeps 3a ceiling unresolved without explicit LPP status', () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'first_salary_tax',
        answers: const {
          '_coach_profile_owner_id': ownerId,
          'q_birth_year': 2001,
          'q_canton': 'VD',
          'q_gross_salary_annual': 78000,
        },
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('first_salary_tax', payload), isEmpty);
      expect(payload['next_questions'], contains('ask_has_second_pillar'));
      final inputs = payload['inputs'] as Map;
      expect(inputs['has2ndPillar']['value'], isNull);
      expect(inputs['has2ndPillar']['source'], 'missing');
      final ceilingContext =
          (payload['outputs'] as Map)['pillar3a_ceiling_context'];
      expect(ceilingContext['status'], 'missing_required_input');
      expect(ceilingContext['missing_inputs'], contains('has2ndPillar'));
      expect(ceilingContext['annual_ceiling'], isNull);
      expect(ceilingContext['remaining_room'], isNull);
    });

    test('builds buy_property payload with affordability and equity context',
        () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'buy_property',
        answers: const {
          '_coach_profile_owner_id': ownerId,
          'q_canton': 'VD',
          'q_civil_status': 'married',
          'q_gross_salary_annual': 145000,
          'q_cash_total': 250000,
          'q_3a_total': 50000,
          'q_target_property_value': 950000,
          'q_mortgage_rate': 0.018,
        },
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('buy_property', payload), isEmpty);
      final outputs = payload['outputs'] as Map;
      expect(outputs['affordability_context']['charges_ratio'], isA<double>());
      expect(outputs['affordability_context']['status'], isNotEmpty);
      expect(outputs['equity_context']['fonds_propres_total'], greaterThan(0));
      final inputs = payload['inputs'] as Map;
      expect(inputs['targetPropertyValue']['value'], 950000);
      expect(inputs.containsKey('patrimoine.propertyMarketValue'), isFalse);
      expect((payload['assumptions'] as List).single['input_key'],
          'stressInterestRate');
      expect(payload['next_questions'], isEmpty);
    });

    test('uses synced mortgage stress rate in buy_property assumptions', () {
      RegulatorySyncService.setMockCache({
        'mortgage.theoretical_rate': 0.0475,
      });

      final payload = DossierPayloadService.buildP0Case(
        caseId: 'buy_property',
        answers: const {
          '_coach_profile_owner_id': ownerId,
          'q_canton': 'VD',
          'q_civil_status': 'married',
          'q_gross_salary_annual': 145000,
          'q_cash_total': 250000,
          'q_3a_total': 50000,
          'q_target_property_value': 950000,
        },
        generatedAt: generatedAt,
      ).toJson();

      final stressAssumption = (payload['assumptions'] as List)
          .cast<Map>()
          .singleWhere((a) => a['input_key'] == 'stressInterestRate');
      expect(stressAssumption['value'], 0.0475);
      expect(
        DossierPayloadService.mortgageStressInterestRate,
        reg('mortgage.theoretical_rate', hypothequeTauxTheorique),
      );
    });

    test('keeps buy_property affordability unresolved without property value',
        () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'buy_property',
        answers: const {
          '_coach_profile_owner_id': ownerId,
          'q_canton': 'VD',
          'q_civil_status': 'married',
          'q_gross_salary_annual': 145000,
          'q_cash_total': 250000,
          'q_3a_total': 50000,
        },
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('buy_property', payload), isEmpty);
      expect(payload['next_questions'], contains('ask_target_property_value'));
      final outputs = payload['outputs'] as Map;
      expect(
        outputs['affordability_context']['status'],
        'missing_required_input',
      );
      expect(
        outputs['affordability_context']['missing_inputs'],
        contains('targetPropertyValue'),
      );
      expect(outputs['affordability_context']['prix_max_accessible'], isNull);
      expect(outputs['equity_context']['fonds_propres_total'], isNull);
    });

    test('keeps buy_property unresolved when only owned property value exists',
        () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'buy_property',
        answers: const {
          '_coach_profile_owner_id': ownerId,
          'q_canton': 'VD',
          'q_civil_status': 'married',
          'q_gross_salary_annual': 145000,
          'q_cash_total': 250000,
          'q_property_market_value': 950000,
        },
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('buy_property', payload), isEmpty);
      expect(payload['next_questions'], contains('ask_target_property_value'));
      final inputs = payload['inputs'] as Map;
      expect(inputs['targetPropertyValue']['value'], isNull);
      expect(inputs['targetPropertyValue']['source'], 'missing');
      final outputs = payload['outputs'] as Map;
      expect(
        outputs['affordability_context']['missing_inputs'],
        contains('targetPropertyValue'),
      );
      expect(outputs['affordability_context']['prix_max_accessible'], isNull);
    });

    test('builds transmit_property dossier from Raiffeisen-style inputs', () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'transmit_property',
        answers: {
          '_coach_profile_owner_id': ownerId,
          'q_canton': 'VD',
          'q_target_retirement_age': 64,
          '_coach_avoir_lpp': 650000,
          'q_3a_total': 180000,
          'q_cash_total': 120000,
          'q_property_market_value': 1200000,
          'q_mortgage_balance': 420000,
          'q_children': 2,
          '_transmit_property_parent_annual_retirement_income': 76000,
          'q_pay_frequency': 'monthly',
          'q_housing_cost_period_chf': 6600,
          'q_lamal_premium_monthly_chf': 400,
          '_transmit_property_cash_paid_by_recipient': 50000,
          '_transmit_property_mortgage_assumed_by_recipient': 420000,
          '_transmit_property_recipient_relationship': 'descendant',
          '_transmit_property_retained_right': 'habitation',
          '_transmit_property_avancement_hoirie': true,
          '_coach_data_sources': {
            'patrimoine.propertyMarketValue': 'estimated',
            'patrimoine.mortgageBalance': 'userInput',
            'patrimoine.epargneLiquide': 'userInput',
            'parentAnnualRetirementIncome': 'userInput',
          },
          '_coach_data_source_dates': {
            'patrimoine.mortgageBalance': '2026-05-31T00:00:00.000Z',
          },
        },
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('transmit_property', payload), isEmpty);
      final outputs = payload['outputs'] as Map;
      expect(
        outputs['retirement_affordability']['status'],
        'needs_review',
      );
      expect(outputs['retirement_affordability']['annual_margin'], -8000);
      expect(outputs['family_equalization']['status'], 'at_risk');
      expect(outputs['family_equalization']['gap'], 195000);
      expect(outputs['cantonal_review']['requires_cantonal_review'], isTrue);
      expect(
        outputs['scenario_confidence']['rationale'],
        contains('educational_triage'),
      );
      expect(
        (payload['inputs'] as Map)['patrimoine.propertyMarketValue']
            ['confidence'],
        'low',
      );
      expect(
        (payload['inputs'] as Map)['parentAnnualRetirementIncome']['source'],
        'userInput',
      );
      expect(
        ((payload['inputs'] as Map)['parentAnnualRetirementIncome'] as Map)
            .containsKey('derived_from'),
        isFalse,
      );
      expect(
        (payload['inputs'] as Map)['parentAnnualLivingCosts']['confidence'],
        'low',
      );
      expect(
        (payload['outputs'] as Map)['living_costs_context']['status'],
        'partial_composition',
      );
      expect(
        (payload['assumptions'] as List).map((a) => a['input_key']),
        containsAll([
          'cashPaidByRecipient',
          'mortgageAssumedByRecipient',
          'recipientRelationship',
          'retainedRight',
          'avancementHoirie',
        ]),
      );
      expect(payload['profile_owner_id'], startsWith('local_demo_'));
      expect(payload['profile_owner_id'], isNot('local_demo_pending'));
      expect(payload['scenario_id'], 'transmit_property_1782988200000');
    });

    test('uses guard-collected parent annual retirement income directly', () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'transmit_property',
        answers: _withFreshMetadata(
          const {
            '_coach_profile_owner_id': ownerId,
            'q_canton': 'VD',
            'q_target_retirement_age': 64,
            '_coach_avoir_lpp': 650000,
            'q_3a_total': 180000,
            '_transmit_property_parent_annual_retirement_income': 76000,
            'q_cash_total': 120000,
            'q_property_market_value': 1200000,
            'q_mortgage_balance': 420000,
            'q_children': 2,
            'q_pay_frequency': 'monthly',
            'q_housing_cost_period_chf': 6600,
            'q_lamal_premium_monthly_chf': 400,
          },
          _freshTransmitPropertyFieldPaths,
        ),
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('transmit_property', payload), isEmpty);
      final incomeInput =
          (payload['inputs'] as Map)['parentAnnualRetirementIncome'] as Map;
      expect(incomeInput['value'], 76000);
      expect(incomeInput['source'], 'userInput');
      expect(incomeInput.containsKey('derived_from'), isFalse);
      final missingInputs =
          (payload['outputs'] as Map)['scenario_confidence']['missing_inputs'];
      expect(missingInputs, isNot(contains('parentAnnualRetirementIncome')));
      expect(
        payload['next_questions'],
        isNot(contains('ask_parent_annual_retirement_income')),
      );
    });

    test('does not double-count other fixed costs when catchall is present',
        () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'transmit_property',
        answers: _withFreshMetadata(
          const {
            '_coach_profile_owner_id': ownerId,
            'q_canton': 'VD',
            'q_target_retirement_age': 64,
            '_coach_avoir_lpp': 650000,
            'q_3a_total': 180000,
            '_transmit_property_parent_annual_retirement_income': 76000,
            'q_cash_total': 120000,
            'q_property_market_value': 1200000,
            'q_mortgage_balance': 420000,
            'q_children': 2,
            'q_pay_frequency': 'monthly',
            'q_housing_cost_period_chf': 2000,
            'q_lamal_premium_monthly_chf': 500,
            '_coach_depenses_autres': 1000,
            'q_tax_provision_monthly_chf': 300,
            'q_other_fixed_costs_monthly_chf': 200,
            'q_debt_payments_period_chf': 400,
          },
          [
            ..._freshTransmitPropertyFieldPaths,
            'depenses.autresDepensesFixes',
          ],
        ),
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('transmit_property', payload), isEmpty);
      final livingCosts =
          (payload['inputs'] as Map)['parentAnnualLivingCosts'] as Map;
      expect(livingCosts['value'], 42000);
      expect(
        livingCosts['derived_from'],
        containsAll([
          'depenses.loyer',
          'depenses.assuranceMaladie',
          'depenses.autresDepensesFixes',
        ]),
      );
    });

    test('keeps period housing cost untrusted when pay frequency is absent',
        () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'transmit_property',
        answers: _withFreshMetadata(
          const {
            '_coach_profile_owner_id': ownerId,
            'q_canton': 'VD',
            'q_target_retirement_age': 64,
            '_coach_avoir_lpp': 650000,
            'q_3a_total': 180000,
            '_transmit_property_parent_annual_retirement_income': 76000,
            'q_cash_total': 120000,
            'q_property_market_value': 1200000,
            'q_mortgage_balance': 420000,
            'q_children': 2,
            'q_housing_cost_period_chf': 24000,
          },
          _freshTransmitPropertyFieldPaths.where(
            (fieldPath) =>
                fieldPath != 'parentAnnualLivingCosts' &&
                fieldPath != 'depenses.loyer' &&
                fieldPath != 'depenses.assuranceMaladie',
          ),
        ),
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('transmit_property', payload), isEmpty);
      final livingCosts =
          (payload['inputs'] as Map)['parentAnnualLivingCosts'] as Map;
      expect(livingCosts['value'], isNull);
      expect(payload['next_questions'],
          contains('ask_parent_annual_living_costs'));
    });

    test(
        'asks annual living costs before mortgage when budget evidence is absent',
        () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'transmit_property',
        answers: _withFreshMetadata(
          const {
            '_coach_profile_owner_id': ownerId,
            'q_canton': 'VD',
            'q_target_retirement_age': 64,
            '_coach_avoir_lpp': 650000,
            'q_3a_total': 180000,
            '_transmit_property_parent_annual_retirement_income': 76000,
            'q_cash_total': 120000,
            'q_property_market_value': 1200000,
          },
          _freshTransmitPropertyFieldPaths.where(
            (fieldPath) =>
                fieldPath != 'parentAnnualLivingCosts' &&
                fieldPath != 'depenses.loyer' &&
                fieldPath != 'depenses.assuranceMaladie',
          ),
        ),
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('transmit_property', payload), isEmpty);
      expect(
        payload['next_questions'],
        contains('ask_parent_annual_living_costs'),
      );
      expect(
        payload['next_questions'],
        isNot(contains('ask_mortgage_balance')),
      );
      expect(
        (payload['outputs'] as Map)['scenario_confidence']['missing_inputs'],
        contains('parentAnnualLivingCosts'),
      );
    });

    test('composes parent annual retirement income from AVS and LPP facts', () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'transmit_property',
        answers: _withFreshMetadata(
          const {
            '_coach_profile_owner_id': ownerId,
            'q_canton': 'VD',
            'q_target_retirement_age': 64,
            '_coach_avoir_lpp': 650000,
            'q_3a_total': 180000,
            '_coach_avs_rente_estimee': 4000,
            '_coach_projected_rente_lpp': 28000,
            'q_cash_total': 120000,
            'q_property_market_value': 1200000,
            'q_mortgage_balance': 420000,
            'q_children': 2,
            'q_pay_frequency': 'monthly',
            'q_housing_cost_period_chf': 6600,
            'q_lamal_premium_monthly_chf': 400,
            '_coach_data_sources': {
              'prevoyance.renteAVSEstimeeMensuelle': 'certificate',
              'prevoyance.projectedRenteLpp': 'certificate',
            },
            '_coach_data_timestamps': {
              'prevoyance.renteAVSEstimeeMensuelle': '2026-05-31T00:00:00.000Z',
              'prevoyance.projectedRenteLpp': '2026-05-31T00:00:00.000Z',
            },
          },
          _freshTransmitPropertyFieldPaths.where(
            (fieldPath) => fieldPath != 'parentAnnualRetirementIncome',
          ),
        ),
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('transmit_property', payload), isEmpty);
      final incomeInput =
          (payload['inputs'] as Map)['parentAnnualRetirementIncome'] as Map;
      expect(incomeInput['value'], 76000);
      expect(incomeInput['source'], 'estimated');
      expect(incomeInput['derived_from'], [
        'prevoyance.renteAVSEstimeeMensuelle',
        'prevoyance.projectedRenteLpp',
      ]);
      expect(
        payload['next_questions'],
        isNot(contains('ask_parent_annual_retirement_income')),
      );
    });

    test('transmit_property dossier surfaces stale profile next questions', () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'transmit_property',
        answers: _withFreshMetadata(
          const {
            '_coach_profile_owner_id': ownerId,
            'q_canton': 'VD',
            'q_target_retirement_age': 64,
            '_coach_avoir_lpp': 650000,
            'q_3a_total': 180000,
            'q_cash_total': 120000,
            'q_property_market_value': 1200000,
            'q_mortgage_balance': 420000,
            'q_children': 2,
            '_transmit_property_parent_annual_retirement_income': 76000,
            'q_pay_frequency': 'monthly',
            'q_housing_cost_period_chf': 6600,
            'q_lamal_premium_monthly_chf': 400,
            '_transmit_property_cash_paid_by_recipient': 50000,
            '_transmit_property_mortgage_assumed_by_recipient': 420000,
            '_transmit_property_recipient_relationship': 'descendant',
            '_transmit_property_retained_right': 'habitation',
            '_transmit_property_avancement_hoirie': true,
            '_coach_data_sources': {
              'patrimoine.propertyMarketValue': 'userInput',
            },
            '_coach_data_timestamps': {
              'patrimoine.propertyMarketValue': '2024-01-01T00:00:00.000Z',
            },
            '_coach_data_source_dates': {
              'patrimoine.propertyMarketValue': '2024-01-01T00:00:00.000Z',
            },
          },
          _freshTransmitPropertyFieldPaths.where(
            (fieldPath) => fieldPath != 'patrimoine.propertyMarketValue',
          ),
        ),
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('transmit_property', payload), isEmpty);
      expect(payload['next_questions'], contains('ask_property_market_value'));
    });

    test(
        'does not mask missing parent liquidity or costs with profile defaults',
        () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'transmit_property',
        answers: _withFreshMetadata(
          const {
            '_coach_profile_owner_id': ownerId,
            'q_canton': 'VD',
            'q_target_retirement_age': 64,
            '_coach_avoir_lpp': 650000,
            'q_3a_total': 180000,
            '_transmit_property_parent_annual_retirement_income': 76000,
            'q_property_market_value': 1200000,
            'q_mortgage_balance': 420000,
            'q_children': 2,
          },
          _freshTransmitPropertyFieldPaths.where(
            (fieldPath) =>
                fieldPath != 'patrimoine.epargneLiquide' &&
                fieldPath != 'parentAnnualLivingCosts' &&
                fieldPath != 'depenses.loyer' &&
                fieldPath != 'depenses.assuranceMaladie',
          ),
        ),
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('transmit_property', payload), isEmpty);
      final inputs = payload['inputs'] as Map;
      expect(inputs['patrimoine.epargneLiquide']['value'], isNull);
      expect(inputs['patrimoine.epargneLiquide']['source'], 'missing');
      expect(inputs['parentAnnualLivingCosts']['value'], isNull);
      expect(inputs['parentAnnualLivingCosts']['source'], 'missing');
      final confidence =
          (payload['outputs'] as Map)['scenario_confidence'] as Map;
      expect(confidence['value'], 'none');
      expect(
        confidence['missing_inputs'],
        containsAll(['parentLiquidAssets', 'parentAnnualLivingCosts']),
      );
      expect(payload['next_questions'], contains('ask_parent_liquid_assets'));
      expect(
        payload['next_questions'],
        contains('ask_parent_annual_living_costs'),
      );
    });

    test('keeps explicit zero parent liquid assets as known data', () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'transmit_property',
        answers: _withFreshMetadata(
          const {
            '_coach_profile_owner_id': ownerId,
            'q_canton': 'VD',
            'q_target_retirement_age': 64,
            '_coach_avoir_lpp': 650000,
            'q_3a_total': 180000,
            'q_cash_total': 0,
            'q_property_market_value': 1200000,
            'q_mortgage_balance': 420000,
            'q_children': 2,
            '_transmit_property_parent_annual_retirement_income': 76000,
          },
          _freshTransmitPropertyFieldPaths.where(
            (fieldPath) =>
                fieldPath != 'parentAnnualLivingCosts' &&
                fieldPath != 'depenses.loyer' &&
                fieldPath != 'depenses.assuranceMaladie',
          ),
        ),
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('transmit_property', payload), isEmpty);
      final inputs = payload['inputs'] as Map;
      expect(inputs['patrimoine.epargneLiquide']['value'], 0);
      expect(inputs['patrimoine.epargneLiquide']['source'], 'userInput');
      final missingInputs =
          (payload['outputs'] as Map)['scenario_confidence']['missing_inputs'];
      expect(missingInputs, isNot(contains('parentLiquidAssets')));
      expect(missingInputs, contains('parentAnnualLivingCosts'));
    });

    test('incomplete transmit_property payload surfaces next questions', () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'transmit_property',
        answers: _withFreshMetadata(
          const {
            '_coach_profile_owner_id': ownerId,
            'q_property_market_value': 1200000,
          },
          const ['patrimoine.propertyMarketValue'],
        ),
        generatedAt: generatedAt,
      ).toJson();

      expect(_schemaErrors('transmit_property', payload), isEmpty);
      expect(
        payload['next_questions'],
        containsAll([
          'ask_target_retirement_age',
          'ask_lpp_assets',
          'ask_pillar3a_balance',
          'ask_parent_liquid_assets',
          'ask_parent_annual_retirement_income',
        ]),
      );
      expect(
        (payload['outputs'] as Map)['scenario_confidence']['value'],
        'none',
      );
    });

    test('schema validator rejects input metadata drift', () {
      final payload = DossierPayloadService.buildP0Case(
        caseId: 'first_salary_tax',
        answers: const {
          '_coach_profile_owner_id': ownerId,
          'q_birth_year': 2001,
          'q_canton': 'VD',
          'q_gross_salary_annual': 78000,
          'q_has_pension_fund': true,
        },
        generatedAt: generatedAt,
      ).toJson();
      ((payload['inputs'] as Map)['birthYear'] as Map).remove('source');

      expect(
        _schemaErrors('first_salary_tax', payload),
        contains('input birthYear missing metadata source'),
      );
    });
  });
}

List<String> _schemaErrors(String caseId, Map<String, dynamic> payload) {
  final schema = jsonDecode(
    File('../../docs/codex/dossier_stubs/dossier_$caseId.schema.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  return DossierPayloadSchemaValidator.validateJsonAgainstSchema(
    payload: payload,
    schema: schema,
  );
}

const _freshTransmitPropertyFieldPaths = [
  'canton',
  'targetRetirementAge',
  'prevoyance.avoirLppTotal',
  'prevoyance.totalEpargne3a',
  'parentAnnualRetirementIncome',
  'patrimoine.epargneLiquide',
  'patrimoine.propertyMarketValue',
  'patrimoine.mortgageBalance',
  'nombreEnfants',
  'depenses.loyer',
  'depenses.assuranceMaladie',
];

Map<String, dynamic> _withFreshMetadata(
  Map<String, dynamic> answers,
  Iterable<String> fieldPaths,
) {
  const freshAt = '2026-05-31T00:00:00.000Z';
  final existingSources = Map<String, dynamic>.from(
    (answers['_coach_data_sources'] as Map?) ?? const {},
  );
  final existingTimestamps = Map<String, dynamic>.from(
    (answers['_coach_data_timestamps'] as Map?) ?? const {},
  );
  final existingSourceDates = Map<String, dynamic>.from(
    (answers['_coach_data_source_dates'] as Map?) ?? const {},
  );
  for (final fieldPath in fieldPaths) {
    existingSources.putIfAbsent(fieldPath, () => 'userInput');
    existingTimestamps.putIfAbsent(fieldPath, () => freshAt);
    existingSourceDates.putIfAbsent(fieldPath, () => freshAt);
  }
  return {
    ...answers,
    '_coach_data_sources': existingSources,
    '_coach_data_timestamps': existingTimestamps,
    '_coach_data_source_dates': existingSourceDates,
  };
}
