import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

Map<String, dynamic> _answers({
  required List<MapEntry<String, dynamic>> values,
  Map<String, String> timestamps = const {},
}) =>
    LinkedHashMap.fromEntries([
      ...values,
      MapEntry('_coach_data_timestamps', timestamps),
    ]);

void main() {
  const canonical = '_coach_dettes_hypotheque';
  const legacy = 'q_mortgage_balance';

  test('sole dated mortgage value wins independently of map order', () {
    final values = <MapEntry<String, dynamic>>[
      const MapEntry(legacy, 500000),
      const MapEntry(canonical, 450000),
    ];
    for (final ordered in [values, values.reversed.toList()]) {
      final profile = CoachProfile.fromWizardAnswers(_answers(
        values: ordered,
        timestamps: const {canonical: '2026-07-01T00:00:00Z'},
      ));
      expect(profile.dettes.hypotheque, 450000);
      expect(profile.patrimoine.mortgageBalance, 450000);
    }
  });

  test('strictly newer dated mortgage wins', () {
    final profile = CoachProfile.fromWizardAnswers(_answers(
      values: const [
        MapEntry(legacy, 500000),
        MapEntry(canonical, 450000),
      ],
      timestamps: const {
        legacy: '2026-07-02T00:00:00Z',
        canonical: '2026-07-01T00:00:00Z',
      },
    ));
    expect(profile.dettes.hypotheque, 500000);
    expect(profile.patrimoine.mortgageBalance, 500000);
  });

  test('divergent missing or equal timestamps quarantine as unknown', () {
    for (final timestamps in [
      <String, String>{},
      <String, String>{
        legacy: '2026-07-01T00:00:00Z',
        canonical: '2026-07-01T00:00:00Z',
      },
    ]) {
      final profile = CoachProfile.fromWizardAnswers(_answers(
        values: const [
          MapEntry(legacy, 500000),
          MapEntry(canonical, 450000),
        ],
        timestamps: timestamps,
      ));
      expect(profile.dettes.hypotheque, isNull);
      expect(profile.patrimoine.mortgageBalance, isNull);
      expect(profile.userProvidedFields, isNot(contains('mortgageBalance')));
    }
  });

  test('equal values are canonical even without timestamps', () {
    final profile = CoachProfile.fromWizardAnswers(_answers(
      values: const [
        MapEntry(legacy, 480000),
        MapEntry(canonical, 480000),
      ],
    ));
    expect(profile.dettes.hypotheque, 480000);
    expect(profile.patrimoine.mortgageBalance, 480000);
  });
}
