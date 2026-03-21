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
      final r = ScreenReturn(
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
      final r = ScreenReturn(
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
      final r = ScreenReturn(
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
      final r = ScreenReturn.completed(
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
      final r = ScreenReturn.abandoned(route: '/divorce');

      expect(r.outcome, ScreenOutcome.abandoned);
      expect(r.route, '/divorce');
      expect(r.updatedFields, isNull);
      expect(r.confidenceDelta, isNull);
      expect(r.nextCapSuggestion, isNull);
    });

    test('ScreenReturn.changedInputs sets correct outcome', () {
      final r = ScreenReturn.changedInputs(
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
      final r = ScreenReturn(route: '/budget', outcome: ScreenOutcome.abandoned);
      expect(r.hasUpdates, isFalse);
    });

    test('hasUpdates is false when updatedFields is empty', () {
      final r = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {},
      );
      expect(r.hasUpdates, isFalse);
    });

    test('hasUpdates is true when updatedFields has entries', () {
      final r = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        updatedFields: {'canton': 'VS'},
      );
      expect(r.hasUpdates, isTrue);
    });

    test('hasConfidenceDelta is false when confidenceDelta is null', () {
      final r = ScreenReturn(route: '/budget', outcome: ScreenOutcome.completed);
      expect(r.hasConfidenceDelta, isFalse);
    });

    test('hasConfidenceDelta is false when confidenceDelta is zero', () {
      final r = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        confidenceDelta: 0.0,
      );
      expect(r.hasConfidenceDelta, isFalse);
    });

    test('hasConfidenceDelta is true for non-zero delta', () {
      final r = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        confidenceDelta: -0.1,
      );
      expect(r.hasConfidenceDelta, isTrue);
    });

    test('hasNextCap is false when nextCapSuggestion is null', () {
      final r = ScreenReturn(route: '/budget', outcome: ScreenOutcome.completed);
      expect(r.hasNextCap, isFalse);
    });

    test('hasNextCap is false when nextCapSuggestion is empty string', () {
      final r = ScreenReturn(
        route: '/budget',
        outcome: ScreenOutcome.completed,
        nextCapSuggestion: '',
      );
      expect(r.hasNextCap, isFalse);
    });

    test('hasNextCap is true for non-empty suggestion', () {
      final r = ScreenReturn(
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
  });

  group('ScreenReturn — toString', () {
    test('includes route and outcome', () {
      final r = ScreenReturn(
        route: '/rente-vs-capital',
        outcome: ScreenOutcome.completed,
      );
      expect(r.toString(), contains('/rente-vs-capital'));
      expect(r.toString(), contains('completed'));
    });
  });
}
