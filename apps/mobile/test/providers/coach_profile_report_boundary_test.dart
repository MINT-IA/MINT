import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

void main() {
  test('report answers are an owned, deeply immutable snapshot', () async {
    final input = <String, dynamic>{
      'q_birth_year': 1985,
      'q_canton': 'ZH',
      'q_net_income_period_chf': 8000,
      '_coach_data_timestamps': <String, dynamic>{
        'age': '2026-07-12T00:00:00.000Z',
      },
    };
    final provider = CoachProfileProvider()..updateFromAnswers(input);

    input['q_canton'] = 'GE';
    (input['_coach_data_timestamps'] as Map<String, dynamic>)['age'] =
        '2030-01-01T00:00:00.000Z';
    final snapshot = provider.reportAnswersSnapshot;

    expect(snapshot['q_canton'], 'ZH');
    expect(
      (snapshot['_coach_data_timestamps'] as Map)['age'],
      '2026-07-12T00:00:00.000Z',
    );
    expect(() => snapshot['q_canton'] = 'VD', throwsUnsupportedError);
    expect(
      () => (snapshot['_coach_data_timestamps'] as Map)['age'] = 'changed',
      throwsUnsupportedError,
    );
    expect(await provider.waitForReportAnswers(), snapshot);
  });

  test('report hydration wait has a bounded timeout', () async {
    final provider = CoachProfileProvider();

    await expectLater(
      provider.waitForReportAnswers(timeout: Duration.zero),
      throwsA(isA<TimeoutException>()),
    );
  });
}
