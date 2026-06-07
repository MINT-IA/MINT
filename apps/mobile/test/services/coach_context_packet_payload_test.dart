import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/data_spine/coach_context_packet_adapter.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStorage = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            if (value != null) secureStorage[key] = value;
            return null;
          case 'read':
            final key = call.arguments['key'] as String;
            return secureStorage[key];
          case 'delete':
            final key = call.arguments['key'] as String;
            secureStorage.remove(key);
            return null;
          case 'deleteAll':
            secureStorage.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  group('CoachContextPacket payload wiring', () {
    test('orchestrator profile context carries the safe packet', () {
      final packet = <String, dynamic>{
        'computed_at': '2026-05-23T12:00:00.000Z',
        'facts': [
          {
            'id': 'budget.monthly_free',
            'domain': 'budget',
            'field_path': 'budget.present.monthlyFree',
            'value': 1800.0,
            'source': 'calculated',
            'confidence': 0.91,
          },
        ],
        'missing_fields': [
          {
            'field_path': 'pillars.lpp.totalBalance',
            'domain': 'pillar_lpp',
            'reason': 'missing',
          },
        ],
        'trajectory': {
          'status': 'drifting',
          'current_monthly_capacity': 1200.0,
          'monthly_required': 1800.0,
          'monthly_gap': 600.0,
          'next_lever_id': 'increase_monthly_capacity',
        },
        'next_questions': [
          {
            'id': 'increase_monthly_capacity',
            'domain': 'budget',
            'field_path': 'budget.present.monthlyCapacity',
          },
        ],
        'readiness': {
          'overall_status': 'partial',
          'sections': [
            {
              'id': 'budget',
              'status': 'ready',
              'known_count': 4,
              'missing_count': 0,
            },
          ],
          'missing_domains': ['pillar_lpp'],
          'next_action_id': 'complete_pillar_lpp',
        },
      };

      final ctx = CoachContext(
        firstName: 'Julien',
        age: 36,
        canton: 'VD',
        archetype: 'swiss_native',
        activeGoal: 'Optimiser 3a 2026',
        capHeadline: 'Compléter le 3a',
        capWhyNow: 'Fenêtre fiscale annuelle',
        capCta: 'Planifier un versement',
        capExpectedImpact: 1200,
        coupleOptimization: const {
          'avs_cap': {'cap_applied': true},
        },
        dataSource: 'calculated',
        plannedContributions: const [
          {'id': '3a', 'label': '3a', 'amount': 300},
        ],
        knownValues: const {
          'fri_total': 62,
          'annual_3a_contribution': 5000,
          'monthly_retirement_income': 4200,
          'capital_final': 850000,
        },
        coachContextPacket: packet,
      );

      final profileContext = CoachOrchestrator.buildProfileContextForTest(ctx);

      expect(profileContext['coach_context_packet'], packet);
      final emittedPacket =
          profileContext['coach_context_packet'] as Map<String, dynamic>;
      expect(emittedPacket['facts'], isA<List<dynamic>>());
      expect(emittedPacket['missing_fields'], isA<List<dynamic>>());
      expect(emittedPacket['trajectory'], isA<Map<String, dynamic>>());
      expect(emittedPacket['next_questions'], isA<List<dynamic>>());
      expect(emittedPacket['readiness'], isA<Map<String, dynamic>>());

      expect(emittedPacket.containsKey('first_name'), isFalse);
      expect(emittedPacket.containsKey('commune'), isFalse);
      expect(emittedPacket.containsKey('wizard_answers'), isFalse);

      // Legacy scalar fields remain for backward compatibility; the packet
      // is the new structured spine, not a replacement for auth/gate fields.
      expect(profileContext.containsKey('first_name'), isFalse);
      expect(profileContext['canton'], 'VD');
      expect(profileContext['fri_total'], 62);
      expect(profileContext['annual_3a_contribution'], 5000);
      expect(profileContext['monthly_retirement_income'], 4200);
      expect(profileContext['capital_final'], 850000);
      expect(profileContext['active_goal'], 'Optimiser 3a 2026');
      expect(profileContext['cap_headline'], 'Compléter le 3a');
      expect(profileContext['cap_expected_impact'], 1200);
      expect(
          profileContext['couple_optimization'], isA<Map<String, dynamic>>());
      expect(profileContext['data_source'], 'calculated');
      expect(profileContext['planned_contributions'], isA<List<dynamic>>());
    });

    test('orchestrator omits empty packet to avoid hollow facade payloads', () {
      const ctx = CoachContext(
        firstName: 'Julien',
        age: 36,
        canton: 'VD',
        archetype: 'swiss_native',
      );

      final profileContext = CoachOrchestrator.buildProfileContextForTest(ctx);

      expect(profileContext.containsKey('coach_context_packet'), isFalse);
    });

    test('CoachLlmService.chat passes packet into the real orchestrator seam',
        () async {
      CoachContext? capturedCtx;
      CoachLlmService.registerOrchestrator(({
        required userMessage,
        required history,
        required ctx,
        byokConfig,
        memoryBlock,
        language = 'fr',
        cashLevel = 3,
        isLoggedIn = false,
      }) async {
        capturedCtx = ctx;
        return const CoachResponse(
          message: 'ok',
          disclaimer: 'Outil educatif.',
          wasFiltered: false,
        );
      });

      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 8000,
        prevoyance: const PrevoyanceProfile(
          totalEpargne3a: 12000,
          nombre3a: 2,
          avoirLppTotal: 80000,
          renteAVSEstimeeMensuelle: 2450,
          anneesContribuees: 18,
        ),
        depenses: const DepensesProfile(loyer: 2200, assuranceMaladie: 450),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
          targetAmount: 250000,
        ),
        plannedContributions: const [
          PlannedMonthlyContribution(
            id: 'primary_3a',
            label: '3a',
            amount: 500,
            category: '3a',
            isAutomatic: true,
          ),
        ],
      );

      await CoachLlmService.chat(
        userMessage: 'Ou en est mon plan?',
        profile: profile,
        history: const [],
        config: LlmConfig.defaultOpenAI,
      );

      final packet = capturedCtx?.coachContextPacket;
      expect(packet, isNotNull);
      expect(packet, isNotEmpty);
      expect(capturedCtx?.knownValues['annual_3a_contribution'], 6000);
      expect(capturedCtx?.activeGoal, 'Retraite');
      expect(capturedCtx?.plannedContributions, hasLength(1));

      final profileContext =
          CoachOrchestrator.buildProfileContextForTest(capturedCtx!);
      expect(profileContext['annual_3a_contribution'], 6000);
      expect(profileContext['active_goal'], 'Retraite');
      expect(profileContext['planned_contributions'], [
        {
          'category': '3a',
          'monthly_amount': 500.0,
          'annual_amount': 6000.0,
          'is_automatic': true,
        }
      ]);
      expect(packet!['facts'], isA<List<dynamic>>());
      expect(packet['trajectory'], isA<Map<String, dynamic>>());
      expect(packet['readiness'], isA<Map<String, dynamic>>());
      expect(
        (packet['readiness'] as Map<String, dynamic>)['next_action_id'],
        isA<String>(),
      );
      expect(packet.containsKey('wizard_answers'), isFalse);
      expect(packet.containsKey('first_name'), isFalse);
    });

    test('CoachLlmService.chat forwards monthly consumer debt Safe Mode',
        () async {
      CoachContext? capturedCtx;
      CoachLlmService.registerOrchestrator(({
        required userMessage,
        required history,
        required ctx,
        byokConfig,
        memoryBlock,
        language = 'fr',
        cashLevel = 3,
        isLoggedIn = false,
      }) async {
        capturedCtx = ctx;
        return const CoachResponse(
          message: 'ok',
          disclaimer: 'Outil educatif.',
          wasFiltered: false,
        );
      });

      final profile = CoachProfile.fromWizardAnswers({
        'q_birth_year': 1985,
        'q_canton': 'VD',
        'q_gross_income_monthly': 6000,
        'q_has_consumer_debt': 'yes',
        'q_debt_payments_period_chf': 900,
        '_coach_dettes_hypotheque': 600000,
        'q_housing_cost_period_chf': 2200,
        'q_lamal_premium_monthly_chf': 420,
        'q_cash_total': 30000,
      });

      await CoachLlmService.chat(
        userMessage: 'Je veux optimiser mon 3a',
        profile: profile,
        history: const [],
        config: LlmConfig.defaultOpenAI,
      );

      expect(capturedCtx?.hasDebt, isTrue);
      expect(capturedCtx?.knownValues.containsKey('hasDebt'), isFalse);
    });

    test(
        'persisted budget answers reach Coach semantic packet after wizard reload',
        () async {
      CoachContext? capturedCtx;
      CoachLlmService.registerOrchestrator(({
        required userMessage,
        required history,
        required ctx,
        byokConfig,
        memoryBlock,
        language = 'fr',
        cashLevel = 3,
        isLoggedIn = false,
      }) async {
        capturedCtx = ctx;
        return const CoachResponse(
          message: 'ok',
          disclaimer: 'Outil educatif.',
          wasFiltered: false,
        );
      });

      await ReportPersistenceService.saveAnswers({
        'q_birth_year': 1988,
        'q_canton': 'VD',
        'q_net_income_period_chf': 5379.0,
        'q_pay_frequency': 'monthly',
        'q_housing_cost_period_chf': 2200.0,
        'q_lamal_premium_monthly_chf': 420.0,
        'q_has_consumer_debt': 'yes',
        'q_debt_payments_period_chf': 900.0,
        'q_cash_total': 25000.0,
      });
      await ReportPersistenceService.setCompleted(true);

      final provider = CoachProfileProvider();
      await provider.loadFromWizard();
      expect(provider.profile, isNotNull);

      await CoachLlmService.chat(
        userMessage: 'Combien me reste-t-il ce mois?',
        profile: provider.profile!,
        history: const [],
        config: LlmConfig.defaultOpenAI,
      );

      expect(capturedCtx, isNotNull);
      expect(capturedCtx!.hasDebt, isTrue);
      expect(capturedCtx!.knownValues.containsKey('hasDebt'), isFalse);

      final packet = capturedCtx!.coachContextPacket;
      expect(packet, isNotEmpty);
      final facts =
          (packet['facts'] as List<dynamic>).cast<Map<dynamic, dynamic>>();
      final factValues = <String, Object?>{
        for (final fact in facts) fact['id'] as String: fact['value'],
      };

      expect(factValues['situation.monthly_housing_cost'], 2200.0);
      expect(factValues['situation.lamal_premium_monthly'], 420.0);
      expect(factValues['budget.monthly_net'], closeTo(5379.0, 0.01));
      expect(factValues['budget.monthly_charges'], isA<num>());
      expect(
        factValues['budget.monthly_charges'] as num,
        greaterThanOrEqualTo(2200 + 420 + 900),
      );
      expect(factValues['budget.monthly_free'], isA<num>());
      expect((factValues['budget.monthly_free'] as num).isFinite, isTrue);

      for (final value in factValues.values.whereType<num>()) {
        expect(value.isFinite, isTrue);
        expect(value, isNot(19272200));
        expect(value, isNot(420420));
      }
    });

    test(
        'independent no-LPP 3a facts survive restart and profile correction recalculates coach response',
        () async {
      CoachContext? capturedCtx;
      CoachLlmService.registerOrchestrator(({
        required userMessage,
        required history,
        required ctx,
        byokConfig,
        memoryBlock,
        language = 'fr',
        cashLevel = 3,
        isLoggedIn = false,
      }) async {
        capturedCtx = ctx;
        return CoachOrchestrator.generateChat(
          userMessage: userMessage,
          history: history,
          ctx: ctx,
          byokConfig: byokConfig,
          memoryBlock: memoryBlock,
          language: language,
          cashLevel: cashLevel,
          isLoggedIn: isLoggedIn,
        );
      });

      Future<CoachResponse> askAfterRestart({
        required double professionalIncomeAnnual,
        required double planned3aAnnual,
      }) async {
        final saved = await ReportPersistenceService.saveAnswers({
          'q_firstname': 'Nadia',
          'q_birth_year': 1988,
          'q_canton': 'VD',
          'q_nationality': 'CH',
          'q_us_tax_person': false,
          'q_employment_status': 'independant',
          'q_has_pension_fund': false,
          'q_pay_frequency': 'monthly',
          'q_net_income_period_chf': professionalIncomeAnnual / 12,
          'q_self_employed_net_income_annual_chf': professionalIncomeAnnual,
          'q_3a_annual_contribution': planned3aAnnual,
          'q_savings_monthly': planned3aAnnual / 12,
          'q_savings_allocation': ['3a'],
        });
        expect(saved, isTrue);
        await ReportPersistenceService.setCompleted(true);

        final provider = CoachProfileProvider();
        await provider.loadFromWizard();
        final profile = provider.profile!;
        expect(profile.archetype, FinancialArchetype.independentNoLpp);
        expect(
          profile.independentNetProfessionalIncomeAnnual,
          professionalIncomeAnnual,
        );
        expect(profile.total3aMensuel * 12, closeTo(planned3aAnnual, 0.01));
        expect(
          BudgetInputs.fromCoachProfile(profile).netIncome,
          closeTo(professionalIncomeAnnual / 12, 0.01),
        );
        expect(
          profile.dataSources['independentNetProfessionalIncomeAnnual'],
          ProfileDataSource.userInput,
        );
        expect(
          profile.dataSources['plannedContributions.3a'],
          ProfileDataSource.userInput,
        );
        expect(
          profile.dataTimestamps['independentNetProfessionalIncomeAnnual'],
          isNotNull,
        );
        expect(profile.dataTimestamps['plannedContributions.3a'], isNotNull);

        capturedCtx = null;
        final response = await CoachLlmService.chat(
          userMessage: 'Combien verser en 3a ?',
          profile: profile,
          history: const [],
          config: LlmConfig.defaultOpenAI,
        );

        expect(capturedCtx, isNotNull);
        expect(capturedCtx!.archetype, 'independent_no_lpp');
        expect(
          capturedCtx!.knownValues['self_employed_net_income_annual'],
          professionalIncomeAnnual,
        );
        expect(
          capturedCtx!.knownValues['annual_3a_contribution'],
          closeTo(planned3aAnnual, 0.01),
        );
        expect(
          capturedCtx!
              .dataReliability['independentNetProfessionalIncomeAnnual'],
          'userInput',
        );
        expect(
          capturedCtx!.dataReliability['plannedContributions.3a'],
          'userInput',
        );
        return response;
      }

      final initial = await askAfterRestart(
        professionalIncomeAnnual: 86400,
        planned3aAnnual: 6000,
      );
      expect(initial.message, contains('86\u00a0400\u00a0CHF/an'));
      expect(initial.message, contains('6\u00a0000\u00a0CHF/an'));
      expect(initial.message, contains('11\u00a0280\u00a0CHF/an'));
      expect(
          initial.message, contains('revenu professionnel: saisie dans MINT'));
      expect(initial.message,
          contains('versements 3a planifiés: saisie dans MINT'));
      expect(initial.message, isNot(contains('Impact fiscal indicatif')));
      expect(initial.message, isNot(contains('2\u00a0218 CHF')));
      expect(initial.message, isNot(contains('ouvrir un compte')));
      expect(initial.message, isNot(contains('fintech')));

      final corrected = await askAfterRestart(
        professionalIncomeAnnual: 90000,
        planned3aAnnual: 7200,
      );
      expect(corrected.message, contains('90\u00a0000\u00a0CHF/an'));
      expect(corrected.message, contains('7\u00a0200\u00a0CHF/an'));
      expect(corrected.message, contains('10\u00a0800\u00a0CHF/an'));
      expect(corrected.message, isNot(contains('11\u00a0280\u00a0CHF/an')));
      expect(corrected.message, contains('revenu déterminant fiscal/AVS'));
      expect(corrected.message, contains('Marge légale ≠ capacité mensuelle'));
    });

    test('shared adapter builds the packet used by screen and service paths',
        () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 8000,
        prevoyance: const PrevoyanceProfile(
          totalEpargne3a: 12000,
          nombre3a: 2,
          avoirLppTotal: 80000,
          renteAVSEstimeeMensuelle: 2450,
          anneesContribuees: 18,
        ),
        depenses: const DepensesProfile(loyer: 2200, assuranceMaladie: 450),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
          targetAmount: 250000,
        ),
      );

      final packet = CoachContextPacketAdapter.fromProfile(profile);

      expect(packet, isNotEmpty);
      expect(packet['facts'], isA<List<dynamic>>());
      expect(packet['missing_fields'], isA<List<dynamic>>());
      expect(packet['trajectory'], isA<Map<String, dynamic>>());
      expect(packet['next_questions'], isA<List<dynamic>>());
      expect(packet['readiness'], isA<Map<String, dynamic>>());
      expect(packet.containsKey('wizard_answers'), isFalse);
      expect(packet.containsKey('first_name'), isFalse);
    });
  });
}
