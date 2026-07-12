import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  test('AVS status and certified counts are order-independent', () {
    final entries = <MapEntry<String, dynamic>>[
      const MapEntry('q_birth_year', 1980),
      const MapEntry('q_avs_lacunes_status', 'lived_abroad'),
      const MapEntry('q_avs_years_abroad', 4),
      const MapEntry('q_avs_contribution_years', 20),
    ];

    for (final ordered in [entries, entries.reversed.toList()]) {
      final profile = CoachProfile.fromWizardAnswers(
        LinkedHashMap.fromEntries(ordered),
      );
      expect(profile.toJson()['avsGapStatus'], 'lived_abroad');
      expect(profile.prevoyance.lacunesAVS, 4);
      expect(profile.prevoyance.anneesContribuees, 20);
    }
  });

  test('lived abroad without explicit years remains unknown', () {
    final profile = CoachProfile.fromWizardAnswers(const {
      'q_birth_year': 1980,
      'q_avs_lacunes_status': 'lived_abroad',
    });
    expect(profile.toJson()['avsGapStatus'], 'lived_abroad');
    expect(profile.prevoyance.lacunesAVS, isNull);
  });

  test('unknown and known-no-gap remain distinct typed states', () {
    final unknown = CoachProfile.fromWizardAnswers(const {
      'q_avs_lacunes_status': 'unknown',
    });
    final noGap = CoachProfile.fromWizardAnswers(const {
      'q_avs_lacunes_status': 'no_gaps',
    });

    expect(unknown.toJson()['avsGapStatus'], 'unknown');
    expect(unknown.prevoyance.lacunesAVS, isNull);
    expect(noGap.toJson()['avsGapStatus'], 'no_gaps');
    expect(noGap.prevoyance.lacunesAVS, 0);
  });
}
