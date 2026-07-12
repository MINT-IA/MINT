import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  test('3a contribution, monthly savings, and presence stay independent', () {
    final entries = <MapEntry<String, dynamic>>[
      const MapEntry('q_3a_annual_contribution', 7200),
      const MapEntry('q_savings_monthly', 900),
      const MapEntry('q_has_3a', 'yes'),
    ];

    for (final ordered in [entries, entries.reversed.toList()]) {
      final profile = CoachProfile.fromWizardAnswers(
        LinkedHashMap.fromEntries(ordered),
      );
      final json = profile.toJson();
      expect(json['pillar3aAnnualContribution'], 7200);
      expect(json['monthlySavingsContribution'], 900);
      expect(json['hasPillar3a'], isTrue);
      expect(profile.plannedContributions, isEmpty);
    }
  });

  test('ambiguous allocation aliases cannot fabricate exact fields', () {
    final profile = CoachProfile.fromWizardAnswers(const {
      'q_savings_allocation': ['3a'],
    });

    final json = profile.toJson();
    expect(json['pillar3aAnnualContribution'], isNull);
    expect(json['monthlySavingsContribution'], isNull);
    expect(json['hasPillar3a'], isNull);
  });
}
