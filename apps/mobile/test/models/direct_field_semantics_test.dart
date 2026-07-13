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
      expect(
          profile.userProvidedFields,
          containsAll([
            'pillar3aAnnualContribution',
            'monthlySavingsContribution',
            'has3a',
          ]));
      expect(profile.dataTimestamps, contains('pillar3aAnnualContribution'));
      expect(profile.dataTimestamps, contains('monthlySavingsContribution'));
      expect(profile.plannedContributions, isEmpty);
    }
  });

  test('each direct write leaves the other exact facts unknown', () {
    final fixtures = <({
      Map<String, dynamic> answers,
      double? annual3a,
      double? monthlySavings,
      bool? has3a,
      String marker
    })>[
      (
        answers: const {'q_3a_annual_contribution': 7200},
        annual3a: 7200,
        monthlySavings: null,
        has3a: null,
        marker: 'pillar3aAnnualContribution',
      ),
      (
        answers: const {'q_savings_monthly': 900},
        annual3a: null,
        monthlySavings: 900,
        has3a: null,
        marker: 'monthlySavingsContribution',
      ),
      (
        answers: const {'q_has_3a': 'yes'},
        annual3a: null,
        monthlySavings: null,
        has3a: true,
        marker: 'has3a',
      ),
      (
        answers: const {'q_has_3a': 'no'},
        annual3a: null,
        monthlySavings: null,
        has3a: false,
        marker: 'has3a',
      ),
    ];

    for (final fixture in fixtures) {
      final profile = CoachProfile.fromWizardAnswers(fixture.answers);

      expect(profile.pillar3aAnnualContribution, fixture.annual3a);
      expect(profile.monthlySavingsContribution, fixture.monthlySavings);
      expect(profile.hasPillar3a, fixture.has3a);
      expect(profile.userProvidedFields, contains(fixture.marker));
      expect(profile.plannedContributions, isEmpty);
    }
  });

  test('ambiguous allocation aliases cannot fabricate a plan or exact fields',
      () {
    final entries = <MapEntry<String, dynamic>>[
      const MapEntry(
        'q_savings_allocation',
        ['3a', 'investissement', 'epargne_libre'],
      ),
      const MapEntry('q_savings_monthly', 900),
    ];

    for (final ordered in [entries, entries.reversed.toList()]) {
      final profile = CoachProfile.fromWizardAnswers(
        LinkedHashMap.fromEntries(ordered),
      );

      expect(profile.pillar3aAnnualContribution, isNull);
      expect(profile.monthlySavingsContribution, 900);
      expect(profile.hasPillar3a, isNull);
      expect(profile.plannedContributions, isEmpty);
      expect(
        profile.userProvidedFields,
        isNot(contains('pillar3aAnnualContribution')),
      );
      expect(
          profile.userProvidedFields, contains('monthlySavingsContribution'));
      expect(profile.userProvidedFields, isNot(contains('has3a')));
    }
  });
}
