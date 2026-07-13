import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('G1 keeps retired financial facades out of production code', () {
    final productionSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => MapEntry(file.path, file.readAsStringSync()))
        .toList();

    const forbiddenReferences = <String>[
      'class PremierEclairageSection',
      'PremierEclairageCoachCard',
      'premier_eclairage_section.dart',
      'premier_eclairage_card_coach.dart',
      'EarlyRetirementComparison',
      'EarlyRetirementScenario',
      'EarlyRetirementChart',
      'earlyRetirementComparisons',
      'early_retirement_comparison.dart',
      'early_retirement_chart.dart',
      'TornadoSensitivityService',
      'tornado_sensitivity_service.dart',
    ];

    final violations = <String>[];
    for (final source in productionSources) {
      for (final forbidden in forbiddenReferences) {
        if (source.value.contains(forbidden)) {
          violations.add('${source.key}: $forbidden');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Removed G1 facades must not regain production references.',
    );
  });
}
