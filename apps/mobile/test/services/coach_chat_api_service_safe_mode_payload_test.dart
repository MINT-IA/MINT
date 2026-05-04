/// Tests that has_debt is correctly forwarded through the CoachContext pipeline
/// and into the profileContext payload that reaches the backend.
///
/// Scope: CoachContextBuilder → CoachContext.hasDebt field contract.
/// The orchestrator builders pick up ctx.hasDebt and inject it as
/// profileContext['has_debt'] — verified here at the builder level.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/coach_context_builder.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';

void main() {
  group('CoachContext.hasDebt — payload contract', () {
    test('hasDebt defaults to false when not passed', () {
      final ctx = CoachContextBuilder.build(firstName: 'Julien', age: 49);
      expect(ctx.hasDebt, isFalse);
    });

    test('hasDebt: true is forwarded into context', () {
      final ctx = CoachContextBuilder.build(
        firstName: 'Lauren',
        age: 43,
        hasDebt: true,
      );
      expect(ctx.hasDebt, isTrue);
    });

    test('hasDebt: false is forwarded into context', () {
      final ctx = CoachContextBuilder.build(
        firstName: 'Julien',
        age: 49,
        hasDebt: false,
      );
      expect(ctx.hasDebt, isFalse);
    });

    test('copyWith preserves hasDebt when not overridden', () {
      final ctx = CoachContextBuilder.build(
        firstName: 'Test',
        age: 35,
        hasDebt: true,
      );
      final copy = ctx.copyWith(fiscalSeason: 'tax_declaration');
      expect(copy.hasDebt, isTrue);
    });

    test('copyWith overrides hasDebt when provided', () {
      final ctx = CoachContextBuilder.build(
        firstName: 'Test',
        age: 35,
        hasDebt: true,
      );
      final copy = ctx.copyWith(hasDebt: false);
      expect(copy.hasDebt, isFalse);
    });

    test('hasDebt does not affect knownValues (compliance: never in grounding map)', () {
      final ctx = CoachContextBuilder.build(
        firstName: 'Test',
        age: 35,
        hasDebt: true,
        friTotal: 55,
      );
      // hasDebt is a boolean flag — must NOT appear in knownValues (numeric map)
      expect(ctx.knownValues.containsKey('has_debt'), isFalse);
      expect(ctx.knownValues.containsKey('hasDebt'), isFalse);
    });

    test('hasDebt: true with all other fields zero does not affect knownValues', () {
      final ctx = CoachContextBuilder.build(hasDebt: true);
      expect(ctx.knownValues, isEmpty);
    });

    test('CoachContext const constructor accepts hasDebt field', () {
      const ctx = CoachContext(hasDebt: true);
      expect(ctx.hasDebt, isTrue);
    });

    test('CoachContext default constructor hasDebt is false', () {
      const ctx = CoachContext();
      expect(ctx.hasDebt, isFalse);
    });

    test('two contexts with different hasDebt are distinct', () {
      final safe = CoachContextBuilder.build(firstName: 'A', hasDebt: false);
      final crisis = CoachContextBuilder.build(firstName: 'A', hasDebt: true);
      expect(safe.hasDebt, isNot(equals(crisis.hasDebt)));
    });
  });
}
