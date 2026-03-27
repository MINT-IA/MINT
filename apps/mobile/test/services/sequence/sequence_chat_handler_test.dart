import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/sequence/sequence_chat_handler.dart';
import 'package:mint_mobile/services/sequence/sequence_coordinator.dart';
import 'package:mint_mobile/services/sequence/sequence_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SequenceChatHandler.isSequenceActive', () {
    test('returns false when no run stored', () async {
      expect(await SequenceChatHandler.isSequenceActive(), isFalse);
    });

    test('returns true when active run stored', () async {
      await SequenceChatHandler.startSequence('housing_purchase');
      expect(await SequenceChatHandler.isSequenceActive(), isTrue);
    });
  });

  group('SequenceChatHandler.startSequence', () {
    test('creates run with first step active', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');
      expect(run, isNotNull);
      expect(run!.templateId, 'housing_purchase');
      expect(run.activeStepId, 'housing_01_affordability');
      expect(run.isActive, isTrue);
    });

    test('records first step proposal in CapMemory', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');
      final capMem = await CapMemoryStore.load();
      expect(
        capMem.proposalCount(run!.runId, 'housing_01_affordability'),
        1,
      );
    });

    test('returns null for unknown intent', () async {
      final run = await SequenceChatHandler.startSequence('unknown_intent');
      expect(run, isNull);
    });

    test('startSequence with valid intent persists', () async {
      await SequenceChatHandler.startSequence('simulator_3a');
      final stored = await SequenceStore.load();
      expect(stored, isNotNull);
      expect(stored!.templateId, 'optimize_3a');
    });
  });

  group('SequenceChatHandler.handleStepReturn', () {
    test('returns null when no sequence active', () async {
      final result = await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.completed,
      );
      expect(result, isNull);
    });

    test('completed step advances to next', () async {
      await SequenceChatHandler.startSequence('housing_purchase');

      final result = await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.completed,
        stepOutputs: {
          'capacite_achat': 850000.0,
          'fonds_propres_requis': 170000.0,
        },
      );

      expect(result, isNotNull);
      expect(result!.action, isA<AdvanceAction>());
      final advance = result.action as AdvanceAction;
      expect(advance.nextStep.id, 'housing_02_epl');
      expect(advance.prefill['montant_necessaire'], 170000.0);
    });

    test('abandoned step triggers retry on first attempt', () async {
      await SequenceChatHandler.startSequence('housing_purchase');

      final result = await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.abandoned,
      );

      expect(result, isNotNull);
      expect(result!.action, isA<RetryAction>());
    });

    test('abandoned twice triggers pause on required step', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');
      // Increment proposal count to simulate second attempt
      var capMem = await CapMemoryStore.load();
      capMem = capMem.incrementProposal(
        run!.runId,
        'housing_01_affordability',
      );
      await CapMemoryStore.save(capMem);

      final result = await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.abandoned,
      );

      expect(result, isNotNull);
      expect(result!.action, isA<PauseAction>());
    });

    test('completed all steps produces CompleteAction', () async {
      await SequenceChatHandler.startSequence('simulator_3a');

      // Complete step 1
      await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.completed,
        stepOutputs: {'contribution_annuelle': 7258},
      );

      // Complete step 2
      await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.completed,
        stepOutputs: {'gain_echelonnement': 12000},
      );

      // Complete step 3 (last)
      final result = await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.completed,
        stepOutputs: {'rendement_net': 2.1},
      );

      expect(result, isNotNull);
      expect(result!.action, isA<CompleteAction>());

      // Run should be cleared from store
      final stored = await SequenceStore.load();
      expect(stored, isNull);
    });

    test('advance increments proposal for next step', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      // Complete step 1 → advances to step 2
      await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.completed,
        stepOutputs: {'capacite_achat': 850000.0},
      );

      // Step 2 should have 1 proposal (from the advance)
      final capMem = await CapMemoryStore.load();
      expect(capMem.proposalCount(run!.runId, 'housing_02_epl'), 1);
    });

    test('retry increments proposal for same step', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      // Abandon step 1 → retry
      await SequenceChatHandler.handleStepReturn(ScreenOutcome.abandoned);

      // Step 1 should now have 2 proposals (1 from start + 1 from retry)
      final capMem = await CapMemoryStore.load();
      expect(capMem.proposalCount(run!.runId, 'housing_01_affordability'), 2);
    });

    test('changedInputs triggers re-evaluate', () async {
      await SequenceChatHandler.startSequence('housing_purchase');

      // Complete step 1
      await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.completed,
        stepOutputs: {'capacite_achat': 850000.0},
      );

      // Step 2 active — user changes profile data on the screen.
      // updatedFields signals that profile data changed → triggers re-evaluation
      // of completed steps that had outputs.
      final result = await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.changedInputs,
        updatedFields: {'prevoyance.avoirLppTotal': 300000},
      );

      // Step 1 had outputs → invalidated
      expect(result, isNotNull);
      expect(result!.action, isA<ReEvaluateAction>());
    });
  });

  group('SequenceChatHandler.handleRealtimeReturn', () {
    test('returns null when no sequence active', () async {
      final result = await SequenceChatHandler.handleRealtimeReturn(
        const ScreenReturn.completed(route: '/hypotheque'),
      );
      expect(result, isNull);
    });

    test('delegates to coordinator when sequence active', () async {
      await SequenceChatHandler.startSequence('housing_purchase');

      final result = await SequenceChatHandler.handleRealtimeReturn(
        const ScreenReturn.completed(
          route: '/hypotheque',
          stepOutputs: {'capacite_achat': 900000.0},
        ),
      );

      expect(result, isNotNull);
      // Completed step 1 → should advance to step 2
      expect(result!.action, isA<AdvanceAction>());
      final advance = result.action as AdvanceAction;
      expect(advance.nextStep.id, 'housing_02_epl');
    });

    test('realtime advance increments proposal for next step', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      await SequenceChatHandler.handleRealtimeReturn(
        const ScreenReturn.completed(
          route: '/hypotheque',
          stepOutputs: {'capacite_achat': 850000.0},
        ),
      );

      // Next step (housing_02_epl) should have 1 proposal
      final capMem = await CapMemoryStore.load();
      expect(capMem.proposalCount(run!.runId, 'housing_02_epl'), 1);
    });
  });

  group('SequenceChatHandler.quitSequence', () {
    test('clears run and proposals', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');
      expect(await SequenceChatHandler.isSequenceActive(), isTrue);

      await SequenceChatHandler.quitSequence();
      expect(await SequenceChatHandler.isSequenceActive(), isFalse);

      // Proposals also cleared
      final capMem = await CapMemoryStore.load();
      expect(
        capMem.proposalCount(run!.runId, 'housing_01_affordability'),
        0,
      );
    });

    test('quitSequence is safe when no sequence active', () async {
      // Should not throw
      await SequenceChatHandler.quitSequence();
    });
  });
}
