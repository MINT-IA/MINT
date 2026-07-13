import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/sequence_template.dart';

void main() {
  test('FIX-190: preretraite_complete is reachable via templateForIntent', () {
    final template = SequenceTemplate.templateForIntent('preretraite_complete');
    expect(template, isNotNull);
    expect(template!.id, 'preretraite_complete');
    expect(template.steps.length, 11);
  });

  test('all 10 templates are reachable via at least one intent', () {
    final intents = [
      'housing_purchase', 'retirement_projection', 'preretraite_complete',
      'simulator_3a', 'debt_ratio', 'life_event_first_job',
      'disability_gap', 'succession_patrimoine', 'life_event_marriage',
      'life_event_birth',
    ];
    for (final intent in intents) {
      expect(SequenceTemplate.templateForIntent(intent), isNotNull,
          reason: 'No template for intent: $intent');
    }
  });

  test('housing fiscal step requires a real withdrawal-tax output', () {
    final fiscalStep = SequenceTemplate.housingPurchase.steps.singleWhere(
      (step) => step.id == 'housing_03_fiscal',
    );

    expect(fiscalStep.requiredOutputKeys, {'impot_retrait'});
  });

  test('sequence navigation has no domain-prefill facade', () {
    final source = [
      File('lib/models/sequence_template.dart').readAsStringSync(),
      File('lib/services/sequence/sequence_coordinator.dart')
          .readAsStringSync(),
    ].join('\n');

    expect(source, isNot(contains('outputMapping')));
    expect(source, isNot(contains('_buildPrefill')));
    expect(source, isNot(contains('prefill')));
  });

  test('orphan sequence summary and progress facades stay deleted', () {
    for (final path in [
      'lib/models/sequence_message_payload.dart',
      'lib/services/sequence/sequence_summary_builder.dart',
      'lib/widgets/coach/sequence_progress_card.dart',
    ]) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
  });
}
