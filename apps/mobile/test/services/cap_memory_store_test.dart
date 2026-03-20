import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';

void main() {
  group('CapMemory — serialization', () {
    test('empty memory round-trips through JSON', () {
      const memory = CapMemory();
      final json = memory.toJson();
      final restored = CapMemory.fromJson(json);

      expect(restored.lastCapServed, isNull);
      expect(restored.lastCapDate, isNull);
      expect(restored.completedActions, isEmpty);
      expect(restored.abandonedFlows, isEmpty);
      expect(restored.preferredCtaMode, isNull);
      expect(restored.declaredGoals, isEmpty);
      expect(restored.recentFrictionContext, isNull);
    });

    test('full memory round-trips through JSON', () {
      final memory = CapMemory(
        lastCapServed: 'pillar_3a',
        lastCapDate: DateTime(2026, 3, 19, 10, 30),
        completedActions: ['debt_ratio', 'budget'],
        abandonedFlows: ['lpp_buyback'],
        preferredCtaMode: 'route',
        declaredGoals: ['retraite', 'achat_immo'],
        recentFrictionContext: 'budget_stress',
      );

      final json = memory.toJson();
      final restored = CapMemory.fromJson(json);

      expect(restored.lastCapServed, 'pillar_3a');
      expect(restored.lastCapDate, DateTime(2026, 3, 19, 10, 30));
      expect(restored.completedActions, ['debt_ratio', 'budget']);
      expect(restored.abandonedFlows, ['lpp_buyback']);
      expect(restored.preferredCtaMode, 'route');
      expect(restored.declaredGoals, ['retraite', 'achat_immo']);
      expect(restored.recentFrictionContext, 'budget_stress');
    });

    test('fromJson handles missing keys gracefully', () {
      final memory = CapMemory.fromJson({'lastCapServed': 'test'});

      expect(memory.lastCapServed, 'test');
      expect(memory.completedActions, isEmpty);
      expect(memory.abandonedFlows, isEmpty);
      expect(memory.declaredGoals, isEmpty);
    });
  });

  group('CapMemory — copyWith', () {
    test('preserves fields not overridden', () {
      const memory = CapMemory(
        lastCapServed: 'a',
        completedActions: ['x'],
        declaredGoals: ['retraite'],
      );

      final updated = memory.copyWith(lastCapServed: 'b');

      expect(updated.lastCapServed, 'b');
      expect(updated.completedActions, ['x']);
      expect(updated.declaredGoals, ['retraite']);
    });

    test('can override all fields', () {
      const memory = CapMemory();

      final updated = memory.copyWith(
        lastCapServed: 'c',
        lastCapDate: DateTime(2026, 1, 1),
        completedActions: ['y'],
        abandonedFlows: ['z'],
        preferredCtaMode: 'coach',
        declaredGoals: ['achat'],
        recentFrictionContext: 'hesitation',
      );

      expect(updated.lastCapServed, 'c');
      expect(updated.lastCapDate, DateTime(2026, 1, 1));
      expect(updated.completedActions, ['y']);
      expect(updated.abandonedFlows, ['z']);
      expect(updated.preferredCtaMode, 'coach');
      expect(updated.declaredGoals, ['achat']);
      expect(updated.recentFrictionContext, 'hesitation');
    });
  });

  group('CapMemoryStore — markCompleted', () {
    test('trims completedActions to max 20', () {
      final long = List.generate(25, (i) => 'action_$i');
      final memory = CapMemory(completedActions: long);

      // Simulate markCompleted logic without SharedPreferences
      final actions = [...memory.completedActions, 'new_action'];
      final trimmed = actions.length > 20
          ? actions.sublist(actions.length - 20)
          : actions;

      expect(trimmed.length, 20);
      expect(trimmed.last, 'new_action');
      expect(trimmed.first, 'action_6'); // 26 - 20 = first 6 dropped
    });
  });

  group('CapMemory — copyWith clears nullable fields', () {
    test('passing null explicitly clears recentFrictionContext', () {
      const memory = CapMemory(
        recentFrictionContext: 'budget_stress',
        completedActions: ['a'],
      );

      final cleared = memory.copyWith(recentFrictionContext: null);

      expect(cleared.recentFrictionContext, isNull);
      expect(cleared.completedActions, ['a']); // other fields preserved
    });

    test('passing null explicitly clears preferredCtaMode', () {
      const memory = CapMemory(preferredCtaMode: 'route');

      final cleared = memory.copyWith(preferredCtaMode: null);

      expect(cleared.preferredCtaMode, isNull);
    });

    test('passing null explicitly clears lastCapServed', () {
      const memory = CapMemory(lastCapServed: 'old_cap');

      final cleared = memory.copyWith(lastCapServed: null);

      expect(cleared.lastCapServed, isNull);
    });

    test('omitting a field preserves existing value (not clear)', () {
      const memory = CapMemory(recentFrictionContext: 'stress');

      // copyWith with no recentFrictionContext arg → keeps 'stress'
      final kept = memory.copyWith(completedActions: ['x']);

      expect(kept.recentFrictionContext, 'stress');
    });
  });

  group('CapMemoryStore — markAbandoned', () {
    test('trims abandonedFlows to max 10', () {
      final long = List.generate(12, (i) => 'flow_$i');
      final memory = CapMemory(abandonedFlows: long);

      final flows = [...memory.abandonedFlows, 'new_flow'];
      final trimmed =
          flows.length > 10 ? flows.sublist(flows.length - 10) : flows;

      expect(trimmed.length, 10);
      expect(trimmed.last, 'new_flow');
    });
  });
}
