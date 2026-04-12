// test/models/screen_return_test.dart
//
// Unit tests for ScreenReturn (ReturnContract).
// See docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §7

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/screen_return.dart';

void main() {
  group('ScreenOutcome', () {
    test('has exactly three values', () {
      expect(ScreenOutcome.values, hasLength(3));
      expect(ScreenOutcome.values, containsAll([
        ScreenOutcome.completed,
        ScreenOutcome.abandoned,
        ScreenOutcome.changedInputs,
      ]));
    });
  });

  group('ScreenReturn — construction', () {
    test('completed outcome with all fields', () {
      const r = ScreenReturn(
        route: '/rente-vs-capital',
        outcome: ScreenOutcome.completed,
        updatedFields: {'prevoyance.avoirLppTotal': 70377.0},
        confidenceDelta: 0.15,
        nextCapSuggestion: 'lpp_rachat',
      );

      expect(r.route, '/rente-vs-capital');
      expect(r.outcome, ScreenOutcome.completed);
      expect(r.updatedFields, {'prevoyance.avoirLppTotal': 70377.0});
      expect(r.confidenceDelta, 0.15);
      expect(r.nextCapSuggestion, 'lpp_rachat');
    });

    test('abandoned outcome with null optional fields', () {
      const r = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.abandoned,
      );

      expect(r.route, '/budget');
      expect(r.outcome, ScreenOutcome.abandoned);
      expect(r.updatedFields, isNull);
      expect(r.confidenceDelta, isNull);
      expect(r.nextCapSuggestion, isNull);
    });

    test('changedInputs outcome', () {
      const r = ScreenReturn(
        route: '/fiscal',
        outcome: ScreenOutcome.changedInputs,
        updatedFields: {'canton': 'GE', 'salaireBrutMensuel': 95000.0},
        confidenceDelta: -0.05,
      );

      expect(r.outcome, ScreenOutcome.changedInputs);
      expect(r.updatedFields!['canton'], 'GE');
      expect(r.confidenceDelta, -0.05);
    });
  });

  group('ScreenReturn — convenience constructors', () {
    test('ScreenReturn.completed sets correct outcome', () {
      const r = ScreenReturn.completed(
        route: '/3a-deep/staggered-withdrawal',
        updatedFields: {'prevoyance.avoir3aTotal': 32000.0},
        confidenceDelta: 0.1,
        nextCapSuggestion: 'objectif_3a',
      );

      expect(r.outcome, ScreenOutcome.completed);
      expect(r.route, '/3a-deep/staggered-withdrawal');
      expect(r.hasUpdates, isTrue);
      expect(r.hasConfidenceDelta, isTrue);
      expect(r.hasNextCap, isTrue);
    });

    test('ScreenReturn.abandoned sets correct outcome and all nulls', () {
      const r = ScreenReturn.abandoned(route: '/divorce');

      expect(r.outcome, ScreenOutcome.abandoned);
      expect(r.route, '/divorce');
      expect(r.updatedFields, isNull);
      expect(r.confidenceDelta, isNull);
      expect(r.nextCapSuggestion, isNull);
    });

    test('ScreenReturn.changedInputs sets correct outcome', () {
      const r = ScreenReturn.changedInputs(
        route: '/budget',
        updatedFields: {'salaireBrutMensuel': 80000.0},
        confidenceDelta: 0.0,
      );

      expect(r.outcome, ScreenOutcome.changedInputs);
      expect(r.hasUpdates, isTrue);
    });
  });

  group('ScreenReturn — computed properties', () {
    test('hasUpdates is false when updatedFields is null', () {
      const r = ScreenReturn(route: '/budget', outcome: ScreenOutcome.abandoned);
      expect(r.hasUpdates, isFalse);
    });

    test('hasUpdates is false when updatedFields is empty', () {
      const r = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {},
      );
      expect(r.hasUpdates, isFalse);
    });

    test('hasUpdates is true when updatedFields has entries', () {
      const r = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {'canton': 'VS'},
      );
      expect(r.hasUpdates, isTrue);
    });

    test('hasConfidenceDelta is false when confidenceDelta is null', () {
      const r = ScreenReturn(route: '/budget', outcome: ScreenOutcome.completed);
      expect(r.hasConfidenceDelta, isFalse);
    });

    test('hasConfidenceDelta is false when confidenceDelta is zero', () {
      const r = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        confidenceDelta: 0.0,
      );
      expect(r.hasConfidenceDelta, isFalse);
    });

    test('hasConfidenceDelta is true for non-zero delta', () {
      const r = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        confidenceDelta: -0.1,
      );
      expect(r.hasConfidenceDelta, isTrue);
    });

    test('hasNextCap is false when nextCapSuggestion is null', () {
      const r = ScreenReturn(route: '/budget', outcome: ScreenOutcome.completed);
      expect(r.hasNextCap, isFalse);
    });

    test('hasNextCap is false when nextCapSuggestion is empty string', () {
      const r = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        nextCapSuggestion: '',
      );
      expect(r.hasNextCap, isFalse);
    });

    test('hasNextCap is true for non-empty suggestion', () {
      const r = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        nextCapSuggestion: 'objectif_3a',
      );
      expect(r.hasNextCap, isTrue);
    });
  });

  group('ScreenReturn — equality', () {
    test('two identical returns are equal', () {
      const r1 = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        confidenceDelta: 0.2,
      );
      const r2 = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        confidenceDelta: 0.2,
      );
      expect(r1, equals(r2));
    });

    test('different routes are not equal', () {
      const r1 = ScreenReturn(route: '/budget', outcome: ScreenOutcome.completed);
      const r2 = ScreenReturn(route: '/fiscal', outcome: ScreenOutcome.completed);
      expect(r1, isNot(equals(r2)));
    });

    test('different outcomes are not equal', () {
      const r1 = ScreenReturn(route: '/budget', outcome: ScreenOutcome.completed);
      const r2 = ScreenReturn(route: '/budget', outcome: ScreenOutcome.abandoned);
      expect(r1, isNot(equals(r2)));
    });

    test('same updatedFields content are equal', () {
      const r1 = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {'canton': 'VS', 'salaireBrut': 122207.0},
      );
      const r2 = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {'canton': 'VS', 'salaireBrut': 122207.0},
      );
      expect(r1, equals(r2));
    });

    test('different updatedFields values are not equal', () {
      const r1 = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {'canton': 'VS'},
      );
      const r2 = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {'canton': 'GE'},
      );
      expect(r1, isNot(equals(r2)));
    });

    test('different updatedFields keys are not equal', () {
      const r1 = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {'canton': 'VS'},
      );
      const r2 = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {'salaireBrut': 'VS'},
      );
      expect(r1, isNot(equals(r2)));
    });

    test('null updatedFields vs non-null updatedFields are not equal', () {
      const r1 = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
      );
      const r2 = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {'canton': 'VS'},
      );
      expect(r1, isNot(equals(r2)));
    });

    test('both null updatedFields are equal', () {
      const r1 = ScreenReturn(route: '/budget', outcome: ScreenOutcome.completed);
      const r2 = ScreenReturn(route: '/budget', outcome: ScreenOutcome.completed);
      expect(r1, equals(r2));
    });

    test('hashCode is consistent with equality for same updatedFields', () {
      const r1 = ScreenReturn(
        route: '/rente-vs-capital',
        outcome: ScreenOutcome.completed,
        updatedFields: {'prevoyance.avoirLppTotal': 70377.0},
        confidenceDelta: 0.15,
      );
      const r2 = ScreenReturn(
        route: '/rente-vs-capital',
        outcome: ScreenOutcome.completed,
        updatedFields: {'prevoyance.avoirLppTotal': 70377.0},
        confidenceDelta: 0.15,
      );
      expect(r1 == r2, isTrue);
      expect(r1.hashCode, equals(r2.hashCode));
    });

    test('hashCode differs when updatedFields differ', () {
      const r1 = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {'canton': 'VS'},
      );
      const r2 = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {'canton': 'ZH'},
      );
      // Not strictly guaranteed by contract, but highly expected for these distinct values.
      expect(r1 == r2, isFalse);
    });
  });

  group('ScreenReturn — toString', () {
    test('includes route and outcome', () {
      const r = ScreenReturn(
        route: '/rente-vs-capital',
        outcome: ScreenOutcome.completed,
      );
      expect(r.toString(), contains('/rente-vs-capital'));
      expect(r.toString(), contains('completed'));
    });

    test('includes sequence IDs when present', () {
      const r = ScreenReturn(
        route: '/hypotheque',
        outcome: ScreenOutcome.completed,
        runId: 'run_123',
        stepId: 'housing_01',
        eventId: 'evt_abc',
      );
      expect(r.toString(), contains('run_123'));
      expect(r.toString(), contains('housing_01'));
      expect(r.toString(), contains('evt_abc'));
    });
  });

  // ── Phase 2: Sequence identity fields ──────────────────────────

  group('ScreenReturn — sequence identity', () {
    test('hasSequenceId true when runId and stepId non-empty', () {
      const r = ScreenReturn(
        route: '/hypotheque',
        outcome: ScreenOutcome.completed,
        runId: 'run_1',
        stepId: 'step_1',
      );
      expect(r.hasSequenceId, isTrue);
    });

    test('hasSequenceId false when runId null', () {
      const r = ScreenReturn(
        route: '/hypotheque',
        outcome: ScreenOutcome.completed,
        stepId: 'step_1',
      );
      expect(r.hasSequenceId, isFalse);
    });

    test('hasSequenceId false when stepId empty', () {
      const r = ScreenReturn(
        route: '/hypotheque',
        outcome: ScreenOutcome.completed,
        runId: 'run_1',
        stepId: '',
      );
      expect(r.hasSequenceId, isFalse);
    });

    test('hasSequenceId false when both null (Tier B)', () {
      const r = ScreenReturn(
        route: '/hypotheque',
        outcome: ScreenOutcome.completed,
      );
      expect(r.hasSequenceId, isFalse);
    });

    test('hasEventId true when eventId non-empty', () {
      const r = ScreenReturn(
        route: '/hypotheque',
        outcome: ScreenOutcome.completed,
        eventId: 'evt_123',
      );
      expect(r.hasEventId, isTrue);
    });

    test('hasEventId false when eventId null', () {
      const r = ScreenReturn(
        route: '/hypotheque',
        outcome: ScreenOutcome.completed,
      );
      expect(r.hasEventId, isFalse);
    });

    test('hasEventId false when eventId empty', () {
      const r = ScreenReturn(
        route: '/hypotheque',
        outcome: ScreenOutcome.completed,
        eventId: '',
      );
      expect(r.hasEventId, isFalse);
    });

    test('equality includes sequence fields', () {
      const a = ScreenReturn(
        route: '/hypotheque',
        outcome: ScreenOutcome.completed,
        runId: 'run_1',
        stepId: 'step_1',
        eventId: 'evt_1',
      );
      const b = ScreenReturn(
        route: '/hypotheque',
        outcome: ScreenOutcome.completed,
        runId: 'run_1',
        stepId: 'step_1',
        eventId: 'evt_1',
      );
      const c = ScreenReturn(
        route: '/hypotheque',
        outcome: ScreenOutcome.completed,
        runId: 'run_1',
        stepId: 'step_1',
        eventId: 'evt_2', // different eventId
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });

    test('equality treats null sequence fields as equal', () {
      const a = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
      );
      const b = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
      );
      expect(a, equals(b));
    });

    test('completed convenience constructor passes sequence fields', () {
      const r = ScreenReturn.completed(
        route: '/hypotheque',
        runId: 'run_1',
        stepId: 'step_1',
        eventId: 'evt_1',
        stepOutputs: {'capacite': 850000},
      );
      expect(r.runId, 'run_1');
      expect(r.stepId, 'step_1');
      expect(r.eventId, 'evt_1');
      expect(r.outcome, ScreenOutcome.completed);
    });

    test('abandoned convenience constructor passes sequence fields', () {
      const r = ScreenReturn.abandoned(
        route: '/hypotheque',
        runId: 'run_1',
        stepId: 'step_1',
        eventId: 'evt_2',
      );
      expect(r.runId, 'run_1');
      expect(r.stepId, 'step_1');
      expect(r.eventId, 'evt_2');
      expect(r.outcome, ScreenOutcome.abandoned);
    });

    test('changedInputs convenience constructor passes sequence fields', () {
      const r = ScreenReturn.changedInputs(
        route: '/hypotheque',
        updatedFields: {'canton': 'GE'},
        runId: 'run_1',
        stepId: 'step_1',
        eventId: 'evt_3',
      );
      expect(r.runId, 'run_1');
      expect(r.stepId, 'step_1');
      expect(r.eventId, 'evt_3');
      expect(r.outcome, ScreenOutcome.changedInputs);
    });
  });
}
