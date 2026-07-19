import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/scenario_session.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/models/sequence_run.dart';
import 'package:mint_mobile/models/sequence_template.dart';
import 'package:mint_mobile/providers/scenario_session_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/scenario/scenario_session_store.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/services/sequence/sequence_chat_handler.dart';
import 'package:mint_mobile/services/sequence/sequence_coordinator.dart';
import 'package:mint_mobile/services/sequence/sequence_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _MemoryScenarioCache implements ScenarioSessionCache {
  String? value;
  bool unavailable = false;

  @override
  Future<void> clear() async {
    if (unavailable) throw StateError('cache unavailable');
    value = null;
  }

  @override
  Future<String?> read() async {
    if (unavailable) throw StateError('cache unavailable');
    return value;
  }

  @override
  Future<void> write(String value) async {
    if (unavailable) throw StateError('cache unavailable');
    this.value = value;
  }
}

void main() {
  const eplId = '11111111-1111-4111-8111-111111111111';
  const renteCapitalId = '22222222-2222-4222-8222-222222222222';
  const absentId = '33333333-3333-4333-8333-333333333333';
  late _MemoryScenarioCache cache;
  late ScenarioSessionProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FeatureFlags.enableGuidedSequences = true;
    cache = _MemoryScenarioCache();
    final ids = [eplId, renteCapitalId].iterator;
    provider = ScenarioSessionProvider(
      enabled: true,
      store: ScenarioSessionStore(
        cache: cache,
        idFactory: () {
          ids.moveNext();
          return ids.current;
        },
        clock: () => DateTime.utc(2026, 7, 19, 12),
      ),
    );
    addTearDown(() => FeatureFlags.enableGuidedSequences = false);
  });

  Future<void> createCompletedEpl() async {
    final draft = await provider.open(
      const EplScenarioLevers(requestedWithdrawal: 80000),
      factsReady: true,
    );
    expect(draft?.id, eplId);
    expect(
      await provider.markCalculated(
        eplId,
        expectedKind: ScenarioKind.epl,
      ),
      isNotNull,
    );
    expect(
      await provider.markTerminal(
        eplId,
        expectedKind: ScenarioKind.epl,
        status: ScenarioStatus.completed,
      ),
      isNotNull,
    );
  }

  Future<void> createCompletedRenteCapital() async {
    final draft = await provider.open(
      const RenteCapitalScenarioLevers(
        retirementAge: 64,
        annualBuyback: 10000,
        hasEpl: false,
        eplAmount: 0,
        returnRatePercent: 3,
        withdrawalRatePercent: 4,
        inflationPercent: 2,
        lifeExpectancy: 88,
      ),
      factsReady: true,
    );
    expect(draft?.id, renteCapitalId);
    await provider.markCalculated(
      renteCapitalId,
      expectedKind: ScenarioKind.renteCapital,
    );
    await provider.markTerminal(
      renteCapitalId,
      expectedKind: ScenarioKind.renteCapital,
      status: ScenarioStatus.completed,
    );
  }

  SequenceRun activeEplRun() {
    const template = SequenceTemplate.housingPurchase;
    return SequenceRun.start(
      runId: 'housing-run',
      templateId: template.id,
      stepIds: template.steps.map((step) => step.id).toList(),
    ).completeStep(
      'housing_01_affordability',
      const {
        'capacite_achat': 850000.0,
        'fonds_propres_requis': 170000.0,
      },
    ).activateStep('housing_02_epl');
  }

  ScreenReturn completedEplReturn({
    String route = '/epl',
    String? runId = 'housing-run',
    String? stepId = 'housing_02_epl',
    String? eventId = 'evt-epl-1',
    String scenarioId = eplId,
    ScenarioStatus scenarioStatus = ScenarioStatus.completed,
  }) =>
      ScreenReturn.completed(
        route: route,
        runId: runId,
        stepId: stepId,
        eventId: eventId,
        scenarioId: scenarioId,
        scenarioStatus: scenarioStatus,
      );

  group('scenario step allowlist', () {
    test('run rejects every non-exact scenario step ID', () {
      final run = activeEplRun();

      for (final stepId in const [
        '',
        'housing_01_affordability',
        'housing_02_epl_notes',
        'ret_02_choice_extra',
        'pre_03_choice/legacy',
      ]) {
        expect(
          () => run.completeScenarioStep(stepId, eplId),
          throwsArgumentError,
          reason: stepId,
        );
      }
    });

    test('deserialization rejects structurally invalid scenario references',
        () {
      Map<String, dynamic> validJson() =>
          activeEplRun().completeScenarioStep('housing_02_epl', eplId).toJson();

      void expectFailsClosed(Map<String, dynamic> json) {
        expect(
          () => SequenceRun.fromJson(json),
          throwsA(isA<FormatException>()),
        );
        expect(SequenceRun.deserialize(jsonEncode(json)), isNull);
      }

      final outsideAllowlist = validJson()
        ..['stepStates'] = {'housing_02_epl_notes': 'completed'}
        ..['scenarioReferences'] = {
          'housing_02_epl_notes': {
            'scenarioId': eplId,
            'scenarioStatus': 'completed',
          },
        };
      expectFailsClosed(outsideAllowlist);

      for (final invalidState in <String, Map<String, dynamic>>{
        'non-completed': {'housing_02_epl': 'active'},
        'absent': <String, dynamic>{},
      }.entries) {
        final invalid = validJson()..['stepStates'] = invalidState.value;
        expectFailsClosed(invalid);
      }

      final duplicateId = validJson()
        ..['stepStates'] = {
          'housing_02_epl': 'completed',
          'ret_02_choice': 'completed',
        }
        ..['scenarioReferences'] = {
          'housing_02_epl': {
            'scenarioId': eplId,
            'scenarioStatus': 'completed',
          },
          'ret_02_choice': {
            'scenarioId': eplId,
            'scenarioStatus': 'completed',
          },
        };
      expectFailsClosed(duplicateId);
    });

    test('only the three exact G1 bindings carry a scenario kind', () {
      const templates = [
        SequenceTemplate.housingPurchase,
        SequenceTemplate.optimize3a,
        SequenceTemplate.retirementPrep,
        SequenceTemplate.preretraiteComplete,
        SequenceTemplate.financialTension,
        SequenceTemplate.coupleFinancier,
        SequenceTemplate.naissanceCouts,
        SequenceTemplate.premiersPas,
        SequenceTemplate.densification,
        SequenceTemplate.retraiteActive,
      ];

      final bindings = <String, ScenarioKind>{};
      for (final template in templates) {
        for (final step in template.steps) {
          if (step.scenarioKind case final kind?) bindings[step.id] = kind;
        }
      }

      expect(bindings, const {
        'housing_02_epl': ScenarioKind.epl,
        'ret_02_choice': ScenarioKind.renteCapital,
        'pre_03_choice': ScenarioKind.renteCapital,
      });
    });

    test('proof is explicit and cannot be forged in the coordinator', () {
      final run = activeEplRun();
      final ret = completedEplReturn();

      final withoutProof = SequenceCoordinator.decide(
        template: SequenceTemplate.housingPurchase,
        run: run,
        stepReturn: ret,
        proposalCount: 1,
      );
      final withProof = SequenceCoordinator.decide(
        template: SequenceTemplate.housingPurchase,
        run: run,
        stepReturn: ret,
        proposalCount: 1,
        scenarioReferenceValidated: true,
      );

      expect(withoutProof, isA<PauseAction>());
      expect(withProof, isA<AdvanceAction>());
      expect((withProof as AdvanceAction).completedScenarioId, eplId);
      expect(withProof.nextStep.id, 'housing_03_fiscal');
    });

    test('both rente-capital bindings accept the exact registered route', () {
      final cases = <SequenceTemplate, String>{
        SequenceTemplate.retirementPrep: 'ret_02_choice',
        SequenceTemplate.preretraiteComplete: 'pre_03_choice',
      };

      for (final entry in cases.entries) {
        var run = SequenceRun.start(
          runId: 'retirement-run',
          templateId: entry.key.id,
          stepIds: entry.key.steps.map((step) => step.id).toList(),
        );
        for (final step in entry.key.steps) {
          if (step.id == entry.value) break;
          run = run.completeStep(step.id, const {});
        }
        run = run.activateStep(entry.value);

        final action = SequenceCoordinator.decide(
          template: entry.key,
          run: run,
          stepReturn: ScreenReturn.completed(
            route: '/rente-vs-capital',
            runId: run.runId,
            stepId: entry.value,
            eventId: 'evt-${entry.value}',
            scenarioId: renteCapitalId,
            scenarioStatus: ScenarioStatus.completed,
          ),
          proposalCount: 1,
          scenarioReferenceValidated: true,
        );

        expect(action, isA<AdvanceAction>(), reason: entry.value);
        expect(
          (action as AdvanceAction).completedScenarioId,
          renteCapitalId,
          reason: entry.value,
        );
      }
    });
  });

  group('authoritative provider resolver', () {
    test('accepts only a completed ID of the expected kind', () async {
      final draft = await provider.open(
        const EplScenarioLevers(requestedWithdrawal: 80000),
        factsReady: true,
      );
      expect(
        await provider.validatesCompleted(draft!.id, ScenarioKind.epl),
        isFalse,
      );
      await provider.markCalculated(
        draft.id,
        expectedKind: ScenarioKind.epl,
      );
      expect(
        await provider.validatesCompleted(draft.id, ScenarioKind.epl),
        isFalse,
      );
      await provider.markTerminal(
        draft.id,
        expectedKind: ScenarioKind.epl,
        status: ScenarioStatus.completed,
      );

      expect(
        await provider.validatesCompleted(draft.id, ScenarioKind.epl),
        isTrue,
      );
      expect(
        await provider.validatesCompleted(
          draft.id,
          ScenarioKind.renteCapital,
        ),
        isFalse,
      );
      expect(
        await provider.validatesCompleted(absentId, ScenarioKind.epl),
        isFalse,
      );
    });

    test('disabled provider and store read failure fail closed', () async {
      await createCompletedEpl();
      final disabled = ScenarioSessionProvider(
        enabled: false,
        store: ScenarioSessionStore(cache: cache),
      );
      expect(
        await disabled.validatesCompleted(eplId, ScenarioKind.epl),
        isFalse,
      );

      cache.unavailable = true;
      expect(
        await provider.validatesCompleted(eplId, ScenarioKind.epl),
        isFalse,
      );
    });
  });

  group('realtime scenario bridge', () {
    test('valid store-backed EPL completion advances without financial output',
        () async {
      await createCompletedEpl();
      await SequenceStore.save(activeEplRun());

      final result = await SequenceChatHandler.handleRealtimeReturn(
        completedEplReturn(),
        scenarioValidator: provider.validatesCompleted,
      );

      expect(result, isNotNull);
      expect(result!.action, isA<AdvanceAction>());
      expect(result.updatedRun.activeStepId, 'housing_03_fiscal');
      expect(
        result.updatedRun.scenarioReferences['housing_02_epl'],
        const ScenarioStepReference(
          id: eplId,
          status: ScenarioStatus.completed,
        ),
      );
      expect(result.updatedRun.stepOutputs, isNot(contains('housing_02_epl')));
      expect(result.updatedRun.isScenarioProcessed(eplId), isTrue);

      final stored = await SequenceStore.load();
      expect(stored?.activeStepId, 'housing_03_fiscal');
      expect(stored?.isScenarioProcessed(eplId), isTrue);
    });

    test(
        'malformed, missing, wrong-route, wrong-kind and absent references pause',
        () async {
      await createCompletedEpl();
      await createCompletedRenteCapital();
      final cases = <String, ScreenReturn>{
        'missing sequence identity': const ScreenReturn.completed(
          route: '/epl',
          scenarioId: eplId,
          scenarioStatus: ScenarioStatus.completed,
        ),
        'wrong run': completedEplReturn(runId: 'other-run'),
        'wrong step': completedEplReturn(stepId: 'housing_03_fiscal'),
        'empty event': completedEplReturn(eventId: ''),
        'wrong route': completedEplReturn(route: '/rente-vs-capital'),
        'wrong status': completedEplReturn(
          scenarioStatus: ScenarioStatus.abandoned,
        ),
        'malformed ID': completedEplReturn(scenarioId: 'scenario-epl'),
        'absent ID': completedEplReturn(scenarioId: absentId),
        'wrong kind': completedEplReturn(scenarioId: renteCapitalId),
      };

      for (final entry in cases.entries) {
        await SequenceStore.save(activeEplRun());
        final result = await SequenceChatHandler.handleRealtimeReturn(
          entry.value,
          scenarioValidator: provider.validatesCompleted,
        );
        expect(
          result?.action,
          isA<PauseAction>(),
          reason: entry.key,
        );
        expect(
          (await SequenceStore.load())?.status,
          SequenceRunStatus.paused,
          reason: entry.key,
        );
      }
    });

    test('store read failure pauses instead of trusting the return', () async {
      await createCompletedEpl();
      await SequenceStore.save(activeEplRun());
      cache.unavailable = true;

      final result = await SequenceChatHandler.handleRealtimeReturn(
        completedEplReturn(),
        scenarioValidator: provider.validatesCompleted,
      );

      expect(result?.action, isA<PauseAction>());
      expect(result?.updatedRun.status, SequenceRunStatus.paused);
    });

    test('abandoned scenario never satisfies the sequence step', () async {
      await SequenceStore.save(activeEplRun());

      final result = await SequenceChatHandler.handleRealtimeReturn(
        const ScreenReturn.abandoned(
          route: '/epl',
          runId: 'housing-run',
          stepId: 'housing_02_epl',
          eventId: 'evt-abandoned',
          scenarioId: eplId,
          scenarioStatus: ScenarioStatus.abandoned,
        ),
        scenarioValidator: provider.validatesCompleted,
      );

      expect(result?.action, isNot(isA<AdvanceAction>()));
      expect(result?.updatedRun.activeStepId, 'housing_02_epl');
      expect(result?.updatedRun.scenarioReferences, isEmpty);
    });

    test('legacy handler cannot satisfy an allowlisted scenario step',
        () async {
      await SequenceStore.save(activeEplRun());

      final result = await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.completed,
        stepOutputs: const {
          'montant_epl': 80000.0,
          'impact_rente': -250.0,
        },
      );

      expect(result?.action, isA<PauseAction>());
      expect(result?.updatedRun.activeStepId, 'housing_02_epl');
      expect(result?.updatedRun.stepOutputs, isNot(contains('housing_02_epl')));
      expect(result?.updatedRun.scenarioReferences, isEmpty);
    });

    test('scenario payload cannot bypass a non-allowlisted step', () async {
      await createCompletedEpl();
      final run = SequenceRun.start(
        runId: 'housing-run',
        templateId: SequenceTemplate.housingPurchase.id,
        stepIds: SequenceTemplate.housingPurchase.steps
            .map((step) => step.id)
            .toList(),
      );
      await SequenceStore.save(run);

      final result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt-bypass',
          scenarioId: eplId,
          scenarioStatus: ScenarioStatus.completed,
        ),
        scenarioValidator: provider.validatesCompleted,
      );

      expect(result?.action, isA<PauseAction>());
      expect(result?.updatedRun.activeStepId, 'housing_01_affordability');
      expect(result?.updatedRun.scenarioReferences, isEmpty);
    });
  });

  group('persistent scenario anti-replay', () {
    test('cold load purges exact legacy scenario outputs from preferences',
        () async {
      final prefs = await SharedPreferences.getInstance();
      for (final stepId in const [
        'housing_02_epl',
        'ret_02_choice',
        'pre_03_choice',
      ]) {
        final legacy = SequenceRun(
          runId: 'legacy-$stepId',
          templateId: 'legacy-template',
          startedAt: DateTime.utc(2026, 7, 19),
          stepStates: {stepId: StepRunState.active},
          stepOutputs: {
            stepId: const {'decision_mixte': 'capital', 'amount': 80000},
          },
        );
        await prefs.setString('mint_sequence_run', legacy.serialize());

        expect(await SequenceStore.load(prefs: prefs), isNull, reason: stepId);
        expect(
          prefs.containsKey('mint_sequence_run'),
          isFalse,
          reason: stepId,
        );
      }
    });

    test('cold load purges malformed state but not similar step IDs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mint_sequence_run', '{malformed');
      expect(await SequenceStore.load(prefs: prefs), isNull);
      expect(prefs.containsKey('mint_sequence_run'), isFalse);

      final unrelated = SequenceRun(
        runId: 'unrelated',
        templateId: 'unrelated',
        startedAt: DateTime.utc(2026, 7, 19),
        stepStates: const {
          'housing_02_epl_notes': StepRunState.active,
        },
        stepOutputs: const {
          'housing_02_epl_notes': {'montant_epl': 80000},
        },
      );
      await prefs.setString('mint_sequence_run', unrelated.serialize());

      expect(await SequenceStore.load(prefs: prefs), isNotNull);
      expect(prefs.containsKey('mint_sequence_run'), isTrue);
    });

    test('same event and same scenario with a new event are both rejected',
        () async {
      await createCompletedEpl();
      await SequenceStore.save(activeEplRun());
      final ret = completedEplReturn();

      final first = await SequenceChatHandler.handleRealtimeReturn(
        ret,
        scenarioValidator: provider.validatesCompleted,
      );
      expect(first?.action, isA<AdvanceAction>());

      final sameEvent = await SequenceChatHandler.handleRealtimeReturn(
        ret,
        scenarioValidator: provider.validatesCompleted,
      );
      expect(sameEvent, isNull);

      final reopened = first!.updatedRun.invalidateSteps(
          const ['housing_02_epl']).activateStep('housing_02_epl');
      expect(reopened.scenarioReferences, isNot(contains('housing_02_epl')));
      expect(reopened.isScenarioProcessed(eplId), isTrue);
      final coldReopened = SequenceRun.deserialize(reopened.serialize());
      expect(coldReopened, isNotNull);
      expect(coldReopened!.scenarioReferences, isEmpty);
      expect(coldReopened.isScenarioProcessed(eplId), isTrue);
      await SequenceStore.save(coldReopened);

      final newEvent = await SequenceChatHandler.handleRealtimeReturn(
        completedEplReturn(eventId: 'evt-epl-2'),
        scenarioValidator: provider.validatesCompleted,
      );
      expect(newEvent?.action, isA<PauseAction>());
    });

    test('scenario replay memory survives cold serialization and stays bounded',
        () {
      var run = activeEplRun();
      for (var i = 0; i < 25; i++) {
        final id = '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';
        run = run.completeScenarioStep('housing_02_epl', id);
      }

      final cold = SequenceRun.deserialize(run.serialize());
      expect(cold, isNotNull);
      expect(
        cold!.processedScenarioIds,
        hasLength(SequenceRun.maxProcessedScenarios),
      );
      expect(
        cold.isScenarioProcessed(
          '00000000-0000-4000-8000-000000000000',
        ),
        isFalse,
      );
      expect(
        cold.isScenarioProcessed(
          '00000000-0000-4000-8000-000000000024',
        ),
        isTrue,
      );
    });

    test('scenario serialization contains only opaque ID and status', () {
      final preMigrationRun = SequenceRun(
        runId: 'housing-run',
        templateId: SequenceTemplate.housingPurchase.id,
        startedAt: DateTime.utc(2026, 7, 19),
        stepStates: const {
          'housing_02_epl': StepRunState.active,
        },
        stepOutputs: const {
          'housing_02_epl': {
            'montant_epl': 80000.0,
            'impact_rente': -250.0,
          },
        },
      );
      final serialized = preMigrationRun
          .completeScenarioStep('housing_02_epl', eplId)
          .serialize();

      expect(serialized, contains(eplId));
      expect(serialized, contains('completed'));
      for (final forbidden in const [
        'requestedWithdrawal',
        'montant_epl',
        'impact_rente',
        'annualBuyback',
        'CHF',
      ]) {
        expect(serialized, isNot(contains(forbidden)));
      }
    });
  });

  test(
      'tracker return flows through real provider validation into SequenceStore',
      () async {
    await createCompletedEpl();
    await SequenceStore.save(activeEplRun());
    final tracked = ScreenCompletionTracker.stream.firstWhere(
      (ret) => ret.eventId == 'evt-tracker-epl',
    );
    final emitted = completedEplReturn(eventId: 'evt-tracker-epl');

    await ScreenCompletionTracker.markCompletedWithReturn('epl', emitted);
    final result = await SequenceChatHandler.handleRealtimeReturn(
      await tracked,
      scenarioValidator: provider.validatesCompleted,
    );

    expect(result?.action, isA<AdvanceAction>());
    expect((await SequenceStore.load())?.activeStepId, 'housing_03_fiscal');
  });
}
