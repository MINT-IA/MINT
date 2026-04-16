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
}
