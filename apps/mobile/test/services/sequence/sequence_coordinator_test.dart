import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/models/sequence_run.dart';
import 'package:mint_mobile/models/sequence_template.dart';
import 'package:mint_mobile/services/sequence/sequence_coordinator.dart';

void main() {
  // ── Helpers ────────────────────────────────────────────────────

  SequenceRun _startRun(SequenceTemplate template) {
    return SequenceRun.start(
      runId: 'test-run-1',
      templateId: template.id,
      stepIds: template.steps.map((s) => s.id).toList(),
    );
  }

  // ── Template mapping ──────────────────────────────────────────

  group('SequenceTemplate.templateForIntent', () {
    test('housing_purchase returns housing template', () {
      final t = SequenceTemplate.templateForIntent('housing_purchase');
      expect(t, isNotNull);
      expect(t!.id, 'housing_purchase');
      expect(t.steps.length, 4);
    });

    test('retirement_projection returns retirement template', () {
      final t = SequenceTemplate.templateForIntent('retirement_projection');
      expect(t, isNotNull);
      expect(t!.id, 'retirement_prep');
    });

    test('retirement_choice returns retirement template', () {
      final t = SequenceTemplate.templateForIntent('retirement_choice');
      expect(t!.id, 'retirement_prep');
    });

    test('simulator_3a returns 3a template', () {
      final t = SequenceTemplate.templateForIntent('simulator_3a');
      expect(t, isNotNull);
      expect(t!.id, 'optimize_3a');
    });

    test('unknown intent returns null', () {
      expect(SequenceTemplate.templateForIntent('unknown_intent'), isNull);
      expect(SequenceTemplate.templateForIntent('budget_overview'), isNull);
    });
  });

  // ── SequenceRun lifecycle ─────────────────────────────────────

  group('SequenceRun', () {
    test('start creates run with first step active', () {
      final run = _startRun(SequenceTemplate.housingPurchase);
      expect(run.isActive, isTrue);
      expect(run.activeStepId, 'housing_01_affordability');
      expect(run.completedCount, 0);
      expect(run.totalCount, 4);
      expect(run.progress, 0.0);
    });

    test('completeStep marks step done and stores outputs', () {
      var run = _startRun(SequenceTemplate.housingPurchase);
      run = run.completeStep('housing_01_affordability', {
        'capacite_achat': 850000,
        'fonds_propres_requis': 170000,
      });
      expect(run.stepStates['housing_01_affordability'], StepRunState.completed);
      expect(run.stepOutputs['housing_01_affordability']!['capacite_achat'], 850000);
      expect(run.completedCount, 1);
    });

    test('skipStep marks step skipped', () {
      var run = _startRun(SequenceTemplate.retirementPrep);
      run = run.skipStep('ret_03_buyback');
      expect(run.stepStates['ret_03_buyback'], StepRunState.skipped);
      expect(run.completedCount, 1); // skipped counts as completed
    });

    test('activateStep deactivates previous active', () {
      var run = _startRun(SequenceTemplate.housingPurchase);
      expect(run.activeStepId, 'housing_01_affordability');
      run = run.activateStep('housing_02_epl');
      expect(run.activeStepId, 'housing_02_epl');
      expect(run.stepStates['housing_01_affordability'], StepRunState.pending);
    });

    test('invalidateSteps resets steps to pending and removes outputs', () {
      var run = _startRun(SequenceTemplate.housingPurchase);
      run = run.completeStep('housing_01_affordability', {'x': 1});
      run = run.invalidateSteps(['housing_01_affordability']);
      expect(run.stepStates['housing_01_affordability'], StepRunState.pending);
      expect(run.stepOutputs.containsKey('housing_01_affordability'), isFalse);
    });

    test('progress is computed correctly', () {
      var run = _startRun(SequenceTemplate.optimize3a);
      expect(run.progress, 0.0);
      run = run.completeStep('3a_01_simulator', {});
      expect(run.progress, closeTo(0.333, 0.01));
      run = run.completeStep('3a_02_withdrawal', {});
      expect(run.progress, closeTo(0.667, 0.01));
      run = run.completeStep('3a_03_real_return', {});
      expect(run.progress, 1.0);
    });
  });

  // ── Serialization ─────────────────────────────────────────────

  group('SequenceRun serialization', () {
    test('round-trip serialize/deserialize preserves all data', () {
      var run = _startRun(SequenceTemplate.housingPurchase);
      run = run.completeStep('housing_01_affordability', {
        'capacite_achat': 850000.0,
        'fonds_propres_requis': 170000,
      });
      run = run.activateStep('housing_02_epl');

      final serialized = run.serialize();
      final deserialized = SequenceRun.deserialize(serialized);

      expect(deserialized, isNotNull);
      expect(deserialized!.runId, run.runId);
      expect(deserialized.templateId, run.templateId);
      expect(deserialized.activeStepId, 'housing_02_epl');
      expect(deserialized.stepStates['housing_01_affordability'],
          StepRunState.completed);
      expect(deserialized.stepOutputs['housing_01_affordability']!['capacite_achat'],
          850000.0);
      expect(deserialized.status, SequenceRunStatus.active);
    });

    test('deserialize returns null for invalid JSON', () {
      expect(SequenceRun.deserialize(null), isNull);
      expect(SequenceRun.deserialize(''), isNull);
      expect(SequenceRun.deserialize('not json'), isNull);
    });
  });

  // ── SequenceCoordinator decisions ─────────────────────────────

  group('SequenceCoordinator.decide', () {
    test('completed step → advance to next', () {
      final template = SequenceTemplate.housingPurchase;
      final run = _startRun(template);

      final action = SequenceCoordinator.decide(
        template: template,
        run: run,
        stepReturn: const ScreenReturn.completed(
          route: '/hypotheque',
          stepOutputs: {
            'capacite_achat': 850000,
            'fonds_propres_requis': 170000,
          },
        ),
        proposalCount: 1,
      );

      expect(action, isA<AdvanceAction>());
      final advance = action as AdvanceAction;
      expect(advance.nextStep.id, 'housing_02_epl');
      expect(advance.prefill['montant_necessaire'], 170000);
      expect(advance.progressLabel, '1/4');
    });

    test('all steps completed → complete action', () {
      final template = SequenceTemplate.optimize3a;
      var run = _startRun(template);
      run = run.completeStep('3a_01_simulator', {'contribution_annuelle': 7258});
      run = run.completeStep('3a_02_withdrawal', {'gain_echelonnement': 12000});
      run = run.activateStep('3a_03_real_return');

      final action = SequenceCoordinator.decide(
        template: template,
        run: run,
        stepReturn: const ScreenReturn.completed(
          route: '/3a-deep/real-return',
          stepOutputs: {'rendement_net': 2.1},
        ),
        proposalCount: 1,
      );

      expect(action, isA<CompleteAction>());
    });

    test('abandoned once → retry', () {
      final template = SequenceTemplate.housingPurchase;
      final run = _startRun(template);

      final action = SequenceCoordinator.decide(
        template: template,
        run: run,
        stepReturn: const ScreenReturn.abandoned(route: '/hypotheque'),
        proposalCount: 1,
      );

      expect(action, isA<RetryAction>());
      expect((action as RetryAction).stepId, 'housing_01_affordability');
    });

    test('abandoned twice on optional step → skip', () {
      final template = SequenceTemplate.housingPurchase;
      // Step 4 (summary) is optional
      var run = _startRun(template);
      run = run.completeStep('housing_01_affordability', {});
      run = run.completeStep('housing_02_epl', {});
      run = run.completeStep('housing_03_fiscal', {});
      run = run.activateStep('housing_04_summary');

      final action = SequenceCoordinator.decide(
        template: template,
        run: run,
        stepReturn: const ScreenReturn.abandoned(route: '/inline'),
        proposalCount: 2,
      );

      expect(action, isA<SkipAction>());
    });

    test('abandoned twice on required step → pause', () {
      final template = SequenceTemplate.housingPurchase;
      final run = _startRun(template);

      final action = SequenceCoordinator.decide(
        template: template,
        run: run,
        stepReturn: const ScreenReturn.abandoned(route: '/hypotheque'),
        proposalCount: 2,
      );

      expect(action, isA<PauseAction>());
      expect((action as PauseAction).canResume, isTrue);
    });

    test('changed inputs → re-evaluate all completed steps with outputs', () {
      final template = SequenceTemplate.housingPurchase;
      var run = _startRun(template);
      run = run.completeStep('housing_01_affordability', {
        'capacite_achat': 850000,
      });
      run = run.activateStep('housing_02_epl');

      // V1: any profile change conservatively invalidates all completed steps
      // that have outputs, because we don't have reverse dependency mapping.
      final action = SequenceCoordinator.decide(
        template: template,
        run: run,
        stepReturn: const ScreenReturn.changedInputs(
          route: '/epl',
          updatedFields: {'prevoyance.avoirLppTotal': 300000},
        ),
        proposalCount: 1,
      );

      expect(action, isA<ReEvaluateAction>());
      // Step 1 had outputs → invalidated
      expect((action as ReEvaluateAction).invalidatedStepIds,
          contains('housing_01_affordability'));
    });

    test('changed inputs with no completed outputs → pause', () {
      final template = SequenceTemplate.housingPurchase;
      final run = _startRun(template);

      final action = SequenceCoordinator.decide(
        template: template,
        run: run,
        stepReturn: const ScreenReturn.changedInputs(
          route: '/hypotheque',
          updatedFields: {'canton': 'GE'},
        ),
        proposalCount: 1,
      );

      // No completed step has outputs → just pause
      expect(action, isA<PauseAction>());
    });

    test('no active step → pause', () {
      final template = SequenceTemplate.housingPurchase;
      final run = SequenceRun(
        runId: 'test',
        templateId: template.id,
        startedAt: DateTime.now(),
        stepStates: {for (final s in template.steps) s.id: StepRunState.pending},
      );

      final action = SequenceCoordinator.decide(
        template: template,
        run: run,
        stepReturn: const ScreenReturn.completed(route: '/hypotheque'),
        proposalCount: 0,
      );

      expect(action, isA<PauseAction>());
    });
  });

  // ── Prefill building ──────────────────────────────────────────

  group('Output transfer (prefill)', () {
    test('step 1 outputs flow to step 2 via outputMapping', () {
      final template = SequenceTemplate.housingPurchase;
      var run = _startRun(template);
      run = run.completeStep('housing_01_affordability', {
        'capacite_achat': 850000,
        'fonds_propres_requis': 170000,
      });
      run = run.activateStep('housing_02_epl');

      final action = SequenceCoordinator.decide(
        template: template,
        run: run.activateStep('housing_01_affordability'), // re-activate for test
        stepReturn: const ScreenReturn.completed(
          route: '/hypotheque',
          stepOutputs: {
            'capacite_achat': 900000,
            'fonds_propres_requis': 180000,
          },
        ),
        proposalCount: 1,
      );

      expect(action, isA<AdvanceAction>());
      final advance = action as AdvanceAction;
      // outputMapping: fonds_propres_requis → montant_necessaire
      expect(advance.prefill['montant_necessaire'], 180000);
    });

    test('outputs accumulate across multiple steps', () {
      final template = SequenceTemplate.housingPurchase;
      var run = _startRun(template);
      // Complete step 1
      run = run.completeStep('housing_01_affordability', {
        'capacite_achat': 850000,
        'fonds_propres_requis': 170000,
      });
      // Complete step 2
      run = run.completeStep('housing_02_epl', {
        'montant_epl': 50000,
        'impact_rente': -200,
      });
      run = run.activateStep('housing_03_fiscal');

      final action = SequenceCoordinator.decide(
        template: template,
        run: run,
        stepReturn: const ScreenReturn.completed(
          route: '/fiscal',
          stepOutputs: {'impot_retrait': 3200},
        ),
        proposalCount: 1,
      );

      // All 3 real steps done (step 4 is inline summary) → complete
      expect(action, isA<CompleteAction>());
      final complete = action as CompleteAction;
      // Outputs from step 1 and step 2 are accumulated
      expect(complete.allOutputs.containsKey('housing_01_affordability'), isTrue);
      expect(complete.allOutputs.containsKey('housing_02_epl'), isTrue);
    });
  });

  // ── Output sanitization ───────────────────────────────────────

  group('Output sanitization', () {
    test('completeStep truncates long strings', () {
      var run = _startRun(SequenceTemplate.housingPurchase);
      final longString = 'x' * 300;
      run = run.completeStep('housing_01_affordability', {
        'label': longString,
      });
      final outputs = run.stepOutputs['housing_01_affordability']!;
      expect((outputs['label'] as String).length, 200); // Truncated to 200
    });

    test('completeStep drops outputs exceeding per-step size budget', () {
      var run = _startRun(SequenceTemplate.housingPurchase);
      // Create outputs that exceed 2KB per step
      final bigOutputs = <String, dynamic>{};
      for (int i = 0; i < 50; i++) {
        bigOutputs['key_$i'] = 'x' * 200; // ~50 × 200 = 10KB+ JSON
      }
      run = run.completeStep('housing_01_affordability', bigOutputs);
      // Per-step sanitization returns empty → not stored
      expect(run.stepOutputs.containsKey('housing_01_affordability'), isFalse);
    });

    test('completeStep filters non-primitive values', () {
      var run = _startRun(SequenceTemplate.housingPurchase);
      run = run.completeStep('housing_01_affordability', {
        'capacite_achat': 850000.0,        // double — kept
        'count': 3,                         // int — kept
        'label': 'test',                    // String — kept
        'flag': true,                       // bool — kept
        'nested': {'a': 1},                 // Map — dropped
        'list': [1, 2, 3],                  // List — dropped
      });

      final outputs = run.stepOutputs['housing_01_affordability']!;
      expect(outputs['capacite_achat'], 850000.0);
      expect(outputs['count'], 3);
      expect(outputs['label'], 'test');
      expect(outputs['flag'], true);
      expect(outputs.containsKey('nested'), isFalse);
      expect(outputs.containsKey('list'), isFalse);
    });
  });

  // ── Blocked step handling ─────────────────────────────────────

  group('Blocked steps', () {
    test('blocked step causes pause (never silently skipped)', () {
      final template = SequenceTemplate.housingPurchase;
      var run = _startRun(template);
      // Block step 2
      final states = Map<String, StepRunState>.from(run.stepStates);
      states['housing_02_epl'] = StepRunState.blocked;
      run = SequenceRun(
        runId: run.runId,
        templateId: run.templateId,
        startedAt: run.startedAt,
        stepStates: states,
      );

      final action = SequenceCoordinator.decide(
        template: template,
        run: run,
        stepReturn: const ScreenReturn.completed(
          route: '/hypotheque',
          stepOutputs: {'capacite_achat': 850000},
        ),
        proposalCount: 1,
      );

      // Blocked step → pause sequence, user must resolve blocker
      expect(action, isA<PauseAction>());
      expect((action as PauseAction).canResume, isTrue);
    });
  });
}
