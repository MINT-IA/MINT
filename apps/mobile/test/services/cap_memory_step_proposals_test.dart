import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';

/// Tests for CapMemory.stepProposals — anti-loop tracking for guided sequences.
/// See RFC_AGENT_LOOP_STATEFUL.md §6.3.
void main() {
  group('CapMemory.stepProposals', () {
    test('proposalCount returns 0 for unknown step', () {
      const mem = CapMemory();
      expect(mem.proposalCount('run1', 'step_a'), 0);
    });

    test('incrementProposal increments count correctly', () {
      var mem = const CapMemory();
      mem = mem.incrementProposal('run1', 'step_a');
      expect(mem.proposalCount('run1', 'step_a'), 1);
      mem = mem.incrementProposal('run1', 'step_a');
      expect(mem.proposalCount('run1', 'step_a'), 2);
    });

    test('proposals are scoped to runId', () {
      var mem = const CapMemory();
      mem = mem.incrementProposal('run1', 'step_a');
      mem = mem.incrementProposal('run2', 'step_a');
      expect(mem.proposalCount('run1', 'step_a'), 1);
      expect(mem.proposalCount('run2', 'step_a'), 1);
    });

    test('clearProposalsForRun removes only that run', () {
      var mem = const CapMemory();
      mem = mem.incrementProposal('run1', 'step_a');
      mem = mem.incrementProposal('run1', 'step_b');
      mem = mem.incrementProposal('run2', 'step_a');
      mem = mem.clearProposalsForRun('run1');
      expect(mem.proposalCount('run1', 'step_a'), 0);
      expect(mem.proposalCount('run1', 'step_b'), 0);
      expect(mem.proposalCount('run2', 'step_a'), 1); // untouched
    });

    test('stepProposals survives toJson/fromJson round-trip', () {
      var mem = const CapMemory();
      mem = mem.incrementProposal('run1', 'housing_01');
      mem = mem.incrementProposal('run1', 'housing_01');
      mem = mem.incrementProposal('run1', 'housing_02');

      final json = mem.toJson();
      final restored = CapMemory.fromJson(json);

      expect(restored.proposalCount('run1', 'housing_01'), 2);
      expect(restored.proposalCount('run1', 'housing_02'), 1);
    });

    test('empty stepProposals not serialized to JSON', () {
      const mem = CapMemory();
      final json = mem.toJson();
      expect(json.containsKey('stepProposals'), isFalse);
    });

    test('existing CapMemory without stepProposals deserializes safely', () {
      // Simulates loading prefs from before this field existed
      final legacyJson = <String, dynamic>{
        'completedActions': ['visited_lpp'],
        'abandonedFlows': [],
        'declaredGoals': [],
      };
      final mem = CapMemory.fromJson(legacyJson);
      expect(mem.stepProposals, isEmpty);
      expect(mem.proposalCount('any', 'any'), 0);
      expect(mem.completedActions, ['visited_lpp']); // existing data intact
    });

    test('incrementProposal preserves other CapMemory fields', () {
      const mem = CapMemory(
        lastCapServed: 'debt_correct',
        completedActions: ['visited_lpp'],
        declaredGoals: ['retraite'],
        recentFrictionContext: 'budget_stress',
      );
      final updated = mem.incrementProposal('run1', 'step_a');
      expect(updated.lastCapServed, 'debt_correct');
      expect(updated.completedActions, ['visited_lpp']);
      expect(updated.declaredGoals, ['retraite']);
      expect(updated.recentFrictionContext, 'budget_stress');
      expect(updated.proposalCount('run1', 'step_a'), 1);
    });
  });
}
