// Service-level integration tests for the guided sequence orchestration chain.
//
// These tests prove the handler + coordinator + store chain works together.
// They exercise: startSequence → handleRealtimeReturn → coordinator →
// store → required-output validation → dedup → completion.
//
// NOTE: These are NOT widget-level E2E tests. They do not cover:
// - CoachChatScreen._onRealtimeScreenReturn / _handleRouteReturnAsync
// - RouteSuggestionCard navigation with GoRouter.extra
// - ScreenCompletionTracker stream emission
// - AffordabilityScreen Tier A PopScope emission
// Widget-level E2E tests require a GoRouter mock + mounted CoachChatScreen.
//
// See: docs/RFC_AGENT_LOOP_STATEFUL.md, docs/SEQUENCE_PHASE2_COMPLETION_PLAN.md

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/models/scenario_session.dart';
import 'package:mint_mobile/models/sequence_run.dart';
import 'package:mint_mobile/providers/scenario_session_provider.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/scenario/scenario_session_store.dart';
import 'package:mint_mobile/services/sequence/sequence_chat_handler.dart';
import 'package:mint_mobile/services/sequence/sequence_coordinator.dart';
import 'package:mint_mobile/services/sequence/sequence_store.dart';

final class _MemoryScenarioCache implements ScenarioSessionCache {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

void main() {
  const eplId = '11111111-1111-4111-8111-111111111111';
  late ScenarioSessionProvider scenarioProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FeatureFlags.enableGuidedSequences = true;
    scenarioProvider = ScenarioSessionProvider(
      enabled: true,
      store: ScenarioSessionStore(
        cache: _MemoryScenarioCache(),
        idFactory: () => eplId,
        clock: () => DateTime.utc(2026, 7, 19, 12),
      ),
    );
    addTearDown(() => FeatureFlags.enableGuidedSequences = false);
  });

  Future<void> createCompletedEpl() async {
    await scenarioProvider.open(
      const EplScenarioLevers(requestedWithdrawal: 50000),
      factsReady: true,
    );
    await scenarioProvider.markCalculated(
      eplId,
      expectedKind: ScenarioKind.epl,
    );
    await scenarioProvider.markTerminal(
      eplId,
      expectedKind: ScenarioKind.epl,
      status: ScenarioStatus.completed,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  FULL MULTI-STEP E2E FLOW
  // ════════════════════════════════════════════════════════════════

  group('Service integration — Housing purchase sequence (4 steps)', () {
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

      // Verify step 2 proposal tracked
      capMem = await CapMemoryStore.load();
      expect(capMem.proposalCount(run.runId, 'housing_02_epl'), 1);

      // Verify eventId was recorded
      final runAfterStep1 = await SequenceStore.load();
      expect(runAfterStep1!.isEventProcessed('evt_step1_${run.runId}'), isTrue);

      // ── STEP 2: /epl (Tier A) ─────────────────────────────────
      await createCompletedEpl();
      final step2Result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/epl',
          runId: run.runId,
          stepId: 'housing_02_epl',
          eventId: 'evt_step2_${run.runId}',
          scenarioId: eplId,
          scenarioStatus: ScenarioStatus.completed,
        ),
        scenarioValidator: scenarioProvider.validatesCompleted,
      );

      expect(step2Result, isNotNull);
      expect(step2Result!.action, isA<AdvanceAction>());
      final advance2 = step2Result.action as AdvanceAction;
      expect(advance2.nextStep.id, 'housing_03_fiscal');
      expect(
        step2Result.updatedRun.scenarioReferences['housing_02_epl']?.id,
        eplId,
      );
      expect(
        step2Result.updatedRun.stepOutputs,
        isNot(contains('housing_02_epl')),
      );

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
      expect(complete.allOutputs.containsKey('housing_02_epl'), isFalse);
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

  group('Service integration — Dedup chain', () {
    test('same eventId rejected on second call', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      final first = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_dedup_test',
          stepOutputs: const {
            'capacite_achat': 850000.0,
            'fonds_propres_requis': 170000.0,
          },
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
          stepOutputs: const {
            'capacite_achat': 850000.0,
            'fonds_propres_requis': 170000.0,
          },
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

  group('Service integration — Tier A vs Tier B', () {
    test('Tier A return (with IDs) consumed by realtime handler', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      final result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_tier_a',
          stepOutputs: const {
            'capacite_achat': 850000.0,
            'fonds_propres_requis': 170000.0,
          },
        ),
      );

      expect(result, isNotNull);
      expect(result!.action, isA<AdvanceAction>());
    });

    test('Tier B return (no IDs) NOT consumed by realtime handler in chat runtime', () async {
      // In the real chat runtime, _onRealtimeScreenReturn checks
      // ret.hasSequenceId BEFORE calling handleRealtimeReturn.
      // A Tier B return (no IDs) does NOT reach the handler — it goes
      // through the debounce/route-return fallback path instead.
      //
      // This test verifies the contract: hasSequenceId is the gate.
      const tierBReturn = ScreenReturn.completed(
        route: '/hypotheque',
        // No runId, no stepId, no eventId — Tier B
      );
      expect(tierBReturn.hasSequenceId, isFalse);
      // In the chat: if (!ret.hasSequenceId) → debounce path, not handler.
    });

    test('Tier B fallback pauses when required outputs are absent', () async {
      await SequenceChatHandler.startSequence('simulator_3a');

      // Tier B fallback path: _handleRouteReturnAsync calls handleStepReturn
      // with just a ScreenOutcome (no rich ScreenReturn).
      final result = await SequenceChatHandler.handleStepReturn(
        ScreenOutcome.completed,
      );

      expect(result, isNotNull);
      expect(result!.action, isA<PauseAction>());
      expect((result.action as PauseAction).canResume, isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  OUTPUT ISOLATION
  // ════════════════════════════════════════════════════════════════

  group('Service integration — Output isolation across steps', () {
    test('step outputs stay in the run while action carries navigation', () async {
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
      expect(advance.nextStep.id, 'housing_02_epl');
      expect(advance.route, isNotEmpty);
      expect(
        result.updatedRun.stepOutputs['housing_01_affordability'],
        containsPair('capacite_achat', 900000.0),
      );
    });

    test('legacy outputs accumulate while scenario stays opaque', () async {
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
      await createCompletedEpl();
      final scenarioResult = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/epl',
          runId: run.runId,
          stepId: 'housing_02_epl',
          eventId: 'evt_accum_2',
          scenarioId: eplId,
          scenarioStatus: ScenarioStatus.completed,
        ),
        scenarioValidator: scenarioProvider.validatesCompleted,
      );
      expect(
        scenarioResult?.updatedRun.scenarioReferences['housing_02_epl']?.id,
        eplId,
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
      expect(complete.allOutputs.length, 2);
      expect(complete.allOutputs['housing_01_affordability']!['capacite_achat'], 850000.0);
      expect(complete.allOutputs, isNot(contains('housing_02_epl')));
      expect(complete.allOutputs['housing_03_fiscal']!['impot_retrait'], 3200.0);
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  ABANDON + RETRY + QUIT
  // ════════════════════════════════════════════════════════════════

  group('Service integration — Abandon, retry, quit', () {
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

  group('Service integration — Persistence survives reload', () {
    test('run state survives store round-trip mid-sequence', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      // Complete step 1
      await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_persist_1',
          stepOutputs: const {
            'capacite_achat': 850000.0,
            'fonds_propres_requis': 170000.0,
          },
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

  // ════════════════════════════════════════════════════════════════
  //  ADVANCE ACTION DATA COMPLETENESS
  // ════════════════════════════════════════════════════════════════

  group('Service integration — AdvanceAction carries navigation data', () {
    test('AdvanceAction has route resolved from ScreenRegistry', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      final result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_nav_data',
          stepOutputs: const {
            'capacite_achat': 850000.0,
            'fonds_propres_requis': 170000.0,
          },
        ),
      );

      expect(result, isNotNull);
      final advance = result!.action as AdvanceAction;

      // Route must be a real GoRouter path (resolved from ScreenRegistry)
      expect(advance.route, isNotEmpty);
      expect(advance.route, startsWith('/'));

      // nextStep must carry the step definition
      expect(advance.nextStep.id, 'housing_02_epl');
      expect(advance.nextStep.intentTag, 'early_pension_withdrawal');
    });

    test('run carries correct runId for navigation extra', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      final result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_runid',
          stepOutputs: const {
            'capacite_achat': 850000.0,
            'fonds_propres_requis': 170000.0,
          },
        ),
      );

      // The updated run in the result carries the same runId
      expect(result!.updatedRun.runId, run.runId);
      // The next active step matches the AdvanceAction
      final advance = result.action as AdvanceAction;
      expect(result.updatedRun.activeStepId, advance.nextStep.id);
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  ABANDONED-ON-NO-INTERACTION (stuck sequence bug fix)
  // ════════════════════════════════════════════════════════════════

  group('Service integration — Abandoned emits retry, not stuck', () {
    test('abandoned ScreenReturn on step 1 triggers RetryAction', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      // User opened affordability screen but popped without interacting.
      // Screen emits ScreenReturn.abandoned() with sequence IDs.
      final result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.abandoned(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_no_interaction_1',
        ),
      );

      expect(result, isNotNull);
      // First abandon → retry (not pause, not stuck)
      expect(result!.action, isA<RetryAction>());
    });

    test('abandoned on step 2 (EPL) triggers RetryAction', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      // Complete step 1 first
      await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.completed(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_step1_ok',
          stepOutputs: const {
            'capacite_achat': 850000.0,
            'fonds_propres_requis': 170000.0,
          },
        ),
      );

      // User opened EPL screen but popped without interacting.
      final result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.abandoned(
          route: '/epl',
          runId: run.runId,
          stepId: 'housing_02_epl',
          eventId: 'evt_no_interaction_epl',
        ),
      );

      expect(result, isNotNull);
      expect(result!.action, isA<RetryAction>());
    });

    test('double abandoned on same step → pause (not infinite loop)', () async {
      final run = await SequenceChatHandler.startSequence('housing_purchase');

      // First abandon → retry
      await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.abandoned(
          route: '/hypotheque',
          runId: run!.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_abandon_1',
        ),
      );

      // Second abandon → pause (anti-loop)
      final result = await SequenceChatHandler.handleRealtimeReturn(
        ScreenReturn.abandoned(
          route: '/hypotheque',
          runId: run.runId,
          stepId: 'housing_01_affordability',
          eventId: 'evt_abandon_2',
        ),
      );

      expect(result, isNotNull);
      expect(result!.action, isA<PauseAction>());
    });
  });
}
