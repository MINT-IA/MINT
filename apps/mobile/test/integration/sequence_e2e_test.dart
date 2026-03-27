// Integration tests for the full guided sequence orchestration chain.
//
// These tests prove the E2E flow works — not just isolated services.
// They exercise: startSequence → handleRealtimeReturn → coordinator →
// store → prefill transfer → dedup → completion.
//
// See: docs/RFC_AGENT_LOOP_STATEFUL.md, docs/SEQUENCE_PHASE2_COMPLETION_PLAN.md

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/models/sequence_run.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/sequence/sequence_chat_handler.dart';
import 'package:mint_mobile/services/sequence/sequence_coordinator.dart';
import 'package:mint_mobile/services/sequence/sequence_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ════════════════════════════════════════════════════════════════
  //  FULL MULTI-STEP E2E FLOW
  // ════════════════════════════════════════════════════════════════

  group('E2E — Housing purchase sequence (4 steps)', () {
    test('full flow: start → step 1 complete → advance → step 2 complete → advance → step 3 complete → sequence complete', () async {
      // ── START ──────────────────────────────────────────────────
      final run = await SequenceChatHandler.startSequence('housing_purchase');
      expect(run, isNotNull);
      expect(run!.templateId, 'housing_purchase');
      expect(run.activeStepId, 'housing_01_affordability');
      expect(run.isActive, isTrue);

      // Verify run is persisted
      final storedRun = await SequenceStore.load();
      expect(storedRun, isNotNull);
      expect(storedRun!.runId, run.runId);

      // Verify first step proposal tracked
      var capMem = await CapMemoryStore.load();
      expect(capMem.proposalCount(run.runId, 'housing_01_affordability'), 1);

      // ── STEP 1: /hypotheque (Tier A) ──────────────────────────
      final step1Result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_step1_${run.runId}',
          stepOutputs: const {
            'capacite_achat': 850000.0,
            'fonds_propres_requis': 170000.0,
          },
        ),
      );

      expect(step1Result, isNotNull);
      expect(step1Result!.action, isA<AdvanceAction>());
      final advance1 = step1Result.action as AdvanceAction;
      expect(advance1.nextStep.id, 'housing_02_epl');
      expect(advance1.progressLabel, '1/4');
      // Verify output transfer via outputMapping
      expect(advance1.prefill['montant_necessaire'], 170000.0);

      // Verify step 2 proposal tracked
      capMem = await CapMemoryStore.load();
      expect(capMem.proposalCount(run.runId, 'housing_02_epl'), 1);

      // Verify eventId was recorded
      final runAfterStep1 = await SequenceStore.load();
      expect(runAfterStep1!.isEventProcessed('evt_step1_${run.runId}'), isTrue);

      // ── STEP 2: /epl (Tier A) ─────────────────────────────────
      final step2Result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/epl',
          runId: run.runId,
          stepId: 'housing_02_epl',
          eventId: 'evt_step2_${run.runId}',
          stepOutputs: const {
            'montant_epl': 50000.0,
            'impact_rente': -200.0,
          },
        ),
      );

      expect(step2Result, isNotNull);
      expect(step2Result!.action, isA<AdvanceAction>());
      final advance2 = step2Result.action as AdvanceAction;
      expect(advance2.nextStep.id, 'housing_03_fiscal');
      // Verify accumulated outputs: step 1 + step 2 outputs available
      expect(advance2.prefill['montant_retrait'], 50000.0);

      // ── STEP 3: /fiscal (Tier A) ──────────────────────────────
      final step3Result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/fiscal',
          runId: run.runId,
          stepId: 'housing_03_fiscal',
          eventId: 'evt_step3_${run.runId}',
          stepOutputs: const {
            'impot_retrait': 3200.0,
          },
        ),
      );

      // Step 4 is inline summary (_inline_summary) → sequence complete
      expect(step3Result, isNotNull);
      expect(step3Result!.action, isA<CompleteAction>());
      final complete = step3Result.action as CompleteAction;
      // All outputs accumulated
      expect(complete.allOutputs.containsKey('housing_01_affordability'), isTrue);
      expect(complete.allOutputs.containsKey('housing_02_epl'), isTrue);
      expect(complete.allOutputs.containsKey('housing_03_fiscal'), isTrue);

      // Verify run cleared from store
      final finalRun = await SequenceStore.load();
      expect(finalRun, isNull);

      // Verify proposals cleared
      capMem = await CapMemoryStore.load();
      expect(capMem.proposalCount(run.runId, 'housing_01_affordability'), 0);
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  DEDUP CHAIN
  // ════════════════════════════════════════════════════════════════

  group('E2E — Dedup chain', () {
    test('same eventId rejected on second call', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      final first = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_dedup_test',
          stepOutputs: const {'capacite_achat': 850000.0},
        ),
      );
      expect(first, isNotNull);

      // Same event again — should be rejected
      final duplicate = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_dedup_test',
          stepOutputs: const {'capacite_achat': 900000.0},
        ),
      );
      expect(duplicate, isNull);
    });

    test('wrong runId rejected', () async {
      await SequenceChatHandler.startSequence('housing_purchase');

      final result = await SequenceChatHandler.handleRealtimeReturn(
        const ScreenReturn.completed(
          route: '/hypotheque',
          runId: 'wrong_run_id',
          stepId: 'housing_01_affordability',
          eventId: 'evt_wrong_run',
        ),
      );
      expect(result, isNull);
    });

    test('stale stepId rejected after advance', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      // Complete step 1, advance to step 2
      await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_step1',
          stepOutputs: const {'capacite_achat': 850000.0},
        ),
      );

      // Stale event from step 1 arrives late
      final stale = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run.runId,
          stepId: 'housing_01_affordability', // stale — run is on step 2
          eventId: 'evt_step1_late',
        ),
      );
      expect(stale, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  TIER A vs TIER B
  // ════════════════════════════════════════════════════════════════

  group('E2E — Tier A vs Tier B', () {
    test('Tier A return (with IDs) is consumed by realtime handler', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      final result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_tier_a',
          stepOutputs: const {'capacite_achat': 850000.0},
        ),
      );

      expect(result, isNotNull);
      expect(result!.action, isA<AdvanceAction>());
    });

    test('Tier B return (no IDs) falls through realtime to fallback', () async {
      await SequenceChatHandler.startSequence('housing_purchase');

      // Tier B: no runId/stepId/eventId
      final result = await SequenceChatHandler.handleRealtimeReturn(
        const ScreenReturn.completed(
          route: '/hypotheque',
          // No runId, no stepId, no eventId — Tier B
        ),
      );

      // Tier B without IDs: handler loads run, but no stepId guard triggered
      // (ret.stepId is null). The handler still processes it as a generic
      // completion of the active step.
      expect(result, isNotNull);
    });

    test('fallback handleStepReturn works for Tier B', () async {
      await SequenceChatHandler.startSequence('simulator_3a');

      // Tier B fallback: only outcome, no rich ScreenReturn
      final result = await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.completed,
      );

      expect(result, isNotNull);
      expect(result!.action, isA<AdvanceAction>());
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  OUTPUT TRANSFER
  // ════════════════════════════════════════════════════════════════

  group('E2E — Output transfer across steps', () {
    test('step 1 outputs flow to step 2 prefill via outputMapping', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      final result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_output_transfer',
          stepOutputs: const {
            'capacite_achat': 900000.0,
            'fonds_propres_requis': 180000.0,
          },
        ),
      );

      expect(result, isNotNull);
      final advance = result!.action as AdvanceAction;
      // outputMapping: fonds_propres_requis → montant_necessaire
      expect(advance.prefill['montant_necessaire'], 180000.0);
      // outputMapping: capacite_achat → montant_bien_cible
      expect(advance.prefill['montant_bien_cible'], 900000.0);
    });

    test('outputs accumulate across 3 steps', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      // Step 1
      await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_accum_1',
          stepOutputs: const {
            'capacite_achat': 850000.0,
            'fonds_propres_requis': 170000.0,
          },
        ),
      );

      // Step 2
      await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/epl',
          runId: run.runId,
          stepId: 'housing_02_epl',
          eventId: 'evt_accum_2',
          stepOutputs: const {
            'montant_epl': 50000.0,
            'impact_rente': -200.0,
          },
        ),
      );

      // Step 3 → completion with all outputs
      final result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/fiscal',
          runId: run.runId,
          stepId: 'housing_03_fiscal',
          eventId: 'evt_accum_3',
          stepOutputs: const {'impot_retrait': 3200.0},
        ),
      );

      expect(result, isNotNull);
      expect(result!.action, isA<CompleteAction>());
      final complete = result.action as CompleteAction;
      expect(complete.allOutputs.length, 3);
      expect(complete.allOutputs['housing_01_affordability']!['capacite_achat'], 850000.0);
      expect(complete.allOutputs['housing_02_epl']!['montant_epl'], 50000.0);
      expect(complete.allOutputs['housing_03_fiscal']!['impot_retrait'], 3200.0);
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  ABANDON + RETRY + QUIT
  // ════════════════════════════════════════════════════════════════

  group('E2E — Abandon, retry, quit', () {
    test('abandon once → retry, abandon twice → pause', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      // First abandon → retry
      final retry = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.abandoned(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_abandon_1',
        ),
      );
      expect(retry, isNotNull);
      expect(retry!.action, isA<RetryAction>());

      // Second abandon → pause (proposal count = 2: 1 from start + 1 from retry)
      final pause = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.abandoned(
          route: '/hypotheque',
          runId: run.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_abandon_2',
        ),
      );
      expect(pause, isNotNull);
      expect(pause!.action, isA<PauseAction>());
    });

    test('quit clears everything', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');
      expect(await SequenceChatHandler.isSequenceActive(), isTrue);

      await SequenceChatHandler.quitSequence();

      expect(await SequenceChatHandler.isSequenceActive(), isFalse);
      final stored = await SequenceStore.load();
      expect(stored, isNull);

      // Proposals also cleared
      final capMem = await CapMemoryStore.load();
      expect(capMem.proposalCount(run!.runId, 'housing_01_affordability'), 0);
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  PERSISTENCE ROUND-TRIP
  // ════════════════════════════════════════════════════════════════

  group('E2E — Persistence survives reload', () {
    test('run state survives store round-trip mid-sequence', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      // Complete step 1
      await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_persist_1',
          stepOutputs: const {'capacite_achat': 850000.0},
        ),
      );

      // Simulate app reload — load from fresh SharedPreferences
      final reloaded = await SequenceStore.load();
      expect(reloaded, isNotNull);
      expect(reloaded!.runId, run.runId);
      expect(reloaded.stepStates['housing_01_affordability'], StepRunState.completed);
      expect(reloaded.activeStepId, 'housing_02_epl');
      expect(reloaded.stepOutputs['housing_01_affordability']!['capacite_achat'], 850000.0);
      expect(reloaded.isEventProcessed('evt_persist_1'), isTrue);
      expect(reloaded.isActive, isTrue);
    });
  });
}
