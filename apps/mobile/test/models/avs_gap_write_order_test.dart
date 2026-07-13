import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  test('wizard AVS declarations never fabricate certified gap years', () {
    final entries = <MapEntry<String, dynamic>>[
      const MapEntry('q_birth_year', 1980),
      const MapEntry('q_avs_lacunes_status', 'lived_abroad'),
      const MapEntry('q_avs_years_abroad', 4),
    ];

    for (final ordered in [entries, entries.reversed.toList()]) {
      final answers = LinkedHashMap<String, dynamic>.fromEntries(ordered);
      final profile = CoachProfile.fromWizardAnswers(
        answers,
      );
      expect(profile.toJson()['avsGapStatus'], 'lived_abroad');
      expect(answers['q_avs_years_abroad'], 4);
      expect(profile.prevoyance.lacunesAVS, isNull);
      expect(
        profile.dataSources['prevoyance.lacunesAVS'],
        isNot(ProfileDataSource.certificate),
      );
    }
  });

  test('all declaration-only AVS statuses keep certified years unknown', () {
    const cases = <String, Map<String, dynamic>>{
      'arrived_late': {
        'q_birth_year': 1980,
        'q_avs_arrival_year': 2005,
      },
      'lived_abroad': {'q_avs_years_abroad': 4},
      'no_gaps': {},
      'unknown': {},
    };

    for (final entry in cases.entries) {
      final profile = CoachProfile.fromWizardAnswers({
        'q_avs_lacunes_status': entry.key,
        ...entry.value,
      });

      expect(profile.toJson()['avsGapStatus'], entry.key);
      expect(profile.prevoyance.lacunesAVS, isNull);
      expect(
        profile.dataSources['prevoyance.lacunesAVS'],
        isNot(ProfileDataSource.certificate),
      );
    }
  });

  test('legacy AVS scan marker leaves gap years estimated', () {
    final profile = CoachProfile.fromWizardAnswers(const {
      '_coach_avs_lacunes': 4,
      '_coach_avs_source': 'document_scan',
    });

    expect(profile.prevoyance.lacunesAVS, 4);
    expect(
      profile.dataSources['prevoyance.lacunesAVS'],
      ProfileDataSource.estimated,
    );
  });

  test('AVS contribution years and declared status keep exact provenance', () {
    final declared = CoachProfile.fromWizardAnswers(const {
      'q_birth_year': 1980,
      'q_avs_contribution_years': 20,
      'q_avs_lacunes_status': 'no_gaps',
    });
    final extracted = CoachProfile.fromWizardAnswers(const {
      'q_birth_year': 1980,
      'q_avs_contribution_years': 20,
      '_coach_avs_source': 'document_scan',
    });

    expect(declared.prevoyance.anneesContribuees, 20);
    expect(
      declared.dataSources['prevoyance.anneesContribuees'],
      ProfileDataSource.userInput,
    );
    expect(
      declared.dataSources['avsGapStatus'],
      ProfileDataSource.userInput,
    );
    expect(declared.dataTimestamps, contains('avsGapStatus'));
    expect(declared.prevoyance.lacunesAVS, isNull);
    expect(
      declared.dataSources['prevoyance.lacunesAVS'],
      isNull,
    );

    expect(extracted.prevoyance.anneesContribuees, 20);
    expect(
      extracted.dataSources['prevoyance.anneesContribuees'],
      ProfileDataSource.userInput,
    );
  });
}
